"""A double-sided DFS image (.dsd) in drive 0 shows its second side as drive 2.

NIO serves a DSD's sectors in logical order: all of side 0, then all of side 1
(from LBA 400 for 40 tracks, 800 for 80). The fake device below holds the image
in that order, so the ROM must address both drives through the one slot.
"""
from __future__ import annotations

import pytest

from fujinet_tools import diskproto as dp

from fuji_device import (
    DISK_CMD_BEGIN_HOST_SESSION,
    build_disk_mount_like_response,
    build_disk_mount_response,
    build_disk_read_sector_response,
    default_success_responder,
    slot_catalog_response,
)
from helpers import command, wait_for_screen_text
from scripted.test_boot_session import _hard_break, _make_marker_ssd

DSD_SLOT = 1
SSD_SLOT = 2


class DsdResponder:
    def __init__(self, dsd_image: bytes, ssd_image: bytes, sector_count: int):
        self.dsd_image = dsd_image
        self.ssd_image = ssd_image
        self.sector_count = sector_count
        self.images: dict[int, tuple[bytes, int, int]] = {}
        self.reads: list[tuple[int, int]] = []

    def __call__(self, pkt):
        catalog = slot_catalog_response(pkt, {
            DSD_SLOT: (0x01, "sd0:/work.dsd"),
            SSD_SLOT: (0x01, "sd0:/other.ssd"),
        })
        if catalog is not None:
            return catalog
        if pkt.device != dp.DISK_DEVICE_ID:
            return default_success_responder(pkt)

        if pkt.command == DISK_CMD_BEGIN_HOST_SESSION:
            return build_disk_mount_like_response(
                command=DISK_CMD_BEGIN_HOST_SESSION, slot=1, mounted=False
            )

        if pkt.command == dp.CMD_MOUNT:
            slot = pkt.payload[1]
            lazy = pkt.payload[2] & 0x02
            uri = pkt.payload[8:].decode("ascii")
            if uri.endswith(".dsd"):
                self.images[slot] = (self.dsd_image, dp.TYPE_DSD, self.sector_count)
            else:
                self.images[slot] = (self.ssd_image, dp.TYPE_SSD, 800)
            _, img_type, count = self.images[slot]
            if lazy:
                # NIO defers opening a lazy mount, so it reports no geometry.
                img_type, count = 0, 0
            return build_disk_mount_response(
                slot=slot, img_type=img_type, sector_count=count
            )

        if pkt.command == dp.CMD_READ_SECTOR:
            slot = pkt.payload[1]
            lba = int.from_bytes(pkt.payload[2:6], "little")
            self.reads.append((slot, lba))
            image = self.images.get(slot, (b"", 0, 0))[0]
            data = image[lba * 256:(lba + 1) * 256]
            data = data + bytes(256 - len(data))
            return build_disk_read_sector_response(slot=slot, lba=lba, data=data)

        return default_success_responder(pkt)


def _make_dsd(tmp_path, sectors_per_side: int) -> bytes:
    side0 = _make_marker_ssd(tmp_path, "SIDE0", "SIDE0MK").read_bytes()
    side1 = _make_marker_ssd(tmp_path, "SIDE1", "SIDE1MK").read_bytes()
    # create_ssd.py pads to 80 tracks; the markers sit in the first sectors.
    side_bytes = sectors_per_side * 256
    return (side0[:side_bytes].ljust(side_bytes, b"\0")
            + side1[:side_bytes].ljust(side_bytes, b"\0"))


def _responder(tmp_path, sectors_per_side: int) -> DsdResponder:
    other = _make_marker_ssd(tmp_path, "OTHER", "OTHERMK").read_bytes()
    return DsdResponder(
        _make_dsd(tmp_path, sectors_per_side), other, sectors_per_side * 2
    )


def _cat_drive_and_expect(beebium, drive: int, text: str) -> None:
    command(beebium, "CLS")
    command(beebium, f"*. :{drive}")
    wait_for_screen_text(beebium, text, timeout=8.0)


def _fmount(beebium, fuji_device, catalog_slot: int, drive: int):
    fuji_device.clear()
    command(beebium, f"*FMOUNT {catalog_slot} {drive}")
    pkt = fuji_device.wait_for_command(dp.DISK_DEVICE_ID, dp.CMD_MOUNT, timeout=8.0)
    assert pkt is not None
    assert pkt.checksum_ok
    return pkt


@pytest.mark.parametrize("sectors_per_side", [800, 400], ids=["80-track", "40-track"])
def test_dsd_in_drive_0_shows_side_1_as_drive_2(
    beebium, fuji_device, tmp_path, sectors_per_side
):
    responder = _responder(tmp_path, sectors_per_side)
    fuji_device.set_responder(responder)
    _hard_break(beebium)

    pkt = _fmount(beebium, fuji_device, DSD_SLOT, 0)
    # The ROM needs the DSD's geometry for drive 2, so it mounts eagerly.
    assert pkt.payload == dp.build_mount_req(
        slot=1, uri="sd0:/work.dsd", readonly=False,
        type_override=0, sector_size_hint=0,
    )

    _cat_drive_and_expect(beebium, 0, "SIDE0MK")
    responder.reads.clear()
    _cat_drive_and_expect(beebium, 2, "SIDE1MK")
    # Drive 2 reads the same slot, past all of side 0.
    assert responder.reads
    assert all(slot == 1 for slot, _ in responder.reads)
    assert min(lba for _, lba in responder.reads) == sectors_per_side

    # Drive 0 goes back to side 0 afterwards.
    _cat_drive_and_expect(beebium, 0, "SIDE0MK")


def test_ssd_mount_is_still_lazy_and_leaves_drive_2_alone(
    beebium, fuji_device, tmp_path
):
    responder = _responder(tmp_path, 800)
    fuji_device.set_responder(responder)
    _hard_break(beebium)

    pkt = _fmount(beebium, fuji_device, SSD_SLOT, 0)
    assert pkt.payload[2] & 0x02, "an SSD mount stays lazy"
    _cat_drive_and_expect(beebium, 0, "OTHERMK")

    responder.reads.clear()
    command(beebium, "CLS")
    command(beebium, "*. :2")
    wait_for_screen_text(beebium, "No disk", timeout=8.0)
    assert responder.reads == []


def test_replacing_dsd_in_drive_0_unmaps_its_second_side(
    beebium, fuji_device, tmp_path
):
    responder = _responder(tmp_path, 800)
    fuji_device.set_responder(responder)
    _hard_break(beebium)

    _fmount(beebium, fuji_device, DSD_SLOT, 0)
    _cat_drive_and_expect(beebium, 2, "SIDE1MK")

    _fmount(beebium, fuji_device, SSD_SLOT, 0)
    _cat_drive_and_expect(beebium, 0, "OTHERMK")

    # Drive 2 must not read side 1 of the SSD that replaced the DSD.
    responder.reads.clear()
    command(beebium, "CLS")
    command(beebium, "*. :2")
    wait_for_screen_text(beebium, "No disk", timeout=8.0)
    assert responder.reads == []

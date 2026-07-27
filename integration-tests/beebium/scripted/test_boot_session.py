from __future__ import annotations

import shutil
import subprocess
import time
from pathlib import Path

import pytest

from fujinet_tools import diskproto as dp
from fujinet_tools import fujiproto as fuji

from fuji_device import (
    DISK_CMD_BEGIN_HOST_SESSION,
    build_disk_info_response,
    build_disk_mount_like_response,
    build_disk_mount_response,
    build_disk_read_sector_response,
    build_get_mount_response,
    build_set_mount_response,
    default_success_responder,
)
from helpers import command, wait_for_screen_text

_ROOT = Path(__file__).resolve().parents[3]
_CREATE_SSD = _ROOT / "scripts" / "create_ssd.py"


def _make_marker_ssd(tmp_path: Path, title: str, marker: str) -> Path:
    if shutil.which("dfstool") is None:
        pytest.skip("dfstool not available in PATH; required to generate SSD fixtures")
    src = tmp_path / title.lower()
    src.mkdir()
    data = src / f"$.{marker}"
    data.write_text(f"{marker}\n")
    (src / f"$.{marker}.inf").write_text(f"$.{marker} 000000 000000\n")
    out = tmp_path / f"{title.lower()}.ssd"
    subprocess.run(
        [str(_CREATE_SSD), "-i", str(src), "-o", str(out), "-t", title],
        cwd=str(_ROOT),
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return out


class BootSessionResponder:
    def __init__(self, boot_image: bytes, work_image: bytes):
        self.images = {
            1: boot_image,  # boot/config disk in BBC drive 0
            2: work_image,  # *FMOUNT 1 0 maps Fuji slot 1 to DiskDevice slot 2
        }

    def __call__(self, pkt):
        if pkt.device == fuji.FUJI_DEVICE_ID:
            if pkt.command == fuji.CMD_GET_MOUNT:
                slot = pkt.payload[0]
                return build_get_mount_response(
                    slot=slot,
                    enabled=True,
                    uri="sd0:/work.ssd" if slot == 1 else "sd0:/boot.ssd",
                )
            if pkt.command == fuji.CMD_SET_MOUNT:
                return build_set_mount_response()
            return default_success_responder(pkt)

        if pkt.device != dp.DISK_DEVICE_ID:
            return default_success_responder(pkt)

        if pkt.command == DISK_CMD_BEGIN_HOST_SESSION:
            return build_disk_mount_like_response(
                command=DISK_CMD_BEGIN_HOST_SESSION,
                slot=1,
                readonly=True,
                sector_count=len(self.images[1]) // 256,
            )

        if pkt.command == dp.CMD_RESTORE_BOOT:
            return build_disk_mount_like_response(
                command=dp.CMD_RESTORE_BOOT,
                slot=1,
                readonly=True,
                sector_count=len(self.images[1]) // 256,
            )

        if pkt.command == dp.CMD_MOUNT:
            slot = pkt.payload[1]
            return build_disk_mount_response(
                slot=slot,
                sector_count=len(self.images.get(slot, b"")) // 256,
            )

        if pkt.command == dp.CMD_INFO:
            slot = pkt.payload[1]
            return build_disk_info_response(
                slot=slot,
                sector_count=len(self.images.get(slot, b"")) // 256,
            )

        if pkt.command == dp.CMD_READ_SECTOR:
            slot = pkt.payload[1]
            lba = int.from_bytes(pkt.payload[2:6], "little")
            maxb = int.from_bytes(pkt.payload[6:8], "little") or 256
            image = self.images.get(slot, b"")
            start = lba * 256
            data = image[start:start + min(maxb, 256)]
            if len(data) < 256:
                data = data + bytes(256 - len(data))
            return build_disk_read_sector_response(slot=slot, lba=lba, data=data)

        return default_success_responder(pkt)


@pytest.fixture()
def boot_session_responder(tmp_path):
    boot = _make_marker_ssd(tmp_path, "FNBOOT", "BOOTMRK").read_bytes()
    work = _make_marker_ssd(tmp_path, "FNWORK", "WORKMRK").read_bytes()
    return BootSessionResponder(boot, work)


def _hard_break(beebium) -> None:
    assert beebium.keyboard.ctrl_break()
    assert beebium.system.wait_for_ready(timeout=5.0)
    time.sleep(0.2)


def _soft_break(beebium) -> None:
    assert beebium.keyboard.press_break()
    assert beebium.system.wait_for_ready(timeout=5.0)
    time.sleep(0.2)


def _cat_and_expect(beebium, text: str) -> None:
    command(beebium, "CLS")
    command(beebium, "*CAT")
    wait_for_screen_text(beebium, text, timeout=8.0)


def _mount_work_drive(beebium, fuji_device) -> None:
    fuji_device.clear()
    command(beebium, "*FMOUNT 1 0")
    pkt = fuji_device.wait_for_command(dp.DISK_DEVICE_ID, dp.CMD_MOUNT, timeout=8.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == dp.build_mount_req(
        slot=2,
        uri="sd0:/work.ssd",
        readonly=False,
        type_override=0,
        sector_size_hint=0,
    )


def test_hard_break_begins_host_session_and_restores_boot_disk(
    beebium, fuji_device, boot_session_responder
):
    fuji_device.set_responder(boot_session_responder)
    fuji_device.clear()

    _hard_break(beebium)

    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, DISK_CMD_BEGIN_HOST_SESSION, timeout=8.0
    )
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == bytes([dp.DISKPROTO_VERSION, 1])

    _cat_and_expect(beebium, "BOOTMRK")


def test_soft_break_preserves_manually_mounted_disk(
    beebium, fuji_device, boot_session_responder
):
    fuji_device.set_responder(boot_session_responder)
    _hard_break(beebium)
    _mount_work_drive(beebium, fuji_device)
    _cat_and_expect(beebium, "WORKMRK")

    fuji_device.clear()
    _soft_break(beebium)

    assert fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, DISK_CMD_BEGIN_HOST_SESSION, timeout=1.0
    ) is None
    _cat_and_expect(beebium, "WORKMRK")


def test_hard_break_replaces_manually_mounted_disk_with_boot_disk(
    beebium, fuji_device, boot_session_responder
):
    fuji_device.set_responder(boot_session_responder)
    _hard_break(beebium)
    _mount_work_drive(beebium, fuji_device)
    _cat_and_expect(beebium, "WORKMRK")

    fuji_device.clear()
    _hard_break(beebium)

    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, DISK_CMD_BEGIN_HOST_SESSION, timeout=8.0
    )
    assert pkt is not None
    assert pkt.checksum_ok
    _cat_and_expect(beebium, "BOOTMRK")


@pytest.mark.needs_boot_utils_setup
def test_fboot_restores_boot_disk_without_beginning_new_session(
    beebium, fuji_device, boot_session_responder
):
    fuji_device.set_responder(boot_session_responder)
    _hard_break(beebium)
    _mount_work_drive(beebium, fuji_device)
    _cat_and_expect(beebium, "WORKMRK")

    fuji_device.clear()
    command(beebium, "*FBOOT")

    restore = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_RESTORE_BOOT, timeout=8.0
    )
    assert restore is not None
    assert restore.checksum_ok
    assert restore.payload == bytes([dp.DISKPROTO_VERSION, 1])
    assert fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, DISK_CMD_BEGIN_HOST_SESSION, timeout=1.0
    ) is None

    _cat_and_expect(beebium, "BOOTMRK")

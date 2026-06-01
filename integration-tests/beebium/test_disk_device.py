from __future__ import annotations

from fujinet_tools import diskproto as dp

from fuji_device import full_stack_responder, mounted_disk_responder


def _command(bbc, text: str) -> None:
    with bbc.keyboard.text_input():
        bbc.keyboard.type(text)
        bbc.keyboard.press_return()


def test_fmount_gets_slot_then_mounts_disk(beebium, fuji_device):
    fuji_device.set_responder(mounted_disk_responder(slot=2, uri="tnfs://example.invalid/bbc/BOOT.SSD"))

    _command(beebium, "*FMOUNT 2 0 RO")

    pkt = fuji_device.wait_for_command(dp.DISK_DEVICE_ID, dp.CMD_MOUNT, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    req = dp.build_mount_req(
        slot=3,
        uri="tnfs://example.invalid/bbc/BOOT.SSD",
        readonly=True,
        type_override=0,
        sector_size_hint=0,
    )
    assert pkt.payload == req


def test_fnew_emits_disk_create_request(beebium, fuji_device):
    fuji_device.set_responder(full_stack_responder(
        resolved_uri="tnfs://example.invalid/bbc/",
        display_path="bbc/",
        mount_slot=0,
    ))

    _command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(0xFE, 0x05, timeout=6.0)

    fuji_device.clear()
    _command(beebium, "*FNEW blank.ssd")
    pkt = fuji_device.wait_for_command(dp.DISK_DEVICE_ID, dp.CMD_CREATE, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == dp.build_create_req(
        uri="tnfs://example.invalid/bbc/blank.ssd",
        img_type=dp.TYPE_SSD,
        sector_size=256,
        sector_count=800,
        overwrite=False,
    )


def test_fmount_then_fout_unmounts_disk_when_slot_is_mapped(beebium, fuji_device):
    fuji_device.set_responder(mounted_disk_responder(slot=2, uri="tnfs://example.invalid/bbc/BOOT.SSD"))

    _command(beebium, "*FMOUNT 2 0")
    assert fuji_device.wait_for_command(dp.DISK_DEVICE_ID, dp.CMD_MOUNT, timeout=6.0)

    fuji_device.clear()
    _command(beebium, "*FOUT 2")
    pkt = fuji_device.wait_for_command(dp.DISK_DEVICE_ID, dp.CMD_UNMOUNT, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == dp.build_unmount_req(slot=3)

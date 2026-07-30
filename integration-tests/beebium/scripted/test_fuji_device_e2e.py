from __future__ import annotations

import pytest

from fujinet_tools import fileproto as fp
from fujinet_tools import fujiproto as fuji

from beebium.client.screen import dump_screen
from fuji_device import (
    FILE_CMD_APPSTORE_WRITE,
    HOST_CMD_SET_CURRENT,
    HOST_SERVICE_ID,
    full_stack_responder,
    mounted_disk_responder,
)
from helpers import command, wait_for_screen_text


@pytest.mark.needs_boot_utils_setup
def test_fdrive_requests_formatted_mounts(beebium, fuji_device):
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == fuji.build_get_mounts_req(flags=0x01, first_slot=0, last_slot=0, start_index=0, max_payload_bytes=220)


def test_fin_persists_sparse_appstore_slot(beebium, fuji_device):
    fuji_device.set_responder(full_stack_responder(
        resolved_uri="tnfs://example.invalid/bbc/",
        display_path="bbc/",
        mount_slot=0,
    ))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FIN 3 boot.ssd")
    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_APPSTORE_WRITE, timeout=6.0
    )

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == (
        bytes([fp.FILEPROTO_VERSION, 10, 0])
        + b"config-nio"
        + bytes([8, 0])
        + b"slot-003"
        + bytes(4)
        + bytes([10, 0, 1, 0])
        + b"boot.ssd"
    )


@pytest.mark.needs_boot_utils_setup
def test_fout_round_trip_gets_then_clears_mount(beebium, fuji_device):
    fuji_device.set_responder(mounted_disk_responder(slot=2, uri="sd0:/BOOT.SSD"))

    command(beebium, "*FDRIVE")
    screen = wait_for_screen_text(beebium, "BOOT.SSD", timeout=6.0)
    assert "2: AUTO sd0:/BOOT.SSD" in screen

    command(beebium, "CLS")
    fuji_device.clear()
    command(beebium, "*FOUT 2")

    get_pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNT, timeout=6.0)
    assert get_pkt is not None
    assert get_pkt.checksum_ok
    assert get_pkt.payload == b"\x02"

    set_pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_SET_MOUNT, timeout=6.0)
    assert set_pkt is not None
    assert set_pkt.checksum_ok
    assert set_pkt.payload == b"\x02\x00\x00\x00"

    command(beebium, "CLS")
    command(beebium, "*FDRIVE")
    screen = dump_screen(beebium)
    assert "BOOT.SSD" not in screen
    assert "2: AUTO" not in screen

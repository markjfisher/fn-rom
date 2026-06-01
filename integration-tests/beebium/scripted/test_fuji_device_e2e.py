from __future__ import annotations

from fujinet_tools import fujiproto as fuji

from fuji_device import full_stack_responder, mounted_disk_responder
from helpers import command


def test_fdrive_requests_formatted_mounts(beebium, fuji_device):
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == fuji.build_get_mounts_req(flags=0x01, first_slot=0, last_slot=0, start_index=0, max_payload_bytes=220)


def test_fin_emits_set_mount_request(beebium, fuji_device):
    fuji_device.set_responder(full_stack_responder(
        resolved_uri="tnfs://example.invalid/bbc/",
        display_path="bbc/",
        mount_slot=0,
    ))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(0xFE, 0x05, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FIN 3 boot.ssd")
    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_SET_MOUNT, timeout=6.0)

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload[0] == 3
    assert pkt.payload[1] == 1
    uri_len = pkt.payload[2]
    uri = pkt.payload[3:3 + uri_len].decode("utf-8")
    mode_len = pkt.payload[3 + uri_len]
    mode = pkt.payload[4 + uri_len:4 + uri_len + mode_len].decode("utf-8")
    assert uri == "tnfs://example.invalid/bbc/boot.ssd"
    assert mode == "auto"


def test_fout_round_trip_gets_then_clears_mount(beebium, fuji_device):
    fuji_device.set_responder(mounted_disk_responder(slot=2, uri="tnfs://example.invalid/bbc/BOOT.SSD"))

    command(beebium, "*FOUT 2")

    get_pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNT, timeout=6.0)
    assert get_pkt is not None
    assert get_pkt.checksum_ok
    assert get_pkt.payload == b"\x02"

    set_pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_SET_MOUNT, timeout=6.0)
    assert set_pkt is not None
    assert set_pkt.checksum_ok
    assert set_pkt.payload == b"\x02\x00\x00\x00"

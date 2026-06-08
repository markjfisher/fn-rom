from __future__ import annotations

import time

import pytest

from beebium.screen import dump_screen
from fujinet_tools import fileproto as fp
from fujinet_tools import fujiproto as fuji

from fuji_device import resolving_responder
from helpers import command


def test_fhost_screen_text_and_wire_payload_case(beebium, fuji_device):
    typed = "*FHOST tnfs://example.invalid/bbc/"

    with beebium.keyboard.text_input():
        beebium.keyboard.type(typed)

        deadline = time.monotonic() + 10.0
        screen = ""
        while time.monotonic() < deadline:
            screen = dump_screen(beebium)
            if "tnfs://example.invalid/bbc/" in screen:
                break
            time.sleep(0.02)

        assert "tnfs://example.invalid/bbc/" in screen, screen
        assert "TNFS://EXAMPLE.INVALID/BBC/" not in screen, screen

        beebium.keyboard.press_return()

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok

    base_uri, arg = fp.parse_resolve_path_req(pkt.payload)
    assert arg == ""
    assert base_uri == "tnfs://example.invalid/bbc/"


def test_fhost_emits_resolve_path_request(beebium, fuji_device):
    command(beebium, "*FHOST tnfs://example.invalid/bbc/")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)
    assert pkt is not None, "no RESOLVE_PATH request observed on the serial/PTY link"
    assert pkt.checksum_ok, "FujiBus checksum mismatch on the emitted frame"
    base_uri, arg = fp.parse_resolve_path_req(pkt.payload)
    assert base_uri == "tnfs://example.invalid/bbc/"
    assert arg == ""


@pytest.mark.needs_resident_utils
def test_fdrive_emits_fuji_get_mounts_request(beebium, fuji_device):
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=6.0)
    assert pkt is not None, "no GET_MOUNTS request observed for *FDRIVE"
    assert pkt.checksum_ok


@pytest.mark.needs_resident_utils
def test_fhost_then_fls_round_trip(beebium, fuji_device):
    fuji_device.set_responder(resolving_responder("tnfs://example.invalid/bbc/", "bbc/"))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FLS")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok

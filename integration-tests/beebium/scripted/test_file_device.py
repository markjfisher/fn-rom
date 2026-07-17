from __future__ import annotations

import pytest

from fujinet_tools import fileproto as fp
from fujinet_tools import fujibus as fb

from fuji_device import (
    HOST_CMD_SET_CURRENT,
    HOST_SERVICE_ID,
    HOST_VERSION,
    build_list_response,
    file_listing_responder,
    host_service_responder,
)
from helpers import command, wait_for_screen_text


def _parse_host_set_req(payload: bytes) -> str:
    assert payload[0] == HOST_VERSION
    n = payload[1] | (payload[2] << 8)
    return payload[3:3 + n].decode("utf-8")


def test_fhost_request_payload_is_structured(beebium, fuji_device):
    fuji_device.set_responder(host_service_responder())

    command(beebium, "*FHOST tnfs://x/bbc/")
    screen = wait_for_screen_text(beebium, "PATH: /bbc/", timeout=6.0)

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert _parse_host_set_req(pkt.payload) == "tnfs://x/bbc/"
    assert "HOST: tnfs://x/bbc/" in screen
    assert "PATH: /bbc/" in screen


@pytest.mark.needs_resident_utils
def test_fcd_emits_relative_host_service_set_request(beebium, fuji_device):
    fuji_device.set_responder(host_service_responder())

    command(beebium, "*FHOST tnfs://x/bbc/")
    wait_for_screen_text(beebium, "PATH: /bbc/", timeout=6.0)
    assert fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FCD games")
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert _parse_host_set_req(pkt.payload) == "games"


@pytest.mark.needs_resident_utils
def test_fls_round_trip_uses_formatted_list_response(beebium, fuji_device):
    listing = "A.$.BOOT\nA.$.GAMES\n"
    fuji_device.set_responder(file_listing_responder(
        resolved_uri="tnfs://x/bbc/",
        display_path="bbc/",
        formatted_text=listing,
    ))

    command(beebium, "*FHOST tnfs://x/bbc/")
    wait_for_screen_text(beebium, "PATH: /bbc/", timeout=6.0)
    assert fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FLS")
    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == bytes([
        fp.FILEPROTO_VERSION,
        0x00, 0x00,        # empty spec: FujiNet resolves against current host
        0x00, 0x00,        # start index
        220, 0x00,         # max formatted payload bytes
        0x06,              # sort by name + formatted text
    ])

    resp_wire = build_list_response(formatted_text=listing)
    resp_pkt = fb.parse_fuji_packet(fb.slip_decode(resp_wire))
    assert resp_pkt is not None
    resp = fp.parse_list_resp(resp_pkt.payload)
    assert resp.formatted is True
    assert resp.text == listing

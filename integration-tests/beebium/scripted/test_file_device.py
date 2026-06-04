from __future__ import annotations

import pytest

from fujinet_tools import fileproto as fp
from fujinet_tools import fujibus as fb

from fuji_device import build_list_response, file_listing_responder
from helpers import command


def test_fhost_request_payload_is_structured(beebium, fuji_device):
    command(beebium, "*FHOST tnfs://example.invalid/bbc/")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok

    base_uri, arg = fp.parse_resolve_path_req(pkt.payload)
    assert base_uri == "tnfs://example.invalid/bbc/"
    assert arg == ""


@pytest.mark.needs_resident_utils
def test_fcd_emits_relative_resolve_path_request(beebium, fuji_device):
    fuji_device.set_responder(file_listing_responder(
        resolved_uri="tnfs://example.invalid/bbc/",
        display_path="bbc/",
        formatted_text="",
    ))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FCD games")
    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    assert pkt is not None
    assert pkt.checksum_ok
    base_uri, arg = fp.parse_resolve_path_req(pkt.payload)
    assert base_uri == "tnfs://example.invalid/bbc/"
    assert arg == "games"


@pytest.mark.needs_resident_utils
def test_fls_round_trip_uses_formatted_list_response(beebium, fuji_device):
    listing = "A.$.BOOT\nA.$.GAMES\n"
    fuji_device.set_responder(file_listing_responder(
        resolved_uri="tnfs://example.invalid/bbc/",
        display_path="bbc/",
        formatted_text=listing,
    ))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FLS")
    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == fp.build_list_req("tnfs://example.invalid/bbc/", 0, 220, list_flags=0x06)

    resp_wire = build_list_response(formatted_text=listing)
    resp_pkt = fb.parse_fuji_packet(fb.slip_decode(resp_wire))
    assert resp_pkt is not None
    resp = fp.parse_list_resp(resp_pkt.payload)
    assert resp.formatted is True
    assert resp.text == listing

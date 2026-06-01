from __future__ import annotations

from fujinet_tools import fileproto as fp

from fuji_device import build_list_response, file_listing_responder
from fujinet_tools import fujibus as fb


def _command(bbc, text: str) -> None:
    bbc.keyboard.type(text)
    bbc.keyboard.press_return()


def test_fhost_request_payload_is_structured(beebium, fuji_device):
    _command(beebium, "*FHOST tnfs://192.168.1.101/bbc/")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok

    base_uri, arg = fp.parse_resolve_path_req(pkt.payload)
    assert base_uri == "TNFS://192.168.1.101/BBC/"
    assert arg == ""


def test_fcd_emits_relative_resolve_path_request(beebium, fuji_device):
    fuji_device.set_responder(file_listing_responder(
        resolved_uri="TNFS://192.168.1.101/BBC/",
        display_path="BBC/",
        formatted_text="",
    ))

    _command(beebium, "*FHOST tnfs://192.168.1.101/bbc/")
    assert fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    fuji_device.clear()
    _command(beebium, "*FCD games")
    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    assert pkt is not None
    assert pkt.checksum_ok
    base_uri, arg = fp.parse_resolve_path_req(pkt.payload)
    assert base_uri == "TNFS://192.168.1.101/BBC/"
    assert arg == "GAMES"


def test_fls_round_trip_uses_formatted_list_response(beebium, fuji_device):
    listing = "A.$.BOOT\nA.$.GAMES\n"
    fuji_device.set_responder(file_listing_responder(
        resolved_uri="TNFS://192.168.1.101/BBC/",
        display_path="BBC/",
        formatted_text=listing,
    ))

    _command(beebium, "*FHOST tnfs://192.168.1.101/bbc/")
    assert fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)

    fuji_device.clear()
    _command(beebium, "*FLS")
    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == fp.build_list_req("TNFS://192.168.1.101/BBC/", 0, 220, list_flags=0x06)

    resp_wire = build_list_response(formatted_text=listing)
    resp_pkt = fb.parse_fuji_packet(fb.slip_decode(resp_wire))
    assert resp_pkt is not None
    resp = fp.parse_list_resp(resp_pkt.payload)
    assert resp.formatted is True
    assert resp.text == listing

from __future__ import annotations

import pytest

from fujinet_tools import netproto as netp

from fuji_device import build_network_open_response


def _command(bbc, text: str) -> None:
    with bbc.keyboard.text_input():
        bbc.keyboard.type(text)
        bbc.keyboard.press_return()


def _type_basic_program(beebium) -> None:
    for line in ('10 A%=OPENIN("HTTP://EXAMPLE.COM/DATA.JSON")', 'RUN'):
        _command(beebium, line)


def _decode_open_payload(payload: bytes):
    off = 0
    version = payload[off]
    off += 1
    method = payload[off]
    off += 1
    flags = payload[off]
    off += 1
    url_len = payload[off] | (payload[off + 1] << 8)
    off += 2
    url = payload[off:off + url_len].decode("utf-8")
    return version, method, flags, url


def test_openin_emits_network_open_request(beebium, fuji_device):
    handle = 0x1234

    def responder(pkt):
        if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        return None

    fuji_device.set_responder(responder)

    _type_basic_program(beebium)

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None
    assert open_pkt.checksum_ok
    version, method, flags, url = _decode_open_payload(open_pkt.payload)
    assert version == netp.NETPROTO_VERSION
    assert method == 1
    assert flags == 0x08
    assert url == "HTTP://EXAMPLE.COM/DATA.JSON"


@pytest.mark.skip(reason="fn-rom OSWORD &78 BASIC flows are not yet covered in the beebium harness; current scripted coverage is direct OPENIN only")
def test_network_device_round_trip_placeholder():
    pass

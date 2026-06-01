from __future__ import annotations

import pytest

from fujinet_tools import netproto as netp

from fuji_device import build_network_open_response


def _command(bbc, text: str) -> None:
    bbc.keyboard.type(text)
    bbc.keyboard.press_return()


def _type_basic_program(beebium) -> None:
    for line in ('10 A%=OPENIN("HTTP://EXAMPLE.COM/DATA.JSON")', 'RUN'):
        _command(beebium, line)


def test_openin_emits_network_open_request(beebium, fuji_device):
    handle = 0x1234

    def responder(pkt):
        if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        return None

    fuji_device.set_responder(responder)

    _type_basic_program(beebium)
    _command(beebium, 'RUN')

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None
    assert open_pkt.checksum_ok
    assert open_pkt.payload == netp.build_open_req(
        method=1,
        flags=0x08,
        url="HTTP://EXAMPLE.COM/DATA.JSON",
    )


@pytest.mark.skip(reason="fn-rom currently has no stable scripted Network round-trip beyond OPEN in the beebium harness")
def test_network_device_round_trip_placeholder():
    pass

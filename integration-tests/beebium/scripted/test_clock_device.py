from __future__ import annotations

import struct

import pytest

from fujinet_tools import fujibus as fb

from helpers import run_basic_program, wait_for_screen_text

pytestmark = pytest.mark.needs_net


CLOCK_DEVICE_ID = 0x45
CMD_CLOCK_GET = 0x01
CLOCK_VERSION = 0x01


def _run_clock_get_basic(beebium):
    run_basic_program(
        beebium,
        [
            "10 DIM B% 16,R% 32",
            "20 B%?0=6:B%?2=&45:B%?3=&01",
            "30 B%?5=0:B%?6=0:B%?7=0:B%?8=0",
            "40 B%?9=R% MOD 256:B%?10=R% DIV 256:B%?11=32:B%?12=0",
            "50 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1",
            '60 PRINT "S=";B%?0;" DS=";B%?4;" L=";B%?13+(B%?14*256);" V=";R%?0;" T=";R%?4;" ";R%?5;" ";R%?6;" ";R%?7',
        ],
    )


def test_osword78_reason06_clock_get_with_mock_fuji(beebium, fuji_device):
    unix_time = 1704067200
    response_body = bytes([CLOCK_VERSION, 0, 0, 0]) + struct.pack("<Q", unix_time)

    def responder(pkt):
        if pkt.device == CLOCK_DEVICE_ID and pkt.command == CMD_CLOCK_GET:
            return fb.build_fuji_response_wire(CLOCK_DEVICE_ID, CMD_CLOCK_GET, 0, response_body)
        return None

    fuji_device.set_responder(responder)

    _run_clock_get_basic(beebium)

    pkt = fuji_device.wait_for_command(CLOCK_DEVICE_ID, CMD_CLOCK_GET, timeout=8.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == b""

    wait_for_screen_text(beebium, "S=0 DS=0 L=12 V=1 T=128 0 146 101", timeout=8.0)

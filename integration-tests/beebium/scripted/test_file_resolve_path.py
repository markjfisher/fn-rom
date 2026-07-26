from __future__ import annotations

import struct

import pytest

from fujinet_tools import fujibus as fb
from helpers import run_basic_program, wait_for_screen_text

pytestmark = pytest.mark.needs_net

FILE_DEVICE_ID = 0xFE
CMD_RESOLVE_PATH = 0x05


def _resolve_payload(base: str, arg: str) -> bytes:
    base_b = base.encode("utf-8")
    arg_b = arg.encode("utf-8")
    return bytes([1]) + struct.pack("<H", len(base_b)) + base_b + struct.pack("<H", len(arg_b)) + arg_b


def _resolve_response(resolved: str, display: str, flags: int = 0x02) -> bytes:
    resolved_b = resolved.encode("utf-8")
    display_b = display.encode("utf-8")
    return bytes([1, flags, 0, 0]) + struct.pack("<H", len(resolved_b)) + resolved_b + struct.pack("<H", len(display_b)) + display_b


def test_osword78_reason06_device_call_resolve_path_round_trip(beebium, fuji_device):
    def responder(pkt):
        if pkt.device == FILE_DEVICE_ID and pkt.command == CMD_RESOLVE_PATH:
            return fb.build_fuji_response_wire(
                FILE_DEVICE_ID,
                CMD_RESOLVE_PATH,
                0,
                _resolve_response("tnfs://192.168.1.101/bbc/bwc.ssd", "/bbc/bwc.ssd"),
            )
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            "10 DIM B% 16,Q% 64,R% 96",
            '20 A$="tnfs://192.168.1.101/bbc/":B$="bwc.ssd"',
            "30 Q%?0=1:Q%?1=LEN(A$):Q%?2=0",
            "40 FOR I%=1 TO LEN(A$):Q%?(2+I%)=ASC(MID$(A$,I%,1)):NEXT",
            "50 O%=3+LEN(A$):Q%?O%=LEN(B$):Q%?(O%+1)=0",
            "60 FOR I%=1 TO LEN(B$):Q%?(O%+1+I%)=ASC(MID$(B$,I%,1)):NEXT",
            "70 B%?0=6:B%?2=&FE:B%?3=&05:B%?5=Q% MOD 256:B%?6=Q% DIV 256",
            "80 L%=5+LEN(A$)+LEN(B$):B%?7=L% MOD 256:B%?8=L% DIV 256",
            "90 B%?9=R% MOD 256:B%?10=R% DIV 256:B%?11=96:B%?12=0",
            "100 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1",
            '110 PRINT "S=";B%?0;" DS=";B%?4;" L=";B%?13+(B%?14*256);" V=";R%?0',
        ],
    )

    pkt = fuji_device.wait_for_command(FILE_DEVICE_ID, CMD_RESOLVE_PATH, timeout=8.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == _resolve_payload("tnfs://192.168.1.101/bbc/", "bwc.ssd")

    wait_for_screen_text(beebium, "S=0 DS=0", timeout=8.0)

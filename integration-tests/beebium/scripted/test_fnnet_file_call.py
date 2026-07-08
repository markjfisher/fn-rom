from __future__ import annotations

import struct

import pytest

from fujinet_tools import fileproto as fp
from fujinet_tools import fujibus as fb

from helpers import run_basic_program, wait_for_screen_text

pytestmark = pytest.mark.needs_net


FILE_DEVICE_ID = getattr(fp, "FILE_DEVICE_ID", 0xFE)
CMD_APPSTORE_READ = getattr(fp, "CMD_APPSTORE_READ", 0x21)


def _appstore_prefix(namespace: str, key: str) -> bytes:
    ns = namespace.encode("utf-8")
    key_b = key.encode("utf-8")
    return bytes([1]) + struct.pack("<H", len(ns)) + ns + struct.pack("<H", len(key_b)) + key_b


def test_osword78_reason06_appstore_read_round_trip(beebium, fuji_device):
    response_body = bytes([1, 0x03, 0, 0]) + struct.pack("<I", 0) + struct.pack("<H", 3) + b"bob"

    def responder(pkt):
        if pkt.device == FILE_DEVICE_ID and pkt.command == CMD_APPSTORE_READ:
            return fb.build_fuji_response_wire(FILE_DEVICE_ID, CMD_APPSTORE_READ, 0, response_body)
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            "10 DIM B% 16,Q% 64,R% 64",
            "20 Q%?0=1:Q%?1=2:Q%?2=0:Q%?3=ASC(\"b\"):Q%?4=ASC(\"w\")",
            "30 Q%?5=4:Q%?6=0:Q%?7=ASC(\"n\"):Q%?8=ASC(\"a\"):Q%?9=ASC(\"m\"):Q%?10=ASC(\"e\")",
            "40 Q%?11=0:Q%?12=0:Q%?13=0:Q%?14=0:Q%?15=8:Q%?16=0",
            "50 B%?0=6:B%?2=&21:B%?4=Q% MOD 256:B%?5=Q% DIV 256:B%?6=17:B%?7=0",
            "60 B%?8=R% MOD 256:B%?9=R% DIV 256:B%?10=64:B%?11=0",
            "70 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1",
            '80 PRINT "S=";B%?0;" FS=";B%?3;" L=";B%?12+(B%?13*256);" V=";R%?0;" F=";R%?1;" D=";R%?10',
        ],
    )

    pkt = fuji_device.wait_for_command(FILE_DEVICE_ID, CMD_APPSTORE_READ, timeout=8.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == _appstore_prefix("bw", "name") + struct.pack("<IH", 0, 8)

    wait_for_screen_text(beebium, "S=0 FS=0 L=13 V=1 F=3 D=98", timeout=8.0)

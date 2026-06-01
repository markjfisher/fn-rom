"""Interop smoke tests: fn-rom in Beebium talking to the REAL posix fujinet-nio."""

from __future__ import annotations

import pytest

from helpers import command, run_basic_program


def test_real_fujinet_receives_fdrive(beebium_real, real_fujinet):
    command(beebium_real, "*FDRIVE")

    assert real_fujinet.wait_for_log("dev=0x70 cmd=0xFD", timeout=8.0)
    assert real_fujinet.wait_for_log("send: dev=0x70", timeout=2.0)


def test_real_fujinet_receives_fhost(beebium_real, real_fujinet):
    command(beebium_real, "*FHOST tnfs://example.invalid/bbc/")
    assert real_fujinet.wait_for_log("dev=0xFE cmd=0x05", timeout=8.0)


def test_real_fujinet_receives_fmount(beebium_real, real_fujinet):
    command(beebium_real, "*FMOUNT 0 0")
    assert real_fujinet.wait_for_log("dev=0x70 cmd=0xFB", timeout=8.0)
    assert real_fujinet.wait_for_log("send: dev=0x70", timeout=2.0)


def test_real_fujinet_receives_openin(beebium_real, real_fujinet):
    run_basic_program(beebium_real, ['10 A%=OPENIN("http://example.com/data.json")'])
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x01", timeout=8.0)


def test_real_fujinet_receives_openin_then_fjson(beebium_real, real_fujinet):
    run_basic_program(
        beebium_real,
        [
            '10 H%=OPENIN("http://example.com/data.json")',
            '20 OSCLI "FJSON "+STR$(H%)+" /value"',
            '30 A%=BGET#H%',
            '40 CLOSE#H%',
        ],
    )
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x01", timeout=8.0)
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x07", timeout=8.0), real_fujinet.log_text()[-4000:]
    assert real_fujinet.wait_for_log("send: dev=0xFD status=0 cmd=0x07", timeout=4.0), real_fujinet.log_text()[-4000:]
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x04", timeout=8.0)


def test_real_fujinet_receives_osword78_long_open_url(beebium_real, real_fujinet):
    run_basic_program(
        beebium_real,
        [
            '10 DIM B% 16,C% 512',
            '20 U$="http://example.com/"+STRING$(260,"a")',
            '30 $(C%)=U$+CHR$(0)',
            '40 B%?0=4:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=LEN(U$) MOD 256:B%?5=LEN(U$) DIV 256',
            '50 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '60 H%=OPENIN("://")',
        ],
    )
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x01", timeout=8.0)


def test_real_fujinet_receives_osword78_post_write(beebium_real, real_fujinet):
    run_basic_program(
        beebium_real,
        [
            '10 DIM B% 16,C% 512',
            '20 BODY$="{"+CHR$(34)+"msg"+CHR$(34)+":"+CHR$(34)+"hello"+CHR$(34)+"}"',
            '30 B%?0=1:B%?2=LEN(BODY$):B%?3=0:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '40 B%?0=3:B%?2=1:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '50 H%=OPENUP("http://example.com/anything")',
            '60 $(C%)=BODY$+CHR$(0)',
            '70 B%?0=2:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=LEN(BODY$):B%?5=0:B%?6=H%',
            '80 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '90 CLOSE#H%',
        ],
    )
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x01", timeout=8.0)
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x03", timeout=8.0)
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x04", timeout=8.0)


@pytest.mark.skip(reason="fn-rom currently exposes no Clock device command path")
def test_real_fujinet_clock_unreachable_from_fn_rom():
    pass


@pytest.mark.skip(reason="fn-rom currently exposes no Modem device command path")
def test_real_fujinet_modem_unreachable_from_fn_rom():
    pass


def test_fujinet_created_the_pty(real_fujinet):
    import os

    assert os.path.islink(real_fujinet.pty_path) or os.path.exists(real_fujinet.pty_path)
    assert "Created PTY" in real_fujinet.log_text()

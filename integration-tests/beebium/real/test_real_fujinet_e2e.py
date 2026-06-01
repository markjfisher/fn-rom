"""Interop smoke tests: fn-rom in Beebium talking to the REAL posix fujinet-nio."""

from __future__ import annotations

import re

import pytest

from helpers import command, run_basic_program


def _receive_blocks(log_text: str, dev_hex: str, cmd_hex: str) -> list[str]:
    lines = log_text.splitlines()
    blocks: list[str] = []
    i = 0
    needle = f"dev={dev_hex} cmd={cmd_hex}"
    while i < len(lines):
        line = lines[i]
        if "fujibus: receive:" not in line or needle not in line:
            i += 1
            continue

        block_lines = [line]
        i += 1
        while i < len(lines):
            nxt = lines[i]
            if "fujibus: receive:" in nxt or "fujibus: send:" in nxt:
                break
            if "fujibus:" in nxt or nxt.startswith("  "):
                block_lines.append(nxt)
                i += 1
                continue
            break
        blocks.append("\n".join(block_lines))
    return blocks


def _latest_receive_block(log_text: str, dev_hex: str, cmd_hex: str) -> str:
    blocks = _receive_blocks(log_text, dev_hex, cmd_hex)
    assert blocks, f"no receive block for {dev_hex} {cmd_hex}\n{log_text[-4000:]}"
    return blocks[-1]


def _payload_size(block: str) -> int:
    match = re.search(r"payload=(\d+)", block)
    assert match, block
    return int(match.group(1))


def _payload_bytes(block: str) -> bytes:
    payload = bytearray()
    for line in block.splitlines():
        if "fujibus:" not in line or ":" not in line:
            continue
        after_tag = line.split("fujibus:", 1)[1].strip()
        if not re.match(r"^[0-9a-f]{4}:", after_tag, re.IGNORECASE):
            continue
        hex_part = after_tag.split("|", 1)[0]
        hex_part = hex_part.split(":", 1)[1]
        for chunk in hex_part.split():
            payload.append(int(chunk, 16))
    return bytes(payload)


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
    block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x01")
    assert b"http://example.com/data.json" in _payload_bytes(block)


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
    open_block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x01")
    xlat_block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x07")
    close_block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x04")
    assert b"http://example.com/data.json" in _payload_bytes(open_block)
    assert b"/value" in _payload_bytes(xlat_block)
    assert "payload=3" in close_block


def test_real_fujinet_receives_osword78_long_open_url(beebium_real, real_fujinet):
    run_basic_program(
        beebium_real,
        [
            '10 DIM B% 16,C% 512',
            '20 A$="http://example.com/"',
            '30 B$=STRING$(200,"a")',
            '40 C$=STRING$(80,"b")',
            '50 N%=LEN(A$)',
            '60 $(C%)=A$+CHR$(0)',
            '70 $(C%+N%)=B$',
            '80 $(C%+N%+LEN(B$))=C$',
            '90 L%=N%+LEN(B$)+LEN(C$)',
            '100 B%?0=4:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=L% MOD 256:B%?5=L% DIV 256',
            '110 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '120 H%=OPENIN("://")',
        ],
    )
    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x01", timeout=8.0)
    block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x01")
    payload = _payload_bytes(block)
    assert b"http://example.com/" in payload
    assert _payload_size(block) > 255
    assert payload.count(b"a") > 200, block


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
    open_block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x01")
    write_block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x03")
    close_block = _latest_receive_block(real_fujinet.log_text(), "0xFD", "0x04")
    assert b"http://example.com/anything" in _payload_bytes(open_block)
    assert b'{"msg":"hello"}' in _payload_bytes(write_block)
    assert "payload=3" in close_block


def test_real_fujinet_host_listing_and_mount_catalog_reads(beebium_real_host_tree, real_fujinet_host_tree):
    command(beebium_real_host_tree, "*FHOST host:/")
    command(beebium_real_host_tree, "*FLS")
    command(beebium_real_host_tree, "*FIN 0 foo/bar/weather.ssd")
    command(beebium_real_host_tree, "*FIN 1 foo/baz/iss.ssd")
    command(beebium_real_host_tree, "*FMOUNT 0 0")
    command(beebium_real_host_tree, "*FMOUNT 1 1")
    command(beebium_real_host_tree, "*. :0.$")
    command(beebium_real_host_tree, "*. :1.$")

    log = real_fujinet_host_tree.log_text()
    assert "dev=0xFE cmd=0x05" in log
    assert "dev=0xFE cmd=0x02" in log
    assert log.count("dev=0x70 cmd=0xFC") >= 2, log[-4000:]
    assert log.count("dev=0x70 cmd=0xFB") >= 2, log[-4000:]

    expected_sector_reads = [
        "0000: 01 01 00 00 00 00 00 01",
        "0000: 01 01 01 00 00 00 00 01",
        "0000: 01 02 00 00 00 00 00 01",
        "0000: 01 02 01 00 00 00 00 01",
    ]
    for needle in expected_sector_reads:
        assert needle in log, log[-6000:]


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

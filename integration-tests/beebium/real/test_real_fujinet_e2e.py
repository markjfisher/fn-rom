"""Interop smoke tests: fn-rom in Beebium talking to the REAL posix fujinet-nio."""

from __future__ import annotations

import re

import pytest

from helpers import command, run_basic_program, wait_for_screen_text


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


def _wait_for_receive_payloads(real_fujinet, dev_hex: str, cmd_hex: str, expected_payloads: set[bytes], *, timeout: float = 8.0) -> set[bytes]:
    import time

    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        log = real_fujinet.log_text()
        seen = {_payload_bytes(block) for block in _receive_blocks(log, dev_hex, cmd_hex)}
        if expected_payloads.issubset(seen):
            return seen
        time.sleep(0.1)
    return {_payload_bytes(block) for block in _receive_blocks(real_fujinet.log_text(), dev_hex, cmd_hex)}


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


def test_real_fujinet_osword78_clock_get(beebium_real, real_fujinet):
    run_basic_program(
        beebium_real,
        [
            "10 DIM B% 16,R% 32",
            "20 B%?0=6:B%?2=&45:B%?3=&01",
            "30 B%?5=0:B%?6=0:B%?7=0:B%?8=0",
            "40 B%?9=R% MOD 256:B%?10=R% DIV 256:B%?11=32:B%?12=0",
            "50 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1",
            '60 PRINT "S=";B%?0;" DS=";B%?4;" L=";B%?13+(B%?14*256);" V=";R%?0',
        ],
    )

    wait_for_screen_text(beebium_real, "S=0 DS=0 L=12 V=1", timeout=8.0)
    assert real_fujinet.wait_for_log("dev=0x45 cmd=0x01", timeout=8.0)
    assert real_fujinet.wait_for_log("send: dev=0x45 status=0 cmd=0x01", timeout=4.0), real_fujinet.log_text()[-4000:]


def test_real_fujinet_host_listing_and_mount_catalog_reads(beebium_real_host_tree, real_fujinet_host_tree):
    command(beebium_real_host_tree, "*FHOST host:/")
    command(beebium_real_host_tree, "*FLS")
    command(beebium_real_host_tree, "*FIN 0 foo/bar/weather.ssd")
    command(beebium_real_host_tree, "*FIN 1 foo/baz/iss.ssd")
    command(beebium_real_host_tree, "*FMOUNT 0 0")
    command(beebium_real_host_tree, "*FMOUNT 1 1")
    command(beebium_real_host_tree, "*. :0.$")
    command(beebium_real_host_tree, "*. :1.$")

    expected_payloads = {
        bytes.fromhex("01 01 00 00 00 00 00 01"),
        bytes.fromhex("01 01 01 00 00 00 00 01"),
        bytes.fromhex("01 02 00 00 00 00 00 01"),
        bytes.fromhex("01 02 01 00 00 00 00 01"),
    }
    seen_payloads = _wait_for_receive_payloads(
        real_fujinet_host_tree,
        "0xFC",
        "0x03",
        expected_payloads,
        timeout=8.0,
    )

    log = real_fujinet_host_tree.log_text()
    assert "dev=0xFE cmd=0x05" in log
    assert "dev=0xFE cmd=0x02" in log
    assert log.count("dev=0x70 cmd=0xFC") >= 2, log[-4000:]
    assert log.count("dev=0x70 cmd=0xFB") >= 2, log[-4000:]

    missing = expected_payloads - seen_payloads
    assert not missing, (
        "missing expected catalog sector reads: "
        + ", ".join(payload.hex(" ") for payload in sorted(missing))
        + "\nseen: "
        + ", ".join(payload.hex(" ") for payload in sorted(seen_payloads))
    )


def test_real_fujinet_httpfs_openin_bget_returns_expected_bytes(beebium_real, real_fujinet, http_fs_service):
    url = f'{http_fs_service["base_url"]}/bbc/tests/hello_print_hash.txt'
    run_basic_program(
        beebium_real,
        [
            f'10 H%=OPENIN("{url}")',
            '20 A%=BGET#H%:B%=BGET#H%:C%=BGET#H%:D%=BGET#H%:E%=BGET#H%:F%=BGET#H%:G%=BGET#H%',
            '30 PRINT A%;",";B%;",";CHR$(C%);CHR$(D%);CHR$(E%);CHR$(F%);CHR$(G%)',
            '40 CLOSE#H%',
        ],
    )

    wait_for_screen_text(beebium_real, '0,5,OLLEH', timeout=8.0)
    log = real_fujinet.log_text()
    assert "dev=0xFD cmd=0x01" in log, log[-4000:]
    assert "dev=0xFD cmd=0x02" in log, log[-4000:]
    assert "dev=0xFD cmd=0x04" in log, log[-4000:]
    block = _latest_receive_block(log, "0xFD", "0x01")
    assert b"/bbc/tests/hello_print_hash.txt" in _payload_bytes(block)


def test_real_fujinet_httpfs_two_open_channels_read_independently(beebium_real, real_fujinet, http_fs_service):
    url1 = f'{http_fs_service["base_url"]}/bbc/tests/simple.txt'
    url2 = f'{http_fs_service["base_url"]}/bbc/tests/hello_print_hash.txt'
    run_basic_program(
        beebium_real,
        [
            f'10 A%=OPENIN("{url1}")',
            f'20 B%=OPENIN("{url2}")',
            '30 X%=BGET#A%:Y%=BGET#B%:Z%=BGET#A%:W%=BGET#B%',
            '40 PRINT X%;",";Y%;",";Z%;",";W%',
            '50 CLOSE#A%:CLOSE#B%',
        ],
    )

    # from A: "FujiNet" are first bytes, decimal 70 = F, 117 = u
    # from B: 0x00, 0x05 OLLEH, so first two bytes are 0, 5.
    # so interweved, it's 70,0,117,5
    wait_for_screen_text(beebium_real, '70,0,117,5', timeout=8.0)
    log = real_fujinet.log_text()
    assert log.count("dev=0xFD cmd=0x01") >= 2, log[-6000:]
    open_blocks = _receive_blocks(log, "0xFD", "0x01")
    assert len(open_blocks) >= 2, log[-6000:]
    assert any(b"/bbc/tests/simple.txt" in _payload_bytes(block) for block in open_blocks)
    assert any(b"/bbc/tests/hello_print_hash.txt" in _payload_bytes(block) for block in open_blocks)
    read_blocks = _receive_blocks(log, "0xFD", "0x02")
    assert read_blocks, log[-6000:]


def test_real_fujinet_httpbin_openin_fjson_bget_returns_translated_value(beebium_real, real_fujinet, httpbin_service):
    url = f'{httpbin_service["base_url"]}/get?value=fnrom'
    run_basic_program(
        beebium_real,
        [
            f'10 H%=OPENIN("{url}")',
            '20 OSCLI "FJSON "+STR$(H%)+" /args/value"',
            '30 A%=BGET#H%:B%=BGET#H%:C%=BGET#H%:D%=BGET#H%:E%=BGET#H%',
            '40 PRINT CHR$(A%);CHR$(B%);CHR$(C%);CHR$(D%);CHR$(E%)',
            '50 CLOSE#H%',
        ],
    )

    wait_for_screen_text(beebium_real, 'fnrom', timeout=8.0, case_sensitive=False)
    log = real_fujinet.log_text()
    open_block = _latest_receive_block(log, "0xFD", "0x01")
    xlat_block = _latest_receive_block(log, "0xFD", "0x07")
    read_blocks = _receive_blocks(log, "0xFD", "0x02")
    assert b'/get?value=fnrom' in _payload_bytes(open_block)
    assert b'/args/value' in _payload_bytes(xlat_block)
    assert read_blocks, log[-6000:]


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

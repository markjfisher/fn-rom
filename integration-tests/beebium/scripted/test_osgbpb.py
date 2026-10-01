"""OSGBPB on disc files: every call reads and returns the caller's block.

Each call copies the caller's 13-byte control block into workspace and
writes it back on exit, so the handle, address, length and pointer the
caller sees afterwards are checked along with the bytes moved.
"""
from __future__ import annotations

import re

from helpers import command, run_basic_program, wait_for_screen_text
from scripted.test_file_tail_reads import (  # noqa: F401  (fixture)
    DATA,
    FILE_LEN,
    LOAD_ADDR,
    PRIMED,
    SENTINEL,
    _mount,
    _prime,
    tail_disk,
)

COPY_ADDR = 0x4000


def _osgbpb(beebium, call: int, *, handle: str, addr: int, length: int,
            ptr: int, before=(), after=()) -> tuple[int, int, int]:
    """Run OSGBPB `call` from BASIC; return the block's (address, L, P) after."""
    lines = ["10 DIM B% 13", *before,
             f"30 ?B%={handle}:B%!1=&{addr:X}:B%!5={length}:B%!9={ptr}",
             f"40 A%={call}:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFD1",
             *after,
             '90 PRINT "GB";"DONE ";B%!1;" ";B%!5;" ";B%!9']
    run_basic_program(beebium, lines)
    screen = wait_for_screen_text(beebium, "GBDONE", timeout=8.0)
    m = re.search(r"GBDONE (-?\d+) (-?\d+) (-?\d+)", screen)
    assert m, screen
    return int(m[1]), int(m[2]), int(m[3])


def _memory(beebium, addr: int, length: int) -> bytes:
    return beebium.memory.address.bus.read(addr, length)


def _assert_read(beebium, want: bytes, addr: int = LOAD_ADDR) -> None:
    got = _memory(beebium, addr, PRIMED)
    bad = [i for i in range(len(want)) if got[i] != want[i]]
    assert not bad, f"{len(bad)} byte(s) wrong, first at offset {bad[0]}"
    assert set(got[len(want):]) == {SENTINEL}, "bytes after the transfer overwritten"


def test_osgbpb_3_reads_from_the_given_pointer_mid_file(
    beebium, fuji_device, tail_disk
):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)
    addr, left, ptr = _osgbpb(
        beebium, 3, handle="H%", addr=LOAD_ADDR, length=FILE_LEN - 10, ptr=10,
        before=['20 H%=OPENIN("DATA")'], after=["50 CLOSE#H%"],
    )
    assert (addr, left, ptr) == (LOAD_ADDR + FILE_LEN - 10, 0, FILE_LEN)
    _assert_read(beebium, DATA[10:])


def test_osgbpb_4_reads_from_the_current_pointer(beebium, fuji_device, tail_disk):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)
    addr, left, ptr = _osgbpb(
        beebium, 4, handle="H%", addr=LOAD_ADDR, length=FILE_LEN - 10, ptr=0,
        before=['20 H%=OPENIN("DATA"):PTR#H%=10'],
        after=['50 PRINT "PTR";PTR#H%:CLOSE#H%'],
    )
    assert (addr, left, ptr) == (LOAD_ADDR + FILE_LEN - 10, 0, FILE_LEN)
    wait_for_screen_text(beebium, f"PTR{FILE_LEN}", timeout=2.0)
    _assert_read(beebium, DATA[10:])


def test_osgbpb_read_past_the_end_reports_what_is_left(
    beebium, fuji_device, tail_disk
):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)
    addr, left, ptr = _osgbpb(
        beebium, 3, handle="H%", addr=LOAD_ADDR, length=FILE_LEN + 100, ptr=0,
        before=['20 H%=OPENIN("DATA")'], after=["50 CLOSE#H%"],
    )
    assert (addr, left, ptr) == (LOAD_ADDR + FILE_LEN, 100, FILE_LEN)
    _assert_read(beebium, DATA)


def test_osgbpb_2_writes_a_file_that_loads_back(beebium, fuji_device, tail_disk):
    _mount(beebium, fuji_device, tail_disk)
    beebium.memory.address.bus.write(LOAD_ADDR, DATA)
    addr, left, _ = _osgbpb(
        beebium, 2, handle="H%", addr=LOAD_ADDR, length=FILE_LEN, ptr=0,
        before=['20 H%=OPENOUT("OUT")'],
        after=['50 PRINT "EXT";EXT#H%:CLOSE#H%'],
    )
    assert (addr, left) == (LOAD_ADDR + FILE_LEN, 0)
    wait_for_screen_text(beebium, f"EXT{FILE_LEN}", timeout=2.0)

    beebium.memory.address.bus.write(COPY_ADDR, bytes([SENTINEL]) * PRIMED)
    command(beebium, f"*LOAD OUT {COPY_ADDR:X}")
    _assert_read(beebium, DATA, COPY_ADDR)


def test_osgbpb_5_reads_the_disc_title(beebium, fuji_device, tail_disk):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)
    _osgbpb(beebium, 5, handle="0", addr=LOAD_ADDR, length=0, ptr=0)
    got = _memory(beebium, LOAD_ADDR, 16)
    assert got[0] == 12, got.hex()
    assert got[1:13].rstrip(b"\0 ") == b"TAIL", got.hex()
    assert got[14] == 0, "drive 0"


def test_osgbpb_8_reads_the_directory_filenames(beebium, fuji_device, tail_disk):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)
    _, left, _ = _osgbpb(beebium, 8, handle="0", addr=LOAD_ADDR, length=1, ptr=0)
    assert left == 0
    got = _memory(beebium, LOAD_ADDR, 9)
    assert got[0] == 7 and got[1:8] == b"DATA   ", got.hex()
    assert got[8] == SENTINEL

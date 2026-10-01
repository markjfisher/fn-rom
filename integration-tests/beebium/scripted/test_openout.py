"""OPENOUT creates a new file even when opening it reads the catalogue.

OPENOUT parses the filename through the pointer at &BA/&BB, reads the
catalogue to look the name up, then parses it again to create the file.
The catalogue read goes over FujiBus, whose receive uses &BA/&BB as scratch,
so the transaction must restore them or the second parse reads garbage
("Bad string").
"""
from __future__ import annotations

from helpers import command, run_basic_program, wait_for_screen_text
from scripted.test_file_tail_reads import (  # noqa: F401  (fixture)
    PRIMED,
    SENTINEL,
    _mount,
    tail_disk,
)

COPY_ADDR = 0x4000


def test_openout_creates_a_new_file_that_loads_back(
    beebium, fuji_device, tail_disk
):
    _mount(beebium, fuji_device, tail_disk)
    run_basic_program(beebium, [
        '10 H%=OPENOUT("NEW")',
        "20 FOR I%=0 TO 9:BPUT#H%,65+I%:NEXT",
        "30 CLOSE#H%",
        '40 PRINT "OPEN";"DONE"',
    ])
    screen = wait_for_screen_text(beebium, "OPENDONE", timeout=8.0)
    assert "Bad string" not in screen

    bus = beebium.memory.address.bus
    bus.write(COPY_ADDR, bytes([SENTINEL]) * PRIMED)
    command(beebium, f"*LOAD NEW {COPY_ADDR:X}")
    got = bus.read(COPY_ADDR, 11)
    assert got == b"ABCDEFGHIJ" + bytes([SENTINEL]), got

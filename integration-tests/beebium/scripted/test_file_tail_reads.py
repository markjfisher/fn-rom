"""Reads of whole sectors plus a partial tail deliver every byte.

A 300-byte file is one full sector and a 44-byte tail. The sector read loop
keeps the tail's byte count in aws_tmp14 across sector calls, so anything
that disturbs it between the full sector and the tail shortens the tail.
Every byte of the file differs from its neighbours, and memory around the
load area is primed with a sentinel, so a lost, stale or overrun byte shows.
"""
from __future__ import annotations

import shutil
import subprocess
import time
from pathlib import Path

import pytest

from fuji_device import disk_image_responder
from helpers import command, run_basic_program, wait_for_screen_text
from scripted.test_boot_session import _hard_break

_ROOT = Path(__file__).resolve().parents[3]
_CREATE_SSD = _ROOT / "scripts" / "create_ssd.py"

FILE_LEN = 300
LOAD_ADDR = 0x3000
SENTINEL = 0xA5
PRIMED = 0x200                  # bytes primed from LOAD_ADDR: file + margin
DATA = bytes((i * 7 + 3) % 251 for i in range(FILE_LEN))


@pytest.fixture()
def tail_disk(tmp_path) -> Path:
    if shutil.which("dfstool") is None:
        pytest.skip("dfstool not available in PATH; required to generate SSD fixtures")
    src = tmp_path / "tail"
    src.mkdir()
    (src / "$.DATA").write_bytes(DATA)
    (src / "$.DATA.inf").write_text(f"$.DATA {LOAD_ADDR:06X} {LOAD_ADDR:06X}\n")
    out = tmp_path / "tail.ssd"
    subprocess.run(
        [str(_CREATE_SSD), "-i", str(src), "-o", str(out), "-t", "TAIL"],
        cwd=str(_ROOT),
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return out


def _mount(beebium, fuji_device, disk: Path) -> None:
    fuji_device.set_responder(disk_image_responder(
        image_path=str(disk), catalog_slot=1, uri="sd0:/tail.ssd"
    ))
    _hard_break(beebium)
    command(beebium, "*FMOUNT 1 0")
    command(beebium, "CLS")
    command(beebium, "*CAT")
    wait_for_screen_text(beebium, "DATA", timeout=8.0)


def _prime(beebium) -> None:
    beebium.memory.address.bus.write(LOAD_ADDR, bytes([SENTINEL]) * PRIMED)


def _assert_loaded(beebium) -> None:
    got = beebium.memory.address.bus.read(LOAD_ADDR, PRIMED)
    bad = [i for i in range(FILE_LEN) if got[i] != DATA[i]]
    assert not bad, (
        f"{len(bad)} byte(s) wrong, first at offset {bad[0]} "
        f"(got {got[bad[0]]:#04x}, want {DATA[bad[0]]:#04x})"
    )
    tail = got[FILE_LEN:]
    clobbered = [i for i, b in enumerate(tail) if b != SENTINEL]
    assert not clobbered, (
        f"{len(clobbered)} byte(s) after the file overwritten, "
        f"offsets {FILE_LEN + clobbered[0]}..{FILE_LEN + clobbered[-1]}"
    )


def test_load_of_a_sector_plus_tail_delivers_every_byte(
    beebium, fuji_device, tail_disk
):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)

    command(beebium, f"*LOAD DATA {LOAD_ADDR:X}")
    time.sleep(0.5)

    _assert_loaded(beebium)


def test_osgbpb_read_of_a_sector_plus_tail_delivers_every_byte(
    beebium, fuji_device, tail_disk
):
    _mount(beebium, fuji_device, tail_disk)
    _prime(beebium)

    # OSGBPB 3: read FILE_LEN bytes from PTR 0 into LOAD_ADDR.
    run_basic_program(beebium, [
        "10 DIM B% 13",
        '20 H%=OPENIN("DATA")',
        f"30 ?B%=H%:B%!1=&{LOAD_ADDR:X}:B%!5={FILE_LEN}:B%!9=0",
        "40 A%=3:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFD1",
        "50 CLOSE#H%",
        '60 PRINT "GB";"DONE ";B%!5',
    ])
    screen = wait_for_screen_text(beebium, "GBDONE", timeout=8.0)
    assert "GBDONE 0" in screen, "OSGBPB left bytes untransferred"

    _assert_loaded(beebium)

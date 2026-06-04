"""Phase 4 command-from-disk equivalence (ROM_ROLE_SPLIT_PLAN Appendix C.4 #3).

Runs against the UTILITIES=disk ROM (so *FDRIVE is NOT in the ROM) with the
FN-UTLS.ssd mounted as the library. Typing *FDRIVE must load+run the transient
binary from disk and emit the same Fuji GET_MOUNTS request as the resident
command — proving the disk-loaded utility behaves identically.

Built + run together by scripts/run_fn_utls_test.sh (the binary calls the
resident ROM by absolute address, so the ROM under test must be the exact
UTILITIES=disk build the binary was linked against).
"""
from __future__ import annotations

import os
import pathlib
import time

import pytest

from beebium.screen import dump_screen
from fujinet_tools import fileproto as fp
from fujinet_tools import fujiproto as fuji

from fuji_device import disk_image_responder
from helpers import command

_SSD = pathlib.Path(__file__).resolve().parents[3] / "build" / "FN-UTLS.ssd"

pytestmark = pytest.mark.skipif(
    os.environ.get("FN_UTLS_TEST") != "1" or not _SSD.is_file(),
    reason="needs the UTILITIES=disk ROM + build/FN-UTLS.ssd "
           "(run scripts/run_fn_utls_test.sh)",
)


def test_fdrive_runs_from_library_disk(beebium, fuji_device):
    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(_SSD), fuji_slot=7, drive_slot=4, uri="sd0:/fn-utls.ssd"
        )
    )

    # Mount the utils image as the current drive (0) so the FS *RUN finds the
    # transient command there. (The library-drive *fallback* path itself is
    # verified separately in Phase 3 / service08; here we prove the disk-loaded
    # binary runs and behaves identically.)
    command(beebium, "*FHOST sd0:/")
    command(beebium, "*FIN 7 fn-utls.ssd")
    command(beebium, "*FMOUNT 7 0")
    fuji_device.clear()

    # *FDRIVE is absent from this (UTILITIES=disk) ROM -> service &04 unclaimed
    # -> FS *RUN resolves the file "FDRIVE" (the full typed name) on the mounted
    # drive -> the transient binary runs and drives the Fuji device exactly as
    # the resident command would.
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(
        fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=8.0
    )
    if pkt is None:
        print("SCREEN AFTER *FDRIVE:\n" + dump_screen(beebium.memory))
    assert pkt is not None, "no GET_MOUNTS observed -> *FDRIVE did not run from disk"
    assert pkt.checksum_ok


# Every transient utility on FN-UTLS.ssd, by the command the user types. Proves
# each one *resolves and loads* from the mounted disk (no "Bad command"): the
# matcher leaves service &04 unclaimed, the FS *RUNs the file under the leaf it
# requests (full name, or F-stripped for "F"-prefixed commands), and the binary
# starts. This is the per-command generalisation of the FDRIVE equivalence test.
_ALL_TRANSIENT_COMMANDS = [
    "*FDRIVE", "*FCD", "*FLS", "*FLIST", "*FNEW", "*FOUT", "*FUMOUNT",
    "*COPY", "*DESTROY", "*WIPE", "*TITLE", "*ACCESS", "*RENAME",
    "*VERIFY", "*MAP", "*FORM", "*FREE",
]


@pytest.mark.parametrize("cmd", _ALL_TRANSIENT_COMMANDS)
def test_transient_command_resolves_from_disk(beebium, fuji_device, cmd):
    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(_SSD), fuji_slot=7, drive_slot=4, uri="sd0:/fn-utls.ssd"
        )
    )

    command(beebium, "*FHOST sd0:/")
    command(beebium, "*FIN 7 fn-utls.ssd")
    command(beebium, "*FMOUNT 7 0")

    command(beebium, "CLS")          # fresh screen so we only see this command's output
    command(beebium, cmd)
    command(beebium, "N")            # dismiss any "Go (Y/N)?" confirm prompt
    time.sleep(0.4)

    screen = dump_screen(beebium.memory)
    # "Bad command" = the FS *RUN could not find the file (wrong leaf name).
    # "Bad string"  = the binary loaded but returned badly to BASIC (it ran wrong
    # bytes / corrupted the stack). Either means the disk command did not work.
    for bad in ("Bad command", "Bad string"):
        assert bad not in screen, (
            f"{cmd} did not run cleanly from FN-UTLS.ssd (got {bad!r}):\n{screen}"
        )


def test_transient_command_receives_arguments(beebium, fuji_device):
    """An argument-taking utility loaded from disk must actually *see* its args:
    the wrapper points text_pointer at the *RUN tail. *FCD <path> resolves a
    relative path, so the FILE RESOLVE_PATH frame must carry the typed path."""
    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(_SSD), fuji_slot=7, drive_slot=4, uri="sd0:/fn-utls.ssd"
        )
    )
    command(beebium, "*FHOST sd0:/")
    command(beebium, "*FIN 7 fn-utls.ssd")
    command(beebium, "*FMOUNT 7 0")
    fuji_device.clear()

    command(beebium, "*FCD bbc")

    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=8.0
    )
    assert pkt is not None, "*FCD bbc did not emit RESOLVE_PATH from disk"
    assert pkt.checksum_ok
    assert b"bbc" in bytes(pkt.payload), (
        f"RESOLVE_PATH payload missing the typed arg 'bbc': {bytes(pkt.payload)!r}"
    )

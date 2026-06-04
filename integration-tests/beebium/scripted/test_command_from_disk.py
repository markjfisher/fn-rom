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

import pytest

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
    # -> FS *RUN resolves "DRIVE" on the library drive -> the transient binary
    # runs and drives the Fuji device exactly as the resident command would.
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(
        fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=8.0
    )
    assert pkt is not None, "no GET_MOUNTS observed -> *FDRIVE did not run from disk"
    assert pkt.checksum_ok

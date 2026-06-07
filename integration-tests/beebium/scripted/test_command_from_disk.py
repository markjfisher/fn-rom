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
from fujinet_tools import diskproto as dp

from fuji_device import (
    disk_image_responder,
    default_success_responder,
    build_resolve_path_response,
    build_list_response,
    build_get_mount_response,
    build_get_mounts_response,
    build_set_mount_response,
    build_disk_mount_response,
    build_disk_info_response,
    build_disk_read_sector_response,
)
from helpers import command

_BUILD = pathlib.Path(__file__).resolve().parents[3] / "build"
_SSD = _BUILD / "FN-UTLS.ssd"
_OTHER_SSD = _BUILD / "OTHER.ssd"

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


def _two_image_responder(by_host_slot: dict[int, tuple[str, bytes]]):
    """Serve a different DFS image per fujinet host slot.

    fn-rom addresses the Fuji GET_MOUNT by ``fuji_disk_slot`` (the host slot),
    but the Disk MOUNT/INFO/READ_SECTOR slot byte is ``fuji_disk_slot + 1``
    (fujibus_disk.s). Route GET_MOUNT by the host slot and the disk ops by
    host_slot+1 so each BBC drive really sees its own image."""
    uris = {hs: u for hs, (u, _) in by_host_slot.items()}
    images = {hs + 1: img for hs, (_, img) in by_host_slot.items()}
    nsec = {s: max(1, len(b) // 256) for s, b in images.items()}

    def _resp(pkt):
        if pkt.device == fp.FILE_DEVICE_ID:
            if pkt.command == fp.CMD_RESOLVE_PATH:
                return build_resolve_path_response("sd0:/", "sd0:/")
            if pkt.command == fp.CMD_LIST:
                return build_list_response(formatted_text="LISTED\n")
        if pkt.device == fuji.FUJI_DEVICE_ID:
            if pkt.command == fuji.CMD_GET_MOUNT:
                slot = pkt.payload[0]
                return build_get_mount_response(
                    slot=slot, enabled=True, uri=uris.get(slot, "sd0:/"))
            if pkt.command == fuji.CMD_SET_MOUNT:
                return build_set_mount_response()
            if pkt.command == fuji.CMD_GET_MOUNTS:
                return build_get_mounts_response("0: AUTO\n")
        if pkt.device == dp.DISK_DEVICE_ID:
            slot = pkt.payload[1]
            if pkt.command == dp.CMD_MOUNT:
                return build_disk_mount_response(
                    slot=slot, sector_count=nsec.get(slot, 1))
            if pkt.command == dp.CMD_INFO:
                return build_disk_info_response(
                    slot=slot, sector_count=nsec.get(slot, 1))
            if pkt.command == dp.CMD_READ_SECTOR:
                img = images.get(slot, b"")
                lba = int.from_bytes(pkt.payload[2:6], "little")
                maxb = int.from_bytes(pkt.payload[6:8], "little") or 256
                start = lba * 256
                data = img[start:start + min(maxb, 256)]
                if len(data) < 256:
                    data = data + bytes(256 - len(data))
                return build_disk_read_sector_response(slot=slot, lba=lba, data=data)
        return default_success_responder(pkt)

    return _resp


@pytest.mark.skipif(
    not _OTHER_SSD.is_file(),
    reason="needs build/OTHER.ssd (a DFS image without FLS) for the library test",
)
def test_transient_command_resolves_via_library_drive(beebium, fuji_device):
    """The actual *LIB fallback path in cmd_run.s (which the equivalence test
    above explicitly does NOT cover): the *current* drive holds a disk that does
    NOT contain the utility, and the utility resolves from the *library* drive.

    Regression for the bug where the *RUN library fallback re-parsed the filename
    via read_fspba. That re-parse runs the MOS GSREAD loop, which corrupts the
    ROM's zero-page scratch (the command-line source pointer aws_tmp10/11 and
    current_drv at &CD), so the re-parse read a garbage pointer and lost the
    library drive — *LIB was silently ignored. The fix reuses the already-parsed
    fuji_filename_buffer and just re-points at the library drive/dir."""
    fnutls = _SSD.read_bytes()
    other = _OTHER_SSD.read_bytes()
    fuji_device.set_responder(_two_image_responder({
        7: ("sd0:/fn-utls.ssd", fnutls),   # host slot 7 -> fn-utls (has FLS)
        6: ("sd0:/other.ssd", other),      # host slot 6 -> other  (no FLS)
    }))

    command(beebium, "*FHOST sd0:/")
    command(beebium, "*FIN 7 fn-utls.ssd")   # slot 7 -> fn-utls (has FLS)
    command(beebium, "*FIN 6 other.ssd")     # slot 6 -> other  (no FLS)
    command(beebium, "*FMOUNT 7 3")          # drive 3 = utils/library disk
    command(beebium, "*FMOUNT 6 0")          # drive 0 = current app disk (no FLS)
    command(beebium, "*LIB :3")
    command(beebium, "*DRIVE 0")
    fuji_device.clear()

    # *FLS: not in ROM, not on the current drive (0/other.ssd). It must be found
    # via the library (drive 3) and run, emitting a FileService LIST.
    command(beebium, "*FLS")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=8.0)
    if pkt is None:
        print("SCREEN AFTER *FLS:\n" + dump_screen(beebium.memory))
    assert pkt is not None, (
        "*FLS did not resolve via the library drive -> *LIB fallback broken"
    )
    assert pkt.checksum_ok


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

"""Boot-disk transient-command and resident mount-administration tests.

Runs against the product ROM with FN-BOOT.ssd mounted as the library. FDRIVE
is deliberately resident so replacing the boot disk cannot remove the command
needed to inspect active mappings. The remaining transient utilities must still
load and execute from disk.

Built + run together by scripts/run_fn_boot_test.sh (the binary calls the
resident ROM by absolute address, so the ROM under test must be the exact
product build the binary was linked against).
"""
from __future__ import annotations

import os
import pathlib
import time

import pytest

from beebium.client.screen import dump_screen, read_mode7_screen
from fujinet_tools.bbc_dfs import parse_dfs_catalogue_090
from fujinet_tools import fileproto as fp
from fujinet_tools import diskproto as dp

from fuji_device import (
    HOST_CMD_GET_CURRENT,
    HOST_CMD_SET_CURRENT,
    HOST_SERVICE_ID,
    HOST_VERSION,
    FILE_CMD_APPSTORE_WRITE,
    FILE_CMD_APPSTORE_READ,
    FILE_CMD_APPSTORE_DELETE,
    FILE_CMD_SLOT_CATALOG_RANGE,
    FILE_CMD_RESOLVE_PATH,
    _appstore_prefix,
    build_appstore_read_response,
    disk_image_responder,
    default_success_responder,
    build_resolve_path_response,
    build_list_response,
    build_disk_mount_response,
    build_disk_info_response,
    build_disk_read_sector_response,
    build_disk_list_mounts_response,
    host_service_responder,
)
from helpers import command, run_basic_program, wait_for_screen_text

_BUILD = pathlib.Path(__file__).resolve().parents[3] / "build"
_SSD = _BUILD / "FN-BOOT.ssd"
_OTHER_SSD = _BUILD / "OTHER.ssd"

_EXPECTED_BOOT_FILES = {
    "!BOOT",
    "ACCESS",
    "COPY",
    "DESTROY",
    "FCD",
    "FLIST",
    "FLS",
    "FNEW",
    "FORM",
    "FOUT",
    "FREE",
    "FSLOTS",
    "FUMOUNT",
    "MAP",
    "RENAME",
    "TITLE",
    "WIPE",
}

pytestmark = pytest.mark.skipif(
    os.environ.get("FN_BOOT_TEST") != "1" or not _SSD.is_file(),
    reason="needs the product ROM + build/FN-BOOT.ssd "
           "(run scripts/run_fn_boot_test.sh)",
)


def test_resident_fdrive_lists_runtime_mount_after_fls_used_response_buffer(
    beebium, fuji_device
):
    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
        )
    )

    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FLS")
    wait_for_screen_text(beebium, "FN-BOOT", timeout=8.0)
    command(beebium, "CLS")
    fuji_device.clear()

    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_LIST_MOUNTS, timeout=8.0
    )
    if pkt is None:
        print("SCREEN AFTER *FDRIVE:\n" + dump_screen(beebium))
    assert pkt is not None, "resident *FDRIVE did not request runtime mappings"
    assert pkt.checksum_ok
    assert pkt.payload == bytes([
        dp.DISKPROTO_VERSION,
        0x01,       # formatted text
        0, 0,       # all units: first
        0, 0,       # all units: last
        0, 0,       # start index
        220, 0,     # maximum response data
    ])
    screen = wait_for_screen_text(beebium, "0: AUTO sd0:/fn-boot.ssd", timeout=8.0)
    assert "0: AUTO sd0:/fn-boot.ssd" in screen
    assert "FN-BOOT" not in screen


def test_resident_fdrive_empty_runtime_does_not_print_stale_fls_text(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD),
        catalog_slot=7,
                uri="sd0:/fn-boot.ssd",
        formatted_mounts="",
    ))
    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FLS")
    wait_for_screen_text(beebium, "FN-BOOT", timeout=8.0)
    command(beebium, "CLS")
    fuji_device.clear()

    command(beebium, "*FDRIVE")
    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_LIST_MOUNTS, timeout=8.0
    )
    assert pkt is not None
    screen = dump_screen(beebium)
    assert "FN-BOOT" not in screen
    assert "FDRIVE err" not in screen
    assert "Bad program" not in screen


def test_resident_fdrive_survives_replacing_boot_disk_and_lists_new_mappings(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD),
        catalog_slot=7,
                uri="sd0:/fn-boot.ssd",
        available_uris=("sd0:/chuck.ssd", "sd0:/bwc.ssd"),
    ))
    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FIN 1 chuck.ssd")
    command(beebium, "*FIN 2 bwc.ssd")
    command(beebium, "*FMOUNT 1 0")  # replaces the disk that held FN-BOOT
    command(beebium, "*FMOUNT 2 1")
    command(beebium, "CLS")
    fuji_device.clear()

    command(beebium, "*FDRIVE")
    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_LIST_MOUNTS, timeout=8.0
    )
    assert pkt is not None
    assert pkt.checksum_ok
    screen = wait_for_screen_text(beebium, "0: AUTO sd0:/chuck.ssd", timeout=8.0)
    assert "1: AUTO sd0:/bwc.ssd" in screen
    assert "Bad command" not in screen
    assert "Bad program" not in screen


def test_fls_without_current_host_exits_cleanly(beebium, fuji_device):
    host_state = [host_service_responder()]

    def switched_host_service(pkt):
        return host_state[0](pkt)

    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD),
        catalog_slot=7,
                uri="sd0:/fn-boot.ssd",
        inner=switched_host_service,
    ))
    _mount_boot_drive(beebium, fuji_device)

    # Preserve the mounted utility disk and sparse slot data, but expose fresh
    # HostService/AppStore state with no current host.
    host_state[0] = host_service_responder()
    fuji_device.clear()

    command(beebium, "CLS")
    command(beebium, "*FLS")
    screen = wait_for_screen_text(beebium, "No host", timeout=8.0)

    pkt = fuji_device.wait_for_command(
        HOST_SERVICE_ID, HOST_CMD_GET_CURRENT, timeout=8.0
    )
    assert pkt is not None
    assert pkt.payload == bytes([HOST_VERSION])
    assert fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=0.2
    ) is None
    assert "List err" not in screen
    assert "Bad program" not in screen


def test_fnew_creates_image_that_can_be_mounted_and_catalogued(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)
    fuji_device.clear()

    command(beebium, "*FNEW blank.ssd")
    create = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_CREATE, timeout=8.0
    )
    assert create is not None
    assert create.checksum_ok
    assert create.payload == dp.build_create_req(
        uri="blank.ssd",
        img_type=dp.TYPE_SSD,
        sector_size=256,
        sector_count=800,
        overwrite=False,
    )

    command(beebium, "*FIN 8 blank.ssd")
    fuji_device.clear()
    command(beebium, "*FMOUNT 8 1")
    mount = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_MOUNT, timeout=8.0
    )
    assert mount is not None
    assert b"blank.ssd" in mount.payload

    command(beebium, "CLS")
    command(beebium, "*CAT :1")
    screen = dump_screen(beebium)
    assert "No disk" not in screen
    assert "Bad catalogue" not in screen


def test_fout_removes_sparse_slot_so_it_cannot_be_mounted(beebium, fuji_device):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FIN 69 retired.ssd")
    command(beebium, "*FLS")  # leave a different transient binary at its load address
    wait_for_screen_text(beebium, "FN-BOOT", timeout=8.0)
    fuji_device.clear()
    command(beebium, "*FOUT 69")

    delete = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_APPSTORE_DELETE, timeout=8.0
    )
    assert delete is not None
    assert delete.payload == (
        bytes([fp.FILEPROTO_VERSION, 10, 0])
        + b"config-nio"
        + bytes([8, 0])
        + b"slot-069"
    )

    fuji_device.clear()
    command(beebium, "*FMOUNT 69 1")
    read = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_APPSTORE_READ, timeout=8.0
    )
    assert read is not None
    assert b"slot-069" in read.payload
    assert fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_MOUNT, timeout=0.2
    ) is None
    screen = wait_for_screen_text(
        beebium, "No slot", timeout=8.0
    )
    assert "Bad program" not in screen


def test_fumount_unmounts_live_disk_and_drive_becomes_unavailable(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)
    command(beebium, "*FMOUNT 7 1")
    fuji_device.clear()

    command(beebium, "*FUMOUNT 1")
    unmount = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_UNMOUNT, timeout=8.0
    )
    assert unmount is not None
    assert unmount.checksum_ok
    assert unmount.payload == bytes([dp.DISKPROTO_VERSION, 2])

    command(beebium, "CLS")
    command(beebium, "*FDRIVE")
    screen = wait_for_screen_text(
        beebium, "0: AUTO sd0:/fn-boot.ssd", timeout=8.0
    )
    assert "1: AUTO" not in screen

    command(beebium, "CLS")
    command(beebium, "*CAT :1")
    screen = wait_for_screen_text(beebium, "No disk", timeout=8.0)
    assert "Bad program" not in screen


def test_fumount_rejects_invalid_and_unmounted_drives_cleanly(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)
    fuji_device.clear()

    command(beebium, "CLS")
    command(beebium, "*FUMOUNT 5")
    screen = wait_for_screen_text(beebium, "Bad drive", timeout=8.0)
    assert "Bad program" not in screen
    assert fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_UNMOUNT, timeout=0.2
    ) is None

    command(beebium, "CLS")
    command(beebium, "*FUMOUNT 1")
    screen = wait_for_screen_text(beebium, "Not mounted", timeout=8.0)
    assert "Bad program" not in screen
    assert fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_UNMOUNT, timeout=0.2
    ) is None


def _catalogue_entry_from_disk_writes(fuji_device, leaf: str):
    sectors: dict[int, bytes] = {}
    for pkt in fuji_device.requests:
        if pkt.device != dp.DISK_DEVICE_ID or pkt.command != dp.CMD_WRITE_SECTOR:
            continue
        lba = int.from_bytes(pkt.payload[2:6], "little")
        data_len = int.from_bytes(pkt.payload[6:8], "little")
        if lba in (0, 1):
            sectors[lba] = pkt.payload[8:8 + data_len]
    assert sectors.keys() >= {0, 1}, "catalogue sectors were not persisted"
    _, entries = parse_dfs_catalogue_090(
        sector0=sectors[0], sector1=sectors[1]
    )
    return next(entry for entry in entries if entry.name == leaf)


def _info_tokens_for_leaf(beebium, leaf: str) -> list[str]:
    for row in read_mode7_screen(beebium):
        tokens = row.split()
        if tokens and tokens[0].endswith(f".{leaf}"):
            return tokens
    raise AssertionError(f"*INFO did not display {leaf!r}\n{dump_screen(beebium)}")


def test_access_locks_and_unlocks_real_catalogue_entry(beebium, fuji_device):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)

    fuji_device.clear()
    command(beebium, "*ACCESS FLS L")
    assert _catalogue_entry_from_disk_writes(
        fuji_device, "FLS"
    ).locked is True

    command(beebium, "CLS")
    command(beebium, "*INFO FLS")
    locked_info = _info_tokens_for_leaf(beebium, "FLS")
    assert locked_info[1] == "L"

    fuji_device.clear()
    command(beebium, "*ACCESS FLS")
    assert _catalogue_entry_from_disk_writes(
        fuji_device, "FLS"
    ).locked is False

    command(beebium, "CLS")
    command(beebium, "*INFO FLS")
    unlocked_info = _info_tokens_for_leaf(beebium, "FLS")
    assert unlocked_info[1] != "L"


# Every transient utility on FN-BOOT.ssd, by the command the user types. Proves
# each one *resolves and loads* from the mounted disk (no "Bad command"): the
# matcher leaves service &04 unclaimed, the FS *RUNs the file under the leaf it
# requests (full name, or F-stripped for "F"-prefixed commands), and the binary
# starts.
_ALL_TRANSIENT_COMMANDS = [
    ("*FCD", "*FCD"),
    ("*FLS", "*FLS"),
    ("*FLIST", "*FLIST"),
    ("*DESTROY", "*DESTROY FLS"),
    ("*WIPE", "*WIPE FLS"),
    ("*TITLE", "*TITLE TEST"),
    ("*RENAME", "*RENAME FLS FLS"),
    ("*MAP", "*MAP"),
    ("*FORM", "*FORM 40 0"),
    ("*FREE", "*FREE"),
]


def test_fn_boot_catalog_contains_the_transient_utility_set():
    image = _SSD.read_bytes()
    desc, entries = parse_dfs_catalogue_090(sector0=image[:256], sector1=image[256:512])
    names = {entry.name for entry in entries}

    assert desc.title == "FN-BOOT"
    assert names == _EXPECTED_BOOT_FILES
    assert "FBOOT" not in names


def test_fslots_lists_only_populated_slots_in_requested_range(beebium, fuji_device):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FIN 69 games/elite.ssd")
    command(beebium, "CLS")
    command(beebium, "*FSLOTS 64 72")
    screen = wait_for_screen_text(beebium, "69: sd0:/games/elite.ssd", timeout=8.0)
    assert "7: sd0:/fn-boot.ssd" not in screen
    assert "Bad program" not in screen

    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_SLOT_CATALOG_RANGE, timeout=8.0
    )
    assert pkt is not None
    assert pkt.payload == bytes([1, 64, 72, 64, 2, 128, 220, 0])


def test_fslots_empty_catalogue_returns_cleanly(beebium, fuji_device):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FSLOTS")
    screen = dump_screen(beebium)
    assert "Bad string" not in screen
    assert "Bad program" not in screen

    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_SLOT_CATALOG_RANGE, timeout=8.0
    )
    assert pkt is not None
    assert pkt.payload == bytes([1, 0, 255, 0, 2, 128, 220, 0])


def test_fslots_runs_after_fls_and_fin_with_high_slot(beebium, fuji_device):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "*FLS")
    wait_for_screen_text(beebium, "FN-BOOT", timeout=8.0)
    command(beebium, "*FIN 200 chuck.ssd")
    fuji_device.clear()
    command(beebium, "*FSLOTS")

    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_SLOT_CATALOG_RANGE, timeout=8.0
    )
    assert pkt is not None, (
        "*FSLOTS ran a stale transient utility instead of requesting the slot catalogue"
    )
    assert pkt.payload == bytes([1, 0, 255, 0, 2, 128, 220, 0])
    sector_reads = [
        request for request in fuji_device.requests
        if request.device == dp.DISK_DEVICE_ID
        and request.command == dp.CMD_READ_SECTOR
    ]
    assert sector_reads
    read_slots = [request.payload[1] for request in sector_reads]
    assert read_slots == [1] * len(read_slots), (
        "transient utility was read from a catalogue slot left behind by *FIN, "
        f"not runtime DiskDevice slot 0 mapped to BBC drive 0: {read_slots}"
    )
    screen = wait_for_screen_text(beebium, "200: sd0:/chuck.ssd", timeout=8.0)
    assert "Bad program" not in screen


def test_form_recreates_current_slot_uri_and_disk_remains_usable(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)
    fuji_device.clear()

    command(beebium, "*FORM 40 0")
    screen = dump_screen(beebium)
    assert "Format drive 0 as 40 tracks" in screen
    assert "Go (Y/N) ?" in screen

    with beebium.keyboard.text_input():
        beebium.keyboard.type("Y")

    screen = wait_for_screen_text(beebium, "Formatted", timeout=8.0)
    assert "Bad program" not in screen

    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_REINITIALIZE, timeout=8.0
    )
    assert pkt is not None, "*FORM did not reinitialize the mounted disk"
    assert pkt.checksum_ok
    assert pkt.payload == bytes([dp.DISKPROTO_VERSION, 1, 0, 1, 0x90, 0x01, 0, 0])

    command(beebium, "CLS")
    command(beebium, "*CAT")
    screen = dump_screen(beebium)
    assert "BLANK" in screen
    assert "FLS" not in screen

    run_basic_program(beebium, [
        '10 A%=OPENOUT("TEST")',
        '20 PRINT#A%,"OK"',
        "30 CLOSE#A%",
    ])
    command(beebium, "*CAT")
    assert "TEST" in dump_screen(beebium)


def test_form_without_geometry_reports_syntax_and_exits_cleanly(
    beebium, fuji_device
):
    fuji_device.set_responder(disk_image_responder(
        image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
    ))
    _mount_boot_drive(beebium, fuji_device)
    fuji_device.clear()

    command(beebium, "*FORM")
    screen = dump_screen(beebium)
    assert "Syntax: *FORM 40|80 (<drive>)" in screen
    assert "Bad program" not in screen
    assert fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_REINITIALIZE, timeout=0.2
    ) is None


def _answer_confirm_prompt_if_visible(beebium) -> None:
    screen = dump_screen(beebium)
    if "(Y/N)" not in screen:
        return
    with beebium.keyboard.text_input():
        beebium.keyboard.type("N")
    time.sleep(0.2)


def _mount_boot_drive(beebium, fuji_device) -> None:
    command(beebium, "*FHOST sd0:/")
    screen = wait_for_screen_text(beebium, "HOST: sd0:/", timeout=8.0)
    assert "PATH: /" in screen

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=8.0)
    assert pkt is not None, "*FHOST sd0:/ did not send HostService SetCurrent"
    assert pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 5, 0]) + b"sd0:/"

    command(beebium, "*FIN 7 fn-boot.ssd")
    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_APPSTORE_WRITE, timeout=8.0
    )
    assert pkt is not None, "*FIN 7 did not persist AppStore slot 007"
    assert pkt.payload == (
        bytes([fp.FILEPROTO_VERSION, 10, 0])
        + b"config-nio"
        + bytes([8, 0])
        + b"slot-007"
        + bytes(4)
        + bytes([18, 0, 1, 0])
        + b"sd0:/fn-boot.ssd"
    )

    command(beebium, "*FMOUNT 7 0")


@pytest.mark.parametrize(
    "cmd, command_line",
    _ALL_TRANSIENT_COMMANDS,
    ids=[cmd for cmd, _ in _ALL_TRANSIENT_COMMANDS],
)
def test_transient_command_resolves_from_disk(beebium, fuji_device, cmd, command_line):
    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
        )
    )

    _mount_boot_drive(beebium, fuji_device)

    command(beebium, "CLS")          # fresh screen so we only see this command's output
    command(beebium, command_line)
    _answer_confirm_prompt_if_visible(beebium)
    time.sleep(0.4)

    screen = dump_screen(beebium)
    # "Bad command" = the FS *RUN could not find the file (wrong leaf name).
    # "Bad string"  = the binary loaded but returned badly to BASIC (it ran wrong
    # bytes / corrupted the stack). Either means the disk command did not work.
    # "Mistake" / "Bad program" catches the test accidentally feeding text back
    # to BASIC after the transient utility has already returned.
    for bad in ("Bad command", "Bad string", "Mistake", "Bad program"):
        assert bad not in screen, (
            f"{cmd} did not run cleanly from FN-BOOT.ssd (got {bad!r}):\n{screen}"
        )


def _two_image_responder(by_host_slot: dict[int, tuple[str, bytes]]):
    """Serve a different DFS image per fujinet host slot.

    Persist sparse AppStore catalog entries, then bind the URI in each Disk
    MOUNT request to its bounded runtime drive slot so each BBC drive sees the
    selected image independently of the catalog index."""
    images_by_uri = {}
    for uri, image in by_host_slot.values():
        images_by_uri[uri] = image
        images_by_uri[uri.rsplit("/", 1)[-1]] = image
    mounted_images: dict[int, bytes] = {}
    appstore: dict[tuple[str, str], bytes] = {}
    host_resp = host_service_responder(["sd0:/"])

    def _resp(pkt):
        if pkt.device == fp.FILE_DEVICE_ID and pkt.command in (
            FILE_CMD_APPSTORE_READ,
            FILE_CMD_APPSTORE_WRITE,
            FILE_CMD_APPSTORE_DELETE,
        ):
            namespace, key, pos = _appstore_prefix(pkt.payload)
            store_key = (namespace, key)
            if pkt.command == FILE_CMD_APPSTORE_DELETE:
                appstore.pop(store_key, None)
                return default_success_responder(pkt)
            offset = int.from_bytes(pkt.payload[pos:pos + 4], "little")
            if pkt.command == FILE_CMD_APPSTORE_WRITE:
                data_len = int.from_bytes(pkt.payload[pos + 4:pos + 6], "little")
                appstore[store_key] = pkt.payload[pos + 6:pos + 6 + data_len]
                return default_success_responder(pkt)
            return build_appstore_read_response(
                appstore.get(store_key), offset=offset
            )

        host_reply = host_resp(pkt)
        if host_reply is not None:
            return host_reply
        if pkt.device == fp.FILE_DEVICE_ID:
            if pkt.command == FILE_CMD_RESOLVE_PATH:
                return build_resolve_path_response("sd0:/", "sd0:/")
            if pkt.command == fp.CMD_LIST:
                return build_list_response(formatted_text="LISTED\n")
        if pkt.device == dp.DISK_DEVICE_ID:
            if pkt.command == dp.CMD_LIST_MOUNTS:
                return build_disk_list_mounts_response("0: AUTO\n")
            slot = pkt.payload[1]
            if pkt.command == dp.CMD_MOUNT:
                uri_len = pkt.payload[6]
                uri = pkt.payload[8:8 + uri_len].decode("utf-8")
                image = images_by_uri.get(uri, b"")
                mounted_images[slot] = image
                return build_disk_mount_response(
                    slot=slot, sector_count=max(1, len(image) // 256))
            if pkt.command == dp.CMD_INFO:
                image = mounted_images.get(slot, b"")
                return build_disk_info_response(
                    slot=slot, sector_count=max(1, len(image) // 256))
            if pkt.command == dp.CMD_READ_SECTOR:
                img = mounted_images.get(slot, b"")
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
    fnboot = _SSD.read_bytes()
    other = _OTHER_SSD.read_bytes()
    fuji_device.set_responder(_two_image_responder({
        7: ("sd0:/fn-boot.ssd", fnboot),   # host slot 7 -> fn-boot (has FLS)
        6: ("sd0:/other.ssd", other),      # host slot 6 -> other  (no FLS)
    }))

    command(beebium, "*FHOST sd0:/")
    command(beebium, "*FIN 7 fn-boot.ssd")   # slot 7 -> fn-boot (has FLS)
    command(beebium, "*FIN 6 other.ssd")     # slot 6 -> other  (no FLS)
    command(beebium, "*FMOUNT 7 3")          # drive 3 = boot/library disk
    command(beebium, "*FMOUNT 6 0")          # drive 0 = current app disk (no FLS)
    command(beebium, "*LIB :3")
    command(beebium, "*DRIVE 0")
    fuji_device.clear()

    # *FLS: not in ROM, not on the current drive (0/other.ssd). It must be found
    # via the library (drive 3) and run, emitting a FileService LIST.
    command(beebium, "*FLS")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=8.0)
    if pkt is None:
        print("SCREEN AFTER *FLS:\n" + dump_screen(beebium))
    assert pkt is not None, (
        "*FLS did not resolve via the library drive -> *LIB fallback broken"
    )
    assert pkt.checksum_ok


@pytest.mark.skipif(
    not _OTHER_SSD.is_file(),
    reason="needs build/OTHER.ssd (a DFS image without FLS) for the library test",
)
def test_transient_command_resolves_via_library_drive_when_current_drive_unmounted(
    beebium, fuji_device
):
    """If the current drive is unmounted, *LIB must still be able to resolve a
    transient command from its own mounted drive.

    Regression for the remaining bug where the initial current-drive lookup tried
    to load drive 0's catalog and threw "No disk" before cmd_run.s ever reached
    the library fallback."""
    fnboot = _SSD.read_bytes()
    fuji_device.set_responder(_two_image_responder({
        7: ("sd0:/fn-boot.ssd", fnboot),   # host slot 7 -> fn-boot (has FLS)
    }))

    command(beebium, "*FHOST sd0:/")
    command(beebium, "*FIN 7 fn-boot.ssd")   # slot 7 -> fn-boot (has FLS)
    command(beebium, "*FMOUNT 7 3")          # drive 3 = boot/library disk
    command(beebium, "*LIB :3")
    command(beebium, "*DRIVE 0")             # current drive remains unmounted
    fuji_device.clear()

    command(beebium, "*FLS")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=8.0)
    if pkt is None:
        print("SCREEN AFTER *FLS ON UNMOUNTED DRIVE 0:\n" + dump_screen(beebium))
    assert pkt is not None, (
        "*FLS did not resolve via the library drive when the current drive was "
        "unmounted"
    )
    assert pkt.checksum_ok


def test_transient_fcd_receives_argument_and_updates_current_host(
    beebium, fuji_device
):
    """FCD loaded from FN-BOOT must receive its *RUN tail and update HostService.

    FIN/FMOUNT are setup only: they make the transient binary available to the
    filing system. FCD itself is verified solely through HostService."""
    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(_SSD), catalog_slot=7, uri="sd0:/fn-boot.ssd"
        )
    )
    _mount_boot_drive(beebium, fuji_device)
    fuji_device.clear()

    command(beebium, "*FCD bbc")

    pkt = fuji_device.wait_for_command(
        HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=8.0
    )
    assert pkt is not None, "*FCD bbc did not emit HostService SetCurrent from disk"
    assert pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 3, 0]) + b"bbc"

    command(beebium, "*FHOST")
    screen = wait_for_screen_text(beebium, "HOST: sd0:/bbc", timeout=8.0)
    assert "PATH: /bbc" in screen

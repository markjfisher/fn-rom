from __future__ import annotations

import time

import pytest

from beebium.client.screen import dump_screen
from fujinet_tools import fileproto as fp
from fujinet_tools import fujiproto as fuji

from fuji_device import (
    HOST_CMD_DELETE_HISTORY,
    HOST_CMD_LIST_HISTORY,
    HOST_CMD_SELECT_HISTORY,
    HOST_CMD_SET_CURRENT,
    HOST_SERVICE_ID,
    HOST_VERSION,
    file_listing_responder,
    host_service_responder,
)
from helpers import command, wait_for_screen_text


def _parse_host_set_req(payload: bytes) -> str:
    assert payload[0] == HOST_VERSION
    n = payload[1] | (payload[2] << 8)
    return payload[3:3 + n].decode("utf-8")


def _assert_screen_contains(beebium, text: str, *, timeout: float = 8.0, screen_evidence=None) -> None:
    try:
        wait_for_screen_text(
            beebium,
            text,
            timeout=timeout,
            evidence=screen_evidence,
            label=f"contains {text}",
        )
    except TimeoutError as exc:
        raise AssertionError(f"{exc}\nSCREEN:\n{dump_screen(beebium)}") from exc


def test_fhost_screen_text_and_wire_payload_case(beebium, fuji_device):
    typed = "*FHOST tnfs://x/bbc/"
    fuji_device.set_responder(host_service_responder())

    with beebium.keyboard.text_input():
        beebium.keyboard.type(typed)

        deadline = time.monotonic() + 10.0
        screen = ""
        while time.monotonic() < deadline:
            screen = dump_screen(beebium)
            if "tnfs://x/bbc/" in screen:
                break
            time.sleep(0.02)

        assert "tnfs://x/bbc/" in screen, screen
        assert "TNFS://X/BBC/" not in screen, screen

        beebium.keyboard.press_return()

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert _parse_host_set_req(pkt.payload) == "tnfs://x/bbc/"


def test_help_futils_describes_current_commands(beebium):
    command(beebium, "*HELP FUTILS")
    screen = wait_for_screen_text(beebium, "FHOST", timeout=8.0)

    screen = wait_for_screen_text(beebium, "FBOOT", timeout=8.0)
    assert "FBOOT" in screen
    assert "FFS" in screen
    assert "FHOST" in screen
    assert "(<host>|LIST|n|n D)" in screen


def test_fhost_emits_host_service_set_request(beebium, fuji_device):
    fuji_device.set_responder(host_service_responder())

    command(beebium, "*FHOST tnfs://x/bbc/")
    screen = wait_for_screen_text(beebium, "PATH: /bbc/", timeout=6.0)

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None, "no HostService SetCurrent request observed on the serial/PTY link"
    assert pkt.checksum_ok, "FujiBus checksum mismatch on the emitted frame"
    assert _parse_host_set_req(pkt.payload) == "tnfs://x/bbc/"
    assert "HOST: tnfs://x/bbc/" in screen
    assert "PATH: /bbc/" in screen


def test_fhost_host_history_crd_screen_flow(beebium, fuji_device):
    fuji_device.set_responder(host_service_responder())

    command(beebium, "*FHOST tnfs://x/a")
    screen = wait_for_screen_text(beebium, "PATH: /a", timeout=6.0)
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert _parse_host_set_req(pkt.payload) == "tnfs://x/a"
    assert "HOST: tnfs://x/a" in screen
    assert "PATH: /a" in screen

    fuji_device.clear()
    command(beebium, "*FHOST tnfs://x/b")
    screen = wait_for_screen_text(beebium, "PATH: /b", timeout=6.0)
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert _parse_host_set_req(pkt.payload) == "tnfs://x/b"
    assert "HOST: tnfs://x/b" in screen
    assert "PATH: /b" in screen

    fuji_device.clear()
    command(beebium, "*FHOST list")
    screen = wait_for_screen_text(beebium, "1 tnfs://x/a", timeout=6.0)
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_LIST_HISTORY, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 0, 0, 255, 0])
    assert "0 tnfs://x/b" in screen
    assert "1 tnfs://x/a" in screen

    fuji_device.clear()
    command(beebium, "*FHOST 1")
    screen = wait_for_screen_text(beebium, "PATH: /a", timeout=6.0)
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SELECT_HISTORY, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 1])
    assert "HOST: tnfs://x/a" in screen
    assert "PATH: /a" in screen

    fuji_device.clear()
    command(beebium, "*FHOST 0 D")
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_DELETE_HISTORY, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 0])


@pytest.mark.needs_boot_utils_setup
def test_fdrive_emits_fuji_get_mounts_request(beebium, fuji_device):
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=6.0)
    assert pkt is not None, "no GET_MOUNTS request observed for *FDRIVE"
    assert pkt.checksum_ok


@pytest.mark.needs_boot_utils_setup
def test_fhost_then_fls_round_trip(beebium, fuji_device):
    listing = "A.$.BOOT\nA.$.GAMES\n"
    fuji_device.set_responder(file_listing_responder(
        resolved_uri="tnfs://x/bbc/",
        display_path="bbc/",
        formatted_text=listing,
    ))

    command(beebium, "*FHOST tnfs://x/bbc/")
    assert fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FLS")
    screen = wait_for_screen_text(beebium, "A.$.GAMES", timeout=6.0)

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert "A.$.BOOT" in screen
    assert "List err" not in screen

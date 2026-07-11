from __future__ import annotations

import time

import pytest

from beebium.screen import dump_screen
from fujinet_tools import fileproto as fp
from fujinet_tools import fujiproto as fuji

from fuji_device import (
    HOST_CMD_DELETE_HISTORY,
    HOST_CMD_LIST_HISTORY,
    HOST_CMD_SELECT_HISTORY,
    HOST_CMD_SET_CURRENT,
    HOST_SERVICE_ID,
    HOST_VERSION,
    host_service_responder,
    resolving_responder,
)
from helpers import command, wait_for_screen_text


def _parse_host_set_req(payload: bytes) -> str:
    assert payload[0] == HOST_VERSION
    n = payload[1] | (payload[2] << 8)
    return payload[3:3 + n].decode("utf-8")


def _assert_screen_contains(beebium, text: str, *, timeout: float = 8.0) -> None:
    try:
        wait_for_screen_text(beebium, text, timeout=timeout)
    except TimeoutError as exc:
        raise AssertionError(f"{exc}\nSCREEN:\n{dump_screen(beebium)}") from exc


def test_fhost_screen_text_and_wire_payload_case(beebium, fuji_device):
    typed = "*FHOST tnfs://example.invalid/bbc/"
    fuji_device.set_responder(host_service_responder())

    with beebium.keyboard.text_input():
        beebium.keyboard.type(typed)

        deadline = time.monotonic() + 10.0
        screen = ""
        while time.monotonic() < deadline:
            screen = dump_screen(beebium)
            if "tnfs://example.invalid/bbc/" in screen:
                break
            time.sleep(0.02)

        assert "tnfs://example.invalid/bbc/" in screen, screen
        assert "TNFS://EXAMPLE.INVALID/BBC/" not in screen, screen

        beebium.keyboard.press_return()

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok
    assert _parse_host_set_req(pkt.payload) == "tnfs://example.invalid/bbc/"


def test_fhost_emits_host_service_set_request(beebium, fuji_device):
    fuji_device.set_responder(host_service_responder())

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)
    assert pkt is not None, "no HostService SetCurrent request observed on the serial/PTY link"
    assert pkt.checksum_ok, "FujiBus checksum mismatch on the emitted frame"
    assert _parse_host_set_req(pkt.payload) == "tnfs://example.invalid/bbc/"
    _assert_screen_contains(beebium, "HOST: tnfs://example.invalid/bbc/", timeout=8.0)
    _assert_screen_contains(beebium, "PATH: /bbc/", timeout=8.0)


def test_fhost_host_history_crd_screen_flow(beebium, fuji_device):
    fuji_device.set_responder(host_service_responder())

    command(beebium, "*FHOST tnfs://example.invalid/a")
    _assert_screen_contains(beebium, "HOST: tnfs://example.invalid/a", timeout=8.0)
    command(beebium, "*FHOST tnfs://example.invalid/b")
    _assert_screen_contains(beebium, "HOST: tnfs://example.invalid/b", timeout=8.0)

    command(beebium, "CLS")
    command(beebium, "*FHOST list")
    _assert_screen_contains(beebium, "0 tnfs://example.invalid/b", timeout=8.0)
    _assert_screen_contains(beebium, "1 tnfs://example.invalid/a", timeout=8.0)

    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_LIST_HISTORY, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok

    fuji_device.clear()
    command(beebium, "CLS")
    command(beebium, "*FHOST 1")
    _assert_screen_contains(beebium, "HOST: tnfs://example.invalid/a", timeout=8.0)
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SELECT_HISTORY, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 1])

    fuji_device.clear()
    command(beebium, "CLS")
    command(beebium, "*FHOST 0 D")
    pkt = fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_DELETE_HISTORY, timeout=6.0)
    assert pkt is not None and pkt.checksum_ok
    assert pkt.payload == bytes([HOST_VERSION, 0])

    command(beebium, "*FHOST")
    _assert_screen_contains(beebium, "HOST: tnfs://example.invalid/a", timeout=8.0)

    command(beebium, "CLS")
    command(beebium, "*FHOST list")
    _assert_screen_contains(beebium, "0 tnfs://example.invalid/b", timeout=8.0)


@pytest.mark.needs_resident_utils
def test_fdrive_emits_fuji_get_mounts_request(beebium, fuji_device):
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=6.0)
    assert pkt is not None, "no GET_MOUNTS request observed for *FDRIVE"
    assert pkt.checksum_ok


@pytest.mark.needs_resident_utils
def test_fhost_then_fls_round_trip(beebium, fuji_device):
    fuji_device.set_responder(resolving_responder("tnfs://example.invalid/bbc/", "bbc/"))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FLS")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)
    assert pkt is not None
    assert pkt.checksum_ok

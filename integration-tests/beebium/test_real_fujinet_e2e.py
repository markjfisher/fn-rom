"""Interop smoke tests: fn-rom in Beebium talking to the REAL posix fujinet-nio.

Topology (see README):

    fujinet-nio (PTY master) ── pty ── beebium (--serial device:) ── fn-rom ── BBC

Unlike ``test_serial_e2e.py`` (which substitutes a scripted ``FujiDevice`` and
asserts exact wire frames -- the deterministic CI gate for the serial/PTY
path), these tests bring up the actual firmware and verify the two interoperate
over the real serial link. They are **opt-in**: they skip unless the fujinet
binary is available (``--fujinet-bin`` / ``FUJINET_BIN``; built with
``./build.sh -cp fujibus-pty-debug`` in the fujinet-nio repo).

These assert on the firmware's own log (it logs ``fujibus: receive: ... dev=..
cmd=..`` for each request and ``fujibus: send: ..`` for each reply on stdout),
which proves the BBC's request actually crossed the serial+PTY link into the
firmware and was answered -- not merely that the keystrokes reached the ROM.

NOTE: a brittler approach would scrape the BBC screen, but the on-screen text
just echoes the typed command and is ROM-version specific. Asserting the
firmware log is the real interop signal.
"""

from __future__ import annotations


def _command(bbc, text: str) -> None:
    bbc.keyboard.type(text)
    bbc.keyboard.press_return()


def test_real_fujinet_receives_fdrive(beebium_real, real_fujinet):
    """``*FDRIVE`` reaches the firmware as a Fuji GET_MOUNTS (0x70/0xFD) request."""
    _command(beebium_real, "*FDRIVE")

    assert real_fujinet.wait_for_log("dev=0x70 cmd=0xFD", timeout=8.0), (
        "firmware never logged a GET_MOUNTS receive for *FDRIVE:\n"
        + real_fujinet.log_text()[-2000:]
    )
    # ...and the firmware replied to the Fuji device over the same link.
    assert real_fujinet.wait_for_log("send: dev=0x70", timeout=2.0), (
        "firmware received the request but logged no reply:\n"
        + real_fujinet.log_text()[-2000:]
    )


def test_real_fujinet_receives_fhost(beebium_real, real_fujinet):
    """``*FHOST <uri>`` reaches the firmware as a FileService RESOLVE_PATH (0xFE/0x05)."""
    _command(beebium_real, "*FHOST tnfs://example.invalid/bbc/")

    assert real_fujinet.wait_for_log("dev=0xFE cmd=0x05", timeout=8.0), (
        "firmware never logged a RESOLVE_PATH receive for *FHOST:\n"
        + real_fujinet.log_text()[-2000:]
    )


def test_real_fujinet_receives_fmount(beebium_real, real_fujinet):
    _command(beebium_real, "*FMOUNT 0 0")

    assert real_fujinet.wait_for_log("dev=0x70 cmd=0xFB", timeout=8.0), (
        "firmware never logged a GET_MOUNT receive for *FMOUNT:\n"
        + real_fujinet.log_text()[-2000:]
    )
    assert real_fujinet.wait_for_log("send: dev=0x70", timeout=2.0), (
        "firmware received the GET_MOUNT request but logged no Fuji reply:\n"
        + real_fujinet.log_text()[-2000:]
    )


def test_real_fujinet_receives_openin(beebium_real, real_fujinet):
    for line in ('10 A%=OPENIN("HTTP://EXAMPLE.COM/DATA.JSON")', 'RUN'):
        _command(beebium_real, line)

    assert real_fujinet.wait_for_log("dev=0xFD cmd=0x01", timeout=8.0), (
        "firmware never logged a Network OPEN receive for OPENIN:\n"
        + real_fujinet.log_text()[-2000:]
    )


import pytest


@pytest.mark.skip(reason="fn-rom OSWORD &78 BASIC flows are not yet covered by the real-firmware beebium harness")
def test_real_fujinet_fnnet_osword78_placeholder():
    pass


@pytest.mark.skip(reason="fn-rom currently exposes no Clock device command path")
def test_real_fujinet_clock_unreachable_from_fn_rom():
    pass


@pytest.mark.skip(reason="fn-rom currently exposes no Modem device command path")
def test_real_fujinet_modem_unreachable_from_fn_rom():
    pass


def test_fujinet_created_the_pty(real_fujinet):
    """Sanity: the firmware created the advertised PTY slave path."""
    import os

    assert os.path.islink(real_fujinet.pty_path) or os.path.exists(real_fujinet.pty_path)
    assert "Created PTY" in real_fujinet.log_text()

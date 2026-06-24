"""Negative tests for the DISK role-split profile (FEATURE_NET=0).

These assert *absence* of network behaviour — the inputs that drive network
traffic on the DISK+NET build must emit no network frames on the DISK build,
and the network-only commands must not exist. See docs/ROM_ROLE_SPLIT_PLAN.md
§6 Phase 3 and Appendix C.4.

Run against a DISK ROM, e.g.:
    make FEATURE_NET=0 all
    FN_PROFILE=disk ./run_pytest.sh scripted/test_disk_profile.py
(or use ./run_profile_tests.sh, which builds both ROMs and runs both subsets).
"""
from __future__ import annotations

import pytest

from fujinet_tools import netproto as netp

from fuji_device import (
    build_network_open_response,
    build_translate_configure_response,
)
from helpers import command, run_basic_program

# Only meaningful on the DISK build; skipped when --fn-profile is 'net'.
pytestmark = pytest.mark.disk_only

# Short timeout: we are proving a frame is *never* sent, so we only need to wait
# long enough that it definitely would have arrived on the DISK+NET build.
_NO_FRAME_TIMEOUT = 3.0


def test_disk_openin_url_emits_no_network_open(beebium, fuji_device):
    """OPENIN of a "scheme://" URL must not open a network channel on DISK.

    The network branch in OSFIND is gated out, so a URL falls through to the
    disk open path (and fails as a bad filename) — but no NETWORK CMD_OPEN frame
    is ever emitted. A responder is armed to prove the absence is real, not a
    device that simply failed to answer.
    """
    def responder(pkt):
        if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=0x1234)
        return None

    fuji_device.set_responder(responder)

    run_basic_program(beebium, ['10 A%=OPENIN("http://example.com/data.json")'])

    open_pkt = fuji_device.wait_for_command(
        netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=_NO_FRAME_TIMEOUT
    )
    assert open_pkt is None, "DISK build must not open a network channel for a URL"


def test_disk_fjson_command_absent(beebium, fuji_device):
    """*FJSON is a network-only command; it must not exist on the DISK build.

    With the command absent from the table, the line is an unrecognised command
    (handled by the FS *RUN fallthrough), so no NETWORK CMD_TRANSLATE_CONFIGURE
    frame is emitted.
    """
    def responder(pkt):
        if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_TRANSLATE_CONFIGURE:
            return build_translate_configure_response(handle=0x1234, translated_size=2)
        return None

    fuji_device.set_responder(responder)

    command(beebium, '*FJSON 0 /value')

    xlat_pkt = fuji_device.wait_for_command(
        netp.NETWORK_DEVICE_ID, netp.CMD_TRANSLATE_CONFIGURE, timeout=_NO_FRAME_TIMEOUT
    )
    assert xlat_pkt is None, "*FJSON must not exist (no translate frame) on the DISK build"

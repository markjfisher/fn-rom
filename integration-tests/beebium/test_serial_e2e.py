"""End-to-end serial + PTY tests: fn-rom under Beebium.

Each test boots a fresh Beebium emulator with the fn-rom image in a sideways
slot and a pseudo-terminal serial transport, types a ``*`` command on the BBC,
and asserts the FujiBus/SLIP request frame the ROM emits on the wire (and, for
the round-trip test, that a follow-up command proceeds once the device replies).

This exercises the whole serial path end to end:
    keyboard -> MOS/OSCLI -> fn-rom command -> FujiBus/SLIP encode
             -> MC6850 ACIA -> Serial ULA -> Beebium PTY -> this test device.
"""

from __future__ import annotations

from fujinet_tools import fileproto as fp
from fujinet_tools import fujiproto as fuji

from fuji_device import resolving_responder


def _command(bbc, text: str) -> None:
    """Type a ``*`` command at the BBC prompt and press RETURN."""
    bbc.keyboard.type(text)
    bbc.keyboard.press_return()


def test_fhost_emits_resolve_path_request(beebium, fuji_device):
    """``*FHOST <uri>`` issues a FileService RESOLVE_PATH carrying the URI."""
    _command(beebium, "*FHOST tnfs://192.168.1.101/bbc/")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0)
    assert pkt is not None, "no RESOLVE_PATH request observed on the serial/PTY link"
    assert pkt.checksum_ok, "FujiBus checksum mismatch on the emitted frame"
    # The ROM upper-cases the command-line URI.
    assert b"TNFS://192.168.1.101/BBC/" in pkt.payload


def test_fdrive_emits_fuji_get_mounts_request(beebium, fuji_device):
    """``*FDRIVE`` queries the Fuji device for its mount table (GET_MOUNTS)."""
    _command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, timeout=6.0)
    assert pkt is not None, "no GET_MOUNTS request observed for *FDRIVE"
    assert pkt.checksum_ok


def test_fhost_then_fls_round_trip(beebium, fuji_device):
    """With RESOLVE_PATH answered, ``*FLS`` issues a FileService LIST request.

    This is the two-way case: the device must reply to ``*FHOST`` before the
    ROM will proceed to ``*FLS``, proving responses flow back over the PTY too.
    """
    fuji_device.set_responder(
        resolving_responder("tnfs://192.168.1.101/bbc/", "bbc/")
    )

    _command(beebium, "*FHOST tnfs://192.168.1.101/bbc/")
    assert fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, timeout=6.0
    ), "host was never resolved"

    fuji_device.clear()
    _command(beebium, "*FLS")

    pkt = fuji_device.wait_for_command(fp.FILE_DEVICE_ID, fp.CMD_LIST, timeout=6.0)
    assert pkt is not None, "no LIST request after *FLS (host not established?)"
    assert pkt.checksum_ok

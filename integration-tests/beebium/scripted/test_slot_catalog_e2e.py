from __future__ import annotations

import pytest

from fujinet_tools import diskproto as dp
from fujinet_tools import fileproto as fp

from fuji_device import (
    FILE_CMD_APPSTORE_WRITE,
    HOST_CMD_SET_CURRENT,
    HOST_SERVICE_ID,
    full_stack_responder,
)
from helpers import command


@pytest.mark.needs_boot_utils_setup
def test_fdrive_requests_formatted_mounts(beebium, fuji_device):
    command(beebium, "*FDRIVE")

    pkt = fuji_device.wait_for_command(
        dp.DISK_DEVICE_ID, dp.CMD_LIST_MOUNTS, timeout=6.0
    )
    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == bytes(
        [dp.DISKPROTO_VERSION, 0x01, 0, 0, 0, 0, 0, 0, 220, 0]
    )


def test_fin_persists_sparse_appstore_slot(beebium, fuji_device):
    fuji_device.set_responder(full_stack_responder(
        resolved_uri="tnfs://example.invalid/bbc/",
        display_path="bbc/",
        mount_slot=0,
    ))

    command(beebium, "*FHOST tnfs://example.invalid/bbc/")
    assert fuji_device.wait_for_command(HOST_SERVICE_ID, HOST_CMD_SET_CURRENT, timeout=6.0)

    fuji_device.clear()
    command(beebium, "*FIN 3 boot.ssd")
    pkt = fuji_device.wait_for_command(
        fp.FILE_DEVICE_ID, FILE_CMD_APPSTORE_WRITE, timeout=6.0
    )

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == (
        bytes([fp.FILEPROTO_VERSION, 10, 0])
        + b"config-nio"
        + bytes([8, 0])
        + b"slot-003"
        + bytes(4)
        + bytes([10, 0, 1, 0])
        + b"boot.ssd"
    )

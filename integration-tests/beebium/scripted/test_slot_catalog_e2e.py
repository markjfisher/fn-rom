from __future__ import annotations

import pytest

from fujinet_tools import diskproto as dp
from fujinet_tools import slotproto as sp

from fuji_device import (
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


def test_fin_puts_sparse_slot_catalog_entry(beebium, fuji_device):
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
        sp.SLOT_CATALOG_DEVICE_ID, sp.CMD_PUT, timeout=6.0
    )

    assert pkt is not None
    assert pkt.checksum_ok
    assert pkt.payload == sp.build_put_req(3, "boot.ssd")

from __future__ import annotations

import pytest


@pytest.mark.skip(reason="fn-rom currently has no BBC command or vector that emits FujiBus traffic to Clock device 0x45")
def test_clock_device_has_no_current_fn_rom_entry_point():
    pass

from __future__ import annotations

import pytest


@pytest.mark.skip(reason="fn-rom currently has no BBC command or vector that emits FujiBus traffic to Modem device 0xFB")
def test_modem_device_has_no_current_fn_rom_entry_point():
    pass

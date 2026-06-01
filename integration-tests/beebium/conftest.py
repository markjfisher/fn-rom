"""pytest configuration for the fn-rom <-> Beebium serial/PTY end-to-end tests.

These tests drive the *real* fn-rom image inside the Beebium BBC emulator, over
the *real* serial + pseudo-terminal path, and observe the FujiBus/SLIP frames
the ROM emits. They are the end-to-end test for the serial transport and the
PTY bridge.

Cross-repo Python wiring
------------------------
Three Python pieces live in three different repositories:

  * the Beebium gRPC client      (in the beebium repo:  clients/python/src)
  * the fujinet_tools package     (in the fujinet-nio repo: py/)  -- SLIP + FujiBus
  * these tests                   (here, in the fn-rom repo)

Rather than installing the first two, we add their source directories to
sys.path (their *third-party* dependencies -- grpcio/protobuf/pyserial -- are
provided by this project's own environment, see pyproject.toml). Locations are
configured by environment variables, each with a sensible default derived from
the conventional sibling-checkout layout:

  BEEBIUM_HOME        beebium repo root        (default: ~/dev/bbc/beebium)
  BEEBIUM_CLIENT_SRC  beebium python src dir   (default: $BEEBIUM_HOME/clients/python/src)
  BEEBIUM_SERVER      beebium-server binary    (default: $BEEBIUM_HOME/build/src/server/beebium-model-b)
  BEEBIUM_MOS         MOS ROM image            (default: $BEEBIUM_HOME/roms/acorn-mos_1_20.rom)
  BEEBIUM_BASIC       BASIC ROM image          (optional)
  FUJINET_TOOLS       dir containing fujinet_tools (default: <fn-rom>/../fujinet-nio/py)
  FN_ROM              sideways ROM image       (default: <fn-rom>/build/fujinet.rom)
  FN_ROM_SLOT         sideways slot for the ROM (default: 12, i.e. slot C)
  FN_PTY              pty symlink path         (default: /tmp/fujinet-pty-e2e)

Any of these can also be overridden on the pytest command line; see
pytest_addoption below.
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import pytest

# --- Resolve repository / tool locations -------------------------------------

_HERE = Path(__file__).resolve()
_FN_ROM_ROOT = _HERE.parents[2]  # integration-tests/beebium/conftest.py -> repo root
_HOME = Path(os.path.expanduser("~"))


def _env_path(name: str, default: Path) -> Path:
    value = os.environ.get(name)
    return Path(value).expanduser() if value else default


BEEBIUM_HOME = _env_path("BEEBIUM_HOME", _HOME / "dev" / "bbc" / "beebium")
BEEBIUM_CLIENT_SRC = _env_path(
    "BEEBIUM_CLIENT_SRC", BEEBIUM_HOME / "clients" / "python" / "src"
)
FUJINET_TOOLS = _env_path(
    "FUJINET_TOOLS", _FN_ROM_ROOT.parent / "fujinet-nio" / "py"
)

# Make the two external packages importable from their source checkouts, and
# this directory (for the local fuji_device helper module).
for _src in (BEEBIUM_CLIENT_SRC, FUJINET_TOOLS, _HERE.parent):
    if _src.is_dir() and str(_src) not in sys.path:
        sys.path.insert(0, str(_src))


# --- pytest command-line options ---------------------------------------------

def pytest_addoption(parser):
    group = parser.getgroup("fn-rom-beebium", "fn-rom Beebium serial/PTY tests")
    group.addoption(
        "--fn-pty",
        action="store",
        default=os.environ.get("FN_PTY", "/tmp/fujinet-pty-e2e"),
        help="PTY symlink path the emulator advertises and the test device opens",
    )
    group.addoption(
        "--fn-rom",
        action="store",
        default=os.environ.get("FN_ROM", str(_FN_ROM_ROOT / "build" / "fujinet.rom")),
        help="fn-rom sideways ROM image to load",
    )
    group.addoption(
        "--fn-rom-slot",
        action="store",
        type=int,
        default=int(os.environ.get("FN_ROM_SLOT", "12")),
        help="sideways slot for the ROM (default 12 = slot C)",
    )
    group.addoption(
        "--beebium-server",
        action="store",
        default=os.environ.get("BEEBIUM_SERVER", str(BEEBIUM_HOME / "build" / "src" / "server" / "beebium-model-b")),
        help="path to the beebium-server executable",
    )
    group.addoption(
        "--beebium-mos",
        action="store",
        default=os.environ.get("BEEBIUM_MOS", str(BEEBIUM_HOME / "roms" / "acorn-mos_1_20.rom")),
        help="path to the MOS ROM image",
    )
    group.addoption(
        "--beebium-basic",
        action="store",
        default=os.environ.get("BEEBIUM_BASIC", ""),
        help="optional path to the BASIC ROM image",
    )
    group.addoption(
        "--fujinet-bin",
        action="store",
        default=os.environ.get(
            "FUJINET_BIN",
            str(FUJINET_TOOLS.parent / "build" / "fujibus-pty-debug" / "fujinet-nio"),
        ),
        help="path to the real posix fujinet-nio binary (fujibus-pty profile) "
        "for the optional real-firmware interop tests",
    )


# --- Fixtures ----------------------------------------------------------------

@pytest.fixture(scope="session")
def beebium_paths(pytestconfig):
    """Resolved, validated paths; skips the suite if anything is missing."""
    server = Path(pytestconfig.getoption("--beebium-server")).expanduser()
    mos = Path(pytestconfig.getoption("--beebium-mos")).expanduser()
    fn_rom = Path(pytestconfig.getoption("--fn-rom")).expanduser()
    basic_opt = pytestconfig.getoption("--beebium-basic")
    basic = Path(basic_opt).expanduser() if basic_opt else None

    if not BEEBIUM_CLIENT_SRC.is_dir():
        pytest.skip(f"Beebium python client not found at {BEEBIUM_CLIENT_SRC} "
                    f"(set BEEBIUM_HOME or BEEBIUM_CLIENT_SRC)")
    if not FUJINET_TOOLS.is_dir():
        pytest.skip(f"fujinet_tools not found at {FUJINET_TOOLS} (set FUJINET_TOOLS)")
    if not server.is_file() or not os.access(server, os.X_OK):
        pytest.skip(f"beebium-server not found/executable at {server} (set BEEBIUM_SERVER)")
    if not mos.is_file():
        pytest.skip(f"MOS ROM not found at {mos} (set BEEBIUM_MOS)")
    if not fn_rom.is_file():
        pytest.skip(f"fn-rom image not found at {fn_rom} -- run `make` (or set FN_ROM)")

    return {
        "server": server,
        "mos": mos,
        "basic": basic,
        "fn_rom": fn_rom,
        "slot": int(pytestconfig.getoption("--fn-rom-slot")),
        "pty": pytestconfig.getoption("--fn-pty"),
    }


import contextlib


@contextlib.contextmanager
def _launch_beebium(beebium_paths, serial_arg):
    """Launch beebium with the fn-rom in its slot and the given --serial arg."""
    from beebium.client import Beebium  # noqa: WPS433 (import after sys.path wiring)

    slot = beebium_paths["slot"]
    extra_args = [
        "--sideways", f"{slot}:rom:{beebium_paths['fn_rom']}",
        "--serial", serial_arg,
    ]
    with Beebium.launch(
        mos_filepath=str(beebium_paths["mos"]),
        basic_filepath=str(beebium_paths["basic"]) if beebium_paths["basic"] else None,
        server_filepath=str(beebium_paths["server"]),
        extra_args=extra_args,
    ) as bbc:
        # Give the MOS a moment to finish booting before we type commands.
        time.sleep(1.0)
        yield bbc


@pytest.fixture()
def beebium(beebium_paths):
    """Beebium with the fn-rom loaded; beebium *creates* the PTY (transport tests).

    Used by the ``fuji_device`` tests, where the test itself plays the device
    role and plugs into the slave beebium publishes. A fresh server per test
    keeps ROM state deterministic.
    """
    with _launch_beebium(beebium_paths, f"pty:{beebium_paths['pty']}") as bbc:
        yield bbc


# --- Real-firmware (interop) fixtures ----------------------------------------

@pytest.fixture()
def real_fujinet(pytestconfig):
    """An isolated, real posix fujinet-nio instance (the PTY master).

    Skips unless the fujinet binary is present (see --fujinet-bin / FUJINET_BIN).
    Each instance runs in its own temp directory with a generated config, so it
    won't clash with a fujinet you are running by hand.
    """
    from fujinet_runner import IsolatedFujinet  # local module

    binary = Path(pytestconfig.getoption("--fujinet-bin")).expanduser()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        pytest.skip(
            f"real fujinet-nio binary not found/executable at {binary} "
            f"(build with `./build.sh -cp fujibus-pty-debug`, or set FUJINET_BIN)"
        )

    fn = IsolatedFujinet(binary)
    fn.start()
    try:
        yield fn
    finally:
        fn.cleanup()


@pytest.fixture()
def beebium_real(beebium_paths, real_fujinet):
    """Beebium plugged into the real fujinet's PTY via ``--serial device:``.

    Topology: fujinet (master) ── pty ── beebium (device:, slave-opener) ── BBC.
    The test observes results via the BBC screen/memory (the PTY is a two-party
    cable owned by fujinet and beebium).
    """
    with _launch_beebium(beebium_paths, f"device:{real_fujinet.pty_path}") as bbc:
        yield bbc


@pytest.fixture()
def fuji_device(beebium, beebium_paths):
    """Open the PTY as the 'device' end and run a background FujiBus responder.

    Yields a :class:`FujiDevice` that records every request frame the ROM emits
    and (by default) answers each with a generic success so multi-step ROM
    flows can proceed. Tests can install a custom responder for protocol-aware
    replies.
    """
    from fuji_device import FujiDevice  # local module in this directory

    dev = FujiDevice(beebium_paths["pty"])
    dev.start()
    try:
        yield dev
    finally:
        dev.close()

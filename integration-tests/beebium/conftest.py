"""pytest configuration for fn-rom Beebium serial/PTY end-to-end tests.

Required environment variables:

  BEEBIUM_HOME       beebium repository root
  FUJINET_NIO_HOME   fujinet-nio repository root

All other paths (server binary, MOS ROM, fujinet_tools, …) are derived
automatically. See docs/DEVELOPMENT.md.
"""

from __future__ import annotations

import contextlib
import datetime as _dt
import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest

from evidence import ScreenEvidenceRecorder
from beebium_test_env import add_fujinet_tools_to_path, ensure_environment

_HERE = Path(__file__).resolve()
_FN_ROM_ROOT = _HERE.parents[2]

ensure_environment()
add_fujinet_tools_to_path()
for _src in (_HERE.parent, _HERE):
    if str(_src) not in sys.path:
        sys.path.insert(0, str(_src))


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
        "--fn-profile",
        action="store",
        choices=("all", "net", "disk"),
        default=os.environ.get("FN_PROFILE", "net"),
        help="role-split build profile the loaded ROM represents",
    )
    group.addoption(
        "--fn-rom-slot",
        action="store",
        type=int,
        default=int(os.environ.get("FN_ROM_SLOT", "12")),
        help="sideways slot for the ROM (default 12 = slot C)",
    )
    group.addoption(
        "--fujinet-bin",
        action="store",
        default=os.environ.get("FUJINET_BIN", ""),
        help="path to the real posix fujinet-nio binary for real/ interop tests",
    )
    group.addoption(
        "--screen-evidence-dir",
        action="store",
        default=os.environ.get("FN_BEEBIUM_EVIDENCE_ROOT", ""),
        help=(
            "directory for Beebium screen evidence "
            "(default: test-evidence/beebium-YYYYMMDD-HHMMSS)"
        ),
    )
    group.addoption(
        "--no-screen-evidence",
        action="store_true",
        default=os.environ.get("FN_BEEBIUM_NO_EVIDENCE", "") in ("1", "true", "yes"),
        help="disable Beebium screen evidence capture",
    )


def pytest_configure(config):
    ensure_environment()
    if not config.getoption("--no-screen-evidence"):
        requested = config.getoption("--screen-evidence-dir")
        if requested:
            evidence_root = Path(requested).expanduser()
        else:
            stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
            evidence_root = _FN_ROM_ROOT / "test-evidence" / f"beebium-{stamp}"
        config._fn_beebium_evidence_root = evidence_root
    config.addinivalue_line(
        "markers", "needs_net: requires the network device (skipped on the DISK profile)"
    )
    config.addinivalue_line(
        "markers", "disk_only: only meaningful on the DISK profile (skipped on net)"
    )
    config.addinivalue_line(
        "markers",
        "needs_resident_utils: requires a management/informational utility to be "
        "resident in the ROM (only the all profile)",
    )


def pytest_collection_modifyitems(config, items):
    profile = config.getoption("--fn-profile")
    utils_resident = profile == "all"
    skip_net = pytest.mark.skip(reason="needs the network device; --fn-profile is 'disk'")
    skip_disk = pytest.mark.skip(reason="DISK-profile test; --fn-profile is 'net'/'all'")
    skip_utils = pytest.mark.skip(
        reason="needs a resident management utility; --fn-profile is not 'all' "
               "(UTILITIES=disk -> utility is transient on FN-UTLS.ssd)"
    )
    for item in items:
        if profile == "disk" and "needs_net" in item.keywords:
            item.add_marker(skip_net)
        if profile != "disk" and "disk_only" in item.keywords:
            item.add_marker(skip_disk)
        if not utils_resident and "needs_resident_utils" in item.keywords:
            item.add_marker(skip_utils)


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    outcome = yield
    setattr(item, "rep_" + call.when, outcome.get_result())


def pytest_report_header(config):
    root = getattr(config, "_fn_beebium_evidence_root", None)
    if root is None:
        return "Beebium screen evidence: disabled"
    return f"Beebium screen evidence: {root}"


@pytest.fixture()
def screen_evidence(pytestconfig, request):
    root = getattr(pytestconfig, "_fn_beebium_evidence_root", None)
    if root is None:
        yield None
        return

    recorder = ScreenEvidenceRecorder(
        root=Path(root),
        profile=pytestconfig.getoption("--fn-profile"),
        nodeid=request.node.nodeid,
    )
    try:
        yield recorder
    finally:
        report = getattr(request.node, "rep_call", None)
        status = report.outcome if report is not None else "unknown"
        recorder.finish(status=status)


@pytest.fixture()
def fn_profile(pytestconfig):
    return pytestconfig.getoption("--fn-profile")


@pytest.fixture(scope="session")
def beebium_paths(pytestconfig):
    server = Path(os.environ["BEEBIUM_SERVER"])
    mos = Path(os.environ["BEEBIUM_MOS"])
    fn_rom = Path(pytestconfig.getoption("--fn-rom")).expanduser()
    basic_opt = os.environ.get("BEEBIUM_BASIC", "")
    basic = Path(basic_opt).expanduser() if basic_opt else None

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


@contextlib.contextmanager
def _launch_beebium(beebium_paths, serial_arg):
    from beebium.client import Beebium

    slot = beebium_paths["slot"]
    extra_args = [
        "--sideways", f"{slot}:rom:{beebium_paths['fn_rom']}",
        "--host-serial", serial_arg,
    ]
    with Beebium.launch(
        mos_filepath=str(beebium_paths["mos"]),
        basic_filepath=str(beebium_paths["basic"]) if beebium_paths["basic"] else None,
        server_filepath=str(beebium_paths["server"]),
        extra_args=extra_args,
    ) as bbc:
        if not bbc.system.wait_for_ready(timeout=5.0):
            raise RuntimeError("Beebium did not report READY within 5 seconds")
        bbc.system.set_speed_multiplier(0.0)
        yield bbc


@pytest.fixture()
def beebium(beebium_paths, screen_evidence):
    with _launch_beebium(beebium_paths, f"mode=pty:path={beebium_paths['pty']}") as bbc:
        _attach_screen_evidence(bbc, screen_evidence)
        try:
            yield bbc
        finally:
            _capture_final_screen_evidence(screen_evidence, bbc)


@pytest.fixture()
def real_fujinet(pytestconfig):
    from fujinet_runner import IsolatedFujinet

    binary_opt = pytestconfig.getoption("--fujinet-bin")
    if not binary_opt:
        pytest.skip("FUJINET_BIN is not set (required for real-firmware interop tests)")

    binary = Path(binary_opt).expanduser()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        pytest.skip(
            f"real fujinet-nio binary not found/executable at {binary} "
            f"(build fujinet-nio or set FUJINET_BIN)"
        )

    fn = IsolatedFujinet(binary)
    fn.start()
    try:
        yield fn
    finally:
        fn.cleanup()


@pytest.fixture()
def real_fujinet_host_tree(pytestconfig):
    from fujinet_runner import IsolatedFujinet

    binary_opt = pytestconfig.getoption("--fujinet-bin")
    if not binary_opt:
        pytest.skip("FUJINET_BIN is not set (required for real-firmware interop tests)")

    binary = Path(binary_opt).expanduser()
    if not binary.is_file() or not os.access(binary, os.X_OK):
        pytest.skip(
            f"real fujinet-nio binary not found/executable at {binary} "
            f"(build fujinet-nio or set FUJINET_BIN)"
        )

    fn = IsolatedFujinet(binary)

    data_root = fn.run_dir / "fujinet-data"
    (data_root / "foo" / "bar").mkdir(parents=True, exist_ok=True)
    (data_root / "foo" / "baz").mkdir(parents=True, exist_ok=True)

    create_ssd = _FN_ROM_ROOT / "scripts" / "create_ssd.py"
    if not create_ssd.is_file():
        pytest.skip(f"SSD generator not found at {create_ssd}")

    beebium_home = Path(os.environ["BEEBIUM_HOME"])
    basictool = shutil.which("basictool")
    if not basictool:
        candidate = (
            beebium_home
            / "integration_tests"
            / "adfs"
            / "src"
            / "adfs_test_support"
            / "basictool.py"
        )
        if candidate.is_file():
            basictool = str(candidate)
    if not basictool:
        pytest.skip(
            "basictool not available in PATH and not found under BEEBIUM_HOME "
            "(integration_tests/adfs/.../basictool.py)"
        )

    dfstool = shutil.which("dfstool")
    if not dfstool:
        pytest.skip("dfstool not available in PATH; required to generate representative SSD images")

    weather_src = _FN_ROM_ROOT / "bas" / "weather"
    iss_src = _FN_ROM_ROOT / "bas" / "iss"
    if not weather_src.is_dir() or not iss_src.is_dir():
        pytest.skip("weather/iss BASIC source trees not found for SSD generation")

    env = os.environ.copy()
    env["PATH"] = f"{Path(basictool).parent}:{env.get('PATH', '')}"
    env["PATH"] = f"{Path(dfstool).parent}:{env['PATH']}"
    if basictool.endswith(".py"):
        shim_dir = fn.run_dir / "tool-shims"
        shim_dir.mkdir(parents=True, exist_ok=True)
        shim = shim_dir / "basictool"
        shim.write_text(f"#!/usr/bin/env bash\nexec python3 \"{basictool}\" \"$@\"\n")
        shim.chmod(0o755)
        env["PATH"] = f"{shim_dir}:{env['PATH']}"

    subprocess.run(
        [str(create_ssd), "-i", str(weather_src), "-o", str(data_root / "foo" / "bar" / "weather.ssd")],
        check=True,
        cwd=str(_FN_ROM_ROOT),
        env=env,
    )
    subprocess.run(
        [str(create_ssd), "-i", str(iss_src), "-o", str(data_root / "foo" / "baz" / "iss.ssd")],
        check=True,
        cwd=str(_FN_ROM_ROOT),
        env=env,
    )

    fn.start()
    try:
        yield fn
    finally:
        fn.cleanup()


@pytest.fixture()
def beebium_real_host_tree(beebium_paths, real_fujinet_host_tree, screen_evidence):
    with _launch_beebium(beebium_paths, f"mode=device:path={real_fujinet_host_tree.pty_path}") as bbc:
        _attach_screen_evidence(bbc, screen_evidence)
        try:
            yield bbc
        finally:
            _capture_final_screen_evidence(screen_evidence, bbc)


def _fujinet_nio_home() -> Path:
    return Path(os.environ["FUJINET_NIO_HOME"])


@pytest.fixture(scope="session")
def http_fs_service():
    port = 18080
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    try:
        if sock.connect_ex(("127.0.0.1", port)) == 0:
            return {"base_url": f"http://127.0.0.1:{port}"}
    finally:
        sock.close()

    fujinet_nio = _fujinet_nio_home()
    script = fujinet_nio / "scripts" / "start_test_services.sh"
    subprocess.run([str(script), "http-fs"], check=True, cwd=str(fujinet_nio))

    deadline = time.monotonic() + 20.0
    while time.monotonic() < deadline:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.5)
        try:
            if sock.connect_ex(("127.0.0.1", port)) == 0:
                return {"base_url": f"http://127.0.0.1:{port}"}
        finally:
            sock.close()
        time.sleep(0.25)

    pytest.skip("http-fs service could not be started on localhost:18080")


@pytest.fixture(scope="session")
def httpbin_service():
    port = 8080
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    try:
        if sock.connect_ex(("127.0.0.1", port)) == 0:
            return {"base_url": f"http://127.0.0.1:{port}"}
    finally:
        sock.close()

    fujinet_nio = _fujinet_nio_home()
    script = fujinet_nio / "scripts" / "start_test_services.sh"
    subprocess.run([str(script), "http"], check=True, cwd=str(fujinet_nio))

    deadline = time.monotonic() + 20.0
    while time.monotonic() < deadline:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.5)
        try:
            if sock.connect_ex(("127.0.0.1", port)) == 0:
                return {"base_url": f"http://127.0.0.1:{port}"}
        finally:
            sock.close()
        time.sleep(0.25)

    pytest.skip("httpbin service could not be started on localhost:8080")


@pytest.fixture()
def beebium_real(beebium_paths, real_fujinet, screen_evidence):
    with _launch_beebium(beebium_paths, f"mode=device:path={real_fujinet.pty_path}") as bbc:
        _attach_screen_evidence(bbc, screen_evidence)
        try:
            yield bbc
        finally:
            _capture_final_screen_evidence(screen_evidence, bbc)


@pytest.fixture()
def fuji_device(beebium, beebium_paths):
    from fuji_device import FujiDevice

    dev = FujiDevice(beebium_paths["pty"])
    dev.start()
    try:
        yield dev
    finally:
        dev.close()


def _capture_final_screen_evidence(screen_evidence, bbc) -> None:
    if screen_evidence is not None:
        screen_evidence.capture(bbc, "final")


def _attach_screen_evidence(bbc, screen_evidence) -> None:
    if screen_evidence is not None:
        setattr(bbc, "_fn_screen_evidence", screen_evidence)

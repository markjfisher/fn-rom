from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

from fuji_device import disk_image_responder, legacy_openbas_network_responder
from yaml_runner import load_suite, run_suite


_FN_ROM_ROOT = Path(__file__).resolve().parents[3]
_STEPS = _FN_ROM_ROOT / "integration-tests" / "steps"

pytestmark = pytest.mark.needs_net

_LEGACY_IP = "192.168.1.101"
_SERVICE_VARS = {
    "HTTP_FS_BASE_URL": "http://127.0.0.1:18080",
    "HTTPBIN_BASE_URL": "http://127.0.0.1:8080",
    "TCP_ECHO_URL": "tcp://127.0.0.1:7777",
}
_SERVICE_VARS["HTTPBIN_GET_URL"] = f"{_SERVICE_VARS['HTTPBIN_BASE_URL']}/get"
_SERVICE_VARS["HTTPBIN_NETLOC"] = _SERVICE_VARS["HTTPBIN_BASE_URL"].split("://", 1)[1]
_SERVICE_VARS["HTTPBIN_GET_LEN"] = str(len(_SERVICE_VARS["HTTPBIN_GET_URL"]))
_SERVICE_VARS["HTTPBIN_NETLOC_LEN"] = str(len(_SERVICE_VARS["HTTPBIN_NETLOC"]))


@pytest.fixture(scope="session")
def legacy_yaml_ssds(tmp_path_factory):
    out = tmp_path_factory.mktemp("legacy-yaml-ssds")
    env = _ssd_tool_env(tmp_path_factory)

    _create_ssd("osfile.ssd", _FN_ROM_ROOT / "bas" / "fs" / "osfile", out, env)
    _create_ssd("osargs.ssd", _FN_ROM_ROOT / "bas" / "fs" / "osargs", out, env)

    return out


@pytest.fixture(scope="session")
def legacy_openbas_ssd(tmp_path_factory):
    out = tmp_path_factory.mktemp("legacy-yaml-openbas-ssd")
    source = tmp_path_factory.mktemp("legacy-yaml-openbas-src")
    shutil.copytree(_FN_ROM_ROOT / "bas" / "fs" / "openbas", source, dirs_exist_ok=True)
    _template_openbas_sources(source)
    _create_ssd("openbas.ssd", source, out, _ssd_tool_env(tmp_path_factory))
    return out


def test_legacy_yaml_osfile(beebium, fuji_device, legacy_yaml_ssds):
    _run_disk_yaml(beebium, fuji_device, legacy_yaml_ssds, "01_osfile.yaml")


def test_legacy_yaml_osargs(beebium, fuji_device, legacy_yaml_ssds):
    _run_disk_yaml(beebium, fuji_device, legacy_yaml_ssds, "02_osargs.yaml")


def test_legacy_yaml_openbas(beebium, fuji_device, legacy_openbas_ssd):
    _run_disk_yaml(
        beebium,
        fuji_device,
        legacy_openbas_ssd,
        "03_open.yaml",
        vars=_SERVICE_VARS,
        inner=_legacy_openbas_network(),
    )


@pytest.mark.needs_boot_utils_setup
def test_legacy_yaml_ctests(beebium, fuji_device, tmp_path):
    cc65_src = os.environ.get("CC65_SRC") or os.environ.get("CC65_HOME")
    if not cc65_src:
        pytest.skip("CC65_SRC/CC65_HOME is required to build c_apps/ctest1")

    subprocess.run(
        [str(_FN_ROM_ROOT / "c_apps" / "create_ctest_ssd.sh")],
        check=True,
        cwd=str(_FN_ROM_ROOT),
        env=os.environ.copy(),
    )
    out = tmp_path / "ctests"
    out.mkdir()
    shutil.copy2(_FN_ROM_ROOT / "build" / "ctests.ssd", out / "ctests.ssd")
    _run_disk_yaml(beebium, fuji_device, out, "04_ctests.yaml")


def test_legacy_yaml_long_strings(beebium, fuji_device, legacy_openbas_ssd):
    _run_disk_yaml(
        beebium,
        fuji_device,
        legacy_openbas_ssd,
        "05_long_str.yaml",
        vars=_SERVICE_VARS,
        inner=_legacy_openbas_network(),
    )


def test_legacy_yaml_json(beebium, fuji_device, legacy_openbas_ssd):
    _run_disk_yaml(
        beebium,
        fuji_device,
        legacy_openbas_ssd,
        "06_json.yaml",
        vars=_SERVICE_VARS,
        inner=_legacy_openbas_network(),
    )


def _run_disk_yaml(
    beebium,
    fuji_device,
    ssd_dir: Path,
    yaml_name: str,
    *,
    vars: dict[str, str] | None = None,
    inner=None,
) -> None:
    suite = load_suite(_STEPS / yaml_name, vars)
    image_path = ssd_dir / suite.disk
    if not image_path.is_file():
        pytest.skip(f"{suite.disk} was not generated")

    fuji_device.set_responder(
        disk_image_responder(
            image_path=str(image_path),
            catalog_slot=7,
                        uri=f"sd0:/{suite.disk}",
            inner=inner,
        )
    )
    run_suite(beebium, suite, fhost="sd0:/", disk_slot=7, drive=0)


def _legacy_openbas_network():
    return legacy_openbas_network_responder(
        http_fs_base_url=_SERVICE_VARS["HTTP_FS_BASE_URL"],
        httpbin_base_url=_SERVICE_VARS["HTTPBIN_BASE_URL"],
        tcp_echo_url=_SERVICE_VARS["TCP_ECHO_URL"],
    )


def _template_openbas_sources(source: Path) -> None:
    replacements = {
        f"http://{_LEGACY_IP}:18080": _SERVICE_VARS["HTTP_FS_BASE_URL"],
        f"http://{_LEGACY_IP}:8080": _SERVICE_VARS["HTTPBIN_BASE_URL"],
        f"tcp://{_LEGACY_IP}:7777": _SERVICE_VARS["TCP_ECHO_URL"],
    }
    for path in source.glob("*.bas"):
        text = path.read_text(encoding="utf-8")
        for old, new in replacements.items():
            text = text.replace(old, new)
        path.write_text(text, encoding="utf-8")


def _create_ssd(name: str, source: Path, out: Path, env: dict[str, str]) -> None:
    subprocess.run(
        [
            str(_FN_ROM_ROOT / "scripts" / "create_ssd.py"),
            "-i",
            str(source),
            "-o",
            str(out / name),
        ],
        check=True,
        cwd=str(_FN_ROM_ROOT),
        env=env,
    )


def _ssd_tool_env(tmp_path_factory) -> dict[str, str]:
    basictool = shutil.which("basictool")
    if not basictool:
        candidate = (
            Path(os.environ["BEEBIUM_HOME"])
            / "integration_tests"
            / "adfs"
            / "src"
            / "adfs_test_support"
            / "basictool.py"
        )
        if candidate.is_file():
            basictool = str(candidate)
    if not basictool:
        pytest.skip("basictool is required to generate legacy YAML SSD images")

    dfstool = shutil.which("dfstool")
    if not dfstool:
        pytest.skip("dfstool is required to generate legacy YAML SSD images")

    env = os.environ.copy()
    env["PATH"] = f"{Path(dfstool).parent}:{env.get('PATH', '')}"
    if basictool.endswith(".py"):
        shim_dir = tmp_path_factory.mktemp("legacy-yaml-tool-shims")
        shim = shim_dir / "basictool"
        shim.write_text(f"#!/usr/bin/env bash\nexec python3 \"{basictool}\" \"$@\"\n")
        shim.chmod(0o755)
        env["PATH"] = f"{shim_dir}:{env['PATH']}"
    else:
        env["PATH"] = f"{Path(basictool).parent}:{env['PATH']}"
    return env

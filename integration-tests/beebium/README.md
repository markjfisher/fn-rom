# fn-rom ↔ Beebium serial/PTY end-to-end tests

For the practical "what do I run?" guide, see [RUNNING_TESTS.md](RUNNING_TESTS.md).
**Setup:** export `BEEBIUM_HOME` and `FUJINET_NIO_HOME`, then run tests —
[docs/DEVELOPMENT.md](../../docs/DEVELOPMENT.md). No separate venv sync step.

These tests run the **real** `fn-rom` image inside the **Beebium** BBC emulator,
over a **real serial + pseudo-terminal** path, and assert the FujiBus/SLIP
frames the ROM emits. They are the end-to-end test for the serial transport and
the PTY bridge.

```
keyboard ─▶ MOS/OSCLI ─▶ fn-rom command ─▶ FujiBus/SLIP encode
         ─▶ MC6850 ACIA ─▶ Serial ULA ─▶ Beebium PTY ─▶ this test (device end)
```

## How the three Python pieces fit together

| Piece | Repo | Role |
|-------|------|------|
| Beebium gRPC client (`beebium`) | beebium | drive the emulator (load ROM, type keys, step) |
| `fujinet_tools` (`fujibus`, `fileproto`, `fujiproto`) | fujinet-nio | SLIP framing + FujiBus encode/decode/parse |
| these tests | fn-rom | the assertions |

The Beebium client is attached automatically by `./run_pytest.sh`
(`uv run --with-editable "$BEEBIUM_HOME/clients/beebium-python-client"`). `fujinet_tools` is
derived from `FUJINET_NIO_HOME/py` and added to `sys.path`.

| Env var | Required | Meaning |
|---------|:--------:|---------|
| `BEEBIUM_HOME` | yes | beebium repo root |
| `FUJINET_NIO_HOME` | yes | fujinet-nio repository root |
| `BEEBIUM_SERVER` | derived | `beebium-model-b` (override if autodetection fails) |
| `BEEBIUM_MOS` | derived | MOS ROM under `$BEEBIUM_HOME/roms/` |
| `BEEBIUM_BASIC` | derived | BASIC ROM (optional) |
| `FUJINET_TOOLS` | derived | parent of `fujinet_tools` (`$FUJINET_NIO_HOME/py`) |
| `FUJINET_BIN` | no | real firmware binary (opt-in `real/` interop tests) |
| `FN_ROM` | no | sideways ROM image (default: `<fn-rom>/build/fujinet.rom`) |
| `FN_ROM_SLOT` | no | sideways slot (default: 12) |
| `FN_PTY` | no | PTY symlink path (default: `/tmp/fujinet-pty-e2e`) |

Pytest options for fn-rom-specific settings: `--fn-pty`, `--fn-rom`,
`--fn-rom-slot`, `--fujinet-bin`. Beebium paths come from env.

## Prerequisites

- Build the fn-rom image: `make` (produces `build/fujinet.rom`).
- Build the beebium server in your beebium checkout (so `beebium-model-b` exists).
- Export `BEEBIUM_HOME` and `FUJINET_NIO_HOME`.
- Python 3.12 or newer for the Beebium Python client.
- [`uv`](https://docs.astral.sh/uv/) installed.

## Running

```bash
cd integration-tests/beebium
./run_pytest.sh -v
```

For common commands and the coverage map, see [RUNNING_TESTS.md](RUNNING_TESTS.md).

`uv` creates an isolated environment from `pyproject.toml` (no system `pip`,
works on PEP 668 distros like Arch). The suite **launches its own** Beebium
server per test (fresh ROM state) and stops it automatically — you do **not**
need a server running beforehand.

Examples with overrides:

```bash
# Different pty path (the "port" the device attaches to)
./run_pytest.sh --fn-pty /tmp/my-fnpty

# A specific ROM build / slot
./run_pytest.sh --fn-rom ../../build/fujinet.rom --fn-rom-slot 12

# Override a derived path when autodetection is wrong
BEEBIUM_SERVER=/path/to/beebium-model-b ./run_pytest.sh
```

### Product ROM coverage

| Marker | Skipped unless | Meaning |
|--------|----------------|---------|
| `needs_net` | never skipped by product build | network OPEN/OSWORD &78 traffic |
| `needs_boot_utils_setup` | FN-BOOT is mounted as library | utility command tests (`*FDRIVE`/`*FLS`/`*FCD`/`*FNEW`/`*FOUT`) covered by the command-from-disk lane |

`run_product_tests.sh` builds the product ROM, runs the normal scripted suite,
then runs the FN-BOOT command-from-disk tests; `../../run_tests.sh` wraps the
whole local gate.

If you want a concise explanation of what each lane covers and why the skip
counts are expected, see [RUNNING_TESTS.md](RUNNING_TESTS.md).

## Two test layers

### 1. Scripted transport/protocol tests (deterministic — the CI gate)

`scripted/` substitutes a scripted `FujiDevice` for the real firmware
and asserts the exact FujiBus/SLIP frames the ROM emits. **Beebium creates the
PTY** here (`--host-serial mode=pty:path=<pty>`) and the test plugs into the slave.

| Test | Command | Asserted frame |
|------|---------|----------------|
| `scripted/test_serial_e2e.py::test_fhost_emits_resolve_path_request` | `*FHOST <uri>` | FileService `RESOLVE_PATH` (0xFE/0x05), URI in payload, checksum OK |
| `scripted/test_serial_e2e.py::test_fdrive_emits_fuji_get_mounts_request` | `*FDRIVE` | Fuji `GET_MOUNTS` (0x70/0xFD), checksum OK |
| `scripted/test_serial_e2e.py::test_fhost_then_fls_round_trip` | `*FHOST` then `*FLS` | RESOLVE_PATH answered by the device, then FileService `LIST` (0xFE/0x02) — proves responses flow back over the PTY |
| `scripted/test_network_device.py::test_openin_bget_close_cycle_emits_open_read_close` | `OPENIN`/`BGET#`/`CLOSE#` | Network `OPEN`, `READ`, `CLOSE` |
| `scripted/test_network_device.py::test_openin_fjson_bget_close_cycle_emits_open_translate_read_close` | `OPENIN`/`*FJSON`/`BGET#`/`CLOSE#` | Network `OPEN`, `TRANSLATE_CONFIGURE`, `READ`, `CLOSE` |
| `scripted/test_network_device.py::test_osword78_reason04_long_url_then_openin_uses_buffered_url` | OSWORD `&78` reason `&04` + `OPENIN("://")` | Network `OPEN` with buffered long URL |
| `scripted/test_network_device.py::test_osword78_reason00_long_json_query_emits_translate_configure` | OSWORD `&78` reason `&00` | Network `TRANSLATE_CONFIGURE` |
| `scripted/test_network_device.py::test_osword78_reason01_02_03_post_flow_emits_open_write_close` | OSWORD `&78` reasons `&01/&02/&03` + `OPENUP` | Network `OPEN`, `WRITE`, `CLOSE` |

The `tnfs://example.invalid/...` URIs used in scripted tests are synthetic. The scripted `FujiDevice` does not connect to a real TNFS server; it only validates the ROM's emitted FujiBus packets and returns protocol-correct replies. The Beebium tests now type commands inside `bbc.keyboard.text_input()` so the BBC's CAPS LOCK startup state does not distort the command line before `fn-rom` sees it, and asserts expect the path casing exactly as typed.

## Device Coverage Matrix

| Device | ID | Scripted transport coverage | Real-firmware interop coverage | Notes |
|--------|----|-----------------------------|-------------------------------|-------|
| Fuji | `0x70` | `scripted/test_fuji_device_e2e.py` (`*FDRIVE`, `*FIN`, `*FOUT`) | `real/test_real_fujinet_e2e.py` (`*FDRIVE`, `*FMOUNT`) | Covers `GET_MOUNTS`, `GET_MOUNT`, `SET_MOUNT` |
| Clock | `0x45` | `scripted/test_clock_device.py` | `real/test_real_fujinet_e2e.py` skip | `fn-rom` currently has no BBC command/vector path to Clock |
| Modem | `0xFB` | `scripted/test_modem_device.py` | `real/test_real_fujinet_e2e.py` skip | `fn-rom` currently has no BBC command/vector path to Modem |
| Disk | `0xFC` | `scripted/test_disk_device.py` (`*FMOUNT`, `*FNEW`, `*FOUT`) | `real/test_real_fujinet_e2e.py` (`*FMOUNT`) | Covers `MOUNT`, `UNMOUNT`, `CREATE`; real interop proves live `MOUNT` |
| Network | `0xFD` | `scripted/test_network_device.py` (`OPENIN`, `OPENIN`/`BGET#`/`CLOSE#`, `OPENIN`/`*FJSON`/`BGET#`/`CLOSE#`, OSWORD `&78` reasons `&00..&04`) | `real/test_real_fujinet_e2e.py` (`OPENIN`, `OPENIN`+`*FJSON`, OSWORD long URL, OSWORD POST/write) | Covers representative chuck/iss/weather-style ROM flows and the `fnnet.s` jump table |
| File | `0xFE` | `scripted/test_file_device.py` (`*FHOST`, `*FCD`, `*FLS`) | `real/test_real_fujinet_e2e.py` (`*FHOST`) | Covers `RESOLVE_PATH`, `LIST` |

### 2. Real-firmware interop tests (opt-in)

`real/` brings up the **actual posix fujinet-nio** and has
beebium talk to it over the real serial link. These skip unless the fujinet
binary is found.

**PTY ownership / topology.** A PTY is a virtual null-modem cable: one side
*creates* it (`posix_openpt`, the "master") and publishes the slave path; the
other side *opens* that path (the slave). It doesn't matter which side creates
it, only that exactly one does. The fujinet-nio firmware is written to be the
creator (it `openpty`s and symlinks the slave to `channel.pty_path`), so here:

```
fujinet-nio (PTY master) ── pty ── beebium (--host-serial mode=device:) ── fn-rom ── BBC
```

beebium *plugs in* with `--host-serial mode=device:path=<pty>` (its open-existing-path mode).
The test drives the BBC and observes results via the screen/memory — it does
**not** open the PTY itself (it's a two-party cable owned by fujinet+beebium).
This is why the transport tests in layer 1 use the opposite convention
(beebium creates, the test plugs in): there's no firmware there to be master.

Each interop test launches its **own isolated fujinet** (`fujinet_runner.py`):
a throwaway temp dir with a generated `fujinet-data/fujinet.yaml`
(`channel.pty_path` set), so it never clashes with a fujinet you run by hand.
Build the firmware with `./build.sh -cp fujibus-pty-debug` (in the fujinet-nio
repo) or point `--fujinet-bin` / `FUJINET_BIN` at the binary.

| Test | Checks |
|------|--------|
| `real/test_real_fujinet_e2e.py::test_real_fujinet_receives_fdrive` | firmware logs a Fuji `GET_MOUNTS` receive (`dev=0x70 cmd=0xFD`) **and** a reply |
| `real/test_real_fujinet_e2e.py::test_real_fujinet_receives_fhost` | firmware logs a FileService `RESOLVE_PATH` receive (`dev=0xFE cmd=0x05`) |
| `real/test_real_fujinet_e2e.py::test_real_fujinet_receives_openin_then_fjson` | firmware logs Network `OPEN`, `TRANSLATE_CONFIGURE`, `READ`, `CLOSE` |
| `real/test_real_fujinet_e2e.py::test_real_fujinet_receives_osword78_long_open_url` | firmware logs Network `OPEN` from OSWORD long-URL path |
| `real/test_real_fujinet_e2e.py::test_real_fujinet_receives_osword78_post_write` | firmware logs Network `OPEN`, `WRITE`, `CLOSE` from OSWORD body/profile/write flow |
| `real/test_real_fujinet_e2e.py::test_real_fujinet_host_listing_and_mount_catalog_reads` | controlled `host:/` tree, FileService `LIST`, Fuji `SET/GET_MOUNT`, and Disk `READ_SECTOR` sector-0/1 catalog fetches for mounted drives |
| `real/test_real_fujinet_e2e.py::test_fujinet_created_the_pty` | the firmware created the advertised PTY slave |

These assert on the **firmware's own log** — fujinet-nio logs
`fujibus: receive: ... dev=.. cmd=..` for every request and `fujibus: send: ..`
for every reply, on **stdout**. That proves the BBC's request actually crossed
the serial+PTY link into the firmware and was answered, rather than merely that
the keystrokes reached the ROM (the BBC screen just echoes the typed command,
so screen-scraping would be a false positive).

> **stdout buffering gotcha.** fujinet-nio's stdout is block-buffered when it's
> a pipe/file rather than a tty, so log lines don't appear until the buffer
> fills. `IsolatedFujinet` launches the firmware under `stdbuf -oL -eL` to force
> line buffering so per-request log assertions are reliable. (Run by hand in a
> terminal you see logs live because a tty is line-buffered.)

#### Extending to data-deterministic interop assertions

To assert real served data (e.g. `*FLS` listing known files), give the firmware
a backing filesystem. Either point `*FHOST` at a TNFS server you control, or
pre-populate the isolated run dir's host filesystem and use a local URI. The
`IsolatedFujinet` constructor takes `extra_config=` to inject extra YAML (e.g.
`mounts:`), and the run dir's `fujinet-data/` is the host filesystem root.

The suite now uses that mechanism for a representative `host:/` scenario: it
creates `foo/bar/weather.ssd` and `foo/baz/iss.ssd` under the isolated
`fujinet-data/`, then drives `*FHOST host:/`, `*FIN`, `*FMOUNT`, and `*.` to
assert the real firmware performs the expected File, Fuji, and Disk traffic,
including the two `READ_SECTOR` catalog fetches (sectors 0 and 1) per mounted
drive.

## Writing more tests

`fuji_device.FujiDevice` is the device end of the link. It records every
request frame and (by default) answers each with a generic success. For
protocol-aware replies, install a responder:

```python
def test_something(beebium, fuji_device):
    fuji_device.set_responder(my_responder)         # fn(pkt) -> Optional[bytes]
    beebium.keyboard.type("*FLS"); beebium.keyboard.press_return()
    pkt = fuji_device.wait_for_command(0xFE, 0x02)  # FileService LIST
    assert pkt and pkt.checksum_ok
```

Build device-side responses with the helpers in `fuji_device.py`
(`build_resolve_path_response`, `resolving_responder`) which reuse the wire
formats defined in `fujinet_tools.fileproto`.

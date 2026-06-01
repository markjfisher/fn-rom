# fn-rom ↔ Beebium serial/PTY end-to-end tests

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

The first two are **not installed** — they're imported from their source
checkouts via `sys.path` wiring in `conftest.py`. Only their third-party
dependencies (`grpcio`, `protobuf`, `pyserial`) are installed, by this
directory's own `pyproject.toml`. Locations are configured by environment
variables (all with sensible defaults for the conventional sibling-checkout
layout):

| Env var | Default | Meaning |
|---------|---------|---------|
| `BEEBIUM_HOME` | `~/dev/bbc/beebium` | beebium repo root (derives the three below) |
| `BEEBIUM_CLIENT_SRC` | `$BEEBIUM_HOME/clients/python/src` | beebium python client source |
| `BEEBIUM_SERVER` | `$BEEBIUM_HOME/build/src/server/beebium-model-b` | server binary |
| `BEEBIUM_MOS` | `$BEEBIUM_HOME/roms/acorn-mos_1_20.rom` | MOS ROM |
| `BEEBIUM_BASIC` | *(unset)* | optional BASIC ROM |
| `FUJINET_TOOLS` | `<fn-rom>/../fujinet-nio/py` | dir containing `fujinet_tools` |
| `FN_ROM` | `<fn-rom>/build/fujinet.rom` | sideways ROM image |
| `FN_ROM_SLOT` | `12` | sideways slot (12 = slot C) |
| `FN_PTY` | `/tmp/fujinet-pty-e2e` | pty symlink path (transport tests only) |
| `FUJINET_BIN` | `<fujinet-nio>/build/fujibus-pty-debug/fujinet-nio` | real firmware binary (opt-in interop tests) |

Each also has a pytest command-line option: `--fn-pty`, `--fn-rom`,
`--fn-rom-slot`, `--beebium-server`, `--beebium-mos`, `--beebium-basic`.

## Prerequisites

- Build the fn-rom image: `make` (produces `build/fujinet.rom`).
- Build the beebium servers in the beebium repo (so `beebium-model-b` exists).
- [`uv`](https://docs.astral.sh/uv/) installed.

## Running

```bash
cd integration-tests/beebium
uv run pytest -v
```

`uv` creates an isolated environment from `pyproject.toml` (no system `pip`,
works on PEP 668 distros like Arch). The suite **launches its own** Beebium
server per test (fresh ROM state) and stops it automatically — you do **not**
need a server running beforehand.

Examples with overrides:

```bash
# Different pty path (the "port" the device attaches to)
uv run pytest --fn-pty /tmp/my-fnpty

# A specific ROM build / slot, and an explicit server binary
uv run pytest --fn-rom ../../build/fujinet.rom --fn-rom-slot 12 \
              --beebium-server ~/dev/bbc/beebium/build/src/server/beebium-model-b

# Via env vars instead
BEEBIUM_HOME=~/src/beebium FUJINET_TOOLS=~/src/fujinet-nio/py uv run pytest
```

## Two test layers

### 1. Transport/protocol tests (deterministic — the CI gate)

`test_serial_e2e.py` substitutes a scripted `FujiDevice` for the real firmware
and asserts the exact FujiBus/SLIP frames the ROM emits. **Beebium creates the
PTY** here (`--serial pty:`) and the test plugs into the slave.

| Test | Command | Asserted frame |
|------|---------|----------------|
| `test_fhost_emits_resolve_path_request` | `*FHOST <uri>` | FileService `RESOLVE_PATH` (0xFE/0x05), URI in payload, checksum OK |
| `test_fdrive_emits_fuji_get_mounts_request` | `*FDRIVE` | Fuji `GET_MOUNTS` (0x70/0xFD), checksum OK |
| `test_fhost_then_fls_round_trip` | `*FHOST` then `*FLS` | RESOLVE_PATH answered by the device, then FileService `LIST` (0xFE/0x02) — proves responses flow back over the PTY |

## Device Coverage Matrix

| Device | ID | Scripted transport coverage | Real-firmware interop coverage | Notes |
|--------|----|-----------------------------|-------------------------------|-------|
| Fuji | `0x70` | `test_fuji_device_e2e.py` (`*FDRIVE`, `*FIN`, `*FOUT`) | `test_real_fujinet_receives_fdrive`, `test_real_fujinet_receives_fmount` | Covers `GET_MOUNTS`, `GET_MOUNT`, `SET_MOUNT` |
| Clock | `0x45` | `test_clock_device.py` | `test_real_fujinet_clock_unreachable_from_fn_rom` | `fn-rom` currently has no BBC command/vector path to Clock |
| Modem | `0xFB` | `test_modem_device.py` | `test_real_fujinet_modem_unreachable_from_fn_rom` | `fn-rom` currently has no BBC command/vector path to Modem |
| Disk | `0xFC` | `test_disk_device.py` (`*FMOUNT`, `*FNEW`, `*FOUT`) | `test_real_fujinet_receives_fmount` | Covers `MOUNT`, `UNMOUNT`, `CREATE`; real interop proves live `MOUNT` |
| Network | `0xFD` | `test_network_device.py` (`OPENIN`) | `test_real_fujinet_receives_openin` | Current stable ROM interop path is network `OPEN` via BASIC `OPENIN` |
| File | `0xFE` | `test_file_device.py` (`*FHOST`, `*FCD`, `*FLS`) | `test_real_fujinet_receives_fhost` | Covers `RESOLVE_PATH`, `LIST` |

### 2. Real-firmware interop tests (opt-in)

`test_real_fujinet_e2e.py` brings up the **actual posix fujinet-nio** and has
beebium talk to it over the real serial link. These skip unless the fujinet
binary is found.

**PTY ownership / topology.** A PTY is a virtual null-modem cable: one side
*creates* it (`posix_openpt`, the "master") and publishes the slave path; the
other side *opens* that path (the slave). It doesn't matter which side creates
it, only that exactly one does. The fujinet-nio firmware is written to be the
creator (it `openpty`s and symlinks the slave to `channel.pty_path`), so here:

```
fujinet-nio (PTY master) ── pty ── beebium (--serial device:) ── fn-rom ── BBC
```

beebium *plugs in* with `--serial device:<pty>` (its open-existing-path mode).
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
| `test_real_fujinet_receives_fdrive` | firmware logs a Fuji `GET_MOUNTS` receive (`dev=0x70 cmd=0xFD`) **and** a reply |
| `test_real_fujinet_receives_fhost` | firmware logs a FileService `RESOLVE_PATH` receive (`dev=0xFE cmd=0x05`) |
| `test_fujinet_created_the_pty` | the firmware created the advertised PTY slave |

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

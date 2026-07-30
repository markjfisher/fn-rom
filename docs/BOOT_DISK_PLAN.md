# fn-rom Product Plan — Resident ROM + transient boot-disk utilities

**Status:** Chosen direction (rev 4 — single product ROM)
**Author:** (drafted with Claude Code)
**Audience:** implementer picking this up cold

> **Rev 2 note.** An earlier draft proposed three peer profiles (FS / DEV / COMBINED).
> Analysing the actual users (§3) showed there is **no network-without-disk user**, so the model
> collapses to a **base + option**: disk is always resident, network is a strict additive feature.
> Moving rarely-used commands out of ROM into boot-disk utilities relieves the
> long-term size pressure. This revision is built around those two decisions.
>
> **Rev 3 decision.** The boot/config disk is now a first-class part of the BBC experience, not an
> afterthought. Going forward, resident ROM bytes are reserved for device/protocol functionality that
> cannot be delivered from disk: filing-system vectors, FujiBus/SLIP/channel code, OSWORD/device
> contracts, bootstrap/recovery commands, and thin wrappers over already-resident APIs. Utility apps
> and bulky management/informational commands should live on the boot/config disk. The all-resident
> build is a compatibility/diagnostic lane only; it must not block protocol or device improvements
> such as streaming responses, SLIP changes, modem support, or richer OSWORD semantics.
>
> **Rev 4 decision.** The ALL/DISK/DISK+NET product matrix is retired. There is one product ROM:
> disk + network device + resident bootstrap/recovery commands. Bulky utilities always live on the
> boot/config disk. `FN-DISK` and `FN-ALL` are not release targets, and the no-network/resident-utils
> build switches should not be reintroduced as product concepts.

---

## 1. Problem statement

fn-rom must fit one 16 KB BBC sideways ROM (`MAIN` = `$8000–$BFFF`, `$4000` bytes — see
`cfg/fujinet-rom.cfg`). We are already at the ceiling:

| Build (current `main`) | End address | Bytes used | Free |
|------------------------|-------------|-----------:|-----:|
| BBC (`fujinet.rom`)    | `$BCD1`     | 15569      | ~815 |
| Master (`fujinet-master.rom`) | `$BCF5` | 15605  | ~779 |

The only mechanism we have today for holding code back is inline conditional assembly
(`.if .defined(_FREE_MAP_)`, `_UTILS_`, `_ROMS_`), most visibly across `src/commands/cmd_tables.s`,
where each gated command is duplicated in the string table, the address table **and** the import
list. It is a blunt instrument, it does not scale, and it does not express "build a ROM for *this
user*". This plan replaces it.

> **Scope:** fn-rom is **BBC-only** (Acorn family — the `BUILD_MACHINE` axis is `BBC | MASTER`, not
> other 8-bits). Atari/C64 are *not* fn-rom targets. They appear only in the wider product sense of a
> "release" bundle: a **BBC release** = fn-rom + `FN-BOOT.ssd` + a BBC-flavoured fujinet build; an
> "Atari release" would be fujinet firmware + any future Atari-side client, which is a separate
> product, not this ROM.

---

## 2. Architecture analysis (what is actually coupled)

### 2.1 Layer map

```
MOS commands ( *CAT, *FMOUNT, *FJSON, ... )           <- cmd_tables.s + src/commands/*
MOS filing vectors (OSFIND/BGET/BPUT/ARGS/GBPB/FILE)  <- src/vectors/*    [SHARED SHELLS]
        |- disk branch  -> DFS catalog + sector IO     [always resident]
        |- net  branch  -> network stream read/write   [network feature]
OSWORD &78 network API (long URIs, JSON paths)         <- src/fnnet.s, src/fnnet/*  [network feature, ABI]
FujiBus device builders                                <- fujibus_disk.s | fujibus_network.s | fujibus_fuji.s
FujiBus packet + SLIP framing + shared data ops        <- fujibus.s, fuji_link_slip.s, fuji_data_fujibus.s  [KERNEL]
Channel (serial / PTY / RS232, userport, 1MHz)         <- src/serial/*, fuji_serial.s, fuji_userport.s      [KERNEL]
```

### 2.2 The network/disk coupling is at clean, identifiable branch points

The disk and network paths meet only at well-defined dispatch points inside the shared MOS filing
vectors — they are **not** smeared across the codebase:

- **Open (`OSFIND`)** — `findv_entry.s:337` calls `read_fspba`, which sets `fuji_network_url_flag`
  when the name contains `"://"`; `:340` branches to `network_open_file`, else the disk open path.
- **Read (`OSBGET`)** — `bgetv_entry.s:85` tests the channel handle and branches to `network_bget`.
- **Write (`OSBPUT`)** — `bputv_entry.s:85` → `network_bput` vs disk.
- **Close** — `findv_entry.s:258` → `close_network_channel` vs disk flush.

Because **disk is always present** (§3), each shell always keeps its *real* disk branch; only the
**network branch** is ever optional. (Wrinkle: `read_fspba` lives in FS-heavy `src/fs_functions.s`
but is also core — it parses every `<fsp>`. Only its URL-detection tail is network-specific; see §5.3.)

### 2.3 The network device already has a stable ABI

`src/fnnet.s` implements the **OSWORD &78 API** (long URIs, JSON queries), dispatched via the
unrecognised-OSWORD service (`service08`). Reason codes live in `src/fnnet/*.inc`
(`reason_set_open_url`, `reason_json_query`, `reason_write_data`, …). This matters twice:
- It is the resident interface that BASIC programs call directly. `*FJSON` is merely *sugar* over it.
- It means network-using utilities can be disk-resident or pure BASIC — they don't need ROM command code.

### 2.4 The MOS already auto-runs unknown commands from disk

`service04_unrec_command` (`services/service09.s:81`) matches the command line against the ROM's own
tables. A `*RUN`-from-filing-system path exists (`fscv2_4_11_starRUN`, `src/commands/cmd_run.s`), and
fn-rom *is* the filing system. Standard BBC behaviour: when no ROM claims service &04, the MOS asks
the current FS to `*RUN` the command as a file. **This is the mechanism that lets us move commands
onto disk** (§5.4). ⚠️ Verify fn-rom leaves service &04 *unclaimed* for genuinely-unknown commands
(so the MOS falls through to load-and-run) rather than erroring — see Phase 3.

### 2.5 Budget pointers

- Largest network file: `fujibus_network.s` (~1201 lines). Largest disk: `fs_functions.s` (~1071),
  `fujibus_disk.s` (~827). Bulky movable commands: `cmd_free_map.s` (~325), `cmd_copy.s` (~312).
  (`cmd_fjson.s` ~171 is *not* movable — it's a thin wrapper, stays resident in NET builds; see §4.2.)
- cc65 **dead-strips only whole object modules**, not unreferenced code inside a linked module.
  Therefore: *to not pay for something, it must live in object files that are simply not linked.*
  This single fact drives the whole mechanism (§5).

---

## 3. Users (actors) and what they require

| # | Actor | Needs disk? | Needs network device? |
|---|-------|:----------:|:---------------------:|
| 1 | **Gamer** — downloads standalone SSDs, runs the game | ✅ | ❌ |
| 2 | **Network gamer** — runs fujinet-aware games/apps | ✅ | ✅ |
| 3 | **Dev** — writes networked apps, also manages disks | ✅ | ✅ |
| 4 | **Filesystem user** — OPENIN/random-access/DFS, app or FS use | ✅ | ❌ |

**Decisive fact:** disk is always needed, and the cost of carrying the network device is now the
right trade-off once utilities live on the boot/config disk. Users who only want drive replacement
simply do not call the network API; they do not need a separate ROM.

**Edge actors (don't change the conclusion):**
- *Power/disk-admin* — heavy `*FORM`/`*COPY`/`*DESTROY` use; a variant of 1/4. Relevant to where the
  resident/transient line sits (§4.2), not to the network axis.
- *Publisher* — builds SSDs on a host with `scripts/create_ssd.py`; not a ROM actor.
- *Pure terminal/modem* (network, no disk, via fujinet-nio's modem device) — the only "network-only"
  shape; treated as a **different product, out of scope** here.

---

## 4. Product model

There is one release shape:

| Build | Contents | ROM filename (≤7) |
|-------|----------|----------------|
| **Product ROM** | disk filing system + network device + resident bootstrap/recovery | `FN-NET` / `FN-NET-M` |

The boot/config utilities disk is shipped alongside it as **`FN-BOOT.ssd`** /
**`FN-BOOT-M.ssd`**. The filename may be revisited later, but the role is settled:
configuration and utility applications live on disk so resident ROM space remains available for
device/protocol functionality.

The product shape is orthogonal to `BUILD_MACHINE` (BBC|MASTER) and `BUILD_INTERFACE`
(SERIAL|USERPORT|1MHZ). These are hardware axes, not product profiles.

### 4.1 Resident kernel vs transient utilities

**Resident in every build (the kernel):**
- Filing-system vectors: OSFIND/BGET/BPUT/FILE/ARGS/GBPB — this *is* the DFS
- FujiBus + SLIP + serial channel; `*FUJI`/`*RESET`/`*ENABLE` init; ROM matcher/help
- **Bootstrap mount set** — the *minimum* to get the boot/config disk into a mounted slot, so these
  cannot themselves live on disk: **`*FHOST`, `*FIN`, `*FMOUNT`** and **`*FBOOT`**. (`*FHOST` takes a
  path, so `*FCD` isn't needed to position a disk; the other F-commands are informational — see
  transient list.)
- `*CAT`, `*RUN`, `*DRIVE` (DFS drive-select), `*DIR`/`*LIB`
- the OSWORD &78 network ABI + network vector branch
- `*FJSON` — verified to be a *thin wrapper* (171 lines of arg-parsing that
  call `fujibus_network_translate_configure`; the JSON engine is in the already-resident network
  code). A thin wrapper over a resident ABI costs almost nothing, so it stays resident and avoids any
  discoverability problem. **General rule:** *thin command-wrappers over already-resident ABI stay
  resident; only commands whose bulk is self-contained become transient.*

**Transient — on the boot/config utilities SSD (`FN-BOOT`), loaded on demand:**
- Disk management whose bulk is self-contained: `*FORM`, `*DESTROY`, `*WIPE`, `*ACCESS`,
  `*TITLE`, `*INFO`, `*RENAME`, `*COPY`, `*FNEW`, `*FREE`/`*MAP`, `*ROMS`, `*FUMOUNT`, `*FOUT`
- **Informational / navigation F-commands** (not needed to position a disk): `*FCD` (covered by
  `*FHOST <path>`), `*FLIST`/`*FLS` (~361+250 lines — large directory listing), `*FDRIVE` (shows what
  the fujinet has in its slots).

> Shared-helper note: `*FLIST`/`*FLS` reuses some variable-width result-display code from `*FDRIVE`.
> Both move out together, so that helper moves to disk too — **duplicate it into the utility** (or a
> shared loadable module) rather than keeping it as a resident ROM entry point (§5.5). Duplication
> costs disk, not ROM, which is the goal.

The line: anything needed to *use* a disk or *get the boot/config disk mounted*
(`*FHOST`/`*FIN`/`*FMOUNT`/`*FBOOT`) stays resident; everything else — management *and*
informational F-commands — is transient. Frequently-used, latency-sensitive things (the vectors,
`*CAT`) never move. ROM headroom is for device behaviour, not utility-app convenience.

### 4.2 Discoverability: the boot/config library drive

A transient utility lives on the boot/config disk (e.g. drive 3), but the user's *current* drive is usually
their app/game disk (drive 0). BBC DFS already solves this: an unrecognised `*command` is looked up
in the current directory **and then the library**, and the library may be on a different drive.
fn-rom already implements this fallback — `cmd_run.s:56–60` ("File not found in default location, try
library") consults `fuji_lib_drive`/`fuji_lib_dir`, and `*LIB` (`cmd_fs_lib`) sets the library slot.

So the bootstrap is: restore the configured boot disk to a drive **and set it as the library**, e.g.

```
*FBOOT 3                ; restore configured boot image to BBC drive 3
*LIB :3                 ; library = drive 3  -> *FORM etc. resolve here regardless of current drive
```

The forward resident helper is `*FBOOT [drive]`: with no argument it preserves the current default
boot behaviour, and with a drive argument such as `*FBOOT 3` it restores the boot/config disk to that
drive so `CONFIG`/`CONFNIO` and utility commands remain available after the user mounts real disks.

This (or a `!BOOT` that runs it, or ROM auto-mount at init) keeps the current drive on the app disk
while management commands resolve from the library. The Beebium command-from-disk lane covers the
*unrecognised-command* route (service &04 → MOS → FSC) and the library-aware lookup.

**Costs of transient utilities (accepted):** they consume user RAM when loaded and incur a disk hit
per invocation; they need stable ROM entry points (MOS calls; OSWORD &78 for network). That is the
intended trade: a small launch cost buys resident ROM space for features that cannot be apps.

### 4.3 Future device features (modem, terminal) — the model generalises

The kernel + selectable-feature structure is **not** hard-wired to "net vs disk". Each optional
feature is: a `src/<feature>/` dir + a composable-table fragment + (optionally) a device ABI. Planned
future slots:
- **`FEATURE_MODEM`** — fujinet exposes a modem device directly; plumbing is a `fujibus_modem`
  builder plus an exposure mechanism (RS423-style stream and/or OSWORD reasons). Likely a NET-adjacent
  feature.
- **`FEATURE_TERMINAL`** — a "killer feature." Open design point: resident `*TERM`-style command
  driving the modem device (VDU out + keyboard in) **vs** a transient terminal app on disk. Decide
  when modem plumbing lands; both fit this model.

---

## 5. Mechanism design

Goal: **a command is resident only if it belongs to the kernel/protocol/recovery boundary.**
Everything else is built as a boot/config disk utility.

### 5.1 Build shape (Makefile)

The Makefile has no product profile levers. `make all` builds the BBC product ROM; add
`BUILD_MACHINE=MASTER` for the Master product ROM. `src/net/` is always compiled. `src/utils/` is
always filtered out of resident ROM sources and is built by `scripts/build_fn_boot.sh` into
`FN-BOOT.ssd`.

### 5.2 Source selection by directory (preferred over file-level `.if`)

Source residency is expressed by location:

```
src/kernel/    resident (vector shells, transport, channel, init, matcher, bootstrap/recovery, CAT/RUN)
src/disk/      resident (disk catalog + sector IO + disk vector branch)
src/net/       resident (network builders, network vector branch, OSWORD &78, FJSON)
src/utils/     boot/config disk utilities only
```

Because cc65 omits unlinked modules wholesale (§2.5), keeping utility modules out of the ROM costs
zero resident bytes.

### 5.3 Composable command table (retires the blunt ifdef)

Replace the monolithic `cmd_tables.s` with **per-module table fragments collected by the linker via
dedicated segments** (`CMDSTR_KERNEL`/`CMDADDR_KERNEL`, `CMDSTR_NET`/`CMDADDR_NET`, etc., declared in
`cfg/fujinet-rom.cfg`, keeping each string region page-aligned with its address region as the current
RODATA comment requires). A `cmd_entry` macro hides the `$80|param` encoding so fragments are
declarative. The matcher walks linker-exported `__CMDSTR_START__..__CMDSTR_END__`, so an absent
module contributes nothing — **no `.if` anywhere in the table**, and the "print leading F" boundary
logic is re-expressed against segment boundaries rather than hard-coded order.

This machinery now mainly separates resident commands from boot/config disk commands. Network is
resident in the product ROM.

### 5.5 Transient-utility extraction

For each `src/utils/` command:
1. It must reach the ROM only through documented entry points (MOS calls; OSWORD &78 for network).
   Audit each command's current `.import` list — anything it pulls from kernel/disk internals must
   become a published entry or be inlined into the utility. **Helpers shared only between transient
   utilities** (e.g. the variable-width display code shared by `*FLIST` and `*FDRIVE`) should be
   **duplicated into each utility or shipped as a shared loadable module** — *not* promoted to a
   resident ROM entry point, since that would re-spend the ROM bytes we are trying to reclaim.
2. Build it as a BBC binary with its own load/exec address. `scripts/create_ssd.py` **already**
   supports per-file load/exec via `.inf` sidecars (and `!BOOT`-style on-disk renaming), so no tooling
   change is needed — each utility ships with its own `<name>.inf`.
3. Ship on `FN-BOOT.ssd` produced by `scripts/create_ssd.py`.
4. It is absent from the ROM because `src/utils/*` is never part of resident `SOURCES`; the §2.4
   fallthrough loads it on use.

### 5.6 Workspace / ZP

Single authoritative map in `os.s`. Do not create alternative workspace meanings for no-network or
resident-utility variants; those product variants are retired.

---

## 6. Current implementation path

The resident-ROM/boot-disk migration has served its purpose and is no longer the product model. Current work should follow this path:

1. Build one resident product ROM with disk and network always present.
2. Keep management and informational utilities out of resident ROM. Build them from `src/utils/` into `FN-BOOT.ssd` with `scripts/build_fn_boot.sh`.
3. Keep `*FHOST`, `*FIN`, `*FMOUNT`, `*FBOOT`, DFS vectors, `*CAT`, `*RUN`, `*DRIVE`, `*DIR`/`*LIB`, `*FJSON`, and OSWORD &78 resident.
4. Spend recovered ROM space on protocol and device functionality, not resident utility convenience.
5. Do not add release targets for no-network or all-resident ROMs.

## 7. Testing

The local gate is:

```bash
make clean all-machines
make sizes
./run_unit_tests.sh
./integration-tests/beebium/run_product_tests.sh
```

The Beebium gate has two lanes:

| Lane | What it proves |
|------|----------------|
| product | resident ROM disk/network behaviour over the scripted FujiBus/SLIP transport |
| boot | boot/config disk command loading, library fallback, and transient utility argument passing |

Tests that require `FN-BOOT.ssd` mounted as the library use the `needs_boot_utils_setup` marker and are covered by the `boot` lane.

## 8. Decisions

- **One product ROM:** `FN-NET` for BBC and `FN-NET-M` for Master.
- **No `FN-DISK` release:** users who only want disk replacement can use the normal product ROM and ignore the network API.
- **No `FN-ALL` release:** all-resident utilities are retired so ROM headroom belongs to device/protocol work.
- **Boot/config disk:** `FN-BOOT.ssd` remains the short filename for now and carries config/utility applications.
- **`*FJSON`:** remains resident because it is a thin wrapper over the resident OSWORD &78 network API.
- **`*FBOOT [drive]`:** resident recovery command direction; no argument preserves existing default boot behaviour, and a drive argument should restore the boot/config disk to that drive.
- **Bank-switching:** deferred for power-user scenarios, not a substitute for moving ordinary utilities to disk.

---

## Appendix A — Boot/config disk auto-setup sketch

> Status: **chosen direction, implementation still staged.** Captures where the policy could live,
> rough resident byte cost, and the failure modes when no boot/config disk is present. The short-term
> disk image may still be named `FN-BOOT.ssd`, but its role is broader: config app plus utilities.

### A.1 The hook already exists
`fuji_init.s` reads the break type and branches at **`skip_autoload`**, which already carries the
intended hook:
```
        lda     #$FD                    ; X=0 soft break, 1 power-up, 2 hard break
        jsr     osbyte_X0YFF
        cpx     #$00
        beq     skip_autoload           ; soft break -> preserve state, do NOT remount
        ; TODO: jsr  fuji_load_boot_disk   <-- auto-mount would go here (cold boot only)
skip_autoload:
```
So auto-mount runs on **power-up / hard break only**; soft break (CTRL-BREAK) preserves the existing
mount + library, which is the behaviour we want. The mount primitive is small:
`set current_drv; set aws_tmp08 = slot; jsr fuji_mount_disk` (records `fuji_drive_disk_map[drv]` and
issues the FujiBus mount), then `sta fuji_lib_drive`.

### A.2 Three places the policy could live

| Layer | Where | ROM cost | Flexibility | Notes |
|-------|-------|---------:|-------------|-------|
| **A. Device config** | fujinet auto-mounts the boot/config SSD to a *slot* at device boot (it already persists a `mounts:` list — see `posix.fujinet.yaml`); ROM reads "which slot is the library disk" from a config field and does FMOUNT+`*LIB` | ~80–120 B | High — retune the slot/drive without reflashing the ROM | Needs a small device-side config field + one status/config FujiBus read at boot |
| **B. ROM resident, hardcoded** | ROM mounts a fixed `BOOT_SLOT`→`BOOT_DRIVE` and sets library at cold boot | **~30–50 B** | Low — slot/drive baked into ROM | Cheapest; brittle if the user’s slot/drive differs |
| **C. User `!BOOT`** | The boot/config disk has a `!BOOT` running `*FMOUNT … ; *LIB :n` | **0 B** | High — fully user-editable | Requires a boot disk and `*OPT 4,n`; nothing automatic on a bare machine |

Rough estimate basis (Layer B happy path): set drive (~4 B) + set slot (~4 B) + `jsr fuji_mount_disk`
(3 B) + `bcs` skip-on-fail (2 B) + set `fuji_lib_drive` (~4 B) + restore `current_drv=0` (~4 B) ≈ **~25 B**,
plus a few bytes of guard/labels. Either way the resident cost is **dwarfed by what moving the
management commands out reclaims** (hundreds of bytes to ~1–2 KB), so affordability is not the issue —
**policy source and drive consumption are.**

### A.3 Failure-mode rules (no boot/config disk present)

The boot path must never hang or error out when the boot/config disk is absent (pure gamer, actor 1; or
fujinet powered separately; or slot unbound; or image missing). Rules:
1. **Bounded, silent failure.** The boot-time mount must use a short timeout (the FujiBus/SLIP layer
   already has retry/backoff) and, on any error (`C` set), simply continue booting.
2. **Only set the library on success.** If the mount fails, **leave `fuji_lib_drive = 0`**. Otherwise
   unrecognised `*commands` would try to load from an empty drive and report errors. On failure the
   machine behaves exactly as a no-boot-disk install: management commands are just unavailable.
3. **Don’t block the network/disk core.** Auto-mount is best-effort decoration on top of an already
   functional kernel.

### A.4 The real trade-off: a consumed drive

Pointing the library at the boot/config disk consumes one BBC drive (the sketch assumed drive 3). DFS
libraries are drive+dir based, so a drive *must* back the library — you can’t point it at a bare
host/slot. Decisions this forces:
- **Which drive?** **Decided: drive 3** (last supported). Reserving 3 leaves 0–2 for the user; users
  rarely need all four drives concurrently, so impact is low.
- **Override semantics.** Auto-setting the library overrides any user `*LIB`; users can re-`*LIB`
  after boot, but a boot disk’s `!BOOT` might fight the ROM. Define precedence (ROM sets it only if
  the user hasn’t, or always, or never on soft break — the last is already implied by A.1).

### A.5 Suggested trajectory
- **Phase 4 (now):** ship Layer **C** (`!BOOT` on the boot/config disk) — zero ROM cost, unblocks the
  transient-utilities work, lets the mechanism be exercised end-to-end.
- **Polish:** move to Layer **A** (config-driven) as the longer-term answer; keep Layer **B**
  (hardcoded) as the fallback if config plumbing proves too heavy. All three share the same
  `skip_autoload` hook and the §A.3 failure rules.

---

## Appendix B — Future directions & scaling notes (not in scope now)

> Captured so today's simple choices (hardcoded drive 3, 8 slots) are understood as deliberate
> stepping stones, not dead ends.

### B.1 A BBC-specific layer inside fujinet (enables config-driven auto-mount — Layer A)
Today the firmware builds host-agnostic profiles (e.g. `fujibus-pty-debug`). A future **BBC layer**
in fujinet would own BBC-only concerns that don't belong in the ROM: text translation, and
**persisted configuration** the ROM can query. That unlocks Appendix A Layer A:
- fn-rom asks the fujinet **very early at boot** "what's the user's configured utils drive / library
  slot?" (and potentially other persisted state), via a small status/config FujiBus call.
- A `*OPT`-style command lets the user change that value; the ROM propagates it to the BBC layer for
  persistence, so it survives reboots without reflashing the ROM.

This keeps policy (which drive, which slot, defaults) on the device and out of the 16 KB budget.

### B.2 Scaling BBC drives beyond 4
From fn-rom's side this is small and well-contained. Places to grow:
- **`fuji_drive_disk_map`** — `os.s:576` (`fuji_static_workspace + $12`, **4 bytes**, `$FF` = unmounted).
  This is the primary state array. Referenced by `fuji_init.s`, `fuji_mount.s`, `fuji_fs.s`,
  `cmd_fout.s`, `cmd_funmount.s`, `src/inc/os.inc`.
- **`MAX_BBC_DRIVE`** — `cmd_fmount.s:42` (currently `3`).
- The **unrolled init loop** in `fuji_init.s` that clears `fuji_drive_disk_map+0..+3` to `$FF`.
- Workspace budget: each extra drive is one more byte in static workspace.

### B.3 Scaling fujinet slots beyond 8
- The data model already allows it: `$FF` is the "no drive / unmounted" sentinel, so **up to 254**
  real slots (0–253) are representable.
- The current cap of **8 (0–7)** is purely a **command-line parsing limit**: `param_get_num` accepts a
  single digit (0–9), and `MAX_MOUNT_SLOT` (`cmd_fin.s:33`) / `MAX_MOUNT_SLOT_COUNT` (`cmd_fmount.s:39`)
  enforce 0–7. Raising it needs multi-digit numeric parsing on the command line plus relaxing those
  constants — not a data-model change.

---

## Appendix C — Current testing strategy

The current product has no profile matrix. Test coverage is split by runtime setup:

| Suite | Command | Protects |
|-------|---------|----------|
| Unit tests | `./run_unit_tests.sh` | soft65c02 checks assembled against the product ROM labels |
| Beebium product lane | `./integration-tests/beebium/run_product_tests.sh` | scripted serial/PTY FujiBus frames for resident disk and network behaviour |
| Beebium FN-BOOT lane | `./scripts/run_fn_boot_test.sh` | disk-loaded utility execution, library fallback, and argument passing |
| Real interop | `cd integration-tests/beebium && ./run_pytest.sh real/ -q` | opt-in live fujinet-nio transport/firmware integration |

`run_product_tests.sh` runs the product lane and then the FN-BOOT lane. `run_tests.sh` wraps builds, sizes, unit tests, and the Beebium gate.

# fn-rom Role Split Plan — Kernel + Network feature + Transient utilities

**Status:** Chosen direction (rev 3 — boot/config disk and resident-kernel model)
**Author:** (drafted with Claude Code)
**Audience:** implementer picking this up cold

> **Rev 2 note.** An earlier draft proposed three peer profiles (FS / DEV / COMBINED).
> Analysing the actual users (§3) showed there is **no network-without-disk user**, so the model
> collapses to a **base + option**: disk is always resident, network is a strict additive feature.
> A second, orthogonal lever — moving rarely-used commands out of ROM onto disk — is what relieves
> the long-term size pressure. This revision is built around those two levers.
>
> **Rev 3 decision.** The boot/config disk is now a first-class part of the BBC experience, not an
> afterthought. Going forward, resident ROM bytes are reserved for device/protocol functionality that
> cannot be delivered from disk: filing-system vectors, FujiBus/SLIP/channel code, OSWORD/device
> contracts, bootstrap/recovery commands, and thin wrappers over already-resident APIs. Utility apps
> and bulky management/informational commands should live on the boot/config disk. The all-resident
> build is a compatibility/diagnostic lane only; it must not block protocol or device improvements
> such as streaming responses, SLIP changes, modem support, or richer OSWORD semantics.

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
> "release" bundle: a **BBC release** = fn-rom + `FN-UTLS.ssd` + a BBC-flavoured fujinet build; an
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

**Decisive fact: nobody needs network without disk.** Actors 2 and 3 must first *get the program
onto the BBC* — including the network demo SSDs — and that path is the filing system. So network is
never standalone; it is **strictly additive on top of disk**. The natural grouping is exactly:

- **1 + 4 → pure disk**
- **2 + 3 → disk + network**

**Edge actors (don't change the conclusion):**
- *Power/disk-admin* — heavy `*FORM`/`*COPY`/`*DESTROY` use; a variant of 1/4. Relevant to where the
  resident/transient line sits (§4.2), not to the network axis.
- *Publisher* — builds SSDs on a host with `scripts/create_ssd.py`; not a ROM actor.
- *Pure terminal/modem* (network, no disk, via fujinet-nio's modem device) — the only "network-only"
  shape; treated as a **different product, out of scope** here.

---

## 4. Recommended model: two orthogonal levers

### Lever A — network feature on/off  (`FEATURE_NET`)
Selects the disk/net axis. Disk capability is the always-resident base; `FEATURE_NET` adds the
network branch in the vectors + the OSWORD &78 ABI + network FujiBus builders.

### Lever B — utilities resident vs on-disk  (`UTILITIES = resident | disk`)
Selects whether rarely-used commands are linked into ROM or shipped as transient files on a
utilities SSD and loaded on demand via the §2.4 fallthrough. Largely orthogonal to Lever A; it is
what gives **both** builds long-term headroom.

### 4.1 Shipped builds

| Build | `FEATURE_NET` | `UTILITIES` | Actors | ROM filename (≤7) |
|-------|:------------:|:-----------:|--------|----------------|
| **DISK**     | off | disk     | 1, 4 | `FN-DISK` |
| **DISK+NET** (default) | on  | disk     | 2, 3 | `FN-NET`  |
| **ALL** (compat/diagnostic) | on | resident | regression tests and legacy convenience while it fits | `FN-ALL` |

> Naming note: a DFS **title** may be up to 12 chars, but a **filename** is ≤7. ROM images and
> transient utilities are *files*, so all names above are ≤7; the utilities SSD's on-disk name is
> **`FN-UTLS`** (the host-side image may be `fn-utls.ssd`).
>
> Decisions taken (owner, rev 3): **default build = DISK+NET**; **minimal resident kernel** (move
> self-contained management/informational commands to the boot/config disk — but see §4.2 on thin
> wrappers); **`ALL` is compatibility/diagnostic only**. It may stay while it fits, but if the choice
> is between an all-resident utility and device/protocol functionality, the utility moves to disk. A
> disk-only-resident variant is *possible* (NET off + resident) but is not a headline distributable.

Role is orthogonal to the existing `BUILD_MACHINE` (BBC|MASTER) and `BUILD_INTERFACE`
(SERIAL|USERPORT|1MHZ) axes; output names encode all of it, e.g. `FN-NET-BBC-SERIAL.rom`.

### 4.2 Resident kernel vs transient utilities (the minimal-kernel boundary)

**Resident in every build (the kernel):**
- Filing-system vectors: OSFIND/BGET/BPUT/FILE/ARGS/GBPB — this *is* the DFS
- FujiBus + SLIP + serial channel; `*FUJI`/`*RESET`/`*ENABLE` init; ROM matcher/help
- **Bootstrap mount set** — the *minimum* to get the boot/config disk into a mounted slot, so these
  cannot themselves live on disk: **`*FHOST`, `*FIN`, `*FMOUNT`** and **`*FBOOT`**. (`*FHOST` takes a
  path, so `*FCD` isn't needed to position a disk; the other F-commands are informational — see
  transient list.)
- `*CAT`, `*RUN`, `*DRIVE` (DFS drive-select), `*DIR`/`*LIB`
- **(DISK+NET / ALL only)** the OSWORD &78 network ABI + network vector branch
- **(DISK+NET / ALL only)** `*FJSON` — verified to be a *thin wrapper* (171 lines of arg-parsing that
  call `fujibus_network_translate_configure`; the JSON engine is in the already-resident network
  code). A thin wrapper over a resident ABI costs almost nothing, so it stays resident and avoids any
  discoverability problem. **General rule:** *thin command-wrappers over already-resident ABI stay
  resident; only commands whose bulk is self-contained become transient.*

**Transient — on the boot/config utilities SSD (`FN-UTLS`), loaded on demand:**
- Disk management whose bulk is self-contained: `*FORM`, `*DESTROY`, `*WIPE`, `*VERIFY`, `*ACCESS`,
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
`*CAT`) never move. This boundary applies to future work as well as DISK/DISK+NET today: ROM
headroom is for device behaviour, not utility-app convenience.

### 4.2.1 Discoverability: the boot/config library drive

A transient utility lives on the boot/config disk (e.g. drive 3), but the user's *current* drive is usually
their app/game disk (drive 0). BBC DFS already solves this: an unrecognised `*command` is looked up
in the current directory **and then the library**, and the library may be on a different drive.
fn-rom already implements this fallback — `cmd_run.s:56–60` ("File not found in default location, try
library") consults `fuji_lib_drive`/`fuji_lib_dir`, and `*LIB` (`cmd_fs_lib`) sets the library slot.

So the bootstrap is: mount the boot/config disk to a drive **and set it as the library**, e.g.

```
*FHOST sd0:/
*FIN 7 fn-utls.ssd      ; bind boot/config image to slot 7
*FMOUNT 7 3             ; mount slot 7 as BBC drive 3
*LIB :3                 ; library = drive 3  -> *FORM etc. resolve here regardless of current drive
```

The forward resident helper is `*FBOOT [drive]`: with no argument it preserves the current default
boot behaviour, and with a drive argument such as `*FBOOT 3` it restores the boot/config disk to that
drive so `CONFIG`/`CONFNIO` and utility commands remain available after the user mounts real disks.
Until that argument exists in code, the explicit `*FHOST`/`*FIN`/`*FMOUNT`/`*LIB` sequence above is
the current mechanism.

This (or a `!BOOT` that runs it, or ROM auto-mount at init) keeps the current drive on the app disk
while management commands resolve from the library. ⚠️ Phase 3 must confirm the *unrecognised-command*
route (service &04 → MOS → FSC) reuses this library-aware lookup, not only the explicit `*RUN`.

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

Goal: **a command/feature is in the ROM iff its object module is linked; no inline `.if` in command
tables or vector bodies.**

### 5.1 Build variables (Makefile)

Add two first-class variables beside `BUILD_MACHINE`/`BUILD_INTERFACE`:

```make
FEATURE_NET ?= 0          # 0 | 1   (Lever A)
UTILITIES   ?= disk       # disk | resident   (Lever B)

ifeq ($(FEATURE_NET),1)
  ASFLAGS += --asm-define FEATURE_NET
endif
ifeq ($(UTILITIES),resident)
  ASFLAGS += --asm-define UTILITIES_RESIDENT
endif
```

Provide convenience targets for the three shipped builds (`make disk`, `make net`, `make all-rom`)
that set the pair appropriately. Fold both into `BUILD_VARIANT` so `obj/<variant>/` stays correct
(stale-object safety).

### 5.2 Source selection by directory (preferred over file-level `.if`)

Reorganise so feature membership is expressed by location, and compose `SOURCES` from selected dirs:

```
src/kernel/    always compiled (vectors shells, transport, channel, init, matcher, bootstrap mounts, CAT/RUN)
src/disk/      always compiled (disk catalog + sector IO + disk vector branch)   -- "disk" is in every build
src/net/       compiled when FEATURE_NET        (fujibus_network.s, fnnet/, network vector branch, OSWORD &78)
src/utils/     compiled when UTILITIES_RESIDENT  (the transient management commands)
```

`src/utils/` files, when not compiled, are instead **built as standalone disk binaries** for the
utilities SSD (see Phase 4). Because cc65 omits unlinked modules wholesale (§2.5), absence costs zero
ROM bytes — no `.if` wrappers needed inside shared files.

### 5.3 Composable command table (retires the blunt ifdef)

Replace the monolithic `cmd_tables.s` with **per-module table fragments collected by the linker via
dedicated segments** (`CMDSTR_KERNEL`/`CMDADDR_KERNEL`, `CMDSTR_NET`/`CMDADDR_NET`, etc., declared in
`cfg/fujinet-rom.cfg`, keeping each string region page-aligned with its address region as the current
RODATA comment requires). A `cmd_entry` macro hides the `$80|param` encoding so fragments are
declarative. The matcher walks linker-exported `__CMDSTR_START__..__CMDSTR_END__`, so an absent
module contributes nothing — **no `.if` anywhere in the table**, and the "print leading F" boundary
logic is re-expressed against segment boundaries rather than hard-coded order.

This serves *both* levers uniformly: a command is absent from the table either because its feature
is off (network) or because it's transient-on-disk (utilities) — same machinery, two reasons.

### 5.4 Network branch hook (only one direction now)

Because disk is always resident, the vectors always keep the real disk branch. Only the **network**
branch is optional:
- `network_open_file`, `network_bget`, `network_bput`, `close_network_channel` live in `src/net/`.
- When `FEATURE_NET` is off, those modules aren't linked. Provide a tiny kernel stub (or simply leave
  `fuji_network_url_flag` permanently clear) so `findv_entry.s:340` and the BGET/BPUT handle tests
  fall straight through to disk and the linker omits the network modules.
- `read_fspba` URL-detection tail (§2.2): gate just the bytes that set the flag; in DISK builds the
  flag stays clear and the branch is dead.

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
3. Ship on `FN-UTLS.ssd` produced by `scripts/create_ssd.py`.
4. Removing it from the ROM = removing its `src/utils/*` module + its table fragment; the §2.4
   fallthrough loads it on use.

### 5.6 Workspace / ZP

Single authoritative, feature-tagged map in `os.s`. DISK builds may reclaim the network state bytes;
do **not** let disk and net assign the same ZP/workspace to incompatible meanings, so `ALL` stays
consistent.

---

## 6. Phased implementation plan (each phase independently mergeable, ROM always builds)

> **Testing runs through every phase, not just at the end.** The existing suite (
> beebium scripted/real integration tests) are the regression net for this refactor — see
> **Appendix C** for the strategy, coverage model, and the new scenarios the transition requires.
> Each phase below carries a concrete **Test gate**.

### Phase 0 — Measure & baseline
- Add `make sizes` (segment usage + free bytes from `.map` per ROM).
- Experimentally exclude `src/net` (network) and the management-command set; record real KB deltas to
  confirm §2.5 and size the three builds.
- **Test gate:** establish the **golden baseline** — run the full beebium
  scripted suite **locally** on today's `main` and record results; this is the behaviour every refactor
  phase must preserve. Confirm the local toolchain is installed (Appendix C.5).
- **Acceptance:** documented byte budget per feature/build; green baseline captured.

### Phase 1 — Composable command table (prove on one group)
- Implement the `cmd_entry` macro + segment-collected table (§5.3); migrate **only** FREE/MAP off
  `.if .defined(_FREE_MAP_)` as the proving ground.
- **Acceptance:** command behaviour byte-identical to today; no `.if` left for FREE/MAP; new
  table-dispatch unit tests green.

### Phase 2 — Source reorg into kernel/disk/net/utils
- Move files (§5.2); update Makefile `SOURCES`, `--asm-include-dir`, import lists
  (`scripts/clean_imports.py`). Still all-compiled (≈ `ALL`).
- **Test gate:** full beebium scripted suites green and **emitted FujiBus frames identical**
  to the Phase 0 baseline (pure move ⇒ no behaviour change).
- **Acceptance:** `ALL` ROM byte-identical (or trivially close); diff is moves + import fixes only.

### Phase 3 — Network feature toggle (Lever A) + service-&04 / library verify
- Network branch hook/stub (§5.4); build `FEATURE_NET=0`.
- Verify unrecognised commands leave service &04 unclaimed → MOS asks the FS to run them, **and that
  the route reuses the library-aware lookup** (§4.2.1), so a util on the library drive resolves while
  the current drive is the app disk.
- **Test gate:** parameterise the beebium scripted suite by build (Appendix C.3). Run network tests
  (`test_network_device.py`, OSWORD `&78`) against `DISK+NET`/`ALL`; add **negative tests** asserting
  the `DISK` build emits *no* network frames for the same inputs. Add a **fallthrough test**: an
  unknown `*command` on a current-drive shell resolves+runs a binary from the library drive.
- **Acceptance:** `DISK` build has no network open path; `*FJSON` present only in NET builds;
  `DISK+NET` matches `ALL` network behaviour; both smaller than `ALL`; negative + fallthrough tests green.

### Phase 4 — Transient utilities (Lever B) + utilities SSD
- Extract self-contained management commands per §5.5; produce `FN-UTLS.ssd` (per-file `.inf`); finish
  migrating all table entries to the composable mechanism. Provide the documented bootstrap (§4.2.1)
  and/or ROM auto-mount of the boot/config disk + `*LIB`.
- **Test gate:** new **command-from-disk** scenario (Appendix C.4) — in beebium, mount `FN-UTLS.ssd`,
  set the library, then run e.g. `*FLS`/`*FORM` and assert the *same* FujiBus frames / results as when
  resident in `ALL`.
- **Acceptance:** in `DISK`/`DISK+NET`, e.g. `*FORM`/`*COPY` are absent from ROM but run from the
  library-mounted boot/config disk with identical behaviour; `make all-rom` keeps them in ROM.

### Phase 5 — Consolidate test matrix, docs, examples
- Make the **build × test matrix** runnable **locally with one command** (Appendix C.3): build all
  three profiles and run the feature-appropriate suites; `run_unit_tests.sh` and the beebium runner
  gain a build/profile arg. Keep it **CI-ready** (cargo-from-git install, env-var path config) for the
  future GitHub CI, but do not block on CI now.
- Update `README.md`, `AGENTS.md`, `docs/fn-rom-bootstrap.md`, `docs/ARCHITECTURE.md`; document the
  ROM ABI used by transient utilities and the per-build test matrix.
- Ensure `bas/` examples + `FN-UTLS.ssd` ship with the `DISK+NET` build.
- Retire/alias `_FREE_MAP_`/`_UTILS_`/`_ROMS_`.
- **Acceptance:** the full matrix runs green **locally**; coverage matrix (Appendix C.3) has no
  unintended gaps.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Composable table breaks "leading-F"/`not_cmd_*` boundary logic | Phase 1 proves on one feature, byte-for-byte |
| cc65 doesn't dead-strip → no real savings | §2.5/§5.2: feature = unlinked object modules; Phase 0 measures |
| Service &04 doesn't fall through to FS run / doesn't use library lookup | Explicit Phase 3 verification (§4.2.1) before relying on it |
| Transient util not found because current drive ≠ utils drive | Resolved by the **library drive** (§4.2.1); fn-rom already does library fallback in `cmd_run.s` |
| Transient utility needs an undocumented ROM internal | Phase 4 audits imports; publish entry points / OSWORD reason |
| Source reorg churns imports | Phase 2 is a pure move; verify `ALL` byte-identical |
| ZP/workspace divergence | Single feature-tagged map in `os.s` (§5.6) |
| Behaviour regression hidden by a "pure refactor" | Per-phase test gates assert emitted FujiBus frames identical to the Phase 0 baseline (Appendix C) |
| Test tooling is the author's own (beebium serial PR un-merged upstream) — not generally packaged | Local-first testing during this transition (Appendix C.5); build beebium; promote beebium once its serial support lands |
| New disk-loaded command path (Phase 4) untested by existing suites | New "command-from-disk" beebium scenario added in Phase 4 (Appendix C.4) |
| `ALL` won't fit after future growth | Trim or move resident utility commands; do not block protocol/device work. DISK/DISK+NET are the lean primaries; bank-switch is the escape hatch (§8.6) |

---

## 8. Decisions (resolved) and remaining open points

**Resolved (owner, rev 3):**
- **8.1 Names** — ROM files `FN-DISK` / `FN-NET` / `FN-ALL` (≤7); boot/config utilities disk
  **`FN-UTLS`** (title may be 12 chars but the filename limit of 7 governs). ✅
- **8.2 Default build** — **DISK+NET**. ✅
- **8.3 `*FJSON`** — stays **resident in NET builds** (thin wrapper over the resident OSWORD &78
  engine; cheap, and avoids a discoverability problem). Absent in `DISK`. ✅
- **8.4 ROM headroom policy** — device/protocol functionality wins over resident utility
  convenience. Utility commands that can run from disk belong on the boot/config disk. `ALL` is a
  compatibility/diagnostic lane, not the design target. ✅
- **8.5 `create_ssd.py`** — already supports per-file load/exec via `.inf` sidecars; no tooling change
  needed. ✅
- **8.6 Bank-switching** — **deferred** (power-user; precedent: owner's cc65 `bbc-clib` target running
  core functions from ROM to free application RAM). Not for the general user. ✅

- **Auto-setup approach** — **decided: a dedicated drive/mount for the boot/config disk** (the consumed-drive
  trade-off in Appendix A.4 is accepted for now), hooked into the cold-boot autoboot facility
  (Appendix A.1). Ship with instructions to copy `FN-UTLS.ssd` to the ESP32's SD card. ✅
- **Library drive number** — **decided: drive 3** (the last supported drive). Users rarely need all
  four drives at once, so reserving drive 3 for the utils/library mount is low-impact. ✅
- **`*FBOOT [drive]` direction** — resident `*FBOOT` should become the recovery shortcut for mounting
  the boot/config disk to the chosen drive. `*FBOOT 3` is the preferred workflow for keeping config
  and utilities reachable as `:3` after real disks are mounted. ✅

**Remaining open:**
1. **Boot/config disk distribution detail** — whether the `FN-UTLS` image name remains long-term or
   is replaced by a clearer boot/config disk name. Short-term, `FN-UTLS.ssd` remains the filename for
   compatibility and DFS-safe naming.
2. **Final bootstrap policy** — ROM auto-mount via the `skip_autoload` hook vs a `!BOOT`; Appendix
   A.5 recommends shipping `!BOOT` (Layer C) first, then evolving to config-driven auto-mount
   (Layer A — see Appendix B).
3. **Modem feature placement** (8.7) — `FEATURE_MODEM` as its own feature vs a NET sub-feature; where
   the modem-device plumbing lives.
4. **Terminal** (8.7) — in scope eventually; resident `*TERM` command vs transient app. Decide
   alongside modem plumbing.
5. **Pure terminal/modem-only product** — out of scope as a *disk-less* build for now, but the modem
   plumbing above should not preclude it later.

---

## 9. Appendix: quick reference

- ROM budget: `MAIN $8000–$BFFF = $4000` (16384) bytes; current free ≈ 800 bytes (§1).
- Network/disk seams: `findv_entry.s:337/340`, `bgetv_entry.s:85`, `bputv_entry.s:85`,
  `findv_entry.s:258` (close).
- Network ABI: OSWORD &78, `src/fnnet.s` + `src/fnnet/*.inc`; dispatched via `service08`.
- Unknown-command → disk `*RUN`: `services/service09.s:81` (service &04), `cmd_run.s`
  (`fscv2_4_11_starRUN`).
- Macros to retire/fold: `_FREE_MAP_`, `_UTILS_`, `_ROMS_`. New: `FEATURE_NET`, `UTILITIES_RESIDENT`.
- Orthogonal dims: `BUILD_MACHINE` (BBC|MASTER), `BUILD_INTERFACE` (SERIAL|USERPORT|1MHZ).

---

## Appendix A — Boot/config disk auto-setup sketch

> Status: **chosen direction, implementation still staged.** Captures where the policy could live,
> rough resident byte cost, and the failure modes when no boot/config disk is present. The short-term
> disk image may still be named `FN-UTLS.ssd`, but its role is broader: config app plus utilities.

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

## Appendix C — Testing strategy across the transition

> The role split is a large, mostly-mechanical refactor of working code; its safety case rests
> entirely on **behaviour-preservation verified by tests**. The repo already has the two suites we
> need — this appendix maps them to the transition and names the new scenarios it requires.

### C.1 Principle
Every phase preserves *observable behaviour*; "byte-identical" is a nice-to-have for pure-move phases,
but the real invariant is **the FujiBus/SLIP frames the ROM emits and the ROM-internal results** stay
the same for the same inputs. Tests — not byte diffs — are the source of truth, because feature
gating and the composable table will legitimately move bytes around.

### C.2 The suites and what each protects

| Suite | Where | Level | Protects |
|-------|-------|-------|----------|
| **beebium scripted** | `integration-tests/beebium/scripted/` | End-to-end over real serial+PTY, scripted `FujiDevice` mock | The **contract**: exact FujiBus frames per command (the README device-coverage matrix). Deterministic — **the primary merge gate (run locally)**. |
| **beebium real interop** | `integration-tests/beebium/real/` (opt-in) | Real posix `fujinet-nio`, asserts on firmware logs | Live interop; catches drift between ROM and firmware. Opt-in (needs the firmware binary). |

The scripted suite already covers Fuji/Clock/Modem/Disk/Network/File device traffic and the OSWORD
`&78` flows — i.e. precisely the seams this plan touches (network branch, `*FJSON`, `*FHOST`/`*FLS`,
mount). That makes it the primary guardrail.

### C.3 Coverage model: tag tests by required feature, run per build
Each test declares the feature it needs; the runner selects tests per build:

| Test class | Needs | Runs on `DISK` | `DISK+NET` | `ALL` |
|------------|-------|:---:|:---:|:---:|
| kernel/disk (`*FHOST`, `*FIN`, `*FMOUNT`, `*CAT`, OPENIN/BGET on disk files) | kernel | ✅ | ✅ | ✅ |
| network (`OPENIN "://"`, `*FJSON`, OSWORD `&78`) | `FEATURE_NET` | ❌ (assert **absent** — C.4) | ✅ | ✅ |
| transient management (`*FORM`, `*COPY`, `*FLS`, `*FDRIVE`) | boot/config disk **or** resident | from disk | from disk | resident |

The beebium runner already accepts `--fn-rom`/`FN_ROM` (and slot), so pointing it at each profile's
ROM is a one-liner; add a `--profile {disk,net,all}` (or marker) that selects the tagged subset.
`run_unit_tests.sh` gains the same build/profile arg.

### C.4 New scenarios the transition introduces (don't exist today)
1. **Negative / absence tests** (Phase 3): on `DISK`, the inputs that drive network traffic on
   `DISK+NET` must emit **no** network frames (and report the right "not available" behaviour). Today's
   suite only asserts presence.
2. **Unknown-command fallthrough** (Phase 3): an unrecognised `*command` with the current drive on an
   app disk resolves+runs a binary from the **library** drive (service &04 → MOS → FSC → library lookup).
3. **Command-from-disk equivalence** (Phase 4): mount `FN-UTLS.ssd`, set the library, run a migrated
   command (e.g. `*FLS`, `*FORM`) and assert it produces the **same** FujiBus frames / results as the
   resident version in `ALL`. This proves the transient path is behaviourally identical, not just that
   the file loads.
4. **Cold-boot auto-mount** (when Appendix A lands): on cold boot with the utils slot bound, the ROM
   mounts drive 3 + sets the library; on a *missing* boot/config disk it continues booting and leaves
   `fuji_lib_drive = 0` (Appendix A.3) — assert both.

### C.5 Running the gates: local now, CI later
**There is no GitHub CI for fn-rom yet — that is a future plan.** Through this transition, the test
gates are **run locally by the implementer before merging each phase**. The plan is structured so the
suites stay CI-ready, but nothing here blocks on CI existing.

- **Local toolchain (both pieces are the author's own):**
  - **beebium** — build the server(s) and wire the env vars per `integration-tests/beebium/README.md`
    (`BEEBIUM_HOME`, `FUJINET_TOOLS`, `FN_ROM`, …). Its serial support is a recently-submitted PR still
    being integrated upstream.
- **Future CI (when it comes):** provision the beebium build +
  `FUJINET_TOOLS`/`BEEBIUM_HOME` paths, build all three profiles, gate on `make sizes` + the
  feature-appropriate suite subset. (fujinet has its own automation scripts; out of scope here.)

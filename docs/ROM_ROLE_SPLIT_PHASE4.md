# Phase 4 — Transient utilities (Lever B) + utilities SSD

Per `docs/ROM_ROLE_SPLIT_PLAN.md` §5.1/§5.2/§5.5 / §6 Phase 4. Makes the management and
informational commands an optional, on-disk feature: `UTILITIES=resident` links them into the ROM
(`make all-rom`); `UTILITIES=disk` drops them from the ROM (they ship on `FN-UTLS.ssd` and load on
demand via the `*RUN` fallthrough).

## ROM-side lever (complete)

**Build (Makefile).** `UTILITIES ?= resident`. When `disk`, `src/utils/*.s` is filtered out of
`SOURCES` (cc65 omits the unlinked modules wholesale); `BUILD_VARIANT` gains a `-utld` suffix so
resident/disk objects never collide. The shipped-build targets pair the two levers:

| Target | FEATURE_NET | UTILITIES | Profile |
|--------|:-----------:|:---------:|---------|
| `make disk`    | 0 | disk     | DISK |
| `make net`     | 1 | disk     | DISK+NET |
| `make all-rom` (== bare `make all`) | 1 | resident | ALL |

> The bare `make all` is the ALL build (everything resident) so the default beebium suite stays green
> until the disk binaries exist; the lean shipped builds are `make net`/`make disk`.

**Composable table.** The 13 transient commands self-register into the `CMDSTR_<grp>_EXT` segments
from their `src/utils/` modules (`cmd_entry "FUJIFS_EXT"/"FUTILS_EXT", …`), exactly like FREE/MAP and
*FJSON. So they are absent from `cmd_tables.s` and **vanish from the command table** when their module
isn't linked — no `.if` in the table. Transient set:

- FUJIFS_EXT: `ACCESS COPY DESTROY FORM RENAME TITLE VERIFY WIPE` (+ `FREE`/`MAP` from cmd_free_map.s)
- FUTILS_EXT: `CD DRIVE LS LIST UNMOUNT OUT NEW`

`*INFO` stays **resident** (moved `cmd_info.s` to `src/kernel/commands/`): it has a resident FSCV hook
(`fscv10_starINFO` in the filing-vector table) and shares `cmd_info_loop` with the resident `*EX`, so
it cannot be cleanly transient. `*FORM`/`*VERIFY` share `cmd_verify_format.s`; both self-register.

## Verification

| Build | BBC ROM used / free | utils in ROM? |
|-------|--------------------:|:-------------:|
| ALL (`make all`)   | 15550 / 834  (== Phase 3) | yes |
| DISK+NET (`make net`)  | 13448 / 2936 | no (−2102 B) |
| DISK (`make disk`)     | **10788 / 5596** | no |

The DISK build is now **10788 B / 5596 free** — dropping NET (−2660 B) and UTILS (−2102 B) from ALL,
matching the Phase 0 projection (~4762 B reclaim) almost exactly.

- ALL build (resident): beebium scripted **19 passed, 4 skipped** — the transient commands now
  dispatch via the `_EXT` segments and behave identically (the FCD/FLS/FDRIVE/FNEW/FOUT tests exercise
  this). Equal to the Phase 3 baseline.
- `UTILITIES=disk` builds link no `src/utils` symbols and the transient commands are absent from the
  table (verified: e.g. `COPY` not in the ROM image).

## Bootstrap (Appendix A.5 Layer C — ready)

`dist/fn-utls/!BOOT` mounts the utils image as drive 3 and sets it as the library, so an unrecognised
`*command` resolves from there regardless of the current drive (the §4.2.1 mechanism, verified in
Phase 3: service &04 stays unclaimed → FS `*RUN` → library-aware lookup). Zero ROM cost.

## Remaining work — the disk binaries (the §5.5 ABI)

The on-disk *execution* of the utilities is the substantial remaining piece. The §5.5 import audit
shows the utilities pull in ~100 distinct kernel/disk code symbols (catalog ops, channel state,
FujiBus transport, formatting, parameter parsing, error handlers). To run as RAM-loaded `*RUN`
binaries they must reach the resident ROM only through **published entry points**:

1. **Resident ABI.** Add a fixed-address jump table (pinned in `cfg/fujinet-rom.cfg`, so it does not
   move between builds) exporting the helpers the utilities need — at minimum the FujiBus transport
   (`fujibus_send_packet`/`receive`/`set_payload_buffer_ptr`), catalog read/write, and a few shared
   printers/parsers. Per §5.5, helpers used *only* between transient utilities (e.g.
   `flist_resolve_target`, `confirm`) are duplicated into the binaries rather than promoted to the ABI.
   ZP workspace (`aws_tmp*`/`cws_tmp*`/`pws_tmp*`, `current_drv`, …) is already at fixed addresses via
   `os.s`, so the binaries reference it directly. The FS ROM is paged in when an `*RUN` command from
   the FS executes, so the binaries call the ABI by absolute `jsr`.
2. **Build target.** Assemble each `src/utils/*` command to a RAM load address against the ABI, emit a
   `<NAME>.inf` (load/exec) per command, and bundle into `FN-UTLS.ssd` via `scripts/create_ssd.py`
   (which already supports per-file `.inf`). Target: `make fn-utls`.
3. **Equivalence test (Appendix C.4 #3).** In beebium, mount `FN-UTLS.ssd`, set the library, run e.g.
   `*FLS`/`*FORM`, and assert the **same** FujiBus frames as the resident `ALL` build. A
   `needs_resident_utils` marker skips the existing util-command tests on `UTILITIES=disk` ROMs until
   this lands.

## Acceptance

- [x] `UTILITIES` lever: transient commands absent from ROM when `UTILITIES=disk`; `make all-rom`
      keeps them resident. Verified (sizes + table + beebium on ALL).
- [x] Bootstrap (`!BOOT` mount + `*LIB`) ready; library-aware `*RUN` route verified (Phase 3).
- [ ] Utilities run from the library-mounted disk with identical FujiBus frames — pending the resident
      ABI + `FN-UTLS.ssd` binaries + the equivalence test (see "Remaining work").

## Still gated by `.if` (Phase 5 cleanup)

`_ROMS_`/`_UTILS_` (ROMS command, UTILS help topic) and `_FREE_MAP_`.

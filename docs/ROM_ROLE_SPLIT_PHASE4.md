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

`utils-bin/!BOOT` mounts the utils image as drive 3 and sets it as the library, so an unrecognised
`*command` resolves from there regardless of the current drive (the §4.2.1 mechanism, verified in
Phase 3: service &04 stays unclaimed → FS `*RUN` → library-aware lookup). Zero ROM cost.

## Disk-binary execution (implemented, proven on *FDRIVE)

The utilities run from disk by linking against the resident ROM at its **actual addresses** — no
hand-written ABI jump table needed:

1. **rom_abi from the ROM .lbl.** `scripts/build_fn_utls.sh` builds the `UTILITIES=disk` ROM, then
   turns its label file into `rom_abi.s` (`name = $addr` for every resident symbol; ZP via
   `.exportzp`). The binaries are built against the exact ROM they will run with.
2. **RAM binaries.** Each command is assembled for `$1900` (`cfg/fn-util.cfg`) with `FN_UTIL_BINARY`
   defined (so `cmd_entry` emits no ROM table fragment), and linked with `rom_abi.o` so its kernel/disk
   imports resolve to ROM addresses. Utils-internal helpers it shares (e.g. `cfl_print_formatted_blob`)
   are linked in from their `src/utils/` source per §5.5. A tiny entry wrapper (`utils-bin/<cmd>.s`)
   sets up the command line and calls the resident handler; it exits via `exit_user_ok`. The FS ROM is
   paged in when an `*RUN` command from the FS executes, so the binary calls the ROM by absolute `jsr`.
3. **FN-UTLS.ssd.** `create_ssd.py` bundles the binaries (per-file `.inf` load/exec `$1900`) + `!BOOT`.

**Equivalence test (Appendix C.4 #3) — passing.** `scripts/run_fn_utls_test.sh` builds the SSD + ROM
and runs `scripted/test_command_from_disk.py`: with `*FDRIVE` absent from the ROM, mounting `FN-UTLS.ssd`
and typing `*FDRIVE` loads+runs the disk binary, which emits the **same Fuji GET_MOUNTS frame** as the
resident command. **1 passed** — the disk-loaded utility behaves identically.

## Acceptance

- [x] `UTILITIES` lever: transient commands absent from ROM when `UTILITIES=disk`; `make all-rom`
      keeps them resident. Verified (sizes + table + beebium on ALL).
- [x] Bootstrap (`!BOOT` mount + `*LIB`) ready; library-aware `*RUN` route verified (Phase 3).
- [x] A utility (`*FDRIVE`) runs from the mounted disk with **identical FujiBus frames** to the
      resident command (build mechanism + equivalence test, proven end-to-end).

## Generalising to the other commands

The mechanism is proven; the remaining commands are mechanical: add a `utils-bin/<cmd>.s` wrapper and a
`build_one` line in `scripts/build_fn_utls.sh`. The only per-command nuance is **argument passing** —
`*FDRIVE` takes none, so its wrapper points the GSINIT pointer at an empty line; commands with args
(`*COPY`, `*FORM`, …) need the wrapper to point `text_pointer` at the `*RUN` command tail
(`fuji_text_ptr_hi`/`fuji_text_ptr_offset`) before calling the handler. The existing util-command
beebium tests run on the resident `ALL` build (where the commands are in ROM); a `needs_resident_utils`
marker would skip them on `UTILITIES=disk` ROMs.

## Still gated by `.if` (done in Phase 5)

`_ROMS_`/`_UTILS_` (ROMS command, UTILS help topic) and `_FREE_MAP_` were retired
in Phase 5 — folded into the `UTILITIES_RESIDENT` lever / the `src/utils/`
location. See `docs/ROM_ROLE_SPLIT_PHASE5.md`.

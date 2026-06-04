# Phase 5 — Consolidate test matrix, docs, examples (results)

Per `docs/ROM_ROLE_SPLIT_PLAN.md` §6 Phase 5 / Appendix C. Goal: make the build ×
test matrix runnable locally with one command, retire the last legacy macros,
update the docs, and ship the DISK+NET distributable (ROM + `FN-UTLS.ssd` + the
`bas/` examples).

## Macro cleanup (retire `_FREE_MAP_`/`_UTILS_`/`_ROMS_`)

- Dropped the `FREE_MAP` make var and the `_FREE_MAP_`/`_UTILS_`/`_ROMS_` asm/C
  defines from the Makefile.
- `*FREE`/`*MAP` (`src/utils/cmd_free_map.s`) lost their `.if .defined(_FREE_MAP_)`
  wrapper. They are now ordinary `src/utils/` modules: resident under
  `UTILITIES=resident`, transient otherwise — governed by the lever + location
  alone, no per-command `.if`.
- `*ROMS` and the UTILS `*HELP` topic (still `rts` stubs / future work) now hang
  off `UTILITIES_RESIDENT` instead of being unconditionally defined for BBC. This
  fixed a latent bug where they stayed in the command table even in the lean
  `make disk` / `make net` builds.
- Net effect on the ALL build: FREE/MAP become resident (as intended for the
  kitchen-sink build). ROM = **15981 / 403 free**, still within budget.

## Utils-disk build fix

The mid-commit had deleted `dist/fn-utls/!BOOT`, which `scripts/build_fn_utls.sh`
needs — and `dist/` is wiped by `make clean` (`DIST_DIR`), so committing sources
there was unsafe. The `!BOOT` + `README.md` now live in the `utils-bin/` source
tree; the script and Phase 4 doc were updated. `FN-UTLS.ssd` now rebuilds after
`make clean`.

## One-command build × test matrix (C.3)

- **`run_tests.sh`** (new, repo root): builds all three profiles, runs
  `make sizes`, the soft65c02 unit tests, then the beebium scripted matrix.
  `--no-beebium` for a builds-only run.
- **`run_unit_tests.sh`**: takes an `all|net|disk` profile arg (selects the ROM
  the harness assembles against) and skips cleanly when `soft65c02_unit` is
  absent.
- **`integration-tests/beebium/run_profile_tests.sh`**: extended from `net`/`disk`
  to `all`/`net`/`disk` plus the FN-UTLS command-from-disk equivalence test, and
  clears a stale PTY symlink left by a killed run (the cause of intermittent
  `wait_for_command` timeouts).

### Coverage model (tag by feature, run per profile)

`conftest.py` gained the `needs_resident_utils` marker and a third `--fn-profile`
value, `all`. The transient management/informational command tests
(`*FDRIVE`/`*FLS`/`*FCD`/`*FNEW`/`*FOUT`) are marked `needs_resident_utils`, so:

| Profile | `--fn-profile` | needs_net | needs_resident_utils | disk_only |
|---------|----------------|:---------:|:--------------------:|:---------:|
| ALL      | `all`  | run | run | skip |
| DISK+NET | `net`  | run | skip (transient → command-from-disk test) | skip |
| DISK     | `disk` | skip | skip | run |

## Docs

- `README.md` — build profiles, the three targets, `make release`, the test
  matrix.
- `AGENTS.md` — role-split source layout + profile table + "don't reintroduce the
  retired macros".
- `docs/fn-rom-bootstrap.md` — role-split table, fixed the stale `src/commands/`
  path, and documented the **transient-utility ROM ABI** (utilities are RAM
  binaries linked against the resident ROM's actual symbol addresses via
  `rom_abi.s`; the ABI is the set of resident symbols a utility imports).
- `docs/ARCHITECTURE.md` — role-split layering section.
- `integration-tests/beebium/README.md` — the per-profile marker/skip matrix.

## Release bundle (ship FN-UTLS.ssd + bas/ examples)

`make release` (alias `make dist`) → `scripts/build_release.sh` stages
`dist/release/`:

- `FN-NET` / `FN-NET-M` — the DISK+NET ROM for BBC and Master.
- `FN-UTLS.ssd` — the transient utilities.
- `examples/<app>.ssd` — bundled `bas/` apps (default: `weather iss net fcs`;
  override with `RELEASE_APPS=…`).
- `README.txt` — what each file is + the utils-disk bootstrap.

## Verification

Full matrix, clean run:

| Profile | Result |
|---------|--------|
| `[all]`  | 19 passed / 5 skipped |
| `[net]`  | 11 passed / 13 skipped |
| `[disk]` | 7 passed / 17 skipped |
| `[utls]` command-from-disk | 1 passed |

All three profile ROMs build for BBC + Master. The intermittent failures seen
during bring-up were a stale `/tmp/fujinet-pty-e2e` symlink (left by
`timeout`-killed runs), not a regression — confirmed by a HEAD-vs-change
full-suite comparison (both 19 passed) and now guarded against in the runner.

## Transient utility binaries — all commands (generalised)

Phase 4 proved the disk-binary mechanism on `*FDRIVE` only; Phase 5 generalised it
to every transient command. `scripts/build_fn_utls.sh` now builds them all from a
single generated wrapper:

- **Leaf names = the full typed command.** The FS `*RUN` reads the leaf from the
  *start* of the command line (`read_fspba` rewinds to offset 0), so the file it
  looks up is the full name including any leading F (`*FDRIVE`->`FDRIVE`,
  `*COPY`->`COPY`). Earlier guesses at an F-stripped leaf were wrong.
- **7-char DFS limit -> `*FUMOUNT`.** `*FUNMOUNT` (8 chars) cannot be a DFS leaf,
  and truncating to `FUNMOUN` desyncs argument parsing, so the unmount command was
  renamed `*FUMOUNT` (registered `"UMOUNT"`). All transient command names are <=7.
- **Two wrapper modes.** No-arg commands (`*FDRIVE`) point the GSINIT pointer at an
  in-binary empty line; arg commands point `text_pointer` at the `*RUN` tail
  (`fuji_text_ptr_*`) so the handler parses arguments exactly as when resident.
- **Shared helpers** used only between utilities (e.g. `confirm`,
  `flist_resolve_target`, `cmd_flist`) are linked into the binaries that need them.

Verified by `scripted/test_command_from_disk.py` (run via `scripts/run_fn_utls_test.sh`):
every command resolves+runs from `FN-UTLS.ssd` (no "Bad command"/"Bad string"),
`*FCD <path>` shows arguments reach the handler, and `*FDRIVE` emits frames
identical to the resident command. **19 passed.**

`*FORM`/`*VERIFY` are still ROM-side stubs (`rts`), so their binaries are stubs too
— implementing them is fujinet-side work, unrelated to the role split.

## Remaining / optional

- CI: the matrix is kept CI-ready but there is no GitHub CI yet (out of scope).
</content>
</invoke>

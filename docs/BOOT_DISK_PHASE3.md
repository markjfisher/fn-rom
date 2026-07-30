# Phase 3 — Optional network feature + service-&04/library verification

Per `docs/BOOT_DISK_PLAN.md` §5.1/§5.4 / §6 Phase 3. Makes the network device an
optional, additive feature: `FEATURE_NET=1` (default) is the DISK+NET build; `FEATURE_NET=0`
is the DISK build with no network open path, no `*FJSON`, and no OSWORD &78.

## Mechanism

**Build (Makefile).** `FEATURE_NET ?= 1`. When on, `--asm-define FEATURE_NET` and `src/net/` is
linked. When off, `src/net/*.s` is filtered out of `SOURCES` (cc65 omits the unlinked modules
wholesale) and nothing is defined. `BUILD_VARIANT` gains a `-disk` suffix so net-on/off objects
never collide. Convenience targets: `make disk` / `make net` / `make all-rom`.

**Network branch hook (§5.4).** Disk is always resident, so only the *network* branch in the shared
filing vectors is optional. Each network branch is gated `.if .defined(FEATURE_NET)`:

| Vector | Decision gated | Body gated |
|--------|----------------|------------|
| OSFIND open (`findv_entry.s`) | `fuji_network_url_flag` test + `jmp network_open_file` | `network_open_file` + `network_release_channel_y` + `network_allocate_channel` |
| OSFIND close (`findv_entry.s`) | handle test + `bne close_network_channel` | `close_network_channel` / `error_closing` (shared `close_file_exit`/`no_flush_error` kept) |
| OSBGET (`bgetv_entry.s`) | handle test + `bne network_bget` | `network_bget` (shared `err_eof` and disk helpers kept) |
| OSBPUT (`bputv_entry.s`) | handle test + `jmp network_bput` | `network_bput` / `network_flush_write` |

When off, the decision branches are absent so every vector falls straight through to its disk path,
and the gated bodies (with their `.export`s and `src/net` `.import`s) are not assembled — so nothing
references `src/net`. The `fuji_network_url_flag` set in `disk/fs_functions.s` stays (harmless: a URL
just fails as a bad disk filename), and `network_retry_*` in `kernel/utils.s` is left as small dead
code (Phase 5 cleanup).

**OSWORD &78 (`service08.s`).** The whole handler is gated; off → service 08 claims nothing.

**`*FJSON`.** Removed from `cmd_tables.s`; it now self-registers into `CMDSTR_FUTILS_EXT` from
`src/net/cmd_fjson.s` via `cmd_entry` (same Phase 1 mechanism as FREE/MAP). Present iff `src/net` is
linked — no `.if` in the command table.

## service-&04 / library-aware `*RUN` (verified)

- **Unrecognised command leaves service &04 unclaimed.** The ROM-service route (fs → utils) ends at
  `not_cmd_utils: rts` (`kernel/commands/commands.s`) inside `remember_axy`, which restores A on exit
  → A returns unchanged → MOS treats service 04 as unclaimed and continues (other ROMs, then the FS).
- **The FS-run route is library-aware.** When fn-rom is the active FS, the unrecognised-command route
  (`fscv3_unreccommand` → fujifs → futils → `not_cmd_futils` = `fscv2_4_11_starRUN`, `cmd_run.s`) looks
  up the command file in the current drive/dir, then falls back to `fuji_lib_drive`/`fuji_lib_dir`
  (the §4.2.1 library mechanism). Pre-existing and preserved through Phases 1–3.

The end-to-end library-fallthrough beebium test (a util resolved from the library drive while the
current drive is the app disk) lands with the utils SSD in Phase 4 (Appendix C.4 #3 is Phase 4 scope).

## Test parameterisation (Appendix C.3)

`conftest.py` gains `--fn-profile {net,disk}` (env `FN_PROFILE`). Tests are feature-tagged:
`needs_net` (skipped on the disk profile) and `disk_only` (skipped on net). `test_network_device.py`
is `needs_net`; new `test_disk_profile.py` is `disk_only` and asserts the **absence** of network
behaviour. `run_profile_tests.sh` builds each ROM and runs the matching subset.

## Verification

| | DISK+NET (`FEATURE_NET=1`) | DISK (`FEATURE_NET=0`) |
|---|---|---|
| beebium scripted | 19 passed, 4 skipped (== Phase 2 baseline) | 15 passed, 8 skipped, **0 failed** |
| network frames for OPENIN URL / `*FJSON` | emitted | **none** (negative tests green) |
| `*FJSON` | present | absent |
| BBC ROM used / free | 15550 / 834 | **12890 / 3494** |
| Master ROM used / free | 15586 / 798 | 12926 / 3458 |

The DISK build reclaims **2660 B** vs DISK+NET — the `src/net` modules *and* the network branch in the
shared vectors (the Phase 0 "vectors-mixed" net bytes), confirming §5.4.

## Acceptance

- [x] DISK build has no network open path (0 `src/net` symbols linked; vectors fall through to disk).
- [x] `*FJSON` present only in NET builds.
- [x] DISK+NET matches ALL network behaviour (19/2 unchanged); DISK smaller than ALL.
- [x] Negative tests green (DISK emits no network frames for the same inputs).
- [x] service-&04 unclaimed → FS `*RUN` with library-aware lookup (verified by inspection).

## Still gated by `.if` (Phase 5 cleanup)

`_ROMS_`/`_UTILS_` (ROMS command, UTILS help topic). The UTILITIES setting (transient utilities on
disk) is Phase 4; until then DISK+NET == ALL.

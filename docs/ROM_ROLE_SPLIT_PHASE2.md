# Phase 2 — Source reorg into kernel/disk/net/utils (results)

Per `docs/ROM_ROLE_SPLIT_PLAN.md` §5.2 / §6 Phase 2. Goal: express feature membership by source
*location*, so later phases can compose `SOURCES` from selected directories. Pure move — everything
is still compiled (≈ the `ALL` build), so behaviour (and ROM size) is unchanged.

## New layout (`src/`)

| Dir | Contents | Built |
|-----|----------|-------|
| `src/kernel/` | transport (`fujibus`, `fuji_link_slip`, `fuji_data_fujibus`), channel (`serial/`, `fuji_serial`, `fuji_userport`), init (`fuji_init`), matcher/help (`services/`, `help`), Fuji device builder (`fujibus_fuji`), shared MOS filing-vector shells (`vectors/`), and resident/bootstrap commands (`commands/`: `cmd_fhost`/`cmd_fin`/`cmd_fmount`, `cmd_run`, `cmd_drive`, `cmd_dir_lib`, `cmd_tables`, `cmd_enable`, `cmd_ex`, `cmd_opt`, `cmd_delete`, `commands`), plus core (`os`, `print_utils`, `remember_axy`, `rom_header`, `service`, `spool`, `user_flag`, `utils`, `workspace_utils`, `channels`, `crc7`, `fuji_host`) | always |
| `src/disk/` | catalog + sector IO (`fs_functions`, `fujibus_disk`, `fuji_mount`, `fuji_fs`, `cmd_cat`) and the disk-side vector files (`vectors/fastgb`, `vectors/gbpb_functions`, `vectors/filev/*`) | always |
| `src/net/` | `fnnet.s` (+ `fnnet/` reason includes), `fujibus_network.s`, `cmd_fjson.s` (OSWORD &78 network ABI + builders + `*FJSON`) | Phase 3: when `FEATURE_NET` |
| `src/utils/` | transient management + informational commands (`cmd_copy`, `cmd_wipe`, `cmd_destroy`, `cmd_rename`, `cmd_access`, `cmd_title`, `cmd_info`, `cmd_fs_fnew`, `cmd_fout`, `cmd_funmount`, `cmd_free_map`, `cmd_verify_format`, `confirm`, `cmd_fcd`, `cmd_flist`, `cmd_fdrive`, `flist_resolve_target`) | Phase 4: when `UTILITIES_RESIDENT` |
| `src/inc/` | shared includes (`fujinet.inc`, `macros.inc`, `os.inc`) — unchanged include dir | n/a |

The shared filing-vector shells (`findv_entry`, `bgetv_entry`, `bputv_entry`, `filev_entry`,
`filing_vectors`, `argsv_entry`) stay in `src/kernel/vectors/` for now — they carry the disk *and*
network branches in one module; the network branch is extracted to `src/net/` in Phase 3 (§5.4).

## No Makefile / import changes needed

- `SOURCES` uses `rwildcard` over `src/`, so the new subdirectories are discovered automatically;
  everything is still compiled.
- ca65 resolves `.include` relative to the including file's directory first, so moving `fnnet.s`
  together with its `fnnet/` include dir into `src/net/` needed no `--asm-include-dir` change. The
  shared includes still resolve via `--asm-include-dir src/inc`.
- `.import`/`.export` are link-time global symbols, independent of file location, so a pure move needs
  no import-list edits. (The Phase 3/4 splits will; that's when `scripts/clean_imports.py` earns its
  keep.)

The conditional `SOURCES` composition (compile `net/` only with `FEATURE_NET`, `utils/` only with
`UTILITIES_RESIDENT`) is Phase 3/4 work; Phase 2 keeps the rwildcard-all.

## Verification

- Builds clean: BBC, Master (`make all-machines`), and `FREE_MAP=1` (cmd_free_map now under `src/utils/`).
- **beebium scripted suite: 19 passed, 2 skipped** — identical to the Phase 0 golden baseline.
- **ROM size unchanged** vs Phase 1 (BBC 15550 / 834 free; Master 15586 / 798 free) — same code, only
  the link order shifted with the directory traversal. This is the "ALL byte-identical / trivially
  close" acceptance: the git diff is renames only.

## Acceptance

- [x] Files moved into `kernel/disk/net/utils` (§5.2); diff is renames only.
- [x] Still all-compiled (≈ `ALL`); ROM size identical to Phase 1.
- [x] beebium scripted suite green (emitted FujiBus frames unchanged).

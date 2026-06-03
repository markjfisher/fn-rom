# Phase 0 — Measure & baseline (results)

Captured per `docs/ROM_ROLE_SPLIT_PLAN.md` §6 Phase 0. This is the **green baseline** every
later refactor phase must preserve, plus the documented byte budget that sizes the three builds.

> Toolchain note (rev): the soft65c02 unit suite has been **dropped as a gate** for this transition —
> those tests are out of date and too brittle. The **beebium scripted suite is the merge gate**.

## 1. Size baseline (`make sizes`, clean `make all-machines`)

MAIN sideways-ROM region: `$8000–$BFFF` = 16384 bytes.

| Build (today's branch) | End | USED | % | FREE |
|------------------------|-----|-----:|--:|-----:|
| BBC (`fujinet.rom`)    | `$BCD1` | 15570 | 95.0% | 814 |
| Master (`fujinet-master.rom`) | `$BCF5` | 15606 | 95.3% | 778 |

### Feature subtotals (map-derived per-module attribution)

| Group | BBC | Master | Notes |
|-------|----:|-------:|-------|
| kernel        | 5109 | 5138 | always-resident core (transport, channel, init, matcher, bootstrap) |
| disk          | 4322 | 4322 | catalog + sector IO + disk vector branch (always resident) |
| vectors-mixed | 2191 | 2198 | shared MOS filing-vector shells: kernel + disk **+ net** branch in one module |
| net           | 1951 | 1951 | `fujibus_network` 1417 + `fnnet` 363 + `cmd_fjson` 171 — **cleanly separable** |
| utils         | 1997 | 1997 | transient management/informational commands — **cleanly separable** |
| **TOTAL**     | **15570** | **15606** | equals USED ⇒ attribution is complete, nothing hidden |

## 2. Projected builds (Phase-0 estimate — BBC)

Cleanly-separable modules only, so these are a **lower bound on reclaim**:

| Build | Drops | USED | FREE |
|-------|-------|-----:|-----:|
| **ALL** (today) | — | 15570 | 814 |
| **DISK+NET** (default) | UTILS (−1997) | 13573 | 2811 |
| **DISK** | UTILS + NET (−3948) | 11622 | 4762 |

⚠️ **Lower bound, not final.** The net branch living *inside* the shared filing vectors is counted in
`vectors-mixed` (2191 B) and is **not** reclaimed by gating alone — it needs the Phase 2 source split
before a `DISK` build sheds it. Real DISK free space will exceed 4762 B once Phase 2 lands.

## 3. §2.5 confirmation — cc65 dead-strips whole unreferenced modules

Empirical, in-tree, non-destructive: in the default build `cmd_free_map.o` **is on the link line** but
the command is unreferenced (gated behind `_FREE_MAP_`). Its contribution in `build/fujinet.rom.map`
is **0 bytes** — ld65 omitted the whole module.

- **Confirms (the mechanism this plan relies on):** a feature that is an *unlinked / unreferenced
  object module* costs **zero** ROM bytes. This is what makes §5.2 (feature = directory of modules
  selected into `SOURCES`) work without any `.if` inside shared files.
- **Limitation (why Phase 2 is necessary):** ld65 does **not** strip unreferenced *code inside* a
  module that is otherwise linked. The network branch currently shares an object module with the
  kernel/disk filing vectors (`vectors-mixed`), so gating `FEATURE_NET` alone cannot reclaim it — the
  net branch must first be moved into its own `src/net/` module (Phase 2/3).

## 4. Behavioural golden baseline — beebium scripted suite

`cd integration-tests/beebium && uv run pytest scripted/ -v` against current HEAD ROM:

```
19 passed, 2 skipped in 168.44s
```

- **Passed:** disk (cat/fnew/fmount/fout), file (fhost/fcd/fls), fuji (fdrive/fin/fout),
  network (OPENIN, BGET/close cycle, `*FJSON` translate, OSWORD &78 reasons 00–04), serial e2e.
- **Skipped (expected):** clock (0x45) and modem (0xFB) — fn-rom emits no FujiBus traffic to those
  devices yet; these are not regressions.

This is the exact-frame contract later phases must keep identical (Appendix C.1). In particular the
network tests here become the **Phase 3 positive set**, and their inputs become the **negative set**
asserting the `DISK` build emits no network frames.

## 5. Acceptance

- [x] `make sizes` implemented and reports both ROMs.
- [x] Byte budget per feature/build documented (§1–2 above).
- [x] §2.5 dead-strip behaviour confirmed empirically (§3).
- [x] Green beebium scripted baseline captured (§4).

# Dominic's PR #1 integration

Branch: `review/dominic-pr1`, based on `5327b8cf`.
Source: https://github.com/markjfisher/fn-rom/pull/1, head `2ad6c13b`.

## Disposition

| Original commit | Decision |
|---|---|
| 6909b933 | Retain: 16-bit network reply length and 255-byte BGET request |
| b5e270c5 | Retain Pi1MHz link; omit fuji_host.s change because that module was removed |
| 8f7e1c29 | Historical merge; no separate change required |
| 30fc3ace | Retain Pi1MHz settling delays, cleared reply length and Escape handling |
| 524ac6cd | Retain bounded network payload copy |
| 08c4ed3e | Retain correct 16-bit scatter length addition |
| 21abaa9c | Already fixed by 70397a3c |
| 1a5fdbe2 | Retain network OSGBPB byte path |
| ea1349ee | Already fixed by ec6cf299 |
| 6d2bdd66 | Retain interface-aware boot build and direct DFS image writer |
| 923ca303 | Retain empty-file ordering and sector-count validation |
| 2d9a33cb | Retain partial-sector write pointer preservation |
| cc012ff6 | Retain full-width BGET buffer-position check after seeking |
| acf5775b | Already fixed by 65cf0c20 |
| 17325632 | Already fixed by 355a163a |
| 2ad6c13b | Already implemented by 354e748d |

Keep current ROM architecture, recent bulk-read APIs, Beebium launch fixes and
utility ABI. Do not resurrect the removed host module or replace current
integration fixtures with the older PR versions. Unit-runner conflicts were
resolved by retaining current tests and adding the new cases once.

## Verification and limits

- Full soft65c02 ROM unit suite passes with the added network/OSGBPB cases.
- Pi1MHz BBC and Master ROMs build, and the Pi1MHz FN-BOOT image builds.
- Pi1MHz timing has NOT been independently hardware-validated here. It retains
  Dominic's reported settling delays and must be checked on his Pi1MHz setup.
- The new network bounds handling clamps malformed lengths rather than raising
  a new error; this follows the contributed behavior and prevents over-copying.
- The serial emulator suite is run separately; results recorded below.

## Pi1MHz build and hardware handoff

Source the workspace environment first. Object paths are machine-specific but
not interface-specific, so clean when switching interfaces:

```sh
make clean
make BUILD_INTERFACE=1MHZ BUILD_MACHINE=BBC all
BUILD_INTERFACE=1MHZ BUILD_MACHINE=BBC scripts/build_fn_boot.sh
# For a Master, use BUILD_MACHINE=MASTER for both commands.
```

Use the resulting machine-specific ROM and its matching `build/FN-BOOT.ssd`.
The link uses Pi1MHz service registers at &FCA6–&FCAA and command 114; it
exchanges FujiBus packets directly rather than carrying serial SLIP bytes.
The existing SLIP-named entry points are retained as the internal link ABI.

Boot-utility lane: `scripts/run_fn_boot_test.sh` — 32 passed.

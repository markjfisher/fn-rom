# FN-UTLS — transient utilities disk (role-split Lever B)

When fn-rom is built with `UTILITIES=disk` (the `make disk` / `make net` shipped builds), the
management and informational commands are **not** in the ROM. They live here, on `FN-UTLS.ssd`, and
load on demand via the MOS unrecognised-command → FS `*RUN` fallthrough (see
`docs/ROM_ROLE_SPLIT_PLAN.md` §2.4, §4.2.1, §5.5).

## Bootstrap (Appendix A.5 Layer C — `!BOOT`, zero ROM cost)

`!BOOT` mounts this image as a drive and makes it the **library**, so an unrecognised `*command`
(e.g. `*FORM`) resolves from here regardless of the current drive:

```
*FHOST sd0:/
*FIN 7 fn-utls.ssd      ; bind the utils image to slot 7
*FMOUNT 7 3             ; mount slot 7 as BBC drive 3
*LIB :3                 ; library = drive 3
```

Run it with `*OPT 4,3` set on the boot disk, or copy these lines into your own boot disk's `!BOOT`.
A future ROM auto-mount (Appendix A) can do this at cold boot instead.

## Contents (when built)

The transient commands, each a standalone BBC binary with its own load/exec (`.inf` sidecar), built
from `src/utils/` against the resident ROM ABI:

  FORM VERIFY ACCESS TITLE INFO RENAME COPY WIPE DESTROY FREE MAP   (DFS management)
  FCD  FLS    FDRIVE FOUT  FNEW FUNMOUNT                            ("F" navigation/mount admin)

> **Status:** the bootstrap above is ready. The command **binaries** are pending the resident ABI
> (the published entry points the §5.5 audit identified, ~the kernel/disk helpers the utilities call)
> — see `docs/ROM_ROLE_SPLIT_PHASE4.md` "Remaining work".

# FN-BOOT — boot disk

Management and informational commands are **not** in the ROM. They live here, on
`FN-BOOT.ssd`, and load on demand via the MOS unrecognised-command -> FS `*RUN`
fallthrough.

## Bootstrap

`!BOOT` restores the configured boot image as drive 3 and makes it the
**library**, so an unrecognised `*command` (e.g. `*FORM`) resolves from here
regardless of the current drive:

```
*FBOOT 3
*LIB :3
```

Run it with `*OPT 4,3` set on the boot disk, or copy these lines into your own boot disk's `!BOOT`.

## Contents (when built)

`scripts/build_fn_boot.sh` builds every transient command as a standalone BBC binary (load/exec
`$1900`, `.inf` sidecar), linked from `src/utils/` against the resident ROM at its actual symbol
addresses. Each is staged under the full command name the FS `*RUN` looks up (`*FDRIVE` -> `FDRIVE`,
`*COPY` -> `COPY`, ...). DFS leaf names are <= 7 chars, which is why the unmount command is `*FUMOUNT`:

  FORM ACCESS TITLE RENAME COPY WIPE DESTROY FREE MAP          (DFS management)
  FDRIVE FCD FLS FLIST FOUT FNEW FUMOUNT                       ("F" navigation/mount admin)

`*FORM` recreates the writable SSD currently mounted in a BBC drive after
confirmation. Traditional physical-media `*VERIFY` is intentionally not
provided for virtual disk images. The wrapper sets
the GSINIT pointer to the `*RUN` argument tail (`fuji_text_ptr_*`) before entering the resident
handler, so the disk-loaded command sees its arguments exactly as the resident command would —
verified by `integration-tests/beebium/scripted/test_command_from_disk.py`.

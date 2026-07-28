# Issues with split rom

*FLS after a while runs whatever is in &1900, so runs *FDRIVE if that was already loaded.
Usually when you're on *DRIVE 0, and *LIB is :3.$

Sequence:

```
*FMOUNT 7 3
*. :3   # lists drive 3's files (fn-boot.ssd)
*LIB :3

*FDRIVE
No disk        # why? because nothing in drive 0

*:3.FDRIVE   # works, loads and runs FDRIVE in 1900

*RUN FLS
No disk       # again, nothing in drive 0, not searching *LIB
Bad program   # doesn't go through $1900, not sure why it errors. Maybe this is the error return of RUN?

*RUN :3.FLS   # BAD: Runs FDRIVE from 1900, without loading FLS at all
*.
No disk
Bad program   # Same as *RUN FLS above

*DRIVE 3
*FLS          # BAD: runs FDRIVE from 1900 without loading FLS from disk
*.
*FLS          # GOOD: loads and runs FLS, prints "No Host"
*FHOST host:/
*FLS          # GOOD: lists files on host:/
*FDRIVE       # GOOD: loads and runs FDRIVE
*DRIVE 0
*.            # Bad drive
*:3.FLS       # BAD: does not load FDRIVE, so loads whatever is in 1900, which is FDRIVE

*FIN 0 iss.ssd
*FMOUNT 0 0
*.            # GOOD: lists files on iss.ssd in drive 0
*:3.FLS       # GOOD: loads FLS into 1900 from disk 3 and lists files, unlike last time
*:3.FDRIVE    # GOOD: loads and runs FDRIVE from 1900
*FLS          # Still not being found on *FLIB :3
Bad string
Bad program
*:3.FLS       # GOOD: loads and runs FLS at 1900
*RUN FLS      # Errors with Bad string, Bad program.
*RUN :3.FDRIVE  # GOOD: despite *FLS being last program loaded, this does load in FDRIVE and run it.

```

Conclusions?
Is it only working when drive 0 has something in?
Why is *LIB never working? Does the lib drive get overwritten?

## Resolution (root cause + fix)

Root cause is in the `*RUN` / unknown-command-from-disk path (`not_cmd_futils` in
`src/kernel/commands/cmd_run.s`). When the file is not found on the current drive,
the library fallback **re-parsed** the filename with `read_fspba`. That re-parse
runs the MOS `GSREAD` loop, and `GSREAD` corrupts the ROM's zero-page scratch —
specifically the command-line source pointer `aws_tmp10/11` (&BA/&BB) and
`current_drv` (&CD). So the second parse read a garbage pointer (observed
`aws_tmp10/11 = &0112`, i.e. the stack) and the drive it had just set to the
library was wiped. Net effect:

- **`*LIB` "never works":** the lib drive *was* stored correctly, but the
  re-parse clobbered `current_drv` straight back, so the library was never read.
- **"only works when drive 0 has something in":** the clobber leaves
  `current_drv = 0`, so the lookup always hit drive 0. If the wanted file happened
  to be on drive 0 it worked; otherwise it ran whatever stale bytes were at &1900
  (e.g. the previously-loaded `FDRIVE`), or errored (`Bad string`/`Bad command`).

**Fix:** the first attempt already parses the name into `fuji_filename_buffer`,
and `get_cat_firstentry81` matches against that buffer directly (it does *not*
re-read the command line). So the library fallback must **not** re-parse — it just
points `directory_param`/`current_drv` at the library and searches again. The
catalog match never calls `GSREAD`, so those values survive.

Verified end-to-end in beebium:
`integration-tests/beebium/scripted/test_command_from_disk.py::test_transient_command_resolves_via_library_drive`
(current drive = app disk without the util, util resolved from the library drive),
covering `*FLS`, `*RUN FLS`, `*:3.FLS` and `*RUN :3.FLS`.

> Note: a related latent issue remains for an **explicit** drive prefix whose
> drive differs from the library (e.g. `*RUN :2.FOO` where the file is only on
> drive 2 and `*LIB` is not `:2`). The same `GSREAD` clobber of `current_drv`
> means the explicit drive is lost after parsing; it currently only resolves
> because the library fallback then covers it. Fixing that fully means making
> `current_drv` survive `GSREAD` (e.g. relocating it off the MOS-corrupted ZP, or
> writing it after the final `GSREAD`), which is out of scope for this fix.

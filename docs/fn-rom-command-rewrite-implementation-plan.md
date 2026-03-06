# fn-rom FujiNet-NIO Command Rewrite Implementation Plan

## Scope

This plan translates the rewrite goals from [`fn-rom-command-rewrite.md`](../../bbc/fn-rom/docs/fn-rom-command-rewrite.md) into an execution-ready work list for the fn-rom source tree.

Primary intent:

- remove legacy host-slot handling from fn-rom command behavior
- align mount and traversal commands with FujiNet-NIO URI-based filesystem selection
- preserve BBC ROM constraints documented in [`fn-rom-bootstrap.md`](../../bbc/fn-rom/docs/fn-rom-bootstrap.md)
- leave no TODO markers in delivered code

## Current Findings

### Legacy host assumptions still present

- [`cmd_fs_fhost`](../../bbc/fn-rom/src/commands/cmd_fhost.s) still implements host listing, host index selection, and host URL assignment.
- [`current_host`](../../bbc/fn-rom/src/os.s) is still exported as a persistent command state alias.
- [`fujibus_host.s`](../../bbc/fn-rom/src/fujibus_host.s) appears to retain the old host-management transport path.

### DiskService integration exists but mount payload is incomplete

- [`fujibus_disk.s`](../../bbc/fn-rom/src/fujibus_disk.s) already targets DiskService device `0xFC`.
- [`fn_disk_mount`](../../bbc/fn-rom/src/fujibus_disk.s) still contains a placeholder comment for URI serialization and does not yet emit the request format described in [`disk_device_protocol.md`](../../../atari/fujinet-nio/docs/disk_device_protocol.md).

### Command table needs new alias surface

- [`cmd_table_futils`](../../bbc/fn-rom/src/commands/cmd_tables.s) currently exposes `HOST`, `IN`, and `RESET`.
- `HOST` and `FS` should coexist as aliases and both map to [`cmd_fs_fhost`](../../bbc/fn-rom/src/commands/cmd_fhost.s).

### fujinet-nio side is ready for URI-based access

- [`disk_device_protocol.md`](../../../atari/fujinet-nio/docs/disk_device_protocol.md) defines full-URI mounting on DiskService.
- [`file_device_protocol.md`](../../../atari/fujinet-nio/docs/file_device_protocol.md) defines URI-mode filesystem traversal when `fsNameLen == 0`.
- [`filesystem.md`](../../../atari/fujinet-nio/docs/filesystem.md) confirms URI resolution and path handling are already modeled in the storage layer.

## Planned Architecture

### Command aliases

- Keep `*FHOST`.
- Add `*FFS`.
- Route both command names to the existing handler symbol [`cmd_fs_fhost`](../../bbc/fn-rom/src/commands/cmd_fhost.s).

### ROM-owned state

fn-rom should own the current filesystem selection instead of delegating selection to a firmware-side host table.

Required state additions in [`os.s`](../../bbc/fn-rom/src/os.s):

- current filesystem URI buffer
- current directory buffer or equivalent current path state
- optional cached length bytes if they simplify packet construction without increasing transient parsing cost

### Service split

- Disk image mount and unmount stay on DiskService via [`fujibus_disk.s`](../../bbc/fn-rom/src/fujibus_disk.s).
- Directory traversal commands should use FileService semantics described in [`file_device_protocol.md`](../../../atari/fujinet-nio/docs/file_device_protocol.md).
- fn-rom should resolve relative paths against its stored current filesystem and current directory before issuing protocol requests.

## Execution Plan

1. Update command metadata

- extend [`cmd_table_futils`](../../bbc/fn-rom/src/commands/cmd_tables.s) with `FS`
- update [`parameter_table`](../../bbc/fn-rom/src/commands/cmd_tables.s) strings for URI-oriented usage
- review help text in [`help.s`](../../bbc/fn-rom/src/help.s) and related command help output

2. Replace persistent legacy host state

- introduce new workspace allocations in [`os.s`](../../bbc/fn-rom/src/os.s)
- remove or repurpose host-specific state such as [`current_host`](../../bbc/fn-rom/src/os.s)
- audit callers before removing exported symbols relied on elsewhere

3. Rewrite [`cmd_fs_fhost`](../../bbc/fn-rom/src/commands/cmd_fhost.s)

- no parameter: print current filesystem URI and current directory
- one parameter: set current filesystem URI and reset or normalize the current directory state
- reject numeric legacy host-slot forms
- remove dependence on old host-list transport helpers where no longer needed

4. Complete URI mount support in [`fujibus_disk.s`](../../bbc/fn-rom/src/fujibus_disk.s)

- serialize `version`, `slot`, `flags`, `typeOverride`, `sectorSizeHint`, `uriLen`, and URI bytes
- align comments and helper contracts with the actual full-URI protocol
- validate response parsing against the current DiskService response layout

5. Refactor [`cmd_fs_fin`](../../bbc/fn-rom/src/commands/cmd_fin.s) and helpers

- build a full mount URI from current filesystem state plus the requested filename
- preserve BBC drive-default behavior where appropriate
- remove assumptions about host indexes and host prefixes

6. Implement traversal command coverage

- inspect existing handlers in [`src/commands/`](../../bbc/fn-rom/src/commands/) and filesystem helpers in [`fuji_fs.s`](../../bbc/fn-rom/src/fuji_fs.s)
- determine whether `*FCD`, `*FDIR`, `*FLIST`, `*FOUT`, and `*FDRIVE` already exist under legacy names or require new command entries and handlers
- wire traversal commands to FileService-compatible request builders

7. Review reset behavior

- confirm [`cmd_fs_freset`](../../bbc/fn-rom/src/commands/cmd_freset.s) still uses the valid FujiBus path through [`fuji_reset`](../../bbc/fn-rom/src/commands/cmd_freset.s)
- adjust only if transport details no longer match the current stack

8. Remove dead legacy host transport usage

- inspect [`fujibus_host.s`](../../bbc/fn-rom/src/fujibus_host.s) import graph
- delete or isolate obsolete host-list code once no active caller remains

9. Verification

- build fn-rom from [`../../bbc/fn-rom/Makefile`](../../bbc/fn-rom/Makefile)
- test alias parsing for `*FHOST` and `*FFS`
- test URI selection, directory traversal, mount, unmount, and drive-list commands
- verify no TODO markers remain in touched files

## Minimal request contract needed for `*FCD` and `*FLIST`

To keep URI parsing and path resolution on FujiNet-NIO instead of in fn-rom, the BBC ROM should not attempt to interpret schemes, authorities, or relative path rules locally. The ROM should send only:

- the currently selected full URI from [`cmd_fs_fhost`](../../bbc/fn-rom/src/commands/cmd_fhost.s)
- an optional user-supplied path argument for `*FCD`
- paging/chunking arguments for `*FLIST`

Recommended minimal FileService extension:

### 1. `ResolvePath` command

Purpose:

- accept a base full URI plus a relative or absolute path fragment
- use FujiNet-NIO path resolver logic to produce a canonical resolved URI
- optionally return a displayable current path string suitable for the BBC prompt/help output

Suggested request payload:

```text
u8  version
u16 baseUriLen
u8[] baseUri
u16 argLen
u8[] arg
```

Suggested response payload:

```text
u8  version
u16 resolvedUriLen
u8[] resolvedUri
u16 displayPathLen
u8[] displayPath
u8  flags    ; bit0=isDirectory, bit1=exists
```

BBC usage:

- [`*FCD`](../../bbc/fn-rom/docs/fn-rom-command-rewrite.md) sends current full URI plus the user argument
- fn-rom stores returned `resolvedUri` as the new current selection
- fn-rom stores returned `displayPath` for lightweight status display without doing its own URI parsing

### 2. `ListDirectoryUri` command

Purpose:

- accept a full URI directly
- return directory entries in chunks
- let FujiNet-NIO decide whether the URI is already a directory, requires normalization, or needs resolver-specific handling

Suggested request payload:

```text
u8  version
u16 uriLen
u8[] uri
u16 startIndex
u16 maxEntries
```

Suggested response payload:

Reuse the existing compact list response structure already documented for [`ListDirectory`](../../../atari/fujinet-nio/docs/file_device_protocol.md), but allow the request to operate directly on a full URI instead of separate filesystem-plus-path fields.

BBC usage:

- [`*FLIST`](../../bbc/fn-rom/docs/fn-rom-command-rewrite.md) sends the current full URI
- fn-rom only handles chunked printing and no path parsing

### Why this split keeps fn-rom small

- fn-rom avoids TNFS and generic URI parsing entirely
- fn-rom only stores opaque strings plus light metadata lengths
- all resolver behavior remains centralized in FujiNet-NIO path resolution code
- changing resolver behavior later does not require ROM parser growth

## Implementation Checklist

- [ ] Add `FS` alias and update command metadata in [`cmd_tables.s`](../../bbc/fn-rom/src/commands/cmd_tables.s)
- [ ] Allocate workspace for current filesystem URI and current directory in [`os.s`](../../bbc/fn-rom/src/os.s)
- [ ] Rewrite [`cmd_fs_fhost`](../../bbc/fn-rom/src/commands/cmd_fhost.s) for URI-based selection
- [ ] Complete full-URI DiskService mount support in [`fujibus_disk.s`](../../bbc/fn-rom/src/fujibus_disk.s)
- [ ] Refactor [`cmd_fs_fin`](../../bbc/fn-rom/src/commands/cmd_fin.s) and dependent helpers
- [ ] Inspect and implement traversal command handlers in [`src/commands/`](../../bbc/fn-rom/src/commands/)
- [ ] Review [`cmd_fs_freset`](../../bbc/fn-rom/src/commands/cmd_freset.s) for transport compatibility
- [ ] Remove or isolate obsolete host-list transport usage
- [ ] Build and verify with no TODOs left in changed files

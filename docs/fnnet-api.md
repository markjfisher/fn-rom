# FujiNet BBC API (OSWORD &78)

Long URIs and JSON paths (up to 512 bytes) use a pointer+length descriptor in user RAM instead of ROM buffers.

## Entry point

| Entry | Usage |
|-------|--------|
| OSWORD `&78` | `A=&78`, `(X,Y)` = 16-byte parameter block; reason at block+0 |

OSWORD numbers `&80` and above are not offered via service call 8; `&E0`–`&FF` route via USERV (`&0200`) instead. FujiNet uses `&78`, which MOS passes to sideways ROMs as service 8 with the function code in `&EF` and `(X,Y)` saved in `&F0`/`&F1`.

From BASIC: poke the parameter block, set `A%=&78`, pass `(X,Y)` as the block address, and `CALL &FFF1`.

## Parameter block

Every call uses a 16-byte block. All calls share:

| Offset | Field |
|--------|-------|
| 0 | Reason in / status out |
| 1 | Status out (duplicate for convenience) |

Each reason then reads its own inputs starting at offset 2. Handlers ignore all other bytes.

### Reasons `&00`, `&01`, `&03` — string operations

| Offset | Field |
|--------|-------|
| 2-3 | String pointer in user RAM |
| 4-5 | String length (u16, max 512) |
| 6 | BASIC file handle (`&10`..`&15`) for reasons `&00` and `&03` only |

### Reason `&02` — set POST/PUT body length

| Offset | Field |
|--------|-------|
| 2-3 | Body length u16le (one-shot; consumed on next network open) |

### Reason `&04` — set request content profile

| Offset | Field |
|--------|-------|
| 2 | Content profile u8 (one-shot; consumed on next network open) |

## Reason codes

| Code | Action |
|------|--------|
| `&00` | JSON query on open channel (TranslateConfigure) |
| `&01` | Stash JSON path for next open-with-translation |
| `&02` | Set one-shot HTTP POST/PUT body length |
| `&03` | Write request body bytes to an open channel |
| `&04` | Set one-shot request content profile |

## Content profiles (reason `&04`, block+2)

| Value | Meaning |
|------:|---------|
| `0` | None (default) |
| `1` | JSON body → `Content-Type: application/json` |
| `2` | Form body → `Content-Type: application/x-www-form-urlencoded` |
| `3` | Text body → `Content-Type: text/plain` |

The profile applies to the next `OPENIN` / `OPENUP` / `OPENOUT` network open and is cleared after use. Fujinet injects the corresponding request header; explicit headers from other clients still take precedence.

## Status codes

| Code | Meaning |
|------|---------|
| `&00` | OK |
| `&01` | Bad call or invalid string descriptor |
| `&02` | JSON query could not be configured on the open channel |
| `&03` | Bad or unopened BASIC channel |

For reason `&00`, status `&02` is a recoverable runtime failure. The ROM also marks the translated read as immediate EOF so callers that proceed to `BGET#` simply read zero bytes. This matches the short-path `*FJSON` behaviour used by polling applications such as `bas/iss/iss.bas`.

## Long URLs

Use normal `OPENIN(url$)` for URLs up to **255 characters** (BBC BASIC string limit). The ROM reads the string in place and scatter-sends it to FujiNet (replacing the old ~64-byte filename buffer path).

URLs longer than 255 bytes require assembling the URI in a user RAM buffer and a separate API path (not yet exposed for OPENIN; see `PROCfnnet_set_str_ptr` for the JSON/query side). That case is intentionally out of scope for the default BASIC story until needed.

Short JSON paths may still use `OSCLI "*FJSON handle path"`. Use OSWORD reason `&00` for longer paths (up to 512 bytes via buffer + pointer).

## BASIC library

See [bas/lib/fnnet.bas](../bas/lib/fnnet.bas).

## ROM source layout

OSWORD `&78` handlers compile as one CODE object from [src/fnnet.s](../src/fnnet.s), with handler bodies in [src/fnnet/](../src/fnnet/) as `.inc` fragments:

| File | Purpose |
|------|---------|
| `fnnet.s` | Jump-table dispatch |
| `ext_str.inc` | Long-string load/clear helpers |
| `exit.inc` | Shared fail/exit tail (placed before large handlers for short branches) |
| `reason_json_query.inc` | Reason `&00` |
| `reason_stash_json.inc` | Reason `&01` |
| `reason_set_body_len.inc` | Reason `&02` |
| `reason_write_data.inc` | Reason `&03` |
| `reason_set_content_profile.inc` | Reason `&04` |

BBC BASIC reserves the `FN` prefix for user functions (case-insensitive) — use the `fin*` prefix for names, not `fn*` or `FNNET_*`.

Integer scratch buffers use `DIM finBlock% 16` (note `%` on the DIM name). Byte pokes use `finBlock%?0`; the base address for `(X,Y)` is `finBlock%`. With `DIM finBlock 16` (no `%`), use `finBlock?0` and `finBlock` as the address instead — `%` on the reference only works when `%` was on the DIM.

The default BASIC template records the most recent API result in `finLastStatus%`. Recoverable JSON query failures do not raise `ERROR`; callers should inspect `finLastStatus%` if they need to distinguish `OK` from `JSON query failed`.

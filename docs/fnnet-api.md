# FujiNet BBC API (OSWORD &78 / CALL)

Long URIs and JSON paths (up to 512 bytes) use a pointer+length descriptor in user RAM instead of ROM buffers.

## Entry points

| Entry | Usage |
|-------|--------|
| OSWORD `&78` | `(X,Y)` = 16-byte parameter block; reason at block+0 |
| CALL | `A` = reason, `(X,Y)` = block; returns status in `A` |

OSWORD numbers `&80` and above are not offered via service call 8; `&E0`–`&FF` route via USERV (`&0200`) instead. FujiNet uses `&78`, which MOS passes to sideways ROMs as service 8 with the function code in `&EF` and `(X,Y)` saved in `&F0`/`&F1`.

Reason `0` returns API version in block+1 and CALL entry address in block+8/9. The first call uses OSWORD via `USR &FFF1` with `A=&78`; later calls use `USR finCallEntry%` with `A=reason`, `(X,Y)=finBlock%`.

## Parameter block

| Offset | Field |
|--------|-------|
| 0 | Reason in / status out |
| 1 | Status out (duplicate for convenience) |
| 2-3 | String pointer in user RAM |
| 4-5 | String length (u16, max 512) |
| 6-7 | BASIC file handle (`&10`..`&15`) for JSON query |
| 8-9 | Out: CALL entry lo/hi (reason 0 only) |

## Reason codes

| Code | Action |
|------|--------|
| `&00` | Return API version |
| `&01` | JSON query on open channel (TranslateConfigure) |
| `&02` | Stash JSON path for next open-with-translation |
| `&04` | Set one-shot HTTP POST/PUT body length (bytes at block+4/+5) |
| `&05` | Write request body bytes to an open channel |
| `&06` | Set one-shot request content profile (byte at block+6) |

## Content profiles (reason `&06`, block+6)

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

For reason `&01`, status `&02` is a recoverable runtime failure. The ROM also marks the translated read as immediate EOF so callers that proceed to `BGET#` simply read zero bytes. This matches the short-path `*FJSON` behaviour used by polling applications such as `bas/iss/iss.bas`.

## Long URLs

Use normal `OPENIN(url$)` for URLs up to **255 characters** (BBC BASIC string limit). The ROM reads the string in place and scatter-sends it to FujiNet (replacing the old ~64-byte filename buffer path).

URLs longer than 255 bytes require assembling the URI in a user RAM buffer and a separate API path (not yet exposed for OPENIN; see `PROCfnnet_set_str_ptr` for the JSON/query side). That case is intentionally out of scope for the default BASIC story until needed.

Short JSON paths may still use `OSCLI "*FJSON handle path"`. Use OSWORD/CALL reason `&01` for longer paths (up to 512 bytes via buffer + pointer).

## BASIC library

See [bas/lib/fnnet.bas](../bas/lib/fnnet.bas).

BBC BASIC reserves the `FN` prefix for user functions (case-insensitive) — use the `fin*` prefix for names, not `fn*` or `FNNET_*`.

Integer scratch buffers use `DIM finBlock% 16` (note `%` on the DIM name). Byte pokes use `finBlock%?0`; the base address for `(X,Y)` is `finBlock%`. With `DIM finBlock 16` (no `%`), use `finBlock?0` and `finBlock` as the address instead — `%` on the reference only works when `%` was on the DIM.

The default BASIC template records the most recent API result in `finLastStatus%`. Recoverable JSON query failures do not raise `ERROR`; callers should inspect `finLastStatus%` if they need to distinguish `OK` from `JSON query failed`.

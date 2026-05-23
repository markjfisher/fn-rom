# FujiNet BBC API (OSWORD &E0 / CALL)

Long URIs and JSON paths (up to 512 bytes) use a pointer+length descriptor in user RAM instead of ROM buffers.

## Entry points

| Entry | Usage |
|-------|--------|
| OSWORD `&E0` | `(X,Y)` = 16-byte parameter block; reason at block+0 |
| CALL | `A` = reason, `(X,Y)` = block; returns status in `A` |

Reason `0` returns API version in block+1 and CALL entry address in block+8/9.

## Parameter block

| Offset | Field |
|--------|-------|
| 0 | Reason in / status out |
| 1 | Status (0 = ok) |
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

## Long URLs

Use normal `OPENIN(url$)` — the ROM reads the string in place (up to 512 chars) and scatter-sends it to FujiNet. No BASIC API call required for URLs.

Short JSON paths may still use `OSCLI "*FJSON handle path"`. Use OSWORD/CALL reason `&01` for longer paths.

## BASIC library

See [bas/lib/fnnet.bas](../bas/lib/fnnet.bas).

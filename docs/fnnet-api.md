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

### Reasons `&00`, `&02` — string operations

| Offset | Field |
|--------|-------|
| 2-3 | String pointer in user RAM |
| 4-5 | String length (u16, max 512) |
| 6 | BASIC file handle (`&10`..`&15`) for reason `&00` only |

### Reason `&01` — set POST/PUT body length

| Offset | Field |
|--------|-------|
| 2-3 | Body length u16le (one-shot; consumed on next network open) |

### Reason `&03` — set request content profile

| Offset | Field |
|--------|-------|
| 2 | Content profile u8 (one-shot; consumed on next network open) |

### Reason `&04` — set open URL (one-shot)

| Offset | Field |
|--------|-------|
| 2-3 | URL pointer in user RAM |
| 4-5 | URL length (u16, max 512) |

Arms a URI for the **next** `OPENIN` / `OPENUP` / `OPENOUT`. The BASIC filename passed to OSFIND must be exactly the sentinel `"://"` (three characters plus CR). The ROM uses the armed bytes from user RAM instead of the sentinel string. Any scheme Fujinet supports (`http://`, `https://`, `ftp://`, `smb://`, …) works because the full URI lives in the buffer.

The armed URL is consumed when the network open completes (same as other one-shot open options). HTTP/TCP connection happens at **open** time, not on the first `BGET#`.

### Reason `&05` — set network open flags (one-shot)

| Offset | Field |
|--------|-------|
| 2 | Open flags u8 (currently `&10` = `stream_no_probe`) |

Arms additional network `Open` request flags for the **next** `OPENIN` / `OPENUP` / `OPENOUT` network open, then clears them after the open attempt completes.

Currently defined flag:

| Bit | Meaning |
|-----|---------|
| `&10` | `stream_no_probe` — for streaming channels, return the current buffered chunk without forcing a follow-up probe read solely to discover whether more bytes are immediately available |

### Reason `&06` — FujiBus device call

| Offset | Field |
|--------|-------|
| 2 | FujiBus device id |
| 3 | Device command byte |
| 4 | Device status out |
| 5-6 | Request payload pointer in user RAM |
| 7-8 | Request payload length u16le |
| 9-10 | Response payload pointer in user RAM |
| 11-12 | Response payload capacity u16le |
| 13-14 | Actual response payload length u16le out |

Sends a raw FujiBus device request and copies the returned device protocol payload into the caller's response buffer. The ROM only performs FujiBus framing, status extraction, length checking, and copying; application protocols such as AppStore and Clock are owned by the caller/library.

If the device response payload is larger than the caller's capacity, status `&01` is returned and offsets 13-14 still contain the actual payload length. Offset 4 contains the device status byte when a valid response was received.

## Reason codes

| Code | Action |
|------|--------|
| `&00` | JSON query on open channel (TranslateConfigure) |
| `&01` | Set one-shot HTTP POST/PUT body length |
| `&02` | Write request body bytes to an open channel |
| `&03` | Set one-shot request content profile |
| `&04` | Arm URL in user RAM for next `OPENIN("://")` |
| `&05` | Set one-shot network open flags |
| `&06` | Raw FujiBus device call |

## JSON query (reason `&00`)

Configure JSON translation on an **already open** network channel, then `BGET#` returns the matched substring (not the raw HTTP body). Fujinet buffers the response, applies the JSON Pointer selector, and serves translated bytes on read.

For multiple fields from one response — as `bas/iss/iss.bas` does for latitude and longitude — `OPENIN` once, then reason `&00` before each `BGET#`.

Short paths may use `OSCLI "*FJSON handle path"`. Use reason `&00` for paths up to 512 bytes via user RAM buffer + pointer.

Examples: [bas/fs/openbas/fnosw78.bas](../bas/fs/openbas/fnosw78.bas) (single query), [bas/fs/openbas/fnjson2.bas](../bas/fs/openbas/fnjson2.bas) (multi-query on one handle).

## Content profiles (reason `&03`, block+2)

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

Use normal `OPENIN(url$)` for URLs up to **255 characters** (BBC BASIC string limit). The ROM reads the string in place and scatter-sends it to FujiNet.

URLs longer than 255 bytes (or any URI you prefer not to embed in a BASIC string) use reason `&04` plus the sentinel open:

1. Assemble the full URI in a user RAM buffer (512-byte max, same as other long-string calls).
2. `PROCfnnet_set_open_url(addr%, len%)` — OSWORD `&78` reason `&04`.
3. `h%=OPENIN("://")` — or `FNfnnet_open_url(addr%, len%)` in [bas/lib/fnnet.bas](../bas/lib/fnnet.bas).

Split assembly across two BASIC strings if needed (base + query tail); only the buffer length matters to the API.

Examples: [bas/fs/openbas/openin03.bas](../bas/fs/openbas/openin03.bas) (255-char `OPENIN`), [bas/fs/openbas/openin04.bas](../bas/fs/openbas/openin04.bas) (buffer + sentinel), [bas/weather/weather.bas](../bas/weather/weather.bas) (Open-Meteo forecast query).

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
| `reason_set_body_len.inc` | Reason `&01` |
| `reason_write_data.inc` | Reason `&02` |
| `reason_set_content_profile.inc` | Reason `&03` |
| `reason_set_open_url.inc` | Reason `&04` |
| `reason_set_open_flags.inc` | Reason `&05` |
| `reason_device_call.inc` | Reason `&06` |

BBC BASIC reserves the `FN` prefix for user functions (case-insensitive) — use the `fin*` prefix for names, not `fn*` or `FNNET_*`.

Integer scratch buffers use `DIM finBlock% 16` (note `%` on the DIM name). Byte pokes use `finBlock%?0`; the base address for `(X,Y)` is `finBlock%`. With `DIM finBlock 16` (no `%`), use `finBlock?0` and `finBlock` as the address instead — `%` on the reference only works when `%` was on the DIM.

The default BASIC template records the most recent API result in `finLastStatus%`. Recoverable JSON query failures do not raise `ERROR`; callers should inspect `finLastStatus%` if they need to distinguish `OK` from `JSON query failed`.

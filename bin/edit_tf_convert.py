#!/usr/bin/env python3
"""
Convert an edit.tf teletext URL into several output formats.

Examples
--------
# Print BBC BASIC DATA lines to stdout
python edit_tf_convert.py "https://edit.tf/#0:..." --format bbc

# Write CA65 .byte output to a file
python edit_tf_convert.py "https://edit.tf/#0:..." --format ca65 -o globe_ca65.inc

# Write raw binary
python edit_tf_convert.py "https://edit.tf/#0:..." --format raw -o globe.bin

# Show row-by-row hex dump
python edit_tf_convert.py "https://edit.tf/#0:..." --format hex
"""

from __future__ import annotations

import argparse
import base64
import re
import sys
from pathlib import Path
from typing import Iterable, List, Sequence
from urllib.parse import urlparse


ROWS = 25
COLS = 40
TOTAL_BYTES = ROWS * COLS


def extract_hash_payload(url_or_hash: str) -> str:
    """
    Extract the edit.tf hash payload from either a full URL or a raw fragment.

    Expected forms:
      https://edit.tf/#0:ENCODED:PS=0:RE=0
      #0:ENCODED:PS=0:RE=0
      0:ENCODED:PS=0:RE=0
    """
    text = url_or_hash.strip()

    if not text:
        raise ValueError("Empty URL or fragment.")

    if "://" in text:
        parsed = urlparse(text)
        fragment = parsed.fragment
        if not fragment:
            raise ValueError("URL does not contain a hash fragment.")
    else:
        fragment = text[1:] if text.startswith("#") else text

    return fragment


def split_fragment(fragment: str) -> tuple[str, str]:
    """
    Return (flags, encoded_data) from an edit.tf fragment.

    Example fragment:
      0:GoEC...3qA:PS=0:RE=0
    """
    parts = fragment.split(":")
    if len(parts) < 2:
        raise ValueError("Fragment is not in the expected edit.tf format.")

    flags = parts[0].strip()
    encoded = parts[1].strip()

    if not re.fullmatch(r"[0-9A-Fa-f]+", flags):
        raise ValueError(f"Unexpected flags field: {flags!r}")

    if not re.fullmatch(r"[A-Za-z0-9_-]+", encoded):
        raise ValueError("Encoded payload contains unexpected characters.")

    return flags, encoded


def decode_edit_tf_payload(encoded: str) -> bytes:
    """
    Decode base64url payload and unpack 7-bit teletext character codes.

    edit.tf stores 1000 7-bit values packed into bytes, then base64url encoded.
    """
    # Pad for base64 decoding
    padded = encoded + "=" * ((4 - len(encoded) % 4) % 4)
    packed = base64.urlsafe_b64decode(padded)

    values: List[int] = []
    bit_buffer = 0
    bit_count = 0

    for b in packed:
        bit_buffer = (bit_buffer << 8) | b
        bit_count += 8

        while bit_count >= 7 and len(values) < TOTAL_BYTES:
            bit_count -= 7
            value = (bit_buffer >> bit_count) & 0x7F
            values.append(value)

    if len(values) != TOTAL_BYTES:
        raise ValueError(
            f"Decoded {len(values)} teletext bytes, expected {TOTAL_BYTES}. "
            "The URL may be malformed or use an unsupported format."
        )

    return bytes(values)


def chunked(data: Sequence[int], size: int) -> Iterable[Sequence[int]]:
    for i in range(0, len(data), size):
        yield data[i:i + size]


def format_bbc_data(data: bytes, values_per_line: int = 16, line_start: int = 1000, line_step: int = 10) -> str:
    """
    Output BBC BASIC II style numbered DATA lines.
    """
    lines: List[str] = []
    line_no = line_start

    for group in chunked(list(data), values_per_line):
        items = ",".join(str(v) for v in group)
        lines.append(f"{line_no} DATA {items}")
        line_no += line_step

    return "\n".join(lines) + "\n"


def format_ca65(data: bytes, values_per_line: int = 16, label: str | None = "teletext_data") -> str:
    """
    Output CA65-compatible .byte directives.
    """
    lines: List[str] = []

    if label:
        lines.append(f"{label}:")

    for row in chunked(list(data), values_per_line):
        items = ", ".join(f"${v:02X}" for v in row)
        lines.append(f"    .byte {items}")

    return "\n".join(lines) + "\n"


def format_hex(data: bytes, row_width: int = COLS, include_ascii: bool = False) -> str:
    """
    Output hex dump, defaulting to one teletext row per line.
    """
    lines: List[str] = []

    for row_idx, row in enumerate(chunked(list(data), row_width)):
        hex_part = " ".join(f"{v:02X}" for v in row)
        if include_ascii:
            ascii_part = "".join(chr(v) if 32 <= v <= 126 else "." for v in row)
            lines.append(f"{row_idx:02d}: {hex_part}  |{ascii_part}|")
        else:
            lines.append(f"{row_idx:02d}: {hex_part}")

    return "\n".join(lines) + "\n"


def format_json(data: bytes) -> str:
    """
    Output a plain JSON-style array without importing json for compactness.
    """
    return "[\n  " + ", ".join(str(v) for v in data) + "\n]\n"


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert an edit.tf teletext URL into BBC BASIC DATA, CA65 .byte, raw binary, or hex dump."
    )
    parser.add_argument(
        "url",
        help="Full edit.tf URL, hash fragment, or fragment body."
    )
    parser.add_argument(
        "--format",
        choices=("bbc", "ca65", "raw", "hex", "hexascii", "json"),
        required=True,
        help="Output format."
    )
    parser.add_argument(
        "-o", "--output",
        help="Output filename. If omitted, text formats go to stdout. Raw format requires -o."
    )
    parser.add_argument(
        "--values-per-line",
        type=int,
        default=16,
        help="Number of values per output line for bbc/ca65. Default: 16."
    )
    parser.add_argument(
        "--line-start",
        type=int,
        default=1000,
        help="Starting line number for BBC BASIC output. Default: 1000."
    )
    parser.add_argument(
        "--line-step",
        type=int,
        default=10,
        help="Line increment for BBC BASIC output. Default: 10."
    )
    parser.add_argument(
        "--label",
        default="teletext_data",
        help="Label name for CA65 output. Use empty string to omit. Default: teletext_data."
    )
    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()

    try:
        fragment = extract_hash_payload(args.url)
        flags, encoded = split_fragment(fragment)
        data = decode_edit_tf_payload(encoded)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    if args.format == "bbc":
        output = format_bbc_data(
            data,
            values_per_line=args.values_per_line,
            line_start=args.line_start,
            line_step=args.line_step,
        )
        binary = False
    elif args.format == "ca65":
        output = format_ca65(
            data,
            values_per_line=args.values_per_line,
            label=(args.label or None),
        )
        binary = False
    elif args.format == "hex":
        output = format_hex(data, include_ascii=False)
        binary = False
    elif args.format == "hexascii":
        output = format_hex(data, include_ascii=True)
        binary = False
    elif args.format == "json":
        output = format_json(data)
        binary = False
    elif args.format == "raw":
        output = data
        binary = True
        if not args.output:
            print("Error: --format raw requires --output.", file=sys.stderr)
            return 1
    else:
        print(f"Error: unsupported format {args.format!r}", file=sys.stderr)
        return 1

    if args.output:
        path = Path(args.output)
        if binary:
            path.write_bytes(output)
        else:
            path.write_text(output, encoding="utf-8")
    else:
        if binary:
            print("Error: binary output requires --output.", file=sys.stderr)
            return 1
        sys.stdout.write(output)

    # Helpful status to stderr so stdout can still be redirected cleanly
    print(
        f"Decoded {len(data)} bytes ({ROWS}x{COLS} teletext frame), flags={flags}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

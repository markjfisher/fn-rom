#!/usr/bin/env python3
"""
b2-http.py - Interact with b2 emulator HTTP API (localhost:48075)

Usage:
    ./b2-http.py [--host HOST] [--port PORT] [--win WIN] <command> [options]

WIN defaults to "*" (most recently used window). Commands: launch, reset,
paste, peek, poke, mount, run, load-disc, screen.
"""

import argparse
import sys
from pathlib import Path
from typing import Optional
from urllib.parse import urlencode

import requests

DEFAULT_PORT = 48075
DEFAULT_WIN = "*"


def base_url(host: str, port: int) -> str:
    return f"http://{host}:{port}"


def common_win_args(parser: argparse.ArgumentParser, default_win: str = DEFAULT_WIN) -> None:
    parser.add_argument("--host", default="localhost", help="b2 HTTP API host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="b2 HTTP API port")
    parser.add_argument("--win", default=default_win, help="Window name (* = most recent, b2 = initial)")


def cmd_launch(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/launch"
    params = {"path": str(args.path)}
    return requests.get(url, params=params, timeout=10)


def cmd_reset(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/reset/{args.win}"
    params = {}
    if args.config is not None:
        params["config"] = args.config
    if args.boot is not None:
        params["boot"] = "1" if args.boot else "0"
    if params:
        url = f"{url}?{urlencode(params)}"
    return requests.post(url, timeout=10)


# BBC Micro uses CR ($0d) to submit a line; LF moves cursor down without executing.
BBC_NEWLINE = "\r"

def cmd_paste(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/paste/{args.win}"
    if args.file is not None:
        body = Path(args.file).read_text(encoding="utf-8")
        # Normalise line endings to BBC CR so pasted files submit lines correctly.
        body = body.replace("\r\n", BBC_NEWLINE).replace("\n", BBC_NEWLINE)
    else:
        body = args.text
        if not body.endswith(BBC_NEWLINE):
            body = body + BBC_NEWLINE
    # b2 expects "charset:" (colon) not "charset=" (equals); see http.cpp CHARSET_PREFIX
    headers = {"Content-Type": "text/plain; charset:utf-8"}
    return requests.post(url, data=body.encode("utf-8"), headers=headers, timeout=10)


def cmd_peek(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/peek/{args.win}/{args.begin}/{args.end}"
    params = {}
    if args.s is not None:
        params["s"] = args.s
    if args.mos is not None:
        params["mos"] = "true" if args.mos else "false"
    if params:
        url = f"{url}?{urlencode(params)}"
    return requests.get(url, timeout=10)


def cmd_poke(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/poke/{args.win}/{args.addr}"
    params = {}
    if args.s is not None:
        params["s"] = args.s
    if args.mos is not None:
        params["mos"] = "true" if args.mos else "false"
    if params:
        url = f"{url}?{urlencode(params)}"
    body = Path(args.file).read_bytes()
    return requests.post(url, data=body, timeout=10)


def cmd_mount(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/mount/{args.win}"
    params = {"drive": args.drive, "name": args.name}
    url = f"{url}?{urlencode(params)}"
    body = Path(args.file).read_bytes()
    content_type = getattr(args, "content_type", None)
    headers = {}
    if content_type:
        headers["Content-Type"] = content_type
    return requests.post(url, data=body, headers=headers or None, timeout=10)


def cmd_run(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/run/{args.win}"
    params = {}
    if args.name is not None:
        params["name"] = args.name
    else:
        params["name"] = args.file.name
    if params:
        url = f"{url}?{urlencode(params)}"
    body = Path(args.file).read_bytes()
    content_type = getattr(args, "content_type", None)
    headers = {}
    if content_type:
        headers["Content-Type"] = content_type
    return requests.post(url, data=body, headers=headers or None, timeout=10)


CHARS_PER_LINE = 40


def screen_bytes_to_ascii(data: bytes, chars_per_line: int = CHARS_PER_LINE) -> list[str]:
    """Decode BBC screen memory to ASCII lines. 32-126 printable, else '.'."""
    lines = []
    for i in range(0, len(data), chars_per_line):
        chunk = data[i : i + chars_per_line]
        line = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(line)
    return lines


def cmd_screen(args: argparse.Namespace) -> requests.Response:
    start = args.start
    chars_per_line = args.chars_per_line
    size = args.lines * chars_per_line
    url = f"{base_url(args.host, args.port)}/peek/{args.win}/{start}/+{size}"
    params = {}
    if getattr(args, "s", None) is not None:
        params["s"] = args.s
    if getattr(args, "mos", None) is not None:
        params["mos"] = "true" if args.mos else "false"
    if params:
        url = f"{url}?{urlencode(params)}"
    return requests.get(url, timeout=10)


def cmd_load_disc(args: argparse.Namespace) -> requests.Response:
    url = f"{base_url(args.host, args.port)}/load-disc/{args.win}"
    params = {"path": str(args.path), "drive": args.drive, "in_memory": "true" if args.in_memory else "false"}
    url = f"{url}?{urlencode(params)}"
    return requests.post(url, timeout=10)


def handle_response(resp: requests.Response, output_file: Optional[Path] = None) -> None:
    if not resp.ok:
        print(resp.text or resp.reason, file=sys.stderr)
        sys.exit(1)
    if output_file is not None and resp.content:
        output_file.write_bytes(resp.content)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Interact with b2 emulator HTTP API (localhost:48075)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s reset
  %(prog)s reset --config "Master 128 (MOS 3.20)" --boot
  %(prog)s paste --text "RUN"
  %(prog)s paste --file script.txt
  %(prog)s load-disc --path ./game.ssd
  %(prog)s run --file build/fujinet.ssd --name fujinet.ssd
  %(prog)s peek 0 100 -o mem.bin
  %(prog)s screen --start 7c00 --lines 25
  %(prog)s screen --start 7c00 -o screen.txt
  %(prog)s launch --path /path/to/file.ssd
        """,
    )
    common_win_args(parser)
    subparsers = parser.add_subparsers(dest="command", required=True, help="Command")

    # launch (no WIN in URL but we keep --win for consistency; API doesn't use it)
    p_launch = subparsers.add_parser("launch", help="Launch file as if double-clicked")
    p_launch.add_argument("path", type=Path, help="Path to file to launch")
    p_launch.set_defaults(func=cmd_launch)

    # reset
    p_reset = subparsers.add_parser("reset", help="Reset the BBC (power-on reset)")
    p_reset.add_argument("--config", help="Config name (File > Change config)")
    p_reset.add_argument("--boot", action="store_true", help="Auto-boot disk (hold SHIFT)")
    p_reset.set_defaults(func=cmd_reset)

    # paste
    p_paste = subparsers.add_parser("paste", help="Paste text (Paste OSRDCH)")
    g = p_paste.add_mutually_exclusive_group(required=True)
    g.add_argument("--file", "-f", type=Path, help="Path to file whose contents to paste")
    g.add_argument("--text", "-t", help="String to paste (newline added if missing)")
    p_paste.set_defaults(func=cmd_paste)

    # peek
    p_peek = subparsers.add_parser("peek", help="Read memory range")
    p_peek.add_argument("begin", help="Start address (hex, e.g. 0 or 8000)")
    p_peek.add_argument("end", help="End address (hex, exclusive) or +SIZE (e.g. +100)")
    p_peek.add_argument("-o", "--output", type=Path, help="Write binary output to file")
    p_peek.add_argument("-s", "--suffix", dest="s", help="Debugger address suffix")
    p_peek.add_argument("--mos", type=lambda x: x.lower() in ("1", "true", "yes"), metavar="BOOL", help="MOS's view")
    p_peek.set_defaults(func=cmd_peek)

    # poke
    p_poke = subparsers.add_parser("poke", help="Write memory at address")
    p_poke.add_argument("addr", help="Address (16-bit hex)")
    p_poke.add_argument("file", type=Path, help="File to write from")
    p_poke.add_argument("-s", "--suffix", dest="s", help="Debugger address suffix")
    p_poke.add_argument("--mos", type=lambda x: x.lower() in ("1", "true", "yes"), metavar="BOOL", help="MOS's view")
    p_poke.set_defaults(func=cmd_poke)

    # mount
    p_mount = subparsers.add_parser("mount", help="Load in-memory disc image")
    p_mount.add_argument("file", type=Path, help="Disc image file")
    p_mount.add_argument("--drive", "-d", type=int, default=0, help="Drive number (default 0)")
    p_mount.add_argument("--name", "-n", default="", help="File name for format detection")
    p_mount.set_defaults(func=cmd_mount)

    # run
    p_run = subparsers.add_parser("run", help="Run file (e.g. disc image; inserts in drive 0 and reset)")
    p_run.add_argument("file", type=Path, help="File to run (e.g. .ssd)")
    p_run.add_argument("--name", "-n", help="File name for type detection (default from file)")
    p_run.set_defaults(func=cmd_run)

    # screen (peek + decode to ASCII)
    p_screen = subparsers.add_parser("screen", help="Grab screen from memory via peek, output as ASCII")
    p_screen.add_argument("--start", "-s", default="7c00", help="Start address in hex (default 7c00)")
    p_screen.add_argument("--lines", "-l", type=int, default=25, help="Number of lines (default 25)")
    p_screen.add_argument("--chars", "-c", dest="chars_per_line", type=int, default=CHARS_PER_LINE,
                          help="Characters per line (default %d, varies by screen mode)" % CHARS_PER_LINE)
    p_screen.add_argument("-o", "--output", type=Path, help="Write ASCII to file (default stdout)")
    p_screen.set_defaults(func=cmd_screen)

    # load-disc
    p_ld = subparsers.add_parser("load-disc", help="Load disc image from file path")
    p_ld.add_argument("path", type=Path, help="Path to disc image")
    p_ld.add_argument("--drive", "-d", type=int, default=0, help="Drive 0 or 1 (default 0)")
    p_ld.add_argument("--in-memory", action="store_true", help="Use in-memory image")
    p_ld.set_defaults(func=cmd_load_disc)

    args = parser.parse_args()
    resp = args.func(args)

    if args.command == "screen":
        handle_response(resp)
        lines = screen_bytes_to_ascii(resp.content, args.chars_per_line)
        text = "\n".join(lines) + "\n"
        if args.output is not None:
            args.output.write_text(text)
        else:
            print(text, end="")
    else:
        output_file = getattr(args, "output", None)
        handle_response(resp, output_file)
        if output_file is None and resp.content:
            sys.stdout.buffer.write(resp.content)


if __name__ == "__main__":
    main()

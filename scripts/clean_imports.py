#!/usr/bin/env python3
"""
Strip .import / .importzp from each src/**/*.s, run the same cl65 invocation as
the Makefile (via `make -n`), collect undefined symbols for that file, then
write back formatted imports (same rules as make_imports.py).
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from import_layout import (
    IMPORT_LINE_RE,
    collect_undefined_for_path,
    layout_import_lines,
    parse_exportzp_symbols,
)

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = REPO_ROOT / "src"
OS_S = SRC_DIR / "os.s"


def object_make_target(src: Path, current_target: str) -> str:
    rel = src.relative_to(SRC_DIR).with_suffix(".o")
    return f"obj/{current_target}/{rel.as_posix()}"


def parse_make_cl65_line(make_n_stdout: str) -> list[str] | None:
    for raw in make_n_stdout.splitlines():
        line = raw.strip()
        if line.startswith("cl65 "):
            return shlex.split(line)
    return None


def filter_cl65_for_scratch(argv: list[str]) -> list[str]:
    """Drop dep/listing/lbl outputs; keep single -o and source."""
    out: list[str] = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--create-dep", "--listing", "-Ln"):
            i += 2
            continue
        out.append(a)
        i += 1
    return out


def compile_staging(
    repo: Path,
    src: Path,
    staging: Path,
    current_target: str,
) -> tuple[int, str]:
    obj = object_make_target(src, current_target)
    mn = subprocess.run(
        ["make", "-n", "-B", obj],
        cwd=str(repo),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    argv = parse_make_cl65_line(mn.stdout + mn.stderr)
    if not argv:
        raise RuntimeError(f"Could not parse cl65 line from make -n {obj}: {mn.stdout!r}")

    argv = filter_cl65_for_scratch(argv)
    # Replace source path (last arg) and -o output
    try:
        oi = argv.index("-o")
    except ValueError as e:
        raise RuntimeError(f"No -o in cl65 argv: {argv}") from e

    with tempfile.NamedTemporaryFile(
        suffix=".o", delete=False, dir=str(repo / "build")
    ) as tf:
        out_o = tf.name
    try:
        argv[oi + 1] = out_o
        argv[-1] = str(staging)
        proc = subprocess.run(
            argv,
            cwd=str(repo),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        combined = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, combined
    finally:
        try:
            os.unlink(out_o)
        except OSError:
            pass


def strip_import_lines(lines: list[str]) -> tuple[list[str], int | None]:
    new: list[str] = []
    insert_at: int | None = None
    for line in lines:
        if IMPORT_LINE_RE.match(line):
            if insert_at is None:
                insert_at = len(new)
            continue
        new.append(line)
    return new, insert_at


def fallback_insert_at(lines: list[str]) -> int:
    for i, line in enumerate(lines):
        if re.match(r"^\s*\.(segment|code)\b", line, re.I):
            return i
    for i, line in enumerate(lines):
        if re.match(r"^[A-Za-z_@][\w@]*:\s*(;.*)?$", line):
            return i
    return 0


def splice_imports(
    body_lines: list[str],
    insert_at: int,
    import_lines: list[str],
) -> list[str]:
    if not import_lines:
        return body_lines
    if insert_at is None:
        insert_at = 0
    insert_at = max(0, min(insert_at, len(body_lines)))
    prefix = body_lines[:insert_at]
    suffix = body_lines[insert_at:]
    out: list[str] = []
    out.extend(prefix)
    if out and import_lines and out[-1].strip() != "":
        out.append("")
    out.extend(import_lines)
    if import_lines and suffix:
        while suffix and suffix[0].strip() == "":
            suffix = suffix[1:]
        if suffix and out[-1].strip() != "":
            out.append("")
    out.extend(suffix)
    return out


def process_file(
    src: Path,
    zp: set[str],
    current_target: str,
    dry_run: bool,
    verbose: bool,
) -> bool:
    text = src.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines(keepends=False)

    stripped, insert_at = strip_import_lines(lines)
    had_imports = insert_at is not None

    staging_dir = REPO_ROOT / "build" / "clean-imports-staging"
    staging_dir.mkdir(parents=True, exist_ok=True)
    staging = staging_dir / src.relative_to(SRC_DIR).as_posix().replace("/", "_")
    staging.write_text("\n".join(stripped) + ("\n" if stripped else ""), encoding="utf-8")

    try:
        _rc, combined = compile_staging(REPO_ROOT, src, staging, current_target)
    except Exception as e:
        print(f"{src}: compile setup failed: {e}", file=sys.stderr)
        return False

    syms = collect_undefined_for_path(combined, str(staging.resolve()))
    if had_imports and not syms:
        print(
            f"{src}: warning: no 'undefined symbol' diagnostics for staging file; "
            "leaving source unchanged (check assembler output).",
            file=sys.stderr,
        )
        return True

    if not syms and not had_imports:
        if verbose:
            print(f"{src}: skip (no imports, no undefined symbols)")
        return True

    insert = insert_at if insert_at is not None else fallback_insert_at(stripped)
    new_imports = layout_import_lines(syms, zp)
    new_lines = splice_imports(stripped, insert, new_imports)
    new_text = "\n".join(new_lines) + ("\n" if new_lines else "")

    if dry_run:
        print(f"--- {src} ({len(syms)} symbols) ---")
        print("\n".join(new_imports))
        return True

    if new_text != text:
        src.write_text(new_text, encoding="utf-8")
        print(f"{src}: wrote {len(new_imports)} import lines ({len(syms)} symbols)")
    elif verbose:
        print(f"{src}: unchanged")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(description="Regenerate .import / .importzp in src/**/*.s")
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be written, do not modify files",
    )
    ap.add_argument(
        "--verbose", "-v", action="store_true", help="Print per-file skip messages"
    )
    ap.add_argument(
        "files",
        nargs="*",
        type=Path,
        help="Specific .s files (default: all under src/)",
    )
    args = ap.parse_args()

    current_target = os.environ.get("CURRENT_TARGET", "none")
    zp = parse_exportzp_symbols(OS_S)

    (REPO_ROOT / "build").mkdir(parents=True, exist_ok=True)

    if args.files:
        sources = []
        for f in args.files:
            p = f if f.is_absolute() else REPO_ROOT / f
            p = p.resolve()
            if not str(p).startswith(str(SRC_DIR.resolve())):
                print(f"Skip (not under src/): {p}", file=sys.stderr)
                continue
            sources.append(p)
    else:
        sources = sorted(SRC_DIR.rglob("*.s"))

    ok = True
    for src in sources:
        if not process_file(src, zp, current_target, args.dry_run, args.verbose):
            ok = False

    scratch = REPO_ROOT / "build" / "clean-imports-staging"
    if scratch.exists():
        shutil.rmtree(scratch, ignore_errors=True)

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

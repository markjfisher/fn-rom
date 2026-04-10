#!/usr/bin/env python3
"""
create_ssd.py - Create BBC Micro SSD disk images from source files

Usage:
    ./create_ssd.py -i <input_dir> -o <output.ssd> [-t title] [-a load_addr] [-e exec_addr]

Handles:
- .bas files: tokenized using basictool (load/exec &001900 / &008023)
- Other files: copied with configurable load/exec (default same as create-ssd.sh)
"""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Optional, Tuple


def parse_hex_address(spec: str) -> int:
    """
    Parse a BBC-style load address from a string.
    Accepts: 0x1900, 1900, &1900, &001900 (hex, 6502 address space 0-0xFFFF).
    """
    s = spec.strip()
    if not s:
        raise ValueError("empty address")
    if s.lower().startswith("0x"):
        return int(s, 16)
    if s.startswith("&"):
        s = s[1:]
    return int(s, 16)


def format_bbc_address(addr: int) -> str:
    """Format as dfstool-style string, e.g. &001900 (matches create-ssd.sh)."""
    if addr < 0 or addr > 0xFFFF:
        raise ValueError(f"address out of 16-bit range: {addr:#x}")
    return f"&{addr:06X}"


def extract_filename_from_bas(bas_file: Path) -> str:
    """
    Extract filename from first line of BAS file if it contains:
    REM filename: DESIRED_NAME

    Returns the extracted name or the file's stem if not found.
    """
    try:
        first_line = bas_file.read_text().split("\n")[0]
        if "filename:" in first_line.lower():
            parts = first_line.lower().split("filename:", 1)
            if len(parts) > 1:
                name = parts[1].strip().split()[0]
                return name
    except OSError:
        pass

    return bas_file.stem


def truncate_filename(name: str, max_len: int = 7) -> str:
    """Truncate filename to BBC Micro limit (7 chars)."""
    if len(name) > max_len:
        print(f"  Warning: Filename truncated to fit BBC format: {name[:max_len]}")
        return name[:max_len]
    return name


def process_bas_file(bas_file: Path, temp_dir: Path) -> Tuple[str, Path]:
    """
    Tokenize a BASIC file and return (filename, tokenized_path).
    """
    extracted_name = extract_filename_from_bas(bas_file)
    filename = truncate_filename(extracted_name).upper()
    output_path = temp_dir / filename

    print(f"  Tokenizing: {bas_file.name} -> {filename}")

    result = subprocess.run(
        ["basictool", "-2", "-t", str(bas_file), str(output_path)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"Error tokenizing {bas_file}:")
        print(result.stderr)
        sys.exit(1)

    return filename, output_path


def process_data_file(data_file: Path, temp_dir: Path) -> Tuple[str, Path]:
    """
    Copy a data file as-is and return (filename, copied_path).
    """
    filename = truncate_filename(data_file.stem).upper()
    output_path = temp_dir / filename

    print(f"  Copying: {data_file.name} -> {filename}")

    output_path.write_bytes(data_file.read_bytes())

    return filename, output_path


def create_manifest(
    files_info: List[Tuple[str, Path, str]],
    temp_dir: Path,
    disc_title: str,
    disc_size: int,
    data_load_bbc: str,
    data_exec_bbc: str,
) -> Path:
    """
    Create JSON manifest for dfstool.

    files_info: list of (filename, path, type) tuples; type is "basic" or "data".
    """
    manifest_path = temp_dir / "manifest.json"

    files_json = []
    for filename, file_path, file_type in files_info:
        if file_type == "basic":
            load_addr = format_bbc_address(0x1900)
            exec_addr = format_bbc_address(0x8023)
        else:
            load_addr = data_load_bbc
            exec_addr = data_exec_bbc

        files_json.append(
            {
                "fileName": filename,
                "directory": "$",
                "locked": False,
                "loadAddress": load_addr,
                "executionAddress": exec_addr,
                "contentPath": str(file_path),
                "type": "basic" if file_type == "basic" else "other",
            }
        )

    manifest = {
        "version": 1,
        "discTitle": disc_title,
        "discSize": disc_size,
        "bootOption": "none",
        "cycleNumber": 0,
        "files": files_json,
    }

    manifest_path.write_text(json.dumps(manifest, indent=2))
    return manifest_path


def create_ssd(
    input_dir: Path,
    output_ssd: Path,
    disc_title: str,
    disc_size: int,
    data_load_addr: str,
    data_exec_addr: Optional[str],
):
    """Main function to create SSD disk image."""

    if not input_dir.is_dir():
        print(f"Error: Input directory '{input_dir}' does not exist")
        sys.exit(1)

    try:
        load_val = parse_hex_address(data_load_addr)
        load_bbc = format_bbc_address(load_val)
    except ValueError as e:
        print(f"Error: invalid --load-addr {data_load_addr!r}: {e}")
        sys.exit(1)

    if data_exec_addr is None:
        exec_bbc = load_bbc
    else:
        try:
            exec_val = parse_hex_address(data_exec_addr)
            exec_bbc = format_bbc_address(exec_val)
        except ValueError as e:
            print(f"Error: invalid --exec-addr {data_exec_addr!r}: {e}")
            sys.exit(1)

    for tool in ["basictool", "dfstool"]:
        result = subprocess.run(["which", tool], capture_output=True)
        if result.returncode != 0:
            print(f"Error: {tool} not found in PATH")
            sys.exit(1)

    bas_files = sorted(input_dir.glob("*.bas"))
    other_files = sorted(
        [f for f in input_dir.iterdir() if f.is_file() and f.suffix.lower() != ".bas"]
    )

    if not bas_files and not other_files:
        print(f"Error: No files found in '{input_dir}'")
        sys.exit(1)

    print("Creating SSD disk image...")
    print(f"  Disc title: {disc_title}")
    print(f"  Input directory: {input_dir}")
    print(f"  Output SSD: {output_ssd}")
    print(f"  Non-BASIC load/exec: {load_bbc} / {exec_bbc}")

    print(f"\nFound {len(bas_files)} .bas files to process:")
    for f in bas_files:
        print(f"  - {f.name}")

    print(f"Found {len(other_files)} other files to process:")
    for f in other_files:
        print(f"  - {f.name}")

    with tempfile.TemporaryDirectory() as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        print(f"\nUsing temporary directory: {temp_dir}")

        files_info = []

        if bas_files:
            print("\nTokenizing BAS files...")
            for bas_file in bas_files:
                filename, output_path = process_bas_file(bas_file, temp_dir)
                files_info.append((filename, output_path, "basic"))

        if other_files:
            print("\nCopying data files...")
            for data_file in other_files:
                filename, output_path = process_data_file(data_file, temp_dir)
                files_info.append((filename, output_path, "data"))

        print(f"\nCreating JSON manifest with {len(files_info)} files")
        manifest_path = create_manifest(
            files_info,
            temp_dir,
            disc_title,
            disc_size,
            load_bbc,
            exec_bbc,
        )

        print(f"\nCreating SSD disk image: {output_ssd}")
        result = subprocess.run(
            [
                "dfstool",
                "make",
                "--output",
                str(output_ssd),
                "--overwrite",
                str(manifest_path),
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            print("Error: Failed to create SSD disk image")
            print(result.stderr)
            sys.exit(1)

    print(f"\nSSD disk image created: {output_ssd}")
    print("Files included:")
    for filename, _, file_type in files_info:
        print(f"  - {filename} ({file_type})")


def main():
    parser = argparse.ArgumentParser(
        description="Create BBC Micro SSD disk images from source files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -i ./basfiles -o output.ssd
  %(prog)s -t MyDisc -i ./bin -o disk.ssd -a 0x8000
  %(prog)s -i ./mix -o disk.ssd -t Programs -a 0x1900 -e 0x2000

File handling:
  - .bas files are tokenized with basictool (load &001900, exec &008023)
  - Other files use --load-addr and --exec-addr (default load 0x1900; if --exec-addr
    is omitted, execution address matches load), matching create-ssd.sh behaviour.
        """,
    )

    parser.add_argument(
        "-i",
        "--input-dir",
        type=Path,
        required=True,
        help="Input directory containing source files",
    )

    parser.add_argument(
        "-o",
        "--ssd",
        type=Path,
        required=True,
        help="Output SSD disk image file",
    )

    parser.add_argument(
        "-t",
        "--title",
        default="beeb",
        help='Disc title (default: %(default)s, same as create-ssd.sh)',
    )

    parser.add_argument(
        "-a",
        "--load-addr",
        default="0x1900",
        help="Hex load address for non-.bas files (default: %(default)s)",
    )

    parser.add_argument(
        "-e",
        "--exec-addr",
        default=None,
        help="Hex execution address for non-.bas files (default: same as --load-addr)",
    )

    parser.add_argument(
        "--disc-size",
        type=int,
        default=800,
        help="Disc size in KB for manifest (default: %(default)s)",
    )

    args = parser.parse_args()

    create_ssd(
        args.input_dir,
        args.ssd,
        args.title,
        args.disc_size,
        args.load_addr,
        args.exec_addr,
    )


if __name__ == "__main__":
    main()

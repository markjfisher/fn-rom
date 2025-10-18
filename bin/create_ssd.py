#!/usr/bin/env python3
"""
create_ssd.py - Create BBC Micro SSD disk images from source files

Usage:
    ./create_ssd.py -i <input_dir> -o <output.ssd>
    
Handles:
- .bas files: tokenized using basictool
- Other files: copied as-is with load/exec addresses &0000
"""

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Tuple


def extract_filename_from_bas(bas_file: Path) -> str:
    """
    Extract filename from first line of BAS file if it contains:
    REM filename: DESIRED_NAME
    
    Returns the extracted name or the file's stem if not found.
    """
    try:
        first_line = bas_file.read_text().split('\n')[0]
        if 'filename:' in first_line.lower():
            # Extract text after "filename:"
            parts = first_line.lower().split('filename:', 1)
            if len(parts) > 1:
                name = parts[1].strip().split()[0]
                return name
    except Exception:
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
    # Extract and prepare filename
    extracted_name = extract_filename_from_bas(bas_file)
    filename = truncate_filename(extracted_name).upper()
    output_path = temp_dir / filename
    
    print(f"  Tokenizing: {bas_file.name} -> {filename}")
    
    # Run basictool
    result = subprocess.run(
        ['basictool', '-2', '-t', str(bas_file), str(output_path)],
        capture_output=True,
        text=True
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
    # Get base filename without extension
    filename = truncate_filename(data_file.stem).upper()
    output_path = temp_dir / filename
    
    print(f"  Copying: {data_file.name} -> {filename}")
    
    # Copy file as-is
    output_path.write_bytes(data_file.read_bytes())
    
    return filename, output_path


def create_manifest(files_info: List[Tuple[str, Path, str]], temp_dir: Path) -> Path:
    """
    Create JSON manifest for dfstool.
    
    files_info: list of (filename, path, type) tuples
    """
    manifest_path = temp_dir / "manifest.json"
    
    files_json = []
    for filename, file_path, file_type in files_info:
        # Set addresses based on type
        if file_type == "basic":
            load_addr = "&1900"
            exec_addr = "&8023"
        else:
            load_addr = "&0000"
            exec_addr = "&0000"
        
        files_json.append({
            "fileName": filename,
            "directory": "$",
            "locked": False,
            "loadAddress": load_addr,
            "executionAddress": exec_addr,
            "contentPath": str(file_path),
            "type": file_type
        })
    
    manifest = {
        "version": 1,
        "discTitle": "BASIC",
        "discSize": 800,
        "bootOption": "none",
        "cycleNumber": 0,
        "files": files_json
    }
    
    manifest_path.write_text(json.dumps(manifest, indent=2))
    return manifest_path


def create_ssd(input_dir: Path, output_ssd: Path):
    """Main function to create SSD disk image."""
    
    # Validate input directory
    if not input_dir.is_dir():
        print(f"Error: Input directory '{input_dir}' does not exist")
        sys.exit(1)
    
    # Check for required tools
    for tool in ['basictool', 'dfstool']:
        result = subprocess.run(['which', tool], capture_output=True)
        if result.returncode != 0:
            print(f"Error: {tool} not found in PATH")
            sys.exit(1)
    
    # Find all files
    bas_files = sorted(input_dir.glob("*.bas"))
    other_files = sorted([f for f in input_dir.iterdir() 
                         if f.is_file() and f.suffix != ".bas"])
    
    if not bas_files and not other_files:
        print(f"Error: No files found in '{input_dir}'")
        sys.exit(1)
    
    print(f"Found {len(bas_files)} .bas files to process:")
    for f in bas_files:
        print(f"  - {f.name}")
    
    print(f"Found {len(other_files)} other files to process:")
    for f in other_files:
        print(f"  - {f.name}")
    
    # Create temporary directory for processing
    with tempfile.TemporaryDirectory() as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        print(f"\nUsing temporary directory: {temp_dir}")
        
        files_info = []
        
        # Process BASIC files
        if bas_files:
            print("\nTokenizing BAS files...")
            for bas_file in bas_files:
                filename, output_path = process_bas_file(bas_file, temp_dir)
                files_info.append((filename, output_path, "basic"))
        
        # Process other files
        if other_files:
            print("\nCopying data files...")
            for data_file in other_files:
                filename, output_path = process_data_file(data_file, temp_dir)
                files_info.append((filename, output_path, "data"))
        
        # Create JSON manifest
        print(f"\nCreating JSON manifest with {len(files_info)} files")
        manifest_path = create_manifest(files_info, temp_dir)
        
        # Create SSD disk image
        print(f"\nCreating SSD disk image: {output_ssd}")
        result = subprocess.run(
            ['dfstool', 'make', '--output', str(output_ssd), 
             '--overwrite', str(manifest_path)],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print("Error: Failed to create SSD disk image")
            print(result.stderr)
            sys.exit(1)
    
    # Success!
    print(f"\nSuccess! SSD disk image created: {output_ssd}")
    print("Files included:")
    for filename, _, file_type in files_info:
        print(f"  - {filename} ({file_type})")
    
    print("\nYou can now load this disk image in your BBC Micro emulator.")


def main():
    parser = argparse.ArgumentParser(
        description='Create BBC Micro SSD disk images from source files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s -i ./basfiles -o output.ssd
  %(prog)s --input-dir ./bas --ssd disk.ssd

File handling:
  - .bas files are tokenized using basictool
  - All other files are copied as-is with load/exec addresses &0000
        """
    )
    
    parser.add_argument('-i', '--input-dir', 
                       type=Path,
                       required=True,
                       help='Input directory containing source files')
    
    parser.add_argument('-o', '--ssd',
                       type=Path,
                       required=True,
                       help='Output SSD disk image file')
    
    args = parser.parse_args()
    
    create_ssd(args.input_dir, args.ssd)


if __name__ == '__main__':
    main()


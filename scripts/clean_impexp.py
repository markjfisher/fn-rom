#!/usr/bin/env python3
"""
Clean import/export statements in assembly files.

This script processes assembly files to:
1. Split multi-entry import/export lines into single lines
2. Sort exports alphabetically
3. Sort imports alphabetically
4. Group exports before imports
5. Preserve other lines unchanged

Usage: python3 clean_impexp.py <file_path>
"""

import sys
import re
import argparse


def parse_import_export_lines(lines):
    """Parse lines and extract import/export statements using the suggested process."""
    exports = []
    imports = []
    before_section = []
    after_section = []
    
    i = 0
    # Read comments and other lines until we hit the first import/export
    while i < len(lines):
        line = lines[i].rstrip('\n\r')
        stripped = line.strip()
        
        # Check for .export or .import directive
        if re.match(r'^\s*\.(export|import)\s+', line):
            break
        
        before_section.append((i + 1, line))
        i += 1
    
    # Now we're at the start of the import/export section
    # Keep reading until we hit a non-import/export/blank line
    while i < len(lines):
        line = lines[i].rstrip('\n\r')
        stripped = line.strip()
        
        # Check for .export directive
        export_match = re.match(r'^(\s*)\.export\s+(.+)$', line)
        if export_match:
            indent = export_match.group(1)
            symbols = export_match.group(2).strip()
            # Split by comma and clean up whitespace
            symbol_list = [s.strip() for s in symbols.split(',') if s.strip()]
            for symbol in symbol_list:
                exports.append((i + 1, indent, symbol))
            i += 1
            continue
        
        # Check for .import directive
        import_match = re.match(r'^(\s*)\.import\s+(.+)$', line)
        if import_match:
            indent = import_match.group(1)
            symbols = import_match.group(2).strip()
            # Split by comma and clean up whitespace
            symbol_list = [s.strip() for s in symbols.split(',') if s.strip()]
            for symbol in symbol_list:
                imports.append((i + 1, indent, symbol))
            i += 1
            continue
        
        # Check for blank line
        if stripped == '':
            i += 1
            continue
        
        # This is a non-import/export/blank line - end of section
        break
    
    # Everything after this point goes to after_section
    while i < len(lines):
        line = lines[i].rstrip('\n\r')
        after_section.append((i + 1, line))
        i += 1
    
    return exports, imports, before_section, after_section


def generate_cleaned_lines(exports, imports, before_section, after_section):
    """Generate the cleaned output lines."""
    result_lines = []
    
    # Sort exports alphabetically by symbol name
    exports_sorted = sorted(exports, key=lambda x: x[2])
    
    # Sort imports alphabetically by symbol name
    imports_sorted = sorted(imports, key=lambda x: x[2])
    
    # Add everything before the import/export section
    for _, line in before_section:
        result_lines.append(line)
    
    # Add all exports (sorted)
    for _, indent, symbol in exports_sorted:
        result_lines.append(f"{indent}.export {symbol}")
    
    # Add a blank line between exports and imports if both exist
    if exports_sorted and imports_sorted:
        result_lines.append("")
    
    # Add all imports (sorted)
    for _, indent, symbol in imports_sorted:
        result_lines.append(f"{indent}.import {symbol}")
    
    # Add a blank line if we have exports/imports and other content
    if (exports_sorted or imports_sorted) and after_section:
        result_lines.append("")
    
    # Add everything after the import/export section
    for _, line in after_section:
        result_lines.append(line)
    
    return result_lines


def clean_file(file_path):
    """Clean import/export statements in the given file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
        return False
    except Exception as e:
        print(f"Error reading file '{file_path}': {e}")
        return False
    
    # Parse the lines
    exports, imports, before_section, after_section = parse_import_export_lines(lines)
    
    # Generate cleaned lines
    cleaned_lines = generate_cleaned_lines(exports, imports, before_section, after_section)
    
    # Write back to file
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            for line in cleaned_lines:
                f.write(line + '\n')
    except Exception as e:
        print(f"Error writing file '{file_path}': {e}")
        return False
    
    print(f"Cleaned import/export statements in '{file_path}'")
    print(f"  - {len(exports)} export statements")
    print(f"  - {len(imports)} import statements")
    
    return True


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description="Clean import/export statements in assembly files"
    )
    parser.add_argument(
        "file_path",
        help="Path to the assembly file to clean"
    )
    
    args = parser.parse_args()
    
    success = clean_file(args.file_path)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

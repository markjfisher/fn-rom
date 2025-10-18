#!/usr/bin/env python3
"""
Convert MMFS build log file to VICE label file format.

This script parses a log file from the MMFS build process and extracts
label definitions, converting them to VICE label file format.

The script looks for:
- Label lines: lines starting with a dot followed by word characters (e.g., ".langentry")
- Address lines: lines starting with 5 spaces followed by 4 hex digits (e.g., "     8000")

Usage:
    python3 log_to_vice_labels.py MMFS.log                    # Output to stdout
    python3 log_to_vice_labels.py MMFS.log labels.vice        # Output to file

Example input:
    .langentry
         8000   00         BRK
    .serventry
         8003   4C E1 8D   JMP &8DE1

Example output:
    al 008000 .langentry
    al 008003 .serventry
"""

import sys
import re
import argparse


def parse_log_to_vice_labels(log_content):
    """
    Parse log content and extract label definitions.
    
    Args:
        log_content: String content of the log file
        
    Returns:
        List of VICE label lines (e.g., "al 008000 .langentry")
    """
    lines = log_content.split('\n')
    labels = []
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Look for label lines: starts with dot followed by word characters
        if re.match(r'^\.\w+$', line):
            label_name = line
            
            # Look for the next address line (starts with 5 spaces + 4 hex digits)
            j = i + 1
            while j < len(lines):
                next_line = lines[j]
                if re.match(r'^     [0-9A-Fa-f]{4}', next_line):
                    # Extract the hex address
                    address_match = re.match(r'^     ([0-9A-Fa-f]{4})', next_line)
                    if address_match:
                        hex_address = address_match.group(1)
                        # Convert to VICE format: al 00XXXX .labelname
                        vice_line = f"al 00{hex_address} {label_name}"
                        labels.append(vice_line)
                    break
                j += 1
        i += 1
    
    return labels


def main():
    parser = argparse.ArgumentParser(
        description='Convert MMFS build log to VICE label file'
    )
    parser.add_argument('input_file', help='Input log file')
    parser.add_argument('output_file', nargs='?', help='Output label file (default: stdout)')
    
    args = parser.parse_args()
    
    try:
        with open(args.input_file, 'r') as f:
            log_content = f.read()
    except FileNotFoundError:
        print(f"Error: Input file '{args.input_file}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Parse the log and extract labels
    labels = parse_log_to_vice_labels(log_content)
    
    # Output the labels
    if args.output_file:
        try:
            with open(args.output_file, 'w') as f:
                for label in labels:
                    f.write(label + '\n')
            print(f"Generated {len(labels)} labels in '{args.output_file}'")
        except Exception as e:
            print(f"Error writing output file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        for label in labels:
            print(label)


if __name__ == '__main__':
    main()

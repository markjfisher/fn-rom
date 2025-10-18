#!/usr/bin/env python3
"""
BBC Micro Screen Memory Extractor

Reads screen memory from a binary dump and converts it to readable text.
BBC Micro screen memory is 40 characters wide, with characters in the range 32-126
being printable ASCII, and others displayed as dots.

Usage:
    python3 extract_screen.py -i <binary_file> -s <start_hex_address> [-l <num_lines>]

Example:
    python3 extract_screen.py -i memory.bin -s 7c00 -l 25
"""

import argparse
import sys

def extract_screen_memory(binary_file, start_address, num_lines=25, chars_per_line=40, dump_base=0x7C00):
    """
    Extract and decode BBC Micro screen memory from a binary file.
    
    Args:
        binary_file: Path to binary file containing memory dump
        start_address: Starting address in hex for display
        num_lines: Number of screen lines to extract (default 25)
        chars_per_line: Characters per line (default 40 for BBC Micro)
        dump_base: Base address of the memory dump (default 0x7C00)
    """
    try:
        with open(binary_file, 'rb') as f:
            # Read the entire file
            data = f.read()
            
        # Always treat as screen memory dump starting at dump_base
        screen_size = len(data)  # Use actual file size
        
        # Calculate initial offset within the screen dump
        if start_address >= dump_base:
            file_offset = (start_address - dump_base) % screen_size
        else:
            file_offset = 0
            
        print(f"Treating as screen memory dump from ${dump_base:04X}, starting display at ${start_address:04X}")
        
        print(f"Extracting {num_lines} lines from address ${start_address:04X}")
        print(f"File: {binary_file}, size: {len(data)} bytes")
        print("-" * (chars_per_line + 10))
        
        for line in range(num_lines):
            line_address = start_address + (line * chars_per_line)
            line_offset = (file_offset + (line * chars_per_line)) % screen_size
            
            # Extract the line data, handling wrap-around within the file
            if line_offset + chars_per_line <= screen_size:
                # Normal case - no wrap needed
                line_data = data[line_offset:line_offset + chars_per_line]
            else:
                # Wrap case - read from end of file and beginning
                first_part_size = screen_size - line_offset
                line_data = data[line_offset:] + data[:chars_per_line - first_part_size]
            
            # Convert to readable text
            text_line = ""
            
            for byte_val in line_data:
                # Convert to printable character or dot
                if 32 <= byte_val <= 126:
                    text_line += chr(byte_val)
                else:
                    text_line += "."
            
            # Print the line with address
            # print(f"${line_address:04X}: {text_line}")
            print(f"{text_line}")
            
        print("-" * (chars_per_line + 10))
        
    except FileNotFoundError:
        print(f"Error: File '{binary_file}' not found")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False
        
    return True

def main():
    parser = argparse.ArgumentParser(
        description="Extract BBC Micro screen memory from binary file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 extract_screen.py -i memory.bin -s 7C00
  python3 extract_screen.py -i memory.bin -s 7CC0 -l 10
  python3 extract_screen.py -i dump.bin -s 3000 -l 20
        """
    )
    
    parser.add_argument('-i', '--input', required=True,
                        help='Input binary file containing memory dump')
    parser.add_argument('-s', '--start', required=True,
                        help='Start address in hex (e.g., 7C00)')
    parser.add_argument('-l', '--lines', type=int, default=25,
                        help='Number of lines to extract (default: 25)')
    parser.add_argument('-b', '--base', default='7C00',
                        help='Base address of memory dump in hex (default: 7C00)')
    
    args = parser.parse_args()
    
    # Parse hex addresses
    try:
        if args.start.lower().startswith('0x'):
            start_addr = int(args.start, 16)
        else:
            start_addr = int(args.start, 16)
            
        if args.base.lower().startswith('0x'):
            base_addr = int(args.base, 16)
        else:
            base_addr = int(args.base, 16)
    except ValueError:
        print(f"Error: Invalid hex address '{args.start}' or '{args.base}'")
        return 1
    
    # Validate parameters
    if args.lines <= 0:
        print("Error: Number of lines must be positive")
        return 1
        
    if not extract_screen_memory(args.input, start_addr, args.lines, 40, base_addr):
        return 1
        
    return 0

if __name__ == "__main__":
    sys.exit(main())

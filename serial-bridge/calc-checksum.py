#!/usr/bin/env python3
"""
Calculate a checksum from input bytes
"""

import argparse
import sys
import os
import select
import time

def create_checksum(buf):
    """
    Calculate checksum using the FujiNet algorithm.
    
    Args:
        buf: List or bytes of data
    
    Returns:
        Checksum byte (0-255)
    """
    chk = 0
    for byte in buf:
        p1 = (chk + byte) >> 8
        p2 = (chk + byte) & 0xff
        chk = p1 + p2
        print(f"b: {byte:02X}, p1: {p1:02X}, p2: {p2:02X}, chk: {chk:04X}")
    return chk & 0xff


def parse_hex_bytes(hex_string):
    """
    Parse space-separated hex bytes from string.
    
    Args:
        hex_string: String like "00 01 02 03 04" or "00:01:02:03:04"
    
    Returns:
        List of integers (0-255)
    """
    # Remove common separators and split
    hex_string = hex_string.replace(':', ' ').replace(',', ' ')
    parts = hex_string.split()
    
    bytes_list = []
    for part in parts:
        try:
            # Parse as hex, handle 0x prefix if present
            if part.startswith('0x') or part.startswith('0X'):
                value = int(part, 16)
            else:
                value = int(part, 16)
            
            if value < 0 or value > 255:
                raise ValueError(f"Byte value {value} out of range (0-255)")
            
            bytes_list.append(value)
        except ValueError as e:
            print(f"Error parsing hex value '{part}': {e}", file=sys.stderr)
            sys.exit(1)
    
    return bytes_list


def main():
    parser = argparse.ArgumentParser(
        description='Calculate checksum from input file or command line bytes',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Using packet bytes directly:
  %(prog)s -p "00 01 02 03 04" -d 70
  %(prog)s --packet "0x00 0x01 0x02 0x03 0x04" --device 70

  # Using file for data bytes:
  %(prog)s -f /path/to/input-file -d 70
  %(prog)s --data /path/to/input-file --device 70
        '''
    )
    
    parser.add_argument(
        '-p', '--packet',
        help='5 hex bytes (space/colon/comma separated, e.g., "00 01 02 03 04")'
    )
    
    parser.add_argument(
        '-d', '--device',
        help='Device number in hex (e.g., 70)'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Print detailed information'
    )
    
    parser.add_argument(
        '-f', '--data',
        help='Data file to use for bytes to calculate checksum on'
    )
    
    args = parser.parse_args()
    
    if not args.device:
        print("Error: --device/-d is required", file=sys.stderr)
        parser.print_help()
        sys.exit(1)
    
    # Either packet or command must be specified
    if not args.packet and not args.data:
        print("Error: Either --packet/-p or --data/-f must be specified", file=sys.stderr)
        parser.print_help()
        sys.exit(1)
    
    if args.packet and args.data:
        print("Error: Cannot specify both --packet and --data", file=sys.stderr)
        sys.exit(1)
    
    # Get packet data from either file or packet argument
    if args.data:
        try:
            with open(args.data, 'rb') as f:
                file_bytes = f.read()  # raw bytes of the file
            packet_data = list(file_bytes)  # convert to list[int] for clarity
            if args.verbose:
                print(f"Read {len(packet_data)} bytes from '{args.data}'", file=sys.stderr)
        except OSError as e:
            print(f"Error reading file '{args.data}': {e}", file=sys.stderr)
            sys.exit(1)
    else:
        # Parse the hex bytes from packet argument
        packet_data = parse_hex_bytes(args.packet)
        if args.verbose:
            print(f"Parsed {len(packet_data)} byte(s) from --packet", file=sys.stderr)

    # Get the device number (hex like "70" or "0x70" both work)
    try:
        device = int(args.device, 16)
    except ValueError:
        print(f"Error: device '{args.device}' is not a valid hex value", file=sys.stderr)
        sys.exit(1)

    # Calculate checksum
    checksum = create_checksum([device] + packet_data)
    if args.verbose:
        print(f"Device: 0x{device:02X}", file=sys.stderr)
    print(f"Checksum: 0x{checksum:02X}")


if __name__ == '__main__':
    main()


#!/usr/bin/env python3
"""
Send a packet with checksum to a serial/PTY endpoint.
Takes 5 data bytes, calculates checksum, and writes all 6 bytes to the endpoint.
Optionally reads and displays the response.
"""

import argparse
import sys
import os
import select
import time

# Well-known command packets (5 bytes each)
COMMAND_MAP = {
    'reset': [0xFF, 0x00, 0x00, 0x00, 0x00],
    'get_ssid': [0xFE, 0x00, 0x00, 0x00, 0x00],
    'scan_networks': [0xFD, 0x00, 0x00, 0x00, 0x00],
    'get_scan_results': [0xFC, 0x00, 0x00, 0x00, 0x00],
    'get_adapter': [0xC4, 0x00, 0x00, 0x00, 0x00],
    'test': [0x00, 0x00, 0x00, 0x00, 0x00],
    # Add more commands here as needed
    # 'status': [0x53, 0x00, 0x00, 0x00, 0x00],
    # 'read': [0x52, 0x00, 0x00, 0x00, 0x00],
}


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
        chk = ((chk + byte) >> 8) + ((chk + byte) & 0xff)
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


def hexdump(data, offset=0):
    """
    Format data as hexdump -C style output.
    
    Args:
        data: bytes to display
        offset: starting offset for display
    """
    if not data:
        return
    
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        
        # Offset
        line = f"{offset + i:08x}  "
        
        # Hex bytes (split into two groups of 8)
        hex_parts = []
        for j in range(16):
            if j < len(chunk):
                hex_parts.append(f"{chunk[j]:02x}")
            else:
                hex_parts.append("  ")
        
        line += " ".join(hex_parts[:8]) + "  "
        line += " ".join(hex_parts[8:16])
        
        # ASCII representation
        line += "  |"
        for byte in chunk:
            if 32 <= byte <= 126:  # Printable ASCII
                line += chr(byte)
            else:
                line += "."
        line += "|"
        
        print(line)
    
    # Print final offset
    print(f"{offset + len(data):08x}")


def validate_response_checksum(response_data):
    """
    Validate response packet checksum.
    Response format:
      Byte 0: 'A' (ACK, 0x41)
      Byte 1: 'C' (COMPLETE, 0x43)
      Bytes 2 to N-1: Payload data
      Byte N: Checksum of payload
    
    Args:
        response_data: Full response bytes
    
    Returns:
        tuple: (is_valid, ack_char, complete_char, payload, received_checksum, calculated_checksum)
    """
    if len(response_data) < 3:
        return (False, None, None, b'', None, None)
    
    ack = response_data[0]
    complete = response_data[1]
    payload = response_data[2:-1]
    received_checksum = response_data[-1]
    calculated_checksum = create_checksum(payload)
    
    is_valid = (received_checksum == calculated_checksum)
    
    return (is_valid, ack, complete, payload, received_checksum, calculated_checksum)


def read_response(fd, timeout_ms=1000, max_bytes=1024):
    """
    Read response from file descriptor with timeout.
    
    Args:
        fd: file descriptor to read from
        timeout_ms: timeout in milliseconds
        max_bytes: maximum bytes to read
    
    Returns:
        bytes read, or empty bytes if timeout/error
    """
    data = b''
    start_time = time.time()
    timeout_sec = timeout_ms / 1000.0
    
    while True:
        elapsed = time.time() - start_time
        if elapsed >= timeout_sec:
            break
        
        remaining = timeout_sec - elapsed
        ready, _, _ = select.select([fd], [], [], remaining)
        
        if not ready:
            break
        
        try:
            chunk = os.read(fd, max_bytes - len(data))
            if not chunk:
                break
            data += chunk
            if len(data) >= max_bytes:
                break
        except OSError:
            break
    
    return data


def main():
    parser = argparse.ArgumentParser(
        description='Send packet with checksum to serial/PTY endpoint',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Using packet bytes directly:
  %(prog)s -p "00 01 02 03 04" -o /dev/pts/6 -d 70
  %(prog)s --packet "0x00 0x01 0x02 0x03 0x04" --endpoint /tmp/serial --device 70
  
  # Using a named command:
  %(prog)s -c reset -o /dev/pts/6 -d 70
  %(prog)s --command reset --endpoint /tmp/serial --device 70 -v
  
  # List available commands:
  %(prog)s --list-commands
        '''
    )
    
    parser.add_argument(
        '-p', '--packet',
        help='5 hex bytes (space/colon/comma separated, e.g., "00 01 02 03 04")'
    )
    
    parser.add_argument(
        '-c', '--command',
        help=f'Named command (available: {", ".join(COMMAND_MAP.keys())})'
    )
    
    parser.add_argument(
        '-o', '--endpoint',
        help='Path to endpoint (e.g., /dev/pts/6 or /tmp/serial)'
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
        '--list-commands',
        action='store_true',
        help='List all available named commands and exit'
    )
    
    parser.add_argument(
        '-r', '--read-response',
        action='store_true',
        help='Read and display response from endpoint after sending'
    )
    
    parser.add_argument(
        '-t', '--timeout',
        type=int,
        default=20,
        help='Response read timeout in milliseconds (default: 20)'
    )
    
    parser.add_argument(
        '-m', '--max-bytes',
        type=int,
        default=1024,
        help='Maximum response bytes to read (default: 1024)'
    )
    
    args = parser.parse_args()
    
    # Handle --list-commands
    if args.list_commands:
        print("Available commands:")
        for cmd, data in sorted(COMMAND_MAP.items()):
            print(f"  {cmd:12s} = {' '.join(f'{b:02X}' for b in data)}")
        sys.exit(0)
    
    # Validate required arguments
    if not args.endpoint:
        print("Error: --endpoint/-o is required", file=sys.stderr)
        parser.print_help()
        sys.exit(1)
    
    if not args.device:
        print("Error: --device/-d is required", file=sys.stderr)
        parser.print_help()
        sys.exit(1)
    
    # Either packet or command must be specified
    if not args.packet and not args.command:
        print("Error: Either --packet/-p or --command/-c must be specified", file=sys.stderr)
        parser.print_help()
        sys.exit(1)
    
    if args.packet and args.command:
        print("Error: Cannot specify both --packet and --command", file=sys.stderr)
        sys.exit(1)
    
    # Get packet data from either command or packet argument
    if args.command:
        if args.command not in COMMAND_MAP:
            print(f"Error: Unknown command '{args.command}'", file=sys.stderr)
            print(f"Available commands: {', '.join(COMMAND_MAP.keys())}", file=sys.stderr)
            sys.exit(1)
        packet_data = COMMAND_MAP[args.command]
        if args.verbose:
            print(f"Using command '{args.command}'")
    else:
        # Parse the hex bytes from packet argument
        packet_data = parse_hex_bytes(args.packet)

    # Get the device number
    device = int(args.device, 16)
    
    # Validate we have exactly 5 bytes
    if len(packet_data) != 5:
        print(f"Error: Expected exactly 5 data bytes, got {len(packet_data)}", file=sys.stderr)
        sys.exit(1)
    
    # Calculate checksum
    checksum = create_checksum([device] + packet_data)
    
    # Create final packet (1 device byte + 5 data bytes + 1 checksum byte)
    packet = bytes([device] + packet_data + [checksum])
    
    if args.verbose:
        print(f"Packet:     {' '.join(f'{b:02X}' for b in packet)} ({len(packet)} bytes)")
        print(f"Endpoint:   {args.endpoint}")
        print()
    
    # Write packet to endpoint and optionally read response
    try:
        # Open in read-write mode if we need to read response
        if args.read_response:
            fd = os.open(args.endpoint, os.O_RDWR | os.O_NONBLOCK)
            try:
                # Write packet
                os.write(fd, packet)
                
                if args.verbose:
                    print(f"Successfully sent {len(packet)} bytes to {args.endpoint}")
                else:
                    print(f"Sent: {' '.join(f'{b:02X}' for b in packet)}")
                
                # Read response
                print(f"\nWaiting for response (timeout: {args.timeout}ms)...")
                response = read_response(fd, timeout_ms=args.timeout, max_bytes=args.max_bytes)
                
                if response:
                    print(f"Received {len(response)} bytes:\n")
                    hexdump(response)
                    
                    # Validate response checksum
                    print()
                    is_valid, ack, complete, payload, recv_csum, calc_csum = validate_response_checksum(response)
                    
                    if len(response) >= 3:
                        print(f"Response structure:")
                        print(f"  Payload:  {len(payload)} bytes")
                        print(f"  Checksum: 0x{recv_csum:02X} (received)")
                        print(f"            0x{calc_csum:02X} (calculated)")
                        
                        if is_valid:
                            print(f"  ✓ Checksum VALID")
                        else:
                            print(f"  ✗ Checksum INVALID")
                        
                        # Show payload as string if it looks like text
                        if payload:
                            try:
                                # Try to decode as ASCII/UTF-8, stopping at first null
                                text = payload.split(b'\x00')[0].decode('ascii', errors='replace')
                                if text and all(32 <= ord(c) <= 126 or c in '\n\r\t' for c in text):
                                    print(f"\n  Payload text: \"{text}\"")
                            except:
                                pass
                    else:
                        print("Response too short for validation (< 3 bytes)")
                else:
                    print("No response received (timeout or no data)")
            finally:
                os.close(fd)
        else:
            # Just write and close
            with open(args.endpoint, 'wb') as f:
                f.write(packet)
            
            if args.verbose:
                print(f"Successfully sent {len(packet)} bytes to {args.endpoint}")
            else:
                print(f"Sent: {' '.join(f'{b:02X}' for b in packet)}")
    
    except FileNotFoundError:
        print(f"Error: Endpoint '{args.endpoint}' not found", file=sys.stderr)
        sys.exit(1)
    except PermissionError:
        print(f"Error: Permission denied accessing '{args.endpoint}'", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error accessing endpoint: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()


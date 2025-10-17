#!/usr/bin/env python3
"""
Breakpoint management script for b2 emulator.

Usage:
    python set-breakpoints.py -i breakpoints.csv [-n b2] [-h localhost] [-p 48075] [--clear-all] [-c]

Input CSV format:
    address,suffix,flags
    $8000,e,r|w|x
    findv_createfile,d,x
    CreateFile_2,d,x
"""

import argparse
import csv
import sys
import requests
from urllib.parse import quote


def parse_address(address_str):
    """Parse address string - either hex ($abcd) or symbol name."""
    address_str = address_str.strip()
    if address_str.startswith('$'):
        # Hex address
        return address_str
    else:
        # Symbol name
        return address_str


def build_url(host, port, machine, action, address, suffix=None, flags=None):
    """Build the HTTP request URL."""
    base_url = f"http://{host}:{port}/{action}/{machine}/{quote(address)}"
    
    params = []
    if suffix:
        params.append(f"s={suffix}")
    if flags:
        # Convert pipe-separated to comma-separated
        flag_list = [f.strip() for f in flags.split('|') if f.strip()]
        if flag_list:
            params.append(f"flags={','.join(flag_list)}")
    
    if params:
        base_url += "?" + "&".join(params)
    
    return base_url


def send_request(url, action):
    """Send HTTP request to b2 emulator."""
    try:
        response = requests.post(url, timeout=5)
        if response.status_code == 200:
            print(f"✓ {action}: {url}")
            return True
        else:
            print(f"✗ {action} failed: {url} (status: {response.status_code})")
            return False
    except requests.exceptions.RequestException as e:
        print(f"✗ {action} error: {url} ({e})")
        return False


def clear_all_breakpoints(host, port, machine):
    """Clear all breakpoints."""
    url = f"http://{host}:{port}/clear-breakpoint/{machine}/all"
    return send_request(url, "Clear all breakpoints")


def process_breakpoints_file(filename, host, port, machine, suffix, clear_mode=False):
    """Process breakpoints from CSV file."""
    success_count = 0
    total_count = 0
    
    try:
        with open(filename, 'r', newline='') as csvfile:
            reader = csv.DictReader(csvfile)
            
            for row in reader:
                total_count += 1
                address = row['address'].strip()
                if not address:
                    continue
                
                # Parse address
                parsed_address = parse_address(address)
                
                # Get suffix from row or use default
                row_suffix = row.get('suffix', '').strip()
                if row_suffix:
                    use_suffix = row_suffix
                else:
                    use_suffix = suffix
                
                # Get flags from row
                row_flags = row.get('flags', '').strip()
                
                # Build URL and send request
                if clear_mode:
                    url = build_url(host, port, machine, "clear-breakpoint", parsed_address)
                    action = "Clear breakpoint"
                else:
                    url = build_url(host, port, machine, "set-breakpoint", parsed_address, use_suffix, row_flags)
                    action = "Set breakpoint"
                
                if send_request(url, action):
                    success_count += 1
                    
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found")
        return False
    except Exception as e:
        print(f"Error processing file: {e}")
        return False
    
    print(f"\nProcessed {total_count} entries, {success_count} successful")
    return success_count == total_count


def main():
    parser = argparse.ArgumentParser(
        description="Manage breakpoints in b2 emulator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python set-breakpoints.py -i mmfs-breakpoints.csv
    python set-breakpoints.py -i breakpoints.csv -n b2 -h localhost -p 48075
    python set-breakpoints.py --clear-all
    python set-breakpoints.py -i breakpoints.csv -c
        """
    )
    
    parser.add_argument('-i', '--input', help='Input CSV file with breakpoints')
    parser.add_argument('-n', '--machine', default='b2', help='Machine name (default: b2)')
    parser.add_argument('--host', default='localhost', help='Host (default: localhost)')
    parser.add_argument('-p', '--port', type=int, default=48075, help='Port (default: 48075)')
    parser.add_argument('--clear-all', action='store_true', help='Clear all breakpoints')
    parser.add_argument('-c', '--clear', action='store_true', help='Clear breakpoints instead of setting them')
    
    args = parser.parse_args()
    
    # Handle clear-all
    if args.clear_all:
        success = clear_all_breakpoints(args.host, args.port, args.machine)
        sys.exit(0 if success else 1)
    
    # Handle input file
    if args.input:
        success = process_breakpoints_file(
            args.input, 
            args.host, 
            args.port, 
            args.machine, 
            None,  # suffix will be read from CSV
            args.clear
        )
        sys.exit(0 if success else 1)
    
    # No action specified
    parser.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()

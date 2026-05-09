#!/usr/bin/env python3
import argparse
import re
from typing import TextIO

# Start and end markers (match the exact states you described; tolerate extra spaces)
START_RE = re.compile(
    r'^.*; xxx_start_delay:.*$',
    re.IGNORECASE,
)
END_RE = re.compile(
    r'^.*; xxx_end_delay:.*$',
    re.IGNORECASE,
)

# Lines that begin with machine-trace addresses: "H $hhhh"
TRACE_LINE_RE = re.compile(r'^H \$[0-9a-fA-F]{4}')

def filter_log(fin: TextIO, fout: TextIO) -> None:
    """
    Copy input to output while pruning repeating delay loops.

    Rules:
      - When a START_RE line is seen, enter "skipping" mode.
      - While skipping:
          * Drop all lines that match TRACE_LINE_RE.
          * Still write any line that does NOT match TRACE_LINE_RE.
          * Exit skipping mode the moment an END_RE line is seen (do not write it).
      - Outside skipping, write everything verbatim.
      - Works across multiple loop occurrences.
    """
    skipping = False
    prev_line: Optional[str] = None

    for line in fin:
        if not skipping:
            if START_RE.match(line):
                skipping = True
                fout.write(line)
                continue
            else:
                fout.write(line)
        else:
            # We are inside a loop block
            if END_RE.match(line):
                # End of the loop block; stop skipping
                skipping = False
                fout.write(line)
                prev_line = line
                continue

            # While skipping, keep lines that do NOT look like "H $hhhh..."
            # e.g., "H SERPROC" or any other non-address line should be preserved.
            if not TRACE_LINE_RE.match(line):
                # Print the previous skipped line (if any)
                if prev_line is not None:
                    fout.write("...\n")
                    fout.write(prev_line)
                    fout.write(line)
                    prev_line = None
                    continue

        prev_line = line

def main():
    parser = argparse.ArgumentParser(
        description="Remove 6502 delay-loop trace bursts from logs while preserving non-address 'H ...' lines."
    )
    parser.add_argument("-i", "--input", required=True, help="Path to input log file")
    parser.add_argument("-o", "--output", required=True, help="Path to output log file")

    args = parser.parse_args()
    with open(args.input, "r", encoding="utf-8", errors="replace") as fin, \
         open(args.output, "w", encoding="utf-8") as fout:
        filter_log(fin, fout)

if __name__ == "__main__":
    main()

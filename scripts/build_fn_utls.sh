#!/usr/bin/env bash
# Build FN-UTLS.ssd: the transient utilities as standalone RAM binaries that call
# the resident ROM by absolute address (role-split Lever B disk execution).
#
# Mechanism: build the UTILITIES=disk ROM, turn its label file into a ca65 source
# (rom_abi.s) that defines every resident symbol at its fixed address, then
# assemble each utility (+ its duplicated utils-internal helpers + a tiny entry
# wrapper) for RAM and link it against rom_abi.o. See docs/ROM_ROLE_SPLIT_PHASE4.md.
set -euo pipefail
cd "$(dirname "$0")/.."          # repos/fn-rom
root="$(pwd)"

MACHINE="${BUILD_MACHINE:-BBC}"
OUT="$root/build/fn-utls"        # intermediate objects
STAGE="$root/build/fn-utls-ssd"  # only the files that go on the disk
ABISRC="$OUT/rom_abi.s"
SSD="$root/build/FN-UTLS.ssd"
LBL="$root/build/fujinet.rom.lbl"

# cc65 defines that must match the ROM build the binaries call into.
ASDEF=(-D "FUJINET_MACHINE_$MACHINE" -D FUJINET_INTERFACE_SERIAL -D FN_UTIL_BINARY)
[ "$MACHINE" = "MASTER" ] && CPU=(--cpu 65C02) || CPU=()
INC=(-I "$root/src" -I "$root/src/inc")

rm -rf "$OUT" "$STAGE"; mkdir -p "$OUT" "$STAGE"

echo "==> building UTILITIES=disk ROM (for resident symbol addresses)"
make -C "$root" FEATURE_NET=1 UTILITIES=disk BUILD_MACHINE="$MACHINE" all >/dev/null

echo "==> generating rom_abi.s from $LBL"
python3 - "$LBL" "$ABISRC" <<'PY'
import re, sys
lbl, out = sys.argv[1], sys.argv[2]
zp, ab = [], []
for line in open(lbl):
    m = re.match(r'^al\s+([0-9A-Fa-f]{6})\s+\.([A-Za-z_][A-Za-z0-9_]*)\s*$', line.strip())
    if not m:
        continue
    addr = int(m.group(1), 16) & 0xFFFF
    name = m.group(2)
    (zp if addr < 0x100 else ab).append((name, addr))
with open(out, "w") as f:
    f.write("; Generated from the ROM .lbl - resident symbols at fixed addresses.\n")
    for name, addr in zp:
        f.write(f".exportzp {name}\n{name} = ${addr:04X}\n")
    for name, addr in ab:
        f.write(f".export {name}\n{name} = ${addr:04X}\n")
print(f"   {len(zp)} zp + {len(ab)} abs symbols")
PY

# Build one utility binary: $1 = command name (DFS leaf), rest = source .s files.
build_one() {
  local name="$1"; shift
  local objs=()
  echo "==> assembling $name binary"
  ca65 "${CPU[@]}" "${ASDEF[@]}" "${INC[@]}" "$ABISRC" -o "$OUT/rom_abi.o"
  objs+=("$OUT/rom_abi.o")
  for src in "$@"; do
    local o="$OUT/$(basename "${src%.s}").o"
    ca65 "${CPU[@]}" "${ASDEF[@]}" "${INC[@]}" "$src" -o "$o"
    objs+=("$o")
  done
  ld65 -C "$root/cfg/fn-util.cfg" -o "$STAGE/$name" "${objs[@]}"
  # .inf: load/exec at PAGE ($1900), entry is _util_start (first byte of CODE)
  printf '%s 001900 001900\n' "$name" > "$STAGE/$name.inf"
  echo "   -> $STAGE/$name ($(stat -c%s "$STAGE/$name") bytes)"
}

# *FDRIVE: wrapper + the command + the utils-internal printer it duplicates.
build_one FDRIVE \
  "$root/utils-bin/fdrive.s" \
  "$root/src/utils/cmd_fdrive.s" \
  "$root/src/utils/cmd_flist.s" \
  "$root/src/utils/flist_resolve_target.s"

# An "F"-command may *RUN under its post-F leaf (e.g. *FDRIVE -> "DRIVE") or its
# full name; ship both catalog entries pointing at the same binary.
if [ -f "$STAGE/FDRIVE" ]; then
  cp "$STAGE/FDRIVE" "$STAGE/DRIVE"
  printf 'DRIVE 001900 001900\n' > "$STAGE/DRIVE.inf"
fi

echo "==> staging + bundling FN-UTLS.ssd"
cp "$root/dist/fn-utls/!BOOT" "$STAGE/!BOOT"
printf '$.!BOOT 000000 000000\n' > "$STAGE/!BOOT.inf"
"$root/scripts/create_ssd.py" -i "$STAGE" -o "$SSD" -t FN-UTLS
echo "==> $SSD"

#!/usr/bin/env bash
# Build FN-UTLS.ssd: every transient utility as a standalone RAM binary that calls
# the resident ROM by absolute address (role-split Lever B disk execution).
#
# Mechanism: build the UTILITIES=disk ROM, turn its label file into a ca65 source
# (rom_abi.s) that defines every resident symbol at its fixed address, then
# assemble each utility (+ its duplicated utils-internal helpers + a generated
# entry wrapper) for RAM and link it against rom_abi.o. See
# docs/ROM_ROLE_SPLIT_PHASE4.md / docs/ROM_ROLE_SPLIT_PHASE5.md.
#
# Filename note: when a transient command is typed, fn-rom leaves service &04
# unclaimed and the MOS asks the FS to *RUN it as a file. The FS reads the leaf
# from the *start* of the command line (read_fspba in fs_functions.s rewinds to
# offset 0), so the requested leaf is the **full typed name** including any
# leading F (e.g. *FDRIVE -> "FDRIVE", *FORM -> "FORM", *COPY -> "COPY"). DFS
# caps a disc at 31 files and a leaf at 7 chars; every transient command name is
# <= 7 chars (the unmount command is *FUMOUNT, not *FUNMOUNT, for this reason).
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
make -B -C "$root" FEATURE_NET=1 UTILITIES=disk BUILD_MACHINE="$MACHINE" all >/dev/null

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

# Assemble the shared resident-ABI object once.
ca65 "${CPU[@]}" "${ASDEF[@]}" "${INC[@]}" "$ABISRC" -o "$OUT/rom_abi.o"

# Generate a tiny entry wrapper for one handler, then enter the resident handler;
# its closing rts returns to the MOS (the binary is entered by jmp, tail-call
# style). The GSINIT string pointer (text_pointer) must point at the command's
# argument tail before the handler parses it. Two modes:
#   args : the FS *RUN leaves the tail addressed by fuji_text_ptr_hi:offset, so
#          point text_pointer there (commands that take parameters).
#   noarg: point text_pointer at an in-binary CR, i.e. an empty parameter line
#          (commands that take none — the *RUN handoff is not relied upon).
gen_wrapper() {
  local handler="$1" mode="$2" out="$OUT/wrap_${handler}.s"
  if [ "$mode" = noarg ]; then
    cat > "$out" <<EOF
        .export   _util_start
        .importzp text_pointer
        .import   $handler
        .segment "CODE"
_util_start:
        lda     #<empty_line
        sta     text_pointer
        lda     #>empty_line
        sta     text_pointer+1
        ldy     #\$00
        jmp     $handler
empty_line:
        .byte   \$0D
EOF
  else
    cat > "$out" <<EOF
        .export   _util_start
        .importzp text_pointer
        .import   $handler
        .import   fuji_text_ptr_hi
        .import   fuji_text_ptr_offset
        .segment "CODE"
_util_start:
        lda     fuji_text_ptr_offset
        sta     text_pointer
        lda     fuji_text_ptr_hi
        sta     text_pointer+1
        ldy     #\$00
        jmp     $handler
EOF
  fi
  echo "$out"
}

# build_util LEAF HANDLER SRC...  (SRC = the command module + any utils-internal
# helpers it depends on; the wrapper is generated and linked first so _util_start
# is the binary's entry at PAGE). Prefix HANDLER with "noarg:" for a no-parameter
# command (uses the in-binary empty parameter line).
build_util() {
  local leaf="$1" handler="$2"; shift 2
  local mode=args
  case "$handler" in noarg:*) mode=noarg; handler="${handler#noarg:}";; esac
  local wrap; wrap="$(gen_wrapper "$handler" "$mode")"
  local objs=("$OUT/rom_abi.o")
  echo "==> $leaf  ($handler)"
  for src in "$wrap" "$@"; do
    local o="$OUT/$(basename "${src%.s}").$leaf.o"
    ca65 "${CPU[@]}" "${ASDEF[@]}" "${INC[@]}" "$src" -o "$o"
    objs+=("$o")
  done
  ld65 -C "$root/cfg/fn-util.cfg" -o "$STAGE/$leaf" "${objs[@]}"
  printf '%s 001900 001900\n' "$leaf" > "$STAGE/$leaf.inf"
}

U="$root/src/utils"

# Each binary is staged under the full command name the FS *RUN looks up.
build_util FDRIVE  noarg:cmd_fs_fdrive "$U/cmd_fdrive.s" "$U/cmd_flist.s" "$U/flist_resolve_target.s"
build_util FBOOT   noarg:cmd_fs_fboot  "$U/cmd_fboot.s"
build_util FCD     cmd_fs_fcd      "$U/cmd_fcd.s" "$U/flist_resolve_target.s"
build_util FLS     cmd_fs_flist    "$U/cmd_flist.s" "$U/flist_resolve_target.s"
build_util FLIST   cmd_fs_flist    "$U/cmd_flist.s" "$U/flist_resolve_target.s"
build_util FNEW    cmd_fs_fnew     "$U/cmd_fs_fnew.s"
build_util FOUT    cmd_fs_fout     "$U/cmd_fout.s"
build_util FUMOUNT cmd_fs_funmount "$U/cmd_funmount.s"   # *FUMOUNT (renamed from FUNMOUNT to fit DFS 7-char leaf)
build_util COPY    cmd_fs_copy     "$U/cmd_copy.s"
build_util DESTROY cmd_fs_destroy  "$U/cmd_destroy.s" "$U/confirm.s"
build_util WIPE    cmd_fs_wipe     "$U/cmd_wipe.s" "$U/confirm.s"
build_util TITLE   cmd_fs_title    "$U/cmd_title.s"
build_util ACCESS  cmd_fs_access   "$U/cmd_access.s"
build_util RENAME  cmd_fs_rename   "$U/cmd_rename.s"
build_util VERIFY  cmd_fs_verify   "$U/cmd_verify_format.s"
build_util MAP     cmd_fs_map      "$U/cmd_free_map.s"
build_util FORM    cmd_fs_form     "$U/cmd_verify_format.s"
build_util FREE    cmd_fs_free     "$U/cmd_free_map.s"

echo "==> staging + bundling FN-UTLS.ssd ($(ls "$STAGE" | grep -vc '\.inf$') files)"
cp "$root/utils-bin/!BOOT" "$STAGE/!BOOT"
printf '$.!BOOT 000000 000000\n' > "$STAGE/!BOOT.inf"
"$root/scripts/create_ssd.py" -i "$STAGE" -o "$SSD" -t FN-UTLS
echo "==> $SSD"

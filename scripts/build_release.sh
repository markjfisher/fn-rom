#!/usr/bin/env bash
# Stage the DISK+NET ("net") release bundle (docs/ROM_ROLE_SPLIT_PLAN.md §1, §6
# Phase 5): the FN-NET ROM(s) + FN-UTLS.ssd (boot/config utilities disk) + the
# bundled BASIC example apps as ready-to-mount SSDs.
#
# A "BBC release" = fn-rom + FN-UTLS.ssd + the example disks; pair it with a
# BBC-flavoured fujinet build on the device side.
#
# Output: dist/release/
#   FN-NET          BBC DISK+NET ROM image  (sideways ROM, load $8000)
#   FN-NET-M        Master DISK+NET ROM image
#   FN-UTLS.ssd     BBC boot/config utilities disk
#   FN-UTLS-M.ssd   Master boot/config utilities disk
#   examples/<app>.ssd   one SSD per bundled bas/ example
#   README.txt      what each file is + how to use it
#
# Example apps default to the network demos; override with RELEASE_APPS:
#   RELEASE_APPS="weather iss" ./scripts/build_release.sh
set -euo pipefail
cd "$(dirname "$0")/.."          # repos/fn-rom
root="$(pwd)"

REL="$root/dist/release"
EX="$REL/examples"
APPS=(${RELEASE_APPS:-weather iss net fcs})

rm -rf "$REL"
mkdir -p "$REL" "$EX"

echo "==> building DISK+NET ROMs (BBC + Master)"
make -C "$root" net >/dev/null
cp "$root/build/fujinet.rom" "$REL/FN-NET"
make -C "$root" net BUILD_MACHINE=MASTER >/dev/null
cp "$root/build/fujinet-master.rom" "$REL/FN-NET-M"

echo "==> building FN-UTLS.ssd (BBC boot/config utilities disk)"
BUILD_MACHINE=BBC FN_UTLS_SSD="$root/build/FN-UTLS.ssd" \
  "$root/scripts/build_fn_utls.sh" >/dev/null
cp "$root/build/FN-UTLS.ssd" "$REL/FN-UTLS.ssd"

echo "==> building FN-UTLS-M.ssd (Master boot/config utilities disk)"
BUILD_MACHINE=MASTER FN_UTLS_SSD="$root/build/FN-UTLS-M.ssd" \
  "$root/scripts/build_fn_utls.sh" >/dev/null
cp "$root/build/FN-UTLS-M.ssd" "$REL/FN-UTLS-M.ssd"

# Example app SSDs. Needs basictool + dfstool (see README); skip gracefully if
# absent so a ROM-only release still builds.
if command -v basictool >/dev/null 2>&1 && command -v dfstool >/dev/null 2>&1; then
  for app in "${APPS[@]}"; do
    src="$root/bas/$app"
    if [ -d "$src" ]; then
      echo "==> example: $app -> examples/$app.ssd"
      "$root/scripts/create_ssd.py" -i "$src" -o "$EX/$app.ssd" -t "$(echo "$app" | tr '[:lower:]' '[:upper:]')"
    else
      echo "   (skip $app: no bas/$app)"
    fi
  done
else
  echo "==> skipping example SSDs (basictool/dfstool not on PATH)"
fi

cat > "$REL/README.txt" <<'EOF'
fn-rom DISK+NET release bundle
==============================

Contents
  FN-NET         BBC DISK+NET sideways ROM (network device + disk; management
                 utilities are on the boot/config disk, FN-UTLS.ssd). Burn to a
                 sideways ROM or load into an emulator at $8000.
  FN-NET-M       As above, for the BBC Master.
  FN-UTLS.ssd    BBC boot/config utilities disk: config tools plus
                 management/informational utilities (*FORM, *COPY, *FLS,
                 *FDRIVE, ...). Copy to the fujinet device's SD card when using
                 FN-NET.
  FN-UTLS-M.ssd  Master boot/config utilities disk. Copy as the boot/config disk
                 when using FN-NET-M.
  examples/      Ready-to-mount demo apps (one SSD each).

Using the boot/config utilities disk
  The utilities are not in the ROM in this build; they load on demand from
  FN-UTLS.ssd via the MOS unrecognised-command -> *RUN fallthrough. Mount it and
  make it the library so a *command resolves there from any current drive:

    *FHOST sd0:/
    *FIN 7 fn-utls.ssd      ; bind the utils image to slot 7
    *FMOUNT 7 3             ; mount slot 7 as BBC drive 3
    *LIB :3                 ; library = drive 3

  (FN-UTLS.ssd ships a !BOOT that does exactly this; *OPT 4,3 to auto-run it.)

Pair with a BBC-flavoured fujinet build on the device side.

Compatibility note
  Utilities call resident ROM routines through the stable jump table at $8030,
  so routine movement inside the ROM is tolerated as long as that table remains
  compatible. BBC and Master boot/config utility disks are still separate
  because the transient binaries also refer to target-specific workspace/data
  addresses.
EOF

echo "==> release staged at $REL"
ls -1 "$REL" "$EX" 2>/dev/null | sed 's/^/    /'

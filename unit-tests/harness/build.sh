#!/bin/bash

LABEL_FILE="${WS_ROOT}/build/fujinet.rom.lbl"

if [[ -z "$WS_ROOT" || ! -f "${LABEL_FILE}" ]]; then
  echo "Check WS_ROOT and the rom has been built."
  exit 1
fi

make_label() {
    local symbol="$1"

    awk -v symbol=".$symbol" '
    $3 == symbol {
        printf "%s := $%X\n",
            substr($3, 2),
            strtonum("0x"$2)
    }
    ' "${LABEL_FILE}"
}

mkdir build 2>/dev/null
rm -f build/*

# generate fnrom.inc with values from the fn-rom labels file
rm fnrom.inc
make_label init_fuji >> fnrom.inc

ca65 -t none -o build/crt0.o crt0.s
ca65 -t none -o build/osbyte_stub.o osbyte_stub.s
ca65 -t none -o build/mos_vectors.o mos_vectors.s
ca65 -t none -o build/fscv_stub.o fscv_stub.s
ca65 -t none -o build/stubs.o stubs.s

ld65 -C harness.ld65.cfg \
    build/crt0.o \
    build/osbyte_stub.o \
    build/mos_vectors.o \
    build/fscv_stub.o \
    build/stubs.o \
    -m build/harness.map \
    -Ln build/harness.lbl \
    -o harness.xex

sed -i '/.__/d' build/harness.lbl
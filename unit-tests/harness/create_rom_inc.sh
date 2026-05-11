#!/bin/bash

LABEL_FILE="${WS_ROOT}/build/fujinet.rom.lbl"

if [[ -z "$WS_ROOT" || ! -f "${LABEL_FILE}" ]]; then
  echo "Check WS_ROOT and the rom has been built. You may need to run test_env.sh to create env vars"
  exit 1
fi

# Don't include CC65 generated symbols like __MAIN_START__
# this converts all symbol names in the VICE label file,
# converting from "al 00ABCD .init_fuji" into "init_fuji := $ABCD" for ca65 to consume
awk '!/\.__.*__/ {
    printf "%s := $%X\n", substr($3, 2), strtonum("0x" $2)
}' "${LABEL_FILE}" > fnrom.inc

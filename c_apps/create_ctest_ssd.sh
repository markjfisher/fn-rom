#!/bin/bash

if [[ -z "${CC65_SRC}" || ! -d "${CC65_SRC}" ]]; then
  echo "You must set CC65_SRC env var to point to a fork of CC65 that contains the BBC target."
  exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd ${SCRIPT_DIR}

cd ctest1
make clean all

cd -
mkdir -p ../build/c_apps_ssd

# copy built apps and inf files into ssd temp folder
cp ctest1/build/ct1 ../build/c_apps_ssd
cp ctest1/ct1.inf   ../build/c_apps_ssd

../scripts/create_ssd.py -t ctests -i ../build/c_apps_ssd/ -o ../build/ctests.ssd

echo "📄 ==== REPORT ===="
echo "🔧 Completed build of $(realpath ../build/ctests.ssd)."
echo "🔍 You may want to copy it to a TNFS folder."

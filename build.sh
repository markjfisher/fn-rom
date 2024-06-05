#!/usr/bin/env bash
#
# Everything in this repo is heavily influenced by and copied from mmfs at
# https://github.com/hoglet67/MMFS


function show_help {
  echo "Usage: $(basename $0) [options]"
  echo ""
  echo "   -d       # enable debug"
  exit 1
}

ENABLE_DEBUG="FALSE"

while getopts "dh" flag
do
  case "$flag" in
    d) ENABLE_DEBUG="TRUE" ;;
    h) show_help ;;
    *) show_help ;;
  esac
done
shift $((OPTIND - 1))

BEEB_CLI=${BEEB_CLI:-"beeb"}
BEEBASM=${BEEBASM:-"beebasm"}

which ${BEEB_CLI} > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "You must have 'beeb' (from MMFS_Utils) installed on your path"
  exit 1
fi

which ${BEEBASM} > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "You must have 'beebasm' (compile from src) installed on your path"
  exit 1
fi

PROJECT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BUILD_DIR=${PROJECT_DIR}/build
SRC_DIR=${PROJECT_DIR}/src

BEEBASM_ARGS=""

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

VERSION=`grep '#VERSION#' ${SRC_DIR}/version.asm | cut -d\" -f2`

# we only have 1 system to build
system="FujiNet"

ssd=${BUILD_DIR}/$(echo ${system} | tr '[:upper:]' '[:lower:]').ssd
rm -f ${ssd}
${BEEB_CLI} blank_ssd ${ssd}
${BEEB_CLI} title ${ssd} "${system} ${VERSION}"
${BEEB_CLI} info ${ssd}

echo "MACRO SYSTEM_NAME"         > ${BUILD_DIR}/device.asm
echo "    EQUS \"${system}\""   >> ${BUILD_DIR}/device.asm
echo "ENDMACRO"                 >> ${BUILD_DIR}/device.asm
echo "_DEBUG = ${ENABLE_DEBUG}" >> ${BUILD_DIR}/device.asm

# <nothing>=beeb, e=electon, m=master, ...
build_files="${SRC_DIR}/start/FN.asm ${SRC_DIR}/start/eFN.asm ${SRC_DIR}/start/mFN.asm"

for f in ${build_files}; do
  name=$(basename $(echo ${f%.asm}))
  echo "Building ${name}..."
  ${BEEBASM} -i ${f} -o ${BUILD_DIR}/${name} ${BEEBASM_ARGS} -v >& ${BUILD_DIR}/${name}.log

  if [ ! -f ${BUILD_DIR}/${name} ]; then
    cat ${BUILD_DIR}/${name}.log
    echo "ERROR: failed to create  ${BUILD_DIR}/${name}"
    exit 1
  fi

  echo -e "\$."${name}"\t8000\t8000" > ${BUILD_DIR}/${name}.inf

  ${BEEB_CLI} putfile ${ssd} ${BUILD_DIR}/${name}

  rm -f ${BUILD_DIR}/${name}.inf

  grep "code ends at" ${BUILD_DIR}/${name}.log

  mv ${BUILD_DIR}/${name} ${BUILD_DIR}/${name}.rom

done

echo ""
${BEEB_CLI} info ${ssd}

#!/bin/bash
#
# Runs BEEBEM with the Beeb version of the ROM
# Set BEEBEM env variable if it is not installed at the same location as below.
BEEBEM=${BEEBEM:-"/c/Program Files (x86)/BeebEm/BeebEm.exe"}

if [ ! -f "${BEEBEM}" ]; then
  echo "Unable to find beebem executable. Set BEEBEM env var to point to it"
  exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# substitute the path into the templated config
SCRIPT_DIR_WINDOWS=$(cygpath -am ${SCRIPT_DIR})
sed "s#__ROOT_DIR__#${SCRIPT_DIR_WINDOWS}#" < cfg/beebem-fn-rom.cfg > build/rom.cfg

# Command line options are in Help/commandline.html, the source for which is at https://github.com/stardot/beebem-windows/blob/master/Help/commandline.html
"${BEEBEM}" -Roms $(cygpath -am ${SCRIPT_DIR}/build/rom.cfg)

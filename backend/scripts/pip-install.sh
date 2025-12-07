#!/bin/bash
#

THIS_FILE=$(readlink -f "$0")
THIS_DIR=$(dirname "$THIS_FILE")
LIB_VENV="${THIS_DIR}/lib_venv.sh"
source "$LIB_VENV" || exit 1
source "$FILE_VENV" || exit 1
	

function main() {
  pip3 "$@"
}

main "$@"

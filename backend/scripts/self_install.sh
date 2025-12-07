#!/bin/bash
#

THIS_FILE=$(readlink -f "$0")
THIS_DIR=$(dirname "$THIS_FILE")
LIB_VENV="${THIS_DIR}/lib_venv.sh"
FILE_REQ="${THIS_DIR}/requirements.txt"
source "$LIB_VENV" || exit 1

function config(){
	source "$FILE_VENV" || exit 1
	pip3 install --upgrade pip
	[[ -f "$FILE_REQ" ]] && pip3 install -r "$FILE_REQ"
	pip3 install .
}

function main() {
  config
}

main "$@"

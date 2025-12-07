#!/bin/bash
#
# Intalar uma VENV loacal em sistemas Linux
#
# Em sistemas Windows você pode instalar os módulos com o seguinte comando:
# python.exe -m pip install -r requirements.txt
# python.exe -m pip install 'https://gitlab.com/bschavesbr/file-utils/-/archive/main/file-utils-main.zip'

THIS_FILE=$(readlink -f "$0")
THIS_DIR=$(dirname "$THIS_FILE")
LIB_VENV="${THIS_DIR}/lib_venv.sh"
FILE_REQ="${THIS_DIR}/requirements.txt"
source "$LIB_VENV" || exit 1

function add_venv(){
	python3 -m venv "$DIR_VENV"
}

function config_venv(){
	source "$FILE_VENV" || exit 1
	pip3 install --upgrade pip
	[[ -f "$FILE_REQ" ]] && pip3 install -r "$FILE_REQ"
}

function main() {
  add_venv
  config_venv
}

main "$@"

#!/bin/bash
#

THIS_FILE=$(readlink -f "$0")
THIS_DIR=$(dirname "$THIS_FILE")
LIB_VENV="${THIS_DIR}/scripts/lib_venv.sh"
source "$LIB_VENV" || exit 1
source "$FILE_VENV" || exit 1
	

function main() {
  readonly PORT=5000
  echo -e "IP Servidor (hostname): $(hostname -I | cut -d ' ' -f 1)"
  uvicorn server:app --host 0.0.0.0 --port "$PORT"
	#uvicorn server:app --reload
  #python3 "${THIS_DIR}/server.py"
}

main "$@"

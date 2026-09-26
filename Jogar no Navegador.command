#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"
if [[ ! -f web/index.html ]]; then ./tools/export_web.sh; fi
exec python3 tools/serve_web.py --multiplayer "$@"

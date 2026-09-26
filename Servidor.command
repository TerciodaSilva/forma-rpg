#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
exec "$PROJECT_DIR/Jogar.command" --headless -- --server "$@"

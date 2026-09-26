#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_DIR"
FORMA_GODOT=${FORMA_GODOT:-"$PROJECT_DIR/.tools/Godot.app/Contents/MacOS/Godot"}
if [ ! -x "$FORMA_GODOT" ]; then FORMA_GODOT=godot; fi
if [ ! -f .tools/web-templates/web_nothreads_release.zip ]; then
  python3 tools/fetch_web_templates.py
fi
mkdir -p web
"$FORMA_GODOT" --headless --path . --editor --import --quit
"$FORMA_GODOT" --headless --path . --export-release Web web/index.html

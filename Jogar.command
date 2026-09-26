#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h}"
ENGINE="$PROJECT_DIR/.tools/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$ENGINE" ]]; then
  ENGINE="/Applications/Godot.app/Contents/MacOS/Godot"
fi
if [[ ! -x "$ENGINE" ]]; then
  echo "Instale o Godot 4.3 ou superior e importe o arquivo project.godot."
  echo "https://godotengine.org/download/macos/"
  read -r "?Pressione Enter para sair."
  exit 1
fi
exec "$ENGINE" --path "$PROJECT_DIR" "$@"

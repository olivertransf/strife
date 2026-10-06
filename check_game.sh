#!/bin/zsh
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -x "$GODOT" ]]; then
	echo "RESULT fail missing Godot at $GODOT" >&2
	exit 1
fi

run_mode() {
	local mode="$1"
	shift
	echo "== $mode =="
	"$GODOT" --headless --path "$ROOT" -- --"$mode" "$@"
}

if [[ "${1:-all}" == "capture" ]]; then
	"$GODOT" --path "$ROOT" -- --capture
	exit $?
fi

run_mode rules
run_mode sim --games 30 --seed 1
echo "RESULT ok"

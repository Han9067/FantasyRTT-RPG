#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.godot-runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.godot-runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.godot-runtime/cache}"
mkdir -p builds/web
godot --headless --editor --import --quit
godot --headless --script res://tests/smoke.gd
godot --headless --export-release Web builds/web/index.html
touch builds/web/.nojekyll

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.godot-runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.godot-runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.godot-runtime/cache}"
godot --headless --editor --import --quit
godot --headless --script res://tests/smoke.gd
release_version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
[[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
# Generated output only. Versioned asset names prevent stale browser PCK/WASM caches.
rm -rf builds/web
mkdir -p builds/web
godot --headless --export-release Web "builds/web/game-${release_version}.html"
mv "builds/web/game-${release_version}.html" builds/web/index.html
touch builds/web/.nojekyll

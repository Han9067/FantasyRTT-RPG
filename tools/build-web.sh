#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.godot-runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.godot-runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.godot-runtime/cache}"
mkdir -p builds
touch builds/.gdignore
python tools/build_medieval_atlas.py
python tools/build_world_map.py
godot --headless --editor --import --quit
godot --headless --script res://tests/smoke.gd
godot --headless --script res://tests/battle_smoke.gd
godot --headless --script res://tests/world_smoke.gd
release_version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
[[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
# Generated output only. Versioned asset names prevent stale browser PCK/WASM caches.
rm -rf builds/web
mkdir -p builds/web
godot --headless --export-release Web "builds/web/game-${release_version}.html"
mv "builds/web/game-${release_version}.html" builds/web/index.html
touch builds/web/.nojekyll

# Versioned review documents are directly downloadable alongside the game.
cp docs/weapons/weapon-name-proposals-ko.txt "builds/web/weapon-names-${release_version}.txt"
cp docs/weapons/weapon-name-proposals-ko.csv "builds/web/weapon-names-${release_version}.csv"

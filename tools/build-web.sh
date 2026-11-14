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
python tests/world_plan_check.py
godot --headless --editor --import --quit
godot --headless --script res://tests/smoke.gd
godot --headless --script res://tests/battle_smoke.gd
godot --headless --script res://tests/world_navigation_smoke.gd
godot --headless --script res://tests/world_smoke.gd
release_version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
[[ "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
# Each export gets new URLs even when a version number is reused or reset.
build_id="${release_version}-$(date -u +%Y%m%d%H%M%S)"
test_url="https://han9067.github.io/FantasyRTT-RPG/?v=${build_id}"
# Generated output only. Unique asset names prevent stale browser PCK/WASM caches.
rm -rf builds/web
mkdir -p builds/web
godot --headless --export-release Web "builds/web/game-${build_id}.html"
mv "builds/web/game-${build_id}.html" builds/web/index.html
touch builds/web/.nojekyll
printf '{"version":"%s","build_id":"%s","test_url":"%s"}\n' \
  "$release_version" "$build_id" "$test_url" > builds/web/build-info.json

# Versioned review documents are directly downloadable alongside the game.
cp docs/weapons/weapon-name-proposals-ko.txt "builds/web/weapon-names-${release_version}.txt"
cp docs/weapons/weapon-name-proposals-ko.csv "builds/web/weapon-names-${release_version}.csv"

# Visual review of the user-authored world layout and numbered cities.
cp docs/world/numbered-world-plan.png "builds/web/world-plan-${release_version}.png"
printf 'Test URL: %s\n' "$test_url"

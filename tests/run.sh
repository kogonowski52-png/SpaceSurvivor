#!/usr/bin/env bash
set -euo pipefail

project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
qa_temp="$(mktemp -d)"
trap 'rm -rf -- "$qa_temp"' EXIT
export XDG_CACHE_HOME="$qa_temp/cache"
export XDG_CONFIG_HOME="$qa_temp/config"
export XDG_DATA_HOME="$qa_temp/data"

"$godot_bin" --headless --path "$project" --editor --import
"$godot_bin" --headless --path "$project" --script res://tests/arsenal.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/encounters.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/progression.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/audit_settings.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/commerce.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/monetization_1_1.gd
"$godot_bin" --headless --path "$project" --script res://tests/economy_1_1.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/play_delivery.gd
"$godot_bin" --headless --path "$project" --fixed-fps 60 --script res://tests/smoke.gd -- "$@"

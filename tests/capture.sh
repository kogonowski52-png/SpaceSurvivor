#!/usr/bin/env bash
set -euo pipefail

project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output="${1:?Podaj katalog na zrzuty ekranu}"
mkdir -p -- "$output"
output="$(cd -- "$output" && pwd)"
qa_temp="$(mktemp -d)"
trap 'rm -rf -- "$qa_temp"' EXIT
export XDG_CACHE_HOME="$qa_temp/cache"
export XDG_CONFIG_HOME="$qa_temp/config"
export XDG_DATA_HOME="$qa_temp/data"

"$godot_bin" --headless --path "$project" --editor --import
for size in 720x1280 1080x1920 1080x2400; do
  "$godot_bin" --path "$project" --resolution "$size" --disable-vsync \
    --audio-driver Dummy --script res://tests/smoke.gd -- \
    --capture-dir "$output" --expect-size "$size"
done

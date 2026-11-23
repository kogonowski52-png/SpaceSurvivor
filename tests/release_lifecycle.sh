#!/usr/bin/env bash
set -euo pipefail
project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-godot}"
output="${1:?Podaj katalog logów}"
mkdir -p -- "$output"
qa=$(mktemp -d)
pid=""
trap 'if [[ -n "$pid" ]]; then kill -TERM "$pid" 2>/dev/null || true; fi; rm -rf -- "$qa"' EXIT
export XDG_CACHE_HOME="$qa/cache"
export XDG_CONFIG_HOME="$qa/config"
export XDG_DATA_HOME="$qa/data"
"$godot_bin" --headless --path "$project" --editor --import > "$output/qa-lifecycle-import.log" 2>&1
"$godot_bin" --path "$project" --resolution 720x1280 --fixed-fps 60 --disable-vsync \
  --audio-driver Dummy --script res://tests/release_lifecycle.gd > "$output/qa-lifecycle-before.log" 2>&1 &
pid=$!
for attempt in {1..240}; do
  if rg -q '^READY_FOR_TERMINATION' "$output/qa-lifecycle-before.log"; then break; fi
  kill -0 "$pid"
  sleep 0.25
done
rg '^READY_FOR_TERMINATION' "$output/qa-lifecycle-before.log"
kill -TERM "$pid"
status=0
wait "$pid" || status=$?
pid=""
test "$status" -eq 143
timeout 60 "$godot_bin" --path "$project" --resolution 720x1280 --fixed-fps 60 --disable-vsync --audio-driver Dummy \
  --script res://tests/release_lifecycle.gd -- --verify-relaunch > "$output/qa-lifecycle-restart.log" 2>&1
if rg -n '^FAIL:|SCRIPT ERROR|^ERROR:' "$output/qa-lifecycle-before.log" "$output/qa-lifecycle-restart.log"; then exit 1; fi
rg '^PASS:' "$output/qa-lifecycle-restart.log"

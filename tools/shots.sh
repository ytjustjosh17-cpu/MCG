#!/usr/bin/env bash
# Render every screen to PNGs:  tools/shots.sh [out_dir]   (default /tmp/sol-shots)
# Look at the ones you changed before committing a screen change.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/sol-shots}"
G="${G:-}"
for c in "$G" "$HOME/.cache/sol-godot/Godot_v4.4.1-stable_linux.x86_64" /tmp/claude-*/*/*/scratchpad/godot/Godot_v4.4.1-stable_linux.x86_64; do
	[ -n "$c" ] && [ -x "$c" ] && { G="$c"; break; }
done
[ -x "$G" ] || { echo "Run tools/check_all.sh once first (it fetches Godot)."; exit 2; }
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$ROOT/game" && timeout 900 xvfb-run -a "$G" --path . --resolution 390x844 -s res://tests/screenshot.gd -- "$OUT" >"$OUT/run.log" 2>&1
echo "$(ls "$OUT"/*.png 2>/dev/null | wc -l) screens in $OUT"

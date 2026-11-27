#!/usr/bin/env bash
# One command for every check before a commit or release.
#   tools/check_all.sh          rules + all 9 test suites (4 lanes in parallel)
#   tools/check_all.sh --quick  rules + smoke + touch test (while iterating)
# Prints one line per suite and the failing checks. Exit code 0 = all pass.
# Each lane runs in its own copy of the game with its own user folder, so
# suites never share a save file.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

# ---- Godot 4.4.1: $G, a cached copy, or download it once ----
find_godot() {
	if [ -n "${G:-}" ] && [ -x "$G" ]; then echo "$G"; return; fi
	for c in "$HOME/.cache/sol-godot/Godot_v4.4.1-stable_linux.x86_64" /godot/Godot_v4.4.1-stable_linux.x86_64 \
		/tmp/claude-*/*/*/scratchpad/godot/Godot_v4.4.1-stable_linux.x86_64; do
		[ -x "$c" ] && { echo "$c"; return; }
	done
	mkdir -p "$HOME/.cache/sol-godot"
	local z="$HOME/.cache/sol-godot/godot.zip"
	curl -sL -o "$z" "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_linux.x86_64.zip" \
		&& (cd "$HOME/.cache/sol-godot" && python3 -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall('.')" "$z") \
		&& chmod +x "$HOME/.cache/sol-godot/Godot_v4.4.1-stable_linux.x86_64" \
		&& echo "$HOME/.cache/sol-godot/Godot_v4.4.1-stable_linux.x86_64"
}
G="$(find_godot)"
[ -x "$G" ] || { echo "No Godot 4.4.1 found or downloaded"; exit 2; }

START=$(date +%s)
FAIL=0
echo "== rules"
if ! python3 "$ROOT/tools/check_rules.py" >/tmp/sol_rules.txt 2>&1; then cat /tmp/sol_rules.txt; FAIL=1; else tail -1 /tmp/sol_rules.txt; fi

# Import once in the real project, then copy it per lane (fast: a few MB).
( cd "$ROOT/game" && "$G" --headless --path . --import >/dev/null 2>&1 )
WORK="$(mktemp -d /tmp/sol-check.XXXX)"

# lane name | touch emulation (1/0) | suites (with optional args after ':')
if [ $QUICK = 1 ]; then
	LANES=("a|0|smoke_test" "b|1|scroll_test")
else
	LANES=("a|0|smoke_test market_test:20" "b|0|stress_test casino_test forge_test fit_test" \
		"c|1|scroll_test tables_ui_test" "d|1|slots_ui_test forge_ui_test casino12_test")
fi

run_lane() {
	local name="$1" touch="$2" suites="$3"
	local dir="$WORK/$name"
	mkdir -p "$dir" && cp -r "$ROOT/game/." "$dir/"
	{
		printf '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="sol-check-%s"\n' "$name"
		[ "$touch" = 1 ] && printf '\n[input_devices]\n\npointing/emulate_touch_from_mouse=true\n'
	} > "$dir/override.cfg"
	for s in $suites; do
		local t="${s%%:*}" a=""
		[ "$s" != "$t" ] && a="-- ${s#*:}"
		local log="$WORK/$t.log"
		( cd "$dir" && timeout 900 "$G" --headless --path . -s "res://tests/$t.gd" $a >"$log" 2>&1 )
		echo $? > "$WORK/$t.code"
	done
}

for l in "${LANES[@]}"; do
	IFS='|' read -r n tch su <<<"$l"
	run_lane "$n" "$tch" "$su" &
done
wait

for l in "${LANES[@]}"; do
	IFS='|' read -r n tch su <<<"$l"
	for s in $su; do
		t="${s%%:*}"
		code=$(cat "$WORK/$t.code" 2>/dev/null || echo 1)
		res=$(grep -E "^Failures" "$WORK/$t.log" | tail -1)
		if [ "$code" != 0 ] || [ -z "$res" ] || [ "$res" != "Failures: 0" ]; then
			FAIL=1
			echo "FAIL $t ($res, exit $code)"
			grep -E "^FAIL|SCRIPT ERROR: (Parse|Invalid)" "$WORK/$t.log" | head -8 | sed 's/^/    /'
		else
			echo "ok   $t"
		fi
	done
done
rm -rf "$WORK"
echo "== $( [ $FAIL = 0 ] && echo ALL PASS || echo FAILED ) in $(( $(date +%s) - START )) s"
exit $FAIL

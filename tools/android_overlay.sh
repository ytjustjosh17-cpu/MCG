#!/usr/bin/env bash
# Sets up Godot's Android build template with Sol's own Android code (the
# home screen widget):  tools/android_overlay.sh
# Unpacks the template from the 4.4.1 export templates into game/android/build
# (what the editor's "Install Android Build Template" does), then adds the
# widget. Run before exporting. Safe to run twice.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/game/android_src"
DST="$ROOT/game/android/build"
VER="4.4.1.stable"
ZIP="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/$VER}/android_source.zip"
if [ ! -f "$DST/AndroidManifest.xml" ]; then
	[ -f "$ZIP" ] || { echo "Missing $ZIP (install the Godot $VER export templates)"; exit 1; }
	mkdir -p "$DST"
	unzip -q -o "$ZIP" -d "$DST"
	printf '%s' "$VER" > "$ROOT/game/android/.build_version"
	touch "$DST/.gdignore"
fi
cp -r "$SRC/src/." "$DST/src/"
cp -r "$SRC/res/." "$DST/res/"
if ! grep -q "com.redsunholdings.game.widget.SolWidget" "$DST/AndroidManifest.xml"; then
	# Put the <receiver> just before </application>.
	awk -v rec="$SRC/receiver.xml" '
		/<\/application>/ && !done { while ((getline line < rec) > 0) print line; done = 1 }
		{ print }
	' "$DST/AndroidManifest.xml" > "$DST/AndroidManifest.xml.new"
	mv "$DST/AndroidManifest.xml.new" "$DST/AndroidManifest.xml"
fi
grep -q "com.redsunholdings.game.widget.SolWidget" "$DST/AndroidManifest.xml"
echo "Widget added to the Android build"

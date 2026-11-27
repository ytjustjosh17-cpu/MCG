#!/usr/bin/env python3
"""Project rules for Sol. Run before every commit; CI runs it on every push.

    python3 tools/check_rules.py

Each rule has an id (R1, R2 ...) that matches CLAUDE.md. Exit code 1 if any
rule is broken, with the file and line. Keep rules cheap and certain: a rule
that cries wolf gets ignored.
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
SCRIPTS = sorted(glob.glob(os.path.join(GAME, "scripts", "*.gd")))
TESTS = sorted(glob.glob(os.path.join(GAME, "tests", "*.gd")))
DOCS = [os.path.join(ROOT, p) for p in ("README.md", "LICENSE", "CLAUDE.md")] + sorted(
    glob.glob(os.path.join(ROOT, "docs", "*.md")))

problems = []


def fail(rule, path, line, msg):
    rel = os.path.relpath(path, ROOT) if path else "-"
    problems.append(f"{rule}  {rel}:{line}  {msg}")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def strings_in(line):
    return re.findall(r'"((?:[^"\\]|\\.)*)"', line)


def code_part(line):
    """The line without a trailing # comment (ignores # inside strings)."""
    out, q = [], False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == "#" and not q:
            break
        out.append(ch)
    return "".join(out)


def tracked_files():
    try:
        out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True)
        return out.stdout.splitlines()
    except Exception:
        return []


# R1  Colours come from UI tokens (ui.gd). No hex colours anywhere else.
for p in SCRIPTS:
    if p.endswith("/ui.gd"):
        continue
    for i, l in enumerate(read(p).split("\n"), 1):
        if 'Color("#' in code_part(l):
            fail("R1", p, i, "hex colour outside ui.gd; add a token to UI instead")

# R2  Every ScrollContainer ignores small finger wobble (else taps on phones fail).
for p in SCRIPTS:
    lines = read(p).split("\n")
    for i, l in enumerate(lines):
        m = re.search(r"(\w[\w\.]*)\s*:?=\s*ScrollContainer\.new\(\)", l)
        if m and not any("scroll_deadzone" in x for x in lines[i:i + 4]):
            fail("R2", p, i + 1, f"{m.group(1)} needs scroll_deadzone (see page.gd)")

# R3  Sliding or scaling animations respect Reduce motion: Motion.d(...) or a
#     function that already returns early when Motion.reduced().
for p in SCRIPTS:
    if p.endswith("/motion.gd"):
        continue
    for i, l in enumerate(read(p).split("\n"), 1):
        if re.search(r'tween_property\([^,]+,\s*"(position|scale)', l) and "Motion.d(" not in l and "reduced-checked" not in l:
            fail("R3", p, i, "position/scale tween without Motion.d(); wrap the duration")

# R4  No em dashes and no hidden Unicode in anything a person reads.
HIDDEN = re.compile("[​‌‍⁠﻿    ­‪-‮⁦-⁩]")
for p in SCRIPTS:
    for i, l in enumerate(read(p).split("\n"), 1):
        for s in strings_in(code_part(l)):
            if "—" in s:
                fail("R4", p, i, "em dash in player-facing text")
for p in SCRIPTS + DOCS:
    if not os.path.exists(p):
        continue
    for i, l in enumerate(read(p).split("\n"), 1):
        if HIDDEN.search(l):
            fail("R4", p, i, "hidden Unicode character")
for p in DOCS:
    if os.path.exists(p):
        for i, l in enumerate(read(p).split("\n"), 1):
            if "—" in l:
                fail("R4", p, i, "em dash in docs")

# R5  Licensing: Fontshare fonts (Switzer, Tanker) must never be in the repo;
#     only the OFL Inter files are allowed as font files.
for f in tracked_files():
    low = f.lower()
    if low.endswith((".ttf", ".otf", ".woff", ".woff2")) and not re.search(r"assets/fonts/inter-", low):
        fail("R5", os.path.join(ROOT, f), 0, "font file in git; Fontshare fonts are downloaded at build time")
    if "/fonts/ext/" in low:
        fail("R5", os.path.join(ROOT, f), 0, "fonts/ext is build-time only")

# R6  The app identity never changes (or every install loses its save).
ep = read(os.path.join(GAME, "export_presets.cfg"))
if 'package/unique_name="com.redsunholdings.game"' not in ep:
    fail("R6", os.path.join(GAME, "export_presets.cfg"), 0, "package name changed; installs would not update")

# R7  Saves: every field written by to_dict() is read back in load_game(),
#     and SAVE_VERSION has a matching step in _migrate().
gs_path = os.path.join(GAME, "scripts", "game_state.gd")
gs = read(gs_path)
m = re.search(r"func to_dict\(\).*?return \{(.*?)\n\t\}", gs, re.S)
if m:
    keys = set(re.findall(r'"(\w+)":', m.group(1)))
    load = gs[gs.index("func load_game()"):]
    load = load[: load.index("\nfunc ", 10)]
    for k in sorted(keys - {"version", "saved_at"}):
        if f'd.get("{k}"' not in load and f'd["{k}"]' not in load:
            fail("R7", gs_path, 0, f'save field "{k}" is never loaded')
else:
    fail("R7", gs_path, 0, "could not find to_dict()")
v = re.search(r"const SAVE_VERSION := (\d+)", gs)
if v and f"if v < {v.group(1)}:" not in gs:
    fail("R7", gs_path, 0, f"SAVE_VERSION {v.group(1)} has no 'if v < {v.group(1)}:' step in _migrate")

# R8  No throwaway files in git (agent scripts, debug scripts, overrides, keys).
for f in tracked_files():
    base = os.path.basename(f)
    if base.startswith(("_agent", "_dbg", "_bench", "_touch", "_stress", "_ld", "_mk")) or base == "override.cfg":
        fail("R8", os.path.join(ROOT, f), 0, "throwaway file is tracked")
    if f.endswith(".keystore") and f != "game/android/release.keystore":
        fail("R8", os.path.join(ROOT, f), 0, "unexpected signing key in git")

# R9  No leftover debug prints in game code (use GameLog instead).
for p in SCRIPTS:
    if p.endswith("/game_log.gd"):
        continue
    for i, l in enumerate(read(p).split("\n"), 1):
        if re.match(r"\s*print(_debug)?\(", l):
            fail("R9", p, i, "print() in game code; use GameLog.info()")

# R10 Every page that is pushed has a way back (super(title, true)).
for p in SCRIPTS:
    s = read(p)
    if re.search(r"^extends Page", s, re.M) and re.search(r'super\("[^"]*"\)', s):
        # Tabs (Invest, Items, ...) have no back button on purpose; they are listed here.
        if os.path.basename(p) not in ("invest_page.gd", "items_page.gd", "profile_page.gd", "business_page.gd"):
            fail("R10", p, 0, "pushed page without a back button; use super(title, true)")

# R11 Tests exist for each test suite CI runs.
for t in ("smoke_test.gd", "stress_test.gd", "scroll_test.gd", "pacing_sim.gd", "market_test.gd", "casino_test.gd", "slots_ui_test.gd", "tables_ui_test.gd", "casino12_test.gd", "fit_test.gd", "forge_test.gd", "forge_ui_test.gd"):
    if not os.path.exists(os.path.join(GAME, "tests", t)):
        fail("R11", None, 0, f"missing tests/{t}")

if problems:
    print("Project rules broken:\n")
    for x in problems:
        print("  " + x)
    print(f"\n{len(problems)} problem(s). See CLAUDE.md for what each rule means.")
    sys.exit(1)
print("All project rules pass (R1-R11).")

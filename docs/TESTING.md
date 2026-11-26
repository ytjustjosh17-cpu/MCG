# Sol testing guide

Every push runs the rules and the tests on GitHub before a release is built.
Run them yourself first. A release with a failing test is never pushed.

## Setup

- Godot 4.4.1 editor for Linux: `Godot_v4.4.1-stable_linux.x86_64` from the Godot releases page. In these docs it's `$G`.
- The Godot project is `game/`. Import it once: `cd game && $G --headless --import --path .`
- Optional, for the real fonts in screenshots: download Switzer and Tanker from Fontshare into `game/assets/fonts/ext/` (the CI step in `.github/workflows/android.yml` shows how). Never commit them.

## The checks

| Check | Command (from `game/` unless noted) | What it covers | Time |
|---|---|---|---|
| Rules | `python3 tools/check_rules.py` (repo root) | R1 to R11 in CLAUDE.md | 1 s |
| Smoke | `$G --headless --path . -s res://tests/smoke_test.gd` | Every system, every page builds, saves, migrations, exploits, update flow, storage limits | 15 s |
| Stress | `$G --headless --path . -s res://tests/stress_test.gd` | Spam buying, odd input, clock going backwards, a year away, huge numbers | 10 s |
| Touch | see below | Scrolling over buttons, wobbly taps, chart drags, sheets, the trade slider, typing an amount, the Lock sheet | 20 s |
| Pacing | see BALANCE.md (`SIM_REBIRTH=rate` for rebirths) | Days to each milestone | 5 min |
| Screenshots | see below | How every page looks | 1 min |

Touch test (the phone has a touchscreen, so this must run as one):
```
printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg
$G --headless --path . -s res://tests/scroll_test.gd
rm override.cfg
```

Market fairness (8 seconds; CI runs it):
```
$G --headless --path . -s res://tests/market_test.gd -- 20
```

Screenshots of a mid-game save, every tab, sheets and popups:
```
xvfb-run -a -s "-screen 0 1280x1024x24" $G --path . --rendering-driver opengl3 \
  --resolution 390x844 -s res://tests/screenshot.gd -- /some/output/folder
```
Rebirth: shots 33 (tree) and 34 (a node). Trade pop-ups are shots 09e (sell), 09f (convert), 09g (buy) and 09h (lock); 31 shows the miner rack.
README pictures live in `docs/screenshots/` and come from this run (01_earn, 03_taxi, 06_invest_shares, 31_crypto_mining, 09c_share, 13_profile). Copy fresh ones in when those screens change.

Lines saying `Identifier not found: Game` at the start are harmless (scripts compiling before the autoloads load).

## Writing tests

- Tests are `SceneTree` scripts. Get the game with `root.get_node("Game")`, the UI kit with `root.get_node("Kit")`.
- Load pages with `load("res://scripts/x.gd").new()`, not by class name (avoids early-compile errors).
- Control time with `game.sim_time` (set it back to `-1.0` when done).
- Give every test a watchdog: `create_timer(N).timeout.connect(func(): quit(1))`.
- Taps must be real input events with a few pixels of wobble (`_wobble_tap` in `scroll_test.gd`). Calling a handler directly skips the bugs that matter on a phone.
- The navigation ignores a second page opened within 450 ms (spam guard). Wait 0.6 s between pushes in tests.
- Big cash in a test makes "rival passed" toasts appear. Set `game.counters["rivals"] = 10` first if that gets in the way.
- Name throwaway scripts `_something.gd` and delete them. Rule R8 fails if one is committed.

## Play-testing with agents

Agent play-testers found real bugs every time. Personas that worked:
- Confused beginner (reads nothing, taps everything, presses back a lot)
- Button spammer (taps 50 times a second, hammers back, switches tabs mid-animation)
- Exploit hunter (tries to make money from markets, deals, backups, the clock)
- Once-a-day player (two short sessions a day, gaps of days)
- Completionist (plays a lot for 80 days, wants 100%)
- Small phone and Reduce motion
- Design reviewers (screenshot every page, judge against DESIGN.md)

Point them at the working branch (agent worktrees start from `main`), tell them to report only, and fix what they confirm.

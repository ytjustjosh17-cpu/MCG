# Sol: rules for working on this project

Sol is a personal idle tycoon game for one phone (Samsung S23, Android).
It is built with Godot 4.4.1 and released by GitHub Actions.
Read this file before changing anything. Then read the doc for the area you touch:

- [docs/DESIGN.md](docs/DESIGN.md): look, colours, type, motion, wording
- [docs/BALANCE.md](docs/BALANCE.md): economy, pace targets, how to check them
- [docs/TESTING.md](docs/TESTING.md): every test and how to run it
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): where things live and how they connect

## The owner

- Writes and reads in British English. Keep replies short, simple, in small chunks (the owner is dyslexic).
- Wants a premium, clean, Apple-meets-brutalist look on a dark teal background with one red sun.
- Wants the game to take weeks, not days. It must never become easy by accident.
- Installs updates with the Update button in Profile. Every push to the working branch makes a release.

## Never do these

1. Never change the package name `com.redsunholdings.game`. Phones would treat it as a new app and lose the save. (R6)
2. Never commit Fontshare fonts (Switzer, Tanker). Their licence allows them inside the app, not in a public repo. CI downloads them. (R5)
3. Never break old saves. New save fields need a default when loading and a step in `_migrate()`. Bump `SAVE_VERSION`. (R7)
4. Never add money, multipliers or automation without running the pacing robot before and after. See BALANCE.md.
5. Never show real brands, real companies or real coins. Everything in the game is made up.
6. Never push a release with a failing test.

## Before every commit

Install the hook once so the rules run on every commit:
`cp tools/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`

Run all of these from the repo root. All must pass.

```
python3 tools/check_rules.py
cd game && $G --headless --path . -s res://tests/smoke_test.gd
cd game && $G --headless --path . -s res://tests/stress_test.gd
cd game && (printf '[input_devices]\n\npointing/emulate_touch_from_mouse=true\n' > override.cfg; $G --headless --path . -s res://tests/scroll_test.gd; rm override.cfg)
```

`$G` is the Godot 4.4.1 editor binary. TESTING.md says where to get it.
If you changed the economy, also run the pacing robot (BALANCE.md).
If you changed a screen, take screenshots and look at them (TESTING.md).

## Project rules (checked by tools/check_rules.py)

| Rule | What it means | Why |
|---|---|---|
| R1 | Colours only from tokens in `ui.gd` | One palette, held with discipline |
| R2 | Every `ScrollContainer` sets `scroll_deadzone` | On phones a wobbly tap otherwise counts as a scroll and the button does nothing |
| R3 | Slide and scale tweens use `Motion.d()` (or the function returns early on `Motion.reduced()` and the line is marked `# reduced-checked`) | Reduce motion must really reduce motion |
| R4 | No em dashes or hidden Unicode in player text or docs | House style |
| R5 | Only the OFL Inter fonts may be in git | Font licences |
| R6 | Package name never changes | Updates and saves |
| R7 | Every saved field is loaded back, and `SAVE_VERSION` has a migrate step | Saves survive updates |
| R8 | No throwaway files in git (`_agent*`, `_dbg*`, `override.cfg`, extra keys) | Clean repo |
| R9 | No `print()` in game code; use `GameLog.info()` | Logs go in the problem report |
| R10 | Pushed pages have a back button (`super(title, true)`) | Never trap the player |
| R11 | The four test suites exist | CI runs them |

Add a rule when a bug class shows up twice. Keep each rule cheap and certain.

## Things learnt the hard way

- Taps inside scroll lists failed on the real phone but passed on desktop. Always test touch with `emulate_touch_from_mouse` and a few pixels of wobble.
- Agent or worktree copies start from `main`, not the working branch. Check out the branch first.
- GitHub sometimes returns 502 when publishing. The workflow retries once. If it still fails, re-run the job later; the code is fine.
- A pop-up that covers the screen during play annoys people. Celebrations never block taps; deals wait until the player is on a main tab and not tapping.
- Agent play-testers found real exploits each time (market trading, backup re-rolls, boost double pay). Re-run the exploit persona after economy changes.

## Releasing

1. All checks above pass.
2. Commit with a short summary, then push to the working branch.
3. GitHub Actions runs the rules, the tests, builds `Sol.apk`, signs it and publishes release `v1.0.<run number>`.
4. The owner taps Update in Profile.

The signing key lives in `game/android/release.keystore` (owner's choice). A move to a private key in GitHub Secrets is planned; the new key is not active yet.

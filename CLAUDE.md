# Sol: rules for working on this project

Sol is a small idle tycoon game for Android, built with Godot 4.4.1 and released by GitHub Actions.
Read this file first, then the doc for the area you touch:

- [docs/DESIGN.md](docs/DESIGN.md): look, colours, type, motion, wording, patterns to avoid
- [docs/BALANCE.md](docs/BALANCE.md): economy, pace targets, the pacing robot
- [docs/TESTING.md](docs/TESTING.md): every test and how to run it
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): where things live and how they connect

## Working style

- British English. Replies short and simple, in small chunks.
- Look: premium, clean, Apple-meets-brutalist, dark teal with one red sun.
- Pace: the game takes weeks, not days. It must never become easy by accident.
- **Ask before every push.** Commit locally and push only when told "push". A push only checks and builds.
- **Releases are rare.** A release (the in-game Update) is made only when the owner says "release", after many changes have built up.

## Never

1. Change the package name `com.redsunholdings.game` (saves would be lost). (R6)
2. Commit Fontshare fonts (Switzer, Tanker). CI downloads them. (R5)
3. Break old saves. New saved fields get a load default and a `_migrate()` step; bump `SAVE_VERSION`. (R7)
4. Add money, multipliers or automation without running the pacing robot before and after (BALANCE.md).
5. Show real brands or companies. Crypto coins use real names; their prices are a made-up simulation.
6. Push with a failing test.
7. Put personal details (names, emails, devices, health) in any file. The repo is public.

## Commands

- `tools/check_all.sh --quick`: rules, smoke and touch tests (about 1 min) while working.
- `tools/check_all.sh`: rules and all 11 suites (about 4 min). Must say ALL PASS before a commit. Finds or downloads Godot 4.4.1.
- `tools/shots.sh <dir>`: renders every screen. Look at the ones you changed.
- `tools/release.sh`: only after "push". Checks, pushes, waits for the build, prints the version.
- Hook once: `cp tools/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`
- Follow the `sol-feature` skill (`.claude/skills/sol-feature/SKILL.md`) for every change.

## Project rules (tools/check_rules.py)

| Rule | What it means |
|---|---|
| R1 | Colours only from tokens in `ui.gd` |
| R2 | Every `ScrollContainer` sets `scroll_deadzone` (wobbly taps on phones) |
| R3 | Slide and scale tweens use `Motion.d()`, or return early on `Motion.reduced()` (`# reduced-checked`) |
| R4 | No em dashes or hidden Unicode in player text or docs |
| R5 | Only the OFL Inter fonts in git |
| R6 | Package name never changes |
| R7 | Every saved field is loaded back; `SAVE_VERSION` has a migrate step |
| R8 | No throwaway files or signing keys in git (`_agent*`, `_dbg*`, `override.cfg`, `*.keystore`) |
| R9 | No `print()` in game code; use `GameLog.info()` |
| R10 | Pushed pages use `super(title, true)`; the back button sits in the bottom bar |
| R11 | Every suite CI runs exists |

Add a rule when a bug class shows up twice. Keep each rule cheap and certain.

## Lessons

- Taps in scroll lists can pass on desktop and fail on a phone. Test touch with `emulate_touch_from_mouse` and a few pixels of wobble.
- Agent worktrees start from `main` and lack the Fontshare fonts. Check out the branch first; run fit and screenshot checks on the merged tree.
- GitHub sometimes returns 502 when publishing. Re-run the job later.
- Pop-ups never open by themselves during play. Celebrations never block taps.
- Play-tester agents found real exploits every time. Re-run the exploit persona after economy changes.
- Big batches: split agents by file, one owner each for `game_state.gd`, `data.gd`, `main.gd`, `ui_kit.gd`, `ui.gd`; cherry-pick their commits.

## Docs stay current

With every change a player can see, in the same commit:
- A line in `CHANGELOG.md` (top section).
- The doc for that area.
- A fresh picture in `docs/screenshots/` if a README screen changed (no pop-ups in shot).

## Releasing

1. All checks pass.
2. Commit, then ask. Push to the working branch only on "push". Every push runs the tests and builds, but publishes nothing.
3. Only on "release": start the Android APK workflow by hand. It builds and signs `Sol.apk` (key and password from the repo Secrets `SOL_KEYSTORE_B64` and `SOL_KEYSTORE_PASSWORD`) and publishes `v1.2.<run number>` with notes for every version (`.github/release-notes/`). Then run Tidy releases so only the newest release stays.
4. The player taps Update in Profile.

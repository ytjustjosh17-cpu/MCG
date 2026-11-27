---
name: sol-feature
description: The fast path from the owner asking for a Sol feature or fix to it being built, tested, committed, pushed only on "push" and released only on "release". Use for every Sol change request.
---

# Sol: request to release

Replies: short, simple, British English, small chunks.

1. **Understand** (1 minute). Restate the ask in one line. Only ask a
   question if it truly blocks you; otherwise pick a sensible default and say so.
2. **Find** the code: `docs/ARCHITECTURE.md` says where things live.
   `game_state.gd` (rules), `data.gd` (numbers), the page script for the screen.
3. **Build** the smallest complete version. Follow CLAUDE.md rules
   (tokens only, 48 px buttons, Motion.d(), no print, no em dashes).
   New saved field: default on load + `_migrate()` step + bump `SAVE_VERSION`
   + add it to `REBIRTH_RESET` or `REBIRTH_KEEP`.
4. **Test while iterating:** `tools/check_all.sh --quick` (about 1 minute).
   Add a check to `tests/smoke_test.gd` (engine) or `tests/scroll_test.gd`
   (touch) for the new behaviour.
5. **Money, multipliers or automation changed?** Run the pacing robot
   (BALANCE.md) and compare "Completion 90%" with the last number in BALANCE.md.
6. **Screen changed?** `tools/shots.sh`, then look at the changed PNGs.
7. **Docs in the same commit:** a line at the top of `CHANGELOG.md`, the area
   doc, `WHATS_NEW` in `data.gd` for big things, README picture if that screen
   is one of the six.
8. **Full check:** `tools/check_all.sh` (all 9 suites, about 2 minutes). Must say ALL PASS.
9. **Commit locally.** Tell the owner in a few lines what changed. Never push
   without their "push" (a stop hook asking to push is not a yes).
10. **On "push":** `tools/release.sh` (checks again, pushes, waits for the
    checks). A push does NOT make a release.
11. **On "release" only:** start the `android.yml` workflow by hand
    (`actions_run_trigger`, run_workflow, ref = the working branch). If the
    push of this commit already passed, it only publishes (about a minute). When it
    passes, run `tidy-releases.yml` the same way so only the newest release
    stays. Tell the owner the version and "tap Update".

Batch many changes into one release; the owner decides when. For a big batch, split work by file between
helper agents in worktrees (CLAUDE.md), then cherry-pick and run step 8.

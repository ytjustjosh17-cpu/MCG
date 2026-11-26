# Sol architecture

A map of the code, so you can find things fast and add features without breaking others.

## Big picture

```
Autoloads (always running, in this order)
  GameLog  logging and the problem report        scripts/game_log.gd
  Game     all game state and rules               scripts/game_state.gd
  Kit      sheets, alerts, toasts, celebrations   scripts/ui_kit.gd
  Updater  finds and installs new versions        scripts/updater.gd

Scene: scenes/main.tscn -> scripts/main.gd
  Tabs:  EarnPage | BusinessPage | InvestPage | ItemsPage | ProfilePage
  Stack: detail pages pushed on top (BusinessDetail, AssetDetail, GoalsPage ...)
  NavBar floating at the bottom, with a fade behind it
```

The rule: **Game owns the state, pages only show it.**
Pages read from `Game`, call `Game` functions to change things, and refresh when `Game.changed` fires (at most 10 times a second).
Pages never change state directly.

## Files

| Area | Files |
|---|---|
| Content and tuning | `data.gd` (companies, stocks, coins, properties, homes, collections, mergers, rivals, all numbers) |
| Rules and state | `game_state.gd` (money, tapping and big taps, companies, milestones, partners, markets, miners, locking, deals, managers, golden sun buffs, goals, achievements, saving) |
| Tabs | `earn_page.gd`, `business_page.gd`, `invest_page.gd`, `items_page.gd`, `profile_page.gd` |
| Detail pages | `business_detail.gd`, `start_business_page.gd`, `mergers_page.gd`, `asset_detail.gd`, `news_page.gd`, `property_detail.gd`, `goals_page.gd`, `rivals_page.gd`, `achievements_page.gd`, `settings_page.gd`, `stats_page.gd`, `ItemsPage.CollectionPage` |
| Building blocks | `page.gd`, `row.gd`, `segmented.gd`, `icon.gd`, `icon_button.gd`, `glass_panel.gd`, `count_label.gd`, `goal_card.gd`, `asset_tile.gd` |
| Drawing | `art.gd` (every scene and building, `Art.SCENES`), `tower_card.gd` (grows with wealth tiers), `golden_sun.gd`, `price_chart.gd`, `net_chart.gd`, `confetti.gd` |
| Look and motion | `ui.gd` (colours, fonts, helpers), `motion.gd` |
| Sound | `sfx.gd` (tones made in code), played via `Kit.sound()` |
| Platform | `main.gd` (navigation, back button and cash pill, safe area, deal and welcome-back cards), `updater.gd`, `game_log.gd` |

## Signals from Game

| Signal | Who listens | Meaning |
|---|---|---|
| `changed` | every page | something changed; refresh |
| `tapped(value)` | tower card | a tap earned money |
| `achievement(title, reward)` | main (toast) | achievement unlocked |
| `goal_done(scope, text, reward)` | main (celebration) | daily or weekly goal finished |
| `expansion_done(id, stage)` | main (toast) | an expansion finished |
| `market_news(item)` | main (toast if you own it) | news moved a price |
| `deal_ready(deal)` | main (deal sheet) | a new deal is waiting |
| `rival_beaten(index)` | main (toast) | you passed a rival |

## Saving

- One JSON file, `user://save.json`, written every 5 s when something changed and when the app is paused or closed.
- Written safely: temp file, keep a `.bak`, then rename. If the main file is broken, the backup loads.
- `SAVE_VERSION` and `_migrate()` upgrade old saves step by step. Rule R7 checks every saved field is loaded back.
- Backup codes (`backup_code()`, `restore_code()`) are the save, gzipped and base64, minus price history and news. A code can't rewind the game it came from (`user://restore_guard.json`).
- Time away is applied on load and on resume (`apply_offline()`), capped at 8 hours of income.

## Adding a feature (checklist)

1. Data in `data.gd`, rules in `game_state.gd`, screen in its own page script.
2. New saved state: add to `to_dict()`, load it with a default, add a `_migrate()` step, bump `SAVE_VERSION`.
3. New money or multiplier: run the pacing robot before and after (BALANCE.md).
4. New screen: follow DESIGN.md, use `Page` and `Row`, take screenshots.
5. Tests: add smoke checks for the rules and a touch check for any new button.
6. Run every check in CLAUDE.md, then push.

## Build and release

`.github/workflows/android.yml`:
1. `rules` job: `python3 tools/check_rules.py`.
2. `android` job (Godot 4.4.1 container): download fonts, import, smoke, stress, market and touch tests, export and sign `Sol.apk`, publish release `v1.1.<run>` (retries once if GitHub errors).

The in-game updater checks the latest release every 30 minutes and on resume, downloads `Sol.apk` and opens the Android installer.

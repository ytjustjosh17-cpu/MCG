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
| Detail pages | `business_detail.gd`, `start_business_page.gd`, `mergers_page.gd`, `asset_detail.gd`, `news_page.gd`, `property_detail.gd`, `goals_page.gd`, `rivals_page.gd`, `achievements_page.gd`, `settings_page.gd`, `stats_page.gd`, `claim_list.gd` (rewards to claim), `trade_sheet.gd` (buy, sell, convert, lock), `head_office_page.gd`, `rebirth_page.gd` (rebirth card and the tree map, `RebirthPage.TreeView`), `ItemsPage.CollectionPage` |
| Building blocks | `page.gd`, `row.gd`, `segmented.gd`, `icon.gd`, `icon_button.gd`, `glass_panel.gd`, `count_label.gd`, `asset_tile.gd` |
| Drawing | `art.gd` (every scene and building, `Art.SCENES`), `tower_card.gd` (grows with wealth tiers), `golden_sun.gd`, `item_art.gd` (personal items), `miner_rack.gd` (animated miners), `asset_tile.gd` (coin logos, share badges), `price_chart.gd`, `net_chart.gd`, `confetti.gd` |
| Unlock content | `Data.FRONTIER`, `Data.ISLES` (saved by index after `PROPERTIES`, read with `Data.property(i)`), `Data.RELICS`. Pages and the robot use `Game.businesses()`, `Game.property_count()`, `Game.collections()`; completion and achievement ids use the base lists |
| Rebirth tree | `rebirth_tree.gd` (`RebirthTree`: every node with a fixed string id, position, links, cost and effects; built once). Effects are summed per stat by `Game.rb(stat)` and used where each rule lives |
| 1.2 | `bank_page.gd` (savings and loans), `weather.gd` (`SkyTime`: day, night, weather), `home_page.gd` (inside your home), `guide.gd` (first-time guide), `stats_page.gd` (charts); casino `video_poker_page.gd`, `crash_page.gd`, `plinko_page.gd`, `race_page.gd`, `wheel_sheet.gd` with maths in `casino/` |
| Casino pages | `casino_page.gd` (lobby: unlock, cage, limits, games; `CasinoPage.CasinoArt` drawings), `slots_page.gd`, `forge_page.gd` (Sun Forge, 6x5 tumble), `roulette_page.gd`, `blackjack_page.gd`. Money only moves through `Game.casino_stake()` and `Game.casino_pay()` |
| Casino game base | `casino_game.gd` (`CasinoGame`): the shared layout for all nine games (title with "i" rules sheet, status row, game area, dock with bet bar or chip tray, one 56 px main button above the nav). Games write `build_game()` and fill `area` and `dock` |
| Shared controls | `switch.gd` (on/off), `Row` options (`set_bold`, `set_locked`, `align_top`, `grow_to_fit`, `caption_on_top`), `UI.primary_btn` / `secondary_btn` / `text_btn`, `Art.Scene.muted` for list thumbnails |
| Casino maths | `casino/forge_math.gd`, `casino/slot_math.gd`, `casino/roulette_math.gd`, `casino/blackjack_math.gd`: pure rules, seedable, no UI (`tests/casino_test.gd` checks their payback) |
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
- Rebirth (`do_rebirth()`) keeps every key in `REBIRTH_KEEP` and clears every key in `REBIRTH_RESET`; a test fails if a saved key is in neither. The save stores RBP earned and owned node ids; RBP left is worked out from those.
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
2. `android` job (Godot 4.4.1 container): download fonts, import, smoke, stress, market and touch tests, export and sign `Sol.apk`, write its SHA-256, stamp build provenance (`actions/attest-build-provenance`), on a by-hand run only (never on a push), publish release `v1.2.<run>` with grouped notes for every version, the checksum, build log, attestation and VirusTotal link in the notes (retries once if GitHub errors).

`.github/workflows/tidy-releases.yml` (by hand only) deletes every release but the newest, so the Releases page shows one release.

The in-game updater checks the latest release every 30 minutes and on resume, downloads `Sol.apk` and opens the Android installer.

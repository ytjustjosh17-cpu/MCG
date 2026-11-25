# Sol design guide

One world: a dark teal city at dusk with a single red sun.
Brutalist bones (big blunt type, hard shapes, lit windows), Apple manners (calm motion, glass, generous space, little text).
If a new screen doesn't look like it belongs in that world, it isn't done.

Check any design change against this page and against `tools/check_rules.py` (R1 to R4).

## Colour

All colours are tokens in `game/scripts/ui.gd`. Never write a hex colour anywhere else (rule R1).

| Token | Hex | Use |
|---|---|---|
| `BG` | `#001414` | Page background (teal-black, never blue-grey) |
| `PANEL` | `#092225` | Cards, rows, sheets |
| `RAISED` | `#1C3A3B` | Secondary buttons, dividers, selected segment |
| `SKY` | `#012B2A` | Art backgrounds |
| `TEXT` | `#D8E6E3` | Main text, primary button fill |
| `SUB` | `#8FAAA6` | Secondary text |
| `DIM` | `#4F6E6C` | Chevrons, unimportant marks |
| `TRACK` | `#2A4A4B` | Empty part of bars |
| `RED` | `#FF1A0F` | The sun, lit windows, the active tab, one alert per screen |
| `INK` | `#001414` | Text on light fills |
| `UP` / `DOWN` | `#7FCFA6` / `#EE7A6B` | Price and money changes only |
| `SECTOR_COL`, `COIN_COL` | muted | One tonal colour per sector and coin |

Rules:
- Red is rare. The sun, lit windows, the active tab and at most one call to action per screen. "Owned" and "done" marks are `TEXT`, not red.
- Up and down always come with ▲ or ▼ and a + or −, never colour alone.
- Accents are tonal and muted. No bright saturated pops, no gradients between hues, no purple.

## Type

| Role | Font | Size |
|---|---|---|
| Page titles, net worth, big money | Tanker (`UI.DISPLAY`, via `UI.display()`) | 28 to 44 |
| Section titles, row titles | Switzer Semibold (`UI.SEMI`) | 17 |
| Body | Switzer Regular (`UI.REG`) | 15 to 17 |
| Captions, sub-lines | Switzer Regular | 13 |

- Tanker and Switzer come from Fontshare at build time (licence: allowed in the app, not in the repo). Inter is the fallback if the download fails.
- Tanker is all caps, so keep display text short. Money suffixes like "Qi" read as "QI" in Tanker; avoid display type for values above $1e18.
- Money: `Game.money()` for exact amounts, `Game.money_short()` for everything else ($32K, $1.2M, $12.27M). No trailing zeros.

## Layout

- Portrait, designed at 390 × 844. 16 px side gutter everywhere.
- Cards: `PANEL`, radius 16, 12 px between cards. Rows 56 to 72 px tall, dividers inset to the text.
- Buttons and controls are at least 44 px tall (primary and secondary 48, segmented 44, chips 40 with padding).
- The tab bar floats over content. Pages keep 104 px of bottom space, and a soft fade sits behind the bar.
- Every pushed page has a back button at the top left (rule R10).

## Components (use these, don't rebuild them)

| Need | Use |
|---|---|
| A page | `Page` (`page.gd`): `card()`, `padded()`, `section()`, `separator()`, `button()` |
| A list row | `Row` (`row.gd`), with `set_texts()`, `set_change()`, `set_lead()` |
| Company or coin mark | `AssetTile` (`asset_tile.gd`): a bare shape, no box behind it |
| Tabs inside a page | `Segmented` |
| Bottom sheet, alert, toast | `Kit.sheet()`, `Kit.alert()`, `Kit.toast()` |
| Celebration | `Kit.celebrate()` (never blocks taps, leaves by itself) |
| Count-up number | `CountLabel` |
| Price chart | `PriceChart` |

No icon or logo inside a coloured tile or circle. Icons are Phosphor, drawn bare and tinted (`Icon`).

## Motion

- Tokens in `motion.gd`: `QUICK` 0.14 s, `STANDARD` 0.28 s, `SLOW` 0.45 s.
- Every slide or scale goes through `Motion.d()`, so Reduce motion can switch it off (rule R3). Fades may stay.
- Pages slide in from the right and leave to the right. Sheets rise from the bottom and leave downwards.
- Press feedback starts on finger-down (`Kit.press_fx`). Buttons never jump on hover.
- Animations never hide content. If an animation fails, the content must still be visible.
- Glass panels can't be scaled cleanly. Move or fade them instead.

## Haptics

`Kit.haptic()` with one of `selection`, `light`, `medium`, `success`, `error`. Use them for real moments only: a purchase, a level up, a "no" shake. Respect the Vibration setting (Kit does this).

## Words

- British English, short, plain. One line beats two. Numbers beat adjectives.
- Say what happens: "Expand · $272K", "Tap the tower to earn", "Ready again in 3:12".
- No jargon without a hint. Staking, dividends and mergers each have a short explanation where they appear.
- No em dashes, no "seamless", "elevate", "unlock your potential" or similar filler (rule R4 checks the dashes).

## Before calling a screen done

1. Take screenshots at 390 × 844 (TESTING.md) and look at every one.
2. Check: one clear main thing, 16 px gutters, nothing clipped, nothing under the tab bar, text readable on its background.
3. Check with Reduce motion on.
4. Run `python3 tools/check_rules.py`.

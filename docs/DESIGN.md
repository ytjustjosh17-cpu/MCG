# Sol design guide

One world: a dark teal city at dusk with a single red sun.
Brutalist bones (big blunt type, hard shapes, lit windows), Apple manners (calm motion, glass, generous space, little text).
Reference mood: "red sun" dystopian brutalism. Concrete blocks in teal haze, one huge flat red sun, sagging cables, a few red windows. No sunset stripes, no neon colours.
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
| `FAR` / `HAZE` | `#03201F` / `#08403D` | Distant skyline layers in art |
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

The scale is 40 (display), 28 (big value), 17 (titles, body), 15 (secondary), 13 (captions). Nothing is smaller than 13 px; the fit test fails if it is.

- Tanker and Switzer come from Fontshare at build time (licence: allowed in the app, not in the repo). Inter is the fallback if the download fails.
- Tanker is all caps, so keep display text short. Money suffixes like "Qi" read as "QI" in Tanker; avoid display type for values above £1e18.
- Money: `Game.money()` for exact amounts, `Game.money_short()` for everything else (£32K, £1.2M, £12.27M). No trailing zeros.

## Layout

- Portrait, designed at 390 × 844. 16 px side gutter everywhere.
- Cards: `PANEL`, radius 16, 12 px between cards. Rows 56 px (60 with a sub-line), dividers inset to the text.
- Buttons and controls are at least 48 px each way (Android's 48 dp touch target): primary 52, secondary 48, segmented 48, drop-downs 48; the casino's main button is 56.
- The tab bar floats over content. Pages keep 104 px of bottom space, and a soft fade sits behind the bar.
- Every pushed page gets the back button in the bottom bar, on the right where the thumb rests. It never scrolls away (rule R10, `main.gd`).
- Cash you can spend is always shown: big on Earn, and as a small glass pill at the top right on every other screen (`main.gd`), fixed while you scroll.
- Rows are 56 px, or 60 px with a sub-line. `Row` sets this itself; pages don't set their own row heights.
- Buttons: `UI.primary_btn()` (52 px, one per screen), `UI.secondary_btn()` (48 px), `UI.text_btn()` for quiet actions (Close, Not now, Sell company). On/off settings use `Switch` (`switch.gd`); chevrons are only for rows that open something.
- Every pressable thing is at least 48 x 48 px. The touch test measures what is on screen on each tab and the main detail pages.

## Components (use these, don't rebuild them)

| Need | Use |
|---|---|
| A page | `Page` (`page.gd`): `card()`, `padded()`, `section()`, `separator()`, `button()` |
| A list row | `Row` (`row.gd`), with `set_texts()`, `set_change()`, `set_lead()` |
| Personal item picture | `ItemArt` (`item_art.gd`): every watch, painting, car, jet, yacht and island drawn with its own details; dim until owned |
| Company or coin mark | `AssetTile` (`asset_tile.gd`): coins show their real logo (`assets/coins`, CC0); shares a sector shape with the company initial cut in |
| Tabs inside a page | `Segmented` |
| Pop-up card (centred, floats in the middle, 14 px from the sides), alert, toast | `Kit.sheet()`, `Kit.alert()`, `Kit.toast()`. Toasts queue (never replace each other), stay 2.6 to 4.5 s by length, and drop repeats |
| Buy / sell / convert / lock amounts | `TradeSheet` (`trade_sheet.gd`): what you own, a big live amount, a thick slider with quarter snaps, 25/50/75/Max chips, an £ amount box, "After:" line, one confirm button |
| Rebirth tree | `RebirthPage.TreeView`: a star-chart map. Drag to move (14 px of wobble is still a tap), pinch or the 48 px + and - buttons to zoom, house button to re-centre. Small nodes are circles, notables diamonds, keystones hexagons; owned nodes are filled, owned paths red, buyable nodes outlined bright, locked ones dim. Tap a node for a sheet with what it gives and Buy |
| Casino | Felt and pocket colours are tokens (`FELT`, `ROUL_*`, `GOLD`, `CHIP_COL`, `SLOT_COL`). Cards are Kenney's flat CC0 cards (`assets/cards`). Wins count up and celebrate without blocking taps; reels and the wheel finish at once with Less motion |
| Miners at work | `MinerRack` (`miner_rack.gd`): machines with spinning fans, blinking lights and coins rising; still with Less motion |
| Celebration | `Kit.celebrate()` (never blocks taps, leaves by itself) |
| Count-up number | `CountLabel` |
| Price chart | `PriceChart` |

Nothing shares one picture: companies and properties have their own scenes, items their own drawings, coins their logos, shares their own badge, achievements an icon for their type.
No icon or logo inside a coloured tile or circle. Icons are Phosphor, drawn bare and tinted (`Icon`).

## Motion

- Tokens in `motion.gd`: `QUICK` 0.14 s, `STANDARD` 0.28 s, `SLOW` 0.45 s.
- Every slide or scale goes through `Motion.d()`, so Reduce motion can switch it off (rule R3). Fades may stay.
- Pages slide in from the right and leave to the right. Sheets rise from the bottom and leave downwards.
- Press feedback starts on finger-down (`Kit.press_fx`). Buttons never jump on hover.
- Animations never hide content. If an animation fails, the content must still be visible.
- Glass panels can't be scaled cleanly. Move or fade them instead.

## Battery

- Pages refresh at most 4 times a second (`Page.REFRESH_MS`), with a final refresh after the last change. Avoid measuring text or making styleboxes in `refresh()`; cache them.

- The game draws at most 60 frames a second (`run/max_fps`), and 5 while it is out of focus (notification shade, a call). It saves when it loses focus.

## Haptics

`Kit.haptic()` with one of `selection`, `light`, `medium`, `success`, `error`. Use them for real moments only: a purchase, a level up, a "no" shake. Respect the Vibration setting (Kit does this).

## Small helpers players expect

- Deals never pop up; they wait in a card on the Business tab.
- Few dots, all round. A dot only means a reward is waiting to claim (Earn: goals and the daily gift; Profile: achievements) or an update is ready. Opening the tab clears its dot until something new arrives (`main._update_badges()`, seen counts in `Game.ui["dots_seen"]`). Nothing gets a dot just because you can afford it.
- Page motion: detail pages slide in and back out on the same quint curve (0.38 s in, 0.32 s out), starting after the page is built so the first frames aren't skipped. Tabs cross-fade with a small slide. An open detail page fades away when you switch tab. Shares, Property and Crypto fade between each other. All of it respects Less motion.
- Tapping the current tab scrolls back to the top.
- Locked buttons say how long until you can afford them (`Game.eta()`: "~12 min").
- Hold +1 to keep buying; it speeds up the longer you hold.
- The game remembers screen choices (`Game.ui`): Invest tab, sector filter, chart range.
- Welcome back lists what happened while away. A daily streak gives a small gift.
- Long names end in "..." rather than running into art.
- Business tab: one row, "+ New" and a "More ▾" drop-down (Fill all, Expand N, Mergers).
- Tap a goal to go where you can do it.
- Settings live on their own page (Profile > Settings): Less motion, Pop-ups drop-down (All / Deals only / None), Keep screen on, Backup, Reset.
- Tap combo counter on the tower ("25 COMBO") is just for fun and pays nothing extra.
- A golden sun sometimes drifts across the tower (max 4 a day, only while playing). Tap it for a small prize.
- Filters and sorts are drop-downs (`Kit.drop_pill()` + `Kit.pick()`), never rows of chips. Lists don't jump while you look at them.
- Earn shows cash to the penny (£1,385.62) as the big number; income and net worth sit below it. No next-goal card (owner removed it).
- Every art kind has its own setting in `Art.SCENES`: where the sun sits and how big, the skyline (city, dense, cranes, hills, none) and the ground (street, water with the sun's reflection, runway, field). Only some get a pylon. A new kind needs its own entry, so no two pictures look alike.
- Company rows on the Business tab are compact: picture, name, stage and units, income, a thin bar, and a red dot only when something can be bought.
- Art scenes share one backdrop (`Art.backdrop`): sun with a soft glow, far skyline, low mist, and a pylon with hanging cables on big pictures.
- The Earn tower grows in five wealth tiers (net worth £1M, £100M, £10B, £1T, £100T): a second block, roof lights, searchlights, a sky bridge, a red crown.
- Sounds come from `Kit.sound()` (made in code in `sfx.gd`); `Kit.tick()` and `Kit.haptic()` already play the right one.
- Sheets: glass, follow the finger down, rubber-band when dragged up, close on a quick flick.
- Invest lists split into "Yours" (what you own) and "Market". Crypto has its own Mining section with one Buy rig button (pick the coin; best payers first).
- A share or coin page: price, chart, Buy and Sell, one "You own" card, then (coins) one Lock row, and the latest 3 news items. Nothing else.
- Rewards never pay by themselves. Finished goals, the daily gift and achievements wait in a "To claim" card (`ClaimList`) on Goals and Achievements, each with its own Claim button and Claim all at the top; the daily gift pop-up has a Claim button. Red dots show where something is waiting.
- Profile shows the next achievement. The nav bar names only the active tab.

## Words and terms

One word per idea, everywhere: "units" (not outlets/spaces), "Stage", "Expand", "Lv", "Net worth", "/h", "X more", "Done", "Reset", "Upgrades", "Lock" (staking).

## Words

- British English, short, plain. One line beats two. Numbers beat adjectives.
- Say what happens: "Expand · £272K", "Tap the tower to earn", "Ready again in 3:12".
- No jargon without a hint. Staking, dividends and mergers each have a short explanation where they appear.
- No em dashes, no "seamless", "elevate", "unlock your potential" or similar filler (rule R4 checks the dashes).

## Patterns to avoid

- More than one red accent per screen (plus the sun). Red is for the one main action, not for done states, info, borders or progress.
- Coloured marks with no label (red squares, pips, dots that mean nothing).
- Run-on lines with 3 or more facts joined by dots ("A · B · C · D"). Use 2 at most, or labelled columns.
- Text under 13 px. `DIM` as a text colour. Grey text on a grey card. Text over busy art without a panel behind it.
- Two equal primary buttons stacked. A full-width destructive button as loud as Buy.
- Normal data that looks disabled. Disabled buttons with no reason shown.
- Tappable rows with no chevron or trailing pill. A lone chip on its own line. A loose "▾" as a control: drop-downs always use the `Kit.drop_pill` look.
- Different controls for the same job on similar screens. Per-page row heights and paddings.
- Empty space over 120 px at the bottom of a screen.
- Pop-ups that open by themselves during play (deals, offers). Celebrations never block taps.

## Before calling a screen done

1. Take screenshots at 390 × 844 (TESTING.md) and look at every one.
2. Check: one clear main thing, 16 px gutters, nothing clipped, nothing under the tab bar, text readable on its background.
3. Check with Reduce motion on.
4. Run `python3 tools/check_rules.py`.

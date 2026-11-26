# Changelog

## 1.1 update: tester feedback

Eight testers (3 reviewers, 5 players including a very confused one) went
through 1.1. Changes from what they found:

- Invest: "Yours" and "Market" are proper titles with a count. Lists no
  longer jump while you look (they re-sort when you open the tab).
- Crypto mining is now "Crypto miners". Buy miner asks which coin (yours
  first, all coins listed, with a Close button). Every miner now raises the
  cap a little (2% of income plus 0.15% per miner), so later miners still count.
- Locked coins pay 3 times more (still capped at 5% of income). Ready coins
  only offer Unlock, so they can't be re-locked by mistake.
- Synergies are now "Partners", with a one-line hint and a confirm before buying.
- Company page: always starts on x1; holding to keep buying only works on x1
  and needs a longer hold. Manager hidden on a fully expanded company.
- Buy, Sell and Lock sheets: the small, safe choice sits nearest your thumb.
  Sell explains why when your coins are locked.
- Plainer words: "Big tap" (not crit), "Taps x5" and "Income x2" buffs,
  "Quick deal" (not Rush order), mining news shows "Mining x1.5".
- The tower grows taller with each wealth tier; brighter searchlights.
- Chart end is a dot in the line's colour (red stays rare).
- Deals: no deal waiting on almost every open; a buyer never breaks a milestone.
- Fewer dead ends late: last rival at £15Qa, 60 golden suns (was 100),
  cheaper Ore, Own fleet and Rocket fuel partners.
- Welcome back also says what locked coins earned. Pickers have a Close button.

## 1.1 (first build: v1.1.36)

Old saves load as before. Saves move from v7 to v9 on first load, and new
fields start empty. A real save from 1.0.31 is kept as a test and must load
with nothing lost.

### New

- **Pounds.** Money shows in £ everywhere.
- **Exact cash.** Earn shows cash to the penny (£1,385.62). From £10M it
  switches to four figures (£177.9M) so it never runs off the screen.
- **Bulk buy.** Every company page has ×1, ×10, ×100 and Max. The price on
  the button is exactly what you pay.
- **Milestones.** 5, 25 and 50 units of one company lift its income
  (×1.1, ×1.15, ×1.25).
- **Synergies.** Ten one-off upgrades where one company boosts another,
  for example Taxi deliveries lift Food trucks by 30%.
- **Achievement bonus.** Each achievement adds 0.25% to all income, up to +15%.
  Six new achievements for synergies and full companies.
- **Critical taps.** 4% of taps (plus 0.2% per level) pay ×5, with a big red
  number, a small burst and a sound.
- **Golden sun buffs.** A caught sun now gives cash, Frenzy (taps ×5 for
  20 s) or Rush (×2 income for 10 min while the app is open).
- **Crypto mining.** Buy rigs for any coin. They mine it all the time,
  even while away (up to 8 h).
- **Three new coins:** Volt, Quartz and Halo.
- **Mining news** can speed a coin's mining up or slow it down for a few days.
- **Sound.** Soft taps, a purchase chime, a fanfare, the golden sun alert.
  Made in code, no files. Settings > Sound: Off, Low, Medium, High.
- **Number format.** Settings > Numbers: Short (£1.2M) or Scientific (£1.2e6).
- **Stats.** Profile > Stats: taps, total earned, time played, best income,
  crits, suns, mined coins and more.
- **Your tower grows** with net worth: a second block, roof lights,
  searchlights, a sky bridge and a red crown at £1M, £100M, £10B, £1T, £100T.
- **What's new** in Profile, with the version number.

### Better

- Back button sits bottom right, next to the tab bar, and never scrolls away.
- Every button is at least 44 px; a test measures them.
- Company rows are compact, and their progress bars glide.
- Sheets follow your finger, push back when dragged up, and close on a flick.
- Six new companies (Food trucks, Gym chain, Hotel, TV station, Mining,
  Space launch) and varied art for every kind of business and property.

### Balance

- All company income × 0.84 so the new bonuses don't make the game easy.
- Pace (robot, seeds 7 and 99): 25% day 8.9, 50% day 19.3 to 20.5,
  90% day 40.3 to 40.8. Targets: 7 to 10, 15 to 21, 33 to 46.
- Coins no longer drift back to a home price. The new market test found
  that drift made coins bounce about 12% after big dips, an easy trade.
  Coins also swing a little less each minute.
- Mining pays at most 8% of income, rig prices climb ×1.45 per rig across all
  coins, 60 rigs at most, so mining stays worth having all game (robot: 5 to
  8% of income from day 10 to day 50). The rig button shows what it adds.
- Frenzy doesn't stack with the ×3 tap boost; the bigger one wins.

### Fixed

- Exploit: backing up, gambling all your cash on a coin and restoring if it
  lost was a free undo (+40 to 80% a day). A backup now can't rewind the
  game it came from; it still works on a new phone or after a reinstall.
- Exploit: setting the phone clock back kept Rush, Frenzy and the x3 boost
  running. They now move back with the clock.
- Mining's 8% cap now holds even with a tiny income.

- Mining news showed a 0% price change; it now shows the mining speed change.
- Mined coins showed "No change · avg £0"; they now show as all profit.
- Reaching a milestone now gives a burst, a sound and a note.
- Tests and the pacing robot start from a fresh market, so seeds repeat exactly.

- Build 25 shipped without its fonts (Tanker and Switzer). The build now
  fails if they are missing and checks the finished app for them.
- Resetting and then restoring a backup could re-roll market prices.
  The market now carries on through a reset.
- The Invest switch was 40 px tall; now 44.
- Pictures were redrawn on every screen refresh; now only when they change.

### Tests added

- Market fairness test (`tests/market_test.gd`), run on every build.
- Old save fixture, bulk-buy cost, milestones, synergies, achievement cap,
  crits, buffs (Rush never paid while away), mining cap and 8 h away limit,
  reset then restore, tap sizes on every tab.

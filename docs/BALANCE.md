# Sol balance guide

The owner wants Sol to take weeks and never feel easy.
This page says how the economy works, what the pace targets are, and how to check a change.

All tuning numbers live in `game/scripts/data.gd`. The rules that use them live in `game/scripts/game_state.gd`.

## Pace targets

Measured with the pacing robot (`game/tests/pacing_sim.gd`): 4 short sessions a day, about 15 minutes of play, tapping 3 times a second, buying sensibly, taking deals and hiring managers.

| Milestone | Target day | Last measured |
|---|---|---|
| First company | under 0.5 | 0.3 |
| 25% complete | 7 to 10 | 9.5 to 10.5 |
| 50% complete | 15 to 21 | 19.5 |
| 75% complete | 28 to 38 | 32.5 to 32.9 |
| 90% complete | 33 to 46 | 37.5 to 38.5 |
| All 6 mergers | 35 to 50 | 40.3 |
| All 17 companies | 35 to 45 | 36.3 to 36.8 |

A change that moves any milestone outside its range needs a reason, written in the commit message.

Other players, measured by the agent play-testers:
- Twice a day: about 1.4 × slower than the robot. Fine.
- Once a day: about 3 × slower (90% around day 98), because time away pays at most 8 hours.
- Heavy completionist (48 minutes a day): 100% around day 55. After that there is nothing new to do yet (see "Open questions").

Companies: 17, sorted by price. New ones fill price gaps (Food trucks, Gym chain, Hotel, TV station, Mining) and one sits above the Airline (Space launch). New companies earn a little less per pound than their neighbours, so the late game does not speed up.

## How money flows

| Source | Rule | Lever |
|---|---|---|
| Tapping | `tap_base(level) + 0.12% of income per hour` per tap; ×3 boost for 60 s every 10 min | `tap_value()` |
| Companies | units × unit income × stage multiplier × merger × global bonus | `BUSINESSES`, `stage_mult` |
| Expansions | real-time timers, doubling each stage, max 48 h | `expansion_minutes()` |
| Property | 2.2% of price per hour, improvements add more | `RENT_PER_H`, `IMPROVEMENTS` |
| Shares | dividends; prices drift slowly back to a fair value; news moves them at once | `STOCK_DIV_SCALE`, `_market_tick()` |
| Crypto | random walk with boom and bust phases (no pull home), staking (24 h lock, capped) | `COINS`, `STAKE_CAP` |
| Converting coins | sell at the usual 0.5% spread, then buy the other coin; nothing gained, so no loop | `convert_coin()` |
| Mining | one pool of miners mining one coin you choose (switch free, any time); a miner earns 4% of its price an hour in £ for any coin (pays back in about a day), with no cap tied to income; each miner costs ×1.7 more, 40 max, which keeps mining to roughly 10 to 25% of income | `RIG_*`, `MINE_*` |
| Head office | ten one-off upgrades: taps ×1.5, deals 25% sooner, away cap 10 h then 12 h, expansions 15% quicker (twice), +1 golden sun a day, locked coins +25%, miners +25%, managers take 6% | `UPGRADES` |
| Golden sun | cash, Frenzy (taps ×5 for 20 s, not on top of ×3) or Rush (×2 income for 10 min, only while open) | `SUN_*`, `FRENZY_*`, `RUSH_S` |
| Crits | 4% + 0.2% per level, ×5 | `CRIT_*` |
| Time away | full income, capped at 8 hours | `OFFLINE_CAP_H` |
| Goals | daily: 1.5 h of income each; weekly: 3 h each; waits to be claimed, amount fixed when earned | `daily_reward()`, `weekly_reward()`, `claim()` |
| Achievements | 1 h of income each | `_check_achievements()` |
| Daily streak | 0.15 h of income × days in a row (max 7) on the first open each day | `_check_streak()` |
| Deals | small, every 12 to 25 minutes of play (time away counts up to 30 min); no buyer deal at a milestone count | `roll_deal()`, `DEAL_EVERY_MIN` |
| Collections, homes, mergers | permanent multipliers | `bonus`, `HOME_BONUS`, `mult` |
| Unit milestones | 5, 25, 50 units of one company: ×1.1, ×1.15, ×1.25 | `MILESTONES` |
| Synergies | one-off buys: a company at stage N lifts another by 20 to 30% | `SYNERGIES` |
| Achievements | +0.2% income each, capped at +15% (reached near the last ones) | `ACH_BONUS`, `ACH_BONUS_CAP` |
| Overall dial | all company income × 0.80, set so the 1.1 bonuses keep the pace | `INCOME_SCALE` |

## Guard rails (keep these true)

1. Trading must not beat owning companies. `tests/market_test.gd` measures it: the average return 6, 24 and 72 hours after crash news, pump news and big dips must stay close to the normal return (limits 3%, 5%, 8%). A pull back to a home price made dips bounce by 12%, so coins no longer have one. Random moves go into the fair price itself (a random walk) and the price follows it, so dips are not promises of a bounce. Coin news shifts the coin's long-run anchor too. Re-run the exploit persona after any market change.
2. After any casino bet, no backup saved before that bet can be restored into the same game, with no time allowance (`_guard_strict()`).
2. Restoring a backup never passes time (so it can't re-roll the market), and a backup can't rewind the game it came from (`user://restore_guard.json`, kept through a reset). Otherwise backup-gamble-restore was a free undo worth +40 to 80% a day.
3. Time away is worked out without the ×2 boost, then only the boosted hours are added back.
4. Selling a unit to a buyer pays a little under what rebuying costs.
5. Staking pays at most 5% of hourly income across all coins together.
10. Taps: at most 7 paid a second. Invest goals need a real amount (10 minutes of income or $100).
11. The clock going backwards never re-rolls goals or the streak. Restoring a backup keeps the live market and deal.
12. Golden suns: at most 4 a day, only while playing, worth 10 to 60 minutes of income or a short buff. Buffs end when the app closes and never pay while away.
13. Mining has no income cap; its limit is price (×1.7 per miner, 40 max). It, counts at most 8 hours while away, and a restore mines nothing.
14. A reset keeps the live market, so reset then restore can't re-roll prices.
15. Setting the clock back pulls short buffs (Frenzy, Rush, x3 tap boost) back with it.
6. Goals only ask for things that are still possible (no "buy units" when every company is full).
7. Deals and the welcome-back card only appear while the app is open.
8. Rivals stay beaten once passed.
9. Managers stop taking their 10% once a company is fully expanded.

The smoke and stress tests check most of these. Add a test when you add a guard rail.

## How to check a change

1. Run the robot before your change on two seeds and note the milestones:
   ```
   cd game
   SIM_SEED=7  $G --headless --path . -s res://tests/pacing_sim.gd -- 45
   SIM_SEED=99 $G --headless --path . -s res://tests/pacing_sim.gd -- 45
   ```
2. Make the change and run both again.
3. One seed can be a day off by chance (markets are random). Two seeds moving the same way is real. The robot starts from a fresh market (`reset_game(true)`), so the same seed gives the same result every time.
4. To isolate a feature, the robot takes a second argument: `nohome` (skip homes), `nodeals` (skip deals and managers) or `nomine` (no mining rigs). `news`, `dip` and `hold` run trading bots that try to profit from news.

## Casino

- Opens once for £2.5M (about day 4 for the robot). Stays open through rebirth; chips do not (they are money).
- Chips: bought with cash at the cage, cashed out any time, counted in net worth.
- Limits follow base income (without the x2 boost): a bet is at most 6 minutes of income (`CASINO_MAX_BET_H`, at least £500), one payout at most 24 hours (`CASINO_MAX_WIN_H`, at least £100K). A slot bonus buy may stake up to 20 bets; a blackjack double or split up to 2. The "High roller" keystone doubles both.
- Payback, measured by `tests/casino_test.gd` on every build: slots 95.5 to 95.8% exactly from the reel strips (bonus buys about 93%), roulette 97.3% (every bet type, all 37 numbers), blackjack 99.3% with perfect basic strategy over 300k hands. The shoe is a fresh six decks every hand, so counting cards can't win.
- Every bet and every payout is saved the moment it happens, before any animation, so closing the app can't undo a loss. A backup can't rewind the game either (restore guard).
- Gambler robot (`SIM_GAMBLE=1`): 40 max-bet spins on Iron Vault (the wildest machine) every session, free spins played out. 90% complete on day 37.5, 38.8, 38.3 and 39.3 (seeds 7, 99, 2024, 5) against 38.5 without gambling. The luckiest seed won £3.8T in all and still finished on day 38.8, so a lucky streak can't skip weeks.

## Rebirth and the RBP tree

- Rebirth from £10B net worth. RBP = 10 × cube root of (net worth ÷ £10B), +RBP nodes up to +50%. So £10B gives 10, £10T 100, £10Qa 1,000.
- Rebirth clears money and assets (`REBIRTH_RESET`), including rewards not yet claimed, the waiting deal and the daily gift, so nothing is carried into a new run. It keeps the market, achievements, stats, settings, goal and streak timers and the tree (`REBIRTH_KEEP`).
- The tree: 152 nodes (8 branches, a ring of gates, 8 bridges, 24 notables, 16 keystones), 7,328 RBP in all. Cost = 3 × 1.32^(depth - 1), notables ×2, keystones ×4. Effects of one stat add up (never multiply each other). The tree is not part of completion %, so the pace targets above are for the first run.
- Guard rails it moves: away cap up to +7.25 h, one more golden sun a day (so 6 at most with Head office), big taps ×10 with Thunder taps, managers' cut 0 with Loyal staff.
- Robot (`SIM_REBIRTH=never|asap|patient|rate`, 240 days, seed 1234):

| Policy | Result |
|---|---|
| never | identical to before (first run 90% day 37.9) |
| asap (rebirth at £10B) | 10 RBP a run, runs of about 20 days, 21 nodes by day 180. A trap, on purpose |
| rate (rebirth when RBP per day stops rising) | 1st rebirth day 70 (+921), runs then 44, 28, 21, 17, 16, 12 days; whole tree day 163 |

- The rebirth card shows what ten times the net worth would give, so waiting is visible.

## Open questions for the owner

- After the whole tree (around day 163 for the robot) RBP has nothing to buy. Options: repeatable nodes, a second tree ring.
- The once-a-day player loses a lot to the 8-hour cap. Options: raise it, or pay a smaller rate beyond it.

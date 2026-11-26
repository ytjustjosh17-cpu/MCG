# Sol balance guide

The owner wants Sol to take weeks and never feel easy.
This page says how the economy works, what the pace targets are, and how to check a change.

All tuning numbers live in `game/scripts/data.gd`. The rules that use them live in `game/scripts/game_state.gd`.

## Pace targets

Measured with the pacing robot (`game/tests/pacing_sim.gd`): 4 short sessions a day, about 15 minutes of play, tapping 3 times a second, buying sensibly, taking deals and hiring managers.

| Milestone | Target day | Last measured |
|---|---|---|
| First company | under 0.5 | 0.3 |
| 25% complete | 7 to 10 | 8.5 to 11.3 (seed noise; 11.5 without mining) |
| 50% complete | 15 to 21 | 18.8 to 19.5 |
| 75% complete | 28 to 38 | 32.5 to 32.9 |
| 90% complete | 33 to 46 | 40.3 to 40.5 |
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
| Mining | one pool of miners that all mine one coin you choose (switch free, any time); a miner earns 3% of its price an hour in £ whichever coin it mines, so switching never changes earnings, only which coin you collect (mining news can speed a coin up for a few days); miner price ×1.45 each, 60 max; all mining capped at 2% of income plus 0.15% per miner | `RIG_*`, `MINE_*` |
| Golden sun | cash, Frenzy (taps ×5 for 20 s, not on top of ×3) or Rush (×2 income for 10 min, only while open) | `SUN_*`, `FRENZY_*`, `RUSH_S` |
| Crits | 4% + 0.2% per level, ×5 | `CRIT_*` |
| Time away | full income, capped at 8 hours | `OFFLINE_CAP_H` |
| Goals | daily: 1.5 h of income each; weekly: 3 h each | `daily_reward()`, `weekly_reward()` |
| Achievements | 1 h of income each | `_check_achievements()` |
| Daily streak | 0.15 h of income × days in a row (max 7) on the first open each day | `_check_streak()` |
| Deals | small, every 12 to 25 minutes of play (time away counts up to 30 min); no buyer deal at a milestone count | `roll_deal()`, `DEAL_EVERY_MIN` |
| Collections, homes, mergers | permanent multipliers | `bonus`, `HOME_BONUS`, `mult` |
| Unit milestones | 5, 25, 50 units of one company: ×1.1, ×1.15, ×1.25 | `MILESTONES` |
| Synergies | one-off buys: a company at stage N lifts another by 20 to 30% | `SYNERGIES` |
| Achievements | +0.2% income each, capped at +15% (reached near the last ones) | `ACH_BONUS`, `ACH_BONUS_CAP` |
| Overall dial | all company income × 0.84, set so the 1.1 bonuses keep the pace | `INCOME_SCALE` |

## Guard rails (keep these true)

1. Trading must not beat owning companies. `tests/market_test.gd` measures it: the average return 6, 24 and 72 hours after crash news, pump news and big dips must stay close to the normal return (limits 3%, 5%, 8%). A pull back to a home price made dips bounce by 12%, so coins no longer have one. Random moves go into the fair price itself (a random walk) and the price follows it, so dips are not promises of a bounce. Coin news shifts the coin's long-run anchor too. Re-run the exploit persona after any market change.
2. Restoring a backup never passes time (so it can't re-roll the market), and a backup can't rewind the game it came from (`user://restore_guard.json`, kept through a reset). Otherwise backup-gamble-restore was a free undo worth +40 to 80% a day.
3. Time away is worked out without the ×2 boost, then only the boosted hours are added back.
4. Selling a unit to a buyer pays a little under what rebuying costs.
5. Staking pays at most 5% of hourly income across all coins together.
10. Taps: at most 7 paid a second. Invest goals need a real amount (10 minutes of income or $100).
11. The clock going backwards never re-rolls goals or the streak. Restoring a backup keeps the live market and deal.
12. Golden suns: at most 4 a day, only while playing, worth 10 to 60 minutes of income or a short buff. Buffs end when the app closes and never pay while away.
13. Mining pays at most 2% of income plus 0.15% per miner, counts at most 8 hours while away, and a restore mines nothing.
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

## Open questions for the owner

- Late game: after everything is bought (around day 55 for heavy players) there is nothing new to do. Options: a "new empire" restart with a permanent bonus, more rivals above $50T, levels past 25.
- The once-a-day player loses a lot to the 8-hour cap. Options: raise it, or pay a smaller rate beyond it.

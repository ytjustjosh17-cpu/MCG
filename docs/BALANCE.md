# Sol balance guide

The owner wants Sol to take weeks and never feel easy.
This page says how the economy works, what the pace targets are, and how to check a change.

All tuning numbers live in `game/scripts/data.gd`. The rules that use them live in `game/scripts/game_state.gd`.

## Pace targets

Measured with the pacing robot (`game/tests/pacing_sim.gd`): 4 short sessions a day, about 15 minutes of play, tapping 3 times a second, buying sensibly, taking deals and hiring managers.

| Milestone | Target day | Last measured |
|---|---|---|
| First company | under 0.5 | 0.3 |
| 25% complete | 7 to 10 | 8.3 to 8.5 |
| 50% complete | 15 to 21 | 17.8 to 18.3 |
| 75% complete | 28 to 38 | 32.8 to 33.8 |
| 90% complete | 33 to 46 | 43.5 to 44.3 |
| All 6 mergers | 35 to 50 | 44.3 to 45.9 |

A change that moves any milestone outside its range needs a reason, written in the commit message.

Other players, measured by the agent play-testers:
- Twice a day: about 1.4 × slower than the robot. Fine.
- Once a day: about 3 × slower (90% around day 98), because time away pays at most 8 hours.
- Heavy completionist (48 minutes a day): 100% around day 55. After that there is nothing new to do yet (see "Open questions").

## How money flows

| Source | Rule | Lever |
|---|---|---|
| Tapping | `tap_base(level) + 0.12% of income per hour` per tap; ×3 boost for 60 s every 10 min | `tap_value()` |
| Companies | units × unit income × stage multiplier × merger × global bonus | `BUSINESSES`, `stage_mult` |
| Expansions | real-time timers, doubling each stage, max 48 h | `expansion_minutes()` |
| Property | 2.2% of price per hour, improvements add more | `RENT_PER_H`, `IMPROVEMENTS` |
| Shares | dividends; prices drift slowly back to a fair value; news moves them at once | `STOCK_DIV_SCALE`, `_market_tick()` |
| Crypto | boom and bust phases, staking (24 h lock, capped) | `COINS`, `STAKE_CAP` |
| Time away | full income, capped at 8 hours | `OFFLINE_CAP_H` |
| Goals | daily: 1.5 h of income each; weekly: 3 h each | `daily_reward()`, `weekly_reward()` |
| Achievements | 1 h of income each | `_check_achievements()` |
| Daily streak | 0.15 h of income × days in a row (max 7) on the first open each day | `_check_streak()` |
| Deals | small, every 12 to 25 minutes of play | `roll_deal()`, `DEAL_EVERY_MIN` |
| Collections, homes, mergers | permanent multipliers | `bonus`, `HOME_BONUS`, `mult` |

## Guard rails (keep these true)

1. Trading must not beat owning companies. Random moves go into the fair price itself (a random walk) and the price follows it, so dips are not promises of a bounce. Coin news shifts the coin's long-run anchor too. Re-run the exploit persona after any market change.
2. Restoring a backup never passes time (so it can't re-roll the market).
3. Time away is worked out without the ×2 boost, then only the boosted hours are added back.
4. Selling a unit to a buyer pays a little under what rebuying costs.
5. Staking pays at most 5% of hourly income across all coins together.
10. Taps: at most 7 paid a second. Invest goals need a real amount (10 minutes of income or $100).
11. The clock going backwards never re-rolls goals or the streak. Restoring a backup keeps the live market and deal.
12. Golden suns: at most 4 a day, only while playing, worth 10 to 60 minutes of income.
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
3. One seed can be a day off by chance (markets are random). Two seeds moving the same way is real.
4. To isolate a feature, the robot takes a second argument: `nohome` (skip homes) or `nodeals` (skip deals and managers). `news`, `dip` and `hold` run trading bots that try to profit from news.

## Open questions for the owner

- Late game: after everything is bought (around day 55 for heavy players) there is nothing new to do. Options: a "new empire" restart with a permanent bonus, more rivals above $50T, levels past 25.
- The once-a-day player loses a lot to the 8-hour cap. Options: raise it, or pay a smaller rate beyond it.

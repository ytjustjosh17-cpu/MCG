# Sol balance guide

The owner wants Sol to take weeks and never feel easy.
This page says how the economy works, what the pace targets are, and how to check a change.

All tuning numbers live in `game/scripts/data.gd`. The rules that use them live in `game/scripts/game_state.gd`.

## Pace targets

Measured with the pacing robot (`game/tests/pacing_sim.gd`): 4 short sessions a day, about 15 minutes of play, tapping 3 times a second, buying sensibly, taking deals and hiring managers.

| Milestone | Target day | Last measured |
|---|---|---|
| First company | under 0.5 | 0.3 |
| 25% complete | 6 to 10 | 6.8 to 8.9 |
| 50% complete | 12 to 18 | 13.8 to 14.8 |
| 75% complete | 21 to 30 | 21.9 to 23.5 |
| 90% complete | 27 to 38 | 27.3 to 28.3 |
| All 6 mergers | 35 to 50 | 40.3 |
| All 17 companies | 35 to 45 | 36.3 to 36.8 |

A change that moves any milestone outside its range needs a reason, written in the commit message. Earlier than the range is not allowed (the game must never get easier); later is fine with a reason.

1.2 batch 3 (season, upgrade paths, fixed terms, days played), measured on seeds 1234, 99, 7 and the greedy robot: 90% day 28.3, 27.3, 27.8, greedy 28.3, rate+gamble+loan 27.3 (before: 29.3, 29.3). Each feature was tuned down until no seed landed before day 27:
- Weekly season bar: daily goal +10 points, weekly +25, golden sun +2, the day's first tap +5. Milestones 30 (1 h of income), 70 (Rush), 120 (2 h), 180 (Frenzy), 250 (4 h). Cash is fixed when reached and waits in the claim list. At 2/4/8 h it cost about half a day.
- Company upgrade paths: five named steps per company, +6% of its income each, opening at stages 2/4/6/8/10. Price = the extra income x the slower of 90 h and 1.5 x a unit's payback at that stage, so a step never beats a unit. At +25% / 30 h the robot finished at day 24.3; at +10% / 60 h, 26.3 to 27.8 with the rest. The spend counts in `invested` (net worth and the sell price), like units.
- Fixed terms: 1 / 3 / 7 days at 20% / 66% / 170% (raised so locking beats dividends: the best share pays about 5% a day). You cannot open one while a loan runs, so borrowing to lock never pays. At most a day of base income locked, so a term adds at most about a fifth of a day's income per day. Robot with these rates (rate rebirths, 60 days): 90% day 28.8 and 29.5 (seeds 1234, 99), greedy 28.8 (was 29.3). Terms run on the wall clock (a forward-set clock can win only a few hours of income); a clock set back never pays early. Breaking early returns 95%, no interest. The robot locks 7 days when cash is four times the room left.
- Days played: milestones at 7/14/30/60/100/200 days pay about an hour of income (a streak gift's size). Never resets.

1.2 earnings boost (owner: "it seems slow to make money"): companies earn 6% more (`INCOME_SCALE` 0.85), and taps in a row pay up to x2 (`combo_mult`: from a 10 combo to x2 at 100, then flat; real taps only, never the auto clicker). The targets moved about a fifth earlier on purpose: 90% at about a month instead of five weeks. A flat x2.5 combo with a bigger tap share put 90% at day 19, far too quick.

Miner upgrades (1.2): Faster chips (+15% mining a level, 5 levels, priced from what mining makes) and Better cooling (+5 points on the mining cap a level, 3 levels, priced from company income). Kept in `miners`, so they reset on a rebirth. The greedy miner robot stays no faster than normal play (90% day 31.3).

Earlier: 1.2 balance pass (seeds 1234, 99, 7, the greedy miner robot, and the rate, gamble and loan robot). 25% on seed 7 lands at day 10.5, half a day late: accepted, later is the safe side.

## Expansion prices (1.2)

Before 1.2 an expansion's price grew ×3.3 a stage while the company's income grew far less. Measured in hours of that company's own income (full units, before bonuses):

| | Stage 1 | Stage 4 | Stage 9 |
|---|---|---|---|
| Shop to IT, before | 33 to 57 | 97 to 167 | 2,300 to 4,000 |
| Shop to IT, now | 45 to 80 | 66 to 116 | 470 to 830 |
| Hotel to Space, before | 66 to 114 | 134 to 254 | 800 to 5,100 |
| Hotel to Space, now | 81 to 160 | 117 to 231 | 800 to 1,650 |

- Expansion prices grow ×2.6 a stage (Space ×2.5, as before). The Shop's 4→5 expansion went from about £287K to about £211K.
- To keep the pace, company openings, unit prices and first expansions cost 45% more (Oil, Airline and Space expansions kept their old base). So stage 1 and 2 expansions cost a little more than before; every later one costs less.
- The company page shows what an expansion is worth: "+£X /h now · +£Y /h when full".
- Why not cheaper still: expansions are the game's main brake. A flat 30 hours of the company's income put 90% at day 19 to 23, even with dearer units.

## How money flows

| Source | Rule | Lever |
|---|---|---|
| Tapping | `tap_base(level) + 0.12% of income per hour` per tap (base 2.5 x 1.9 per level, level cost 1,000 x 3.1 per level); ×3 boost for 60 s every 10 min | `tap_value()` |
| Companies | units × unit income × stage multiplier × merger × global bonus | `BUSINESSES`, `stage_mult` |
| Expansions | real-time timers, doubling each stage, max 48 h | `expansion_minutes()` |
| Property | 2.2% of price per hour, improvements add more | `RENT_PER_H`, `IMPROVEMENTS` |
| Shares | dividends paid once an hour on the hour at a set rate per share (1% to 5% of the base price a day, by the company's yield; `Data.div_yield_day()`, plus bonuses), not tied to the live price; time away pays missed hours up to the away cap; prices drift slowly back to a fair value; news moves them at once. Robot with 1% to 5% a day: 90% day 37.8 and 36.3 (seeds 1234, 99), was 36.9 and 35.3 | `dividend_rate()`, `_pay_dividends()` |
| Crypto | random walk with boom and bust phases (no pull home), staking (24 h lock, capped) | `COINS`, `STAKE_CAP` |
| Converting coins | sell at the usual 0.5% spread, then buy the other coin; nothing gained, so no loop | `convert_coin()` |
| Mining | one pool of miners mining one coin you choose (switch free, any time); a miner earns 4% of its price an hour in £ for any coin (pays back in about a day), capped at a quarter of company income (never under £2K/h, 1.2) because a buy-by-payback player let mining outrun companies; each miner costs ×1.7 more, 40 max, which keeps mining to roughly 10 to 25% of income | `RIG_*`, `MINE_*` |
| Head office | ten one-off upgrades: taps ×1.5, deals 25% sooner, away cap 10 h then 12 h, expansions 15% quicker (twice), +1 golden sun a day, locked coins +25%, miners +25%, managers take 6% | `UPGRADES` |
| Auto clicker | 5 levels (£5K, £40K, £500K, £10M, £300M; cut hard in 1.2 as it only taps while you play: robot 90% day 28.9 / 29.3, greedy 28.8, unchanged): a tap every 2, 1.5, 1, 0.75, 0.5 s, each worth half a tap (no big taps or Frenzy); only while playing, pauses 2 min after the last touch; reset by rebirth | `AUTO_LEVELS`, `auto_tick()` |
| Selling a company | half its value (value = 60% of what was spent), so always a loss; not while expanding | `sell_business()` |
| Managers | can be switched off (no expanding, no cut) and on again | `set_manager_on()` |
| Bank savings | 0.2% an hour, capped at 5% of base income (floor £100/h); reset by rebirth | `BANK_*`, `savings_per_hour()` |
| Loans | up to 6 h of base income (min £5K), 125% back in 5 payments every 4 h; cash can go below zero (nothing can be bought then); owing counts against net worth; reset by rebirth. Borrower robot 90% day 36.3 vs 36.9 | `LOAN_*`, `take_loan()`, `_bank_tick()` |
| Daily wheel | once a day with the casino open: 5 to 180 minutes of income in cash or chips, about 20 on average | `WHEEL`, `spin_wheel()` |
| Golden sun | cash, Frenzy (taps ×5 for 20 s, not on top of ×3) or Rush (×2 income for 10 min, only while open) | `SUN_*`, `FRENZY_*`, `RUSH_S` |
| Crits | 4% + 0.2% per level, ×5 | `CRIT_*` |
| Time away | full income, capped at 8 hours | `OFFLINE_CAP_H` |
| Goals | daily: 1.5 h of income each; weekly: 3 h each; waits to be claimed, amount fixed when earned | `daily_reward()`, `weekly_reward()`, `claim()` |
| Achievements | 1 h of income each | `_check_achievements()` |
| Daily streak | 0.15 h of income × days in a row (max 7) on the first open each day | `_check_streak()` |
| Deals | small, every 12 to 25 minutes of play (time away doesn't count); never pop up, they wait on the Business tab; no buyer deal at a milestone count | `roll_deal()`, `DEAL_EVERY_MIN` |
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
10. Taps: at most 7 paid a second, and tap heat (+1 per paid tap, cools 2 a second) above 1,200 makes taps pay a quarter, so a tapping app can't farm for hours (about 4 minutes non-stop at 7 a second to reach it; the robot's 3 a second never does). Invest goals need a real amount (10 minutes of income or $100).
11. The clock going backwards never re-rolls goals or the streak. Restoring a backup keeps the live market and deal.
12. Golden suns: at most 4 a day, only while playing, worth 10 to 60 minutes of income or a short buff. Buffs end when the app closes and never pay while away.
13. Mining pays at most 25% of company income (floor £2K/h); its other limit is price (×1.7 per miner, 40 max). It, counts at most 8 hours while away, and a restore mines nothing.
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
5. After any money change also run the greedy player, `SIM_GREEDY=1` (buys miners whenever it can and sells what they dig). Its 90% day must not be earlier than the normal robot's; in 1.2 it was 36.3 for both.

## Casino

- Opens with tree unlock nodes: Sol Casino (6 RBP, linked to the Empire and Hands gates, so a first rebirth reaches it) for slots, High tables (20 RBP) for roulette and blackjack. Tree nodes last forever; chips do not (they are money). So the casino never touches the first run.
- Chips: bought with cash at the cage, cashed out any time, counted in net worth.
- Limits follow base income (without the x2 boost): a bet is at most 6 minutes of income (`CASINO_MAX_BET_H`, at least £500), one payout at most 24 hours (`CASINO_MAX_WIN_H`, at least £100K). A slot bonus buy may stake up to 20 bets; a blackjack double or split up to 2. The "High roller" keystone doubles both.
- Sun Forge (`tests/forge_test.gd`, 400k spins a mode): base 96.2%, ante 96.1% (free spins 1 in 188 vs 1 in 395), bought feature 95.7% (average 92.7x). Hit rate 30%. Max 5,000x, plus the round cap.
- 1.2 games (`tests/casino12_test.gd`): video poker 9/6 97.7% with the hint strategy (about 99.5% perfect), crash about 97% (max 1000x, crash point fixed at the start), plinko 97.9 to 98.3%, races at most 95% a runner.
- Payback, measured by `tests/casino_test.gd` on every build: slots 95.5 to 95.8% exactly from the reel strips (bonus buys about 93%), roulette 97.3% (every bet type, all 37 numbers), blackjack 99.3% with perfect basic strategy over 300k hands. The shoe is a fresh six decks every hand, so counting cards can't win.
- Every bet and every payout is saved the moment it happens, before any animation, so closing the app can't undo a loss. A backup can't rewind the game either (restore guard).
- Gambler robot (`SIM_GAMBLE=1`): 40 max-bet spins on Iron Vault (the wildest machine) every session, free spins played out. 90% complete on day 37.5, 38.8, 38.3 and 39.3 (seeds 7, 99, 2024, 5) against 38.5 without gambling. The luckiest seed won £3.8T in all and still finished on day 38.8, so a lucky streak can't skip weeks.
- Jackpot (every game but blackjack and video poker, which pay back about 99% already): the pot is kept in hours of base income (`casino.pot_h`), so it keeps pace with the empire. It starts at `JP_SEED_H` (24 h, never under £100K), each bet adds bet / max bet x 6 min x `JP_SHARE` (0.5%), so a max bet adds 0.0005 h and small bets at the £500 floor can't pump it, and it stops at `JP_CAP_H` (72 h). Chance `JP_CHANCE` 1 in 12,000 bets. A bet wins pot x (bet / max bet), so a max bet empties it back to the seed. Wins in jackpot games pay `JP_TRIM` (2%) less; the Crash and Tower cash-out buttons show the real figure (`casino_net`) and every info sheet says so. Return = base x 0.98 + jackpot share, measured in `smoke_test` with the real pot: a 96.7% game returns 96.8% over 2,320 max bets (the robot's 90 days) and 97.3% over 24,000; a 98.3% game 98.4% to 98.8%; a 99% game (Tower's best mode) 99.1% to 99.5%. Normal play stays near the seed: the robot's pot was 25.2 h after 90 days, so a max-bet jackpot is about a day of income and 3 days is a ceiling. Average pot over 24,000 max bets: 30 h of income. The roll is seeded by the game start, a bet counter (`counters.jp_n`) and a salt re-rolled on every backup restore (`casino.jp_salt`, so a restored code cannot replay known rolls), decided when the bet is taken and saved with it, so closing the app can't re-roll it. A won jackpot (`casino.jp_due`) is paid past the 24 h cap when the round ends, or when the lobby opens. The pot goes back to the seed on a rebirth.
- Jackpot robot (seed 1234, rate rebirths, gambler and loan, 90 days): 90% on day 28.3 and 80.5 (run 2) before and after. The gambler made 2,320 bets, so no jackpot. Luckiest persona (`SIM_JP=1`, a jackpot every 10th session: 6 jackpots worth £2.5Qa, about 30 times normal luck): still 28.3 and 80.5. The casino can't skip weeks.

## Rebirth and the RBP tree

- Rebirth from £10B net worth. RBP = 10 × cube root of (net worth ÷ £10B), +RBP nodes up to +50%. So £10B gives 10, £10T 100, £10Qa 1,000. Past 1,000 RBP it grows with the 9th root instead (`RBP_SOFT_CAP`, 1.2): a player who waited months used to get 87,000 RBP, the whole tree at once; now about 4,400.
- Rebirth clears money and assets (`REBIRTH_RESET`), including rewards not yet claimed, the waiting deal and the daily gift, so nothing is carried into a new run. It keeps the market, achievements, stats, settings, goal and streak timers and the tree (`REBIRTH_KEEP`).
- The tree: 229 nodes since 1.2 (a 9-node deep path on every branch, ~19,000 RBP in all); before that 157 nodes plus Sol (8 branches, a ring of gates, 8 bridges, 24 notables, 16 keystones, 5 unlocks), 7,509 RBP in all.
- Unlock nodes (gold stars, 3 slots still free for future unlocks): Sol Casino 6, High tables 20, Island estates 45 (3 properties £50B to £160B), Relic hunters 50 (a 7th collection, £2B to £2T, +8% when complete), Frontier 60 (Fusion plant £1.5T and Orbital yards £20T, about 2% of price an hour per unit like Space launch). Their content is never counted in completion % or achievements (`businesses()`, `property_count()`, `collections()` are the lists in play; completion uses the base lists). Cost = 3 × 1.32^(depth - 1), notables ×2, keystones ×4. Effects of one stat add up (never multiply each other). The tree is not part of completion %, so the pace targets above are for the first run.
- Guard rails it moves: away cap up to +7.25 h, one more golden sun a day (so 6 at most with Head office), big taps ×10 with Thunder taps, managers' cut 0 with Loyal staff.
- Robot (`SIM_REBIRTH=never|asap|patient|rate`, 240 days, seed 1234):

| Policy | Result |
|---|---|
| never | identical to before (first run 90% day 37.9) |
| asap (rebirth at £10B) | 10 RBP a run, runs of about 20 days, 21 nodes by day 180. A trap, on purpose |
| rate (rebirth when RBP per day stops rising) | 1.2 (229 nodes, RBP soft cap): 1st rebirth day 207.9, +5,981 RBP, 185 of 229 nodes. Before 1.2: day 118, +87,446 (the whole tree). Older: day 70, +921 |

- The rebirth card shows what ten times the net worth would give, so waiting is visible.
- With the unlock nodes (Frontier raises late net worth a lot): never-rebirth run unchanged; rate robot rebirths on days 70, 115, 136, 159, whole tree day 158.5 (was 163). Gambler + rate: whole tree day 169.8, so the casino slows the tree, never speeds it.

## Open questions for the owner

- 1.2: the rate robot waits until day 208 for its first rebirth and then buys 80% of the tree at once. A steeper cap or dearer deep nodes would spread the tree over more rebirths; not changed yet.

- After the whole tree (around day 163 for the robot) RBP has nothing to buy. Options: repeatable nodes, a second tree ring.
- The once-a-day player loses a lot to the 8-hour cap. Options: raise it, or pay a smaller rate beyond it.

## Time to £10B (1.2, corrected robot)

The robot now tires like a thumb (heat) and gets the tap boost for only its 60 s of taps (before, every tap of a visit was boosted, which made tapping look three times stronger). With that fix the normal robot (4 short visits) reaches 90% on day 38.3 and 37.9 (seeds 1234, 99), the top of the target range; greedy miner 38.9.

| How you play (`SIM_SCHED`) | Day net worth reaches £10B |
|---|---|
| six 30-minute visits (`heavy`) | 8.9 |
| six 10-minute visits (`six`) | 10.8 (seed 99: 11.4) |
| every 4 hours round the clock (`alarm`) | 11.6 |
| four short visits (normal robot) | 22.5 to 22.8 |
| one 15-minute visit a day (`once`) | 42.8 |

In the `six` diary (`SIM_DIARY=1`), taps paid about 60% of everything earned before £10B, rewards about 6%, and companies the rest. One hour of tapping at 3 a second pays about 19 hours of income (0.12% of an hour a tap x 10,800 taps x about 1.46 for combos); past about 10 minutes non-stop at 3 a second taps tire to a tenth.

Then (owner: "speed it up a little"): `INCOME_SCALE` 0.85 to 1.05 (companies earn about 24% more). Robot 90% day 32.3 and 33.3 (seeds 1234, 99), greedy 33.3; £10B on day 19.5 to 19.8 for the normal robot and 9.4 for six 10-minute visits. Tried: 0.92 (35.8), 0.97 (34.8), taps +25% (35.3), 1.12 (30.3, a little quick).

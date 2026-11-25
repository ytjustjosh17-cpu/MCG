extends Node
## Global game state and rules: money, tapping, businesses, investments,
## collections, mergers, achievements, daily tasks, saving.

signal changed
signal tapped(amount: float)
signal achievement(title: String, reward: float)
signal goal_done(scope: String, text: String, reward: float)
signal deal_ready(deal: Dictionary)
signal rival_beaten(index: int)
signal streak_gift(days: int, amount: float)
signal expansion_done(biz_id: String, stage: int)
signal market_news(item: Dictionary)

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.json.tmp"
const SAVE_BAK := "user://save.json.bak"
const SAVE_VERSION := 6
const CHANGE_EVERY_S := 0.1
const BOOST_MULT := 3.0
const BOOST_LEN_S := 60.0
const BOOST_COOLDOWN_S := 600.0
const IBOOST_LEN_S := 4.0 * 3600.0
const IBOOST_COOLDOWN_S := 4.0 * 3600.0
const HISTORY_EVERY_S := 300.0
const HISTORY_MAX := 2100
const WEEK_S := 7.0 * 24.0 * 3600.0
const MARKET_TICK_S := 60.0
const MARKET_HIST := 120   # 1-minute points (2 hours)
const HIST_Q := 96         # 15-minute points (1 day)
const HIST_H := 168        # hourly points (1 week)
const NEWS_MAX := 30

# ---- saved state ---------------------------------------------------------
var cash := 0.0
var total_earned := 0.0
var level := 1
var taps := 0
var boost_until := 0.0
var boost_ready_at := 0.0
var boosts_used := 0
var ibost_until := 0.0
var ibost_ready_at := 0.0
var biz := {}          # id -> {name, stage, units, exp_until, invested}
var shares := {}       # sym -> {qty, cost}
var coins := {}        # sym -> {qty, cost}
var prices := {}       # sym -> price (shares and coins)
var price_hist := {}   # sym -> Array of 1-minute prices
var hist_q := {}       # sym -> Array of 15-minute prices
var hist_h := {}       # sym -> Array of hourly prices
var moods := {}        # sym or sector -> news effect on fair price
var trends := {}       # coin -> current trend per minute
var fair_log := {}     # coin -> log of fair price
var news: Array = []   # newest last: {t, text, sym, pct}
var home := 0         # index into Data.HOMES
var props := {}        # "index" -> {imps: [bool...]}
var items := {}        # "col:index" -> true
var mergers := {}      # id -> true
var achieved := {}     # id -> true
var counters := {}     # name -> number
var daily := {}        # {day, tasks: [{id, text, goal, progress, reward, done}]}
var weekly := {}       # {week, tasks: [...]}, same shape as daily
var deal := {}         # the offer waiting for an answer, if any
var deal_wait := 1500.0  # seconds of play until the next deal
var payouts: Array = []  # [{amount, at}] money owed later by a deal
var history: Array = []
var vibrate := true
var reduce_motion := false
var started_at := 0.0
var away_earned := 0.0
var away_seconds := 0.0
var away_unseen := false  # show the welcome-back card once
var last_tap_at := 0.0
var away_notes: Array = []
var ui := {}          # remembered screen choices (tabs, chart range)
var streak := 0       # days in a row the game was opened
var streak_day := -1
var streak_unseen: Array = []  # [days, gift] to show once

# ---- runtime -------------------------------------------------------------
var sim_time := -1.0   # set by the pacing simulator
var income_per_hour := 0.0
var _income_parts := {}
var _dirty := false
var _save_timer := 0.0
var _hist_timer := 0.0
var _market_timer := 0.0
var _tick_t := -1.0      # time stamp used for news made while fast-forwarding
var _quiet := false       # no news signals while catching up
var _check_timer := 0.0
var _paused_at := 0.0
var _change_pending := false
var _change_timer := 0.0
var _achievements: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_achievements = _build_achievements()
	load_game()


func now() -> float:
	return sim_time if sim_time >= 0.0 else Time.get_unix_time_from_system()


# ==== tapping and levels =================================================

func tap_value() -> float:
	return Data.tap_base(level) + income_per_hour * 0.0012


func next_tap_value() -> float:
	return Data.tap_base(level + 1) + income_per_hour * 0.002


func level_cost() -> float:
	return Data.level_cost(level)


func level_progress() -> float:
	if level >= Data.MAX_LEVEL:
		return 1.0
	return clampf(cash / level_cost(), 0.0, 1.0)


func can_level_up() -> bool:
	return level < Data.MAX_LEVEL and cash >= level_cost()


func level_up() -> bool:
	if not can_level_up():
		return false
	cash -= level_cost()
	level += 1
	GameLog.info("game", "Level up to %d" % level)
	_mark()
	return true


func boost_active() -> bool:
	return now() < boost_until


func boost_left() -> float:
	return maxf(0.0, boost_until - now())


func boost_cooldown_left() -> float:
	return maxf(0.0, boost_ready_at - now())


func boost_ready() -> bool:
	return boost_cooldown_left() <= 0.0


func start_boost() -> bool:
	if not boost_ready():
		return false
	boost_until = now() + BOOST_LEN_S
	boost_ready_at = boost_until + BOOST_COOLDOWN_S
	boosts_used += 1
	_mark()
	return true


func ibost_active() -> bool:
	return now() < ibost_until


func ibost_ready() -> bool:
	return now() >= ibost_ready_at


func ibost_left() -> float:
	return maxf(0.0, ibost_until - now())


func ibost_cooldown_left() -> float:
	return maxf(0.0, ibost_ready_at - now())


func start_ibost() -> bool:
	if not ibost_ready() or biz.is_empty():
		return false
	ibost_until = now() + IBOOST_LEN_S
	ibost_ready_at = ibost_until + IBOOST_COOLDOWN_S
	recalc()
	return true


func tap() -> float:
	var v := tap_value() * (BOOST_MULT if boost_active() else 1.0)
	taps += 1
	last_tap_at = now()
	_task_progress("taps", 1)
	_earn(v)
	tapped.emit(v)
	return v


# ==== businesses ==========================================================

func owns(id: String) -> bool:
	return biz.has(id)


func companies() -> int:
	return biz.size()


func capacity(id: String) -> int:
	return int(biz[id]["stage"]) * Data.UNITS_PER_STAGE if biz.has(id) else 0


func merger_mult(id: String) -> float:
	var m := 1.0
	for mg in Data.MERGERS:
		if mergers.has(mg["id"]) and id in mg["boost"]:
			m *= float(mg["mult"])
	return m


func global_mult() -> float:
	var m := 1.0
	for c in Data.COLLECTIONS:
		if collection_done(c["id"]):
			m += float(c["bonus"])
	m += Data.HOME_BONUS * float(home)
	if mergers.has("holding"):
		m *= 2.0
	return m


func biz_income(id: String) -> float:
	if not biz.has(id):
		return 0.0
	var b := Data.business(id)
	var s: Dictionary = biz[id]
	var v := float(s["units"]) * float(b["unit_income"]) * pow(float(b["stage_mult"]), int(s["stage"]) - 1)
	v *= merger_mult(id) * global_mult()
	if ibost_active():
		v *= 2.0
	if s.get("manager", false) and int(s["stage"]) < Data.MAX_STAGE:
		v *= 1.0 - Data.MANAGER_CUT  # no cut once fully expanded
	return v


# ==== managers =============================================================

func manager_cost(id: String) -> float:
	if not biz.has(id):
		return 0.0
	var st := mini(int(biz[id]["stage"]), Data.MAX_STAGE - 1)
	return Data.expansion_cost(Data.business(id), st) * Data.MANAGER_COST_X


func has_manager(id: String) -> bool:
	return biz.has(id) and bool(biz[id].get("manager", false))


func hire_manager(id: String) -> bool:
	if not biz.has(id) or has_manager(id) or cash < manager_cost(id):
		return false
	cash -= manager_cost(id)
	biz[id]["manager"] = true
	GameLog.info("biz", "Manager hired for %s" % id)
	recalc()
	return true


func _managers_work() -> void:
	## Managers start the next expansion as soon as a company is full and
	## there's cash for it. They never buy units.
	for id in biz.keys():
		if has_manager(id) and int(biz[id]["units"]) >= capacity(id) and can_expand(id):
			start_expansion(id)


# ==== deals ================================================================

func tick_deals(dt: float) -> void:
	## Only counts time with the app open, so deals never pile up while away.
	if not deal.is_empty() or biz.is_empty():
		return
	deal_wait -= dt
	if deal_wait <= 0.0:
		deal_wait = randf_range(Data.DEAL_EVERY_MIN[0], Data.DEAL_EVERY_MIN[1]) * 60.0
		deal = roll_deal()
		if not deal.is_empty():
			deal_ready.emit(deal)


func roll_deal() -> Dictionary:
	var ids: Array = biz.keys()
	ids.shuffle()
	var id: String = ids[0]
	var name := String(biz[id]["name"])
	var inc := maxf(income_per_hour, 100.0)
	var kinds := ["order"]
	if int(biz[id]["units"]) >= 2:
		kinds.append("buyer")
	if int(biz[id]["stage"]) < Data.MAX_STAGE and not expanding(id) and float(biz[id].get("discount", 1.0)) >= 1.0:
		kinds.append("supplier")
	match kinds[randi() % kinds.size()]:
		"buyer":
			var price := unit_price(id) / Data.UNIT_PRICE_GROWTH * 1.15  # a bit over what the last outlet cost
			return {"kind": "buyer", "id": id, "value": price,
				"title": "A buyer for one outlet", "text": "%s · they pay %s" % [name, money_short(price)],
				"yes": "Sell for " + money_short(price)}
		"supplier":
			return {"kind": "supplier", "id": id, "value": expansion_cost(id) * 0.25,
				"title": "Supplier discount", "text": "%s · next expansion 25%% off" % name,
				"yes": "Take it"}
	var cost := inc / 6.0  # ten minutes of income
	return {"kind": "order", "id": id, "value": cost,
		"title": "Rush order", "text": "%s · pay %s now, get %s in an hour" % [name, money_short(cost), money_short(cost * 1.3)],
		"yes": "Pay " + money_short(cost)}


func accept_deal() -> bool:
	if deal.is_empty():
		return false
	var d := deal
	var id := String(d["id"])
	var ok := false
	if biz.has(id):
		match d["kind"]:
			"buyer":
				if int(biz[id]["units"]) >= 2:
					biz[id]["units"] = int(biz[id]["units"]) - 1
					biz[id]["invested"] = maxf(0.0, float(biz[id]["invested"]) - unit_price(id))
					_pay(float(d["value"]))
					ok = true
			"supplier":
				biz[id]["discount"] = 0.75
				ok = true
			"order":
				if cash >= float(d["value"]):
					cash -= float(d["value"])
					payouts.append({"amount": float(d["value"]) * 1.3, "at": now() + 3600.0})
					ok = true
	deal = {}
	if ok:
		_bump("deals")
		_task_progress("deal", 1)
		recalc()
	return ok


func decline_deal() -> void:
	deal = {}


func _pay_out() -> void:
	var t := now()
	for i in range(payouts.size() - 1, -1, -1):
		if t >= float(payouts[i]["at"]):
			_pay(float(payouts[i]["amount"]))
			payouts.remove_at(i)


# ==== rivals ================================================================

func rivals_beaten() -> int:
	## Rivals you've passed. Once passed they stay passed, even if spending
	## drops your net worth for a while.
	return maxi(_rivals_live(), int(counters.get("rivals", 0)))


func _rivals_live() -> int:
	var nw := net_worth()
	var n := 0
	for r in Data.RIVALS:
		if nw >= float(r[2]):
			n += 1
	return n


func _check_rivals() -> void:
	var n := _rivals_live()
	var best := int(counters.get("rivals", 0))
	if n > best:
		counters["rivals"] = float(n)
		for i in range(best, n):
			rival_beaten.emit(i)


func open_business(id: String, name: String) -> bool:
	var b := Data.business(id)
	if b.is_empty() or biz.has(id) or cash < float(b["cost"]):
		return false
	cash -= float(b["cost"])
	biz[id] = {"name": name, "stage": 1, "units": 1, "exp_until": 0.0, "invested": float(b["cost"])}
	GameLog.info("biz", "Opened %s (%s) for %s" % [name, id, money(b["cost"])])
	recalc()
	return true


func unit_price(id: String) -> float:
	return Data.unit_price(Data.business(id), int(biz[id]["units"]) - 1) if biz.has(id) else 0.0


func buy_unit(id: String) -> bool:
	if not biz.has(id):
		return false
	var s: Dictionary = biz[id]
	if int(s["units"]) >= capacity(id):
		return false
	var p := unit_price(id)
	if cash < p:
		return false
	cash -= p
	s["units"] = int(s["units"]) + 1
	s["invested"] = float(s["invested"]) + p
	_bump("units_bought")
	_task_progress("units", 1)
	recalc()
	return true


func expansion_cost(id: String) -> float:
	if not biz.has(id):
		return 0.0
	return Data.expansion_cost(Data.business(id), int(biz[id]["stage"])) * float(biz[id].get("discount", 1.0))


func expansion_seconds(id: String) -> float:
	return Data.expansion_minutes(Data.business(id), int(biz[id]["stage"])) * 60.0 if biz.has(id) else 0.0


func expanding(id: String) -> bool:
	return biz.has(id) and float(biz[id]["exp_until"]) > 0.0


func expansion_left(id: String) -> float:
	return maxf(0.0, float(biz[id]["exp_until"]) - now()) if expanding(id) else 0.0


func can_expand(id: String) -> bool:
	return biz.has(id) and not expanding(id) and int(biz[id]["stage"]) < Data.MAX_STAGE and cash >= expansion_cost(id)


func start_expansion(id: String) -> bool:
	if not can_expand(id):
		return false
	var c := expansion_cost(id)
	cash -= c
	biz[id]["invested"] = float(biz[id]["invested"]) + c
	biz[id]["discount"] = 1.0
	biz[id]["exp_until"] = now() + expansion_seconds(id)
	GameLog.info("biz", "Expansion started: %s to stage %d (%s)" % [id, int(biz[id]["stage"]) + 1, clock(expansion_seconds(id))])
	_mark()
	return true


func _finish_expansions() -> void:
	var t := now()
	for id in biz.keys():
		var s: Dictionary = biz[id]
		if float(s["exp_until"]) > 0.0 and t >= float(s["exp_until"]):
			s["exp_until"] = 0.0
			s["stage"] = int(s["stage"]) + 1
			GameLog.info("biz", "Expansion done: %s now stage %d" % [id, s["stage"]])
			_bump("expansions")
			_task_progress("expand", 1)
			recalc()
			expansion_done.emit(id, int(s["stage"]))


func biz_value(id: String) -> float:
	return float(biz[id]["invested"]) * 0.6 if biz.has(id) else 0.0


# ==== shares and coins ====================================================

func price(sym: String) -> float:
	return float(prices.get(sym, 0.0))


func _stock(sym: String) -> Array:
	for s in Data.STOCKS:
		if s[0] == sym:
			return s
	return []


func _coin(sym: String) -> Array:
	for c in Data.COINS:
		if c[0] == sym:
			return c
	return []


func holding(book: Dictionary, sym: String) -> float:
	## Free (sellable) amount.
	return float(book[sym]["qty"]) if book.has(sym) else 0.0


func staked(sym: String) -> float:
	return float(coins[sym].get("staked", 0.0)) if coins.has(sym) else 0.0


func stake_left(sym: String) -> float:
	return maxf(0.0, float(coins[sym].get("stake_until", 0.0)) - now()) if coins.has(sym) else 0.0


func stake_rate(sym: String) -> float:
	var c := _coin(sym)
	return float(c[4]) if c.size() > 4 else 0.0


func stake(sym: String, fraction: float) -> bool:
	## Locks coins for 24 hours; they earn more coins while locked.
	var free := holding(coins, sym)
	var q := free * clampf(fraction, 0.0, 1.0)
	if q <= 0.0:
		return false
	coins[sym]["qty"] = free - q
	coins[sym]["staked"] = staked(sym) + q
	coins[sym]["stake_until"] = now() + Data.STAKE_LOCK_H * 3600.0
	GameLog.info("invest", "Staked %s %s" % [str(snappedf(q, 0.0001)), sym])
	recalc()
	return true


func unstake(sym: String) -> bool:
	if staked(sym) <= 0.0 or stake_left(sym) > 0.0:
		return false
	coins[sym]["qty"] = holding(coins, sym) + staked(sym)
	coins[sym]["staked"] = 0.0
	recalc()
	return true


func stake_earn_per_hour(sym: String) -> float:
	## What one coin's stake really earns per hour, after the cap.
	var p := price(sym)
	if p <= 0.0:
		return 0.0
	var per_h := staked(sym) * stake_rate(sym)
	per_h = minf(per_h, maxf(income_per_hour, 1000.0) * Data.STAKE_CAP / p)
	return per_h * p


func staking_per_hour() -> float:
	## Value of staking rewards per hour at today's prices (capped like _accrue).
	var v := 0.0
	for sym in coins.keys():
		v += stake_earn_per_hour(sym)
	return v

func avg_price(book: Dictionary, sym: String) -> float:
	if not book.has(sym):
		return 0.0
	var q := float(book[sym]["qty"]) + float(book[sym].get("staked", 0.0))
	return float(book[sym]["cost"]) / q if q > 0.0 else 0.0


func change_pct(sym: String, minutes: int) -> float:
	## Price change over the last `minutes`, using the best history available.
	var series: Array
	var back := 0
	if minutes <= MARKET_HIST:
		series = price_hist.get(sym, [])
		back = minutes
	elif minutes <= HIST_Q * 15:
		series = hist_q.get(sym, [])
		back = minutes / 15
	else:
		series = hist_h.get(sym, [])
		back = minutes / 60
	if series.size() < 2:
		return 0.0
	var a: float = series[maxi(0, series.size() - 1 - back)]
	return (price(sym) - a) / a * 100.0 if a > 0.0 else 0.0


func series(sym: String, range_name: String) -> Array:
	match range_name:
		"1D":
			return hist_q.get(sym, [])
		"1W":
			return hist_h.get(sym, [])
	return price_hist.get(sym, [])


func sector_of(sym: String) -> String:
	var s := _stock(sym)
	return s[4] if s.size() > 4 else ""


func market_mood() -> float:
	## 0 = fear, 100 = greed, from the last day of crypto moves.
	var total := 0.0
	for c in Data.COINS:
		total += clampf(change_pct(c[0], 1440), -30.0, 30.0)
	return clampf(50.0 + total / float(Data.COINS.size()) * 2.0, 0.0, 100.0)


func buy_asset(kind: String, sym: String, amount_cash: float) -> bool:
	## Buys `amount_cash` worth of a share or coin.
	var p := price(sym)
	if p <= 0.0 or amount_cash <= 0.0 or cash < amount_cash - 0.001:
		return false
	amount_cash = minf(amount_cash, cash)
	var book: Dictionary = shares if kind == "share" else coins
	if not book.has(sym):
		book[sym] = {"qty": 0.0, "cost": 0.0}
	book[sym]["qty"] = float(book[sym]["qty"]) + amount_cash / p
	book[sym]["cost"] = float(book[sym]["cost"]) + amount_cash
	cash -= amount_cash
	_task_progress("invest", 1)
	recalc()
	return true


func sell_asset(kind: String, sym: String, fraction: float) -> float:
	var book: Dictionary = shares if kind == "share" else coins
	if not book.has(sym):
		return 0.0
	fraction = clampf(fraction, 0.0, 1.0)
	var qty := float(book[sym]["qty"]) * fraction
	var total := float(book[sym]["qty"]) + float(book[sym].get("staked", 0.0))
	var cost := float(book[sym]["cost"]) * (qty / total if total > 0.0 else 0.0)
	var got := qty * price(sym) * (1.0 - Data.SELL_SPREAD)
	cash += got
	if kind == "coin":
		_bump("crypto_profit", got - cost)  # losses count too
	book[sym]["qty"] = float(book[sym]["qty"]) - qty
	book[sym]["cost"] = float(book[sym]["cost"]) - cost
	if float(book[sym]["qty"]) <= 1e-9 and float(book[sym].get("staked", 0.0)) <= 1e-9:
		book.erase(sym)
	recalc()
	return got


func book_value(book: Dictionary) -> float:
	var v := 0.0
	for sym in book.keys():
		v += (float(book[sym]["qty"]) + float(book[sym].get("staked", 0.0))) * price(sym)
	return v


func book_cost(book: Dictionary) -> float:
	var v := 0.0
	for sym in book.keys():
		v += float(book[sym]["cost"])
	return v


func dividends_per_hour() -> float:
	var v := 0.0
	for sym in shares.keys():
		var s := _stock(sym)
		if not s.is_empty():
			v += float(shares[sym]["qty"]) * price(sym) * float(s[3]) * Data.STOCK_DIV_SCALE
	return v * global_mult()


func _market_tick(minutes := 1) -> void:
	## One market step of `minutes` (1 normally, 60 for fast-forward while away).
	var m := float(minutes)
	var ticks := float(counters.get("market_ticks", 0))
	# News effects fade slowly (half gone in about 20 days) and stay within limits,
	# so prices can't run away over months of play.
	var keep := pow(0.999976, m)
	for k in moods.keys():
		moods[k] = clampf(exp(log(maxf(float(moods[k]), 1e-6)) * keep), 0.2, 5.0)
	var pull_s := 1.0 - pow(1.0 - 0.004, m)  # drifts back to fair over hours, not minutes
	for s in Data.STOCKS:
		var sym: String = s[0]
		var fair := float(s[2]) * exp(Data.STOCK_GROWTH * ticks) * float(moods.get(sym, 1.0)) * float(moods.get(s[4], 1.0))
		var vol: float = Data.SECTOR_VOL.get(s[4], 0.006)
		_step(sym, fair, pull_s, vol * 0.45 * sqrt(m))
	var pull_c := 1.0 - pow(1.0 - 0.003, m)
	for c in Data.COINS:
		var sym: String = c[0]
		# Coins wander in boom and bust phases that change every few hours.
		if not trends.has(sym) or randf() < m / 180.0:
			trends[sym] = randfn(0.0, 0.0002)
		fair_log[sym] = float(fair_log.get(sym, log(float(c[2])))) + float(trends[sym]) * m
		fair_log[sym] = lerpf(float(fair_log[sym]), log(float(c[2])), 0.0004 * m)
		var fair := exp(float(fair_log[sym]))
		_step(sym, fair, pull_c, float(c[3]) * 0.3 * sqrt(m))
	if randf() < m / Data.NEWS_EVERY_MIN:
		_news_event()


func _step(sym: String, fair: float, pull: float, noise: float) -> void:
	var p := price(sym)
	if p <= 0.0:
		p = fair
	p *= exp((log(fair) - log(p)) * pull + randfn(0.0, noise))
	prices[sym] = p


func _record_prices(minutes: int) -> void:
	## Adds a point to each history. 15-minute steps (catching up) feed the
	## day and week charts directly.
	var t := int(counters.get("market_ticks", 0))
	for sym in prices.keys():
		_push(price_hist, sym, MARKET_HIST)
		if minutes >= 15 or t % 15 == 0:
			_push(hist_q, sym, HIST_Q)
		if t % 60 == 0:
			_push(hist_h, sym, HIST_H)


func _catch_up(quarters: int, end_t: float) -> void:
	## Fast-forwards the market in 15-minute steps without news pop-ups.
	_quiet = true
	for i in quarters:
		# Stay on 15-minute marks so the hourly chart gets every 4th step.
		counters["market_ticks"] = floorf(float(counters.get("market_ticks", 0)) / 15.0) * 15.0 + 15.0
		_tick_t = end_t - float(quarters - 1 - i) * 900.0
		_market_tick(15)
		_record_prices(15)
	_tick_t = -1.0
	_quiet = false


func _push(store: Dictionary, sym: String, cap: int) -> void:
	var h: Array = store.get(sym, [])
	h.append(_sig(prices[sym]))
	while h.size() > cap:
		h.pop_front()
	store[sym] = h


static func _sig(v: float) -> float:
	## Keeps 5 significant figures so the save file stays small.
	if v <= 0.0:
		return v
	var step := pow(10.0, floor(log(v) / log(10.0)) - 4.0)
	return snappedf(v, step)


func _news_event() -> void:
	## News moves the price straight away, so only people who already own it gain.
	## Ups and downs are the same size in log terms, so news gives no free edge.
	var r := randf()
	var item := {}
	var sym := ""
	var f := 1.0
	if r < 0.55:
		var st: Array = Data.STOCKS[randi() % Data.STOCKS.size()]
		var up := randf() < 0.5
		f = 1.0 + randf_range(0.04, 0.16)
		f = f if up else 1.0 / f
		sym = st[0]
		moods[sym] = float(moods.get(sym, 1.0)) * f
		prices[sym] = price(sym) * f
		var tmpl: Array = Data.NEWS_STOCK_UP if up else Data.NEWS_STOCK_DOWN
		item = {"text": tmpl[randi() % tmpl.size()] % st[1], "sym": sym}
	elif r < 0.75:
		var sec: String = Data.SECTORS[randi() % Data.SECTORS.size()]
		var up := randf() < 0.5
		f = 1.0 + randf_range(0.03, 0.09)
		f = f if up else 1.0 / f
		sym = sec
		moods[sec] = float(moods.get(sec, 1.0)) * f
		for st in Data.STOCKS:
			if st[4] == sec:
				prices[st[0]] = price(st[0]) * f
		var tmpl: Array = Data.NEWS_SECTOR_UP if up else Data.NEWS_SECTOR_DOWN
		item = {"text": tmpl[randi() % tmpl.size()] % sec, "sym": sec}
	else:
		var c: Array = Data.COINS[randi() % Data.COINS.size()]
		var up := randf() < 0.5
		f = 1.0 + randf_range(0.15, 0.5)
		f = f if up else 1.0 / f
		sym = c[0]
		fair_log[sym] = float(fair_log.get(sym, log(float(c[2])))) + log(f)
		prices[sym] = price(sym) * f
		var tmpl: Array = Data.NEWS_COIN_UP if up else Data.NEWS_COIN_DOWN
		item = {"text": tmpl[randi() % tmpl.size()] % c[1], "sym": sym}
	item["pct"] = (f - 1.0) * 100.0
	item["t"] = _tick_t if _tick_t >= 0.0 else now()
	news.append(item)
	while news.size() > NEWS_MAX:
		news.pop_front()
	_bump("news_total")
	if not _quiet:
		market_news.emit(item)


func news_for(sym: String) -> Array:
	var out: Array = []
	var sec := sector_of(sym)
	for i in range(news.size() - 1, -1, -1):
		if news[i]["sym"] == sym or (sec != "" and news[i]["sym"] == sec):
			out.append(news[i])
	return out


func _init_market() -> void:
	for s in Data.STOCKS:
		if not prices.has(s[0]):
			prices[s[0]] = float(s[2])
	for c in Data.COINS:
		if not prices.has(c[0]):
			prices[c[0]] = float(c[2])
	if price_hist.is_empty() or hist_h.is_empty():
		# Give a new market a week of believable history.
		var saved := prices.duplicate()
		_catch_up(HIST_H * 4, now() - 7200.0)
		_quiet = true
		for i in 120:
			_bump("market_ticks")
			_market_tick()
			_record_prices(1)
		_quiet = false
		news.clear()
		_end_on(saved)


func _end_on(saved: Dictionary) -> void:
	## After building history for an older save, keep the prices the player
	## saw: scale each history so it ends on the saved price.
	var ticks := float(counters.get("market_ticks", 0))
	for sym in saved.keys():
		var want := float(saved[sym])
		var now_p := price(sym)
		if want <= 0.0 or now_p <= 0.0 or not prices.has(sym):
			continue
		var f := want / now_p
		for store in [price_hist, hist_q, hist_h]:
			var h: Array = store.get(sym, [])
			for i in range(h.size()):
				h[i] = _sig(float(h[i]) * f)
		prices[sym] = want
		var st := _stock(sym)
		if not st.is_empty():
			moods[sym] = clampf(want / (float(st[2]) * exp(Data.STOCK_GROWTH * ticks) * float(moods.get(st[4], 1.0))), 0.2, 5.0)
		elif not _coin(sym).is_empty():
			fair_log[sym] = log(want)


# ==== property ============================================================

func prop_owned(i: int) -> bool:
	return props.has(str(i))


func prop_price(i: int) -> float:
	return float(Data.PROPERTIES[i][2])


func prop_rent(i: int) -> float:
	if not prop_owned(i):
		return 0.0
	var extra := 0.0
	var imps: Array = props[str(i)]["imps"]
	for k in range(imps.size()):
		if imps[k]:
			extra += float(Data.IMPROVEMENTS[k][2])
	return prop_price(i) * Data.RENT_PER_H * (1.0 + extra) * global_mult()


func prop_value(i: int) -> float:
	if not prop_owned(i):
		return 0.0
	var v := prop_price(i)
	var imps: Array = props[str(i)]["imps"]
	for k in range(imps.size()):
		if imps[k]:
			v += prop_price(i) * float(Data.IMPROVEMENTS[k][1])
	return v


func buy_property(i: int) -> bool:
	if prop_owned(i) or cash < prop_price(i):
		return false
	cash -= prop_price(i)
	props[str(i)] = {"imps": [false, false, false, false, false]}
	GameLog.info("invest", "Bought property %d (%s)" % [i, Data.PROPERTIES[i][0]])
	_task_progress("invest", 1)
	recalc()
	return true


func improve_property(i: int, k: int) -> bool:
	if not prop_owned(i):
		return false
	var imps: Array = props[str(i)]["imps"]
	var c := prop_price(i) * float(Data.IMPROVEMENTS[k][1])
	if imps[k] or cash < c:
		return false
	cash -= c
	imps[k] = true
	recalc()
	return true


func sell_property_value(i: int) -> float:
	return prop_value(i) * (1.0 - Data.SELL_TAX)


func sell_property(i: int) -> float:
	if not prop_owned(i):
		return 0.0
	var got := sell_property_value(i)
	GameLog.info("invest", "Sold property %d for %s" % [i, money(got)])
	cash += got
	props.erase(str(i))
	recalc()
	return got


func props_owned() -> int:
	return props.size()


func props_value() -> float:
	var v := 0.0
	for k in props.keys():
		v += prop_value(int(k))
	return v


func rent_per_hour() -> float:
	var v := 0.0
	for k in props.keys():
		v += prop_rent(int(k))
	return v


# ==== collections =========================================================

func item_owned(col: String, i: int) -> bool:
	return items.has("%s:%d" % [col, i])


func collection(col: String) -> Dictionary:
	for c in Data.COLLECTIONS:
		if c["id"] == col:
			return c
	return {}


func collection_count(col: String) -> int:
	var n := 0
	for i in range(collection(col)["items"].size()):
		if item_owned(col, i):
			n += 1
	return n


func collection_done(col: String) -> bool:
	return collection_count(col) == collection(col)["items"].size()


func buy_item(col: String, i: int) -> bool:
	var p: float = collection(col)["items"][i][1]
	if item_owned(col, i) or cash < p:
		return false
	cash -= p
	items["%s:%d" % [col, i]] = true
	recalc()
	return true


func sell_item(col: String, i: int) -> float:
	if not item_owned(col, i):
		return 0.0
	var got: float = float(collection(col)["items"][i][1]) * Data.ITEM_RESALE
	items.erase("%s:%d" % [col, i])
	cash += got
	recalc()
	return got


# ==== bulk actions ===========================================================

func fill_all() -> int:
	## Buys outlets across all companies, cheapest first, until the money or
	## the space runs out. Returns how many were bought.
	var n := 0
	while n < 1000:
		var best := ""
		var best_p := INF
		for id in biz.keys():
			if int(biz[id]["units"]) < capacity(id) and unit_price(id) < best_p:
				best = id
				best_p = unit_price(id)
		if best == "" or not buy_unit(best):
			break
		n += 1
	return n


func fill_all_cost() -> float:
	## What the single cheapest next outlet costs (0 if every company is full).
	var best := INF
	for id in biz.keys():
		if int(biz[id]["units"]) < capacity(id):
			best = minf(best, unit_price(id))
	return 0.0 if best == INF else best


func expandable() -> Array:
	## Full companies whose next expansion you can start right now.
	var out: Array = []
	for id in biz.keys():
		if int(biz[id]["units"]) >= capacity(id) and can_expand(id):
			out.append(id)
	return out


func expand_all() -> int:
	var n := 0
	var ids := expandable()
	ids.sort_custom(func(a, b): return expansion_cost(a) < expansion_cost(b))
	for id in ids:
		if start_expansion(id):
			n += 1
	return n


func next_achievement() -> Dictionary:
	## The locked achievement you're closest to, with how far along you are.
	var best := {}
	var best_p := -1.0
	for a in _achievements:
		if achieved.has(a["id"]):
			continue
		var p := clampf(metric(a["m"]) / float(a["goal"]), 0.0, 0.999)
		if p > best_p:
			best_p = p
			best = a
	if best.is_empty():
		return {}
	return {"title": best["title"], "progress": best_p}


# ==== waiting time ===========================================================

func eta(cost: float) -> String:
	## Roughly how long until you can afford something from income alone.
	## Empty if you can already afford it or have no income yet.
	var need := cost - cash
	if need <= 0.0 or income_per_hour <= 0.0:
		return ""
	var s := need / income_per_hour * 3600.0
	if s < 60.0:
		return "under a minute"
	if s < 3600.0:
		return "~%d min" % int(ceil(s / 60.0))
	if s < 48.0 * 3600.0:
		return "~%d h" % int(ceil(s / 3600.0))
	return "~%d days" % int(ceil(s / 86400.0))


# ==== tab dots ===============================================================

func tab_badges() -> Array:
	## Which tabs have something worth a look right now (shown as red dots).
	var earn := level < Data.MAX_LEVEL and can_level_up()
	var business := false
	for id in biz.keys():
		if int(biz[id]["units"]) >= capacity(id) and can_expand(id):
			business = true
	for b in Data.BUSINESSES:
		if not biz.has(b["id"]) and cash >= float(b["cost"]):
			business = true
			break
	for m in Data.MERGERS:
		if not mergers.has(m["id"]) and merger_ready(m) and cash >= float(m["cost"]):
			business = true
	var invest := false
	for sym in coins.keys():
		if staked(sym) > 0.0 and stake_left(sym) <= 0.0:
			invest = true
	var items := next_home_cost() > 0.0 and cash >= next_home_cost()
	return [earn, business, invest, items]


# ==== next goal =============================================================

func next_goal() -> Dictionary:
	## The cheapest next big step, shown on the Earn screen so there's always
	## something to save for. tab: which tab opens when tapped.
	var c: Array = []
	for b in Data.BUSINESSES:
		if not biz.has(b["id"]):
			c.append({"icon": "business", "text": String(b["name"]), "cost": float(b["cost"]), "tab": 1})
			break
	for id in biz.keys():
		if int(biz[id]["units"]) < capacity(id):
			c.append({"icon": "business", "text": "+1 outlet · %s" % biz[id]["name"], "cost": unit_price(id), "tab": 1})
	if next_home_cost() > 0.0:
		c.append({"icon": "home", "text": String(Data.HOMES[home + 1][0]), "cost": next_home_cost(), "tab": 3})
	for i in range(Data.PROPERTIES.size()):
		if not prop_owned(i):
			c.append({"icon": "invest", "text": String(Data.PROPERTIES[i][0]), "cost": prop_price(i), "tab": 2})
	for m in Data.MERGERS:
		if mergers.has(m["id"]):
			continue
		if merger_ready(m):
			c.append({"icon": "pie", "text": String(m["name"]), "cost": float(m["cost"]), "tab": 1})
			continue
		# Not ready: show the next thing it needs that money can buy.
		for n in m["needs"]:
			var st := need_status(n)
			if st[0]:
				continue
			if n[0] == "shares" or n[0] == "crypto":
				var have := book_value(shares if n[0] == "shares" else coins)
				c.append({"icon": "invest", "text": "%s for %s" % [st[1], m["name"]], "cost": float(n[1]) - have, "tab": 2})
			break
		break
	if c.is_empty():
		return {}
	# Skip small stuff: a goal should be worth saving for.
	var big: Array = c.filter(func(g): return float(g["cost"]) >= cash * 0.1)
	if not big.is_empty():
		c = big
	var best: Dictionary = c[0]
	for g in c:
		if float(g["cost"]) < float(best["cost"]):
			best = g
	return best


# ==== home ================================================================

func home_value() -> float:
	return float(Data.HOMES[home][2])


func next_home_cost() -> float:
	return float(Data.HOMES[home + 1][2]) if home + 1 < Data.HOMES.size() else -1.0


func move_home() -> bool:
	## Moves one step up the ladder. The old home isn't sold: you keep it.
	var c := next_home_cost()
	if c < 0.0 or cash < c:
		return false
	cash -= c
	home += 1
	GameLog.info("game", "Moved to %s" % Data.HOMES[home][0])
	recalc()
	return true


func items_value() -> float:
	var v := 0.0
	for k in items.keys():
		var parts: PackedStringArray = k.split(":")
		v += float(collection(parts[0])["items"][int(parts[1])][1])
	return v


# ==== mergers =============================================================

func need_status(n: Array) -> Array:
	## Returns [done: bool, label: String, have: String, progress: float].
	match n[0]:
		"biz":
			var b := Data.business(n[1])
			var st := int(biz[n[1]]["stage"]) if biz.has(n[1]) else 0
			return [st >= int(n[2]), "%s at stage %d" % [b["name"], n[2]], "stage %d" % st if st > 0 else "not owned", clampf(float(st) / float(n[2]), 0, 1)]
		"props":
			return [props_owned() >= int(n[1]), "Own %d properties" % n[1], "%d" % props_owned(), clampf(float(props_owned()) / float(n[1]), 0, 1)]
		"shares":
			var v := book_value(shares)
			return [v >= float(n[1]), "Shares worth %s" % money_short(n[1]), money_short(v), clampf(v / float(n[1]), 0, 1)]
		"crypto":
			var v := book_value(coins)
			return [v >= float(n[1]), "Crypto worth %s" % money_short(n[1]), money_short(v), clampf(v / float(n[1]), 0, 1)]
		"collection":
			var c := collection(n[1])
			var k := collection_count(n[1])
			return [collection_done(n[1]), "Complete %s" % c["name"], "%d of %d" % [k, c["items"].size()], float(k) / float(c["items"].size())]
		"mergers":
			return [mergers.size() >= int(n[1]), "%d other mergers" % n[1], "%d" % mergers.size(), clampf(float(mergers.size()) / float(n[1]), 0, 1)]
	return [false, "?", "", 0.0]


func merger_ready(m: Dictionary) -> bool:
	for n in m["needs"]:
		if not need_status(n)[0]:
			return false
	return true


func merge(id: String) -> bool:
	for m in Data.MERGERS:
		if m["id"] == id:
			if mergers.has(id) or not merger_ready(m) or cash < float(m["cost"]):
				return false
			cash -= float(m["cost"])
			mergers[id] = true
			GameLog.info("game", "Merger done: %s" % id)
			recalc()
			return true
	return false


# ==== totals ==============================================================

func business_value() -> float:
	var v := 0.0
	for id in biz.keys():
		v += biz_value(id)
	return v


func net_worth() -> float:
	return cash + business_value() + book_value(shares) + book_value(coins) + props_value() + items_value() + home_value()


func business_per_hour() -> float:
	return float(_income_parts.get("biz", 0.0))


func recalc() -> void:
	var b := 0.0
	for id in biz.keys():
		b += biz_income(id)
	var d := dividends_per_hour()
	var r := rent_per_hour()
	_income_parts = {"biz": b, "div": d, "rent": r}
	income_per_hour = b + d + r
	_mark()


# ==== completion ==========================================================

func completion() -> float:
	## 0..1 share of the game finished.
	var bz := 0.0
	for b in Data.BUSINESSES:
		if biz.has(b["id"]):
			var s: Dictionary = biz[b["id"]]
			bz += 0.5 * float(s["stage"]) / Data.MAX_STAGE + 0.5 * float(s["units"]) / float(Data.MAX_STAGE * Data.UNITS_PER_STAGE)
	bz /= Data.BUSINESSES.size()
	var mg := float(mergers.size()) / Data.MERGERS.size()
	var pr := float(props.size()) / Data.PROPERTIES.size()
	var total_items := 0
	for c in Data.COLLECTIONS:
		total_items += c["items"].size()
	var it := float(items.size()) / float(total_items)
	var ac := float(achieved.size()) / float(maxi(1, _achievements.size()))
	var lv := float(level - 1) / float(Data.MAX_LEVEL - 1)
	var hm := float(home) / float(Data.HOMES.size() - 1)
	return 0.36 * bz + 0.15 * mg + 0.15 * pr + 0.15 * it + 0.10 * ac + 0.04 * lv + 0.05 * hm


# ==== achievements ========================================================

func _build_achievements() -> Array:
	var a: Array = []
	for t in [100, 1000, 10000, 50000]:
		a.append({"id": "taps_%d" % t, "title": "%s taps" % group(t), "m": "taps", "goal": float(t)})
	for e in range(4, 13):
		var g := pow(10.0, e)
		a.append({"id": "worth_%d" % e, "title": "Worth %s" % money_short(g), "m": "worth", "goal": g})
	for n in [1, 3, 6, 11]:
		a.append({"id": "biz_%d" % n, "title": "%d compan%s" % [n, "y" if n == 1 else "ies"], "m": "biz", "goal": float(n)})
	for n in [10, 30, 60, 99]:
		a.append({"id": "stages_%d" % n, "title": "%d expansions" % n, "m": "expansions", "goal": float(n)})
	for n in [1, 5, 10, 20]:
		a.append({"id": "props_%d" % n, "title": "%d propert%s" % [n, "y" if n == 1 else "ies"], "m": "props", "goal": float(n)})
	for e in [4, 7, 10]:
		a.append({"id": "shares_%d" % e, "title": "Shares worth %s" % money_short(pow(10.0, e)), "m": "shares", "goal": pow(10.0, e)})
	for e in [3, 6, 9]:
		a.append({"id": "crypto_%d" % e, "title": "%s crypto profit" % money_short(pow(10.0, e)), "m": "crypto_profit", "goal": pow(10.0, e)})
	for e in [3, 6, 9]:
		a.append({"id": "div_%d" % e, "title": "%s in dividends" % money_short(pow(10.0, e)), "m": "dividends", "goal": pow(10.0, e)})
	for e in [3, 6]:
		a.append({"id": "stake_%d" % e, "title": "%s from staking" % money_short(pow(10.0, e)), "m": "stake_earned", "goal": pow(10.0, e)})
	for n in [1, 3, 6]:
		a.append({"id": "cols_%d" % n, "title": "%d collection%s done" % [n, "" if n == 1 else "s"], "m": "collections", "goal": float(n)})
	for n in [1, 10, 25]:
		a.append({"id": "deals_%d" % n, "title": "%d deal%s" % [n, "" if n == 1 else "s"], "m": "deals", "goal": float(n)})
	for n in [1, 5, 11]:
		a.append({"id": "managers_%d" % n, "title": "%d manager%s" % [n, "" if n == 1 else "s"], "m": "managers", "goal": float(n)})
	for n in [1, 5, 10]:
		a.append({"id": "rivals_%d" % n, "title": "Beat %d rival%s" % [n, "" if n == 1 else "s"], "m": "rivals", "goal": float(n)})
	for n in [10, 50]:
		a.append({"id": "goals_%d" % n, "title": "%d goals done" % n, "m": "goals", "goal": float(n)})
	for n in [1, 4, 8]:
		a.append({"id": "home_%d" % n, "title": Data.HOMES[n][0], "m": "home", "goal": float(n)})
	for n in [1, 3, 6]:
		a.append({"id": "merge_%d" % n, "title": "%d merger%s" % [n, "" if n == 1 else "s"], "m": "mergers", "goal": float(n)})
	for n in [5, 10, 20, 25]:
		a.append({"id": "level_%d" % n, "title": "Level %d" % n, "m": "level", "goal": float(n)})
	for n in [10, 100]:
		a.append({"id": "boosts_%d" % n, "title": "%d boosts" % n, "m": "boosts", "goal": float(n)})
	return a


func achievements() -> Array:
	return _achievements


func metric(m: String) -> float:
	match m:
		"taps": return float(taps)
		"worth": return net_worth()
		"biz": return float(biz.size())
		"expansions": return float(counters.get("expansions", 0))
		"props": return float(props.size())
		"shares": return book_value(shares)
		"crypto_profit": return float(counters.get("crypto_profit", 0.0))
		"dividends": return float(counters.get("dividends_earned", 0.0))
		"stake_earned": return float(counters.get("stake_earned", 0.0))
		"collections":
			var n := 0
			for c in Data.COLLECTIONS:
				if collection_done(c["id"]):
					n += 1
			return float(n)
		"mergers": return float(mergers.size())
		"home": return float(home)
		"deals": return float(counters.get("deals", 0))
		"rivals": return float(rivals_beaten())
		"goals": return float(counters.get("goals_done", 0))
		"managers":
			var n := 0
			for id in biz.keys():
				if has_manager(id):
					n += 1
			return float(n)
		"level": return float(level)
		"boosts": return float(boosts_used)
	return 0.0


func _check_achievements() -> void:
	for a in _achievements:
		if achieved.has(a["id"]):
			continue
		if metric(a["m"]) >= float(a["goal"]):
			achieved[a["id"]] = true
			GameLog.info("game", "Achievement: %s" % a["title"])
			var reward := maxf(500.0, income_per_hour * 1.0)
			_earn(reward)
			achievement.emit(a["title"], reward)


# ==== daily tasks =========================================================

func _today() -> int:
	return int(now() / 86400.0)


func _check_streak() -> void:
	## Coming back on consecutive days builds a streak with a small gift.
	var today := _today()
	if streak_day == today:
		return
	streak = streak + 1 if streak_day == today - 1 else 1
	streak_day = today
	var gift := maxf(250.0, income_per_hour * 0.15 * float(mini(streak, 7)))
	_pay(gift)
	streak_unseen = [streak, gift]
	streak_gift.emit(streak, gift)


func _ensure_daily() -> void:
	_check_streak()
	if int(daily.get("day", -1)) == _today():
		return
	var pool := [
		{"id": "taps", "text": "Tap your tower %d times", "goal": 200},
		{"id": "invest", "text": "Make %d investments", "goal": 3},
	]
	if _units_left() >= 5:
		pool.append({"id": "units", "text": "Buy %d units for your companies", "goal": 5})
	if _can_still_expand():
		pool.append({"id": "expand", "text": "Finish %d expansion", "goal": 1})
	if biz.is_empty():
		pool = [{"id": "taps", "text": "Tap your tower %d times", "goal": 400}]
	pool.shuffle()
	var tasks: Array = []
	for i in range(mini(3, pool.size())):
		var t: Dictionary = pool[i]
		tasks.append({"id": t["id"], "text": t["text"] % t["goal"], "goal": t["goal"], "progress": 0, "done": false})
	daily = {"day": _today(), "tasks": tasks}


func daily_tasks() -> Array:
	_ensure_daily()
	_ensure_weekly()
	return daily["tasks"]


func daily_reward() -> float:
	return maxf(1000.0, income_per_hour * 1.5)


func _task_progress(id: String, n: float) -> void:
	_advance(daily, id, n, "daily")
	_advance(weekly, id, n, "weekly")


func _advance(book: Dictionary, id: String, n: float, scope: String) -> void:
	if book.is_empty():
		return
	for t in book.get("tasks", []):
		if t["id"] == id and not t["done"]:
			t["progress"] = float(t["progress"]) + n
			if float(t["progress"]) >= float(t["goal"]):
				t["done"] = true
				var r := daily_reward() if scope == "daily" else weekly_reward()
				_pay(r)
				_bump("goals_done")
				goal_done.emit(scope, String(t["text"]), r)


func _units_left() -> int:
	## Units that could still be bought, counting future stages.
	var n := 0
	for id in biz.keys():
		n += Data.MAX_STAGE * Data.UNITS_PER_STAGE - int(biz[id]["units"])
	return n


func _can_still_expand() -> bool:
	for id in biz.keys():
		if int(biz[id]["stage"]) < Data.MAX_STAGE:
			return true
	return false


func _week() -> int:
	## Weeks start on Monday (1 Jan 1970 was a Thursday).
	return int(floor((now() / 86400.0 + 3.0) / 7.0))


func _ensure_weekly() -> void:
	if int(weekly.get("week", -1)) == _week():
		return
	var earn_goal := maxf(50000.0, income_per_hour * 30.0)
	var pool := [
		{"id": "taps", "text": "Tap your tower %s times" % group(1200), "goal": 1200.0},
		{"id": "invest", "text": "Make 10 investments", "goal": 10.0},
		{"id": "earn", "text": "Earn %s" % money_short(earn_goal), "goal": earn_goal, "money": true},
	]
	if _units_left() >= 30:
		pool.append({"id": "units", "text": "Buy 30 units for your companies", "goal": 30.0})
	if _can_still_expand():
		pool.append({"id": "expand", "text": "Finish 3 expansions", "goal": 3.0})
	pool.shuffle()
	var tasks: Array = []
	for i in 3:
		var t: Dictionary = pool[i]
		tasks.append({"id": t["id"], "text": t["text"], "goal": t["goal"], "progress": 0.0, "done": false, "money": t.get("money", false)})
	weekly = {"week": _week(), "tasks": tasks}


func weekly_tasks() -> Array:
	_ensure_weekly()
	return weekly["tasks"]


func weekly_reward() -> float:
	return maxf(5000.0, income_per_hour * 3.0)


func week_left() -> float:
	return float(_week() + 1) * 7.0 * 86400.0 - 3.0 * 86400.0 - now()


func goals_open() -> int:
	var n := 0
	for t in daily_tasks() + weekly_tasks():
		if not t["done"]:
			n += 1
	return n


# ==== time ===============================================================

func _earn(v: float) -> void:
	cash += v
	total_earned += v
	if v > 0.0:
		_advance(weekly, "earn", v, "weekly")
	_mark()


func _pay(v: float) -> void:
	## Rewards: count as earnings but not towards the "earn" goal.
	cash += v
	total_earned += v
	_mark()


func _bump(name: String, by := 1.0) -> void:
	counters[name] = float(counters.get(name, 0.0)) + by


func _mark() -> void:
	## Changes are batched and announced at most 10 times a second.
	_dirty = true
	_change_pending = true


func flush_changes() -> void:
	_change_pending = false
	_change_timer = 0.0
	changed.emit()


func advance(dt: float, earn_income := true) -> void:
	## Moves the game forward. Used each frame and by the simulator.
	if not (dt > 0.0):
		return  # clock went backwards (or NaN): never undo progress
	_pay_out()
	if earn_income:
		_managers_work()
		if income_per_hour > 0.0:
			_earn(income_per_hour * dt / 3600.0)
		_accrue(dt)
	_market_timer += dt
	var minutes := int(_market_timer / MARKET_TICK_S)
	_market_timer = fmod(_market_timer, MARKET_TICK_S)
	if minutes > 0:
		# Long gaps (time away) move in 15-minute steps, at most a week's worth.
		var recent := mini(minutes, 120)
		var quarters := mini((minutes - recent) / 15, HIST_H * 4)
		if quarters > 0:
			_catch_up(quarters, now() - float(recent) * 60.0)
		for i in recent:
			_bump("market_ticks")
			_market_tick()
			_record_prices(1)
		recalc()
	_finish_expansions()
	if ibost_until > 0.0 and now() >= ibost_until and _income_parts.get("ib", false):
		pass
	_hist_timer += dt
	if _hist_timer >= HISTORY_EVERY_S:
		_hist_timer = 0.0
		_record_history()


func _process(delta: float) -> void:
	if sim_time >= 0.0:
		return
	_change_timer += delta
	if _change_pending and _change_timer >= CHANGE_EVERY_S:
		flush_changes()
	var was_boosting := ibost_active()
	advance(delta)
	tick_deals(delta)
	if was_boosting != ibost_active():
		recalc()
	_check_timer += delta
	if _check_timer >= 1.0:
		_check_timer = 0.0
		_ensure_daily()
		_ensure_weekly()
		_check_achievements()
		_check_rivals()
	_save_timer += delta
	if _save_timer >= 5.0:
		_save_timer = 0.0
		if _dirty:
			save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_paused_at = now()
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0.0:
				apply_offline(now() - _paused_at)
				_paused_at = 0.0
				flush_changes()


func apply_offline(seconds: float) -> void:
	## Income is capped at 8 hours; timers and markets run for real.
	var s := maxf(0.0, seconds)
	var capped := minf(s, Data.OFFLINE_CAP_H * 3600.0)
	var before := cash
	var ib_part := 0.0
	if ibost_until > 0.0:
		var start := now() - s
		ib_part = clampf(ibost_until - start, 0.0, capped)
	# Work out income without the x2 boost, then add the boosted hours back.
	var keep_ib := ibost_until
	ibost_until = 0.0
	recalc()
	var base := income_per_hour
	var biz_base := business_per_hour()
	ibost_until = keep_ib
	var gained := base * capped / 3600.0 + biz_base * ib_part / 3600.0
	var exp0 := int(counters.get("expansions", 0))
	var pay0 := payouts.size()
	advance(s, false)
	recalc()
	_earn(gained)
	_accrue(capped)
	away_earned = cash - before
	away_seconds = s
	away_notes = []
	var done := int(counters.get("expansions", 0)) - exp0
	if done > 0:
		away_notes.append("%d expansion%s finished" % [done, "" if done == 1 else "s"])
	if pay0 > payouts.size():
		away_notes.append("Rush orders paid out")
	if s > Data.OFFLINE_CAP_H * 3600.0:
		away_notes.append("Earnings stop after %d h away" % int(Data.OFFLINE_CAP_H))
	away_unseen = s >= 600.0 and away_earned > 0.0
	_managers_work()
	if s > 60.0:
		GameLog.info("game", "Away for %s, earned %s (income %s/h)" % [clock(s), money(away_earned), money(income_per_hour)])
	_ensure_daily()
	_ensure_weekly()
	_check_achievements()


func _accrue(dt: float) -> void:
	## Dividends earned so far and staking rewards (paid in coins).
	counters["dividends_earned"] = float(counters.get("dividends_earned", 0.0)) + dividends_per_hour() * dt / 3600.0
	for sym in coins.keys():
		var st := staked(sym)
		if st > 0.0:
			var per_h := st * stake_rate(sym)
			var p := price(sym)
			if p > 0.0:
				per_h = minf(per_h, maxf(income_per_hour, 1000.0) * Data.STAKE_CAP / p)
			var gain := per_h * dt / 3600.0
			coins[sym]["staked"] = st + gain
			counters["stake_earned"] = float(counters.get("stake_earned", 0.0)) + gain * price(sym)


func _record_history() -> void:
	history.append([now(), net_worth()])
	while history.size() > HISTORY_MAX:
		history.pop_front()


func week_change() -> Array:
	if history.size() < 2:
		return []
	var cutoff := now() - WEEK_S
	var start_value: float = history[0][1]
	for p in history:
		if p[0] >= cutoff:
			start_value = p[1]
			break
	return [start_value, net_worth()]


# ==== saving ==============================================================

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION, "saved_at": now(),
		"cash": cash, "total_earned": total_earned, "level": level, "taps": taps,
		"boost_until": boost_until, "boost_ready_at": boost_ready_at, "boosts_used": boosts_used,
		"ibost_until": ibost_until, "ibost_ready_at": ibost_ready_at,
		"biz": biz, "shares": shares, "coins": coins, "prices": prices, "price_hist": price_hist,
		"hist_q": hist_q, "hist_h": hist_h, "moods": moods, "trends": trends, "fair_log": fair_log, "news": news,
		"props": props, "items": items, "mergers": mergers, "achieved": achieved, "home": home,
		"counters": counters, "daily": daily, "weekly": weekly, "history": history,
		"deal_wait": deal_wait, "payouts": payouts, "deal": deal,
		"ui": ui, "streak": streak, "streak_day": streak_day,
		"vibrate": vibrate, "reduce_motion": reduce_motion, "started_at": started_at,
	}


func save_game() -> void:
	if sim_time >= 0.0:
		return
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		GameLog.error("save", "Could not write save: error %d" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	var tmp := ProjectSettings.globalize_path(SAVE_TMP)
	var main := ProjectSettings.globalize_path(SAVE_PATH)
	var bak := ProjectSettings.globalize_path(SAVE_BAK)
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BAK):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(main, bak)
	DirAccess.rename_absolute(tmp, main)
	if not FileAccess.file_exists(SAVE_PATH):
		GameLog.error("save", "Save file missing after write")
	_dirty = false


# ==== backup code ===========================================================
# The whole save as one short text code, so progress survives a reinstall.
# Price charts and news are left out; they rebuild on restore.

const BACKUP_PREFIX := "SOL1:"


func backup_code() -> String:
	var d := to_dict()
	for k in ["price_hist", "hist_q", "hist_h", "news"]:
		d.erase(k)
	var raw := JSON.stringify(d).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	return BACKUP_PREFIX + str(raw.size()) + ":" + Marshalls.raw_to_base64(packed)


func restore_code(text: String) -> bool:
	## Checks the code fully before touching the current save.
	text = text.strip_edges().replace("\n", "").replace(" ", "")
	if not text.begins_with(BACKUP_PREFIX):
		return false
	var parts := text.substr(BACKUP_PREFIX.length()).split(":", false, 1)
	if parts.size() != 2 or not parts[0].is_valid_int():
		return false
	var n := int(parts[0])
	if n <= 0 or n > 5000000:
		return false
	var packed := Marshalls.base64_to_raw(parts[1])
	if packed.is_empty():
		return false
	var raw := packed.decompress(n, FileAccess.COMPRESSION_GZIP)
	if raw.size() != n:
		return false
	var d = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or not d.has("version") or not d.has("cash"):
		return false
	if int(d["version"]) > SAVE_VERSION:
		return false  # made by a newer version of the game
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		return false
	d["saved_at"] = now()  # no time passes on restore, so it can't re-roll the market
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BAK):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_BAK))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(SAVE_BAK))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_TMP), ProjectSettings.globalize_path(SAVE_PATH))
	load_game()
	recalc()
	GameLog.info("save", "Restored from backup code (%s)" % GameLog.bytes(n))
	changed.emit()
	return true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _migrate(d: Dictionary) -> Dictionary:
	## Upgrades older saves step by step so updates never lose progress.
	var v := int(d.get("version", 1))
	if v < 2:
		# v1 only had tapping; everything else starts empty.
		v = 2
	if v < 3:
		# v3 adds day and week price history; rebuild it from the current prices.
		d["price_hist"] = {}
		v = 3
	if v < 4:
		# v4 adds homes; everyone starts in the rented room.
		d["home"] = int(d.get("home", 0))
		v = 4
	if v < 5:
		# v5 adds goals for the week, deals, managers and rivals. Rivals already
		# passed count as beaten without a pop-up (set after loading).
		v = 5
	if v < 6:
		# v6 adds the daily streak and remembered screen choices (defaults are fine).
		v = 6
	d["version"] = v
	return d


func _reset_state() -> void:
	home = 0
	cash = 0.0
	total_earned = 0.0
	level = 1
	taps = 0
	boost_until = 0.0
	boost_ready_at = 0.0
	boosts_used = 0
	ibost_until = 0.0
	ibost_ready_at = 0.0
	biz = {}
	shares = {}
	coins = {}
	prices = {}
	price_hist = {}
	hist_q = {}
	hist_h = {}
	moods = {}
	trends = {}
	fair_log = {}
	news = []
	props = {}
	items = {}
	mergers = {}
	achieved = {}
	counters = {}
	daily = {}
	weekly = {}
	deal = {}
	ui = {}
	streak = 0
	streak_day = -1
	deal_wait = 1500.0
	payouts = []
	history = []
	away_earned = 0.0
	started_at = now()


func load_game() -> void:
	_reset_state()
	var d := _read_save(SAVE_PATH)
	if d.is_empty() and FileAccess.file_exists(SAVE_PATH):
		GameLog.warn("save", "Main save unreadable, trying backup")
	if d.is_empty():
		d = _read_save(SAVE_BAK)
	if d.is_empty():
		GameLog.info("save", "No save found, new game")
		_init_market()
		recalc()
		_record_history()
		return
	d = _migrate(d)
	GameLog.info("save", "Loaded save v%d (%s)" % [int(d.get("version", 1)), GameLog.bytes(GameLog.file_size(SAVE_PATH))])
	cash = float(d.get("cash", 0.0))
	total_earned = float(d.get("total_earned", 0.0))
	level = int(d.get("level", 1))
	taps = int(d.get("taps", 0))
	boost_until = float(d.get("boost_until", 0.0))
	boost_ready_at = float(d.get("boost_ready_at", 0.0))
	boosts_used = int(d.get("boosts_used", 0))
	ibost_until = float(d.get("ibost_until", 0.0))
	ibost_ready_at = float(d.get("ibost_ready_at", 0.0))
	biz = d.get("biz", {})
	shares = d.get("shares", {})
	coins = d.get("coins", {})
	prices = d.get("prices", {})
	price_hist = d.get("price_hist", {})
	hist_q = d.get("hist_q", {})
	hist_h = d.get("hist_h", {})
	moods = d.get("moods", {})
	trends = d.get("trends", {})
	fair_log = d.get("fair_log", {})
	news = d.get("news", [])
	props = d.get("props", {})
	items = d.get("items", {})
	home = clampi(int(d.get("home", 0)), 0, Data.HOMES.size() - 1)
	mergers = d.get("mergers", {})
	achieved = d.get("achieved", {})
	counters = d.get("counters", {})
	daily = d.get("daily", {})
	weekly = d.get("weekly", {})
	deal_wait = float(d.get("deal_wait", 1500.0))
	deal = d.get("deal", {})
	ui = d.get("ui", {})
	streak = int(d.get("streak", 0))
	streak_day = int(d.get("streak_day", -1))
	payouts = d.get("payouts", [])
	history = d.get("history", [])
	vibrate = bool(d.get("vibrate", true))
	reduce_motion = bool(d.get("reduce_motion", false))
	started_at = float(d.get("started_at", now()))
	_init_market()
	recalc()
	apply_offline(now() - float(d.get("saved_at", now())))
	if history.is_empty():
		_record_history()
	if not counters.has("rivals"):
		counters["rivals"] = float(rivals_beaten())


func reset_game() -> void:
	GameLog.info("game", "Progress reset")
	_reset_state()
	_init_market()
	recalc()
	_record_history()
	save_game()
	flush_changes()


# ==== number formatting ===================================================

static func group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


const BIG_UNITS := [[1e33, "Dc"], [1e30, "No"], [1e27, "Oc"], [1e24, "Sp"], [1e21, "Sx"], [1e18, "Qi"],
	[1e15, "Q"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]


static func money(v: float) -> String:
	## $12.50 under 1,000; $19,284 up to a billion; then $1.25B and $3.40T.
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if a < 1000.0:
		return sign + "$%.2f" % a
	if a < 1e9:
		return sign + "$" + group(int(floor(a)))
	if a < 1e12:
		return sign + "$%.2fB" % (a / 1e9)
	return money_short(v)


static func money_short(v: float) -> String:
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if a < 999.5:
		return sign + ("$%d" % int(round(a)) if a >= 100.0 else "$%.2f" % a)
	# Three significant figures, no trailing zeros: $32K, $1.2M, $12.27M, $383K.
	var units := BIG_UNITS
	for u in units:
		if a >= float(u[0]) * 0.9995:
			var x: float = a / float(u[0])
			var t := "%.0f" % x if x >= 100.0 else ("%.1f" % x if x >= 10.0 else "%.2f" % x)
			if t.contains("."):
				t = t.rstrip("0").rstrip(".")
			return sign + "$" + t + String(u[1])
	return sign + "$%.2f" % a


static func clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 86400:
		return "%dd %dh" % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]

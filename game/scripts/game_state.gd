extends Node
## Global game state and rules: money, tapping, businesses, investments,
## collections, mergers, achievements, daily tasks, saving.

signal changed
signal tapped(amount: float)
signal achievement(title: String, reward: float)
signal expansion_done(biz_id: String, stage: int)

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.json.tmp"
const SAVE_BAK := "user://save.json.bak"
const SAVE_VERSION := 2
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
const MARKET_HIST := 180

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
var price_hist := {}   # sym -> Array of prices
var props := {}        # "index" -> {imps: [bool...]}
var items := {}        # "col:index" -> true
var mergers := {}      # id -> true
var achieved := {}     # id -> true
var counters := {}     # name -> number
var daily := {}        # {day, tasks: [{id, text, goal, progress, reward, done}]}
var history: Array = []
var vibrate := true
var reduce_motion := false
var started_at := 0.0
var away_earned := 0.0

# ---- runtime -------------------------------------------------------------
var sim_time := -1.0   # set by the pacing simulator
var income_per_hour := 0.0
var _income_parts := {}
var _dirty := false
var _save_timer := 0.0
var _hist_timer := 0.0
var _market_timer := 0.0
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
	return Data.tap_base(level) + income_per_hour * 0.002


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
	return v


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
	return Data.expansion_cost(Data.business(id), int(biz[id]["stage"])) if biz.has(id) else 0.0


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
	return float(book[sym]["qty"]) if book.has(sym) else 0.0


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
	var cost := float(book[sym]["cost"]) * fraction
	var got := qty * price(sym)
	cash += got
	if kind == "coin":
		_bump("crypto_profit", maxf(0.0, got - cost))
	book[sym]["qty"] = float(book[sym]["qty"]) - qty
	book[sym]["cost"] = float(book[sym]["cost"]) - cost
	if float(book[sym]["qty"]) <= 1e-9:
		book.erase(sym)
	recalc()
	return got


func book_value(book: Dictionary) -> float:
	var v := 0.0
	for sym in book.keys():
		v += float(book[sym]["qty"]) * price(sym)
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


func _market_tick() -> void:
	for s in Data.STOCKS:
		_walk(s[0], float(s[2]), 0.006, 0.00002)
	for c in Data.COINS:
		_walk(c[0], float(c[2]), float(c[3]), 0.0)


func _walk(sym: String, base: float, vol: float, drift: float) -> void:
	var p := price(sym)
	if p <= 0.0:
		p = base
	var fair := base * (1.0 + drift * float(counters.get("market_ticks", 0)))
	var pull := (log(fair) - log(p)) * 0.02
	p *= exp(pull + randfn(0.0, vol))
	prices[sym] = p
	var h: Array = price_hist.get(sym, [])
	h.append(p)
	while h.size() > MARKET_HIST:
		h.pop_front()
	price_hist[sym] = h


func _init_market() -> void:
	for s in Data.STOCKS:
		if not prices.has(s[0]):
			prices[s[0]] = float(s[2])
	for c in Data.COINS:
		if not prices.has(c[0]):
			prices[c[0]] = float(c[2])
	if price_hist.is_empty():
		for i in 60:
			_market_tick()


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
	return cash + business_value() + book_value(shares) + book_value(coins) + props_value() + items_value()


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
	return 0.40 * bz + 0.15 * mg + 0.15 * pr + 0.15 * it + 0.10 * ac + 0.05 * lv


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
	for n in [1, 3, 6]:
		a.append({"id": "cols_%d" % n, "title": "%d collection%s done" % [n, "" if n == 1 else "s"], "m": "collections", "goal": float(n)})
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
		"collections":
			var n := 0
			for c in Data.COLLECTIONS:
				if collection_done(c["id"]):
					n += 1
			return float(n)
		"mergers": return float(mergers.size())
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


func _ensure_daily() -> void:
	if int(daily.get("day", -1)) == _today():
		return
	var pool := [
		{"id": "taps", "text": "Tap your tower %d times", "goal": 300},
		{"id": "units", "text": "Buy %d units for your companies", "goal": 5},
		{"id": "expand", "text": "Finish %d expansion", "goal": 1},
		{"id": "invest", "text": "Make %d investments", "goal": 3},
	]
	if biz.is_empty():
		pool = [pool[0], {"id": "taps", "text": "Tap your tower %d times", "goal": 600}]
	pool.shuffle()
	var tasks: Array = []
	for i in range(mini(3, pool.size())):
		var t: Dictionary = pool[i]
		tasks.append({"id": t["id"], "text": t["text"] % t["goal"], "goal": t["goal"], "progress": 0, "done": false})
	daily = {"day": _today(), "tasks": tasks}


func daily_tasks() -> Array:
	_ensure_daily()
	return daily["tasks"]


func daily_reward() -> float:
	return maxf(1000.0, income_per_hour * 1.5)


func _task_progress(id: String, n: int) -> void:
	if daily.is_empty():
		return
	for t in daily.get("tasks", []):
		if t["id"] == id and not t["done"]:
			t["progress"] = int(t["progress"]) + n
			if int(t["progress"]) >= int(t["goal"]):
				t["done"] = true
				var r := daily_reward()
				_earn(r)
				achievement.emit("Daily task done", r)


# ==== time ===============================================================

func _earn(v: float) -> void:
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
	if earn_income and income_per_hour > 0.0:
		_earn(income_per_hour * dt / 3600.0)
	_market_timer += dt
	var ticks := 0
	while _market_timer >= MARKET_TICK_S and ticks < 240:
		_market_timer -= MARKET_TICK_S
		_bump("market_ticks")
		_market_tick()
		ticks += 1
	if ticks > 0:
		recalc()
	_market_timer = fmod(_market_timer, MARKET_TICK_S)
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
	if was_boosting != ibost_active():
		recalc()
	_check_timer += delta
	if _check_timer >= 1.0:
		_check_timer = 0.0
		_ensure_daily()
		_check_achievements()
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
	# Business income during the boosted part was double.
	var base := income_per_hour
	if ibost_active():
		base = income_per_hour - business_per_hour() * 0.5
	var biz_base := business_per_hour() * (0.5 if ibost_active() else 1.0)
	var gained := base * capped / 3600.0 + biz_base * ib_part / 3600.0
	advance(s, false)
	recalc()
	_earn(gained)
	away_earned = cash - before
	if s > 60.0:
		GameLog.info("game", "Away for %s, earned %s (income %s/h)" % [clock(s), money(away_earned), money(income_per_hour)])
	_ensure_daily()
	_check_achievements()


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
		"props": props, "items": items, "mergers": mergers, "achieved": achieved,
		"counters": counters, "daily": daily, "history": history,
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
	d["version"] = v
	return d


func _reset_state() -> void:
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
	props = {}
	items = {}
	mergers = {}
	achieved = {}
	counters = {}
	daily = {}
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
	props = d.get("props", {})
	items = d.get("items", {})
	mergers = d.get("mergers", {})
	achieved = d.get("achieved", {})
	counters = d.get("counters", {})
	daily = d.get("daily", {})
	history = d.get("history", [])
	vibrate = bool(d.get("vibrate", true))
	reduce_motion = bool(d.get("reduce_motion", false))
	started_at = float(d.get("started_at", now()))
	_init_market()
	recalc()
	apply_offline(now() - float(d.get("saved_at", now())))
	if history.is_empty():
		_record_history()


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
	if a < 1e15:
		return sign + "$%.2fT" % (a / 1e12)
	return sign + "$%.2fQ" % (a / 1e15)


static func money_short(v: float) -> String:
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if a < 1000.0:
		return sign + ("$%d" % int(round(a)) if a >= 100.0 else "$%.2f" % a)
	var units := [[1e15, "Q"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]
	for u in units:
		if a >= u[0]:
			var x: float = a / u[0]
			return sign + ("$%.1f%s" % [x, u[1]] if x >= 100.0 else "$%.2f%s" % [x, u[1]])
	return sign + "$%.2f" % a


static func clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 86400:
		return "%dd %dh" % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]

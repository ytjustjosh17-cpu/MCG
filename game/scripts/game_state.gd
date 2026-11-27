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
signal golden_sun
signal expansion_done(biz_id: String, stage: int)
signal market_news(item: Dictionary)
signal dividends_paid(amount: float)
signal auto_tapped(count: int, amount: float)

const SAVE_PATH := "user://save.json"
const SAVE_TMP := "user://save.json.tmp"
const SAVE_BAK := "user://save.json.bak"
const SAVE_VERSION := 17
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
const NEWS_MAX := 120  # about 2 days of headlines

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
var coin_shift := {}   # coin -> lasting news effect on its long-run price (log)
var trends := {}       # coin -> current trend per minute
var fair_log := {}     # coin -> log of fair price
var news: Array = []   # newest last: {t, text, sym, pct}
var home := 0         # index into Data.HOMES
var props := {}        # "index" -> {imps: [bool...]}
var items := {}        # "col:index" -> true
var mergers := {}      # id -> true
var synergies := {}    # id -> true (v8)
var miners := {"n": 0, "hash": 0.0}   # all your miners and the cash paid for them (v10)
var mine_target := ""  # the one coin every miner digs up (v10); change it any time
var upgrades := {}     # head office upgrades bought: id -> true (v11)
var auto_level := 0    # auto clicker level, 0 = none (v16)
var bank := {"saved": 0.0, "loan": {}}   # savings, and the loan if any (v17)
var _auto_acc := 0.0
var rewards: Array = []  # earned but not yet claimed: {key, kind, title, amount} (v12)
var rebirth := {"count": 0, "earned": 0, "nodes": {}}   # RBP earned in total, tree nodes owned (v13)
var _rb_cache := {}      # stat -> summed tree effect; cleared when the tree changes
var casino := {"open": false, "chips": 0.0}   # unlocked?, chips at the cage (v14)
var mine_eff := {}     # coin -> mining speed from news, 1.0 = normal (v9)
var achieved := {}     # id -> true
var counters := {}     # name -> number
var daily := {}        # {day, tasks: [{id, text, goal, progress, reward, done}]}
var weekly := {}       # {week, tasks: [...]}, same shape as daily
var deal := {}         # the offer waiting for an answer, if any
var deal_wait := 1500.0  # seconds of play until the next deal
var div_hour := -1         # last whole clock hour dividends were paid for (v15)
var last_dividend := 0.0
var _in_offline := false   # dividends paid while away go in the welcome-back note, not a toast
var payouts: Array = []  # [{amount, at}] money owed later by a deal
var history: Array = []
var vibrate := true
var reduce_motion := false
var started_at := 0.0
var away_earned := 0.0
var away_seconds := 0.0
var away_unseen := false  # show the welcome-back card once
var last_tap_at := 0.0
var tap_cap := true  # tests switch this off to tap in bulk
var _tap_tokens := 7.0
var _tap_heat := 0.0      # paid taps, cooling 2 a second: long non-stop tapping tires
var _heat_ms := 0
var _tap_ms := 0
var away_notes: Array = []
var ui := {}          # remembered screen choices (tabs, chart range)
var streak := 0       # days in a row the game was opened
var streak_day := -1
var streak_unseen: Array = []  # [days, gift] to show once
var streak_lost := 0  # length of a streak that just ended (for the message)
var sun_wait := 900.0   # seconds of play until the next golden sun
var sun_day := -1
var sun_count := 0
# Short buffs from golden suns. Not saved: they end if the app closes.
var frenzy_until := 0.0
var rush_until := 0.0
var _last_now := 0.0
var last_sun := ""        # "cash", "frenzy" or "rush"
var last_tap_crit := false
var _tap_rng := RandomNumberGenerator.new()   # own stream, so markets stay on their seed
var _news_rng := RandomNumberGenerator.new()  # mining news, likewise

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
	_tap_rng.randomize()
	_news_rng.randomize()
	_achievements = _build_achievements()
	load_game()


func now() -> float:
	return sim_time if sim_time >= 0.0 else Time.get_unix_time_from_system()


# ==== tapping and levels =================================================

func tap_value() -> float:
	return (Data.tap_base(level) + income_per_hour * 0.0012) * (1.5 if has_up("tap") else 1.0) * (1.0 + rb("tap"))


# ---- auto clicker --------------------------------------------------------

func auto_cost() -> float:
	## Price of the next level (0 when maxed).
	return float(Data.AUTO_LEVELS[auto_level][0]) if auto_level < Data.AUTO_LEVELS.size() else 0.0


func auto_interval() -> float:
	return float(Data.AUTO_LEVELS[auto_level - 1][1]) if auto_level > 0 else 0.0


func auto_running() -> bool:
	return auto_level > 0 and now() - last_tap_at <= Data.AUTO_IDLE_S


func buy_auto() -> bool:
	var c := auto_cost()
	if c <= 0.0 or cash < c:
		return false
	cash -= c
	auto_level += 1
	_bump("auto_bought")
	GameLog.info("earn", "Auto clicker level %d" % auto_level)
	recalc()
	return true


func auto_tick(dt: float) -> int:
	## Taps for you while you play. Each tap is half a normal tap (no big
	## taps, no Frenzy). Returns how many taps it made.
	if not auto_running() or dt <= 0.0:
		_auto_acc = 0.0
		return 0
	_auto_acc += minf(dt, 1.0)
	var iv := auto_interval()
	var n := int(_auto_acc / iv)
	if n <= 0:
		return 0
	_auto_acc -= float(n) * iv
	var v := tap_value() * Data.AUTO_TAP_SHARE * float(n)
	_earn(v)
	counters["auto_taps"] = int(counters.get("auto_taps", 0)) + n
	auto_tapped.emit(n, v)
	return n


# ---- head office upgrades -------------------------------------------------

func has_up(id: String) -> bool:
	return upgrades.has(id)


func upgrade(id: String) -> Array:
	for u in Data.UPGRADES:
		if u[0] == id:
			return u
	return []


func buy_upgrade(id: String) -> bool:
	var u := upgrade(id)
	if u.is_empty() or has_up(id) or cash < float(u[3]):
		return false
	cash -= float(u[3])
	upgrades[id] = true
	GameLog.info("game", "Head office upgrade: %s" % id)
	recalc()
	return true


func offline_cap_h() -> float:
	return Data.OFFLINE_CAP_H + (2.0 if has_up("away1") else 0.0) + (2.0 if has_up("away2") else 0.0) + rb("away")


func sun_per_day() -> int:
	return Data.SUN_PER_DAY + (1 if has_up("sun") else 0) + int(rb("sun"))


func manager_cut() -> float:
	if rb("mgr0") > 0.0:
		return 0.0
	return 0.06 if has_up("mgr") else Data.MANAGER_CUT


func crit_chance() -> float:
	return Data.CRIT_BASE + Data.CRIT_PER_LEVEL * float(level - 1) + rb("crit")


func crit_mult() -> float:
	return Data.CRIT_MULT * (2.0 if rb("critx") > 0.0 else 1.0)


func frenzy_active() -> bool:
	return now() < frenzy_until


func rush_active() -> bool:
	return now() < rush_until


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


func tap_tired() -> bool:
	var cool := float(Time.get_ticks_msec() - _heat_ms) / 1000.0 * Data.TAP_HEAT_COOL
	return _tap_heat - cool > Data.TAP_HEAT_MAX


func tap() -> float:
	## At most 7 paid taps a second (faster than any thumb); extra taps still
	## light the tower but earn nothing.
	var t := Time.get_ticks_msec()
	_tap_tokens = minf(7.0, _tap_tokens + float(t - _tap_ms) / 1000.0 * 7.0)
	_tap_ms = t
	if _tap_tokens < 1.0 and sim_time < 0.0 and tap_cap:
		return 0.0
	_tap_tokens -= 1.0
	var mult := 1.0
	if sim_time < 0.0:
		# Tired hands: tapping (or a tapping app) can go on for ever, but after
		# about 4 minutes non-stop at full speed taps pay a quarter until you rest.
		_tap_heat = maxf(0.0, _tap_heat - float(t - _heat_ms) / 1000.0 * Data.TAP_HEAT_COOL) + 1.0
		_heat_ms = t
		if _tap_heat > Data.TAP_HEAT_MAX:
			mult *= Data.TAP_TIRED_MULT
	if boost_active():
		mult = BOOST_MULT
	if frenzy_active():
		mult = maxf(mult, Data.FRENZY_MULT)   # the bigger one wins; they don't stack
	last_tap_crit = _tap_rng.randf() < crit_chance()
	if last_tap_crit:
		mult *= crit_mult()
		_bump("crits")
	var v := tap_value() * mult
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


func milestone_mult(id: String) -> float:
	## Owning 10, 25 and 50 units of a company each lift its income.
	if not biz.has(id):
		return 1.0
	var m := 1.0
	for ms in Data.MILESTONES:
		if int(biz[id]["units"]) >= int(ms[0]):
			m *= float(ms[1])
	return m


func next_milestone(id: String) -> Array:
	## [units needed, multiplier] for the next milestone, or [] at the top.
	if not biz.has(id):
		return []
	for ms in Data.MILESTONES:
		if int(biz[id]["units"]) < int(ms[0]):
			return ms
	return []


func synergy_mult(id: String) -> float:
	var m := 1.0
	for sy in Data.SYNERGIES:
		if synergies.has(sy[0]) and sy[4] == id:
			m *= float(sy[5])
	return m


func synergy_ready(sid: String) -> bool:
	## Both companies owned and the source has reached the stage needed.
	var sy := Data.synergy(sid)
	if sy.is_empty() or synergies.has(sid):
		return false
	return biz.has(sy[2]) and biz.has(sy[4]) and int(biz[sy[2]]["stage"]) >= int(sy[3])


func buy_synergy(sid: String) -> bool:
	var sy := Data.synergy(sid)
	if not synergy_ready(sid) or cash < float(sy[6]):
		return false
	cash -= float(sy[6])
	synergies[sid] = true
	GameLog.info("biz", "Synergy bought: %s" % sid)
	recalc()
	return true


func synergies_for(id: String) -> Array:
	## Synergies that boost this company (to list on its page).
	var out: Array = []
	for sy in Data.SYNERGIES:
		if sy[4] == id:
			out.append(sy)
	return out


func ach_bonus() -> float:
	## Small permanent income bonus from achievements, capped.
	return minf(Data.ACH_BONUS_CAP, Data.ACH_BONUS * float(achieved.size()))


func global_mult() -> float:
	var m := 1.0 + ach_bonus()
	for c in collections():
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
	v *= Data.INCOME_SCALE * merger_mult(id) * global_mult() * milestone_mult(id) * synergy_mult(id) * (1.0 + rb("income") + rb("all"))
	if ibost_active():
		v *= 2.0
	if s.get("manager", false) and not s.get("mgr_off", false) and int(s["stage"]) < Data.MAX_STAGE:
		v *= 1.0 - manager_cut()  # no cut once fully expanded
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


func manager_on(id: String) -> bool:
	## Hired and not switched off.
	return has_manager(id) and not bool(biz[id].get("mgr_off", false))


func set_manager_on(id: String, on: bool) -> void:
	## Switch a hired manager off (no expanding, no cut) or back on.
	if has_manager(id):
		biz[id]["mgr_off"] = not on
		recalc()


func sell_price(id: String) -> float:
	return biz_value(id) * 0.5


func sell_business(id: String) -> float:
	## Sells a whole company for half its value. Its units, stage and
	## manager go; partners and mergers stay bought but need it again.
	if not biz.has(id) or expanding(id):
		return 0.0
	var v := sell_price(id)
	biz.erase(id)
	cash += v
	_bump("companies_sold")
	GameLog.info("biz", "Sold %s for %s" % [id, money(v)])
	recalc()
	return v


func _managers_work() -> void:
	## Managers start the next expansion as soon as a company is full and
	## there's cash for it. They never buy units.
	for id in biz.keys():
		if manager_on(id) and int(biz[id]["units"]) >= capacity(id) and can_expand(id):
			start_expansion(id)


# ==== deals ================================================================

func tick_deals(dt: float) -> void:
	## Only counts time with the app open, so deals never pile up while away.
	if not deal.is_empty() or biz.is_empty():
		return
	deal_wait -= dt
	if deal_wait <= 0.0:
		deal_wait = randf_range(Data.DEAL_EVERY_MIN[0], Data.DEAL_EVERY_MIN[1]) * 60.0 * (0.75 if has_up("deals") else 1.0)
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
	# A buyer only if selling one unit doesn't drop you below a milestone.
	var at_mile := false
	for ms in Data.MILESTONES:
		if int(biz[id]["units"]) == int(ms[0]):
			at_mile = true
	if int(biz[id]["units"]) >= 2 and not at_mile:
		kinds.append("buyer")
	if int(biz[id]["stage"]) < Data.MAX_STAGE and not expanding(id) and float(biz[id].get("discount", 1.0)) >= 1.0:
		kinds.append("supplier")
	match kinds[randi() % kinds.size()]:
		"buyer":
			var price := unit_price(id) / Data.UNIT_PRICE_GROWTH * 0.95  # a bit under what rebuying costs
			return {"kind": "buyer", "id": id, "value": price,
				"title": "A buyer for one %s" % Data.business(id).get("unit", "unit"), "text": "%s · they pay %s" % [name, money_short(price)],
				"yes": "Sell for " + money_short(price)}
		"supplier":
			return {"kind": "supplier", "id": id, "value": expansion_cost(id) * 0.25,
				"title": "Supplier discount", "text": "%s · next expansion 25%% off" % name,
				"yes": "Take it"}
	var cost := inc / 6.0  # ten minutes of income
	return {"kind": "order", "id": id, "value": cost,
		"title": "Quick deal", "text": "%s · pay %s now, get %s in 1 h" % [name, money_short(cost), money_short(cost * 1.3)],
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


# ==== golden sun ============================================================

func tick_sun(dt: float) -> void:
	## Counts play time only. Signals the screen to float a sun across.
	if biz.is_empty():
		return
	if sun_day != _today():
		sun_day = _today()
		sun_count = 0
	if sun_count >= sun_per_day():
		return
	sun_wait -= dt
	if sun_wait <= 0.0:
		sun_wait = randf_range(Data.SUN_EVERY_MIN[0], Data.SUN_EVERY_MIN[1]) * 60.0
		sun_count += 1
		golden_sun.emit()


func catch_sun() -> float:
	## The player tapped the sun: a cash prize (minutes of income), or a short
	## buff: Frenzy (taps ×5 for 20 s) or Rush (+1× income for 10 min).
	## Returns the cash paid (0 for a buff); last_sun says which it was.
	_bump("suns")
	var pick := _tap_rng.randf()
	if pick >= Data.SUN_CASH_CHANCE:
		if pick < Data.SUN_CASH_CHANCE + Data.SUN_FRENZY_CHANCE:
			last_sun = "frenzy"
			frenzy_until = now() + Data.FRENZY_S
		else:
			last_sun = "rush"
			rush_until = now() + Data.RUSH_S
		_mark()
		return 0.0
	last_sun = "cash"
	var r := _tap_rng.randf()
	var mins := 10.0
	for p in Data.SUN_PRIZES:
		if r < float(p[0]):
			mins = float(p[1])
			break
		r -= float(p[0])
	var v := maxf(100.0, income_per_hour * mins / 60.0)
	_pay(v)
	return v


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
	if b in Data.FRONTIER and rb("u_frontier") <= 0.0:
		return false   # Frontier companies open with the tree unlock
	cash -= float(b["cost"])
	biz[id] = {"name": name, "stage": 1, "units": 1, "exp_until": 0.0, "invested": float(b["cost"])}
	GameLog.info("biz", "Opened %s (%s) for %s" % [name, id, money(b["cost"])])
	recalc()
	return true


func unit_price(id: String) -> float:
	return Data.unit_price(Data.business(id), int(biz[id]["units"]) - 1) if biz.has(id) else 0.0


func bulk_count(id: String, want: int) -> int:
	## How many units a ×want buy gets: no more than the room left, and for
	## want <= 0 ("Max") as many as the cash covers.
	if not biz.has(id):
		return 0
	var room := capacity(id) - int(biz[id]["units"])
	if want > 0:
		return clampi(want, 0, room)
	var n := 0
	var total := 0.0
	while n < room:
		var p := Data.unit_price(Data.business(id), int(biz[id]["units"]) - 1 + n)
		if total + p > cash:
			break
		total += p
		n += 1
	return n


func bulk_cost(id: String, n: int) -> float:
	## Exact price of the next n units (each costs 13% more than the last).
	if not biz.has(id) or n <= 0:
		return 0.0
	var total := 0.0
	for k in n:
		total += Data.unit_price(Data.business(id), int(biz[id]["units"]) - 1 + k)
	return total


func buy_units(id: String, n: int) -> int:
	## Buys exactly n units if all are affordable (same cost as bulk_cost); else none.
	if n <= 0 or bulk_count(id, n) < n or cash < bulk_cost(id, n):
		return 0
	var got := 0
	for k in n:
		if buy_unit(id):
			got += 1
	return got


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
	var k := (0.85 if has_up("fast1") else 1.0) * (0.85 if has_up("fast2") else 1.0) * (1.0 - minf(0.5, rb("speed")))
	return Data.expansion_minutes(Data.business(id), int(biz[id]["stage"])) * 60.0 * k if biz.has(id) else 0.0


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
	return (float(c[4]) if c.size() > 4 else 0.0) * (1.25 if has_up("lock") else 1.0) * (1.0 + rb("stake"))


func stake(sym: String, fraction: float) -> bool:
	## Locks coins for 24 hours; they earn more coins while locked.
	var free := holding(coins, sym)
	var q := free * clampf(fraction, 0.0, 1.0)
	if q <= 0.0:
		return false
	coins[sym]["qty"] = free - q
	coins[sym]["staked"] = staked(sym) + q
	# Adding to a stake starts a fresh 24 h for all of it, so a tiny early
	# lock can't let a big one skip most of the wait.
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
	return staked(sym) * stake_rate(sym) * p * _stake_scale()


func _stake_scale() -> float:
	## Staking pays at most STAKE_CAP of hourly income across ALL coins together.
	var raw := 0.0
	for c in coins.keys():
		raw += staked(c) * stake_rate(c) * price(c)
	if raw <= 0.0:
		return 1.0
	return minf(1.0, maxf(income_per_hour, 200.0) * Data.STAKE_CAP / raw)


func staking_per_hour() -> float:
	## Value of staking rewards per hour at today's prices (capped like _accrue).
	var v := 0.0
	for sym in coins.keys():
		v += stake_earn_per_hour(sym)
	return v

# ---- mining ----------------------------------------------------------------

func rigs_total() -> int:
	return int(miners.get("n", 0))


func rig_price() -> float:
	## The next miner. Climbs with every miner you own.
	return Data.RIG_BASE * pow(Data.RIG_GROWTH, rigs_total())


func rig_count(sym: String) -> int:
	## Miners digging this coin (all of them if it's the target, else none).
	return rigs_total() if sym == mine_target else 0


func set_mine_target(sym: String) -> bool:
	## Every miner switches to this coin. Free, any time.
	if _coin(sym).is_empty():
		return false
	mine_target = sym
	if not coins.has(sym):
		coins[sym] = {"qty": 0.0, "cost": 0.0}
	GameLog.info("invest", "Miners now mine %s" % sym)
	recalc()
	return true


func buy_miner() -> bool:
	if rigs_total() >= Data.RIG_MAX:
		return false
	var p := rig_price()
	if cash < p:
		return false
	if mine_target == "":
		set_mine_target(_first_coin_owned())
	cash -= p
	miners = {"n": rigs_total() + 1, "hash": float(miners.get("hash", 0.0)) + p}
	_bump("rigs_bought")
	GameLog.info("invest", "Miner bought (%s), mining %s" % [money(p), mine_target])
	recalc()
	return true


func buy_rig(sym: String) -> bool:
	## Older name: aim the miners at this coin (only if none chosen yet), then buy one.
	if mine_target == "" and not _coin(sym).is_empty():
		set_mine_target(sym)
	return buy_miner()


func _first_coin_owned() -> String:
	for c in Data.COINS:
		if holding(coins, c[0]) + staked(c[0]) > 0.0:
			return c[0]
	return "BTC"


func miner_gain() -> float:
	## Extra mining value per hour the next miner would really add (after the cap).
	var before := mining_value_per_hour()
	var keep := miners.duplicate()
	var keep_t := mine_target
	if mine_target == "":
		mine_target = _first_coin_owned()   # what the first miner would mine
	miners = {"n": rigs_total() + 1, "hash": float(keep.get("hash", 0.0)) + rig_price()}
	var after := mining_value_per_hour()
	miners = keep
	mine_target = keep_t
	return maxf(0.0, after - before)


func rig_gain(_sym: String = "") -> float:
	return miner_gain()


func _mine_raw_value() -> float:
	## Mining value per hour in £ before the cap. Each miner earns the same in £
	## whichever coin it digs, so switching coins never changes what you earn.
	if mine_target == "" or rigs_total() <= 0:
		return 0.0
	return float(miners.get("hash", 0.0)) * Data.MINE_YIELD * float(mine_eff.get(mine_target, 1.0)) * (1.25 if has_up("mine") else 1.0)


func _mine_scale() -> float:
	## 1.1 rebalance: no cap tied to income any more (it made early miners
	## worthless). Miners are limited by their price, ×1.6 each, 40 at most.
	return 1.0


func mine_cap() -> float:
	## Share of income all mining can pay: grows with every miner you own.
	return Data.MINE_CAP + Data.MINE_CAP_PER_RIG * float(rigs_total())


func mine_per_hour(sym: String) -> float:
	## Coins of this kind mined per hour (only the target coin is mined).
	if sym != mine_target or price(sym) <= 0.0:
		return 0.0
	return mining_value_per_hour() / price(sym)


func mining_value_per_hour() -> float:
	return _mine_raw_value() * _mine_scale() * (1.0 + rb("mine"))


func mining_capped() -> bool:
	return _mine_scale() < 0.999


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
	if amount_cash >= maxf(100.0, income_per_hour / 6.0):
		_task_progress("invest", 1)  # pennies don't count
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


func convert_coin(from: String, to: String, fraction: float) -> float:
	## Swap free coins of one kind for another: sold at the usual spread,
	## then bought at the other coin's price. Returns how many `to` coins you got.
	if from == to or _coin(to).is_empty() or holding(coins, from) <= 0.0:
		return 0.0
	var before := holding(coins, to)
	var got := sell_asset("coin", from, fraction)
	if got <= 0.0:
		return 0.0
	buy_asset("coin", to, got)
	_bump("conversions")
	GameLog.info("invest", "Converted %s to %s (%s)" % [from, to, money(got)])
	return holding(coins, to) - before


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


func dividend_rate(sym: String) -> float:
	## Set pay per share per hour for one company (it doesn't move with the
	## price). Each company has its own rate. Bonuses apply on top.
	var s := _stock(sym)
	if s.is_empty():
		return 0.0
	return float(s[2]) * Data.div_yield_day(float(s[3])) / 24.0 * global_mult() * (1.0 + rb("div") + rb("all"))


func dividends_per_hour() -> float:
	var v := 0.0
	for sym in shares.keys():
		v += float(shares[sym]["qty"]) * dividend_rate(sym)
	return v


func next_dividend_in() -> float:
	## Seconds until the next payout (on the hour).
	return 3600.0 - fmod(now(), 3600.0)


func _pay_dividends() -> void:
	## Shares pay once an hour, on the hour, for the shares you hold then.
	## Time away pays the hours missed, up to the away cap.
	var h := int(floor(now() / 3600.0))
	if div_hour < 0 or h < div_hour:
		div_hour = h   # first run, or the clock went back: start counting from now
		return
	if h == div_hour:
		return
	var hours := mini(h - div_hour, int(ceil(offline_cap_h())))
	div_hour = h
	var v := dividends_per_hour() * float(hours)
	if v <= 0.0:
		return
	_earn(v)
	last_dividend = v
	counters["dividends_earned"] = float(counters.get("dividends_earned", 0.0)) + v
	if not _in_offline:
		dividends_paid.emit(v)


func _market_tick(minutes := 1) -> void:
	## One market step of `minutes` (1 normally, 60 for fast-forward while away).
	var m := float(minutes)
	var ticks := float(counters.get("market_ticks", 0))
	# News effects fade slowly (half gone in about 20 days) and stay within limits,
	# so prices can't run away over months of play.
	var keep := pow(0.999976, m)
	for k in moods.keys():
		moods[k] = clampf(exp(log(maxf(float(moods[k]), 1e-6)) * keep), 0.2, 5.0)
	# Random moves go into the fair price itself (a random walk), and the
	# price follows it closely. So a dip isn't a promise of a bounce, and
	# buy-low/sell-high on the chart has no built-in edge.
	var follow := 1.0 - pow(0.5, m)
	for s in Data.STOCKS:
		var sym: String = s[0]
		var vol: float = Data.SECTOR_VOL.get(s[4], 0.006)
		moods[sym] = clampf(float(moods.get(sym, 1.0)) * exp(randfn(0.0, vol * 0.45 * sqrt(m))), 0.2, 5.0)
		var fair := float(s[2]) * exp(Data.STOCK_GROWTH * ticks) * float(moods.get(sym, 1.0)) * float(moods.get(s[4], 1.0))
		_step(sym, fair, follow, vol * 0.04 * sqrt(m))
	for c in Data.COINS:
		var sym: String = c[0]
		# Coins wander in boom and bust phases that change every few hours.
		if not trends.has(sym) or randf() < m / 180.0:
			trends[sym] = randfn(0.0, 0.0002)
		var f_log := float(fair_log.get(sym, log(float(c[2])))) + float(trends[sym]) * m + randfn(0.0, float(c[3]) * 0.2 * sqrt(m))
		# No pull back home (1.1): any pull made dips bounce, which the market
		# test caught. Coins wander freely within wide limits (x20 either way).
		var anchor := log(float(c[2])) + float(coin_shift.get(sym, 0.0))
		fair_log[sym] = clampf(f_log, anchor - 3.0, anchor + 3.0)
		coin_shift[sym] = float(coin_shift.get(sym, 0.0)) * pow(0.99995, m)
		var fair := exp(float(fair_log[sym]))
		_step(sym, fair, follow, float(c[3]) * 0.03 * sqrt(m))
	for k in mine_eff.keys():
		# Mining news wears off over about two days.
		mine_eff[k] = 1.0 + (float(mine_eff[k]) - 1.0) * pow(0.9995, m)
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
	elif r < 0.85 and rigs_total() > 0 and _news_rng.randf() < 0.5:
		# Mining news: a coin's mining speeds up or slows down for a while
		# (any coin, so it can be worth switching your miners).
		var ms: String = Data.COINS[_news_rng.randi() % Data.COINS.size()][0]
		var mup := _news_rng.randf() < 0.5
		var eff0 := float(mine_eff.get(ms, 1.0))
		mine_eff[ms] = clampf(eff0 * (1.5 if mup else 0.5), 0.25, 2.0)
		f = float(mine_eff[ms]) / eff0   # shown as the change in mining speed
		sym = ms
		var mt: Array = Data.NEWS_MINE_UP if mup else Data.NEWS_MINE_DOWN
		item = {"text": mt[_news_rng.randi() % mt.size()] % _coin(ms)[1], "sym": ms, "mine": mup}
	else:
		var c: Array = Data.COINS[randi() % Data.COINS.size()]
		var up := randf() < 0.5
		f = 1.0 + randf_range(0.15, 0.5)
		f = f if up else 1.0 / f
		sym = c[0]
		fair_log[sym] = float(fair_log.get(sym, log(float(c[2])))) + log(f)
		coin_shift[sym] = float(coin_shift.get(sym, 0.0)) + log(f)  # news sticks, not a quick bounce
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
	# A coin or share added in an update gets its own believable back history,
	# so its charts aren't empty on an old save.
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for list in [Data.STOCKS, Data.COINS]:
		for a in list:
			var sym: String = a[0]
			if hist_h.has(sym) and not (hist_h[sym] as Array).is_empty():
				continue
			var vol: float = float(a[3]) * 0.2 if list == Data.COINS else 0.006
			for spec in [[price_hist, MARKET_HIST, 1.0], [hist_q, HIST_Q, 15.0], [hist_h, HIST_H, 60.0]]:
				var arr: Array = []
				var lp := log(price(sym))
				for i in int(spec[1]):
					arr.push_front(_sig(exp(lp)))
					lp += rng.randfn(0.0, vol * sqrt(float(spec[2])))
				(spec[0] as Dictionary)[sym] = arr


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
	return float(Data.property(i)[2])


# ---- tree unlock content: the lists the player can use right now ----------

func businesses() -> Array:
	return Data.BUSINESSES + Data.FRONTIER if rb("u_frontier") > 0.0 else Data.BUSINESSES


func property_count() -> int:
	return Data.PROPERTIES.size() + (Data.ISLES.size() if rb("u_isles") > 0.0 else 0)


func collections() -> Array:
	return Data.COLLECTIONS + [Data.RELICS] if rb("u_relics") > 0.0 else Data.COLLECTIONS


func prop_rent(i: int) -> float:
	if not prop_owned(i):
		return 0.0
	var extra := 0.0
	var imps: Array = props[str(i)]["imps"]
	for k in range(imps.size()):
		if imps[k]:
			extra += float(Data.IMPROVEMENTS[k][2])
	return prop_price(i) * Data.RENT_PER_H * (1.0 + extra) * global_mult() * (1.0 + rb("rent") + rb("all"))


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
	if i < 0 or i >= property_count() or prop_owned(i) or cash < prop_price(i):
		return false
	cash -= prop_price(i)
	props[str(i)] = {"imps": [false, false, false, false, false]}
	GameLog.info("invest", "Bought property %d (%s)" % [i, Data.property(i)[0]])
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
	return Data.RELICS if col == "relics" else {}


func collection_count(col: String) -> int:
	var n := 0
	for i in range(collection(col)["items"].size()):
		if item_owned(col, i):
			n += 1
	return n


func collection_done(col: String) -> bool:
	return collection_count(col) == collection(col)["items"].size()


func buy_item(col: String, i: int) -> bool:
	if col == "relics" and rb("u_relics") <= 0.0:
		return false
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


# ==== next goal =============================================================

func next_goal() -> Dictionary:
	## The cheapest next big step, shown on the Earn screen so there's always
	## something to save for. tab: which tab opens when tapped.
	var c: Array = []
	for b in businesses():
		if not biz.has(b["id"]):
			c.append({"icon": "business", "text": String(b["name"]), "cost": float(b["cost"]), "tab": 1})
			break
	for id in biz.keys():
		if int(biz[id]["units"]) < capacity(id):
			c.append({"icon": "business", "text": "+1 %s · %s" % [Data.business(id).get("unit", "unit"), biz[id]["name"]], "cost": unit_price(id), "tab": 1})
	if next_home_cost() > 0.0:
		c.append({"icon": "home", "text": String(Data.HOMES[home + 1][0]), "cost": next_home_cost(), "tab": 3})
	for i in range(property_count()):
		if not prop_owned(i):
			c.append({"icon": "invest", "text": String(Data.property(i)[0]), "cost": prop_price(i), "tab": 2})
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
	return cash + chips() + savings() - loan_owed() + business_value() + book_value(shares) + book_value(coins) + props_value() + items_value() + home_value()


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
	# Tree unlock content (island estates, relics, frontier) is a bonus: only
	# the base game counts, so a later run's % means the same as the first.
	var base_props := 0
	for k in props.keys():
		if int(k) < Data.PROPERTIES.size():
			base_props += 1
	var pr := float(base_props) / Data.PROPERTIES.size()
	var total_items := 0
	for c in Data.COLLECTIONS:
		total_items += c["items"].size()
	var base_items := 0
	for k in items.keys():
		if not String(k).begins_with("relics:"):
			base_items += 1
	var it := float(base_items) / float(total_items)
	var ac := float(achieved.size()) / float(maxi(1, _achievements.size()))
	var lv := float(level - 1) / float(Data.MAX_LEVEL - 1)
	var hm := float(home) / float(Data.HOMES.size() - 1)
	return 0.36 * bz + 0.15 * mg + 0.15 * pr + 0.15 * it + 0.10 * ac + 0.04 * lv + 0.05 * hm


# ==== achievements ========================================================

func _build_achievements() -> Array:
	var a: Array = []
	for t in [100, 1000, 10000, 50000]:
		a.append({"id": "taps_%d" % t, "title": "%s taps" % group(t), "m": "taps", "goal": float(t)})
	for e in range(4, 16):  # up to $1Qa, so the late game still has goals
		var g := pow(10.0, e)
		a.append({"id": "worth_%d" % e, "title": "Worth %s" % money_short(g), "m": "worth", "goal": g})
	for n in [1, 3, 6, 11, Data.BUSINESSES.size()]:
		a.append({"id": "biz_%d" % n, "title": "%d compan%s" % [n, "y" if n == 1 else "ies"], "m": "biz", "goal": float(n)})
	for n in [10, 30, 60, 99]:
		a.append({"id": "stages_%d" % n, "title": "%d expansions" % n, "m": "expansions", "goal": float(n)})
	for n in [1, 5, 10, 20]:
		a.append({"id": "props_%d" % n, "title": "%d propert%s" % [n, "y" if n == 1 else "ies"], "m": "props", "goal": float(n)})
	for e in [4, 7, 10, 12]:
		a.append({"id": "shares_%d" % e, "title": "Shares worth %s" % money_short(pow(10.0, e)), "m": "shares", "goal": pow(10.0, e)})
	for e in [3, 6, 9]:
		a.append({"id": "crypto_%d" % e, "title": "%s crypto profit" % money_short(pow(10.0, e)), "m": "crypto_profit", "goal": pow(10.0, e)})
	for e in [3, 6, 9]:
		a.append({"id": "div_%d" % e, "title": "%s in dividends" % money_short(pow(10.0, e)), "m": "dividends", "goal": pow(10.0, e)})
	for e in [3, 6]:
		a.append({"id": "stake_%d" % e, "title": "%s from staking" % money_short(pow(10.0, e)), "m": "stake_earned", "goal": pow(10.0, e)})
	for n in [1, 3, 6]:
		a.append({"id": "cols_%d" % n, "title": "%d collection%s done" % [n, "" if n == 1 else "s"], "m": "collections", "goal": float(n)})
	for n in [1, 25, 60]:
		a.append({"id": "suns_%d" % n, "title": "Catch %d golden sun%s" % [n, "" if n == 1 else "s"], "m": "suns", "goal": float(n)})
	for n in [1, 10, 25]:
		a.append({"id": "deals_%d" % n, "title": "%d deal%s" % [n, "" if n == 1 else "s"], "m": "deals", "goal": float(n)})
	for n in [1, 5, 11]:
		a.append({"id": "managers_%d" % n, "title": "%d manager%s" % [n, "" if n == 1 else "s"], "m": "managers", "goal": float(n)})
	for n in [1, 5, 10, 13]:
		a.append({"id": "rivals_%d" % n, "title": "Beat %d rival%s" % [n, "" if n == 1 else "s"], "m": "rivals", "goal": float(n)})
	for n in [10, 50]:
		a.append({"id": "goals_%d" % n, "title": "%d goals done" % n, "m": "goals", "goal": float(n)})
	for n in [1, 4, 8]:
		a.append({"id": "home_%d" % n, "title": Data.HOMES[n][0], "m": "home", "goal": float(n)})
	for n in [1, 3, 6]:
		a.append({"id": "merge_%d" % n, "title": "%d merger%s" % [n, "" if n == 1 else "s"], "m": "mergers", "goal": float(n)})
	for n in [5, 10, 20, 25]:
		a.append({"id": "level_%d" % n, "title": "Level %d" % n, "m": "level", "goal": float(n)})
	for n in [1, 5, 10]:
		a.append({"id": "syn_%d" % n, "title": "%d synerg%s" % [n, "y" if n == 1 else "ies"], "m": "synergies", "goal": float(n)})
	for n in [1, 10, 17]:
		a.append({"id": "mile_%d" % n, "title": "%d full compan%s" % [n, "y" if n == 1 else "ies"], "m": "full50", "goal": float(n)})
	for n in [1, 5, 10]:
		a.append({"id": "office_%d" % n, "title": "%d head office upgrade%s" % [n, "" if n == 1 else "s"], "m": "upgrades", "goal": float(n)})
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
		"suns": return float(counters.get("suns", 0))
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
		"synergies": return float(synergies.size())
		"upgrades": return float(upgrades.size())
		"full50":
			var n := 0
			for id in biz.keys():
				if int(biz[id]["units"]) >= Data.MAX_STAGE * Data.UNITS_PER_STAGE:
					n += 1
			return float(n)
	return 0.0


func _check_achievements() -> void:
	var got := false
	for a in _achievements:
		if achieved.has(a["id"]):
			continue
		if metric(a["m"]) >= float(a["goal"]):
			achieved[a["id"]] = true
			got = true
			GameLog.info("game", "Achievement: %s" % a["title"])
			var reward := maxf(500.0, income_per_hour * 1.0)
			add_reward("ach:" + String(a["id"]), "ach", String(a["title"]), reward)   # waits for a tap
			achievement.emit(a["title"], reward)
	if got:
		recalc()  # each achievement adds a little to all income


# ==== daily tasks =========================================================

func _local_now() -> float:
	## Days and weeks roll over at local midnight, not UTC.
	return now() + float(_tz_bias_min) * 60.0


var _tz_bias_min := int(Time.get_time_zone_from_system().get("bias", 0))


func _today() -> int:
	return int(_local_now() / 86400.0)


func _check_streak() -> void:
	## Coming back on consecutive days builds a streak with a small gift.
	var today := _today()
	if today <= streak_day:
		return  # same day, or the clock went backwards
	var old := streak
	streak = streak + 1 if streak_day == today - 1 else 1
	streak_lost = old if (streak == 1 and old >= 2) else 0
	streak_day = today
	var gift := maxf(250.0, income_per_hour * 0.15 * float(mini(streak, 7)))
	add_reward("streak:%d" % today, "streak", "Day %d in a row" % streak, gift)   # waits for a tap
	streak_unseen = [streak, gift]
	streak_gift.emit(streak, gift)


func _ensure_daily() -> void:
	_check_streak()
	if not daily.is_empty() and _today() <= int(daily.get("day", -1)):
		return  # same day, or the clock went backwards
	var pool := [
		{"id": "taps", "text": "Tap %d times", "goal": 200},
		{"id": "invest", "text": "Invest %d times", "goal": 3},
	]
	if _units_left() >= 5:
		pool.append({"id": "units", "text": "Buy %d units", "goal": 5})
	if _can_still_expand():
		pool.append({"id": "expand", "text": "Finish %d expansion", "goal": 1})
	if biz.is_empty():
		pool = [{"id": "taps", "text": "Tap %d times", "goal": 400}]
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
				var period := int(book.get("day", book.get("week", 0)))
				t["key"] = "goal:%s:%d:%s" % [scope, period, String(t["id"])]
				add_reward(String(t["key"]), "goal", String(t["text"]), r)   # waits for a tap
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
	return int(floor((_local_now() / 86400.0 + 3.0) / 7.0))


func _ensure_weekly() -> void:
	if not weekly.is_empty() and _week() <= int(weekly.get("week", -1)):
		return
	var earn_goal := maxf(50000.0, income_per_hour * 30.0)
	var pool := [
		{"id": "taps", "text": "Tap %s times" % group(800), "goal": 800.0},
		{"id": "invest", "text": "Invest 10 times", "goal": 10.0},
		{"id": "earn", "text": "Earn %s" % money_short(earn_goal), "goal": earn_goal, "money": true},
	]
	if _units_left() >= 30:
		pool.append({"id": "units", "text": "Buy 30 units", "goal": 30.0})
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
	return float(_week() + 1) * 7.0 * 86400.0 - 3.0 * 86400.0 - _local_now()


# ---- rewards you claim with a tap -----------------------------------------

func add_reward(key: String, kind: String, title: String, amount: float) -> void:
	if not reward_for(key).is_empty():
		return
	rewards.append({"key": key, "kind": kind, "title": title, "amount": amount})
	_mark()


func reward_for(key: String) -> Dictionary:
	for r in rewards:
		if String(r.get("key", "")) == key:
			return r
	return {}


func claim(key: String) -> float:
	## Pays a waiting reward. The amount was fixed when it was earned, so
	## waiting to claim never pays more.
	for i in range(rewards.size()):
		var r: Dictionary = rewards[i]
		if String(r.get("key", "")) == key:
			rewards.remove_at(i)
			var v := float(r.get("amount", 0.0))
			if String(r.get("kind", "")) == "ach":
				_earn(v)
			else:
				_pay(v)
			GameLog.info("game", "Claimed %s (%s)" % [key, money(v)])
			return v
	return 0.0


func claim_all(kind := "") -> float:
	var total := 0.0
	for r in rewards.duplicate():
		if kind == "" or String(r.get("kind", "")) == kind:
			total += claim(String(r["key"]))
	return total


func unclaimed(kind := "") -> int:
	var n := 0
	for r in rewards:
		if kind == "" or String(r.get("kind", "")) == kind:
			n += 1
	return n


func unclaimed_total(kind := "") -> float:
	var v := 0.0
	for r in rewards:
		if kind == "" or String(r.get("kind", "")) == kind:
			v += float(r.get("amount", 0.0))
	return v


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
		var flow := income_per_hour - float(_income_parts.get("div", 0.0))   # dividends come on the hour
		if flow > 0.0:
			_earn(flow * dt / 3600.0)
		_accrue(dt)
	_pay_dividends()
	_market_timer += dt
	var minutes := int(_market_timer / MARKET_TICK_S)
	_market_timer = fmod(_market_timer, MARKET_TICK_S)
	if minutes > 0:
		# Long gaps (time away) move in 15-minute steps, at most a week's worth.
		var recent := mini(minutes, 120)
		var quarters := mini((minutes - recent) / 15, HIST_H * 4)
		if quarters > 0:
			_catch_up(quarters, now() - float(recent) * 60.0)
		var catching_up := recent > 2
		if catching_up:
			_quiet = true
		for i in recent:
			_bump("market_ticks")
			if catching_up:
				_tick_t = now() - float(recent - 1 - i) * 60.0
			_market_tick()
			_record_prices(1)
		_tick_t = -1.0
		_quiet = false
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
	var tnow := now()
	if _last_now > 0.0 and tnow < _last_now - 1.0:
		# Clock set back: pull short buffs back too, so they can't run longer.
		var back := _last_now - tnow
		for k in ["frenzy_until", "rush_until", "boost_until"]:
			if float(get(k)) > tnow:
				set(k, float(get(k)) - back)
	_last_now = tnow
	advance(delta)
	if rush_active():
		# Rush: one more lot of income while open, at most 1 s per frame
		# (a long first frame after a pause must not pay twice).
		_earn((income_per_hour - float(_income_parts.get("div", 0.0))) * minf(delta, 1.0) / 3600.0)
	tick_deals(delta)
	tick_sun(delta)
	auto_tick(delta)
	if was_boosting != ibost_active():
		recalc()
	_check_timer += delta
	if _check_timer >= 1.0:
		# Stats: time played and the best income seen (only while the app is open).
		counters["play_s"] = float(counters.get("play_s", 0.0)) + _check_timer
		counters["best_income"] = maxf(float(counters.get("best_income", 0.0)), income_per_hour)
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
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Notification shade, a call, another app on top: save, and draw
			# only a few frames a second to spare the battery.
			if sim_time < 0.0:
				save_game()
				Engine.max_fps = 5
		NOTIFICATION_APPLICATION_FOCUS_IN:
			Engine.max_fps = 60
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0.0:
				apply_offline(now() - _paused_at)
				_paused_at = 0.0
				flush_changes()


func apply_offline(seconds: float) -> void:
	## Income is capped at 8 hours; timers and markets run for real.
	var s := maxf(0.0, seconds)
	# Roll today's goals first, so things that finish while away can't pay
	# out on yesterday's list.
	_ensure_daily()
	_ensure_weekly()
	# Some of the time away counts towards the next deal (up to 2 h), so
	# short-session players still get them.
	# (Time away no longer brings a deal closer: deals come from play time.)
	var capped := minf(s, offline_cap_h() * 3600.0)
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
	var gained := (base - dividends_per_hour()) * capped / 3600.0 + biz_base * ib_part / 3600.0   # dividends: paid by the hour
	var exp0 := int(counters.get("expansions", 0))
	var mined0 := float(counters.get("mined_value", 0.0))
	var staked0 := float(counters.get("stake_earned", 0.0))
	var pay0 := payouts.size()
	var div0 := float(counters.get("dividends_earned", 0.0))
	_in_offline = true
	advance(s, false)
	_in_offline = false
	recalc()
	_earn(gained)
	_accrue(capped)
	away_earned = cash - before
	away_seconds = s
	away_notes = []
	var done := int(counters.get("expansions", 0)) - exp0
	if done > 0:
		away_notes.append("%d expansion%s done" % [done, "" if done == 1 else "s"])
	if pay0 > payouts.size():
		away_notes.append("Quick deals paid")
	var div_got := float(counters.get("dividends_earned", 0.0)) - div0
	if div_got >= 0.01:
		away_notes.append("Dividends paid %s" % money_short(div_got))
	var mined := float(counters.get("mined_value", 0.0)) - mined0
	if mined >= 1.0:
		away_notes.append("Mined %s of crypto" % money_short(mined))
	var lock_got := float(counters.get("stake_earned", 0.0)) - staked0
	if lock_got >= 1.0:
		away_notes.append("Locked coins earned %s" % money_short(lock_got))
	if s > offline_cap_h() * 3600.0:
		away_notes.append("Capped at %d h" % int(offline_cap_h()))
	away_unseen = s >= 600.0 and away_earned >= 1.0
	var exp_before := 0
	for id in biz.keys():
		if expanding(id):
			exp_before += 1
	_managers_work()
	var started := 0
	for id in biz.keys():
		if expanding(id):
			started += 1
	started -= exp_before
	if started > 0:
		away_notes.append("Managers started %d expansion%s" % [started, "" if started == 1 else "s"])
	if s > 60.0:
		GameLog.info("game", "Away for %s, earned %s (income %s/h)" % [clock(s), money(away_earned), money(income_per_hour)])
	_ensure_daily()
	_ensure_weekly()
	_check_achievements()


# ==== bank =================================================================

func savings() -> float:
	return float(bank.get("saved", 0.0))


func savings_per_hour() -> float:
	## Interest an hour on savings, capped against base income.
	var cap := maxf(base_income(), Data.BANK_CAP_FLOOR) * Data.BANK_CAP
	return minf(savings() * Data.BANK_RATE_H, cap)


func deposit(amount: float) -> bool:
	amount = minf(amount, cash)
	if amount < 0.01:
		return false
	cash -= amount
	bank["saved"] = savings() + amount
	recalc()
	save_game()
	return true


func withdraw(amount: float) -> bool:
	amount = minf(amount, savings())
	if amount < 0.01:
		return false
	bank["saved"] = savings() - amount
	cash += amount
	recalc()
	save_game()
	return true


func loan() -> Dictionary:
	return bank.get("loan", {})


func loan_limit() -> float:
	return maxf(Data.LOAN_MIN, base_income() * Data.LOAN_MAX_H)


func loan_owed() -> float:
	var l := loan()
	return 0.0 if l.is_empty() else float(l["payment"]) * float(l["left"])


func take_loan(amount: float) -> bool:
	## One loan at a time; paid back in set payments, the first after 4 h.
	if not loan().is_empty() or amount < 1.0 or amount > loan_limit() + 0.01:
		return false
	var total := amount * (1.0 + Data.LOAN_FEE)
	bank["loan"] = {"amount": amount, "payment": total / float(Data.LOAN_PAYMENTS),
		"left": Data.LOAN_PAYMENTS, "next": now() + Data.LOAN_EVERY_H * 3600.0}
	cash += amount
	_bump("loans")
	GameLog.info("bank", "Loan %s, %d payments of %s" % [money(amount), Data.LOAN_PAYMENTS, money(total / float(Data.LOAN_PAYMENTS))])
	recalc()
	save_game()
	return true


func repay_loan() -> bool:
	## Pay off everything left now (no discount).
	var owed := loan_owed()
	if owed <= 0.0 or cash < owed:
		return false
	cash -= owed
	bank["loan"] = {}
	recalc()
	save_game()
	return true


func _bank_tick(dt: float) -> void:
	## Interest into savings, and loan payments when they fall due (cash may
	## go into the minus; income then pays that off first).
	if savings() > 0.0 and dt > 0.0:
		var got := savings_per_hour() * dt / 3600.0
		bank["saved"] = savings() + got
		counters["interest_earned"] = float(counters.get("interest_earned", 0.0)) + got
	var l := loan()
	while not l.is_empty() and now() >= float(l["next"]):
		cash -= float(l["payment"])
		l["left"] = int(l["left"]) - 1
		l["next"] = float(l["next"]) + Data.LOAN_EVERY_H * 3600.0
		GameLog.info("bank", "Loan payment %s, %d left" % [money(float(l["payment"])), int(l["left"])])
		if int(l["left"]) <= 0:
			bank["loan"] = {}
			l = {}


func in_minus() -> bool:
	return cash < 0.0


func _accrue(dt: float) -> void:
	_bank_tick(dt)
	## Dividends earned so far, staking rewards and mining (both paid in coins).
	for sym in ([mine_target] if mine_target != "" else []):
		var got := mine_per_hour(sym) * dt / 3600.0
		if got > 0.0:
			if not coins.has(sym):
				coins[sym] = {"qty": 0.0, "cost": 0.0}
			coins[sym]["qty"] = holding(coins, sym) + got
			counters["mined_value"] = float(counters.get("mined_value", 0.0)) + got * price(sym)
	for sym in coins.keys():
		var st := staked(sym)
		if st > 0.0:
			var gain := st * stake_rate(sym) * _stake_scale() * dt / 3600.0
			coins[sym]["staked"] = st + gain
			counters["stake_earned"] = float(counters.get("stake_earned", 0.0)) + gain * price(sym)


func _record_history() -> void:
	history.append([now(), net_worth(), income_per_hour])   # income for the Stats chart (1.2)
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
		"hist_q": hist_q, "hist_h": hist_h, "moods": moods, "coin_shift": coin_shift, "trends": trends, "fair_log": fair_log, "news": news,
		"props": props, "items": items, "mergers": mergers, "synergies": synergies, "miners": miners, "mine_target": mine_target, "upgrades": upgrades, "auto_level": auto_level, "bank": bank, "rewards": rewards, "rebirth": rebirth, "casino": casino, "mine_eff": mine_eff, "achieved": achieved, "home": home,
		"counters": counters, "daily": daily, "weekly": weekly, "history": history,
		"deal_wait": deal_wait, "div_hour": div_hour, "payouts": payouts, "deal": deal,
		"ui": ui, "streak": streak, "streak_day": streak_day,
		"sun_wait": sun_wait, "sun_day": sun_day, "sun_count": sun_count,
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
	_guard_note()


func _guard_load() -> void:
	if _guard.is_empty() and FileAccess.file_exists(GUARD_PATH):
		var g = JSON.parse_string(FileAccess.get_file_as_string(GUARD_PATH))
		_guard = g if typeof(g) == TYPE_DICTIONARY else {}


func _guard_strict() -> void:
	## Marks this game: nothing saved before now may be restored into it.
	_guard_load()
	_guard[str(int(started_at)) + "!"] = now()
	var f := FileAccess.open(GUARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_guard))
		f.close()


func _guard_note() -> void:
	## Remembers how far each game on this phone has got (newest save time).
	_guard_load()
	var key := str(int(started_at))
	var t := now()
	if float(_guard.get(key, 0.0)) >= t - 30.0:
		return
	_guard[key] = t
	var f := FileAccess.open(GUARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_guard))
		f.close()


# ==== backup code ===========================================================
# The whole save as one short text code, so progress survives a reinstall.
# Price charts and news are left out; they rebuild on restore.

const BACKUP_PREFIX := "SOL1:"
# Restore guard: a backup can't rewind the game it came from (that would be a
# free "undo" on trades and golden suns). It works on a new phone, after a
# reinstall, or for a different game. Kept in its own file so a reset keeps it.
const GUARD_PATH := "user://restore_guard.json"
var restore_guard := true    # tests switch this off to restore freely
var restore_error := ""
var _guard := {}


func backup_code() -> String:
	var d := to_dict()
	for k in ["price_hist", "hist_q", "hist_h", "news"]:
		d.erase(k)
	var raw := JSON.stringify(d).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	return BACKUP_PREFIX + str(raw.size()) + ":" + Marshalls.raw_to_base64(packed)


func restore_code(text: String) -> bool:
	## Checks the code fully before touching the current save.
	restore_error = ""
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
	if restore_guard and sim_time < 0.0:
		_guard_load()
		var gk := str(int(float(d.get("started_at", 0.0))))
		# After a casino bet, no older backup of this game may come back, with
		# no 10-minute allowance (else: back up, gamble, restore if down).
		if _guard.has(gk + "!") and float(d.get("saved_at", 0.0)) <= float(_guard[gk + "!"]):
			restore_error = "This backup is from before a casino bet in this game. Use it on a new phone or after reinstalling."
			GameLog.info("save", "Restore refused: older than a casino bet")
			return false
		if _guard.has(gk) and float(d.get("saved_at", 0.0)) < float(_guard[gk]) - 600.0:
			restore_error = "This backup is older than your game here. Use it on a new phone or after reinstalling."
			GameLog.info("save", "Restore refused: older backup of this same game")
			return false
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		return false
	d = _migrate(d, prices)   # old codes: convert coins from their saved prices to today's
	d["saved_at"] = now()  # no time passes on restore, so it can't re-roll the market
	# Keep today's market and deal, so a restore can't rewind prices or re-roll a deal.
	var live := to_dict()
	for k in ["prices", "price_hist", "hist_q", "hist_h", "moods", "coin_shift", "trends", "fair_log", "news", "deal", "deal_wait", "mine_eff"]:
		d[k] = live[k]
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


func _migrate(d: Dictionary, live_prices: Dictionary = {}) -> Dictionary:
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
	if v < 7:
		# v7 adds the golden sun and lasting coin news (defaults are fine).
		v = 7
	if v < 8:
		# v8 (1.1) adds synergy upgrades; milestones and achievement bonuses
		# are worked out from what you already own, so old saves get them at once.
		d["synergies"] = d.get("synergies", {})
		v = 8
	if v < 9:
		# v9 (1.1) adds crypto mining. New coins get their price on load
		# (_init_market fills any coin the save doesn't have).
		d["rigs"] = d.get("rigs", {})
		d["mine_eff"] = d.get("mine_eff", {})
		v = 9
	if v < 10:
		_migrate_v10(d, live_prices)
		v = 10
	if v < 11:
		# v11 adds head office upgrades (none bought yet).
		d["upgrades"] = d.get("upgrades", {})
		v = 11
	if v < 12:
		# v12: rewards wait to be claimed. Older ones were already paid.
		d["rewards"] = d.get("rewards", [])
		v = 12
	if v < 13:
		# v13: rebirth. Nobody has reborn yet, so the tree starts empty.
		d["rebirth"] = d.get("rebirth", {"count": 0, "earned": 0, "nodes": {}})
		v = 13
	if v < 14:
		# v14: the casino (locked, no chips).
		d["casino"] = d.get("casino", {"open": false, "chips": 0.0})
		v = 14
	if v < 15:
		# v15: dividends pay on the hour. Older saves earned them all along,
		# so counting starts from the save time (nothing paid twice).
		d["div_hour"] = int(floor(float(d.get("saved_at", 0.0)) / 3600.0)) if float(d.get("saved_at", 0.0)) > 0.0 else -1
		v = 15
	if v < 16:
		# v16: the auto clicker (none yet).
		d["auto_level"] = int(d.get("auto_level", 0))
		v = 16
	if v < 17:
		# v17: the bank (nothing saved, no loan).
		d["bank"] = d.get("bank", {"saved": 0.0, "loan": {}})
		v = 17
	d["version"] = v
	return d


func _migrate_v10(d: Dictionary, live_prices: Dictionary = {}) -> void:
	## 1.1: made-up coins became real ones, and miners moved to one pool that
	## mines one coin. Holdings keep their value in £ at the saved price.
	var ren: Dictionary = Data.COIN_RENAME
	var old_prices: Dictionary = d.get("prices", {})
	var new_coins := {}
	for old in (d.get("coins", {}) as Dictionary).keys():
		var c: Dictionary = d["coins"][old]
		var nsym: String = ren.get(old, old)
		var nc := Data.coin(nsym)
		var po := float(old_prices.get(old, 0.0))
		# Convert at the price the coin will actually have: the live market on a
		# restore (else an old code would gain whatever the coin has risen since),
		# or the new coin's starting price on a plain load.
		var pn := float(live_prices.get(nsym, nc[2] if not nc.is_empty() else 0.0))
		var f := po / pn if po > 0.0 and pn > 0.0 else 0.0
		var out := c.duplicate()
		out["qty"] = float(c.get("qty", 0.0)) * f
		if c.has("staked"):
			out["staked"] = float(c.get("staked", 0.0)) * f
		new_coins[nsym] = out
	d["coins"] = new_coins
	# Coin prices and charts start fresh at the new coins' prices.
	for key in ["prices", "price_hist", "hist_q", "hist_h", "fair_log", "trends", "coin_shift", "moods"]:
		var store: Dictionary = d.get(key, {})
		for old in ren.keys():
			store.erase(old)
		d[key] = store
	var eff := {}
	for old in (d.get("mine_eff", {}) as Dictionary).keys():
		eff[ren.get(old, old)] = d["mine_eff"][old]
	d["mine_eff"] = eff
	# Old per-coin rigs become one pool; it mines the coin that had the most.
	var n := 0
	var h := 0.0
	var best := ""
	var best_h := -1.0
	for old in (d.get("rigs", {}) as Dictionary).keys():
		var r: Dictionary = d["rigs"][old]
		n += int(r.get("n", 0))
		h += float(r.get("hash", 0.0))
		if float(r.get("hash", 0.0)) > best_h:
			best_h = float(r.get("hash", 0.0))
			best = ren.get(old, old)
	d["miners"] = {"n": n, "hash": h}
	d["mine_target"] = best
	d.erase("rigs")
	# Old headlines named the old coins; start the news afresh.
	d["news"] = []


func _reset_state() -> void:
	sci = false
	away_unseen = false
	away_earned = 0.0
	frenzy_until = 0.0
	rush_until = 0.0
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
	coin_shift = {}
	trends = {}
	fair_log = {}
	news = []
	props = {}
	items = {}
	mergers = {}
	synergies = {}
	miners = {"n": 0, "hash": 0.0}
	mine_target = ""
	upgrades = {}
	auto_level = 0
	bank = {"saved": 0.0, "loan": {}}
	rewards = []
	rebirth = {"count": 0, "earned": 0, "nodes": {}}
	_rb_cache = {}
	casino = {"open": false, "chips": 0.0}
	mine_eff = {}
	achieved = {}
	counters = {}
	daily = {}
	weekly = {}
	deal = {}
	ui = {}
	streak = 0
	streak_day = -1
	sun_wait = 900.0
	sun_day = -1
	sun_count = 0
	deal_wait = 1500.0
	div_hour = -1
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
	coin_shift = d.get("coin_shift", {})
	trends = d.get("trends", {})
	fair_log = d.get("fair_log", {})
	news = d.get("news", [])
	props = d.get("props", {})
	items = d.get("items", {})
	home = clampi(int(d.get("home", 0)), 0, Data.HOMES.size() - 1)
	mergers = d.get("mergers", {})
	synergies = d.get("synergies", {})
	miners = d.get("miners", {"n": 0, "hash": 0.0})
	mine_target = String(d.get("mine_target", ""))
	upgrades = d.get("upgrades", {})
	rewards = d.get("rewards", [])
	auto_level = int(d.get("auto_level", 0))
	bank = d.get("bank", {"saved": 0.0, "loan": {}})
	rebirth = d.get("rebirth", {"count": 0, "earned": 0, "nodes": {}})
	_rb_cache = {}
	casino = d.get("casino", {"open": false, "chips": 0.0})
	if not mine_target.is_empty() and _coin(mine_target).is_empty():
		mine_target = ""
	mine_eff = d.get("mine_eff", {})
	achieved = d.get("achieved", {})
	counters = d.get("counters", {})
	daily = d.get("daily", {})
	weekly = d.get("weekly", {})
	deal_wait = float(d.get("deal_wait", 1500.0))
	div_hour = int(d.get("div_hour", -1))
	deal = d.get("deal", {})
	ui = d.get("ui", {})
	streak = int(d.get("streak", 0))
	streak_day = int(d.get("streak_day", -1))
	sun_wait = float(d.get("sun_wait", 900.0))
	sun_day = int(d.get("sun_day", -1))
	sun_count = int(d.get("sun_count", 0))
	payouts = d.get("payouts", [])
	history = d.get("history", [])
	vibrate = bool(d.get("vibrate", true))
	reduce_motion = bool(d.get("reduce_motion", false))
	sci = bool(ui.get("sci", false))
	started_at = float(d.get("started_at", now()))
	_init_market()
	recalc()
	apply_offline(now() - float(d.get("saved_at", now())))
	if history.is_empty():
		_record_history()
	if not counters.has("rivals"):
		counters["rivals"] = float(rivals_beaten())


func reset_game(fresh_market := false) -> void:
	GameLog.info("game", "Progress reset")
	if fresh_market:
		# Tests and the robot: a brand new market, so seeds repeat exactly.
		_reset_state()
		_init_market()
		recalc()
		_record_history()
		save_game()
		flush_changes()
		return
	# The market is the world, not your save: it carries on through a reset,
	# so resetting and then restoring a backup can't re-roll prices.
	var keep := {}
	for k in ["prices", "price_hist", "hist_q", "hist_h", "moods", "coin_shift", "trends", "fair_log", "news"]:
		keep[k] = to_dict()[k]
	var ticks := float(counters.get("market_ticks", 0))
	_reset_state()
	prices = keep["prices"]
	price_hist = keep["price_hist"]
	hist_q = keep["hist_q"]
	hist_h = keep["hist_h"]
	moods = keep["moods"]
	coin_shift = keep["coin_shift"]
	trends = keep["trends"]
	fair_log = keep["fair_log"]
	news = keep["news"]
	counters["market_ticks"] = ticks
	_init_market()
	recalc()
	_record_history()
	save_game()
	flush_changes()


# ==== casino ================================================================
# Opened by unlock nodes in the RBP tree (u_casino, u_tables). Chips are bought at the cage with cash and cashed out any time. Every
# round goes through casino_stake() then casino_pay(): limits are checked,
# the result is saved at once (before any animation), so closing the app
# mid-spin can't undo a loss. Limits follow base income, so the casino can't
# skip weeks: a bet is at most CASINO_MAX_BET_H hours of income, a single
# payout at most CASINO_MAX_WIN_H hours.

func chips() -> float:
	return float(casino.get("chips", 0.0))


func casino_open() -> bool:
	## Opened by the Sol Casino node in the RBP tree.
	return rb("u_casino") > 0.0


func tables_open() -> bool:
	## Roulette and blackjack: the High tables node (and the casino itself).
	return casino_open() and rb("u_tables") > 0.0


func grant_node(id: String) -> void:
	## Tests and screenshots: own a tree node without paying.
	rebirth["nodes"][id] = true
	_rb_cache = {}
	recalc()


func path_cost(id: String) -> int:
	## RBP needed to reach and buy a node from what you own (cheapest path).
	if node_owned(id):
		return 0
	var best := {}
	var todo: Array = []
	for n in RebirthTree.nodes():
		if node_owned(String(n["id"])):
			best[n["id"]] = 0
			todo.append(String(n["id"]))
	while not todo.is_empty():
		todo.sort_custom(func(a, b): return int(best[a]) < int(best[b]))
		var cur: String = todo.pop_front()
		for l in RebirthTree.node(cur)["links"]:
			var c := int(best[cur]) + int(RebirthTree.node(String(l))["cost"])
			if not best.has(l) or c < int(best[l]):
				best[l] = c
				todo.append(String(l))
	return int(best.get(id, 0))


func base_income() -> float:
	## Hourly income without short boosts (the x2 income boost).
	return income_per_hour / (2.0 if ibost_active() else 1.0)


func casino_max_bet() -> float:
	var m := maxf(Data.CASINO_MIN_BET_CAP, base_income() * Data.CASINO_MAX_BET_H)
	return m * (2.0 if rb("casino") > 0.0 else 1.0)


func casino_max_win() -> float:
	var m := maxf(Data.CASINO_MIN_WIN_CAP, base_income() * Data.CASINO_MAX_WIN_H)
	return m * (2.0 if rb("casino") > 0.0 else 1.0)


func buy_chips(amount: float) -> bool:
	amount = minf(amount, cash)
	if not casino_open() or amount < 0.01:
		return false
	cash -= amount
	casino["chips"] = chips() + amount
	recalc()
	save_game()
	return true


func cash_out(amount: float) -> bool:
	amount = minf(amount, chips())
	if amount < 0.01:
		return false
	casino["chips"] = chips() - amount
	cash += amount
	recalc()
	save_game()
	return true


func wheel_ready() -> bool:
	## One free spin a day, once the casino is open.
	return casino_open() and int(casino.get("wheel_day", -1)) < _today()


func spin_wheel() -> Dictionary:
	## Spins the free wheel: {index, kind ("cash"/"chips"), amount}. Saved at once.
	if not wheel_ready():
		return {}
	var total := 0
	for w in Data.WHEEL:
		total += int(w[2])
	var roll := randi() % total
	var idx := 0
	for i in range(Data.WHEEL.size()):
		roll -= int(Data.WHEEL[i][2])
		if roll < 0:
			idx = i
			break
	var seg: Array = Data.WHEEL[idx]
	var amount := maxf(base_income(), 100.0) * float(seg[1]) / 60.0
	if String(seg[0]) == "chips":
		casino["chips"] = chips() + amount
	else:
		cash += amount
	casino["wheel_day"] = _today()
	_bump("wheel_spins")
	GameLog.info("casino", "Wheel: %s %s" % [seg[0], money(amount)])
	recalc()
	save_game()
	flush_changes()
	return {"index": idx, "kind": String(seg[0]), "amount": amount}


func casino_stake(amount: float, limit_mult := 1.0) -> bool:
	## Takes a bet from chips. limit_mult lets a bonus buy or a blackjack
	## double or split go past one normal bet.
	if not casino_open() or amount <= 0.0 or amount > chips() + 0.001:
		return false
	if amount > casino_max_bet() * limit_mult + 0.001:
		return false
	casino["chips"] = chips() - amount
	counters["casino_bet"] = float(counters.get("casino_bet", 0.0)) + amount
	counters["casino_rounds"] = int(counters.get("casino_rounds", 0)) + 1
	_guard_strict()
	save_game()
	flush_changes()
	return true


func casino_pay(amount: float) -> float:
	## Pays a win into chips, capped. Returns what was really paid.
	amount = clampf(amount, 0.0, casino_max_win())
	if amount <= 0.0:
		return 0.0
	casino["chips"] = chips() + amount
	counters["casino_won"] = float(counters.get("casino_won", 0.0)) + amount
	if amount > float(counters.get("casino_best", 0.0)):
		counters["casino_best"] = amount
	save_game()
	flush_changes()
	return amount


# ==== rebirth and the RBP tree ===========================================

# What a rebirth clears. Everything else in the save is kept (market, stats,
# achievements, settings, goal and streak timers, the tree). A test checks
# every saved key is in exactly one of these lists.
const REBIRTH_RESET := ["cash", "level", "boost_until", "boost_ready_at", "ibost_until", "ibost_ready_at",
	"biz", "shares", "coins", "props", "items", "mergers", "synergies", "miners", "mine_target",
	"upgrades", "auto_level", "bank", "rewards", "home", "deal", "payouts", "history"]
const REBIRTH_KEEP := ["total_earned", "taps", "boosts_used", "prices", "price_hist", "hist_q", "hist_h",
	"moods", "coin_shift", "trends", "fair_log", "news", "mine_eff", "achieved", "counters", "daily",
	"weekly", "deal_wait", "div_hour", "ui", "streak", "streak_day", "sun_wait", "sun_day", "sun_count", "vibrate",
	"reduce_motion", "started_at", "rebirth", "casino"]   # casino: the unlock stays, chips are cleared


func rb(stat: String) -> float:
	## The tree's total for one stat (owned nodes only).
	if _rb_cache.is_empty():
		_rb_cache = {"_": 0.0}
		for id in (rebirth.get("nodes", {}) as Dictionary).keys():
			var n := RebirthTree.node(String(id))
			for k in (n.get("fx", {}) as Dictionary).keys():
				_rb_cache[k] = float(_rb_cache.get(k, 0.0)) + float(n["fx"][k])
	return float(_rb_cache.get(stat, 0.0))


func rbp_spent() -> int:
	var t := 0
	for id in (rebirth.get("nodes", {}) as Dictionary).keys():
		t += int(RebirthTree.node(String(id)).get("cost", 0))
	return t


func rbp_free() -> int:
	return int(rebirth.get("earned", 0)) - rbp_spent()


func rebirths() -> int:
	return int(rebirth.get("count", 0))


func node_owned(id: String) -> bool:
	return id == "core" or (rebirth.get("nodes", {}) as Dictionary).has(id)


func node_open(id: String) -> bool:
	## Buyable now: not owned, and linked to something owned.
	if node_owned(id):
		return false
	for l in RebirthTree.node(id).get("links", []):
		if node_owned(String(l)):
			return true
	return false


func buy_node(id: String) -> bool:
	var n := RebirthTree.node(id)
	if n.is_empty() or not node_open(id) or rbp_free() < int(n["cost"]):
		return false
	rebirth["nodes"][id] = true
	_rb_cache = {}
	_bump("nodes_bought")
	GameLog.info("rebirth", "Bought %s (%d RBP)" % [id, int(n["cost"])])
	recalc()
	save_game()
	return true


func tree_owned_count() -> int:
	return (rebirth.get("nodes", {}) as Dictionary).size()


func rebirth_pending() -> int:
	## RBP a rebirth would give now: 10 at £10B net worth, then the cube root.
	var nw := net_worth()
	if nw < Data.REBIRTH_MIN:
		return 0
	return int(floor(10.0 * pow(nw / Data.REBIRTH_MIN, 1.0 / 3.0) * (1.0 + minf(0.5, rb("rbp"))) + 1e-6))


func start_level() -> int:
	return clampi(1 + int(rb("level")), 1, Data.MAX_LEVEL)


func do_rebirth() -> int:
	## Starts a new run: money and assets go, the tree and the rest stay.
	var got := rebirth_pending()
	if got <= 0:
		return 0
	var keep := {}
	var d := to_dict()
	for k in REBIRTH_KEEP:
		keep[k] = d[k]
	var keep_sci := sci
	_reset_state()
	total_earned = float(keep["total_earned"])
	taps = int(keep["taps"])
	boosts_used = int(keep["boosts_used"])
	prices = keep["prices"]
	price_hist = keep["price_hist"]
	hist_q = keep["hist_q"]
	hist_h = keep["hist_h"]
	moods = keep["moods"]
	coin_shift = keep["coin_shift"]
	trends = keep["trends"]
	fair_log = keep["fair_log"]
	news = keep["news"]
	mine_eff = keep["mine_eff"]
	achieved = keep["achieved"]
	counters = keep["counters"]
	daily = keep["daily"]
	weekly = keep["weekly"]
	deal_wait = float(keep["deal_wait"])
	div_hour = int(keep["div_hour"])
	ui = keep["ui"]
	streak = int(keep["streak"])
	streak_day = int(keep["streak_day"])
	sun_wait = float(keep["sun_wait"])
	sun_day = int(keep["sun_day"])
	sun_count = int(keep["sun_count"])
	vibrate = bool(keep["vibrate"])
	reduce_motion = bool(keep["reduce_motion"])
	started_at = float(keep["started_at"])
	rebirth = keep["rebirth"]
	casino = {"open": false, "chips": 0.0}   # chips are money: they go (the tree keeps the unlock)
	sci = keep_sci
	rebirth["count"] = int(rebirth.get("count", 0)) + 1
	rebirth["earned"] = int(rebirth.get("earned", 0)) + got
	_rb_cache = {}
	counters["run_started"] = now()
	cash = RebirthTree.start_cash(rb("start"))
	level = start_level()
	streak_unseen = []
	away_unseen = false
	GameLog.info("rebirth", "Rebirth %d: +%d RBP" % [rebirths(), got])
	_init_market()
	recalc()
	_record_history()
	save_game()
	flush_changes()
	return got


# ==== number formatting ===================================================

static func group(n: int) -> String:
	if absi(n) >= 1000000000000000:
		return money_short(float(n)).substr(1)  # very big counts read as 1.2Qa, not 19 digits
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
	[1e15, "Qa"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]


const CUR := "£"
static var sci := false   # number format setting: true shows 1.23e9 instead of 1.23B


static func money(v: float) -> String:
	## £12.50 under 1,000; £19,284 up to a billion; then £1.25B and £3.4T.
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if a < 1000.0:
		return sign + CUR + "%.2f" % a
	if a < 1e9:
		return sign + CUR + group(int(floor(a)))
	return money_short(v)


static func cash_text(v: float) -> String:
	## Cash to the penny while it fits on screen (£1,385.62). From ten million
	## it switches to four figures, like £177.9M.
	var a := absf(v)
	if a >= 1e7:
		return _short(v, 4)
	var whole := floorf(a)
	var pence := int(floor((a - whole) * 100.0 + 0.0001))
	return ("-" if v < 0.0 else "") + CUR + group(int(whole)) + ".%02d" % pence


static func money_short(v: float) -> String:
	## Three figures, no trailing zeros: £32K, £1.2M, £12.27M, £383K.
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if a < 999.5:
		return sign + (CUR + "%d" % int(round(a)) if a >= 100.0 else CUR + "%.2f" % a)
	return _short(v, 3)


static func _short(v: float, figs: int) -> String:
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if sci and a >= 1e6:
		var e := int(floor(log(a) / log(10.0)))
		var m := a / pow(10.0, e)
		if m >= 9.995:
			m /= 10.0
			e += 1
		return sign + CUR + ("%.2f" % m).rstrip("0").rstrip(".") + "e%d" % e
	for u in BIG_UNITS:
		if a >= float(u[0]) * 0.9995:
			var x: float = a / float(u[0])
			var dec := figs - (3 if x >= 100.0 else (2 if x >= 10.0 else 1))
			var t := ("%." + str(maxi(0, dec)) + "f") % x
			if t.contains("."):
				t = t.rstrip("0").rstrip(".")
			return sign + CUR + t + String(u[1])
	return sign + CUR + "%.2f" % a


static func clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 86400:
		return "%dd %dh" % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]

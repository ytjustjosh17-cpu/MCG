extends Node
## Global game state: money, levels, boost, saving and offline earnings.

signal changed
signal tapped(amount: float)

const SAVE_PATH := "user://save.json"
const OFFLINE_CAP_S := 8.0 * 3600.0
const BOOST_MULT := 3.0
const BOOST_LEN_S := 60.0
const BOOST_COOLDOWN_S := 600.0
const HISTORY_EVERY_S := 300.0
const HISTORY_MAX := 2100
const WEEK_S := 7.0 * 24.0 * 3600.0

var cash := 0.0
var total_earned := 0.0
var level := 1
var taps := 0
var boost_until := 0.0
var boost_ready_at := 0.0
var income_per_hour := 0.0  # filled by businesses later
var away_earned := 0.0
var history: Array = []  # [[unix_time, net_worth], ...]
var vibrate := true
var started_at := 0.0

var _dirty := false
var _save_timer := 0.0
var _hist_timer := 0.0
var _paused_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func now() -> float:
	return Time.get_unix_time_from_system()


# ---- economy -------------------------------------------------------------

func tap_value() -> float:
	return 2.5 * pow(1.64, level - 1)


func next_tap_value() -> float:
	return 2.5 * pow(1.64, level)


func level_cost() -> float:
	return 1000.0 * pow(3.28, level - 1)


func level_progress() -> float:
	return clampf(cash / level_cost(), 0.0, 1.0)


func can_level_up() -> bool:
	return cash >= level_cost()


func boost_active() -> bool:
	return now() < boost_until


func boost_left() -> float:
	return maxf(0.0, boost_until - now())


func boost_cooldown_left() -> float:
	return maxf(0.0, boost_ready_at - now())


func boost_ready() -> bool:
	return boost_cooldown_left() <= 0.0


func net_worth() -> float:
	return cash  # + business, shares, property and crypto values later


func companies() -> int:
	return 0


func tap() -> float:
	var v := tap_value() * (BOOST_MULT if boost_active() else 1.0)
	taps += 1
	_earn(v)
	tapped.emit(v)
	return v


func level_up() -> bool:
	if not can_level_up():
		return false
	cash -= level_cost()
	level += 1
	_mark()
	return true


func start_boost() -> bool:
	if not boost_ready():
		return false
	boost_until = now() + BOOST_LEN_S
	boost_ready_at = boost_until + BOOST_COOLDOWN_S
	_mark()
	return true


func week_change() -> Array:
	## Returns [start_value, current_value] for the past week, or [] if there is no history yet.
	if history.size() < 2:
		return []
	var cutoff := now() - WEEK_S
	var start_value: float = history[0][1]
	for p in history:
		if p[0] >= cutoff:
			start_value = p[1]
			break
	return [start_value, net_worth()]


func _earn(v: float) -> void:
	cash += v
	total_earned += v
	_mark()


func _mark() -> void:
	_dirty = true
	changed.emit()


func _record_history() -> void:
	history.append([now(), net_worth()])
	while history.size() > HISTORY_MAX:
		history.pop_front()


func _process(delta: float) -> void:
	if income_per_hour > 0.0:
		_earn(income_per_hour * delta / 3600.0)
	_hist_timer += delta
	if _hist_timer >= HISTORY_EVERY_S:
		_hist_timer = 0.0
		_record_history()
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
				_apply_offline(now() - _paused_at)
				_paused_at = 0.0


func _apply_offline(seconds: float) -> void:
	var s := clampf(seconds, 0.0, OFFLINE_CAP_S)
	var gained := income_per_hour * s / 3600.0
	away_earned = gained
	if gained > 0.0:
		_earn(gained)


# ---- saving --------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": 1,
		"saved_at": now(),
		"cash": cash,
		"total_earned": total_earned,
		"level": level,
		"taps": taps,
		"boost_until": boost_until,
		"boost_ready_at": boost_ready_at,
		"income_per_hour": income_per_hour,
		"history": history,
		"vibrate": vibrate,
		"started_at": started_at,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	_dirty = false


func load_game() -> void:
	started_at = now()
	if not FileAccess.file_exists(SAVE_PATH):
		_record_history()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable, starting fresh.")
		_record_history()
		return
	var d: Dictionary = parsed
	cash = float(d.get("cash", 0.0))
	total_earned = float(d.get("total_earned", 0.0))
	level = int(d.get("level", 1))
	taps = int(d.get("taps", 0))
	boost_until = float(d.get("boost_until", 0.0))
	boost_ready_at = float(d.get("boost_ready_at", 0.0))
	income_per_hour = float(d.get("income_per_hour", 0.0))
	vibrate = bool(d.get("vibrate", true))
	started_at = float(d.get("started_at", now()))
	history = d.get("history", [])
	var saved_at := float(d.get("saved_at", now()))
	_apply_offline(now() - saved_at)
	if history.is_empty():
		_record_history()


func reset_game() -> void:
	cash = 0.0
	total_earned = 0.0
	level = 1
	taps = 0
	boost_until = 0.0
	boost_ready_at = 0.0
	income_per_hour = 0.0
	away_earned = 0.0
	history = []
	started_at = now()
	_record_history()
	save_game()
	changed.emit()


# ---- number formatting ---------------------------------------------------

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
	## Compact form for tight spaces: $950, $19.2K, $4.66M, $1.25B.
	var a := absf(v)
	var sign := "-" if v < 0.0 else ""
	if a < 1000.0:
		return sign + "$%d" % int(round(a)) if a >= 100.0 else sign + "$%.2f" % a
	var units := [[1e15, "Q"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]
	for u in units:
		if a >= u[0]:
			var x: float = a / u[0]
			return sign + ("$%.1f%s" % [x, u[1]] if x >= 100.0 else "$%.2f%s" % [x, u[1]])
	return sign + "$%.2f" % a


static func clock(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]

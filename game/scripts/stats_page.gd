class_name StatsPage
extends Page
## Lifetime numbers, pushed from Profile.

var _list: VBoxContainer
var _rows := {}

const STATS := [
	["taps", "Taps"],
	["earned", "Earned in total"],
	["played", "Time played"],
	["best", "Best income"],
	["crits", "Critical taps"],
	["suns", "Golden suns caught"],
	["units", "Units bought"],
	["expansions", "Expansions"],
	["deals", "Deals taken"],
	["goals", "Goals done"],
	["achievements", "Achievements"],
	["mined", "Coins mined (value)"],
	["staked", "Staking earned"],
	["streak", "Days in a row"],
]


func _init() -> void:
	super("Stats", true)


func build() -> void:
	_list = card()
	for i in range(STATS.size()):
		if i > 0:
			separator(_list)
		var r := Row.new("", "", false)
		r.custom_minimum_size = Vector2(0, 48)
		r.set_texts(STATS[i][1])
		r.disabled = true
		r.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		_list.add_child(r)
		_rows[STATS[i][0]] = r


func refresh() -> void:
	if _list == null:
		return
	var c := Game.counters
	var vals := {
		"taps": Game.group(Game.taps),
		"earned": Game.money_short(Game.total_earned),
		"played": _played(float(c.get("play_s", 0.0))),
		"best": Game.money_short(float(c.get("best_income", Game.income_per_hour))) + " /h",
		"crits": Game.group(int(c.get("crits", 0))),
		"suns": Game.group(int(c.get("suns", 0))),
		"units": Game.group(int(c.get("units_bought", 0))),
		"expansions": Game.group(int(c.get("expansions", 0))),
		"deals": Game.group(int(c.get("deals", 0))),
		"goals": Game.group(int(c.get("goals_done", 0))),
		"achievements": "%d / %d" % [Game.achieved.size(), Game.achievements().size()],
		"mined": Game.money_short(float(c.get("mined_value", 0.0))),
		"staked": Game.money_short(float(c.get("stake_earned", 0.0))),
		"streak": str(Game.streak),
	}
	for k in vals.keys():
		(_rows[k] as Row).set_texts(_label(k), "", vals[k])


static func _label(k: String) -> String:
	for s in STATS:
		if s[0] == k:
			return s[1]
	return k


static func _played(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 60:
		return "%d min" % m
	if m < 60 * 48:
		return "%dh %02dm" % [m / 60, m % 60]
	return "%dd %dh" % [m / 1440, (m % 1440) / 60]

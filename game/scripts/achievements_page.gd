class_name AchievementsPage
extends Page
## Achievements as medals: one per kind, climbing a tier at a time, with a filter.

const FILTERS := [["all", "All"], ["taps", "Taps"], ["worth", "Net worth"], ["biz", "Companies"], ["invest", "Investing"], ["other", "Other"]]
const GROUP := {
	"taps": "taps", "boosts": "taps", "level": "taps",
	"worth": "worth", "home": "worth",
	"biz": "biz", "expansions": "biz", "managers": "biz", "synergies": "biz", "full50": "biz", "upgrades": "biz", "mergers": "biz", "deals": "biz", "rivals": "biz",
	"props": "invest", "shares": "invest", "crypto_profit": "invest", "dividends": "invest", "stake_earned": "invest",
}
const KIND_ICON := {"taps": "earn", "boosts": "bolt", "level": "level", "worth": "pie", "home": "home",
	"biz": "business", "expansions": "level", "managers": "profile", "mergers": "check", "deals": "coins",
	"rivals": "goal", "props": "home", "shares": "invest", "crypto_profit": "coins", "dividends": "coins",
	"stake_earned": "lock", "collections": "diamond", "suns": "star", "goals": "list", "synergies": "sparkle",
	"full50": "business", "upgrades": "gear"}
const MONEY := ["worth", "shares", "crypto_profit", "dividends", "stake_earned"]

static var _filter := "all"
var _pill: Button
var _bonus: Label
var _list: VBoxContainer
var _sig := ""
var _rows: Array = []


func _init() -> void:
	super("Achievements", true)


func build() -> void:
	_pill = Kit.drop_pill("All")
	_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_pill.pressed.connect(func():
		Kit.tick()
		Kit.pick("Show", FILTERS, _filter, func(v):
			_filter = v
			_sig = ""
			refresh()))
	Kit.press_fx(_pill)
	body.add_child(ClaimList.new(["ach"]))   # earned achievements wait here for a tap
	body.add_child(_pill)
	_bonus = UI.label("", 15, UI.SUB)
	body.add_child(_bonus)
	_list = card()


static func _label(v: String) -> String:
	for f in FILTERS:
		if f[0] == v:
			return f[1]
	return "All"


func refresh() -> void:
	if _list == null:
		return
	_pill.text = _label(_filter) + "  ▾"
	_bonus.text = "+%.1f%% income from achievements (max %d%%)" % [Game.ach_bonus() * 100.0, int(Data.ACH_BONUS_CAP * 100.0)]
	# One medal per kind of achievement. Waiting rewards first, then the ones
	# under way (closest first), finished medals last.
	var gs: Array = []
	for grp in Game.medal_groups():
		if _filter != "all" and String(GROUP.get(grp["metric"], "other")) != _filter:
			continue
		gs.append(grp)
	gs.sort_custom(func(x, y):
		return _rank(x) > _rank(y))
	var sig := _filter
	for grp in gs:
		sig += "|%s:%d:%d" % [grp["metric"], int(grp["level"]), _waiting(grp)]
	if sig != _sig:
		_sig = sig
		_rows.clear()
		for ch in _list.get_children():
			ch.queue_free()
		for i in range(gs.size()):
			if i > 0:
				separator(_list, 68)
			var grp: Dictionary = gs[i]
			var r := MedalRow.new(grp, KIND_ICON.get(String(grp["metric"]), "trophy"))
			_list.add_child(r)
			_rows.append(r)
	else:
		# Same medals in the same order: just update their progress.
		for i in range(mini(_rows.size(), gs.size())):
			(_rows[i] as MedalRow).set_group(gs[i])


static func _waiting(grp: Dictionary) -> int:
	var n := 0
	for t in grp["tiers"]:
		if t["done"] and not t["claimed"]:
			n += 1
	return n


static func _rank(grp: Dictionary) -> float:
	if _waiting(grp) > 0:
		return 3.0
	if int(grp["next"]) < 0:
		return 0.0   # every tier done
	return 1.0 + float(grp["progress"])


static func _progress(a: Dictionary) -> String:
	var have := minf(Game.metric(a["m"]), float(a["goal"]))
	if a["m"] in MONEY:
		return "%s / %s" % [Game.money_short(have), Game.money_short(a["goal"])]
	return "%s / %s" % [Game.group(int(have)), Game.group(int(a["goal"]))]

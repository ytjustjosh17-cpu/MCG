class_name AchievementsPage
extends Page
## Achievements with a filter. Locked first with progress, unlocked at the bottom.

const FILTERS := [["all", "All"], ["taps", "Taps"], ["worth", "Net worth"], ["biz", "Companies"], ["invest", "Investing"], ["other", "Other"]]
const GROUP := {
	"taps": "taps", "boosts": "taps", "level": "taps",
	"worth": "worth", "home": "worth",
	"biz": "biz", "expansions": "biz", "managers": "biz", "synergies": "biz", "full50": "biz", "upgrades": "biz", "mergers": "biz", "deals": "biz", "rivals": "biz",
	"props": "invest", "shares": "invest", "crypto_profit": "invest", "dividends": "invest", "stake_earned": "invest",
}
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
	var locked: Array = []
	var got: Array = []
	for a in Game.achievements():
		if _filter != "all" and String(GROUP.get(a["m"], "other")) != _filter:
			continue
		if Game.achieved.has(a["id"]):
			got.append(a)
		else:
			locked.append(a)
	# Rebuild only when the filter or the unlocked set changes; otherwise just retext.
	var sig := _filter + str(Game.achieved.size())
	if sig != _sig:
		_sig = sig
		_rows.clear()
		for ch in _list.get_children():
			ch.queue_free()
		var all := locked + got
		for i in range(all.size()):
			if i > 0:
				separator(_list, 50)
			var a: Dictionary = all[i]
			var done := i >= locked.size()
			var r := Row.new("check" if done else "lock", "", false)
			r.custom_minimum_size = Vector2(0, 56)
			var ic: Icon = r.lead
			ic.set_style(UI.TEXT if done else UI.DIM, done)
			r.title_l.add_theme_color_override("font_color", UI.TEXT if done else UI.SUB)
			r.value_l.add_theme_font_size_override("font_size", 13)
			r.value_l.add_theme_color_override("font_color", UI.SUB)
			_list.add_child(r)
			_rows.append([a, r, done])
	for e in _rows:
		var r: Row = e[1]
		r.set_texts(e[0]["title"], "" if e[2] else _progress(e[0]), "Done" if e[2] else "")


static func _progress(a: Dictionary) -> String:
	var have := minf(Game.metric(a["m"]), float(a["goal"]))
	if a["m"] in MONEY:
		return "%s / %s" % [Game.money_short(have), Game.money_short(a["goal"])]
	return "%s / %s" % [Game.group(int(have)), Game.group(int(a["goal"]))]

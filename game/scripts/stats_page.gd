class_name StatsPage
extends Page
## Charts and lifetime numbers, pushed from Profile. Net worth and income
## over time (1D, 1W, All), where income comes from, then the totals in two
## compact columns.

const RANGES := [86400.0, 604800.0, 0.0]   # 1D, 1W, All (0 = everything)

var _seg: Segmented
var _worth_chart: HistoryChart
var _income_chart: HistoryChart
var _worth_l: Label
var _income_l: Label
var _income_box: Control
var _mix: IncomeMix
var _grid: GridContainer
var _cells := {}
var _starts: Array = []   # the "start" label under each chart

const STATS := [
	["taps", "Taps"],
	["earned", "Earned in total"],
	["played", "Time played"],
	["best", "Best income"],
	["crits", "Big taps"],
	["suns", "Golden suns"],
	["units", "Units bought"],
	["expansions", "Expansions"],
	["deals", "Deals taken"],
	["goals", "Goals done"],
	["achievements", "Achievements"],
	["streak", "Days in a row"],
	["mined", "Mined"],
	["staked", "Locked coins earned"],
	["rebirths", "Rebirths"],
	["rbp", "RBP earned"],
	["casino_bet", "Casino bets"],
	["casino_net", "Casino result"],
]


func _init() -> void:
	super("Stats", true)


func build() -> void:
	_seg = Segmented.new(["1D", "1W", "All"])
	_seg.changed.connect(func(_i: int):
		Kit.tick()
		refresh())
	body.add_child(_seg)
	# Net worth over time.
	var wc := card()
	var wp := padded(wc, 16, 6)
	var wh := HBoxContainer.new()
	wp.add_child(wh)
	var wt := UI.label("Net worth", 13, UI.SUB)
	wt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wt)
	_worth_l = UI.label("", 15, UI.TEXT, true)
	wh.add_child(_worth_l)
	_worth_chart = HistoryChart.new(1)
	_worth_chart.custom_minimum_size = Vector2(0, 120)
	wp.add_child(_worth_chart)
	_axis(wp)
	# Income over time (needs the income saved with each history point).
	var ic := card()
	_income_box = ic.get_parent()
	var ip := padded(ic, 16, 6)
	var ih := HBoxContainer.new()
	ip.add_child(ih)
	var it := UI.label("Income per hour", 13, UI.SUB)
	it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(it)
	_income_l = UI.label("", 15, UI.TEXT, true)
	ih.add_child(_income_l)
	_income_chart = HistoryChart.new(2)
	_income_chart.custom_minimum_size = Vector2(0, 100)
	ip.add_child(_income_chart)
	_axis(ip)
	# Where income comes from.
	var mc := card()
	var mp := padded(mc, 16, 8)
	mp.add_child(UI.label("Income comes from", 13, UI.SUB))
	_mix = IncomeMix.new()
	mp.add_child(_mix)
	# Totals, two columns.
	var tc := card()
	var tp := padded(tc, 16, 0)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 12)
	tp.add_child(_grid)
	for s in STATS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		var name_l := UI.label(String(s[1]), 13, UI.SUB)
		var val_l := UI.label("", 17, UI.TEXT, true)
		val_l.clip_text = true
		val_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(name_l)
		cell.add_child(val_l)
		_grid.add_child(cell)
		_cells[s[0]] = val_l


func _axis(parent: Control) -> void:
	## Where the line starts and ends, in plain words, under a chart.
	var h := HBoxContainer.new()
	parent.add_child(h)
	var a := UI.label("", 13, UI.SUB)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UI.label("Now", 13, UI.SUB))
	_starts.append(a)


func refresh() -> void:
	if _grid == null:
		return
	var start: String = ["24 hours ago", "7 days ago", "Start"][_seg.index]
	for a in _starts:
		(a as Label).text = start
	var span: float = RANGES[_seg.index]
	_worth_chart.span = span
	_income_chart.span = span
	_worth_chart.queue_redraw()
	_income_chart.queue_redraw()
	_worth_l.text = Game.money_short(Game.net_worth())
	_income_l.text = Game.money_short(Game.income_per_hour) + " /h"
	_income_box.visible = HistoryChart.has_income()
	_mix.queue_redraw()
	var c := Game.counters
	var bet := float(c.get("casino_bet", 0.0))
	var won := float(c.get("casino_won", 0.0))
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
		"streak": str(Game.streak),
		"mined": Game.money_short(float(c.get("mined_value", 0.0))),
		"staked": Game.money_short(float(c.get("stake_earned", 0.0))),
		"rebirths": str(Game.rebirths()),
		"rbp": Game.group(int(Game.rebirth.get("earned", 0))),
		"casino_bet": Game.money_short(bet),
		"casino_net": ("+" if won >= bet else "-") + Game.money_short(absf(won - bet)),
	}
	for k in vals.keys():
		(_cells[k] as Label).text = String(vals[k])


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


class HistoryChart extends Control:
	## One clean line from Game.history: field 1 = net worth, 2 = income per
	## hour (only in points saved with it). span: seconds shown (0 = all).
	var field := 1
	var span := 86400.0

	func _init(f := 1) -> void:
		field = f
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	static func has_income() -> bool:
		for p in Game.history:
			if (p as Array).size() > 2:
				return true
		return false

	func _values() -> Array:
		var cutoff := Game.now() - span if span > 0.0 else -1.0e18
		var out: Array = []
		for p in Game.history:
			var a: Array = p
			if float(a[0]) >= cutoff and a.size() > field:
				out.append(float(a[field]))
		out.append(Game.net_worth() if field == 1 else Game.income_per_hour)
		# Long histories: thin out to about 160 points (fast to draw).
		if out.size() > 160:
			var step := float(out.size()) / 160.0
			var thin: Array = []
			var i := 0.0
			while int(i) < out.size() - 1:
				thin.append(out[int(i)])
				i += step
			thin.append(out[out.size() - 1])
			out = thin
		return out

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 20.0 or h < 20.0:
			return
		var vals := _values()
		if vals.size() < 2:
			draw_dashed_line(Vector2(0, h * 0.6), Vector2(w, h * 0.6), UI.TRACK, 1.0, 4.0)
			var f: Font = UI.REG
			draw_string(f, Vector2(0, h * 0.6 - 10.0), "Not enough history yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.SUB)
			return
		var lo: float = vals.min()
		var hi: float = vals.max()
		if hi - lo < 0.01:
			hi = lo + 1.0
		var line := PackedVector2Array()
		var x_end := w - 8.0
		for i in range(vals.size()):
			var x := x_end * float(i) / float(vals.size() - 1)
			var y := h - 6.0 - (float(vals[i]) - lo) / (hi - lo) * (h - 14.0)
			line.append(Vector2(x, y))
		var area := PackedVector2Array(line)
		area.append(Vector2(line[line.size() - 1].x, h))
		area.append(Vector2(0, h))
		var cols := PackedColorArray()
		for p in area:
			cols.append(Color(UI.TEXT, 0.12 * (1.0 - clampf(p.y / h, 0.0, 1.0))))
		draw_polygon(area, cols)
		draw_polyline(line, UI.TEXT, 2.0, true)
		draw_circle(line[line.size() - 1], 4.0, UI.RED)


class IncomeMix extends Control:
	## A single stacked bar: companies, rent, dividends, mining, with a legend.
	func _init() -> void:
		custom_minimum_size = Vector2(0, 66)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _parts() -> Array:
		var p: Dictionary = Game._income_parts
		return [
			["Companies", float(p.get("biz", 0.0)), UI.TEXT],
			["Rent", float(p.get("rent", 0.0)), UI.SUB],
			["Dividends", float(p.get("div", 0.0)), UI.GOLD],
			["Mining", Game.mining_value_per_hour(), UI.UP],
		]

	func _draw() -> void:
		var parts := _parts()
		var total := 0.0
		for pt in parts:
			total += float(pt[1])
		var w := size.x
		var bar := Rect2(0, 4, w, 12)
		draw_rect(bar, UI.TRACK)
		if total > 0.0:
			var x := 0.0
			for pt in parts:
				var pw := w * float(pt[1]) / total
				if pw > 0.5:
					draw_rect(Rect2(x, 4, pw, 12), pt[2])
				x += pw
		# Legend in two columns.
		var f: Font = UI.REG
		for i in range(parts.size()):
			var pt: Array = parts[i]
			var cx := (w * 0.5) * float(i % 2)
			var cy := 34.0 + 22.0 * float(i / 2)
			draw_circle(Vector2(cx + 5.0, cy - 4.0), 4.0, pt[2])
			var pct := 0 if total <= 0.0 else int(round(float(pt[1]) / total * 100.0))
			draw_string(f, Vector2(cx + 14.0, cy), "%s %d%%" % [pt[0], pct], HORIZONTAL_ALIGNMENT_LEFT, w * 0.5 - 16.0, 13, UI.SUB)

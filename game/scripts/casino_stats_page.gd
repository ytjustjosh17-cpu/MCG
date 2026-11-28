class_name CasinoStatsPage
extends Page
## Casino stats, pushed from the casino lobby: the all-time result in big
## type, the totals in two columns, then each game you've played with its
## rounds, how often it paid, its best win and its result.

const TOTALS := [
	["rounds", "Rounds played"],
	["return", "Paid back"],
	["bet", "Bet in total"],
	["won", "Won in total"],
	["best", "Biggest win"],
	["jackpots", "Jackpots"],
	["best_jp", "Best jackpot"],
	["wheel", "Wheel spins"],
	["chips_in", "Chips bought"],
	["chips_out", "Cashed out"],
]

var _net: Label
var _net_sub: Label
var _cells := {}
var _games: VBoxContainer
var _sig := ""


func _init() -> void:
	super("Casino stats", true)


func build() -> void:
	var hc := card()
	var hp := padded(hc, 16, 14)
	hp.add_child(UI.label("All-time result", 13, UI.SUB))
	_net = UI.display("", 40, UI.TEXT)
	hp.add_child(_net)
	_net_sub = UI.label("", 13, UI.SUB)
	_net_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hp.add_child(_net_sub)
	var tc := card()
	var tp := padded(tc, 16, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	tp.add_child(grid)
	for s in TOTALS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UI.label(String(s[1]), 13, UI.SUB))
		var v := UI.label("", 17, UI.TEXT, true)
		v.clip_text = true
		v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.add_child(v)
		grid.add_child(cell)
		_cells[s[0]] = v
	section("By game")
	_games = card()
	refresh()


func refresh() -> void:
	if _net == null:
		return
	var c: Dictionary = Game.counters
	var bet := float(c.get("casino_bet", 0.0))
	var won := float(c.get("casino_won", 0.0))
	var net := won - bet
	_net.text = ("+" if net >= 0.0 else "-") + Game.money_short(absf(net))
	_net.add_theme_color_override("font_color", UI.TEXT if net >= 0.0 else UI.SUB)
	_net_sub.text = "Won %s from %s bet. The house keeps a small edge, so over time you lose a little." % [Game.money_short(won), Game.money_short(bet)]
	var best_at := float(c.get("casino_best_at", 0.0))
	var vals := {
		"rounds": Game.group(int(c.get("casino_rounds", 0))),
		"return": ("%.1f%%" % (won / bet * 100.0)) if bet > 0.0 else "-",
		"bet": Game.money_short(bet),
		"won": Game.money_short(won),
		"best": Game.money_short(float(c.get("casino_best", 0.0))) + (("  " + RecordsPage.when_text(best_at, "").trim_prefix("Set ")) if best_at > 0.0 else ""),
		"jackpots": Game.group(int(c.get("jackpots", 0.0))),
		"best_jp": Game.money_short(float(c.get("best_jackpot", 0.0))) if float(c.get("best_jackpot", 0.0)) > 0.0 else "-",
		"wheel": Game.group(int(c.get("wheel_spins", 0.0))),
		"chips_in": Game.money_short(float(c.get("chips_in", 0.0))),
		"chips_out": Game.money_short(float(c.get("chips_out", 0.0))) if float(c.get("chips_out", 0.0)) > 0.0 else "-",
	}
	for k in vals.keys():
		(_cells[k] as Label).text = String(vals[k])
	_games_list()


func _games_list() -> void:
	## One row per game played, most played first. Rebuilt only when it changes.
	var played: Array = []
	for gm in CasinoPage.GAMES:
		var st: Dictionary = Game.casino_game_stats(String(gm[0]))
		if float(st.get("rounds", 0.0)) > 0.0:
			played.append([gm, st])
	played.sort_custom(func(a, b): return float(a[1]["rounds"]) > float(b[1]["rounds"]))
	var sig := JSON.stringify(played.map(func(p): return [p[0][0], p[1]]))
	if sig == _sig:
		return
	_sig = sig
	for ch in _games.get_children():
		ch.queue_free()
	if played.is_empty():
		var m := padded(_games, 16, 0)
		var l := UI.label("Play a game and its stats show here. Counting started in version 1.2.", 15, UI.SUB)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.add_child(l)
		return
	for i in range(played.size()):
		var gm: Array = played[i][0]
		var st: Dictionary = played[i][1]
		if i > 0:
			separator(_games, 68)
		var rounds := float(st.get("rounds", 0.0))
		var g_bet := float(st.get("bet", 0.0))
		var g_won := float(st.get("won", 0.0))
		var g_net := g_won - g_bet
		var r := Row.new("", "", false)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_lead(CasinoPage.CasinoArt.new(String(gm[0]), 40.0))
		var sub := "%s rounds · %d%% paid" % [Game.group(int(rounds)), int(round(float(st.get("wins", 0.0)) / rounds * 100.0))]
		if float(st.get("jackpots", 0.0)) > 0.0:
			sub += " · %d jackpot%s" % [int(st["jackpots"]), "" if int(st["jackpots"]) == 1 else "s"]
		var best := ("best " + Game.money_short(float(st["best"]))) if float(st.get("best", 0.0)) > 0.0 else ""
		r.set_texts(String(gm[1]), sub, ("+" if g_net >= 0.0 else "-") + Game.money_short(absf(g_net)), best)
		_games.add_child(r)

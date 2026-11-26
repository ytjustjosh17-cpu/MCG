class_name CasinoPage
extends Page
## Sol Casino: the cage (buy chips, cash out), the table limits and the games.
## Opened by unlock nodes in the RBP tree: Sol Casino (slots) and High
## tables (roulette and blackjack). Tree nodes last through every rebirth.

const GAMES := [
	# id, title, subtitle, page script, arg
	["forge", "Sun Forge", "Tumbles · sun orbs · buy free spins", "res://scripts/forge_page.gd", "forge"],
	["classic", "Red Sun Classic", "Slots · steady, small wins", "res://scripts/slots_page.gd", "classic"],
	["neon", "Neon Reef", "Slots · balanced", "res://scripts/slots_page.gd", "neon"],
	["vault", "Iron Vault", "Slots · rare, big wins", "res://scripts/slots_page.gd", "vault"],
	["roulette", "Roulette", "European wheel · single zero", "res://scripts/roulette_page.gd", ""],
	["blackjack", "Blackjack", "Six decks · blackjack pays 3 to 2", "res://scripts/blackjack_page.gd", ""],
]

var _locked: VBoxContainer
var _unlock: Button
var _open: VBoxContainer
var _chips: Label
var _limits: Label
var _stats: Label
var _table_rows: Array = []


func _init() -> void:
	super("Casino", true)


func build() -> void:
	var sign := CasinoArt.new("sign")
	sign.custom_minimum_size = Vector2(0, 120)
	sign.clip_contents = true
	var sc := card()
	sc.add_child(sign)
	# Locked: one clear price and one button.
	_locked = VBoxContainer.new()
	_locked.add_theme_constant_override("separation", 10)
	body.add_child(_locked)
	var l := UI.label("Unlocks with Sol Casino in the Rebirth tree.", 15, UI.SUB)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_locked.add_child(l)
	_unlock = UI.pill("", UI.TEXT, UI.INK, 17, 24)
	_unlock.custom_minimum_size = Vector2(0, 52)
	_unlock.pressed.connect(_on_unlock)
	Kit.press_fx(_unlock)
	_locked.add_child(_unlock)
	# Open: the cage and the games.
	_open = VBoxContainer.new()
	_open.add_theme_constant_override("separation", 12)
	body.add_child(_open)
	var cage := PanelContainer.new()
	cage.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16, 16, 14))
	_open.add_child(cage)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cage.add_child(cv)
	cv.add_child(UI.label("Your chips", 13, UI.SUB))
	_chips = UI.display("", 36)
	cv.add_child(_chips)
	_limits = UI.label("", 13, UI.SUB)
	_limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_limits)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	cv.add_child(row)
	var buy := UI.pill("Buy chips", UI.TEXT, UI.INK, 17, 16)
	buy.custom_minimum_size = Vector2(0, 48)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.pressed.connect(func():
		Kit.tick()
		if Game.cash < 0.01:
			Kit.toast("No cash to spend")
			return
		TradeSheet.open("chips", "", "chips_in"))
	Kit.press_fx(buy)
	row.add_child(buy)
	var out := UI.pill("Cash out", UI.RAISED, UI.TEXT, 17, 16)
	out.custom_minimum_size = Vector2(0, 48)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	out.pressed.connect(func():
		Kit.tick()
		if Game.chips() < 0.01:
			Kit.toast("No chips to cash out")
			return
		TradeSheet.open("chips", "", "chips_out"))
	Kit.press_fx(out)
	row.add_child(out)
	_open.add_child(UI.label("Games", 17, UI.TEXT, true))
	var list := PanelContainer.new()
	list.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	_open.add_child(list)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 0)
	list.add_child(lv)
	for i in range(GAMES.size()):
		var gm: Array = GAMES[i]
		if i > 0:
			var sep := ColorRect.new()
			sep.color = UI.RAISED
			sep.custom_minimum_size = Vector2(0, 1)
			lv.add_child(sep)
		var r := Row.new("", "", true)
		r.set_lead(CasinoArt.new(String(gm[0]), 48.0))
		r.set_texts(String(gm[1]), String(gm[2]))
		var path: String = gm[3]
		var arg: String = gm[4]
		var table := arg == ""
		if table:
			_table_rows.append(r)
		r.pressed.connect(func():
			Kit.tick()
			if table and not Game.tables_open():
				Kit.sheet("High tables", "Roulette and blackjack open with the High tables node in your Rebirth tree (%d RBP from what you own)." % Game.path_cost("u_tables"), [
					{"text": "Open the tree", "style": "primary", "call": func(): push_page.emit(RebirthPage.new())},
					{"text": "Close", "style": "plain"}])
				return
			var pg = load(path).new(arg) if arg != "" else load(path).new()
			push_page.emit(pg))
		lv.add_child(r)
	_stats = UI.label("", 13, UI.SUB)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_open.add_child(_stats)
	var fine := UI.label("Play for fun. Every game pays back a little less than you put in over time (slots about 95%, roulette 97.3%, blackjack about 99.4% with good play).", 13, UI.DIM)
	fine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_open.add_child(fine)


func refresh() -> void:
	if _chips == null:
		return
	var open := Game.casino_open()
	_locked.visible = not open
	_open.visible = open
	if not open:
		var need := Game.path_cost("u_casino")
		_unlock.text = ("Open the tree · %d RBP" % need) if Game.rebirths() > 0 else ("Rebirth first, then %d RBP" % need)
		Page.set_enabled(_unlock, true)
		return
	for tr in _table_rows:
		(tr as Row).modulate.a = 1.0 if Game.tables_open() else 0.55
	_chips.text = Game.money(Game.chips())
	_limits.text = "Max bet %s · max win %s a round (they grow with your income)" % [Game.money_short(Game.casino_max_bet()), Game.money_short(Game.casino_max_win())]
	var bet := float(Game.counters.get("casino_bet", 0.0))
	var won := float(Game.counters.get("casino_won", 0.0))
	_stats.visible = bet > 0.0
	_stats.text = "All time: bet %s · won %s · %s %s" % [Game.money_short(bet), Game.money_short(won), "up" if won >= bet else "down", Game.money_short(absf(won - bet))]


func _on_unlock() -> void:
	Kit.tick()
	push_page.emit(RebirthPage.new())


class CasinoArt extends Control:
	## Small drawings for the casino: the sign, each slot machine, the wheel
	## and a blackjack hand. kind: sign, classic, neon, vault, roulette, blackjack.
	var kind := "sign"
	var _t := 0.0

	func _init(k := "sign", side := 0.0) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side > 0.0:
			custom_minimum_size = Vector2(side, side)

	func _process(delta: float) -> void:
		if kind == "sign" and is_visible_in_tree() and not Game.reduce_motion:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var s := size
		match kind:
			"sign":
				draw_rect(Rect2(Vector2.ZERO, s), UI.SKY)
				# A red sun rising behind a concrete block with a lit marquee.
				draw_circle(Vector2(s.x * 0.5, s.y * 0.5), s.y * 0.36, UI.RED)
				draw_rect(Rect2(Vector2(0, s.y * 0.78), Vector2(s.x, s.y * 0.22)), UI.FAR)
				var blk := Rect2(Vector2(s.x * 0.14, s.y * 0.46), Vector2(s.x * 0.72, s.y * 0.54))
				draw_rect(blk, UI.SIDE)
				draw_rect(Rect2(blk.position, Vector2(blk.size.x, 3)), UI.TRACK)
				for i in 11:
					var on := fmod(_t * 3.0 + float(i) * 0.7, 2.0) < 1.4
					draw_circle(Vector2(blk.position.x + 10.0 + (blk.size.x - 20.0) * float(i) / 10.0, blk.position.y + 10.0), 2.5, UI.GOLD if on else UI.TRACK)
				var f: Font = UI.DISPLAY
				draw_string(f, Vector2(blk.position.x, blk.position.y + blk.size.y * 0.72), "SOL CASINO", HORIZONTAL_ALIGNMENT_CENTER, blk.size.x, 28, UI.TEXT)
			"forge":
				# A furnace window: an iron frame, a molten seam, gems inside.
				var fr := Rect2(Vector2(s.x * 0.08, s.y * 0.14), Vector2(s.x * 0.84, s.y * 0.72))
				draw_rect(fr, UI.SIDE)
				draw_rect(Rect2(fr.position, Vector2(fr.size.x, 3.0)), UI.RED)
				var inner := fr.grow(-4.0)
				draw_rect(inner, UI.INK)
				var cw := inner.size.x / 3.0
				var ch := inner.size.y / 2.0
				var gems := [6, 8, 0, 10, 3, 9]
				for gi in 6:
					var gc := inner.position + Vector2(cw * (float(gi % 3) + 0.5), ch * (float(gi / 3) + 0.5))
					ForgePage.ForgeGrid.draw_symbol(self, gems[gi], 5, gc, minf(cw, ch) * 1.15, 1.0, 1.0)
			"classic", "neon", "vault":
				var body: Color = {"classic": UI.RED, "neon": UI.SLOT_COL["wild"], "vault": UI.DIM}[kind]
				var r := Rect2(Vector2(s.x * 0.16, s.y * 0.08), Vector2(s.x * 0.62, s.y * 0.86))
				draw_rect(r, body)
				draw_rect(Rect2(r.position + Vector2(4, s.y * 0.2), Vector2(r.size.x - 8, s.y * 0.32)), UI.INK)
				var syms: Array = {"classic": ["seven", "sun", "seven"], "neon": ["wild", "bell", "wild"], "vault": ["crown", "bar", "crown"]}[kind]
				for i in 3:
					draw_circle(r.position + Vector2(8 + (r.size.x - 16) * (0.17 + 0.33 * i), s.y * 0.36), s.x * 0.06, UI.SLOT_COL[syms[i]])
				draw_rect(Rect2(r.position + Vector2(6, s.y * 0.62), Vector2(r.size.x - 12, 4)), UI.INK)
				# Lever.
				draw_line(Vector2(r.end.x, s.y * 0.5), Vector2(s.x * 0.9, s.y * 0.5), UI.SUB, 2.0)
				draw_line(Vector2(s.x * 0.9, s.y * 0.5), Vector2(s.x * 0.9, s.y * 0.18), UI.SUB, 2.0)
				draw_circle(Vector2(s.x * 0.9, s.y * 0.16), 4.0, UI.SUB)   # not red: red dots mean "claim"
			"roulette":
				var c := s * 0.5
				var rad := minf(s.x, s.y) * 0.46
				for i in 37:
					var a0 := TAU * float(i) / 37.0
					var a1 := TAU * float(i + 1) / 37.0
					var col: Color = UI.ROUL_GREEN if i == 0 else (UI.ROUL_RED if i % 2 == 1 else UI.ROUL_BLACK)
					draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rad, c + Vector2(cos(a1), sin(a1)) * rad]), col)
				draw_circle(c, rad * 0.55, UI.FELT)
				draw_circle(c, rad * 0.2, UI.GOLD)
				draw_circle(c + Vector2(rad * 0.75, -rad * 0.3), 3.0, UI.TEXT)
			"blackjack":
				var a := load("res://assets/cards/cardSpadesA.png") as Texture2D
				var k := load("res://assets/cards/cardHeartsK.png") as Texture2D
				var h := s.y * 0.86
				var w := h * 140.0 / 190.0
				if a and k:
					draw_set_transform(Vector2(s.x * 0.3, s.y * 0.1), -0.18)
					draw_texture_rect(a, Rect2(Vector2.ZERO, Vector2(w, h)), false)
					draw_set_transform(Vector2(s.x * 0.42, s.y * 0.06), 0.14)
					draw_texture_rect(k, Rect2(Vector2.ZERO, Vector2(w, h)), false)
					draw_set_transform(Vector2.ZERO, 0.0)

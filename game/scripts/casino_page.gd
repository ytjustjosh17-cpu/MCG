class_name CasinoPage
extends Page
## Sol Casino: the cage (buy chips, cash out), the table limits and the games.
## Opened by unlock nodes in the RBP tree: Sol Casino (slots) and High
## tables (roulette and blackjack). Tree nodes last through every rebirth.

const GAMES := [
	# id, title, subtitle, page script, arg, gate ("slots" = Sol Casino, "tables" = High tables)
	["forge", "Sun Forge", "Tumbles · sun orbs · buy free spins", "res://scripts/forge_page.gd", "forge", "slots"],
	["classic", "Red Sun Classic", "Slots · steady, small wins", "res://scripts/slots_page.gd", "classic", "slots"],
	["neon", "Neon Reef", "Slots · balanced", "res://scripts/slots_page.gd", "neon", "slots"],
	["vault", "Iron Vault", "Slots · rare, big wins", "res://scripts/slots_page.gd", "vault", "slots"],
	["crash", "Crash", "Cash out before it crashes", "res://scripts/crash_page.gd", "", "slots"],
	["plinko", "Plinko", "Drop a ball · three risk levels", "res://scripts/plinko_page.gd", "", "slots"],
	["roulette", "Roulette", "European wheel · single zero", "res://scripts/roulette_page.gd", "", "tables"],
	["blackjack", "Blackjack", "Six decks · blackjack pays 3 to 2", "res://scripts/blackjack_page.gd", "", "tables"],
	["poker", "Video poker", "Jacks or better · hold and draw", "res://scripts/video_poker_page.gd", "", "tables"],
	["races", "Races", "Back a car · six runners", "res://scripts/race_page.gd", "", "tables"],
	["tower", "Tower", "Climb row by row · cash out any time", "res://scripts/tower_page.gd", "", "tables"],
]

var _locked: VBoxContainer
var _unlock: Button
var _open: VBoxContainer
var _chips: Label
var _jp: Label
var _limits: Label
var _stats: Label
var _table_rows: Array = []
var _wheel_row: Row


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
	# The shared jackpot: one gold line of hope, not a flashing sign.
	var jc := PanelContainer.new()
	jc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16, 16, 14))
	_open.add_child(jc)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 2)
	jc.add_child(jv)
	jv.add_child(UI.label("Jackpot", 13, UI.GOLD, true))
	_jp = UI.display("", 36, UI.GOLD)
	jv.add_child(_jp)
	var jl := UI.label("Super rare on any bet, in every game but blackjack and video poker. A max bet wins it all.", 13, UI.SUB)
	jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jv.add_child(jl)
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
	# The free daily wheel.
	var wc := PanelContainer.new()
	wc.add_theme_stylebox_override("panel", UI.box(UI.PANEL, 16))
	_open.add_child(wc)
	_wheel_row = Row.new("", "", true)
	_wheel_row.set_lead(CasinoArt.new("wheel", 40.0))
	_wheel_row.pressed.connect(func():
		Kit.tick()
		WheelSheet.open())
	wc.add_child(_wheel_row)
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
			separator(lv, 68)   # inset under the text, past the thumbnail
		var r := Row.new("", "", true)
		r.set_lead(CasinoArt.new(String(gm[0]), 40.0))
		r.set_texts(String(gm[1]), String(gm[2]))
		var path: String = gm[3]
		var arg: String = gm[4]
		var table: bool = gm[5] == "tables"
		if table:
			_table_rows.append(r)
		r.pressed.connect(func():
			Kit.tick()
			if table and not Game.tables_open():
				Kit.sheet("High tables", "Unlock High tables in the Rebirth tree (%d RBP)." % Game.path_cost("u_tables"), [
					{"text": "Open the tree", "style": "primary", "call": func(): push_page.emit(RebirthPage.new())},
					{"text": "Close", "style": "plain"}])
				return
			var pg = load(path).new(arg) if arg != "" else load(path).new()
			push_page.emit(pg))
		lv.add_child(r)
	_stats = UI.label("", 13, UI.SUB)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_open.add_child(_stats)
	var fine := UI.label("The house keeps a small edge: slots ~95%, crash 97%, plinko ~98%, roulette 97.3%, races 95%, tower 97%, blackjack and poker ~99%.", 13, UI.SUB)
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
	# A jackpot won on a round that was walked away from is paid and shown here.
	var left := Game.settle_jackpot()
	if left > 0.0:
		Kit.celebrate("Jackpot", "Won on your last round", "+" + Game.money_short(left))
	_jp.text = Game.money_short(Game.jackpot_pot())
	_chips.text = Game.money(Game.chips())
	_wheel_row.set_texts("Daily wheel", "Free spin ready" if Game.wheel_ready() else "Next spin tomorrow", "Spin" if Game.wheel_ready() else "")
	_limits.text = "Max bet %s · max win %s a round" % [Game.money_short(Game.casino_max_bet()), Game.money_short(Game.casino_max_win())]
	var bet := float(Game.counters.get("casino_bet", 0.0))
	var won := float(Game.counters.get("casino_won", 0.0))
	_stats.visible = bet > 0.0
	_stats.text = "All time: bet %s, won %s" % [Game.money_short(bet), Game.money_short(won)]


func _on_unlock() -> void:
	Kit.tick()
	push_page.emit(RebirthPage.new())


class CasinoArt extends Control:
	## Small drawings for the casino: the sign, each slot machine, the wheel
	## and a blackjack hand. kind: sign, classic, neon, vault, roulette, blackjack.
	var kind := "sign"
	var _t := 0.0
	var _acc := 0.0

	func _init(k := "sign", side := 0.0) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if side > 0.0:
			custom_minimum_size = Vector2(side, side)
		set_process(k == "sign")

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or Game.reduce_motion:
			return
		# The marquee lights chase at 15 frames a second: plenty, and it saves battery.
		_t += delta
		_acc += delta
		if _acc >= 1.0 / 15.0:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var s := size
		if kind != "sign":
			# Every game thumbnail sits on a small bevelled tile.
			var tr := Rect2(Vector2.ZERO, s)
			draw_colored_polygon(UI.rounded_rect_poly(tr, 10.0), UI.SIDE)
			draw_polyline(CasinoGame._top_edge(tr.grow(-1.0), 9.0), Color(UI.TEXT, 0.12), 1.0, true)
		match kind:
			"sign":
				# Night sky in soft bands, the red sun glowing behind the casino.
				draw_rect(Rect2(Vector2.ZERO, s), UI.SKY)
				for k in 4:
					draw_rect(Rect2(Vector2(0, s.y * 0.2 * float(k)), Vector2(s.x, s.y * 0.2)), Color(UI.HAZE, 0.06 * float(k)))
				var sun := Vector2(s.x * 0.5, s.y * 0.48)
				draw_circle(sun, s.y * 0.5, Color(UI.RED, 0.06))
				draw_circle(sun, s.y * 0.43, Color(UI.RED, 0.1))
				draw_circle(sun, s.y * 0.36, UI.RED)
				draw_rect(Rect2(Vector2(0, s.y * 0.8), Vector2(s.x, s.y * 0.2)), UI.FAR)
				# The building: a concrete block with columns and lit windows.
				var blk := Rect2(Vector2(s.x * 0.12, s.y * 0.42), Vector2(s.x * 0.76, s.y * 0.58))
				draw_rect(Rect2(blk.position + Vector2(4, 4), blk.size), Color(UI.INK, 0.5))
				draw_rect(blk, UI.SIDE)
				draw_rect(Rect2(blk.position, Vector2(blk.size.x, 3)), UI.TRACK)
				var cols := 6
				for ci in cols + 1:
					var cx := blk.position.x + 6.0 + (blk.size.x - 12.0) * float(ci) / float(cols)
					draw_rect(Rect2(Vector2(cx - 2.0, blk.position.y + s.y * 0.2), Vector2(4.0, blk.size.y - s.y * 0.2)), UI.SIDE.lerp(UI.RAISED, 0.6))
				for wi in cols:
					var wx := blk.position.x + 6.0 + (blk.size.x - 12.0) * (float(wi) + 0.5) / float(cols)
					var lit := wi != 1 and wi != 4
					draw_rect(Rect2(Vector2(wx - 5.0, blk.position.y + s.y * 0.24), Vector2(10.0, 7.0)), Color(UI.GOLD, 0.55) if lit else UI.WINDOW)
				# The marquee: a framed sign with chasing bulbs all round.
				var mq := Rect2(Vector2(blk.position.x + 8.0, blk.position.y - s.y * 0.06), Vector2(blk.size.x - 16.0, s.y * 0.22))
				draw_rect(Rect2(mq.position + Vector2(3, 3), mq.size), Color(UI.INK, 0.5))
				draw_rect(mq, UI.SIDE.lerp(UI.RAISED, 0.3))
				draw_rect(mq.grow(-5.0), UI.INK)
				var perim := 2.0 * (mq.size.x + mq.size.y)
				var nb := int(perim / 12.0)
				for i in nb:
					var d := perim * float(i) / float(nb)
					var bp := Vector2.ZERO
					if d < mq.size.x:
						bp = mq.position + Vector2(d, 2.5)
					elif d < mq.size.x + mq.size.y:
						bp = mq.position + Vector2(mq.size.x - 2.5, d - mq.size.x)
					elif d < 2.0 * mq.size.x + mq.size.y:
						bp = mq.position + Vector2(mq.size.x - (d - mq.size.x - mq.size.y), mq.size.y - 2.5)
					else:
						bp = mq.position + Vector2(2.5, mq.size.y - (d - 2.0 * mq.size.x - mq.size.y))
					var on := fmod(_t * 3.0 + float(i) * 0.5, 2.0) < 1.2
					if on:
						draw_circle(bp, 3.2, Color(UI.GOLD, 0.25))
					draw_circle(bp, 1.8, UI.GOLD if on else UI.TRACK)
				var f: Font = UI.DISPLAY
				draw_string(f, Vector2(mq.position.x, mq.position.y + mq.size.y * 0.74), "SOL CASINO", HORIZONTAL_ALIGNMENT_CENTER, mq.size.x, 28, UI.TEXT)
				# The entrance: warm light through the doors, a canopy and two steps.
				var door := Rect2(Vector2(s.x * 0.5 - s.x * 0.09, s.y * 0.8), Vector2(s.x * 0.18, s.y * 0.2))
				draw_rect(Rect2(door.position - Vector2(4, 0), door.size + Vector2(8, 0)), Color(UI.GOLD, 0.12))
				draw_rect(door, Color(UI.GOLD, 0.55))
				draw_line(Vector2(door.get_center().x, door.position.y), Vector2(door.get_center().x, door.end.y), UI.SIDE, 2.0)
				draw_rect(Rect2(Vector2(door.position.x - 10.0, door.position.y - 5.0), Vector2(door.size.x + 20.0, 5.0)), UI.TRACK)
				draw_rect(Rect2(Vector2(door.position.x - 6.0, s.y - 4.0), Vector2(door.size.x + 12.0, 4.0)), UI.RAISED)
				# Round the corners like every other picture card.
				for piece in Geometry2D.clip_polygons(UI.rect_poly(Rect2(Vector2.ZERO, s)), UI.rounded_rect_poly(Rect2(Vector2.ZERO, s), 16.0)):
					if not Geometry2D.is_polygon_clockwise(piece):
						draw_colored_polygon(piece, UI.BG)
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
				# Tonal cabinets (red is for the one thing to tap); the classic keeps a small sun.
				var body: Color = {"classic": UI.TRACK, "neon": UI.FELT_LINE, "vault": UI.DIM}[kind]
				var r := Rect2(Vector2(s.x * 0.16, s.y * 0.1), Vector2(s.x * 0.62, s.y * 0.82))
				draw_colored_polygon(UI.rounded_rect_poly(Rect2(r.position + Vector2(1.5, 2), r.size), 5.0), Color(UI.INK, 0.5))
				draw_colored_polygon(UI.rounded_rect_poly(r, 5.0), body)
				draw_line(r.position + Vector2(3, 1.5), Vector2(r.end.x - 3, r.position.y + 1.5), Color(UI.TEXT, 0.35), 1.0, true)
				# Lamp on top.
				draw_circle(Vector2(r.get_center().x, r.position.y + s.y * 0.07), s.x * 0.05, Color(UI.GOLD, 0.8) if kind != "classic" else Color(UI.RED, 0.7))
				# The screen: three reel windows behind glass with a glare.
				var scr := Rect2(r.position + Vector2(4, s.y * 0.2), Vector2(r.size.x - 8, s.y * 0.3))
				draw_rect(scr, UI.INK)
				var syms: Array = {"classic": ["seven", "sun", "seven"], "neon": ["wild", "bell", "wild"], "vault": ["crown", "bar", "crown"]}[kind]
				for i in 3:
					var cx := scr.position.x + scr.size.x * (0.17 + 0.33 * float(i))
					if i > 0:
						draw_line(Vector2(scr.position.x + scr.size.x * 0.333 * float(i), scr.position.y + 2), Vector2(scr.position.x + scr.size.x * 0.333 * float(i), scr.end.y - 2), Color(UI.TEXT, 0.1), 1.0)
					draw_circle(Vector2(cx, scr.get_center().y), s.x * 0.06, UI.SLOT_COL[syms[i]])
				draw_line(scr.position + Vector2(2, scr.size.y * 0.25), scr.position + Vector2(scr.size.x * 0.4, 2), Color(UI.TEXT, 0.16), 2.0, true)
				# Coin tray.
				draw_rect(Rect2(r.position + Vector2(6, s.y * 0.66), Vector2(r.size.x - 12, 4)), UI.INK)
				# Lever with a ball (not red: red dots mean "claim").
				draw_line(Vector2(r.end.x, s.y * 0.5), Vector2(s.x * 0.9, s.y * 0.5), UI.SUB, 2.0)
				draw_line(Vector2(s.x * 0.9, s.y * 0.5), Vector2(s.x * 0.9, s.y * 0.2), UI.SUB, 2.0)
				CasinoGame.draw_ball(self, Vector2(s.x * 0.9, s.y * 0.17), 3.5, UI.SUB)
			"roulette":
				var c := s * 0.5
				var rad := minf(s.x, s.y) * 0.46
				for i in 37:
					var a0 := TAU * float(i) / 37.0
					var a1 := TAU * float(i + 1) / 37.0
					var col: Color = UI.ROUL_GREEN if i == 0 else (UI.ROUL_RED if i % 2 == 1 else UI.ROUL_BLACK)
					draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rad, c + Vector2(cos(a1), sin(a1)) * rad]), col)
				draw_arc(c, rad, 0.0, TAU, 37, UI.GOLD.lerp(UI.SIDE, 0.4), 2.0, true)
				draw_circle(c, rad * 0.55, UI.FELT)
				draw_arc(c, rad * 0.55, 0.0, TAU, 24, UI.GOLD.lerp(UI.SIDE, 0.4), 1.0, true)
				CasinoGame.draw_ball(self, c, rad * 0.18, UI.GOLD)
				CasinoGame.draw_ball(self, c + Vector2(rad * 0.75, -rad * 0.3), 2.6)
			"wheel":
				var c := s * 0.5
				var rad := minf(s.x, s.y) * 0.44
				for i in 8:
					var a0 := TAU * float(i) / 8.0
					var a1 := TAU * float(i + 1) / 8.0
					var pts := PackedVector2Array([c])
					for k in 5:
						var a := lerpf(a0, a1, float(k) / 4.0)
						pts.append(c + Vector2(cos(a), sin(a)) * rad)
					draw_colored_polygon(pts, UI.CHIP_COL[i % UI.CHIP_COL.size()] if i % 2 == 0 else UI.RAISED)
				draw_circle(c, rad * 0.22, UI.GOLD)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -rad - 3), c + Vector2(4, -rad - 3), c + Vector2(0, -rad + 6)]), UI.RED)
			"crash":
				draw_rect(Rect2(Vector2(s.x * 0.08, s.y * 0.1), Vector2(s.x * 0.84, s.y * 0.8)), UI.INK)
				for gk in 3:
					var gy := s.y * (0.3 + 0.2 * float(gk))
					draw_line(Vector2(s.x * 0.1, gy), Vector2(s.x * 0.9, gy), Color(UI.TEXT, 0.07), 1.0)
				var pts2 := PackedVector2Array()
				for k in 12:
					var x := float(k) / 11.0
					pts2.append(Vector2(s.x * (0.14 + 0.72 * x), s.y * (0.82 - 0.62 * x * x)))
				draw_polyline(pts2, Color(UI.GOLD, 0.25), 6.0, true)
				draw_polyline(pts2, UI.GOLD, 2.5, true)
				draw_circle(pts2[pts2.size() - 1], 6.0, Color(UI.RED, 0.25))
				draw_circle(pts2[pts2.size() - 1], 3.5, UI.RED)
			"plinko":
				for row in 4:
					for k in row + 1:
						draw_circle(Vector2(s.x * 0.5 + (float(k) - float(row) * 0.5) * s.x * 0.18, s.y * (0.18 + 0.16 * float(row))), 2.5, UI.SUB)
				for k in 5:
					draw_rect(Rect2(Vector2(s.x * (0.1 + 0.165 * float(k)), s.y * 0.82), Vector2(s.x * 0.14, s.y * 0.1)), UI.GOLD if k == 0 or k == 4 else UI.RAISED)
				CasinoGame.draw_ball(self, Vector2(s.x * 0.56, s.y * 0.42), 3.5)
			"poker":
				var cards := ["cardSpadesA.png", "cardSpadesK.png", "cardSpadesQ.png"]
				var h2 := s.y * 0.78
				var w2 := h2 * 140.0 / 190.0
				for i in 3:
					var tx := load("res://assets/cards/" + cards[i]) as Texture2D
					if tx:
						draw_set_transform(Vector2(s.x * (0.12 + 0.2 * float(i)), s.y * 0.11), 0.0)
						draw_texture_rect(tx, Rect2(Vector2.ZERO, Vector2(w2, h2)), false)
				draw_set_transform(Vector2.ZERO, 0.0)
			"races":
				for k in 3:
					var y := s.y * (0.25 + 0.25 * float(k))
					draw_line(Vector2(s.x * 0.06, y + 6), Vector2(s.x * 0.94, y + 6), UI.TRACK, 1.0)
					var x := s.x * (0.25 + 0.2 * float(k))
					RacePage.draw_car(self, Vector2(x, y), 0.55, RacePage.car_color(k, k == 2))
				draw_rect(Rect2(Vector2(s.x * 0.86, s.y * 0.14), Vector2(3, s.y * 0.72)), UI.TEXT)
			"tower":
				# Three columns of boxes, the climbed ones lit, one red cross.
				var bw := s.x * 0.22
				var bh := s.y * 0.15
				for row in 4:
					for k in 3:
						var rr := Rect2(Vector2(s.x * 0.14 + float(k) * (bw + s.x * 0.04), s.y * 0.8 - float(row + 1) * (bh + s.y * 0.04)), Vector2(bw, bh))
						var col: Color = UI.RAISED
						if row < 2 and k == (row + 1) % 3:
							col = UI.GOLD
						elif row == 2 and k == 0:
							col = Color(UI.RED, 0.85)
						draw_rect(rr, col)
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




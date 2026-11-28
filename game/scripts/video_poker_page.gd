class_name VideoPokerPage
extends CasinoGame
## Video poker, Jacks or Better (9/6). Deal five cards, tap the ones to keep,
## draw. A fresh deck every hand. Money: the bet is taken (and saved) at Deal;
## at Draw the result is worked out and paid at once, then the new cards flip
## over. Leaving mid-hand draws with what you held and pays it; if the app is
## killed mid-hand the stake was already taken, so that hand is lost.

const CARD := Vector2(64, 88)

var _pm := PokerMath.new()
var _phase := "idle"        # idle, hold, show
var _holds := [false, false, false, false, false]
var _bet_now := 0.0
var _hidden_win := 0.0
var _last := ""             # last result id
var _cards: Array = []      # CardSlot x5
var _pay: PayTable
var _result: Label
var _tip: Label
var _bet: BetBar
var _go: Button
var _hint: Button


func _init() -> void:
	super("Video poker", true)


func play_button() -> Button:
	return _go


func finish_for_test() -> void:
	if _phase == "hold":
		_on_go()
	await get_tree().create_timer(0.3).timeout


func build_game() -> void:
	var felt := PanelContainer.new()
	var fsb := StyleBoxEmpty.new()   # the cabinet is drawn below; this only pads the content
	fsb.content_margin_left = 8    # five cards just fit a 358 px column
	fsb.content_margin_right = 8
	fsb.content_margin_top = 16
	fsb.content_margin_bottom = 16
	felt.add_theme_stylebox_override("panel", fsb)
	felt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A machine cabinet: a bevelled frame around a lit green screen.
	felt.draw.connect(func():
		var face := CasinoGame.draw_frame(felt, Rect2(Vector2.ZERO, felt.size), 18.0, UI.FELT.darkened(0.15))
		for k in 4:
			var t := float(k + 1) / 5.0
			var rr := Rect2(face.position + face.size * t * 0.15, face.size * (1.0 - t * 0.3))
			felt.draw_colored_polygon(UI.rounded_rect_poly(rr, 12.0), Color(UI.FELT.lightened(0.05), 0.25)))
	area.add_child(felt)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 10)
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	felt.add_child(fv)
	_pay = PayTable.new()
	_pay.size_flags_vertical = Control.SIZE_EXPAND_FILL   # takes the room left; hides on a short screen
	fv.add_child(_pay)
	_result = UI.label("", 17, UI.TEXT, true)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(_result)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	fv.add_child(row)
	for i in 5:
		var cs := CardSlot.new(i)
		cs.pressed.connect(func(): _toggle(cs.index))
		row.add_child(cs)
		_cards.append(cs)
	# Under the cards: a hint while idle, "Suggest holds" while holding.
	var under := CenterContainer.new()
	under.custom_minimum_size = Vector2(0, 48)
	fv.add_child(under)
	_tip = UI.label("Pair of jacks or better pays", 13, UI.FELT_LINE)
	under.add_child(_tip)
	_hint = UI.pill("Suggest holds", Color(UI.INK, 0.35), UI.TEXT, 15, 24)
	_hint.custom_minimum_size = Vector2(168, 48)
	_hint.pressed.connect(_on_hint)
	Kit.press_fx(_hint)
	under.add_child(_hint)
	_bet = BetBar.new()
	dock.add_child(_bet)
	_go = primary("Deal", _on_go)
	dock.add_child(_go)
	tree_exiting.connect(_settle_on_leave)
	_show_idle_line()


func in_jackpot() -> bool:
	return false


func info_content() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for p in PokerMath.PAYTABLE:
		box.add_child(pay_line(String(p[1]), "×%d" % int(p[2]), String(p[0]) == _last))
	box.add_child(note("\nPays are times your bet. Deal five cards, tap the ones to keep, then draw. A fresh deck every hand. Pays back about 99.5% with perfect play."))
	return box


func _show_idle_line() -> void:
	_result.text = "Jacks or better"
	_result.add_theme_color_override("font_color", UI.TEXT)


func refresh() -> void:
	if _go == null:
		return
	_bet.locked = _phase == "hold"
	_bet.refresh()
	status.set_chips(Game.chips() - _hidden_win)
	_go.text = "Draw" if _phase == "hold" else "Deal · " + Game.money_short(_bet.value)
	_hint.visible = _phase == "hold"
	_tip.visible = _phase != "hold"
	_pay.highlight = _last if _phase == "idle" else ""


func _toggle(i: int) -> void:
	if _phase != "hold":
		return
	Kit.haptic("selection")
	_holds[i] = not _holds[i]
	_cards[i].held = _holds[i]


func _on_hint() -> void:
	if _phase != "hold":
		return
	Kit.tick()
	_holds = PokerMath.auto_hold(_pm.hand)
	for i in 5:
		_cards[i].held = _holds[i]


func _on_go() -> void:
	if _phase == "hold":
		_draw_now(true)
		return
	_bet.refresh()
	var bet := _bet.value
	if bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips")
		Motion.shake(_go)
		offer_chips()
		return
	if not Game.casino_stake(bet, 1.0, false):
		Kit.toast("Over the table limit")
		Motion.shake(_go)
		return
	Kit.sound("tap")
	_bet_now = bet
	_last = ""
	_pm.deal()
	_holds = [false, false, false, false, false]
	_phase = "hold"
	status.clear_win()
	_result.text = "Tap cards to hold, then draw"
	_result.add_theme_color_override("font_color", UI.TEXT)
	for i in 5:
		_cards[i].held = false
		_cards[i].show_card(_pm.hand[i], float(i) * 0.06)
	refresh()


func _draw_now(animate: bool) -> void:
	_pm.draw(_holds)
	var id := PokerMath.evaluate(_pm.hand)
	var win := _bet_now * PokerMath.pays(id)
	var paid := Game.casino_pay(win, false) if win > 0.0 else 0.0   # paid and saved before the cards turn
	_phase = "show"
	_last = id
	if not animate:
		return
	_hidden_win = paid
	var k := 0
	for i in 5:
		if not _holds[i]:
			_cards[i].show_card(_pm.hand[i], float(k) * 0.08)
			k += 1
	var wait := Motion.d(0.35 + 0.08 * float(k))
	var stake := _bet_now
	get_tree().create_timer(wait).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_hidden_win = 0.0
		if paid > 0.0:
			_result.text = PokerMath.name_of(id) + ("" if paid > stake + 0.001 else ", bet back")
			_result.add_theme_color_override("font_color", UI.GOLD if paid > stake + 0.001 else UI.TEXT)
		else:
			_result.text = "No win"
			_result.add_theme_color_override("font_color", UI.SUB)
		_phase = "idle"
		win_fx(paid, stake, 25.0)
		refresh())
	refresh()


func _settle_on_leave() -> void:
	## Leaving mid-hand draws with the cards held and pays the result.
	if _phase == "hold":
		_draw_now(false)


class CardSlot extends Button:
	var index := 0
	var held := false:
		set(v):
			held = v
			queue_redraw()
	var _face: TextureRect
	var _card: Dictionary = {}

	func _init(i := 0) -> void:
		index = i
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(VideoPokerPage.CARD.x, VideoPokerPage.CARD.y + 22)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		_face = TextureRect.new()
		_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_face.size = VideoPokerPage.CARD
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.texture = load("res://assets/cards/cardBack.png")
		add_child(_face)

	func show_card(c: Dictionary, delay: float) -> void:
		_card = c
		var tex := load("res://assets/cards/" + BlackjackMath.card_file(c)) as Texture2D
		if Motion.reduced():
			_face.texture = tex
			return
		# A quick flip: squash to nothing, swap the face, open again.
		_face.pivot_offset = VideoPokerPage.CARD * 0.5
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(_face, "scale:x", 0.0, Motion.d(0.1))
		t.tween_callback(func(): _face.texture = tex)
		t.tween_property(_face, "scale:x", 1.0, Motion.d(0.12))

	func _draw() -> void:
		# A soft shadow under the card (the card face itself is a child, drawn on top).
		draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2(2, 4), VideoPokerPage.CARD), 6.0), Color(UI.INK, 0.45))
		var r := Rect2(Vector2(4, VideoPokerPage.CARD.y + 3), Vector2(size.x - 8, 17))
		if held:
			draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2(-5, -5), VideoPokerPage.CARD + Vector2(10, 10)), 9.0), Color(UI.GOLD, 0.25))
			draw_polyline(UI.rounded_rect_poly(Rect2(Vector2(-2, -2), VideoPokerPage.CARD + Vector2(4, 4)), 7.0), UI.GOLD, 2.5, true)
			draw_colored_polygon(UI.rounded_rect_poly(r, 8.5), UI.GOLD)
			draw_string(UI.SEMI, r.position + Vector2(0, 13), "HELD", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, UI.INK)


class PayTable extends Control:
	## The pays on the felt, quiet, as on a real machine; the winning hand lights gold.
	var highlight := "":
		set(v):
			if v != highlight:
				highlight = v
				queue_redraw()

	func _draw() -> void:
		var rows := PokerMath.PAYTABLE.size()
		var h := minf(18.0, (size.y - 26.0) / float(rows))
		if h < 14.0:
			return   # too short to read: the i sheet has the pays
		# A dark glass panel set into the cabinet, with a title and a gold divider.
		var tot := h * float(rows) + 26.0
		var pr := Rect2(Vector2(4, (size.y - tot) * 0.5), Vector2(size.x - 8, tot))
		draw_colored_polygon(UI.rounded_rect_poly(pr, 10.0), Color(UI.INK, 0.45))
		draw_polyline(UI.rounded_rect_poly(pr, 10.0), Color(UI.GOLD, 0.3), 1.0, true)
		draw_string(UI.SEMI, Vector2(pr.position.x, pr.position.y + 16), "JACKS OR BETTER", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 13, UI.GOLD)
		var y0 := pr.position.y + 22.0
		draw_line(Vector2(size.x * 0.62, y0), Vector2(size.x * 0.62, y0 + h * float(rows)), Color(UI.GOLD, 0.2), 1.0)
		for i in rows:
			var p: Array = PokerMath.PAYTABLE[i]
			var y := y0 + h * float(i)
			var lit := String(p[0]) == highlight
			if i % 2 == 1:
				draw_rect(Rect2(Vector2(pr.position.x + 4, y), Vector2(pr.size.x - 8, h)), Color(UI.TEXT, 0.03))
			if lit:
				draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2(6, y - 2), Vector2(size.x - 12, h + 4)), 8.0), Color(UI.GOLD, 0.3))
				draw_colored_polygon(UI.rounded_rect_poly(Rect2(Vector2(8, y), Vector2(size.x - 16, h)), 6.0), UI.GOLD)
			var col: Color = UI.INK if lit else Color(UI.TEXT, 0.8)
			draw_string(UI.SEMI, Vector2(18, y + h * 0.74), String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 13, col)
			draw_string(UI.SEMI, Vector2(size.x * 0.6, y + h * 0.74), "×%d" % int(p[2]), HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.4 - 18, 13, UI.INK if lit else UI.GOLD)

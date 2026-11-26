class_name VideoPokerPage
extends Page
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
var _status: Label
var _result: Label
var _bet: CasinoPage.BetBar
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


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pay = PayTable.new()
	_pay.custom_minimum_size = Vector2(0, 168)
	body.add_child(_pay)
	var felt := PanelContainer.new()
	felt.add_theme_stylebox_override("panel", UI.box(UI.FELT, 18, 8, 12))
	body.add_child(felt)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 8)
	felt.add_child(fv)
	_result = UI.label("Deal to start", 17, UI.TEXT, true)
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
	var tip := UI.label("Tap cards to hold", 13, UI.FELT_LINE)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(tip)
	_status = CasinoPage.status_row(body)
	_bet = CasinoPage.BetBar.new()
	body.add_child(_bet)
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 6)
	body.add_child(act)
	_hint = CasinoPage.game_button("?", false, _on_hint)
	_hint.custom_minimum_size.x = 52
	act.add_child(_hint)
	_go = CasinoPage.game_button("Deal", true, _on_go)
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act.add_child(_go)
	tree_exiting.connect(_settle_on_leave)


func refresh() -> void:
	if _status == null:
		return
	_bet.locked = _phase == "hold"
	_bet.refresh()
	_status.text = "Chips %s · limit %s" % [Game.money(Game.chips() - _hidden_win), Game.money_short(Game.casino_max_bet())]
	_go.text = "Draw" if _phase == "hold" else "Deal · " + Game.money_short(_bet.value)
	_hint.visible = _phase == "hold"
	_pay.highlight = _last


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
	Kit.toast("Suggested holds")


func _on_go() -> void:
	if _phase == "hold":
		_draw_now(true)
		return
	_bet.refresh()
	var bet := _bet.value
	if bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips")
		Motion.shake(_go)
		return
	if not Game.casino_stake(bet):
		Kit.toast("Over the table limit")
		Motion.shake(_go)
		return
	Kit.sound("tap")
	_bet_now = bet
	_last = ""
	_pm.deal()
	_holds = [false, false, false, false, false]
	_phase = "hold"
	_result.text = "Hold cards, then draw"
	for i in 5:
		_cards[i].held = false
		_cards[i].show_card(_pm.hand[i], float(i) * 0.06)
	refresh()


func _draw_now(animate: bool) -> void:
	_pm.draw(_holds)
	var id := PokerMath.evaluate(_pm.hand)
	var win := _bet_now * PokerMath.pays(id)
	var paid := Game.casino_pay(win) if win > 0.0 else 0.0   # paid and saved before the cards turn
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
	get_tree().create_timer(wait).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_hidden_win = 0.0
		if paid > 0.0:
			_result.text = "%s · +%s" % [PokerMath.name_of(id), Game.money_short(paid)]
			Kit.haptic("success")
			Kit.sound("buy" if PokerMath.pays(id) < 25.0 else "fanfare")
		else:
			_result.text = "No win"
		_phase = "idle"
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
		var r := Rect2(Vector2(0, VideoPokerPage.CARD.y + 3), Vector2(size.x, 17))
		if held:
			draw_rect(Rect2(Vector2(-2, -2), VideoPokerPage.CARD + Vector2(4, 4)), UI.GOLD, false, 3.0)
			draw_rect(r, UI.GOLD)
			draw_string(UI.SEMI, r.position + Vector2(0, 13), "HELD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UI.INK)


class PayTable extends Control:
	## The pay table, two columns; the last result lights up.
	var highlight := "":
		set(v):
			if v != highlight:
				highlight = v
				queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.PANEL)
		var f: Font = UI.SEMI
		var rows := PokerMath.PAYTABLE.size()
		var h := (size.y - 12.0) / float(rows)
		for i in rows:
			var p: Array = PokerMath.PAYTABLE[i]
			var y := 6.0 + h * float(i)
			var lit := String(p[0]) == highlight
			if lit:
				draw_rect(Rect2(Vector2(6, y), Vector2(size.x - 12, h)), UI.GOLD)
			var col: Color = UI.INK if lit else (UI.TEXT if i < 4 else UI.SUB)
			draw_string(f, Vector2(16, y + h * 0.72), String(p[1]), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.6, 13, col)
			draw_string(f, Vector2(size.x * 0.6, y + h * 0.72), "x%s" % str(int(p[2])), HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.4 - 16, 13, col)

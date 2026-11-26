class_name BlackjackPage
extends Page
## Blackjack at a felt table with real cards (Kenney, CC0). Six decks,
## shuffled for every hand; dealer stands on 17; blackjack pays 3 to 2;
## double on any two cards; split once.
##
## Money: the bet is taken (and saved) at Deal, a double or split takes its
## extra stake the moment you tap it, and the result is paid the moment the
## hand ends, before the dealer's cards finish moving. Leaving the page in the
## middle of a hand stands on what's left and pays it out, so no stake is
## lost to a closed page. If the app itself is killed mid-hand, the stake was
## already taken and saved, so that hand is lost, never refunded (as at a
## real table): a restart can't undo a bad hand.

const CARD := Vector2(62, 84)

var _bj := BlackjackMath.new()
var _table: TableView
var _status: Label
var _chip_row: HBoxContainer
var _idle_row: HBoxContainer
var _play_row: HBoxContainer
var _deal_b: Button
var _clear_b: Button
var _hit_b: Button
var _stand_b: Button
var _double_b: Button
var _split_b: Button
var _hint_b: Button

var _bet := 0.0
var _denoms: Array = []
var _staked := 0.0          # stakes taken for the hand on the table
var _settled := true        # the hand on the table has been paid
var _paid := 0.0
var _revealing := false     # results show once the cards stop moving
var _hidden_win := 0.0      # chips not yet shown while the cards move


func _init() -> void:
	super("Blackjack", true)


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_table = TableView.new()
	_table.custom_minimum_size = Vector2(0, 420)
	body.add_child(_table)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	body.add_child(sr)
	_status = UI.label("", 13, UI.SUB)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sr.add_child(_status)
	var buy := UI.pill("+ Chips", UI.RAISED, UI.TEXT, 15, 16)
	buy.custom_minimum_size = Vector2(88, 48)
	buy.pressed.connect(func():
		Kit.tick()
		if Game.cash < 0.01:
			Kit.toast("No cash to spend")
			return
		TradeSheet.open("chips", "", "chips_in"))
	Kit.press_fx(buy)
	sr.add_child(buy)
	_chip_row = HBoxContainer.new()
	_chip_row.add_theme_constant_override("separation", 8)
	_chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_chip_row)
	# Before a hand: clear the bet or deal.
	_idle_row = HBoxContainer.new()
	_idle_row.add_theme_constant_override("separation", 6)
	body.add_child(_idle_row)
	_clear_b = _btn("Clear", false, _on_clear)
	_clear_b.custom_minimum_size.x = 88
	_idle_row.add_child(_clear_b)
	_deal_b = _btn("Deal", true, _on_deal)
	_deal_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_idle_row.add_child(_deal_b)
	# During a hand: Hint, Split, Double, Hit, Stand (Stand nearest the thumb).
	_play_row = HBoxContainer.new()
	_play_row.add_theme_constant_override("separation", 6)
	body.add_child(_play_row)
	_hint_b = _btn("?", false, _on_hint)
	_hint_b.custom_minimum_size.x = 48
	_play_row.add_child(_hint_b)
	_split_b = _btn("Split", false, _on_split)
	_double_b = _btn("Double", false, _on_double)
	_hit_b = _btn("Hit", true, _on_hit)
	_stand_b = _btn("Stand", true, _on_stand)
	for b in [_split_b, _double_b, _hit_b, _stand_b]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_play_row.add_child(b)


func _ready() -> void:
	super()
	await get_tree().process_frame
	if not is_instance_valid(_table):
		return
	var used := body.get_combined_minimum_size().y - _table.custom_minimum_size.y
	_table.custom_minimum_size.y = maxf(340.0, get_viewport_rect().size.y - 4.0 - 104.0 - used)


func _btn(t: String, primary: bool, call: Callable) -> Button:
	var b := UI.pill(t, UI.TEXT if primary else UI.RAISED, UI.INK if primary else UI.TEXT, 16, 18)
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(func():
		if b.get_meta("blocked", false):
			Motion.shake(b)
			return
		call.call())
	Kit.press_fx(b)
	return b


# ---- chips and bet ----------------------------------------------------------

func _rebuild_chips() -> void:
	var d := RoulettePage.denoms(Game.casino_max_bet())
	if d == _denoms:
		return
	_denoms = d
	for ch in _chip_row.get_children():
		ch.queue_free()
	for i in range(_denoms.size()):
		var v: float = _denoms[i]
		var cb := RoulettePage.ChipButton.new(v, i)
		cb.pressed.connect(func(): _add_bet(v, cb))
		_chip_row.add_child(cb)
	if _bet <= 0.0 or _bet > Game.casino_max_bet():
		_bet = _denoms[1] if _denoms.size() > 1 else _denoms[0]


func _add_bet(v: float, cb: Control) -> void:
	if _bj.phase == "player":
		Kit.toast("Bets are in for this hand")
		return
	var mx := Game.casino_max_bet()
	if _bet + v > mx + 0.001:
		Kit.toast("Table limit %s" % Game.money_short(mx))
		Motion.shake(cb)
		return
	_bet += v
	Kit.haptic("selection")
	Kit.sound("tap")
	refresh()


func _on_clear() -> void:
	if _bj.phase == "player":
		return
	if _bet <= 0.0:
		Motion.shake(_clear_b)
		return
	Kit.tick()
	_bet = 0.0
	refresh()


# ---- the hand -------------------------------------------------------------------

func _on_deal() -> void:
	if _bj.phase == "player":
		return
	if _bet <= 0.0:
		Kit.toast("Tap a chip to bet")
		Motion.shake(_deal_b)
		return
	if _bet > Game.chips() + 0.001:
		Kit.toast("Not enough chips · tap + Chips")
		Motion.shake(_deal_b)
		return
	if not Game.casino_stake(_bet):
		Kit.toast("Table limit %s" % Game.money_short(Game.casino_max_bet()))
		Motion.shake(_deal_b)
		return
	Kit.haptic("medium")
	_staked = _bet
	_settled = false
	_paid = 0.0
	_table.outcomes = []
	_table.clear_cards()
	_bj.deal(_bet)
	_after_move()


func _on_hit() -> void:
	if not _bj.can_hit():
		return
	Kit.tick()
	_bj.hit()
	_after_move()


func _on_stand() -> void:
	if _bj.phase != "player":
		return
	Kit.tick()
	_bj.stand()
	_after_move()


func _on_double() -> void:
	if not _bj.can_double():
		Motion.shake(_double_b)
		return
	var extra := float(_bj.current_hand()["bet"])
	if extra > Game.chips() + 0.001:
		Kit.toast("Not enough chips to double")
		Motion.shake(_double_b)
		return
	if not Game.casino_stake(extra, 2.0):
		Motion.shake(_double_b)
		return
	Kit.haptic("medium")
	_staked += _bj.double()
	_after_move()


func _on_split() -> void:
	if not _bj.can_split():
		Motion.shake(_split_b)
		return
	var extra := float(_bj.hands[0]["bet"])
	if extra > Game.chips() + 0.001:
		Kit.toast("Not enough chips to split")
		Motion.shake(_split_b)
		return
	if not Game.casino_stake(extra, 2.0):
		Motion.shake(_split_b)
		return
	Kit.haptic("medium")
	_staked += _bj.split()
	_after_move()


func _on_hint() -> void:
	if _bj.phase != "player":
		return
	var h: Dictionary = _bj.current_hand()
	var mv := BlackjackMath.basic_strategy(h["cards"], _bj.dealer_up(), _bj.can_double(), _bj.can_split())
	Kit.tick()
	Kit.toast("Good play here: %s" % mv.capitalize())


func _after_move() -> void:
	## Pays at once when the hand is over, then lets the cards catch up.
	var t := _sync()
	if _bj.is_over() and not _settled:
		_settle()
		_revealing = true
		_hidden_win = _paid
		get_tree().create_timer(t + Motion.d(0.15)).timeout.connect(func():
			if is_instance_valid(self):
				_show_result())
	refresh()


func _settle() -> void:
	var res := _bj.result()
	_paid = Game.casino_pay(float(res["payout_total"]))
	_settled = true
	GameLog.info("casino", "Blackjack: staked %s, back %s" % [Game.money(_staked), Game.money(_paid)])


func _show_result() -> void:
	_revealing = false
	_hidden_win = 0.0
	var res := _bj.result()
	var outs: Array = []
	for h in res["hands"]:
		outs.append(String(h["outcome"]))
	_table.outcomes = outs
	_table.queue_redraw()
	var net := _paid - _staked
	if _paid > _staked + 0.001:
		Kit.haptic("success")
		var bj := outs.has("blackjack")
		Kit.toast(("Blackjack · +" if bj else "You win · +") + Game.money_short(net), true)
		if bj:
			Kit.sound("fanfare")
	elif absf(net) <= 0.001:
		Kit.toast("Push · bet back")
	else:
		Kit.haptic("light")
	refresh()


func _exit_tree() -> void:
	# Leaving mid-hand: stand on what's left and pay it, so nothing is lost.
	if _bj.phase == "player" and not _settled:
		while not _bj.is_over():
			_bj.stand()
		_settle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _bj.phase == "player" and not _settled:
		while not _bj.is_over():
			_bj.stand()
		_settle()


# ---- drawing the cards ----------------------------------------------------------

func _sync() -> float:
	## Moves cards to where the state says, dealing new ones from the shoe.
	## Returns how long the moves take.
	var want: Array = []   # [card, pos, face_up]
	var w := _table.size.x if _table.size.x > 0.0 else 358.0
	var h := _table.size.y if _table.size.y > 0.0 else 420.0
	var over := _bj.is_over()
	# Player hands along the bottom, side by side after a split.
	var hands: Array = _bj.hands
	var n_h := hands.size()
	var py := h - CARD.y - 52.0
	var centers: Array = [w * 0.5] if n_h <= 1 else [w * 0.27, w * 0.73]
	var pstep := 24.0 if n_h > 1 else 30.0
	_table.hand_labels = []
	for hi in range(n_h):
		var cards: Array = hands[hi]["cards"]
		var span := CARD.x + pstep * float(cards.size() - 1)
		var x0 := float(centers[hi]) - span * 0.5
		for ci in range(cards.size()):
			# Each new card sits a little higher, like a fanned hand.
			want.append([cards[ci], Vector2(x0 + pstep * float(ci), py - float(ci) * 2.0), true])
		var hv := BlackjackMath.hand_value(cards)
		_table.hand_labels.append({"pos": Vector2(float(centers[hi]), py + CARD.y + 22.0), "text": _total_text(cards), "active": not over and hi == _bj.active and n_h > 1, "bet": float(hands[hi]["bet"]), "doubled": bool(hands[hi]["doubled"]), "bust": int(hv["total"]) > 21})
	# Dealer along the top; the second card stays face down until the end.
	var dc: Array = _bj.dealer
	var dspan := CARD.x + 30.0 * float(dc.size() - 1)
	var dx0 := w * 0.5 - dspan * 0.5
	for ci in range(dc.size()):
		want.append([dc[ci], Vector2(dx0 + 30.0 * float(ci), 34.0), over or ci == 0])
	_table.dealer_label = _total_text(dc) if over else (_total_text([dc[0]]) if not dc.is_empty() else "")
	return _table.place_cards(want)


func _total_text(cards: Array) -> String:
	if cards.is_empty():
		return ""
	if cards.size() == 2 and BlackjackMath.is_blackjack(cards):
		return "Blackjack"
	var hv := BlackjackMath.hand_value(cards)
	var t := int(hv["total"])
	if t > 21:
		return "%d · bust" % t
	if bool(hv["soft"]) and t < 21:
		return "%d/%d" % [t - 10, t]
	return str(t)


func refresh() -> void:
	if _status == null:
		return
	_rebuild_chips()
	var playing := _bj.phase == "player"
	var chips_shown := Game.chips() - (_hidden_win if _revealing else 0.0)
	var on := _staked if (playing or _revealing) else _bet
	_status.text = "Bet %s · limit %s\nChips %s" % [Game.money_short(on), Game.money_short(Game.casino_max_bet()), Game.money(chips_shown)]
	_table.bet_amount = on
	_table.queue_redraw()
	_idle_row.visible = not playing
	_play_row.visible = playing
	Page.set_enabled(_deal_b, _bet > 0.0 and not _revealing)
	if playing:
		Page.set_enabled(_hit_b, _bj.can_hit())
		Page.set_enabled(_stand_b, true)
		Page.set_enabled(_double_b, _bj.can_double(), false)
		Page.set_enabled(_split_b, _bj.can_split(), false)
		Page.set_enabled(_hint_b, true, false)
	for ch in _chip_row.get_children():
		if ch is RoulettePage.ChipButton:
			(ch as Control).modulate.a = 0.45 if playing else 1.0


class TableView extends Control:
	## The felt, the shoe, the bet circle, totals and outcome tags. Cards are
	## TextureRect children that slide in from the shoe and flip over.
	var hand_labels: Array = []
	var dealer_label := ""
	var outcomes: Array = []
	var bet_amount := 0.0
	var _cards: Array = []     # TextureRect, meta "card" (Dictionary), meta "up"
	var _shoe: TextureRect

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The shoe: a small card box inside the felt, top right (never clipped).
		_shoe = TextureRect.new()
		_shoe.texture = load("res://assets/cards/cardBack.png") as Texture2D
		_shoe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shoe.stretch_mode = TextureRect.STRETCH_SCALE
		_shoe.size = SHOE
		_shoe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shoe)
		resized.connect(func(): _shoe.position = shoe_pos())

	const SHOE := Vector2(36, 49)

	func shoe_pos() -> Vector2:
		return Vector2(size.x - SHOE.x - 16.0, 14.0)

	func clear_cards() -> void:
		for c in _cards:
			var tr: TextureRect = c
			var t := tr.create_tween()
			t.tween_property(tr, "modulate:a", 0.0, Motion.d(0.15))
			t.tween_callback(tr.queue_free)
		_cards = []

	static func tex(card: Dictionary, up: bool) -> Texture2D:
		var p := "res://assets/cards/" + (BlackjackMath.card_file(card) if up else "cardBack.png")
		return load(p) as Texture2D

	func place_cards(want: Array) -> float:
		var delay := 0.0
		var step := Motion.d(0.2)
		var keep: Array = []
		var flips: Array = []
		var fresh: Array = []
		for wv in want:
			var card: Dictionary = wv[0]
			var pos: Vector2 = wv[1]
			var up: bool = wv[2]
			var node: TextureRect = null
			for c in _cards:
				if is_same((c as TextureRect).get_meta("card"), card):
					node = c
					break
			if node == null:
				fresh.append([card, pos, up])
				continue
			keep.append(node)
			if node.position.distance_to(pos) > 0.5:
				var t := node.create_tween()
				t.tween_property(node, "position", pos, Motion.d(0.25)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			if bool(node.get_meta("up")) != up:
				flips.append([node, up])
		# Flip the hole card first, then deal the new cards one by one.
		for f in flips:
			_flip(f[0], f[1], delay)
			delay += step
		var z := keep.size()
		for fr in fresh:
			var node := TextureRect.new()
			node.texture = tex(fr[0], fr[2])
			node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			node.stretch_mode = TextureRect.STRETCH_SCALE
			node.size = BlackjackPage.CARD
			node.pivot_offset = BlackjackPage.CARD * 0.5
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.set_meta("card", fr[0])
			node.set_meta("up", fr[2])
			node.position = shoe_pos()
			node.z_index = z
			z += 1
			add_child(node)
			keep.append(node)
			var t := node.create_tween()
			if delay > 0.0:
				t.tween_interval(delay)
			t.tween_callback(func(): Kit.sound("tap"))
			t.tween_property(node, "position", fr[1], Motion.d(0.3)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			delay += step
		_cards = keep
		queue_redraw()
		return delay + Motion.d(0.3)

	func _flip(node: TextureRect, up: bool, delay: float) -> void:
		node.set_meta("up", up)
		var card: Dictionary = node.get_meta("card")
		if Motion.reduced():   # reduced-checked
			node.texture = tex(card, up)
			return
		var t := node.create_tween()
		if delay > 0.0:
			t.tween_interval(delay)
		t.tween_property(node, "scale:x", 0.0, Motion.d(0.12))
		t.tween_callback(func(): node.texture = tex(card, up))
		t.tween_property(node, "scale:x", 1.0, Motion.d(0.12))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(UI.rounded_rect_poly(r, 20.0), UI.FELT)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.06), size.x * 0.62, PI * 0.18, PI * 0.82, 64, UI.FELT_LINE, 1.5, true)
		var f: Font = UI.SEMI
		# Shoe, top right.
		var sp := shoe_pos()
		draw_rect(Rect2(sp + Vector2(-5, -5), SHOE + Vector2(10, 10)), UI.SIDE)
		# Table rules, printed on the felt like a real layout.
		var mid := size.y * 0.47
		draw_string(f, Vector2(0, mid - 26.0), "BLACKJACK PAYS 3 TO 2", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, UI.GOLD)
		draw_string(f, Vector2(0, mid - 8.0), "Dealer stands on all 17s", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(UI.TEXT, 0.55))
		# Dealer total.
		draw_string(f, Vector2(14, 22), "DEALER", HORIZONTAL_ALIGNMENT_LEFT, 120, 11, UI.SUB)
		if dealer_label != "":
			_tag(Vector2(size.x * 0.5, 34.0 + BlackjackPage.CARD.y + 18.0), dealer_label, UI.TEXT, UI.SIDE)
		# Bet circle with a chip stack.
		var bc := Vector2(size.x * 0.5, mid + 30.0)
		draw_arc(bc, 26.0, 0.0, TAU, 48, UI.FELT_LINE, 2.0, true)
		if bet_amount > 0.0:
			var ds := RoulettePage.denoms(Game.casino_max_bet())
			var tier := 0
			for i in range(ds.size()):
				if bet_amount >= float(ds[i]):
					tier = i
			for k in 3:
				draw_circle(bc + Vector2(0, 6 - k * 3), 19.0, Color(UI.INK, 0.4))
			RoulettePage.draw_chip(self, bc, 19.0, tier, RoulettePage.chip_text(bet_amount))
		# Player totals and outcomes.
		for i in range(hand_labels.size()):
			var hl: Dictionary = hand_labels[i]
			var p: Vector2 = hl["pos"]
			var txt := String(hl["text"])
			var fg := UI.TEXT
			var bg := UI.SIDE
			if i < outcomes.size():
				match String(outcomes[i]):
					"blackjack":
						txt = "Blackjack · win"
						fg = UI.INK
						bg = UI.GOLD
					"win":
						txt += " · win"
						fg = UI.INK
						bg = UI.GOLD
					"push":
						txt += " · push"
						fg = UI.TEXT
						bg = UI.RAISED
					"lose":
						txt += " · lose"
						fg = UI.SUB
						bg = UI.SIDE
					"bust":
						txt = String(hl["text"])
						fg = UI.DOWN
						bg = UI.SIDE
			if bool(hl["doubled"]):
				txt += " · x2"
			_tag(p, txt, fg, bg)
			if bool(hl["active"]):
				draw_line(p + Vector2(-34, 18), p + Vector2(34, 18), UI.GOLD, 3.0, true)

	func _tag(center: Vector2, text: String, fg: Color, bg: Color) -> void:
		var f: Font = UI.SEMI
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
		var r := Rect2(center - Vector2(w * 0.5, 13.0), Vector2(w, 26.0))
		draw_colored_polygon(UI.rounded_rect_poly(r, 13.0), bg)
		draw_string(f, Vector2(r.position.x, center.y + 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 14, fg)

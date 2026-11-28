class_name CasinoGame
extends Page
## The shared frame for every casino game, so all nine tables work the same:
##   title row    the game's name and an "i" (rules and pays, in a sheet)
##   status row   chips (as the page wants them shown), max bet, this round's
##                win counting up in gold, and "+" to buy chips
##   area         the game itself; it takes the height that is left
##   dock         bet bar or chip tray, an optional row of quiet buttons, and
##                ONE primary button, 56 px, its bottom just above the nav bar
## Subclasses write build_game() (not build()) and fill `area` and `dock`.
##
## Landscape (1.2): two columns. The game area on the left takes all the
## height; title, status and dock stack in a 300 px column on the right with
## the main button at its foot. (Side column 340 px since the bet bar got ½ and ×2.) Turning the phone only moves these nodes
## between the two layouts: nothing is rebuilt, so a round in play, its stake
## and the chips are never touched by a rotation.
##
## Colour rule (design pass): the primary is a TEXT fill; RED only for the one
## live action (Cash out while climbing) or the winning thing; GOLD for wins.

const PRIMARY_H := 56.0
const CONFETTI_X := 10.0          # a win this many times the stake gets confetti

var status: StatusRow
var area: VBoxContainer
var dock: VBoxContainer
var info_b: Button
var title_row: HBoxContainer
var split: HBoxContainer      # landscape: [area | side]
var side: VBoxContainer       # landscape: title, status, dock
const SIDE_W := 340.0   # room for the bet bar's six buttons
var auto_on := false         # autoplay (slots), shared so leaving always stops it
var auto_left := 0


func _init(t := "", _back := true) -> void:   # pushed page: back in the bottom bar (R10)
	super(t, true)


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # the table never scrolls while you play
	# Fill the screen, so the dock sits on the bottom bar on every game.
	var margin := body.get_parent() as Control
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_row()
	status = StatusRow.new()
	body.add_child(status)
	area = VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 10)
	body.add_child(area)
	dock = VBoxContainer.new()
	dock.add_theme_constant_override("separation", 8)
	body.add_child(dock)
	split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	split.visible = false
	body.add_child(split)
	side = VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_W
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	build_game()
	_apply_layout()
	Kit.layout_changed.connect(func(_l: bool): _apply_layout())
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			stop_auto())
	tree_exiting.connect(stop_auto)


func build_game() -> void:
	pass


func _title_row() -> void:
	if _title_label == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	title_row = row
	var at := _title_label.get_index()
	body.remove_child(_title_label)
	body.add_child(row)
	body.move_child(row, at)
	row.add_child(_title_label)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fit_title()
	info_b = UI.pill("", UI.RAISED, UI.TEXT, 15, 24)
	info_b.custom_minimum_size = Vector2(48, 48)
	info_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := Icon.new("info", UI.TEXT, 22.0)
	ic.position = Vector2(13, 13)
	info_b.add_child(ic)
	info_b.pressed.connect(func():
		Kit.tick()
		show_info())
	Kit.press_fx(info_b)
	row.add_child(info_b)


func _fit_title() -> void:
	## Tanker 36, smaller for a long name so it stays on one line (in landscape
	## the title shares the 300 px side column).
	if _title_label == null:
		return
	var avail := (SIDE_W if Kit.landscape else 358.0) - 56.0
	var fs := 36 if not Kit.landscape else 30
	while fs > 22 and UI.DISPLAY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
		fs -= 2
	_title_label.add_theme_font_size_override("font_size", fs)


func _move(n: Control, to: Control) -> void:
	if n == null or n.get_parent() == to:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	to.add_child(n)


func _apply_layout() -> void:
	## Portrait: title, status, area, dock down the page. Landscape: area on the
	## left, the rest in a column on the right. Only re-parents; never rebuilds.
	if split == null or area == null:
		return
	var land := Kit.landscape
	if land:
		_move(area, split)
		_move(side, split)
		for n in [title_row, status, dock]:
			_move(n, side)
		# The dock sits at the foot of the side column.
		var spacer := side.get_node_or_null("DockSpacer")
		if spacer == null:
			spacer = Control.new()
			spacer.name = "DockSpacer"
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			side.add_child(spacer)
		side.move_child(spacer, side.get_child_count() - 1)
		side.move_child(dock, side.get_child_count() - 1)
		area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.visible = true
	else:
		var order := [title_row, status, area, dock]
		for n in order:
			_move(n, body)
		var i := 1   # after the gap that keeps clear of the cash pill
		for n in order:
			if n != null:
				body.move_child(n, i)
				i += 1
		split.visible = false
	_fit_title()
	_fit_column()
	layout_changed_game(land)


func layout_changed_game(_landscape: bool) -> void:
	## Games that need more than the frame's move (e.g. a fixed board size) override this.
	pass


func _fit_column() -> void:
	## The table uses the whole width in landscape (no 600 px column), and the
	## main button sits just above the bottom edge.
	if _margin == null:
		return
	if Kit.landscape:
		_margin.add_theme_constant_override("margin_left", 16)
		_margin.add_theme_constant_override("margin_right", 16)
		_margin.add_theme_constant_override("margin_bottom", 12)
	else:
		super()


# ---- the "i" sheet ---------------------------------------------------------------

func show_info() -> void:
	## Rules and pays in a centred sheet. Games give info_content().
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(info_content())
	box.add_child(note("Max bet %s, max win %s a round. Both grow with your income." % [Game.money_short(Game.casino_max_bet()), Game.money_short(Game.casino_max_win())]))
	Kit.sheet(title, "", [{"text": "Close", "style": "plain"}], true, box)


func info_content() -> Control:
	return note("")


static func note(text: String, color: Color = UI.SUB) -> Label:
	## A wrapped 13 px line for info sheets.
	var l := UI.label(text, 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	return l


static func pay_line(left: String, right: String, lit := false) -> Control:
	## One row of a pay table: name on the left, pay on the right.
	var h := HBoxContainer.new()
	var a := UI.label(left, 15, UI.GOLD if lit else UI.TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UI.label(right, 15, UI.GOLD if lit else UI.SUB, true))
	return h


# ---- the dock ----------------------------------------------------------------------

func primary(text: String, call: Callable) -> Button:
	## The one main button: full width, 56 px, TEXT fill. Added to the dock last.
	var b := UI.pill(text, UI.TEXT, UI.INK, 17, 28)
	b.custom_minimum_size = Vector2(0, PRIMARY_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A "not yet" button still calls the page, which says why (and may offer chips).
	b.pressed.connect(call)
	Kit.press_fx(b)
	return b


static func set_go(b: Button, on: bool, live := false) -> void:
	## Ready: TEXT fill. Live (the one thing to tap now): RED. Not yet: RAISED,
	## still tappable so a tap can shake and say why.
	b.disabled = false
	b.set_meta("blocked", not on)
	if not on:
		UI.paint(b, UI.RAISED, UI.SUB, 28)
	elif live:
		UI.paint(b, UI.RED, UI.TEXT, 28)
	else:
		UI.paint(b, UI.TEXT, UI.INK, 28)


static func quiet(text: String, call: Callable) -> Button:
	## A second action (Auto, Bonus, Undo, Clear...): RAISED, 48 px, 15 px text.
	var b := UI.pill(text, UI.RAISED, UI.TEXT, 15, 24)
	b.custom_minimum_size = Vector2(48, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if call.is_valid():
		b.pressed.connect(call)
	Kit.press_fx(b)
	return b


func dock_row(buttons: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for b in buttons:
		h.add_child(b)
	dock.add_child(h)
	return h


# ---- results -------------------------------------------------------------------------

func win_fx(paid: float, stake: float, big_x := CONFETTI_X, at := Vector2.INF) -> void:
	## The same answer on every game: the win counts up in gold, a win buzzes,
	## a big one throws confetti, a loss gives a soft tap. Never blocks a tap.
	## A jackpot won on this round is paid here and gets its own celebration.
	var jp := Game.settle_jackpot()
	if jp > 0.0:
		jackpot_fx(jp, at)
		status.set_chips(Game.chips())
		status.set_win(paid + jp, true)
		return
	status.set_win(paid, paid > stake + 0.001)
	if paid > stake + 0.001:
		Kit.haptic("success")
		if paid >= stake * big_x:
			Kit.sound("fanfare")
			if not Motion.reduced():
				var p := at if at != Vector2.INF else area.get_global_rect().get_center()
				get_tree().root.get_node("Kit").add_child(Confetti.new(p, 60))
	elif paid > 0.0:
		Kit.haptic("selection")
	else:
		Kit.haptic("light")


func jackpot_fx(amount: float, at := Vector2.INF) -> void:
	## Gold "JACKPOT" over the game, confetti and the centred celebration card.
	## Nothing here blocks a tap; the money is already in chips.
	Kit.haptic("success")
	Kit.celebrate("Jackpot", title, "+" + Game.money_short(amount))
	var p := at if at != Vector2.INF else area.get_global_rect().get_center()
	if not Motion.reduced():
		get_tree().root.get_node("Kit").add_child(Confetti.new(p, 140))
	var f := JackpotFlash.new()
	area.add_child(f)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh_jackpot()


func refresh_jackpot() -> void:
	if status != null:
		status.set_jackpot(Game.jackpot_pot())


class JackpotFlash extends Control:
	## Rays and a big gold JACKPOT across the game for a moment.
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(d: float) -> void:
		_t += d
		if _t > 2.6 or Motion.reduced() and _t > 1.6:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var a := clampf(minf(_t / 0.25, (2.6 - _t) / 0.6), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UI.INK, 0.45 * a))
		var rays := 18
		var r := maxf(size.x, size.y)
		for i in rays:
			var ang := TAU * float(i) / float(rays) + _t * 0.6
			var p1 := c + Vector2(cos(ang - 0.06), sin(ang - 0.06)) * r
			var p2 := c + Vector2(cos(ang + 0.06), sin(ang + 0.06)) * r
			draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(UI.GOLD, 0.10 * a))
		var f: Font = UI.DISPLAY
		var fs := int(clampf(size.x / 6.0, 30.0, 64.0))
		var w := f.get_string_size("JACKPOT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - w * 0.5, c.y + fs * 0.35)
		var pulse := 1.0 + 0.04 * sin(_t * 9.0)
		draw_set_transform(c, 0.0, Vector2(pulse, pulse))
		draw_string_outline(f, pos - c + Vector2(0, 3), "JACKPOT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(UI.INK, 0.8 * a))
		draw_string(f, pos - c, "JACKPOT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.GOLD, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- the last results strip ---------------------------------------------------------

var results: ResultStrip


func add_results_strip(key: String) -> void:
	## A thin row of the last five rounds (won or lost, after the stake) at the
	## top of the game area. Kept in Game.ui, so it survives leaving the page.
	results = ResultStrip.new(key)
	area.add_child(results)
	area.move_child(results, 0)


func record_result(stake: float, paid: float) -> void:
	if results != null:
		results.add(paid - stake)


func offer_chips() -> void:
	if Game.cash >= 0.01:
		TradeSheet.open("chips", "", "chips_in")


# ---- autoplay (slots) ----------------------------------------------------------------

func auto_spin() -> bool:
	## One autoplay round. Games with autoplay return false when it can't start.
	return false


func _start_auto(n: int) -> void:
	auto_on = true
	auto_left = n
	refresh()
	if not is_busy() and not auto_spin():
		stop_auto()


func is_busy() -> bool:
	return false


func stop_auto() -> void:
	if not auto_on:
		return
	auto_on = false
	auto_left = 0
	if is_inside_tree():
		refresh()


func is_auto() -> bool:
	return auto_on


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		stop_auto()



# ---- chips and bets (shared maths for the tables) ----------------------------------

static func nice(x: float) -> float:
	## Rounds down to 1, 2 or 5 times a power of ten.
	if x < 1.0:
		return 1.0
	var p := pow(10.0, floor(log(x) / log(10.0)))
	var m := x / p
	return (1.0 if m < 2.0 else (2.0 if m < 5.0 else 5.0)) * p


static func denoms(max_bet: float) -> Array:
	## Five chip values that fit the table limit.
	var out: Array = []
	for f in [0.01, 0.05, 0.1, 0.25, 0.5]:
		var v := nice(max_bet * f)
		if not out.has(v):
			out.append(v)
	return out


static func chip_text(v: float) -> String:
	if v >= 1000.0:
		return Game.money_short(v).substr(1)
	return str(int(v))


static func chip_tier(amount: float) -> int:
	var ds := denoms(Game.casino_max_bet())
	var tier := 0
	for i in range(ds.size()):
		if amount >= float(ds[i]):
			tier = i
	return tier


static func draw_chip(ci: CanvasItem, c: Vector2, r: float, tier: int, text: String) -> void:
	## A casino chip lit from the top left: a soft shadow, the edge with six
	## inlaid stripes, a raised rim, a dashed inner ring and the value.
	var col: Color = UI.CHIP_COL[tier % UI.CHIP_COL.size()]
	var light := tier % UI.CHIP_COL.size() == 0
	var mark: Color = UI.INK if light else UI.TEXT
	ci.draw_circle(c + Vector2(0, r * 0.14), r * 1.02, Color(UI.INK, 0.45))   # shadow on the felt
	ci.draw_circle(c, r, col.darkened(0.18))                                   # edge
	ci.draw_circle(c + Vector2(0, -r * 0.05), r * 0.97, col)
	for i in 6:   # inlaid edge stripes, a touch longer than wide
		var a := TAU * float(i) / 6.0 + 0.26
		ci.draw_arc(c, r * 0.84, a - 0.2, a + 0.2, 8, Color(mark, 0.92), r * 0.26, true)
	ci.draw_circle(c, r * 0.66, col.lightened(0.06))                         # raised centre
	ci.draw_arc(c, r * 0.66, 0.0, TAU, 40, Color(UI.INK, 0.35), 1.6, true)
	var dash := 18
	for i in dash:   # dashed inner ring
		var a0 := TAU * float(i) / float(dash)
		ci.draw_arc(c, r * 0.56, a0, a0 + TAU / float(dash) * 0.5, 3, Color(mark, 0.55), 1.0, true)
	ci.draw_arc(c, r * 0.95, PI * 1.05, PI * 1.55, 12, Color(UI.TEXT, 0.35 if not light else 0.6), 1.4, true)   # top-left sheen
	var fs := int(clampf(r * 0.62, 9.0, 15.0))
	if text.length() > 3:
		fs = int(fs * 0.8)
	ci.draw_string(UI.SEMI, c + Vector2(-r, fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, UI.INK if light else UI.TEXT)


static func draw_chip_stack(ci: CanvasItem, c: Vector2, r: float, tier: int, text: String, n := 3) -> void:
	## A short stack: the lower chips show only their edges, the top one its face.
	for k in range(n - 1, 0, -1):
		var p := c + Vector2(0, float(k) * r * 0.22)
		var col: Color = UI.CHIP_COL[(tier + k) % UI.CHIP_COL.size()]
		ci.draw_circle(p + Vector2(0, r * 0.14), r * 1.02, Color(UI.INK, 0.35))
		ci.draw_circle(p, r, col.darkened(0.25))
		for i in 6:
			var a := TAU * float(i) / 6.0
			ci.draw_arc(p, r * 0.98, a + 0.35 - 0.12, a + 0.35 + 0.12, 4, Color(UI.TEXT, 0.55), r * 0.08, true)
	draw_chip(ci, c, r, tier, text)


static func draw_table(ci: CanvasItem, r: Rect2, radius := 20.0, rail := 7.0) -> Rect2:
	## A card table: a padded rail around green felt with a soft pool of light
	## in the middle and a faint weave. Returns the felt rect inside the rail.
	ci.draw_colored_polygon(UI.rounded_rect_poly(r, radius), UI.SIDE)
	ci.draw_colored_polygon(UI.rounded_rect_poly(r.grow(-1.0), radius - 1.0), UI.SIDE.lerp(UI.RAISED, 0.35))
	ci.draw_polyline(_top_edge(r.grow(-1.5), radius - 1.5), Color(UI.TEXT, 0.18), 1.2, true)   # light on the rail's top edge
	var felt := r.grow(-rail)
	var fr := maxf(4.0, radius - rail)
	ci.draw_colored_polygon(UI.rounded_rect_poly(felt.grow(1.5), fr + 1.5), Color(UI.INK, 0.6))   # rail's inner shadow
	ci.draw_colored_polygon(UI.rounded_rect_poly(felt, fr), UI.FELT.darkened(0.12))
	# Light pooled in the middle, fading to the edges (a few soft steps).
	for k in 5:
		var t := float(k + 1) / 6.0
		var rr := Rect2(felt.position + felt.size * t * 0.18, felt.size * (1.0 - t * 0.36))
		ci.draw_colored_polygon(UI.rounded_rect_poly(rr, maxf(4.0, fr * (1.0 - t * 0.4))), Color(UI.FELT.lightened(0.06), 0.28))
	# The weave: faint diagonal threads, wide apart so it reads as cloth, not noise.
	var weave := Color(UI.TEXT, 0.025)
	var step := 9.0
	var x := felt.position.x - felt.size.y
	while x < felt.end.x:
		var a := Vector2(x, felt.end.y)
		var b := Vector2(x + felt.size.y, felt.position.y)
		var lo := maxf(0.0, (felt.position.x - a.x) / felt.size.y)
		var hi := minf(1.0, (felt.end.x - a.x) / felt.size.y)
		if hi > lo:
			ci.draw_line(a.lerp(b, lo), a.lerp(b, hi), weave, 1.0)
		x += step
	return felt


static func _top_edge(r: Rect2, radius: float) -> PackedVector2Array:
	## The upper arc of a rounded rect: left corner, top edge, right corner.
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI + PI * 0.5 * float(i) / 6.0
		pts.append(Vector2(r.position.x + radius, r.position.y + radius) + Vector2(cos(a), sin(a)) * radius)
	for i in 7:
		var a := PI * 1.5 + PI * 0.5 * float(i) / 6.0
		pts.append(Vector2(r.end.x - radius, r.position.y + radius) + Vector2(cos(a), sin(a)) * radius)
	return pts


static func draw_frame(ci: CanvasItem, r: Rect2, radius := 16.0, face: Color = UI.PANEL) -> Rect2:
	## A bevelled machine frame: dark outer edge, a lit top bevel, a shadowed
	## lower bevel and a recessed face. Returns the face rect.
	ci.draw_colored_polygon(UI.rounded_rect_poly(r, radius), UI.SIDE)
	ci.draw_colored_polygon(UI.rounded_rect_poly(r.grow(-1.0), radius - 1.0), face.lerp(UI.RAISED, 0.5))
	ci.draw_polyline(_top_edge(r.grow(-1.5), radius - 1.5), Color(UI.TEXT, 0.22), 1.2, true)
	var inner := r.grow(-5.0)
	var ir := maxf(4.0, radius - 5.0)
	ci.draw_colored_polygon(UI.rounded_rect_poly(inner.grow(1.0), ir + 1.0), Color(UI.INK, 0.7))
	ci.draw_colored_polygon(UI.rounded_rect_poly(inner, ir), face)
	ci.draw_polyline(_top_edge(Rect2(inner.position + Vector2(0, 1), inner.size), ir), Color(UI.INK, 0.5), 2.0, true)   # recess shadow
	return inner


static func draw_ball(ci: CanvasItem, p: Vector2, r: float, col: Color = UI.TEXT) -> void:
	## A small polished ball: contact shadow, body, a darker lower half and a
	## bright highlight up and to the left.
	ci.draw_circle(p + Vector2(r * 0.25, r * 0.4), r * 1.05, Color(UI.INK, 0.45))
	ci.draw_circle(p, r, col.darkened(0.25))
	ci.draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.84, col)
	ci.draw_circle(p + Vector2(-r * 0.35, -r * 0.38), r * 0.3, Color(UI.TEXT.lightened(0.4), 0.95))


static func draw_arc_text(ci: CanvasItem, center: Vector2, radius: float, a_mid: float, text: String, fs: int, col: Color, font: Font = null) -> void:
	## Text printed along an arc (like the layout on a card table), centred on
	## angle a_mid; letters stand upright facing the centre.
	var f: Font = font if font != null else UI.SEMI
	var widths: Array = []
	var total := 0.0
	for ch in text:
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w
	# On the lower half of the circle (a smile, like a card table's printed
	# arc) the text runs the other way so it still reads left to right.
	var lower := sin(a_mid) > 0.0
	var dir := -1.0 if lower else 1.0
	var a := a_mid - dir * total * 0.5 / radius
	for i in text.length():
		var w: float = widths[i]
		var am := a + dir * w * 0.5 / radius
		var p := center + Vector2(cos(am), sin(am)) * radius
		ci.draw_set_transform(p, am - PI / 2.0 if lower else am + PI / 2.0)
		ci.draw_string(f, Vector2(-w * 0.5, fs * 0.35), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		a += dir * w / radius
	ci.draw_set_transform(Vector2.ZERO, 0.0)


# =====================================================================================

class StatusRow extends HBoxContainer:
	## Chips and max bet on the left, this round's win on the right, then "+".
	## Pages pass the chips to show: they lag while a result plays out.
	var chips_l: Label
	var max_l: Label
	var jp_l: Label
	var win_l: Label
	var buy_b: Button
	var _tw: Tween
	var _ctw: Tween

	func _init() -> void:
		custom_minimum_size = Vector2(0, 56)
		add_theme_constant_override("separation", 12)
		var pad := Control.new()   # inner padding: the row sits on its own panel
		pad.custom_minimum_size = Vector2(2, 0)   # (12 px with the separation)
		add_child(pad)
		var lv := VBoxContainer.new()
		lv.add_theme_constant_override("separation", -2)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(lv)
		chips_l = UI.display("", 22)
		lv.add_child(chips_l)
		max_l = UI.label("", 13, UI.SUB)
		lv.add_child(max_l)
		jp_l = UI.label("", 13, UI.GOLD)
		jp_l.clip_text = true
		jp_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lv.add_child(jp_l)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", -2)
		rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(rv)
		win_l = UI.display("-", 22, UI.SUB)
		win_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rv.add_child(win_l)
		var wc := UI.label("Win", 13, UI.SUB)
		wc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rv.add_child(wc)
		buy_b = UI.pill("", UI.RAISED, UI.TEXT, 15, 24)
		buy_b.custom_minimum_size = Vector2(48, 48)
		buy_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ic := Icon.new("plus", UI.TEXT, 22.0)
		ic.position = Vector2(13, 13)
		buy_b.add_child(ic)
		buy_b.pressed.connect(func():
			Kit.tick()
			if Game.cash < 0.01:
				Kit.toast("No cash to spend")
				return
			TradeSheet.open("chips", "", "chips_in"))
		Kit.press_fx(buy_b)
		add_child(buy_b)
		var pad2 := Control.new()
		pad2.custom_minimum_size = Vector2(0, 0)   # 4 px after the + button
		add_child(pad2)

	func _draw() -> void:
		# A quiet panel behind chips, limits and win, so they read as one unit.
		var r := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(UI.rounded_rect_poly(r, 16.0), UI.PANEL)
		draw_polyline(CasinoGame._top_edge(r.grow(-1.0), 15.0), Color(UI.TEXT, 0.06), 1.0, true)

	func set_chips(v: float) -> void:
		if _ctw and _ctw.is_valid():
			_ctw.kill()
		chips_l.text = Game.money(v)
		max_l.text = "Chips · max bet " + Game.money_short(Game.casino_max_bet())
		set_jackpot(Game.jackpot_pot())

	func set_jackpot(v: float) -> void:
		if jp_l != null:
			jp_l.text = "Jackpot " + Game.money_short(v)

	func tween_chips(from: float, to: float) -> void:
		## The chips glide to their new value (slots, after the reels stop).
		max_l.text = "Chips · max bet " + Game.money_short(Game.casino_max_bet())
		if Motion.reduced() or absf(to - from) < 0.005:
			set_chips(to)
			return
		if _ctw and _ctw.is_valid():
			_ctw.kill()
		_ctw = create_tween()
		_ctw.tween_method(func(f: float): chips_l.text = Game.money(f), from, to, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	func set_win(v: float, gold := true) -> void:
		## Counts up; gold only when more came back than was staked. 0 shows a dash.
		if _tw and _tw.is_valid():
			_tw.kill()
		if v <= 0.0:
			win_l.text = "-"
			win_l.add_theme_color_override("font_color", UI.SUB)
			return
		win_l.add_theme_color_override("font_color", UI.GOLD if gold else UI.TEXT)
		if Motion.reduced():
			win_l.text = Game.money_short(v)
			return
		_tw = create_tween()
		_tw.tween_method(func(f: float): win_l.text = Game.money_short(f), 0.0, v, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	func clear_win() -> void:
		set_win(0.0)


class ResultStrip extends HBoxContainer:
	## Up to five small chips, newest first: "+£1.2K" in gold for a win,
	## "−£500" in grey for a loss. Quiet on purpose: no big numbers to chase.
	const KEEP := 5
	var key := ""

	func _init(k := "") -> void:
		key = k
		custom_minimum_size = Vector2(0, 28)
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := UI.label("Last", 13, UI.SUB)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(t)
		_paint()

	static func _all() -> Dictionary:
		if typeof(Game.ui.get("casino_last")) != TYPE_DICTIONARY:
			Game.ui["casino_last"] = {}
		return Game.ui["casino_last"]

	func add(net: float) -> void:
		var all := _all()
		var list: Array = all.get(key, [])
		list.push_front(snappedf(net, 0.01))
		while list.size() > KEEP:
			list.pop_back()
		all[key] = list
		_paint()

	func _paint() -> void:
		for i in range(get_child_count() - 1, 0, -1):
			var c := get_child(i)
			remove_child(c)
			c.queue_free()
		var list: Array = _all().get(key, [])
		get_child(0).visible = not list.is_empty()
		for v in list:
			var net := float(v)
			var won := net > 0.004
			var t := ("+" if won else ("−" if net < -0.004 else "")) + Game.money_short(absf(net))
			var l := UI.label(t, 13, UI.GOLD if won else UI.SUB, won)
			l.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 12, 10, 4))
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(l)


class BetBar extends HBoxContainer:
	## The bet: - and + step through round amounts up to the table limit, Max
	## jumps to the limit. `locked` while a round runs (the amount stays
	## readable; only the buttons fade). Slots with their own ladders set
	## `external` and answer the stepped / maxed signals themselves.
	signal stepped(d: int)
	signal maxed
	var value := 0.0
	var locked := false:
		set(v):
			locked = v
			for b in [minus, plus, mx, half, dbl]:
				if b:
					(b as Control).modulate.a = 0.4 if v else 1.0
	var external := false:
		set(v):
			external = v
			# Slots step through their own line-bet ladders: no ½ / ×2 there.
			for b in [half, dbl]:
				if b:
					(b as Control).visible = not v
	var minus: Button
	var plus: Button
	var mx: Button
	var half: Button     # ½ and ×2: quick halving and doubling (hidden on slots' own ladders)
	var dbl: Button
	var _mid: VBoxContainer
	var _l: Label
	var _sub: Label
	var _ladder: Array = []

	func _init() -> void:
		add_theme_constant_override("separation", 6)
		custom_minimum_size = Vector2(0, 52)
		half = _b("½", 48)
		half.pressed.connect(func(): _scale(0.5))
		add_child(half)
		minus = _b("-", 48)
		minus.pressed.connect(func(): _step(-1))
		add_child(minus)
		var mid := VBoxContainer.new()
		_mid = mid
		mid.resized.connect(_fit_value)
		mid.add_theme_constant_override("separation", -4)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mid)
		_l = UI.display("", 24)
		_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_child(_l)
		_sub = UI.label("", 13, UI.SUB)
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.visible = false
		mid.add_child(_sub)
		plus = _b("+", 48)
		plus.pressed.connect(func(): _step(1))
		add_child(plus)
		dbl = _b("×2", 48)
		dbl.add_theme_font_size_override("font_size", 17)
		dbl.pressed.connect(func(): _scale(2.0))
		add_child(dbl)
		mx = _b("Max", 56)
		mx.add_theme_font_size_override("font_size", 15)
		mx.pressed.connect(func():
			if locked:
				Motion.shake(mx)
				return
			Kit.haptic("selection")
			if external:
				maxed.emit()
				return
			_rebuild()
			value = _ladder[_ladder.size() - 1]
			_show())
		add_child(mx)

	func _b(t: String, w: float) -> Button:
		var b := UI.pill(t, UI.RAISED, UI.TEXT, 22, 14)
		b.custom_minimum_size = Vector2(w, 52)
		Kit.press_fx(b)
		return b

	func show_text(t: String, sub := "") -> void:
		_l.text = t
		_sub.text = sub
		_sub.visible = sub != ""
		_fit_value()

	func _fit_value() -> void:
		## The amount shrinks (24 down to 15) rather than run out of its slot.
		if _l == null or _mid == null or _mid.size.x <= 0.0:
			return
		var fs := 24
		while fs > 15 and UI.DISPLAY.get_string_size(_l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _mid.size.x - 2.0:
			fs -= 1
		_l.add_theme_font_size_override("font_size", fs)

	func _scale(f: float) -> void:
		## ½ halves the bet, ×2 doubles it, inside the table's smallest and
		## largest bet. Off the - / + ladder is fine: any amount can be bet.
		if locked:
			Motion.shake(half if f < 1.0 else dbl)
			return
		_rebuild()
		var lo: float = _ladder[0]
		var hi: float = _ladder[_ladder.size() - 1]
		var nv := clampf(floor(value * f * 100.0) / 100.0, lo, hi)
		if absf(nv - value) < 0.005:
			Motion.shake(half if f < 1.0 else dbl)
			if f > 1.0:
				Kit.toast("Table limit: %s" % Game.money_short(hi))
			return
		Kit.haptic("selection")
		value = nv
		_show()

	func _rebuild() -> void:
		var top := Game.casino_max_bet()
		_ladder = []
		var v := CasinoGame.nice(maxf(1.0, top / 500.0))
		while v < top - 0.001 and _ladder.size() < 40:
			_ladder.append(v)
			var p := pow(10.0, floor(log(v) / log(10.0)))
			var m := roundf(v / p)
			v = (2.0 if m < 2.0 else (5.0 if m < 5.0 else 10.0)) * p
		_ladder.append(top)

	func refresh() -> void:
		if external:
			return
		_rebuild()
		if value <= 0.0:
			value = _ladder[mini(3, _ladder.size() - 1)]
		value = minf(value, _ladder[_ladder.size() - 1])
		_show()

	func _step(d: int) -> void:
		if locked:
			Motion.shake(minus if d < 0 else plus)
			return
		if external:
			stepped.emit(d)
			return
		Kit.haptic("selection")
		_rebuild()
		var i := 0
		for k in range(_ladder.size()):
			if _ladder[k] <= value + 0.001:
				i = k
		var ni := clampi(i + d, 0, _ladder.size() - 1)
		if ni == i and d > 0 and value >= _ladder[_ladder.size() - 1] - 0.001:
			Motion.shake(plus)
			Kit.toast("Table limit: %s" % Game.money_short(Game.casino_max_bet()))
		value = _ladder[ni]
		_show()

	func _show() -> void:
		show_text(Game.money_short(value))


class ChipButton extends Button:
	## A round casino chip you can tap; the chosen one sits up on a gold ring.
	var value := 1.0
	var tier := 0
	var selected := false

	func _init(v := 1.0, t := 0) -> void:
		value = v
		tier = t
		focus_mode = Control.FOCUS_NONE
		flat = true
		custom_minimum_size = Vector2(52, 52)
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5 - Vector2(0, 3.0 if selected else 0.0)
		if selected:
			draw_circle(c + Vector2(0, 3), 26.0, UI.GOLD)
		CasinoGame.draw_chip(self, c, 22.0, tier, CasinoGame.chip_text(value))

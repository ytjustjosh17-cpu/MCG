class_name RebirthPage
extends Page
## Rebirth and the RBP tree. The top card says how many RBP a rebirth gives
## now; the map below is the tree: drag to move around, pinch or use + and -
## to zoom, tap a node to see what it gives and buy it.

var _rbp: Label
var _sub: Label
var _go: Button
var _view: TreeView
var _top_panel: Control
var _key: Control
var _split: HBoxContainer   # landscape: hero on the left, the map on the right
var _left: VBoxContainer


func _init() -> void:
	super("Rebirth", true)


func build() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED   # the map moves, not the page
	var top := card()
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	top.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	_rbp = UI.display("", 32)
	_rbp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_rbp)
	var info := UI.pill("?", UI.RAISED, UI.TEXT, 17, 16)
	info.custom_minimum_size = Vector2(48, 48)
	info.pressed.connect(_explain)
	Kit.press_fx(info)
	h.add_child(info)
	_sub = UI.label("", 13, UI.SUB)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sub)
	_go = UI.pill("", UI.TEXT, UI.INK, 17, 24)
	_go.custom_minimum_size = Vector2(0, 48)
	_go.pressed.connect(_confirm)
	Kit.press_fx(_go)
	v.add_child(_go)
	var key := Legend.new()
	body.add_child(key)
	_view = TreeView.new()
	_view.node_tapped.connect(_on_node)
	body.add_child(_view)
	_top_panel = top.get_parent()
	_key = key
	_split = HBoxContainer.new()
	_split.add_theme_constant_override("separation", 16)
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 12)
	_left.custom_minimum_size.x = 280.0
	_split.add_child(_left)
	Kit.layout_changed.connect(func(_l: bool): _arrange())


func _ready() -> void:
	super()
	_arrange()


func _arrange() -> void:
	## Portrait: title, hero card, legend and the map one under another.
	## Landscape: title, hero and legend in a left column; the map fills the
	## rest of the width and the height. The same nodes move, nothing is rebuilt.
	if _view == null:
		return
	var land := Kit.landscape
	var nodes: Array = [_title_label, _top_panel, _key]
	if land and _split.get_parent() == null:
		for n in nodes:
			if n != null and n.get_parent() != null:
				n.get_parent().remove_child(n)
				_left.add_child(n)
		_view.get_parent().remove_child(_view)
		_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_split.add_child(_view)
		body.add_child(_split)
	elif not land and _split.get_parent() != null:
		body.remove_child(_split)
		for n in nodes:
			if n != null and n.get_parent() == _left:
				_left.remove_child(n)
				body.add_child(n)
		_split.remove_child(_view)
		body.add_child(_view)
	_fit_map.call_deferred()


func _fit_map() -> void:
	# The map fills what's left of the screen above the bottom bar (portrait)
	# or down to the bottom edge (landscape).
	await get_tree().process_frame
	if not is_instance_valid(_view) or not is_inside_tree():
		return
	var used := _view.global_position.y
	if Kit.landscape:
		_view.custom_minimum_size.y = maxf(240.0, get_viewport_rect().size.y - used - 24.0)
	else:
		_view.custom_minimum_size.y = maxf(320.0, get_viewport_rect().size.y - used - 104.0)


func refresh() -> void:
	if _rbp == null:
		return
	_rbp.text = "%s RBP" % Game.group(Game.rbp_free())
	var pend := Game.rebirth_pending()
	var owned := Game.tree_owned_count()
	var total := RebirthTree.nodes().size() - 1
	_sub.text = "Rebirths %d · %d of %d nodes" % [Game.rebirths(), owned, total]
	# Waiting pays: show what ten times the net worth would give.
	var nw := maxf(Game.net_worth(), Data.REBIRTH_MIN)
	var later := Game.rbp_for(nw * 10.0)
	if pend > 0:
		_sub.text += "\nNow +%s RBP · at %s: +%s" % [Game.group(pend), Game.money_short(nw * 10.0), Game.group(later)]
	else:
		_sub.text += "\nFirst RBP at %s net worth" % Game.money_short(Data.REBIRTH_MIN)
	if pend > 0:
		_go.text = "Rebirth · +%s RBP" % Game.group(pend)
		Page.set_enabled(_go, true)
	else:
		_go.text = "Rebirth at %s net worth" % Game.money_short(Data.REBIRTH_MIN)
		Page.set_enabled(_go, false)
	if _view:
		_view.queue_redraw()


func _explain() -> void:
	Kit.tick()
	Kit.sheet("How rebirth works",
		"From %s net worth, rebirth to start again for RBP. Richer means more RBP.\n\nBuy nodes linked to ones you own. They stay forever.\n\nDrag to move, pinch or +/- to zoom, tap a node." % Game.money_short(Data.REBIRTH_MIN),
		[{"text": "Got it", "style": "plain"}])


func _confirm() -> void:
	var pend := Game.rebirth_pending()
	if pend <= 0:
		return
	Kit.tick()
	Kit.sheet("Rebirth for %s RBP?" % Game.group(pend),
		"Lose: money, companies, property, shares, coins, miners, items, home, level, Head office, unclaimed rewards.\nKeep: the tree, RBP, achievements, stats, settings.",
		[{"text": "Rebirth · +%s RBP" % Game.group(pend), "style": "primary", "call": _do_rebirth},
		 {"text": "Not yet", "style": "plain"}])


func _do_rebirth() -> void:
	var got := Game.do_rebirth()
	if got <= 0:
		return
	Kit.haptic("success")
	Kit.sound("fanfare")
	Kit.toast("Reborn · +%s RBP" % Game.group(got), true)
	if not Motion.reduced():
		var c := Confetti.new(Vector2(get_viewport_rect().size.x * 0.5, 200.0), 80)
		get_tree().root.get_node("Kit").add_child(c)
	refresh()


func _on_node(id: String) -> void:
	var n := RebirthTree.node(id)
	if n.is_empty():
		return
	Kit.tick()
	if id == "core":
		Kit.sheet("Sol", "The centre of your tree. Everything grows out from here.", [{"text": "Close", "style": "plain"}])
		return
	var cost := int(n["cost"])
	var kinds := {"small": "", "notable": "Notable · ", "key": "Keystone · ", "unlock": "Unlock · "}
	var body := String(kinds.get(n["kind"], "")) + RebirthTree.describe(n["fx"])
	var actions: Array = []
	if Game.node_owned(id):
		body += "\n\nOwned."
	elif not Game.node_open(id):
		body += "\n\nCosts %d RBP. Buy a node next to it first." % cost
	elif Game.rbp_free() < cost:
		body += "\n\nCosts %d RBP. You have %d." % [cost, Game.rbp_free()]
	else:
		body += "\n\nYou have %d RBP." % Game.rbp_free()
		actions.append({"text": "Buy · %d RBP" % cost, "style": "primary", "call": func():
			if Game.buy_node(id):
				Kit.haptic("success")
				Kit.sound("buy")
				Kit.toast(String(n["name"]) + " bought", true)
				_view.flash(id)
				refresh()})
	actions.append({"text": "Close", "style": "plain"})
	Kit.sheet(String(n["name"]), body, actions)


class TreeView extends Control:
	## The tree map. Draws in tree space through a pan offset and zoom.
	signal node_tapped(id: String)
	const ZMIN := 0.35
	const ZMAX := 1.6
	var zoom := 0.62
	var pan := Vector2.ZERO          # screen offset of the centre from the view middle
	var _press := false
	var _press_pos := Vector2.ZERO
	var _dragging := false
	var _touches := {}               # index -> position, for pinch
	var _pinch_d := 0.0
	var _flash_id := ""
	var _flash_t := 0.0
	var _btns: HBoxContainer         # +, - and re-centre: taps there never reach the map

	func _init() -> void:
		custom_minimum_size = Vector2(0, 420)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		# Zoom and centre buttons, 48 px, in a low row at the bottom right
		# (thumb side), see-through so nodes behind them still show.
		var col := HBoxContainer.new()
		_btns = col
		col.add_theme_constant_override("separation", 8)
		col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		col.grow_vertical = Control.GROW_DIRECTION_BEGIN
		col.offset_right = -8
		col.offset_bottom = -8
		add_child(col)
		for spec in [["+", 1.25], ["-", 0.8], ["o", 0.0]]:
			var b := UI.pill("" if spec[0] == "o" else String(spec[0]), Color(UI.RAISED, 0.72), UI.TEXT, 20, 0)
			b.custom_minimum_size = Vector2(48, 48)
			var f: float = spec[1]
			if spec[0] == "o":
				var ic := Icon.new("home", UI.TEXT, 22.0)
				ic.position = Vector2(13, 13)
				b.add_child(ic)
			b.pressed.connect(func():
				Kit.haptic("selection")
				if f == 0.0:
					_glide_to(Vector2.ZERO, 0.62)
				else:
					_glide_to(pan * (clampf(zoom * f, ZMIN, ZMAX) / zoom), clampf(zoom * f, ZMIN, ZMAX)))
			col.add_child(b)

	func _ready() -> void:
		# Kit lets every button pass presses on to what is behind it (so lists
		# scroll). Here that opened the node under the button: stop them.
		for b in _btns.get_children():
			(b as Control).mouse_filter = Control.MOUSE_FILTER_STOP

	func _on_buttons(p: Vector2) -> bool:
		## True for a point on the zoom and centre buttons (with a few pixels spare).
		return _btns != null and _btns.get_rect().grow(4.0).has_point(p)

	func flash(id: String) -> void:
		_flash_id = id
		_flash_t = 1.0
		set_process(true)

	func _process(delta: float) -> void:
		if _flash_t > 0.0:
			_flash_t = maxf(0.0, _flash_t - delta * 1.6)
			queue_redraw()
		else:
			set_process(false)

	func _glide_to(p: Vector2, z: float) -> void:
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "pan", p, Motion.d(0.28)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "zoom", z, Motion.d(0.28)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		t.tween_method(func(_v): queue_redraw(), 0.0, 1.0, Motion.d(0.28))

	func to_screen(n: Dictionary) -> Vector2:
		return size * 0.5 + pan + Vector2(float(n["x"]), float(n["y"])) * zoom

	func _gui_input(e: InputEvent) -> void:
		# Two fingers: pinch to zoom (touch events), and the trackpad gesture.
		if e is InputEventScreenTouch:
			if e.pressed:
				_touches[e.index] = e.position
			else:
				_touches.erase(e.index)
			_pinch_d = _pinch_dist()
			if _touches.size() >= 2:
				_dragging = true   # a pinch is never a tap
			accept_event()
			return
		if e is InputEventScreenDrag:
			_touches[e.index] = e.position
			if _touches.size() >= 2:
				var d := _pinch_dist()
				if _pinch_d > 0.0 and d > 0.0:
					_zoom_about(d / _pinch_d, _pinch_mid())
				_pinch_d = d
			accept_event()
			return
		if e is InputEventMagnifyGesture:
			_zoom_about(e.factor, e.position)
			accept_event()
			return
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
				_zoom_about(1.1, e.position)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
				_zoom_about(0.9, e.position)
			elif e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					if _on_buttons(e.position):
						return   # the button handles it; never a tap on the map
					_press = true
					_dragging = false
					_press_pos = e.position
				else:
					if _press and not _dragging and _touches.size() < 2:
						_tap(e.position)
					_press = false
			accept_event()
		elif e is InputEventMouseMotion and _press:
			if _touches.size() >= 2:
				accept_event()
				return
			# A few pixels of wobble is still a tap, not a drag.
			if not _dragging and e.position.distance_to(_press_pos) > 14.0:
				_dragging = true
			if _dragging:
				pan += e.relative
				_clamp_pan()
				queue_redraw()
			accept_event()

	func _pinch_dist() -> float:
		if _touches.size() < 2:
			return 0.0
		var ps: Array = _touches.values()
		return (ps[0] as Vector2).distance_to(ps[1])

	func _pinch_mid() -> Vector2:
		var ps: Array = _touches.values()
		return ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5

	func _zoom_about(f: float, at: Vector2) -> void:
		var nz := clampf(zoom * f, ZMIN, ZMAX)
		var k := nz / zoom
		# Keep the point under the fingers still.
		var c := size * 0.5 + pan
		pan += (at - c) * (1.0 - k)
		zoom = nz
		_clamp_pan()
		queue_redraw()

	func _clamp_pan() -> void:
		var lim := RebirthTree.STEP * 15.5 * zoom
		pan = pan.clamp(Vector2(-lim, -lim), Vector2(lim, lim))

	func _tap(p: Vector2) -> void:
		if _on_buttons(p):
			return
		var best := ""
		var best_d := 30.0   # finger-sized: 30 px around the node counts
		for n in RebirthTree.nodes():
			var d := to_screen(n).distance_to(p)
			if d < best_d + _radius(n):
				if d - _radius(n) < best_d:
					best_d = d - _radius(n)
					best = String(n["id"])
		if best != "":
			node_tapped.emit(best)

	func _radius(n: Dictionary) -> float:
		var r: float = {"core": 30.0, "key": 22.0, "unlock": 20.0, "notable": 17.0, "small": 12.0}.get(n["kind"], 12.0)
		return r * clampf(zoom / 0.62, 0.7, 1.6)

	func _state(id: String) -> int:
		## 2 owned, 1 can be bought now, 0 open but too dear, -1 locked.
		if Game.node_owned(id):
			return 2
		if Game.node_open(id):
			return 1 if Game.rbp_free() >= int(RebirthTree.node(id)["cost"]) else 0
		return -1

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UI.WINDOW)
		# Faint rings for depth, like a star chart.
		var c := size * 0.5 + pan
		for k in [1.6, 4.9, 6.6, 12.1, 14.9]:
			draw_arc(c, RebirthTree.STEP * k * zoom, 0.0, TAU, 96, Color(UI.TEXT, 0.05), 1.0, true)
		var ns: Array = RebirthTree.nodes()
		# Links first, so nodes sit on top.
		var done := {}
		for n in ns:
			var a := String(n["id"])
			for l in n["links"]:
				var b := String(l)
				var key := a + "|" + b if a < b else b + "|" + a
				if done.has(key):
					continue
				done[key] = true
				var oa := Game.node_owned(a)
				var ob := Game.node_owned(b)
				var col := Color(UI.TEXT, 0.12)
				var w := 1.5
				if oa and ob:
					col = UI.RED
					w = 2.5
				elif oa or ob:
					col = Color(UI.TEXT, 0.45)
					w = 2.0
				draw_line(to_screen(n), to_screen(RebirthTree.node(b)), col, w, true)
		for n in ns:
			var p := to_screen(n)
			var r := _radius(n)
			if p.x < -r - 8.0 or p.y < -r - 8.0 or p.x > size.x + r + 8.0 or p.y > size.y + r + 8.0:
				continue
			var id := String(n["id"])
			if id == "core":
				draw_circle(p, r + 6.0, Color(UI.RED, 0.18))
				draw_circle(p, r, UI.RED)
				draw_circle(p, r * 0.62, Color(UI.INK, 0.25))
				continue
			var st := _state(id)
			var kind := String(n["kind"])
			# Owned: solid. Can buy now: a soft halo and a bright ring. Open but
			# too dear: a grey ring. Locked: barely there.
			var fill: Color = UI.TEXT if st == 2 else (UI.RAISED if st == 1 else (UI.PANEL if st == 0 else UI.WINDOW))
			var ring: Color = UI.TEXT if st >= 1 else (UI.SUB if st == 0 else UI.TRACK)
			var ink: Color = UI.INK if st == 2 else (UI.TEXT if st == 1 else (UI.SUB if st == 0 else UI.DIM))
			var pts := _shape(kind, p, r)
			if st == 1:
				draw_colored_polygon(_shape(kind, p, r + 5.0), Color(UI.TEXT, 0.14))
			draw_colored_polygon(pts, fill)
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, ring, 2.0 if st >= 0 else 1.0, true)
			if kind == "unlock":
				draw_arc(p, r + 5.0, 0.0, TAU, 40, UI.TEXT if st >= 1 else UI.SUB, 2.0, true)   # unlocks get an outer ring
			elif kind == "key" and st >= 0:
				var outer := _shape(kind, p, r + 4.0)
				outer.append(outer[0])
				draw_polyline(outer, Color(ring, 0.5), 1.0, true)   # keystones: a second, fainter rim
			var tex := Icon.texture(Icon.MAP.get(String(n["icon"]), String(n["icon"])), st == 2)
			if tex and r >= 9.0:
				var sz := r * 1.1
				draw_texture_rect(tex, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, ink)
			if id == _flash_id and _flash_t > 0.0:
				draw_arc(p, r + 4.0 + (1.0 - _flash_t) * 18.0, 0.0, TAU, 40, Color(UI.RED, _flash_t), 3.0, true)
		_draw_labels(ns)

	func _draw_labels(ns: Array) -> void:
		## Each branch name sits right beside its own trunk (never between two
		## branches), on whichever side has more room.
		var f: Font = UI.SEMI
		var fs := 12
		var keep_out := _btns.get_rect().grow(8.0) if _btns else Rect2()
		for br in RebirthTree.BRANCHES:
			var txt := String(br[1]).to_upper()
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var th := 14.0
			var g1 := RebirthTree.node("%s_t1" % br[0])
			var g2 := RebirthTree.node("%s_t2" % br[0])
			var out := Vector2(float(g2["x"]), float(g2["y"])).normalized()
			var perp := Vector2(-out.y, out.x)
			# How far the box reaches towards the trunk, so its near edge sits
			# a fixed 8 px from the line whatever the branch's angle.
			var reach := absf(perp.x) * tw * 0.5 + absf(perp.y) * th * 0.5
			var best := Rect2()
			var best_score := -1.0e9
			for at in [(to_screen(g1) + to_screen(g2)) * 0.5, to_screen(g2)]:
				for sd in [1.0, -1.0]:
					var mid: Vector2 = at + perp * sd * (reach + 8.0 + 4.0)
					var box := Rect2(mid - Vector2(tw, th) * 0.5, Vector2(tw, th))
					var score := 1.0e6
					for n in ns:
						var q := to_screen(n)
						var cx := clampf(q.x, box.position.x, box.end.x)
						var cy := clampf(q.y, box.position.y, box.end.y)
						score = minf(score, Vector2(cx, cy).distance_to(q) - _radius(n))
					if box.intersects(keep_out):
						score -= 200.0
					if box.position.x < 4.0 or box.end.x > size.x - 4.0 or box.position.y < 4.0 or box.end.y > size.y - 4.0:
						score -= 100.0
					if score > best_score:
						best_score = score
						best = box
			# Never cut off at the map's edge: slide back inside.
			best.position.x = clampf(best.position.x, 4.0, maxf(4.0, size.x - best.size.x - 4.0))
			best.position.y = clampf(best.position.y, 4.0, maxf(4.0, size.y - best.size.y - 4.0))
			var tp := Vector2(best.position.x, best.end.y - 2.0)
			# A dark halo keeps the name readable over lines and nodes.
			draw_string_outline(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(UI.WINDOW, 0.95))
			draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.SUB)

	func _shape(kind: String, p: Vector2, r: float) -> PackedVector2Array:
		## Circle for small, diamond for notable, hexagon for keystones,
		## an eight-point star for unlocks.
		var pts := PackedVector2Array()
		if kind == "unlock":
			for i in 16:
				var a := TAU * float(i) / 16.0 - PI / 2.0
				pts.append(p + Vector2(cos(a), sin(a)) * r * (1.0 if i % 2 == 0 else 0.72))
			return pts
		var n := 20
		var rot := 0.0
		if kind == "notable":
			n = 4
		elif kind == "key":
			n = 6
			rot = PI / 6.0
		for i in n:
			var a := rot + TAU * float(i) / float(n) - (PI / 2.0 if kind == "notable" else 0.0)
			pts.append(p + Vector2(cos(a), sin(a)) * r * (1.25 if kind == "notable" else 1.0))
		return pts


class Legend extends Control:
	## One line above the map: what the three node looks mean.
	const ITEMS := [["Owned", 2], ["Can buy", 1], ["Locked", -1]]

	func _init() -> void:
		custom_minimum_size = Vector2(0, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f: Font = UI.REG
		var fs := 13
		var cx := 10.0
		var cy := size.y * 0.5
		for it in ITEMS:
			var st: int = it[1]
			var c := Vector2(cx, cy)
			if st == 1:
				draw_circle(c, 9.0, Color(UI.TEXT, 0.14))
			draw_circle(c, 6.0, UI.TEXT if st == 2 else (UI.RAISED if st == 1 else UI.WINDOW))
			draw_arc(c, 6.0, 0.0, TAU, 24, UI.TEXT if st >= 1 else UI.TRACK, 1.5, true)
			draw_string(f, Vector2(cx + 13.0, cy + 5.0), String(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.SUB)
			cx += 13.0 + f.get_string_size(String(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 22.0

class_name MinerRack
extends Control
## A little live view of your miners: a shelf of machines (10 to a row) with
## spinning fans and blinking lights, and coins of the mined coin floating up.
## Owned machines are lit; the rest of the row is drawn as thin outlines.
## Still with Less motion on; no redraws at all while there's nothing to move.

const COLS := 10
const GAP := 6.0
const BOX_H := 30.0
const ROW_GAP := 8.0
const TOP := 16.0
const FPS := 20.0        # enough for small fans; keeps the page cheap
var _t := 0.0
var _coins: Array = []   # [x, y, life]
var _spawn := 0.0
var _acc := 0.0
var _rows := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true   # rising coins never draw over the card above
	resized.connect(queue_redraw)
	_fit()


func _ready() -> void:
	Game.changed.connect(_on_changed)   # a new miner or coin shows even with Less motion


func _on_changed() -> void:
	if _fit() or Game.reduce_motion or Game.rigs_total() == 0:
		queue_redraw()


func _slots() -> int:
	## The rows in use plus room for the next miner, never more than the max.
	var n := Game.rigs_total()
	return clampi(int(ceil(float(n + 1) / COLS)) * COLS, COLS, maxi(COLS, Data.RIG_MAX))


func _fit() -> bool:
	## Grows the shelf a row at a time. True when the height changed.
	var rows := _slots() / COLS
	if rows == _rows:
		return false
	_rows = rows
	custom_minimum_size = Vector2(0, TOP + 4.0 + rows * BOX_H + (rows - 1) * ROW_GAP)   # the card adds its own padding under it
	return true


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Game.reduce_motion:
		return
	var n := Game.rigs_total()
	if n == 0 and _coins.is_empty():
		return   # nothing moves: no redraw
	_t += delta * (1.0 + 0.5 * float(Game.mine_eff.get(Game.mine_target, 1.0)))
	if n > 0:
		_spawn -= delta
		if _spawn <= 0.0:
			_spawn = maxf(0.25, 1.4 - 0.08 * float(n))
			var r := _box(randi() % mini(n, _slots()))
			_coins.append([r.get_center().x, r.position.y, 1.0])
	var i := _coins.size() - 1
	while i >= 0:
		var c: Array = _coins[i]
		c[1] -= delta * 28.0
		c[2] -= delta * 0.9
		if c[2] <= 0.0:
			_coins.remove_at(i)
		i -= 1
	_acc += delta
	if _acc >= 1.0 / FPS:
		_acc = 0.0
		queue_redraw()


func _box(i: int) -> Rect2:
	var w := (size.x - 32.0 - GAP * float(COLS - 1)) / float(COLS)
	var col := i % COLS
	var row := i / COLS
	return Rect2(16.0 + col * (w + GAP), TOP + row * (BOX_H + ROW_GAP), w, BOX_H)


func _draw() -> void:
	var n := Game.rigs_total()
	for i in _slots():
		var r := _box(i)
		if i >= n:
			# An empty bay: a thin outline only.
			draw_rect(r, UI.TRACK, false, 1.0)
			continue
		draw_rect(r, UI.RAISED, true)
		# Case: a lighter top edge, a darker base, vent slats on the left.
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), Color(UI.TEXT, 0.18), true)
		draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), Color(UI.INK, 0.6), true)
		for v in 3:
			draw_rect(Rect2(r.position.x + 2.0, r.position.y + 6.0 + v * 4.0, 3.0, 1.0), Color(UI.INK, 0.7), true)
		# Fan: a grille ring, three blades turning, a hub.
		var c := Vector2(r.position.x + r.size.x * 0.5, r.get_center().y + 2.0)
		var rad := minf(r.size.x, r.size.y) * 0.3
		draw_circle(c, rad + 1.5, UI.INK)
		draw_arc(c, rad + 1.5, 0.0, TAU, 20, Color(UI.SUB, 0.35), 1.0, true)
		for b in 3:
			var a := _t * 9.0 + TAU * float(b) / 3.0 + float(i)
			draw_line(c, c + Vector2(cos(a), sin(a)) * rad, UI.SUB, 2.0, true)
		draw_circle(c, 1.6, UI.TEXT)
		# A row of tiny status lights (red stays for the sun): one blinks.
		var blink := fmod(_t * 2.0 + float(i) * 0.37, 1.0) < 0.55
		draw_circle(Vector2(r.end.x - 5.0, r.position.y + 5.0), 2.0, UI.TEXT if blink else UI.TRACK)
		draw_circle(Vector2(r.end.x - 5.0, r.position.y + 10.0), 1.2, Color(UI.GOLD, 0.8))
		# Heat shimmer rising off the top while it works.
		if not Game.reduce_motion:
			var hx := r.position.x + r.size.x * 0.5
			var hp := PackedVector2Array()
			for q in 5:
				var yy := r.position.y - 1.0 - q * 2.2
				hp.append(Vector2(hx + sin(_t * 6.0 + q * 1.3 + i) * 2.0, yy))
			draw_polyline(hp, Color(UI.TEXT, 0.12), 1.0, true)
	# Coins rising out of the machines.
	if _coins.is_empty():
		return
	var tgt := Game.mine_target if Game.mine_target != "" else Game._first_coin_owned()
	var tex := AssetTile.logo(tgt) if tgt != "" else null
	for cn in _coins:
		var p := Vector2(float(cn[0]), float(cn[1]))
		var a := clampf(float(cn[2]), 0.0, 1.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, a))
		else:
			draw_circle(p, 7.0, Color(UI.asset_color(tgt), a))

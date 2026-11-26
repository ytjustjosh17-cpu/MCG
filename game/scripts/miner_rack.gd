class_name MinerRack
extends Control
## A little live view of your miners: a rack of machines with spinning fans
## and blinking lights, and coins of the mined coin floating up out of them.
## Still with Less motion on.

const SLOTS := 12        # boxes shown; more miners show as "+N"
var _t := 0.0
var _coins: Array = []   # [x, y, life]
var _spawn := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true   # rising coins never draw over the card above


func _ready() -> void:
	Game.changed.connect(queue_redraw)   # a new miner or coin shows even with Less motion


func _process(delta: float) -> void:
	if not is_visible_in_tree() or Game.reduce_motion:
		return
	var n := Game.rigs_total()
	_t += delta * (1.0 + 0.5 * float(Game.mine_eff.get(Game.mine_target, 1.0)))
	if n > 0:
		_spawn -= delta
		if _spawn <= 0.0:
			_spawn = maxf(0.25, 1.4 - 0.08 * float(n))
			var slot := randi() % mini(n, SLOTS)
			var r := _box(slot)
			_coins.append([r.get_center().x, r.position.y, 1.0])
	for c in _coins:
		c[1] -= delta * 28.0
		c[2] -= delta * 0.9
	_coins = _coins.filter(func(c): return c[2] > 0.0)
	queue_redraw()


func _box(i: int) -> Rect2:
	var cols := 6
	var gap := 8.0
	var w := (size.x - 32.0 - gap * float(cols - 1)) / float(cols)
	var h := 38.0
	var col := i % cols
	var row := i / cols
	return Rect2(16.0 + col * (w + gap), 18.0 + row * (h + 10.0), w, h)


func _draw() -> void:
	var n := Game.rigs_total()
	for i in SLOTS:
		var r := _box(i)
		var on := i < n
		draw_rect(r, UI.RAISED if on else UI.WINDOW, true)
		# Fan: three blades turning.
		var c := Vector2(r.position.x + r.size.x * 0.38, r.get_center().y)
		var rad := minf(r.size.x, r.size.y) * 0.28
		draw_circle(c, rad + 2.0, UI.INK)
		if on:
			for b in 3:
				var a := _t * 9.0 + TAU * float(b) / 3.0 + float(i)
				draw_line(c, c + Vector2(cos(a), sin(a)) * rad, UI.SUB, 2.5, true)
		# Status light: blinks red while mining.
		var blink := on and fmod(_t * 2.0 + float(i) * 0.37, 1.0) < 0.55
		draw_circle(Vector2(r.end.x - 7.0, r.position.y + 7.0), 3.0, UI.RED if blink else UI.TRACK)
		# Vents.
		for v in 3:
			draw_rect(Rect2(r.end.x - 14.0, r.position.y + 14.0 + v * 6.0, 9.0, 2.0), UI.INK if on else UI.PANEL, true)
	if n > SLOTS:
		var f: Font = UI.SEMI
		draw_string(f, Vector2(size.x - 52.0, 14.0), "+%d" % (n - SLOTS), HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 13, UI.SUB)
	# Coins rising out of the machines.
	var tgt := Game.mine_target if Game.mine_target != "" else Game._first_coin_owned()
	var tex := AssetTile.logo(tgt) if tgt != "" else null
	for cn in _coins:
		var p := Vector2(float(cn[0]), float(cn[1]))
		var a := clampf(float(cn[2]), 0.0, 1.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(p - Vector2(9, 9), Vector2(18, 18)), false, Color(1, 1, 1, a))
		else:
			draw_circle(p, 8.0, Color(UI.asset_color(tgt), a))

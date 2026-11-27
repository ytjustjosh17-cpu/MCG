class_name TowerMath
extends RefCounted
## Tower: climb rows of boxes. Each row hides one or two bad boxes; pick a
## safe one to climb, cash out between rows, or lose the stake on a bad one.
## The whole tower is laid out when you bet (roll_layout), so a pick only
## reveals what was already decided and a restore can't re-roll it.
## Cashing out after k safe rows pays EDGE x (boxes / safe)^k, so every
## cash-out point pays back EDGE (97%) on average. Rows are trimmed so the
## top prize stays under 200x (the casino's smallest win cap over its
## biggest bet), so the ladder is never cut short by the cap.

const EDGE := 0.97
const MODES := {
	"easy": {"name": "Easy", "boxes": 3, "bad": 1, "rows": 8},
	"medium": {"name": "Medium", "boxes": 2, "bad": 1, "rows": 7},
	"hard": {"name": "Hard", "boxes": 3, "bad": 2, "rows": 4},
}
const ORDER := ["easy", "medium", "hard"]

var rng := RandomNumberGenerator.new()


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


static func mode(m: String) -> Dictionary:
	return MODES.get(m, MODES["easy"])


static func mult(m: String, step: int) -> float:
	## What cashing out after `step` safe rows pays, times the stake (0 at the start).
	if step <= 0:
		return 0.0
	var d := mode(m)
	var odds := float(d["boxes"]) / float(int(d["boxes"]) - int(d["bad"]))
	return floor(EDGE * pow(odds, step) * 100.0) / 100.0


func roll_layout(m: String) -> Array:
	## For each row, the bad box numbers (0-based), bottom row first.
	var d := mode(m)
	var out: Array = []
	for r in int(d["rows"]):
		var boxes: Array = range(int(d["boxes"]))
		var bad: Array = []
		for k in int(d["bad"]):
			var i := rng.randi_range(0, boxes.size() - 1)
			bad.append(boxes[i])
			boxes.remove_at(i)
		bad.sort()
		out.append(bad)
	return out


static func is_safe(layout: Array, row: int, pick: int) -> bool:
	if row < 0 or row >= layout.size():
		return false
	return not (layout[row] as Array).has(pick)

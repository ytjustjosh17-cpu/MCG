class_name PlinkoMath
extends RefCounted
## Plinko: a ball falls through 12 rows of pegs, going left or right at each
## one, and lands in one of 13 slots. Three risk tables; each pays back about
## 97 to 98% (worked out exactly in `rtp()`).

const ROWS := 12
const TABLES := {
	"low": [10.0, 3.0, 1.6, 1.3, 1.1, 1.0, 0.5, 1.0, 1.1, 1.3, 1.6, 3.0, 10.0],
	"medium": [30.0, 10.0, 4.0, 2.0, 1.1, 0.6, 0.3, 0.6, 1.1, 2.0, 4.0, 10.0, 30.0],
	"high": [155.0, 24.0, 8.0, 2.0, 0.7, 0.2, 0.2, 0.2, 0.7, 2.0, 8.0, 24.0, 155.0],
}

var rng := RandomNumberGenerator.new()


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func drop() -> Dictionary:
	## {path: Array of 12 ints (0 left, 1 right), slot: 0..12}
	var path: Array = []
	var slot := 0
	for i in ROWS:
		var r := rng.randi() % 2
		path.append(r)
		slot += r
	return {"path": path, "slot": slot}


static func mult(risk: String, slot: int) -> float:
	return float(TABLES[risk][slot])


static func rtp(risk: String) -> float:
	## Exact payback: sum over slots of P(slot) x multiplier.
	var t := 0.0
	for k in range(ROWS + 1):
		t += _choose(ROWS, k) / pow(2.0, ROWS) * mult(risk, k)
	return t


static func _choose(n: int, k: int) -> float:
	var r := 1.0
	for i in range(1, k + 1):
		r = r * float(n - k + i) / float(i)
	return r

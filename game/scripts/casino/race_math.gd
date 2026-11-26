class_name RaceMath
extends RefCounted
## Races: six made-up cars. Each race has a fresh "form": every runner gets a
## chance to win, and the odds offered are 0.95 / chance, so a bet pays back
## 95% on average whichever car you back. The winner is drawn at the start
## from those chances; the rest of the order is random.

const EDGE := 0.95
const RUNNERS := [
	["Red Comet", "red"], ["Iron Duke", "iron"], ["Tern Flyer", "tern"],
	["Salt Runner", "salt"], ["Night Lark", "lark"], ["Ember Twelve", "ember"],
]
const FORM := [0.32, 0.22, 0.16, 0.13, 0.10, 0.07]   # shuffled onto the runners each race

var rng := RandomNumberGenerator.new()
var chances: Array = []    # per runner, sums to 1
var odds: Array = []       # decimal odds (stake included)


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	new_form()


func new_form() -> void:
	## Shuffles who is the favourite for the next race.
	var f: Array = FORM.duplicate()
	for i in range(f.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = f[i]
		f[i] = f[j]
		f[j] = t
	chances = f
	odds = []
	for p in chances:
		odds.append(floor(EDGE / float(p) * 100.0) / 100.0)


func run() -> Array:
	## Finishing order (runner indexes), winner first, drawn from `chances`.
	var u := rng.randf()
	var win := chances.size() - 1
	for i in range(chances.size()):
		u -= float(chances[i])
		if u < 0.0:
			win = i
			break
	var rest: Array = []
	for i in range(chances.size()):
		if i != win:
			rest.append(i)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = rest[i]
		rest[i] = rest[j]
		rest[j] = t
	return [win] + rest


func rtp(runner: int) -> float:
	return float(chances[runner]) * float(odds[runner])

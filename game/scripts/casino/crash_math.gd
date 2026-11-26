class_name CrashMath
extends RefCounted
## Crash: a multiplier climbs from 1.00x until it crashes. The crash point is
## decided before the round starts, from a curve with a 3% house edge:
## the chance it reaches x is 0.97 / x, so cashing out at any target pays
## back 97% on average. It never goes past MAX_X.

const EDGE := 0.97
const MAX_X := 1000.0
const GROWTH := 0.12      # the shown multiplier is e^(GROWTH * seconds)

var rng := RandomNumberGenerator.new()


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func roll() -> float:
	## A crash point, in hundredths, from 1.00 up to MAX_X.
	var u := rng.randf()
	var x := EDGE / maxf(1e-9, 1.0 - u)
	x = floor(x * 100.0) / 100.0
	return clampf(x, 1.0, MAX_X)


static func at(seconds: float) -> float:
	## The multiplier shown after `seconds` of climbing.
	return exp(GROWTH * maxf(0.0, seconds))


static func time_to(x: float) -> float:
	## Seconds the curve takes to reach x.
	return log(maxf(1.0, x)) / GROWTH

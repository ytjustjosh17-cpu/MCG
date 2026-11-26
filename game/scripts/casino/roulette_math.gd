class_name RouletteMath
extends RefCounted
## European roulette (one zero), no pictures. Every bet returns 36/37 of its
## stake on average (house edge 2.7%), which tests/casino_test.gd checks by
## going through all 37 numbers.
##
## Bet types and their `arg`:
##   straight  a number 0-36             pays 35 to 1
##   split     [a, b] side by side       pays 17 to 1
##   street    first number of a row     pays 11 to 1 (1, 4, ... 34)
##   corner    [a, b, c, d] a square     pays 8 to 1
##   six       first number of a row     pays 5 to 1 (two rows: 1 ... 31)
##   dozen     1, 2 or 3                 pays 2 to 1
##   column    1, 2 or 3                 pays 2 to 1
##   red, black, odd, even, low (1-18), high (19-36)   pay 1 to 1 (arg unused)

## Pockets in wheel order, clockwise from zero.
const WHEEL := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
	5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const TYPES := ["straight", "split", "street", "corner", "six", "dozen", "column",
	"red", "black", "odd", "even", "low", "high"]

var rng := RandomNumberGenerator.new()


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


static func color(n: int) -> String:
	## "green", "red" or "black".
	if n == 0:
		return "green"
	return "red" if RED.has(n) else "black"


static func pocket_index(n: int) -> int:
	## Where a number sits on the wheel (0-36), for the spin animation.
	return WHEEL.find(n)


static func covered(bet_type: String, arg = null) -> Array:
	## The numbers a bet wins on ([] if the bet isn't valid).
	var out: Array = []
	match bet_type:
		"straight":
			if typeof(arg) in [TYPE_INT, TYPE_FLOAT] and int(arg) >= 0 and int(arg) <= 36:
				out = [int(arg)]
		"split":
			if arg is Array and arg.size() == 2 and _adjacent(int(arg[0]), int(arg[1])):
				out = [int(arg[0]), int(arg[1])]
		"street":
			var a := int(arg) if typeof(arg) in [TYPE_INT, TYPE_FLOAT] else -1
			if a >= 1 and a <= 34 and (a - 1) % 3 == 0:
				out = [a, a + 1, a + 2]
		"corner":
			if arg is Array and arg.size() == 4:
				var s: Array = arg.map(func(x): return int(x))
				s.sort()
				var a: int = s[0]
				if a >= 1 and a % 3 != 0 and s == [a, a + 1, a + 3, a + 4] and a + 4 <= 36:
					out = s
		"six":
			var a := int(arg) if typeof(arg) in [TYPE_INT, TYPE_FLOAT] else -1
			if a >= 1 and a <= 31 and (a - 1) % 3 == 0:
				out = [a, a + 1, a + 2, a + 3, a + 4, a + 5]
		"dozen":
			var d := int(arg) if typeof(arg) in [TYPE_INT, TYPE_FLOAT] else 0
			if d >= 1 and d <= 3:
				for n in range((d - 1) * 12 + 1, d * 12 + 1):
					out.append(n)
		"column":
			var c := int(arg) if typeof(arg) in [TYPE_INT, TYPE_FLOAT] else 0
			if c >= 1 and c <= 3:
				for n in range(c, 37, 3):
					out.append(n)
		"red":
			out = RED.duplicate()
		"black":
			for n in range(1, 37):
				if not RED.has(n):
					out.append(n)
		"odd":
			for n in range(1, 37, 2):
				out.append(n)
		"even":
			for n in range(2, 37, 2):
				out.append(n)
		"low":
			for n in range(1, 19):
				out.append(n)
		"high":
			for n in range(19, 37):
				out.append(n)
	return out


static func _adjacent(a: int, b: int) -> bool:
	## Side by side on the table (or 0 with 1, 2 or 3).
	var lo := mini(a, b)
	var hi := maxi(a, b)
	if lo < 0 or hi > 36 or lo == hi:
		return false
	if lo == 0:
		return hi <= 3
	if hi - lo == 3:
		return true
	return hi - lo == 1 and lo % 3 != 0


static func valid(bet_type: String, arg = null) -> bool:
	return not covered(bet_type, arg).is_empty()


static func payout(bet_type: String, arg, number: int) -> float:
	## What a bet of 1 gives back if `number` comes up, stake included
	## (36 / numbers covered, so 36 for a straight, 2 for red). 0 if it lost.
	var nums := covered(bet_type, arg)
	if nums.is_empty() or not nums.has(number):
		return 0.0
	return 36.0 / float(nums.size())


func spin(r: RandomNumberGenerator = null) -> int:
	## The winning number, 0-36.
	return (r if r != null else rng).randi_range(0, 36)


static func settle(bets: Array, n: int) -> float:
	## Total given back for a list of bets [{type, arg, amount}], stakes included.
	var back := 0.0
	for b in bets:
		back += float(b.get("amount", 0.0)) * payout(String(b.get("type", "")), b.get("arg"), n)
	return back

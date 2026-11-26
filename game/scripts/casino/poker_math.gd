class_name PokerMath
extends RefCounted
## Video poker, Jacks or Better, 9/6 table. A fresh 52-card deck for every
## hand (no memory between hands). Cards use BlackjackMath's shape:
## {rank: "A","2".."10","J","Q","K", suit: "hearts"/"diamonds"/"clubs"/"spades"}.
## With perfect play the table returns about 99.5%; the simple strategy in
## `auto_hold()` (used by tests and the Hint button) gets about 97.7%.

const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const SUITS := ["hearts", "diamonds", "clubs", "spades"]
# hand id, name, pays (multiple of the bet returned: 1 = your bet back)
const PAYTABLE := [
	["royal", "Royal flush", 800.0],
	["sflush", "Straight flush", 50.0],
	["four", "Four of a kind", 25.0],
	["full", "Full house", 9.0],
	["flush", "Flush", 6.0],
	["straight", "Straight", 4.0],
	["three", "Three of a kind", 3.0],
	["two", "Two pair", 2.0],
	["jacks", "Jacks or better", 1.0],
]

var rng := RandomNumberGenerator.new()
var deck: Array = []
var hand: Array = []


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


func deal() -> Array:
	## A fresh shuffled deck, five cards dealt.
	deck = []
	for s in SUITS:
		for r in RANKS:
			deck.append({"rank": r, "suit": s})
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = deck[i]
		deck[i] = deck[j]
		deck[j] = t
	hand = deck.slice(0, 5)
	deck = deck.slice(5)
	return hand


func draw(holds: Array) -> Array:
	## Replaces every card not held. holds: 5 bools.
	for i in 5:
		if not bool(holds[i]):
			hand[i] = deck.pop_back()
	return hand


static func rank_value(r: String) -> int:
	return RANKS.find(r) + 2


static func evaluate(cards: Array) -> String:
	## The best paying hand id, or "" for nothing.
	var vals: Array = []
	var counts := {}
	var suits := {}
	for c in cards:
		var v := rank_value(String(c["rank"]))
		vals.append(v)
		counts[v] = int(counts.get(v, 0)) + 1
		suits[c["suit"]] = true
	vals.sort()
	var flush := suits.size() == 1
	var straight := false
	if counts.size() == 5:
		if vals[4] - vals[0] == 4:
			straight = true
		elif vals == [2, 3, 4, 5, 14]:
			straight = true   # A-2-3-4-5
	if straight and flush:
		return "royal" if vals[0] == 10 else "sflush"
	var groups: Array = counts.values()
	groups.sort()
	if groups == [1, 4]:
		return "four"
	if groups == [2, 3]:
		return "full"
	if flush:
		return "flush"
	if straight:
		return "straight"
	if groups == [1, 1, 3]:
		return "three"
	if groups == [1, 2, 2]:
		return "two"
	if groups == [1, 1, 1, 2]:
		for v in counts.keys():
			if int(counts[v]) == 2 and int(v) >= 11:
				return "jacks"
	return ""


static func pays(id: String) -> float:
	## Multiple of the bet returned for a hand, 0 for nothing. As on a real
	## machine, "Jacks or better pays 1" means you get your bet back.
	for p in PAYTABLE:
		if p[0] == id:
			return float(p[2])
	return 0.0


static func name_of(id: String) -> String:
	for p in PAYTABLE:
		if p[0] == id:
			return String(p[1])
	return "No win"


static func auto_hold(cards: Array) -> Array:
	## A simple Jacks or Better strategy (the well-known short list).
	var vals: Array = []
	for c in cards:
		vals.append(rank_value(String(c["rank"])))
	var made := evaluate(cards)
	if made in ["royal", "sflush", "four", "full", "flush", "straight"]:
		return [true, true, true, true, true]
	var r4 := _to_royal(cards, 4)
	if not r4.is_empty():
		return r4
	if made == "three" or made == "two":
		return _hold_groups(vals)
	var sf4 := _to_flush_run(cards, 4, true)
	if not sf4.is_empty():
		return sf4
	if made == "jacks":
		return _hold_groups(vals)
	var r3 := _to_royal(cards, 3)
	if not r3.is_empty():
		return r3
	var f4 := _suited(cards, 4)
	if not f4.is_empty():
		return f4
	var low_pair := _hold_groups(vals)
	if low_pair.has(true):
		return low_pair
	var st4 := _outside_straight(vals)
	if not st4.is_empty():
		return st4
	# Two suited high cards.
	for s in SUITS:
		var hi: Array = []
		for i in 5:
			if cards[i]["suit"] == s and vals[i] >= 11:
				hi.append(i)
		if hi.size() >= 2:
			return _mask([hi[0], hi[1]])
	var sf3 := _to_flush_run(cards, 3, true)
	if not sf3.is_empty():
		return sf3
	# High cards: keep up to two (the lowest ones).
	var his: Array = []
	for i in 5:
		if vals[i] >= 11:
			his.append(i)
	his.sort_custom(func(a, b): return vals[a] < vals[b])
	if his.size() >= 2:
		return _mask([his[0], his[1]])
	if his.size() == 1:
		return _mask([his[0]])
	return [false, false, false, false, false]


static func _mask(idx: Array) -> Array:
	var m := [false, false, false, false, false]
	for i in idx:
		m[i] = true
	return m


static func _hold_groups(vals: Array) -> Array:
	var counts := {}
	for v in vals:
		counts[v] = int(counts.get(v, 0)) + 1
	var m := [false, false, false, false, false]
	for i in 5:
		if int(counts[vals[i]]) >= 2:
			m[i] = true
	return m


static func _to_royal(cards: Array, n: int) -> Array:
	for s in SUITS:
		var idx: Array = []
		for i in 5:
			if cards[i]["suit"] == s and rank_value(String(cards[i]["rank"])) >= 10:
				idx.append(i)
		if idx.size() == n:
			return _mask(idx)
	return []


static func _suited(cards: Array, n: int) -> Array:
	for s in SUITS:
		var idx: Array = []
		for i in 5:
			if cards[i]["suit"] == s:
				idx.append(i)
		if idx.size() == n:
			return _mask(idx)
	return []


static func _to_flush_run(cards: Array, n: int, need_flush: bool) -> Array:
	## n suited cards that fit inside a 5-wide run (straight flush draws).
	for s in SUITS:
		var idx: Array = []
		for i in 5:
			if cards[i]["suit"] == s or not need_flush:
				idx.append(i)
		if idx.size() < n:
			continue
		var vs: Array = []
		for i in idx:
			vs.append(rank_value(String(cards[i]["rank"])))
		for lo in range(1, 11):
			var pick: Array = []
			for k in range(idx.size()):
				var v: int = vs[k]
				var vv := 1 if v == 14 and lo == 1 else v
				if vv >= lo and vv <= lo + 4 and not pick.has(idx[k]):
					pick.append(idx[k])
			if pick.size() == n:
				return _mask(pick)
	return []


static func _outside_straight(vals: Array) -> Array:
	## Four cards in a row (both ends open), e.g. 6-7-8-9.
	var uniq := {}
	for i in 5:
		uniq[vals[i]] = i
	for lo in range(2, 11):
		var have := true
		for v in range(lo, lo + 4):
			if not uniq.has(v):
				have = false
		if have and lo + 3 < 14:
			var idx: Array = []
			for v in range(lo, lo + 4):
				idx.append(uniq[v])
			return _mask(idx)
	return []

class_name BlackjackMath
extends RefCounted
## Blackjack, no pictures. Six decks, shuffled fresh for EVERY hand, so
## counting cards can't work. Dealer stands on soft 17, peeks for blackjack,
## blackjack pays 3 to 2. Double on any first two cards (also after a
## split), split once (no re-split; split aces get one card each). No
## insurance. Basic strategy returns about 99.5% (tests/casino_test.gd).
##
## Flow for a page: deal(bet) -> while not is_over(): hit() / stand() /
## double() / split() -> result(). double() and split() return the extra
## stake the player must put in (charge it before calling). Cards are
## {rank: "A", "2".."10", "J", "Q", "K", suit: "hearts", "diamonds",
## "clubs", "spades"}, matching Kenney's card files (cardHeartsA.png).

const DECKS := 6
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUITS := ["hearts", "diamonds", "clubs", "spades"]
const BJ_PAYS := 1.5

var rng := RandomNumberGenerator.new()
var shoe: Array = []
var shoe_serial := 0          # goes up by one every deal (a fresh shoe each time)
var hands: Array = []         # [{cards, bet, done, doubled, split_aces, bust}]
var dealer: Array = []
var active := 0
var phase := "idle"           # idle, player, done
var _split_done := false
var _base_bet := 0.0


func _init(rng_seed := -1) -> void:
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


static func card_file(c: Dictionary) -> String:
	## Kenney file name for a card, e.g. "cardHeartsA.png".
	return "card%s%s.png" % [String(c["suit"]).capitalize(), String(c["rank"])]


static func card_value(c: Dictionary) -> int:
	var r := String(c["rank"])
	if r == "A":
		return 11
	if r in ["J", "Q", "K"]:
		return 10
	return int(r)


static func hand_value(cards: Array) -> Dictionary:
	## {total, soft}: soft means an ace still counts as 11.
	var total := 0
	var aces := 0
	for c in cards:
		var v := card_value(c)
		total += v
		if v == 11:
			aces += 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return {"total": total, "soft": aces > 0}


static func is_blackjack(cards: Array) -> bool:
	return cards.size() == 2 and int(hand_value(cards)["total"]) == 21


func cards_left() -> int:
	return shoe.size()


static var _full: Array = []


func _new_shoe() -> void:
	## A fresh, full six-deck shoe. Cards are drawn at random from what's
	## left (the same as a full shuffle, but quicker).
	if _full.is_empty():
		for d in range(DECKS):
			for s in SUITS:
				for r in RANKS:
					_full.append({"rank": r, "suit": s})
	shoe = _full.duplicate()
	shoe_serial += 1


func _draw() -> Dictionary:
	var i := rng.randi_range(0, shoe.size() - 1)
	var c: Dictionary = shoe[i]
	shoe[i] = shoe[shoe.size() - 1]
	shoe.pop_back()
	return c


func deal(bet: float) -> Dictionary:
	## Starts a hand with a fresh shoe. Ends at once if either side has blackjack.
	_new_shoe()
	_base_bet = bet
	_split_done = false
	hands = [{"cards": [], "bet": bet, "done": false, "doubled": false, "split_aces": false, "bust": false, "from_split": false}]
	dealer = []
	hands[0]["cards"].append(_draw())
	dealer.append(_draw())
	hands[0]["cards"].append(_draw())
	dealer.append(_draw())
	active = 0
	phase = "player"
	var dealer_bj := is_blackjack(dealer)
	if dealer_bj or is_blackjack(hands[0]["cards"]):
		# The dealer peeks: a dealer blackjack ends it before anything else.
		hands[0]["done"] = true
		phase = "done"
	return state()


func dealer_up() -> Dictionary:
	return dealer[0] if not dealer.is_empty() else {}


func current_hand() -> Dictionary:
	return hands[active] if active < hands.size() else {}


func is_over() -> bool:
	return phase == "done"


func can_hit() -> bool:
	return phase == "player" and not hands[active]["done"]


func can_double() -> bool:
	if phase != "player":
		return false
	var h: Dictionary = hands[active]
	return not h["done"] and h["cards"].size() == 2 and not h["split_aces"]


func can_split() -> bool:
	if phase != "player" or _split_done or hands.size() != 1:
		return false
	var c: Array = hands[0]["cards"]
	return c.size() == 2 and card_value(c[0]) == card_value(c[1])


func hit() -> Dictionary:
	if not can_hit():
		return state()
	var h: Dictionary = hands[active]
	h["cards"].append(_draw())
	var t := int(hand_value(h["cards"])["total"])
	if t > 21:
		h["bust"] = true
		h["done"] = true
	elif t == 21:
		h["done"] = true   # 21 stands by itself
	_advance()
	return state()


func stand() -> Dictionary:
	if phase == "player":
		hands[active]["done"] = true
		_advance()
	return state()


func double() -> float:
	## Doubles the bet, takes exactly one card and stands. Returns the extra
	## stake (0 if not allowed).
	if not can_double():
		return 0.0
	var h: Dictionary = hands[active]
	var extra: float = h["bet"]
	h["bet"] = float(h["bet"]) * 2.0
	h["doubled"] = true
	h["cards"].append(_draw())
	if int(hand_value(h["cards"])["total"]) > 21:
		h["bust"] = true
	h["done"] = true
	_advance()
	return extra


func split() -> float:
	## Splits a pair into two hands, each with the same bet. Returns the
	## extra stake (0 if not allowed).
	if not can_split():
		return 0.0
	_split_done = true
	var c: Array = hands[0]["cards"]
	var bet: float = hands[0]["bet"]
	var aces := String(c[0]["rank"]) == "A"
	hands = [
		{"cards": [c[0], _draw()], "bet": bet, "done": false, "doubled": false, "split_aces": aces, "bust": false, "from_split": true},
		{"cards": [c[1], _draw()], "bet": bet, "done": false, "doubled": false, "split_aces": aces, "bust": false, "from_split": true},
	]
	for h in hands:
		if aces or int(hand_value(h["cards"])["total"]) == 21:
			h["done"] = true   # split aces get one card each
	active = 0
	_advance()
	return bet


func _advance() -> void:
	while active < hands.size() and hands[active]["done"]:
		active += 1
	if active < hands.size():
		return
	active = hands.size() - 1
	# Dealer plays only if a hand is still standing.
	var any_live := false
	for h in hands:
		if not h["bust"]:
			any_live = true
	if any_live:
		while true:
			var v := hand_value(dealer)
			var t := int(v["total"])
			if t < 17:
				dealer.append(_draw())
			else:
				break   # stands on all 17s, soft 17 included
	phase = "done"


func result() -> Dictionary:
	## {payout_total (given back, stakes included), staked_total, hands:
	## [{cards, total, bet, outcome, payout}], dealer: {cards, total}}.
	## outcome: blackjack, win, push, lose, bust.
	var out: Array = []
	var back := 0.0
	var staked := 0.0
	var dv := int(hand_value(dealer)["total"])
	var dealer_bj := is_blackjack(dealer)
	for h in hands:
		var t := int(hand_value(h["cards"])["total"])
		var bet: float = h["bet"]
		staked += bet
		var outcome := "lose"
		var pay := 0.0
		var player_bj: bool = is_blackjack(h["cards"]) and not h["from_split"]
		if phase != "done":
			outcome = "playing"
		elif h["bust"]:
			outcome = "bust"
		elif player_bj and dealer_bj:
			outcome = "push"
			pay = bet
		elif player_bj:
			outcome = "blackjack"
			pay = bet * (1.0 + BJ_PAYS)
		elif dealer_bj:
			outcome = "lose"
		elif dv > 21 or t > dv:
			outcome = "win"
			pay = bet * 2.0
		elif t == dv:
			outcome = "push"
			pay = bet
		back += pay
		out.append({"cards": h["cards"], "total": t, "bet": bet, "outcome": outcome, "payout": pay})
	return {"payout_total": back, "staked_total": staked, "hands": out,
		"dealer": {"cards": dealer, "total": dv, "blackjack": dealer_bj}}


func state() -> Dictionary:
	## Everything a page needs to draw the table. The dealer's second card is
	## hidden until the hand is over.
	var dshow: Array = dealer.duplicate() if phase == "done" else [dealer[0]] if not dealer.is_empty() else []
	return {"phase": phase, "active": active, "hands": hands, "dealer_shown": dshow,
		"dealer_total": int(hand_value(dshow)["total"]), "can_hit": can_hit(),
		"can_double": can_double(), "can_split": can_split(), "over": is_over()}


static func basic_strategy(cards: Array, up: Dictionary, may_double := true, may_split := true) -> String:
	## The textbook move for six decks, dealer stands on soft 17, double
	## after split allowed: "hit", "stand", "double" or "split".
	var d := card_value(up)
	if d == 11:
		d = 1   # ace shown as 1 in the tables below (A = 1, then 2..10)
	var hv := hand_value(cards)
	var t := int(hv["total"])
	if may_split and cards.size() == 2 and card_value(cards[0]) == card_value(cards[1]):
		var p := card_value(cards[0])
		var split := false
		match p:
			11: split = true
			10: split = false
			9: split = d in [2, 3, 4, 5, 6, 8, 9]
			8: split = true
			7: split = d >= 2 and d <= 7
			6: split = d >= 2 and d <= 6
			5: split = false
			4: split = d == 5 or d == 6
			3, 2: split = d >= 2 and d <= 7
		if split:
			return "split"
	var can_dbl := may_double and cards.size() == 2
	if bool(hv["soft"]) and t <= 21:
		match t:
			21, 20: return "stand"
			19: return "double" if can_dbl and d == 6 else "stand"
			18:
				if d >= 2 and d <= 6:
					return "double" if can_dbl else "stand"
				return "stand" if d == 7 or d == 8 else "hit"
			17: return "double" if can_dbl and d >= 3 and d <= 6 else "hit"
			16, 15: return "double" if can_dbl and d >= 4 and d <= 6 else "hit"
			14, 13: return "double" if can_dbl and d >= 5 and d <= 6 else "hit"
			_: return "hit"
	if t >= 17:
		return "stand"
	if t >= 13:
		return "stand" if d >= 2 and d <= 6 else "hit"
	if t == 12:
		return "stand" if d >= 4 and d <= 6 else "hit"
	if t == 11:
		return "double" if can_dbl else "hit"
	if t == 10:
		return "double" if can_dbl and d >= 2 and d <= 9 else "hit"
	if t == 9:
		return "double" if can_dbl and d >= 3 and d <= 6 else "hit"
	return "hit"

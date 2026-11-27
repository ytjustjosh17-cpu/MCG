class_name RecordsPage
extends Page
## All-time bests, pushed from Profile. The richest you've been leads in big
## type; the rest are one row each with the day it was set. Records live in
## Game.counters, so they last through rebirths.

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var _hero_v: Label
var _hero_when: Label
var _rows: Array = []
var _days: Row


func _init() -> void:
	super("Records", true)


func build() -> void:
	var hc := card()
	var hp := padded(hc, 16, 14)
	hp.add_child(UI.label("Richest you've been", 13, UI.SUB))
	_hero_v = UI.display("", 40, UI.TEXT)
	hp.add_child(_hero_v)
	_hero_when = UI.label("", 13, UI.SUB)
	hp.add_child(_hero_when)
	var lc := card()
	var recs: Array = Game.records()
	for i in range(1, recs.size()):
		if i > 1:
			separator(lc, 16)
		var r := Row.new("", "", false)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lc.add_child(r)
		_rows.append(r)
	separator(lc, 16)
	_days = Row.new("", "", false)
	_days.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lc.add_child(_days)
	refresh()


func refresh() -> void:
	if _hero_v == null:
		return
	var recs: Array = Game.records()
	_hero_v.text = Game.money_short(float(recs[0][1]))
	_hero_when.text = when_text(float(recs[0][2]), "Set today")
	for i in range(_rows.size()):
		var rec: Array = recs[i + 1]
		var r: Row = _rows[i]
		var v := float(rec[1])
		var sub := when_text(float(rec[2]), "") if v > 0.0 else "Not yet"
		r.set_texts(str(rec[0]), sub, value_text(v, str(rec[3])) if v > 0.0 else "-")
	_days.set_texts("Days played", "Counts every day you open the game", value_text(float(Game.days_played()), "days"))


static func value_text(v: float, kind: String) -> String:
	match kind:
		"rate":
			return Game.money_short(v) + " /h"
		"days":
			return "%d day%s" % [int(v), "" if int(v) == 1 else "s"]
		"count":
			return Game.group(int(v))
	return Game.money_short(v)


static func when_text(at: float, fallback: String) -> String:
	## "Set 27 Nov" (the year only when it isn't this one).
	if at <= 0.0:
		return fallback
	var d := Time.get_datetime_dict_from_unix_time(int(at))
	var now := Time.get_datetime_dict_from_unix_time(int(Game.now()))
	var s := "Set %d %s" % [int(d["day"]), MONTHS[int(d["month"]) - 1]]
	if int(d["year"]) != int(now["year"]):
		s += " %d" % int(d["year"])
	return s

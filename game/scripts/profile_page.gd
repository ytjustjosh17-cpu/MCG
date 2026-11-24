class_name ProfilePage
extends Control
## Profile: fortune, stats and settings.

var _fortune: Label
var _stats: Array = []
var _vibrate_value: Label
var _reset_btn: Button
var _reset_armed := false
var _card_stats: Panel
var _card_settings: Panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UI.place(UI.label("Profile", 34, UI.TEXT, true), 20, 52))
	add_child(UI.place(UI.label("Fortune", 13, UI.SUB), 20, 104))
	_fortune = UI.label("", 34)
	add_child(UI.place(_fortune, 20, 122))

	_card_stats = UI.panel(UI.PANEL, 16)
	add_child(_card_stats)
	for i in range(3):
		var v := UI.label("", 17, UI.TEXT, true)
		var k := UI.label(["Level", "Taps", "Playing"][i], 13, UI.SUB)
		_card_stats.add_child(v)
		_card_stats.add_child(k)
		_stats.append([v, k])

	_card_settings = UI.panel(UI.PANEL, 16)
	_card_settings.clip_contents = true
	add_child(_card_settings)
	var vib := UI.flat_button()
	vib.name = "Vibrate"
	vib.add_child(UI.place(UI.label("Vibrate on tap", 17), 16, 13))
	_vibrate_value = UI.label("", 17, UI.SUB)
	_vibrate_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vib.add_child(_vibrate_value)
	vib.pressed.connect(func():
		Game.vibrate = not Game.vibrate
		Game.save_game()
		_refresh())
	_card_settings.add_child(vib)

	_reset_btn = UI.pill("Start again", UI.RAISED, UI.TEXT, 17, 22)
	_reset_btn.pressed.connect(_on_reset)
	add_child(_reset_btn)
	var note := UI.label("Saved on this phone", 13, UI.SUB)
	note.name = "Note"
	add_child(note)

	resized.connect(_layout)
	Game.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_layout()


func _layout() -> void:
	var w := size.x
	_card_stats.position = Vector2(16, 176)
	_card_stats.size = Vector2(w - 32, 64)
	var cw := (w - 32) / 3.0
	for i in range(3):
		_stats[i][0].position = Vector2(i * cw + 16, 10)
		_stats[i][1].position = Vector2(i * cw + 16, 34)
	_card_settings.position = Vector2(16, 256)
	_card_settings.size = Vector2(w - 32, 48)
	var vib: Button = _card_settings.get_node("Vibrate")
	vib.size = Vector2(w - 32, 48)
	_vibrate_value.size = Vector2(80, 24)
	_vibrate_value.position = Vector2(w - 32 - 16 - 80, 12)
	_reset_btn.position = Vector2(16, 328)
	_reset_btn.size = Vector2(w - 32, 48)
	var note: Label = get_node("Note")
	note.position = Vector2(20, 392)
	_refresh()


func _refresh() -> void:
	if _fortune == null:
		return
	_fortune.text = Game.money(Game.net_worth())
	_stats[0][0].text = str(Game.level)
	_stats[1][0].text = Game.group(Game.taps)
	var days := int((Game.now() - Game.started_at) / 86400.0) + 1
	_stats[2][0].text = "%d day%s" % [days, "" if days == 1 else "s"]
	_vibrate_value.text = "On" if Game.vibrate else "Off"


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Tap again to wipe everything"
		get_tree().create_timer(3.0).timeout.connect(func():
			_reset_armed = false
			_reset_btn.text = "Start again")
		return
	_reset_armed = false
	_reset_btn.text = "Start again"
	Game.reset_game()

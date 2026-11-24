extends Control
## Root: background, pages and the floating tab bar. Keeps clear of the camera hole and gesture bar.

var _content: Control
var _pages: Array = []
var _nav: NavBar


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_content)

	var earn := EarnPage.new()
	_pages = [
		earn,
		PlaceholderPage.new("Business", ["Start shops, taxi firms and more", "Earn money every hour", "Expand and merge companies"]),
		PlaceholderPage.new("Invest", ["Shares with dividends", "Property with rent", "Crypto with live prices"]),
		PlaceholderPage.new("Items", ["Cars, jets and yachts", "Collections to complete"]),
		ProfilePage.new(),
	]
	for p in _pages:
		_content.add_child(p)
	earn.open_tab.connect(show_page)

	_nav = NavBar.new()
	_nav.anchor_left = 0.0
	_nav.anchor_right = 1.0
	_nav.anchor_top = 1.0
	_nav.anchor_bottom = 1.0
	add_child(_nav)
	_nav.tab_selected.connect(show_page)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	show_page(0)


func show_page(i: int) -> void:
	for k in range(_pages.size()):
		_pages[k].visible = k == i
	_nav.set_active(i)


func _apply_safe_area() -> void:
	var top := 0.0
	var bottom := 0.0
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if win.y > 0:
			var k := get_viewport_rect().size.y / float(win.y)
			top = clampf(safe.position.y * k, 0.0, 80.0)
			bottom = clampf((win.y - safe.end.y) * k, 0.0, 60.0)
	_content.offset_top = top
	_content.offset_bottom = -bottom
	_nav.offset_left = 16
	_nav.offset_right = -16
	_nav.offset_bottom = -(12 + bottom)
	_nav.offset_top = _nav.offset_bottom - 64

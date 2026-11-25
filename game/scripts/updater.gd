extends Node
## Checks GitHub for a newer build and offers it in a custom sheet.

signal update_available(version: String)
signal check_finished(found: bool)

const API := "https://api.github.com/repos/ytjustjosh17-cpu/MCG/releases/latest"
const DOWNLOAD := "https://github.com/ytjustjosh17-cpu/MCG/releases/latest/download/Sol.apk"
const MIN_GAP_S := 1800.0

var latest_version := ""
var _http: HTTPRequest
var _busy := false
var _last := -1e9


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_done)


func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func build_of(version: String) -> int:
	var parts := version.trim_prefix("v").split(".")
	return int(parts[parts.size() - 1]) if parts.size() > 0 else 0


func check(force := false) -> void:
	if _busy:
		return
	if not force and Time.get_ticks_msec() / 1000.0 - _last < MIN_GAP_S:
		return
	_busy = true
	_last = Time.get_ticks_msec() / 1000.0
	var err := _http.request(API, ["User-Agent: Sol-game", "Accept: application/vnd.github+json"])
	if err != OK:
		_busy = false
		check_finished.emit(false)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		GameLog.warn("update", "Update check failed (result %d, HTTP %d)" % [result, code])
		check_finished.emit(false)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("tag_name"):
		check_finished.emit(false)
		return
	var tag: String = data["tag_name"]
	var found := build_of(tag) > build_of(current_version())
	GameLog.info("update", "Latest %s, this is v%s, update %s" % [tag, current_version(), "available" if found else "not needed"])
	if found:
		latest_version = tag.trim_prefix("v")
		update_available.emit(latest_version)
	check_finished.emit(found)


func open_download() -> void:
	GameLog.info("update", "Opening download link")
	OS.shell_open(DOWNLOAD)

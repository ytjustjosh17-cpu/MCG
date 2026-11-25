extends Node
## Finds new builds on GitHub, downloads them inside the game and hands the
## file to Android's installer, so updating is: Profile > Update > Android's "Update".
## If anything in the in-app route fails, it falls back to the browser download.

signal update_available(version: String)
signal check_finished(found: bool)
signal state_changed

const API := "https://api.github.com/repos/ytjustjosh17-cpu/MCG/releases/latest"
const DOWNLOAD := "https://github.com/ytjustjosh17-cpu/MCG/releases/latest/download/Sol.apk"
const APK_PATH := "user://update.apk"
const APK_META := "user://update.txt"
const AUTHORITY := "com.redsunholdings.game.fileprovider"
const MIN_GAP_S := 1800.0
const MIN_APK_BYTES := 5000000

enum State { IDLE, CHECKING, AVAILABLE, DOWNLOADING, READY, INSTALLING, FAILED }

var state := State.IDLE
var latest_version := ""
var progress := 0.0
var _http: HTTPRequest
var _dl: HTTPRequest
var _last := -1e9
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_checked)
	_dl = HTTPRequest.new()
	_dl.timeout = 120.0
	_dl.max_redirects = 10
	_dl.download_chunk_size = 262144
	add_child(_dl)
	_dl.request_completed.connect(_on_downloaded)
	_cleanup_old_download()
	if OS.has_feature("android"):
		_timer = Timer.new()
		_timer.wait_time = MIN_GAP_S
		_timer.autostart = true
		_timer.timeout.connect(func(): check())
		add_child(_timer)


func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func build_of(version: String) -> int:
	var parts := version.trim_prefix("v").split(".")
	return int(parts[parts.size() - 1]) if parts.size() > 0 else 0


func has_update() -> bool:
	return state in [State.AVAILABLE, State.DOWNLOADING, State.READY, State.INSTALLING, State.FAILED] and latest_version != ""


func _set_state(s: State) -> void:
	state = s
	state_changed.emit()


# ---- checking ---------------------------------------------------------------

func check(force := false) -> void:
	if state in [State.CHECKING, State.DOWNLOADING, State.INSTALLING]:
		return
	if not force and Time.get_ticks_msec() / 1000.0 - _last < MIN_GAP_S and state != State.IDLE:
		return
	_last = Time.get_ticks_msec() / 1000.0
	var before := state
	_set_state(State.CHECKING)
	var err := _http.request(API, ["User-Agent: Sol-game", "Accept: application/vnd.github+json"])
	if err != OK:
		_set_state(before if before != State.CHECKING else State.IDLE)
		check_finished.emit(false)


func _on_checked(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		GameLog.warn("update", "Update check failed (result %d, HTTP %d)" % [result, code])
		_set_state(State.AVAILABLE if latest_version != "" else State.IDLE)
		check_finished.emit(false)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	var tag: String = data.get("tag_name", "") if typeof(data) == TYPE_DICTIONARY else ""
	var found := tag != "" and build_of(tag) > build_of(current_version())
	GameLog.info("update", "Latest %s, this is v%s, update %s" % [tag, current_version(), "available" if found else "not needed"])
	if found:
		latest_version = tag.trim_prefix("v")
		_set_state(State.READY if _downloaded_version() == latest_version else State.AVAILABLE)
		update_available.emit(latest_version)
	else:
		_set_state(State.IDLE)
	check_finished.emit(found)


# ---- downloading ------------------------------------------------------------

func start_update() -> void:
	## One tap: download (if needed) then open Android's installer.
	if state == State.READY:
		install()
		return
	if state in [State.DOWNLOADING, State.INSTALLING]:
		return
	if not OS.has_feature("android"):
		open_download()
		return
	progress = 0.0
	_remove(APK_PATH)
	_dl.download_file = APK_PATH
	var err := _dl.request(DOWNLOAD, ["User-Agent: Sol-game"])
	if err != OK:
		GameLog.error("update", "Download could not start (error %d)" % err)
		_fail()
		return
	GameLog.info("update", "Downloading v%s" % latest_version)
	_set_state(State.DOWNLOADING)


func _process(_delta: float) -> void:
	if state == State.DOWNLOADING:
		var total := _dl.get_body_size()
		if total > 0:
			var p := clampf(float(_dl.get_downloaded_bytes()) / float(total), 0.0, 1.0)
			if absf(p - progress) >= 0.01:
				progress = p
				state_changed.emit()


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != State.DOWNLOADING:
		return
	var size := GameLog.file_size(APK_PATH)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or size < MIN_APK_BYTES:
		GameLog.error("update", "Download failed (result %d, HTTP %d, %s)" % [result, code, GameLog.bytes(size)])
		_remove(APK_PATH)
		_fail()
		return
	var f := FileAccess.open(APK_META, FileAccess.WRITE)
	if f:
		f.store_string(latest_version)
		f.close()
	GameLog.info("update", "Downloaded v%s (%s)" % [latest_version, GameLog.bytes(size)])
	progress = 1.0
	_set_state(State.READY)
	install()


# ---- installing -------------------------------------------------------------

func install() -> void:
	## Hands the downloaded file to Android's package installer.
	if not FileAccess.file_exists(APK_PATH):
		_set_state(State.AVAILABLE)
		start_update()
		return
	var ok := _launch_installer(ProjectSettings.globalize_path(APK_PATH))
	if ok:
		GameLog.info("update", "Installer opened for v%s" % latest_version)
		_set_state(State.INSTALLING)
		# If the person backs out of Android's prompt, let them tap again.
		get_tree().create_timer(4.0).timeout.connect(func():
			if state == State.INSTALLING:
				_set_state(State.READY))
	else:
		_fail()


func _launch_installer(path: String) -> bool:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return false
	var rt = Engine.get_singleton("AndroidRuntime")
	var activity = rt.getActivity()
	var context = rt.getApplicationContext()
	if activity == null or context == null:
		GameLog.error("update", "No Android activity")
		return false
	var file = JavaClassWrapper.wrap("java.io.File").File(path)
	if not _java_ok("File") or file == null:
		return false
	var uri = JavaClassWrapper.wrap("androidx.core.content.FileProvider").getUriForFile(context, AUTHORITY, file)
	if not _java_ok("FileProvider") or uri == null:
		return false
	var intent = JavaClassWrapper.wrap("android.content.Intent").Intent("android.intent.action.VIEW")
	if not _java_ok("Intent") or intent == null:
		return false
	intent.setDataAndType(uri, "application/vnd.android.package-archive")
	intent.addFlags(1 | 268435456)  # grant read permission + new task
	if not _java_ok("Intent setup"):
		return false
	activity.startActivity(intent)
	return _java_ok("startActivity")


func _java_ok(step: String) -> bool:
	var ex = JavaClassWrapper.get_exception()
	if ex != null:
		GameLog.error("update", "%s failed: %s" % [step, str(ex.toString()) if ex.has_method("toString") else str(ex)])
		return false
	return true


func _fail() -> void:
	## In-app route failed: fall back to the browser download, which always works.
	GameLog.warn("update", "Falling back to the browser download")
	_set_state(State.FAILED)
	open_download()


func open_download() -> void:
	GameLog.info("update", "Opening download link")
	OS.shell_open(DOWNLOAD)


# ---- storage ----------------------------------------------------------------

func _downloaded_version() -> String:
	if not FileAccess.file_exists(APK_META) or not FileAccess.file_exists(APK_PATH):
		return ""
	return FileAccess.get_file_as_string(APK_META).strip_edges()


func _cleanup_old_download() -> void:
	## Once an update is installed, its downloaded file is deleted so it never wastes space.
	var v := _downloaded_version()
	if FileAccess.file_exists(APK_PATH) and (v == "" or build_of(v) <= build_of(current_version())):
		GameLog.info("update", "Removed old update file (%s)" % GameLog.bytes(GameLog.file_size(APK_PATH)))
		_remove(APK_PATH)
		_remove(APK_META)


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

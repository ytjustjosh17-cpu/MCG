extends Node
## Small, bounded logging system.
## - Keeps the last 400 lines in memory and writes to user://logs/game.log
## - Rotates at 200 KB and keeps one old file, so logs never grow without limit
## - Every minute records speed, memory, node counts and save size to spot leaks
## - "Copy problem report" puts everything useful on the clipboard

const DIR := "user://logs"
const FILE := "user://logs/game.log"
const OLD := "user://logs/game.old.log"
const FLAG := "user://logs/running.flag"
const MAX_BYTES := 200000
const MEMORY_LINES := 400
const PERF_EVERY_S := 60.0

var _lines: Array = []
var _file: FileAccess
var _flush_timer := 0.0
var _perf_timer := 0.0
var _slow_frames := 0
var _start_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_ms = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_open()
	info("app", "Started v%s on %s (%s), screen %s, %d CPU cores, %s" % [
		ProjectSettings.get_setting("application/config/version", "?"), OS.get_model_name(), os_text(),
		str(DisplayServer.screen_get_size()), OS.get_processor_count(), ram_text()])
	if FileAccess.file_exists(FLAG):
		warn("app", "The last session ended unexpectedly (closed by the system or a crash)")
	_set_flag(true)


func _open() -> void:
	var path := ProjectSettings.globalize_path(FILE)
	if FileAccess.file_exists(FILE):
		var f := FileAccess.open(FILE, FileAccess.READ)
		var big := f != null and f.get_length() > MAX_BYTES
		if f:
			f.close()
		if big:
			_rotate()
	if FileAccess.file_exists(FILE):
		_file = FileAccess.open(FILE, FileAccess.READ_WRITE)
		if _file:
			_file.seek_end()
	else:
		_file = FileAccess.open(FILE, FileAccess.WRITE)
	if _file == null:
		push_warning("Log file unavailable: %s" % path)


func _rotate() -> void:
	if _file:
		_file.close()
		_file = null
	var cur := ProjectSettings.globalize_path(FILE)
	var old := ProjectSettings.globalize_path(OLD)
	if FileAccess.file_exists(OLD):
		DirAccess.remove_absolute(old)
	DirAccess.rename_absolute(cur, old)


func _set_flag(on: bool) -> void:
	if on:
		var f := FileAccess.open(FLAG, FileAccess.WRITE)
		if f:
			f.store_string(str(Time.get_unix_time_from_system()))
			f.close()
	elif FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))


func _write(level: String, area: String, msg: String) -> void:
	var t := Time.get_datetime_dict_from_system()
	var line := "%02d-%02d %02d:%02d:%02d %s %s: %s" % [t["month"], t["day"], t["hour"], t["minute"], t["second"], level, area, msg]
	_lines.append(line)
	while _lines.size() > MEMORY_LINES:
		_lines.pop_front()
	if _file:
		_file.store_line(line)
		if _file.get_position() > MAX_BYTES:
			_rotate()
			_open()
	if level == "ERROR":
		push_warning(line)


func info(area: String, msg: String) -> void:
	_write("INFO ", area, msg)


func warn(area: String, msg: String) -> void:
	_write("WARN ", area, msg)


func error(area: String, msg: String) -> void:
	_write("ERROR", area, msg)


func _process(delta: float) -> void:
	if delta > 0.1:
		_slow_frames += 1
	_flush_timer += delta
	if _flush_timer >= 2.0 and _file:
		_flush_timer = 0.0
		_file.flush()
	_perf_timer += delta
	if _perf_timer >= PERF_EVERY_S:
		_perf_timer = 0.0
		info("perf", perf_line())
		if _slow_frames > 30:
			warn("perf", "%d slow frames in the last minute" % _slow_frames)
		_slow_frames = 0


static func os_text() -> String:
	var v := OS.get_version()
	if v == "" and OS.has_method("get_version_alias"):
		v = OS.call("get_version_alias")
	return "%s %s" % [OS.get_name(), v if v != "" else "(version hidden)"]


static func ram_text() -> String:
	var m := OS.get_memory_info()
	var avail := int(m.get("available", -1))
	var phys := int(m.get("physical", -1))
	if avail < 0 or phys <= 0:
		return "RAM unknown"
	return "RAM free %s of %s" % [bytes(avail), bytes(phys)]


func perf_line() -> String:
	var used := OS.get_static_memory_usage()
	var mem := ("game memory %.1f MB" % (used / 1048576.0)) if used > 0 else ram_text()
	return "fps %d, %s, nodes %d, orphan nodes %d, objects %d, save %s, logs %s" % [
		Engine.get_frames_per_second(),
		mem,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		bytes(file_size("user://save.json")), bytes(logs_size())]


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			info("app", "Paused (sent to background)")
			_set_flag(false)
			if _file:
				_file.flush()
		NOTIFICATION_APPLICATION_RESUMED:
			info("app", "Resumed")
			_set_flag(true)
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			_set_flag(false)
			if _file:
				_file.flush()


# ---- storage -------------------------------------------------------------

static func file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n


static func dir_size(path: String) -> int:
	var total := 0
	var d := DirAccess.open(path)
	if d == null:
		return 0
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := path.path_join(name)
		if d.current_is_dir():
			if name != "." and name != "..":
				total += dir_size(full)
		else:
			total += file_size(full)
		name = d.get_next()
	d.list_dir_end()
	return total


func logs_size() -> int:
	return dir_size(DIR)


func storage_used() -> int:
	return dir_size("user://")


static func bytes(n: int) -> String:
	if n < 1024:
		return "%d B" % n
	if n < 1048576:
		return "%.1f KB" % (n / 1024.0)
	return "%.1f MB" % (n / 1048576.0)


# ---- report --------------------------------------------------------------

func _engine_log_tail(max_lines := 60) -> Array:
	## Last lines of Godot's own log, which includes script errors.
	var path := "user://logs/godot.log"
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var all := f.get_as_text().split("\n")
	f.close()
	var out: Array = []
	for line in all:
		if line.strip_edges() != "":
			out.append(line)
	return out.slice(maxi(0, out.size() - max_lines))


func report() -> String:
	var lines: Array = []
	lines.append("=== Sol problem report ===")
	lines.append("Version %s · %s · %s" % [ProjectSettings.get_setting("application/config/version", "?"), OS.get_model_name(), os_text()])
	lines.append("Time %s · up %d min" % [Time.get_datetime_string_from_system(), (Time.get_ticks_msec() - _start_ms) / 60000])
	lines.append("Storage used %s (save %s, logs %s)" % [bytes(storage_used()), bytes(file_size("user://save.json")), bytes(logs_size())])
	lines.append(perf_line())
	if has_node("/root/Game"):
		var g = get_node("/root/Game")
		lines.append("Game: level %d, cash %s, worth %s, income %s/h, %d companies, %d properties, %.1f%% complete" % [
			g.level, g.money(g.cash), g.money(g.net_worth()), g.money(g.income_per_hour), g.biz.size(), g.props.size(), g.completion() * 100.0])
	lines.append("")
	lines.append("--- game log (newest last) ---")
	lines.append_array(_lines.slice(maxi(0, _lines.size() - 300)))
	var eng := _engine_log_tail()
	if not eng.is_empty():
		lines.append("")
		lines.append("--- engine log ---")
		lines.append_array(eng)
	return "\n".join(lines)


func copy_report() -> int:
	if _file:
		_file.flush()
	var r := report()
	DisplayServer.clipboard_set(r)
	info("log", "Problem report copied (%s)" % bytes(r.length()))
	return r.length()

class_name Sfx
extends Node
## Small sound effects made in code (no audio files): soft taps, a purchase
## chime, a fanfare, the golden sun alert. Volume lives in Game.ui["vol"]
## (0 = off). Silent on headless test runs.

const RATE := 22050
const POOL := 4

var _streams := {}
var _players: Array = []
var _next := 0
var _last_ms := {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_streams = {
		"tap": _tone([[1046.0, 0.035]], 0.25, 0.0),
		"crit": _tone([[1318.0, 0.03], [1760.0, 0.06]], 0.35, 0.0),
		"buy": _tone([[659.0, 0.07], [988.0, 0.12]], 0.35, 0.0),
		"fanfare": _tone([[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1046.0, 0.25]], 0.4, 0.0),
		"sun": _tone([[1568.0, 0.08], [2093.0, 0.08], [1568.0, 0.08], [2349.0, 0.2]], 0.25, 6.0),
		"error": _tone([[220.0, 0.06], [174.0, 0.1]], 0.35, 0.0),
	}
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func volume() -> float:
	return clampf(float(Game.ui.get("vol", 0.5)), 0.0, 1.0)


func play(name: String) -> void:
	if _players.is_empty() or not _streams.has(name) or volume() <= 0.0:
		return
	# The same sound at most every 45 ms, so fast tapping doesn't turn to buzz.
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(name, -1000)) < 45:
		return
	_last_ms[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = linear_to_db(volume() * (0.5 if name == "tap" else 1.0))
	p.play()


static func _tone(notes: Array, gain: float, vibrato: float) -> AudioStreamWAV:
	## notes: [[hz, seconds], ...] played one after another, each with a soft
	## attack and decay. A touch of a fifth above gives a glassy ring.
	var data := PackedByteArray()
	var phase := 0.0
	var phase2 := 0.0
	for n in notes:
		var hz: float = n[0]
		var count := int(float(n[1]) * RATE)
		for i in count:
			var t := float(i) / RATE
			var env := minf(1.0, t / 0.004) * exp(-t * 18.0 / maxf(0.05, float(n[1]) * 4.0))
			var f := hz * (1.0 + 0.01 * sin(t * TAU * vibrato)) if vibrato > 0.0 else hz
			phase += TAU * f / RATE
			phase2 += TAU * f * 1.5 / RATE
			var v := (sin(phase) * 0.8 + sin(phase2) * 0.2) * env * gain
			var q := clampi(int(v * 32767.0), -32768, 32767)
			data.append(q & 0xff)
			data.append((q >> 8) & 0xff)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

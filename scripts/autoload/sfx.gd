extends Node
## Tiny synthesised sound effects (no audio files). Respects Settings.sound.
##   Sfx.play("key")

const RATE := 22050
const VOICES := 8
const VOLUME_DB := -10.0

## name -> [wave, volume, [[freq_from, freq_to, seconds], ...]]
const SOUNDS := {
	"key": ["noise", 0.35, [[0, 0, 0.018]]],
	"lock": ["square", 0.18, [[1250, 1250, 0.03]]],
	"hit": ["square", 0.2, [[660, 660, 0.05], [990, 990, 0.08]]],
	"wrong": ["square", 0.25, [[170, 140, 0.12]]],
	"miss": ["square", 0.25, [[420, 110, 0.32]]],
	"level_up": ["square", 0.2, [[523, 523, 0.08], [659, 659, 0.08], [784, 784, 0.08], [1047, 1047, 0.18]]],
	"level_down": ["square", 0.2, [[784, 784, 0.1], [622, 622, 0.1], [523, 523, 0.1], [392, 392, 0.22]]],
	"power": ["sine", 0.45, [[700, 1800, 0.22]]],
	"earn": ["sine", 0.4, [[1200, 1200, 0.06], [1600, 1600, 0.12]]],
}

var _streams := {}
## Headless runs (tests, CI) have no audio output; the dummy driver never
## releases playbacks, so don't start any.
var _enabled := DisplayServer.get_name() != "headless"
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in SOUNDS:
		var s: Array = SOUNDS[name]
		_streams[name] = synth(s[0], s[1], s[2])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)


func stop_all() -> void:
	for p in _players:
		p.stop()


func play(name: String) -> void:
	if not _enabled or not Settings.sound or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.play()


## Builds a mono 16-bit sample from frequency segments, each with its own
## short attack and quadratic decay.
static func synth(wave: String, volume: float, parts: Array) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var total := 0
	for part in parts:
		total += int(part[2] * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var phase := 0.0
	var idx := 0
	for part in parts:
		var n := int(part[2] * RATE)
		for i in n:
			var t := float(i) / n
			var f := lerpf(part[0], part[1], t)
			phase += f / RATE
			var s := 0.0
			match wave:
				"square":
					s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"sine":
					s = sin(TAU * phase)
				_:
					s = rng.randf_range(-1.0, 1.0)
			var env := minf(1.0, i / (RATE * 0.002)) * pow(1.0 - t, 2.0)
			data.encode_s16(idx * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
			idx += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

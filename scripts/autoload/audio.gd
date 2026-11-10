extends Node
## Audio buses and sound effects. SFX are synthesized at startup, voice limited and rate
## limited per sound so they never drown the music.

const VOICES: int = 10
## name: [start Hz, end Hz, seconds, noise amount]
const SOUNDS: Dictionary = {
	"click": [660, 660, 0.05, 0.0], "tick": [990, 990, 0.025, 0.0], "gem": [880, 1100, 0.04, 0.0],
	"hurt": [220, 90, 0.18, 0.35], "kill": [320, 140, 0.06, 0.5], "coin": [1320, 1760, 0.09, 0.0],
	"heal": [440, 880, 0.22, 0.0], "levelup": [523, 1046, 0.4, 0.0], "fanfare": [392, 1175, 0.7, 0.0],
	"boom": [95, 38, 0.45, 0.6], "break": [800, 300, 0.09, 0.6], "magnet": [300, 900, 0.3, 0.0],
	"freeze": [1500, 500, 0.3, 0.1], "revive": [300, 1200, 0.5, 0.0], "phase": [200, 70, 0.45, 0.3],
	"boss_intro": [110, 50, 0.9, 0.25], "boss_shot": [520, 300, 0.07, 0.2],
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last: Dictionary = {}
var _gem_pitch: float = 1.0
var _gem_t: int = 0
var enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var lp: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), lp)
	AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	enabled = DisplayServer.get_name() != "headless"
	if enabled:
		for name: String in SOUNDS:
			var s: Array = SOUNDS[name]
			_streams[name] = Synth.sfx(float(s[0]), float(s[1]), float(s[2]), float(s[3]))
		for k: int in VOICES:
			var p: AudioStreamPlayer = AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			_players.append(p)
	apply_volumes()


func play(name: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or Game.headless or not _streams.has(name):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 60:
		return
	_last[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[name]
	p.volume_db = db - 6.0
	p.pitch_scale = pitch
	p.play()


func play_gem() -> void:
	var now: int = Time.get_ticks_msec()
	_gem_pitch = minf(_gem_pitch + 0.06, 2.0) if now - _gem_t < 400 else 1.0
	_gem_t = now
	play("gem", -10.0, _gem_pitch)


## Attacks are voiced by the instrument's music layer, which fires on the same steps.
func attack(_instrument: String, _slot: int, _evolved: bool) -> void:
	pass


func apply_volumes() -> void:
	for pair: Array in [["Master", "vol_master"], ["Music", "vol_music"], ["SFX", "vol_sfx"]]:
		var idx: int = AudioServer.get_bus_index(pair[0])
		var v: float = float(Save.setting(pair[1]))
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))

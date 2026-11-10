extends Node
## Music director. One master clock, one AudioStreamSynchronized whose sub-streams are the
## layers of the stage track: base parts, an intensity part and one layer per equipped
## instrument. Layers are rendered on worker threads and switched in on a bar line.
##
## An instrument's layer plays its notes on exactly the steps its weapon fires on, so every
## attack is heard in key and on the grid.

const SLOTS: int = 16
const BASE: PackedStringArray = ["drums", "bass", "keys", "perc"]

var virtual: bool = true
var bpm: float = 120.0
var step_dur: float = 0.125
var step: int = 0
var step_f: float = 0.0
var beat_phase: float = 0.0
var song_time: float = 0.0
var playing: bool = false

var _track: Dictionary = {}
var _player: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _wavs: Array[AudioStreamWAV] = []
var _slot_key: PackedStringArray = []
var _slot_layer: PackedStringArray = []
var _slot_on: PackedByteArray = []
var _jobs: Array[Dictionary] = []
var _loops: int = 0
var _last_pos: float = 0.0
var _loop_len: float = 1.0
var _last_bar: int = -1
var _want_perc: bool = false
var _muffle_t: float = 0.0
var _paused_filter: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	_slot_key.resize(SLOTS)
	_slot_layer.resize(SLOTS)
	_slot_on.resize(SLOTS)


func _audible() -> bool:
	return not Game.headless and DisplayServer.get_name() != "headless"


func start_stage(stage_id: String, hyper: bool = false) -> void:
	_finish_jobs()
	var cfg: Dictionary = Content.music.get("tracks", {}).get(Content.stages[stage_id].get("track", ""), {})
	if cfg.is_empty():
		cfg = Content.music.get("tracks", {}).values()[0]
	_track = cfg.duplicate(true)
	var want_bpm: float = float(cfg.get("bpm", 100)) * (1.12 if hyper else 1.0)
	var sps: int = roundi(Synth.SR * 15.0 / want_bpm)
	_track["sps"] = sps
	step_dur = float(sps) / float(Synth.SR)
	bpm = 15.0 / step_dur
	_loop_len = step_dur * 64.0
	song_time = 0.0
	step = 0
	step_f = 0.0
	_loops = 0
	_last_pos = 0.0
	_last_bar = -1
	_want_perc = false
	playing = true
	virtual = not _audible() or AudioServer.get_driver_name() == "Dummy"
	if not _audible():
		return
	Synth.ensure_tables()
	_player.stop()
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = SLOTS
	_wavs.clear()
	var silent: PackedByteArray = PackedByteArray()
	silent.resize(64 * sps * 2)
	for i: int in SLOTS:
		var w: AudioStreamWAV = AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = Synth.SR
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = 64 * sps
		w.data = silent
		_wavs.append(w)
		_sync.set_sync_stream(i, w)
		_sync.set_sync_stream_volume(i, -80.0)
		_slot_key[i] = ""
		_slot_layer[i] = ""
		_slot_on[i] = 0
	var parts: Dictionary = _track.get("parts", {})
	for i: int in BASE.size():
		if parts.has(BASE[i]):
			_wavs[i].data = Synth.render_layer({"track": _track, "part": parts[BASE[i]]})
			_slot_layer[i] = BASE[i]
			if BASE[i] != "perc":
				_slot_on[i] = 1
				_sync.set_sync_stream_volume(i, 0.0)
	_player.stream = _sync
	_player.play()
	_apply_filter()


func _process(delta: float) -> void:
	if not playing:
		return
	if virtual:
		if not Game.headless:
			advance(delta)
	else:
		var pos: float = _player.get_playback_position()
		if pos < _last_pos - _loop_len * 0.5:
			_loops += 1
		_last_pos = pos
		var t: float = _loops * _loop_len + pos + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		_set_time(maxf(t, song_time))
	if _muffle_t > 0.0:
		_muffle_t -= delta
		if _muffle_t <= 0.0:
			_apply_filter()
	if not _audible():
		return
	var bar: int = step >> 4
	if bar != _last_bar:
		_last_bar = bar
		_on_bar()


## Advances the virtual clock (headless tools drive this from the simulation).
func advance(dt: float) -> void:
	_set_time(song_time + dt)


func _set_time(t: float) -> void:
	song_time = t
	step_f = song_time / step_dur
	step = int(step_f)
	beat_phase = fmod(step_f * 0.25, 1.0)


## Bar line: switch in finished renders and apply pending layer on/off changes.
func _on_bar() -> void:
	var k: int = _jobs.size() - 1
	while k >= 0:
		var job: Dictionary = _jobs[k]
		if WorkerThreadPool.is_task_completed(job["task"]):
			WorkerThreadPool.wait_for_task_completion(job["task"])
			_jobs.remove_at(k)
			var slot: int = job["slot"]
			if _slot_key[slot] == job["key"]:
				_wavs[slot].data = job["out"][0]
				_slot_on[slot] = 1
		k -= 1
	for i: int in SLOTS:
		var on: bool = _slot_on[i] != 0
		if i == 3:
			on = _want_perc and _slot_layer[i] != ""
		_sync.set_sync_stream_volume(i, 0.0 if on else -80.0)


func _finish_jobs() -> void:
	for job: Dictionary in _jobs:
		WorkerThreadPool.wait_for_task_completion(job["task"])
	_jobs.clear()


## layers: [{layer, tier, hits: PackedByteArray, phase}] from WeaponSystem.
func set_instrument_layers(layers: Array) -> void:
	if not _audible() or _sync == null:
		return
	var defs: Dictionary = Content.music.get("instrument_layers", {})
	var wanted: Dictionary = {}
	for l: Dictionary in layers:
		var id: String = l["layer"]
		if not defs.has(id) or wanted.has(id):
			continue
		wanted[id] = l
	for i: int in range(BASE.size(), SLOTS):
		if _slot_layer[i] != "" and not wanted.has(_slot_layer[i]):
			_slot_layer[i] = ""
			_slot_key[i] = ""
			_slot_on[i] = 0
	for id: String in wanted:
		var l2: Dictionary = wanted[id]
		var key: String = "%s|%d|%d|%s" % [id, int(l2["tier"]), int(l2["phase"]), (l2["hits"] as PackedByteArray).hex_encode()]
		var slot: int = _slot_layer.find(id)
		if slot < 0:
			for i: int in range(BASE.size(), SLOTS):
				if _slot_layer[i] == "":
					slot = i
					break
		if slot < 0 or _slot_key[slot] == key:
			continue
		_slot_layer[slot] = id
		_slot_key[slot] = key
		var out: Array = [PackedByteArray()]
		var job: Dictionary = {"track": _track, "part": defs[id], "hits": l2["hits"], "phase": l2["phase"], "tier": l2["tier"]}
		var task: int = WorkerThreadPool.add_task(func() -> void: out[0] = Synth.render_layer(job))
		_jobs.append({"task": task, "slot": slot, "key": key, "out": out})


func set_intensity(v: float, _danger: bool) -> void:
	_want_perc = v > 0.3


func set_boss(on: bool) -> void:
	if on:
		_want_perc = true


func set_boss_phase(_phase: int) -> void:
	pass


func muffle(time: float) -> void:
	_muffle_t = maxf(_muffle_t, time)
	_apply_filter()


func set_paused_filter(on: bool) -> void:
	_paused_filter = on
	_apply_filter()


func _apply_filter() -> void:
	var bus: int = AudioServer.get_bus_index("Music")
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, 0)
	lp.cutoff_hz = 700.0 if (_paused_filter or _muffle_t > 0.0) else 20000.0


func end_run(_victory: bool) -> void:
	playing = false
	_paused_filter = false
	_muffle_t = 0.0
	_apply_filter()
	_finish_jobs()
	if _player.playing:
		_player.stop()

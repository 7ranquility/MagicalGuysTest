extends Node
## Dev tool: renders the stage mix with a set of instrument layers to user://mix.wav.

func _ready() -> void:
	Synth.ensure_tables()
	var track: Dictionary = Content.music["tracks"]["lofi_grove"].duplicate(true)
	var sps: int = roundi(Synth.SR * 15.0 / float(track["bpm"]))
	track["sps"] = sps
	var n: int = 64 * sps
	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(n)
	var jobs: Array = []
	for id: String in ["drums", "bass", "keys"]:
		jobs.append({"track": track, "part": track["parts"][id]})
	var k: int = 0
	for id: String in ["guitar", "violin", "piano", "drums"]:
		var cd: float = float(Content.instruments[id]["base"]["cooldown"])
		var hits: int = Rhythm.hits_for_cooldown(cd, float(sps) / Synth.SR)
		jobs.append({"track": track, "part": Content.music["instrument_layers"][id], "hits": Rhythm.euclid(hits), "phase": int(Content.instruments[id].get("phase", 0)), "tier": k})
		k += 1
	var t0: int = Time.get_ticks_msec()
	for job: Dictionary in jobs:
		var pcm: PackedByteArray = Synth.render_layer(job)
		for i: int in n:
			mix[i] += float(pcm.decode_s16(i * 2)) / 32768.0
	print("rendered %d layers in %d ms, sps=%d" % [jobs.size(), Time.get_ticks_msec() - t0, sps])
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = Synth.SR
	w.data = Synth.to_pcm(mix, 0.8)
	w.save_to_wav("user://mix.wav")
	get_tree().quit()

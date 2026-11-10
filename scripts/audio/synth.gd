class_name Synth
extends RefCounted
## Procedural sound: wavetable voices, synthesized drums and the layer renderer that turns
## pattern data from data/music.json into loopable PCM. Pure functions on packed arrays so
## layers can be rendered on worker threads.

const SR: int = 24000
const TBL: int = 2048

## h: harmonic amplitudes, a: attack s, d: decay time constant s, sus: held notes (else plucked).
const TIMBRES: Dictionary = {
	"guitar": {"h": [1, 0.5, 0.33, 0.25, 0.2, 0.16, 0.14, 0.12, 0.1], "a": 0.003, "d": 0.3, "sus": false},
	"piano": {"h": [1, 0.4, 0.2, 0.1, 0.05], "a": 0.003, "d": 0.45, "sus": false},
	"epiano": {"h": [1, 0.15, 0.3, 0.02, 0.06], "a": 0.01, "d": 1.4, "sus": true},
	"harp": {"h": [1, 0.3, 0.1, 0.05], "a": 0.002, "d": 0.4, "sus": false},
	"bass": {"h": [1, 0.5, 0.2, 0.08], "a": 0.004, "d": 0.5, "sus": false},
	"violin": {"h": [1, 0.6, 0.4, 0.3, 0.2, 0.15], "a": 0.04, "d": 2.5, "sus": true},
	"trumpet": {"h": [1, 0.8, 0.7, 0.5, 0.4, 0.3, 0.2], "a": 0.02, "d": 1.2, "sus": true},
	"flute": {"h": [1, 0.1, 0.2, 0.03], "a": 0.03, "d": 2.0, "sus": true},
	"choir": {"h": [1, 0.2, 0.4, 0.1, 0.15], "a": 0.08, "d": 3.0, "sus": true},
	"organ": {"h": [1, 0.8, 0, 0.6, 0, 0, 0, 0.4], "a": 0.01, "d": 4.0, "sus": true},
	"sine": {"h": [1, 0.05], "a": 0.06, "d": 3.0, "sus": true},
	"square": {"h": [1, 0, 0.33, 0, 0.2, 0, 0.14, 0, 0.11], "a": 0.003, "d": 0.25, "sus": false},
	"scratch": {"h": [1, 0, 0.33, 0, 0.2, 0, 0.14], "a": 0.002, "d": 0.07, "sus": false},
	"bell": {"h": [1, 0, 0, 0.6, 0, 0.3, 0, 0, 0.4], "a": 0.001, "d": 0.5, "sus": false},
	"cowbell": {"h": [1, 0, 0.7, 0, 0, 0.5], "a": 0.001, "d": 0.1, "sus": false},
}

static var tables: Dictionary = {}
static var noise: PackedFloat32Array = PackedFloat32Array()


## Builds the wavetables. Call once on the main thread before any rendering.
static func ensure_tables() -> void:
	if not tables.is_empty():
		return
	for name: String in TIMBRES:
		var h: Array = TIMBRES[name]["h"]
		var t: PackedFloat32Array = PackedFloat32Array()
		t.resize(TBL)
		var peak: float = 0.001
		for i: int in TBL:
			var v: float = 0.0
			for k: int in h.size():
				if float(h[k]) != 0.0:
					v += float(h[k]) * sin(TAU * float(i * (k + 1)) / float(TBL))
			t[i] = v
			peak = maxf(peak, absf(v))
		for i: int in TBL:
			t[i] /= peak
		tables[name] = t
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	noise.resize(8192)
	for i: int in 8192:
		noise[i] = rng.randf_range(-1.0, 1.0)


static func midi_freq(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Mixes one note into the loop buffer (wraps around the end).
static func add_note(buf: PackedFloat32Array, start: int, length: int, freq: float, timbre: String, amp: float) -> void:
	var t: Dictionary = TIMBRES.get(timbre, TIMBRES["piano"])
	var tbl: PackedFloat32Array = tables[timbre if tables.has(timbre) else "piano"]
	var n: int = buf.size()
	var att: int = maxi(1, int(float(t["a"]) * SR))
	var rel: int = int(0.04 * SR)
	var total: int = length + rel
	if not t["sus"]:
		total = clampi(int(float(t["d"]) * 3.5 * SR), rel * 2, n)
	var decay_mul: float = exp(-1.0 / (float(t["d"]) * SR))
	var inc: float = float(TBL) * freq / float(SR)
	var ph: float = 0.0
	var env: float = amp
	var o: int = posmod(start, n)
	var rel_start: int = total - rel
	for i: int in total:
		var e: float = env
		if i < att:
			e *= float(i) / float(att)
		if i > rel_start:
			e *= float(total - i) / float(rel)
		buf[o] += tbl[int(ph) & 2047] * e
		ph += inc
		env *= decay_mul
		o += 1
		if o >= n:
			o = 0


## kind: kick, snare, hat, tom, crash
static func add_drum(buf: PackedFloat32Array, start: int, kind: String, amp: float, pitch: float = 110.0) -> void:
	var n: int = buf.size()
	var o: int = posmod(start, n)
	var total: int = 0
	var f0: float = 0.0
	var f1: float = 0.0
	var tone: float = 0.0
	var nz: float = 0.0
	var tau: float = 0.05
	match kind:
		"kick":
			total = int(0.22 * SR); f0 = 130.0; f1 = 42.0; tone = 1.0; tau = 0.07
		"snare":
			total = int(0.16 * SR); f0 = 200.0; f1 = 170.0; tone = 0.35; nz = 0.7; tau = 0.045
		"hat":
			total = int(0.035 * SR); nz = 0.45; tau = 0.01
		"tom":
			total = int(0.2 * SR); f0 = pitch * 1.4; f1 = pitch; tone = 0.9; nz = 0.08; tau = 0.06
		_:
			total = int(0.5 * SR); nz = 0.4; tau = 0.14
	var ph: float = 0.0
	var env: float = amp
	var mul: float = exp(-1.0 / (tau * SR))
	var ni: int = (start * 7) & 8191
	var prev: float = 0.0
	var hp: bool = kind == "hat" or kind == "crash"
	for i: int in total:
		var u: float = float(i) / float(total)
		var v: float = 0.0
		if tone > 0.0:
			ph += TAU * (f0 + (f1 - f0) * u) / float(SR)
			v = sin(ph) * tone
		if nz > 0.0:
			var x: float = noise[ni]
			ni = (ni + 1) & 8191
			v += ((x - prev) if hp else x) * nz
			prev = x
		buf[o] += v * env
		env *= mul
		o += 1
		if o >= n:
			o = 0


static func to_pcm(buf: PackedFloat32Array, gain: float) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var n: int = buf.size()
	out.resize(n * 2)
	for i: int in n:
		var v: float = buf[i] * gain
		if v > 1.0:
			v = 1.0
		elif v < -1.0:
			v = -1.0
		out.encode_s16(i * 2, int(v * 30000.0))
	return out


static func step_pos(step: int, sps: int, swing: float) -> int:
	return step * sps + (int(swing * sps) if (step & 1) == 1 else 0)


## MIDI note of scale step `idx` (0 = stage root) in the given octave offset.
static func note(track: Dictionary, idx: int, octave: int) -> float:
	var scale: Array = track["scale"]
	var n: int = scale.size()
	return float(track["root"]) + 12.0 * octave + float(scale[posmod(idx, n)]) + 12.0 * floorf(float(idx) / float(n))


## Renders one layer of a track to a 64-step loop. `job` keys: track, part, and for weapon
## layers hits (PackedByteArray), phase, tier.
static func render_layer(job: Dictionary) -> PackedByteArray:
	var track: Dictionary = job["track"]
	var part: Dictionary = job["part"]
	var sps: int = int(track["sps"])
	var swing: float = float(track.get("swing", 0.0))
	var prog: Array = track["progression"]
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(64 * sps)
	var vol: float = float(part.get("vol", 0.5))
	var octave: int = int(part.get("octave", 0))
	var timbre: String = part.get("timbre", "piano")
	match part.get("kind", "line"):
		"drums":
			for bar: int in 4:
				for s: int in 16:
					var at: int = step_pos(bar * 16 + s, sps, swing)
					for drum: String in ["kick", "snare", "hat"]:
						var pat: String = part.get(drum, "")
						if s < pat.length() and pat[s] != ".":
							add_drum(buf, at, drum, 1.0 if pat[s] == "x" else 0.45)
		"line":
			var pat2: String = part.get("pattern", "")
			var hold: int = int(part.get("len", 2))
			for bar: int in 4:
				for s: int in mini(16, pat2.length()):
					if pat2[s] == ".":
						continue
					var idx: int = int(prog[bar % prog.size()]) + int(pat2[s]) - 1
					add_note(buf, step_pos(bar * 16 + s, sps, swing), hold * sps, midi_freq(note(track, idx, octave)), timbre, 1.0)
		"chords":
			for bar: int in 4:
				for tone: int in part.get("tones", [0, 2, 4]):
					var idx2: int = int(prog[bar % prog.size()]) + int(tone)
					add_note(buf, bar * 16 * sps, int(part.get("len", 16)) * sps, midi_freq(note(track, idx2, octave)), timbre, 0.4)
		"weapon":
			_render_weapon(buf, job, track, part, sps, swing)
	return to_pcm(buf, vol)


static func _render_weapon(buf: PackedFloat32Array, job: Dictionary, track: Dictionary, part: Dictionary, sps: int, swing: float) -> void:
	var rhythm: PackedByteArray = job["hits"]
	var phase: int = int(job.get("phase", 0))
	var tier: int = int(job.get("tier", 0))
	var prog: Array = track["progression"]
	var motif: Array = part.get("motif", [0, 2, 4, 2])
	var octave: int = int(part.get("octave", 0)) + (1 if tier >= 3 and not part.get("kit", false) else 0)
	var timbre: String = part.get("timbre", "piano")
	var steps: PackedInt32Array = PackedInt32Array()
	for s: int in 64:
		if rhythm[(s - phase) & 63] != 0:
			steps.append(s)
	for j: int in steps.size():
		var s2: int = steps[j]
		var gap: int = posmod(steps[(j + 1) % steps.size()] - s2, 64)
		if gap == 0:
			gap = 64
		var at: int = step_pos(s2, sps, swing)
		var chord: int = int(prog[(s2 / 16) % prog.size()])
		if part.get("kit", false):
			add_drum(buf, at, "tom", 1.0, 90.0 + 40.0 * float(j % 3))
			add_drum(buf, at, "kick", 0.6)
			if tier >= 1 and j % 4 == 0:
				add_drum(buf, at, "crash", 0.5)
			if tier >= 2 and gap >= 2:
				add_drum(buf, step_pos(s2 + gap - 1, sps, swing), "snare", 0.4)
			if tier >= 3 and gap >= 4:
				add_drum(buf, step_pos(s2 + gap / 2, sps, swing), "tom", 0.7, 150.0)
			continue
		var deg: int = chord + int(motif[j % motif.size()])
		var hold: int = clampi(gap, 1, 8) * sps
		add_note(buf, at, hold, midi_freq(note(track, deg, octave)), timbre, 1.0)
		if tier >= 2:
			add_note(buf, at, hold, midi_freq(note(track, deg + 4, octave)), timbre, 0.45)
		if tier >= 3:
			add_note(buf, at, hold, midi_freq(note(track, deg + 2, octave)), timbre, 0.4)
		if tier >= 1 and gap >= 4:
			var echo_step: int = 2 if tier >= 3 else gap / 2
			var e: int = echo_step
			var k: int = 1
			while e < gap:
				add_note(buf, step_pos(s2 + e, sps, swing), mini(echo_step, 4) * sps, midi_freq(note(track, deg + 2 * k, octave)), timbre, 0.4)
				e += echo_step
				k += 1


## A short one-shot sound effect: pitch sweep plus noise.
static func sfx(f0: float, f1: float, dur: float, noise_amt: float, amp: float = 0.6) -> AudioStreamWAV:
	ensure_tables()
	var n: int = int(dur * SR)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	var ph: float = 0.0
	for i: int in n:
		var u: float = float(i) / float(n)
		ph += TAU * (f0 + (f1 - f0) * u) / float(SR)
		var sq: float = 1.0 if sin(ph) > 0.0 else -1.0
		var v: float = (sin(ph) * 0.7 + sq * 0.3) * (1.0 - noise_amt) + noise[i & 8191] * noise_amt
		v *= (1.0 - u) * (1.0 - u) * minf(1.0, float(i) / 40.0) * amp
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.data = data
	return w

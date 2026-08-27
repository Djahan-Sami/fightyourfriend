extends RefCounted
class_name SFX

# ============================================================
#  Bruitages generes en code (aucun fichier audio externe),
#  dans le meme esprit que le reste du jeu (tout est dessine).
# ============================================================

const RATE := 22050

static var _cache: Dictionary = {}


static func play(player: AudioStreamPlayer, name: String, vol_db := 0.0, pitch := 1.0) -> void:
	player.stream = _stream_for(name)
	player.volume_db = vol_db
	player.pitch_scale = pitch * randf_range(0.96, 1.04)
	player.play()


static func play2d(player: AudioStreamPlayer2D, name: String, vol_db := 0.0, pitch := 1.0) -> void:
	player.stream = _stream_for(name)
	player.volume_db = vol_db
	player.pitch_scale = pitch * randf_range(0.96, 1.04)
	player.play()


static func _stream_for(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStreamWAV
	match name:
		"jump":      s = _sweep(280.0, 560.0, 0.14, 0.5, false)
		"whiff":     s = _noise_burst(0.10, 0.16, 2600.0)
		"hit_light": s = _thump(160.0, 0.11, 0.85, true)
		"hit_heavy": s = _thump(95.0, 0.20, 1.0, true)
		"block":     s = _ring(1500.0, 0.10, 0.5)
		"grab":      s = _thump(130.0, 0.13, 0.7, false)
		"throw":     s = _thump(70.0, 0.24, 1.0, true)
		"ko":        s = _sweep(300.0, 55.0, 0.55, 0.9, true)
		"gong":      s = _gong()
		_: s = _thump(120.0, 0.10, 0.6, false)
	_cache[name] = s
	return s


# ---- generateurs ----
static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


static func _thump(freq: float, dur: float, amp: float, noisy: bool) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t / (dur * 0.28))
		var body := sin(TAU * freq * t) * 0.8
		if noisy:
			body += (randf() * 2.0 - 1.0) * 0.5
		s[i] = body * env * amp
	return _to_stream(s)


static func _sweep(f0: float, f1: float, dur: float, amp: float, noisy: bool) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var freq := lerpf(f0, f1, k)
		phase += TAU * freq / RATE
		var env := (1.0 - k) if noisy else exp(-t / (dur * 0.6))
		var v := sin(phase)
		if noisy:
			v += (randf() * 2.0 - 1.0) * 0.35
		s[i] = v * env * amp
	return _to_stream(s)


static func _noise_burst(dur: float, amp: float, cutoff: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	var a := clampf(cutoff / RATE, 0.02, 0.9)
	for i in n:
		var t := float(i) / RATE
		var env := 1.0 - t / dur
		var raw := randf() * 2.0 - 1.0
		prev += a * (raw - prev)
		s[i] = prev * env * amp
	return _to_stream(s)


static func _ring(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t / (dur * 0.18))
		var v := sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 1.5 * t) * 0.4
		s[i] = v * env * amp
	return _to_stream(s)


static func _gong() -> AudioStreamWAV:
	var dur := 0.9
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var partials := [220.0, 330.0, 440.0, 660.0]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * p * t) * exp(-t / (dur * 0.4)) * (1.0 / partials.size())
		s[i] = v * 0.9
	return _to_stream(s)

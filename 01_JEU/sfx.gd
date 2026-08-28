extends RefCounted
class_name SFX

# ============================================================
#  Bruitages generes en code (aucun fichier audio externe),
#  dans le meme esprit que le reste du jeu (tout est dessine).
# ============================================================

const RATE := 44100

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


# Les sons d'interface doivent survivre au changement de scene (par exemple
# lorsqu'on clique sur JOUER). Le lecteur temporaire est donc place a la racine.
static func play_global(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _stream_for(name)
	player.volume_db = vol_db
	player.pitch_scale = pitch * randf_range(0.98, 1.02)
	(loop as SceneTree).root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _stream_for(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStreamWAV
	match name:
		"ui_hover":    s = _two_tone(620.0, 700.0, 0.045, 0.16)
		"ui_confirm":  s = _two_tone(460.0, 760.0, 0.095, 0.30)
		"jump":        s = _sweep(240.0, 640.0, 0.15, 0.55, false)
		"step":        s = _impact(105.0, 0.055, 0.28, 0.08)
		"land":        s = _impact(62.0, 0.18, 0.72, 0.18)
		"whiff":       s = _noise_burst(0.11, 0.22, 4200.0)
		"hit_light":   s = _impact(155.0, 0.11, 0.85, 0.38)
		"hit_body":    s = _impact(105.0, 0.15, 0.98, 0.28)
		"hit_head":    s = _impact(175.0, 0.14, 1.0, 0.72)
		"hit_heavy":   s = _impact(72.0, 0.23, 1.0, 0.58)
		"block":       s = _ring(1450.0, 0.13, 0.62)
		"guard_break": s = _impact(58.0, 0.32, 1.0, 0.85)
		"grab":        s = _impact(125.0, 0.13, 0.70, 0.15)
		"throw":       s = _impact(55.0, 0.28, 1.0, 0.62)
		"countdown":   s = _ring(720.0, 0.09, 0.42)
		"fight":       s = _two_tone(410.0, 820.0, 0.18, 0.52)
		"victory":     s = _chime([523.25, 659.25, 783.99, 1046.50], 0.15, 0.52)
		"ko":          s = _sweep(310.0, 48.0, 0.62, 0.95, true)
		"gong":        s = _gong()
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


# Impact en deux couches : le grave donne le poids du contact et le bruit tres
# court donne sa nettete. Le dosage de crack distingue corps, tete et projection.
static func _impact(freq: float, dur: float, amp: float, crack: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var low_noise := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := clampf(t / dur, 0.0, 1.0)
		var body_env := exp(-t / maxf(0.012, dur * 0.26))
		var body_freq := freq * lerpf(1.35, 0.62, k)
		phase += TAU * body_freq / RATE
		var raw := randf() * 2.0 - 1.0
		low_noise += 0.10 * (raw - low_noise)
		var high_noise := raw - low_noise
		var crack_env := exp(-t / maxf(0.004, dur * 0.055))
		var click := 1.0 if t < 0.0025 else 0.0
		var value := sin(phase) * body_env * 0.86
		value += high_noise * crack_env * crack
		value += click * 0.12 * crack
		samples[i] = value * amp
	return _to_stream(samples)


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


static func _two_tone(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var k := clampf(t / dur, 0.0, 1.0)
		var freq := f0 if k < 0.48 else f1
		var local_k := fmod(k, 0.5) * 2.0
		var env := sin(PI * clampf(local_k, 0.0, 1.0)) * (1.0 - k * 0.35)
		samples[i] = sin(TAU * freq * t) * env * amp
	return _to_stream(samples)


static func _chime(notes: Array, step_duration: float, amp: float) -> AudioStreamWAV:
	var dur := step_duration * notes.size() + 0.18
	var n := int(RATE * dur)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / RATE
		var note_index := mini(int(t / step_duration), notes.size() - 1)
		var local_t := t - float(note_index) * step_duration
		var env := exp(-local_t / (step_duration * 0.72))
		var freq := float(notes[note_index])
		var value := sin(TAU * freq * local_t) * 0.72
		value += sin(TAU * freq * 2.0 * local_t) * 0.20
		value += sin(TAU * freq * 3.0 * local_t) * 0.08
		samples[i] = value * env * amp
	return _to_stream(samples)


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

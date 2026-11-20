class_name Sfx
extends Node
## Sons 100 % générés par code (aucun fichier audio) : AudioStreamWAV 16 bits mono.

const RATE: int = 22050

var _cache: Dictionary = {}
var _pool: Array = []
var _dig: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _drip_t: float = 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_dig = AudioStreamPlayer.new()
	_dig.stream = _stream("dig")
	_dig.volume_db = -4.0
	add_child(_dig)
	_hum = AudioStreamPlayer.new()
	_hum.stream = _stream("hum")
	_hum.volume_db = -18.0
	add_child(_hum)


func _process(delta: float) -> void:
	if not _hum.playing:
		return
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = _rng.randf_range(3.0, 9.0)
		play("drip", -16.0 + _rng.randf_range(-4.0, 2.0))


# ------------------------------------------------------------------ API

func start_ambience() -> void:
	_hum.play()


func stop_ambience() -> void:
	_hum.stop()


func play(sound: String, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _stream(sound)
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = _rng.randf_range(0.96, 1.04)
			p.play()
			return
	var p0: AudioStreamPlayer = _pool[0]
	p0.stream = stream
	p0.volume_db = volume_db
	p0.play()


func dig_loop(on: bool) -> void:
	if on and not _dig.playing:
		_dig.play()
	elif not on and _dig.playing:
		_dig.stop()


# ------------------------------------------------------------------ synthèse

func _stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStreamWAV
	match sound:
		"whack":
			s = _whack()
		"bell":
			s = _tones([[880.0, 0.0], [1320.0, 0.0]], 1.3, 5.0)
		"clink":
			s = _tones([[2200.0, 0.0], [3310.0, 0.0], [4100.0, 0.0]], 0.45, 9.0)
		"chew":
			s = _chew()
		"flush":
			s = _noise(1.9, 700.0, 1.0, "swell")
		"pee":
			s = _noise(1.4, 1800.0, 0.6, "flat")
		"scrape":
			s = _noise(0.5, 1200.0, 0.8, "swell")
		"dig":
			s = _dig_stream()
		"hum":
			s = _hum_stream()
		"drip":
			s = _drip()
		"found":
			s = _arp([523.25, 659.25, 783.99, 1046.5], 0.14, 0.5)
		"win":
			s = _arp([523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0], 0.16, 0.7)
		"alarm":
			s = _arp([440.0, 330.0, 440.0, 330.0], 0.18, 0.5)
		_:
			s = _noise(0.2, 1000.0, 0.5, "flat")
	_cache[sound] = s
	return s


func _make(data: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		var v: int = clampi(int(data[i] * 32000.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w


func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * float(RATE)))
	return a


func _noise(seconds: float, cutoff: float, gain: float, shape: String) -> AudioStreamWAV:
	var d: PackedFloat32Array = _buf(seconds)
	var n: int = d.size()
	var a: float = clampf(cutoff / float(RATE) * 6.0, 0.01, 0.95)
	var y: float = 0.0
	for i in n:
		var t: float = float(i) / float(n)
		var env: float = 1.0
		if shape == "swell":
			env = sin(t * PI)
		else:
			env = minf(1.0, minf(t * 12.0, (1.0 - t) * 12.0))
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		d[i] = y * env * gain
	return _make(d)


func _tones(tones: Array, seconds: float, decay: float) -> AudioStreamWAV:
	var d: PackedFloat32Array = _buf(seconds)
	for i in d.size():
		var t: float = float(i) / float(RATE)
		var env: float = exp(-t * decay) * minf(1.0, t * 400.0)
		var v: float = 0.0
		for k in tones.size():
			v += sin(TAU * float(tones[k][0]) * t) * (1.0 / float(k + 1))
		d[i] = v * env * 0.35
	return _make(d)


func _whack() -> AudioStreamWAV:
	var d: PackedFloat32Array = _buf(0.5)
	var ph: float = 0.0
	var y: float = 0.0
	for i in d.size():
		var t: float = float(i) / float(RATE)
		var f: float = lerpf(140.0, 45.0, minf(t * 6.0, 1.0))
		ph += TAU * f / float(RATE)
		y += 0.25 * (_rng.randf_range(-1.0, 1.0) - y)
		d[i] = (sin(ph) * exp(-t * 9.0) * 0.9 + y * exp(-t * 35.0) * 0.8)
	return _make(d)


func _chew() -> AudioStreamWAV:
	var d: PackedFloat32Array = _buf(0.9)
	var y: float = 0.0
	for i in d.size():
		var t: float = float(i) / float(RATE)
		var env: float = 0.0
		for c in [0.05, 0.27, 0.5, 0.72]:
			var dt: float = t - float(c)
			if dt > 0.0:
				env = maxf(env, exp(-dt * 40.0))
		y += 0.35 * (_rng.randf_range(-1.0, 1.0) - y)
		d[i] = y * env * 0.9
	return _make(d)


func _dig_stream() -> AudioStreamWAV:
	var seconds: float = 0.5
	var d: PackedFloat32Array = _buf(seconds)
	var y: float = 0.0
	for i in d.size():
		var t: float = float(i) / float(RATE)
		var phase: float = fmod(t * 4.0, 1.0)
		var env: float = pow(1.0 - phase, 2.0) * minf(1.0, phase * 30.0)
		y += 0.5 * (_rng.randf_range(-1.0, 1.0) - y)
		d[i] = (y * 0.55 + sin(TAU * 180.0 * t) * 0.12) * env
	return _make(d, true)


func _hum_stream() -> AudioStreamWAV:
	var d: PackedFloat32Array = _buf(2.0)
	for i in d.size():
		var t: float = float(i) / float(RATE)
		d[i] = sin(TAU * 60.0 * t) * 0.5 + sin(TAU * 120.0 * t) * 0.25 + sin(TAU * 180.0 * t) * 0.08
	return _make(d, true)


func _drip() -> AudioStreamWAV:
	var d: PackedFloat32Array = _buf(0.3)
	var ph: float = 0.0
	for i in d.size():
		var t: float = float(i) / float(RATE)
		ph += TAU * lerpf(1900.0, 800.0, minf(t * 14.0, 1.0)) / float(RATE)
		d[i] = sin(ph) * exp(-t * 28.0) * 0.6
	return _make(d)


func _arp(notes: Array, step: float, tail: float) -> AudioStreamWAV:
	var total: float = step * float(notes.size()) + tail
	var d: PackedFloat32Array = _buf(total)
	for i in d.size():
		var t: float = float(i) / float(RATE)
		var v: float = 0.0
		for k in notes.size():
			var dt: float = t - step * float(k)
			if dt > 0.0:
				v += sin(TAU * float(notes[k]) * dt) * exp(-dt * 4.0) * minf(1.0, dt * 300.0)
		d[i] = v * 0.25
	return _make(d)

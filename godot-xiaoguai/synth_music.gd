class_name SynthMusic
extends RefCounted
## Music made in code, so the game can play a fitting loop for what is happening without extra files or
## licences: calm, danger, a hidden enemy, meteors, earthquakes, raids and treasure rain. Loops are built
## once on a worker thread (prepare_all at start) and then cached; stream(id) is null until a loop is ready.

const RATE := 16000
const IDS := ["peace", "danger", "hidden", "meteor", "quake", "raid", "treasure"]

static var _cache := {}
static var _busy := {}
static var _tasks := {}


## The finished loop for an id, or null while it is still being built.
static func stream(id: String) -> AudioStreamWAV:
	return _cache.get(id)


static func has(id: String) -> bool:
	return _cache.has(id)


## Start building one loop in the background (nothing happens if it is built or being built).
## The worker only builds; the result is handed to the main thread with a deferred call, so no locks.
static func prepare(id: String) -> void:
	if _cache.has(id) or _busy.has(id) or not IDS.has(id):
		return
	_busy[id] = true
	_tasks[id] = WorkerThreadPool.add_task(func():
		var built := build(id)
		Callable(SynthMusic, "_store").call_deferred(id, built))


## Wait for any loop still being built (call before the game exits, or the worker threads can hang it).
static func finish() -> void:
	for id in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[id])
	_tasks.clear()


static func _store(id: String, built: AudioStreamWAV) -> void:
	_cache[id] = built
	_busy.erase(id)


static func prepare_all() -> void:
	for id in IDS:
		prepare(id)


## Build a loop right now (used by prepare, and directly by tests).
static func build(id: String) -> AudioStreamWAV:
	var m: Mix
	match id:
		"peace":
			m = _peace()
		"danger":
			m = _danger()
		"hidden":
			m = _hidden()
		"meteor":
			m = _meteor()
		"quake":
			m = _quake()
		"raid":
			m = _raid()
		_:
			m = _treasure()
	return m.to_stream()


# --- the mixer: renders notes and drums straight into a looping buffer ---

class Mix:
	const RATE := 16000
	var buf := PackedFloat32Array()
	var spb := 0.0

	func _init(beats: float, bpm: float) -> void:
		spb = RATE * 60.0 / bpm
		buf.resize(int(beats * spb))

	func _add(i: int, v: float) -> void:
		buf[i % buf.size()] += v

	## wave: 0 sine, 1 saw, 2 square, 3 triangle
	func tone(beat: float, dur: float, midi: float, vol: float, wave: int = 0, atk: float = 0.02, rel: float = 0.2, tremolo: float = 0.0) -> void:
		var f := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
		var start := int(beat * spb)
		var held := int(dur * spb)
		var tail := int(rel * RATE)
		var phase := 0.0
		for i in held + tail:
			var t := float(i) / RATE
			var env := minf(1.0, t / atk)
			if i >= held:
				env *= exp(-4.0 * float(i - held) / maxf(1.0, float(tail)))
			phase += f / RATE
			var p := fposmod(phase, 1.0)
			var w := 0.0
			match wave:
				0:
					w = sin(TAU * phase)
				1:
					w = (p * 2.0 - 1.0) * 0.55
				2:
					w = (1.0 if p < 0.5 else -1.0) * 0.4
				_:
					w = (absf(p * 4.0 - 2.0) - 1.0) * 0.8
			if tremolo > 0.0:
				env *= 1.0 - tremolo * (0.5 + 0.5 * sin(TAU * 6.0 * t))
			_add(start + i, w * env * vol)

	func kick(beat: float, vol: float = 0.9) -> void:
		var start := int(beat * spb)
		var n := int(0.28 * RATE)
		var phase := 0.0
		for i in n:
			var t := float(i) / RATE
			phase += (45.0 + 90.0 * exp(-t * 28.0)) / RATE
			_add(start + i, sin(TAU * phase) * exp(-t * 11.0) * vol)

	func tom(beat: float, freq: float, vol: float = 0.6) -> void:
		var start := int(beat * spb)
		var n := int(0.3 * RATE)
		var phase := 0.0
		for i in n:
			var t := float(i) / RATE
			phase += (freq * (1.0 + 0.5 * exp(-t * 20.0))) / RATE
			_add(start + i, sin(TAU * phase) * exp(-t * 9.0) * vol)

	func snare(beat: float, vol: float = 0.5) -> void:
		var start := int(beat * spb)
		var n := int(0.2 * RATE)
		for i in n:
			var t := float(i) / RATE
			_add(start + i, (randf() * 2.0 - 1.0) * exp(-t * 16.0) * vol + sin(TAU * 190.0 * t) * exp(-t * 22.0) * vol * 0.5)

	func hat(beat: float, vol: float = 0.2) -> void:
		var start := int(beat * spb)
		var n := int(0.05 * RATE)
		var last := 0.0
		for i in n:
			var r := randf() * 2.0 - 1.0
			var hp := r - last
			last = r
			_add(start + i, hp * exp(-float(i) / RATE * 70.0) * vol)

	func swell(beat: float, dur: float, vol: float = 0.2) -> void:
		var start := int(beat * spb)
		var n := int(dur * spb)
		var lp := 0.0
		for i in n:
			var k := float(i) / float(n)
			lp += ((randf() * 2.0 - 1.0) - lp) * (0.05 + 0.3 * k)
			_add(start + i, lp * k * k * vol)

	func bell(beat: float, midi: float, vol: float = 0.3) -> void:
		var f := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
		var start := int(beat * spb)
		var n := int(1.4 * RATE)
		for i in n:
			var t := float(i) / RATE
			_add(start + i, (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.76 * t) * exp(-t * 4.0)) * exp(-t * 2.6) * vol)

	func to_stream() -> AudioStreamWAV:
		var peak := 0.001
		for v in buf:
			peak = maxf(peak, absf(v))
		var gain := 0.85 / peak
		var bytes := PackedByteArray()
		bytes.resize(buf.size() * 2)
		for i in buf.size():
			bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
		var s := AudioStreamWAV.new()
		s.format = AudioStreamWAV.FORMAT_16_BITS
		s.mix_rate = RATE
		s.stereo = false
		s.data = bytes
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
		return s


# --- the tracks (A minor unless noted) ---

static func _peace() -> Mix:
	var m := Mix.new(32.0, 72.0)
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	for bar in 8:
		var ch: Array = chords[bar % 4]
		for n in ch:
			m.tone(bar * 4.0, 4.0, float(n) - 12.0, 0.16, 3, 0.4, 0.8)
		var arp := [ch[0], ch[1], ch[2], ch[1], ch[2], ch[1], ch[0], ch[1]]
		for i in 8:
			if (bar + i) % 3 != 2:
				m.bell(bar * 4.0 + i * 0.5, float(arp[i]) + 12.0, 0.16)
	return m


static func _danger() -> Mix:
	var m := Mix.new(16.0, 124.0)
	for beat in 16:
		m.kick(float(beat), 0.8)
		m.kick(float(beat) + 0.28, 0.5)   # lub-dub
	for bar in 4:
		m.tone(bar * 4.0, 4.0, 45.0, 0.2, 1, 0.3, 0.5, 0.5)
		m.tone(bar * 4.0, 4.0, 46.0, 0.12, 1, 0.3, 0.5, 0.5)   # a rubbing semitone
		m.swell(bar * 4.0 + 2.0, 2.0, 0.2)
	return m


static func _hidden() -> Mix:
	var m := Mix.new(32.0, 78.0)
	for bar in 8:
		m.tone(bar * 4.0, 4.0, 38.0, 0.25, 1, 0.6, 0.8, 0.25)
		m.tone(bar * 4.0, 4.0, 39.0 if bar % 2 == 0 else 44.0, 0.12, 3, 0.8, 0.8)
		m.tom(bar * 4.0 + 3.0, 70.0, 0.5)
		if bar % 2 == 1:
			m.swell(bar * 4.0 + 1.0, 3.0, 0.18)
			m.tom(bar * 4.0 + 3.5, 60.0, 0.4)
	return m


static func _meteor() -> Mix:
	var m := Mix.new(32.0, 142.0)
	var stab := [[57, 60, 63], [57, 60, 63], [56, 59, 62], [57, 60, 63]]
	for bar in 8:
		m.tone(bar * 4.0, 4.0, 33.0, 0.3, 1, 0.1, 0.3)
		for step in 8:
			if step in [0, 3, 4, 6]:
				m.tom(bar * 4.0 + step * 0.5, 95.0 + float(step) * 8.0, 0.55)
		for n in stab[bar % 4]:
			m.tone(bar * 4.0 + 2.0, 0.6, float(n), 0.1, 2, 0.01, 0.25)
		m.swell(bar * 4.0 + 3.0, 1.0, 0.18)
		m.kick(bar * 4.0, 0.8)
	return m


static func _quake() -> Mix:
	var m := Mix.new(24.0, 92.0)
	for bar in 6:
		m.tone(bar * 4.0, 4.0, 28.0, 0.5, 0, 0.2, 0.4, 0.6)       # sub bass trembling
		m.tone(bar * 4.0, 4.0, 40.0, 0.14, 1, 0.3, 0.4, 0.8)
		m.swell(bar * 4.0, 3.0, 0.22)
		m.tom(bar * 4.0 + 0.0, 62.0, 0.7)
		m.tom(bar * 4.0 + 1.5, 55.0, 0.5)
		m.tom(bar * 4.0 + 2.25, 66.0, 0.6)
		m.tom(bar * 4.0 + 3.5, 50.0, 0.7)
	return m


static func _raid() -> Mix:
	var m := Mix.new(32.0, 108.0)
	var roots := [45, 45, 41, 43]
	for bar in 8:
		var root: int = roots[bar % 4]
		m.kick(bar * 4.0, 0.85)
		m.kick(bar * 4.0 + 2.0, 0.85)
		m.snare(bar * 4.0 + 1.0, 0.45)
		m.snare(bar * 4.0 + 3.0, 0.45)
		for i in 8:
			m.hat(bar * 4.0 + i * 0.5, 0.12)
		for k in 3:
			m.tom(bar * 4.0 + 3.0 + k * 0.25, 120.0 - float(k) * 12.0, 0.4)
		for n in [root + 12, root + 19, root + 24]:
			m.tone(bar * 4.0, 1.8, float(n), 0.09, 1, 0.05, 0.4)
		m.tone(bar * 4.0, 3.5, float(root), 0.22, 1, 0.05, 0.3)
	# the horn call over the first bars
	m.tone(0.0, 2.0, 57.0, 0.16, 1, 0.1, 0.4)
	m.tone(2.0, 1.0, 64.0, 0.16, 1, 0.05, 0.3)
	m.tone(3.0, 3.0, 69.0, 0.18, 1, 0.05, 0.5)
	return m


static func _treasure() -> Mix:
	var m := Mix.new(32.0, 126.0)
	var chords := [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 65]]
	for bar in 8:
		var ch: Array = chords[bar % 4]
		for i in 8:
			m.bell(bar * 4.0 + i * 0.5, float(ch[i % 4]) + 12.0 + (12.0 if i % 8 == 7 else 0.0), 0.2)
			m.hat(bar * 4.0 + i * 0.5, 0.1)
		m.tone(bar * 4.0, 1.9, float(ch[0]) - 24.0, 0.25, 3, 0.02, 0.2)
		m.tone(bar * 4.0 + 2.0, 1.9, float(ch[2]) - 24.0, 0.25, 3, 0.02, 0.2)
		m.kick(bar * 4.0, 0.5)
		m.kick(bar * 4.0 + 2.0, 0.5)
	return m

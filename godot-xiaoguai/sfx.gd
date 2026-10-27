extends RefCounted
## Sound effects, made from math at startup: no audio files, so they add nothing to the size.
## Use Sfx.play(get_tree(), "bite") for a sound everyone hears, or
## Sfx.play_at(get_tree(), "hit", position) for a sound that gets quieter with distance.

const RATE := 22050
const POOL_SIZE := 16
const HEARD_WITHIN := 900.0   ## farther than this from 小怪 and a positional sound is skipped

## name -> [recipe, minimum seconds between two plays]. A recipe is a list of parts:
## [wave, from_hz, to_hz, seconds, volume, start_seconds]. wave: sine square saw tri noise.
const SOUNDS := {
	"bite": [[["noise", 0, 0, 0.05, 0.5, 0.0], ["square", 240, 110, 0.07, 0.35, 0.0]], 0.07],
	"hit": [[["noise", 0, 0, 0.05, 0.45, 0.0], ["sine", 320, 140, 0.08, 0.5, 0.0]], 0.05],
	"kill": [[["square", 420, 90, 0.16, 0.4, 0.0], ["noise", 0, 0, 0.08, 0.3, 0.0]], 0.05],
	"hurt": [[["saw", 200, 60, 0.22, 0.55, 0.0], ["noise", 0, 0, 0.1, 0.4, 0.0]], 0.15],
	"death": [[["saw", 320, 40, 0.9, 0.6, 0.0], ["noise", 0, 0, 0.4, 0.4, 0.0]], 0.5],
	"roll": [[["noise", 0, 0, 0.16, 0.3, 0.0], ["sine", 500, 250, 0.12, 0.2, 0.0]], 0.2],
	"lunge": [[["sine", 180, 700, 0.16, 0.5, 0.0], ["noise", 0, 0, 0.1, 0.25, 0.0]], 0.2],
	"dodge": [[["sine", 1000, 300, 0.11, 0.5, 0.0]], 0.2],
	"levelup": [[["square", 523, 523, 0.08, 0.35, 0.0], ["square", 659, 659, 0.08, 0.35, 0.08], ["square", 784, 784, 0.14, 0.35, 0.16]], 0.2],
	"evolve": [[["sine", 220, 1100, 0.7, 0.5, 0.0], ["square", 330, 1320, 0.7, 0.2, 0.05], ["sine", 1320, 1320, 0.3, 0.4, 0.7]], 0.5],
	"win": [[["square", 523, 523, 0.12, 0.35, 0.0], ["square", 659, 659, 0.12, 0.35, 0.12], ["square", 784, 784, 0.12, 0.35, 0.24], ["square", 1046, 1046, 0.4, 0.4, 0.36]], 0.5],
	"nova": [[["sine", 140, 30, 0.35, 0.7, 0.0], ["noise", 0, 0, 0.25, 0.4, 0.0]], 0.1],
	"bolt": [[["sine", 700, 1600, 0.14, 0.45, 0.0]], 0.08],
	"roar": [[["saw", 100, 55, 0.55, 0.55, 0.0], ["noise", 0, 0, 0.45, 0.3, 0.05]], 0.3],
	"doom": [[["saw", 60, 30, 1.1, 0.7, 0.0], ["noise", 0, 0, 0.9, 0.5, 0.0], ["sine", 300, 40, 0.8, 0.5, 0.0]], 0.5],
	"shoot": [[["square", 650, 300, 0.08, 0.3, 0.0]], 0.07],
	"explosion": [[["noise", 0, 0, 0.4, 0.7, 0.0], ["sine", 90, 35, 0.4, 0.6, 0.0]], 0.08],
	"warn": [[["sine", 440, 440, 0.1, 0.25, 0.0], ["sine", 330, 330, 0.1, 0.25, 0.12]], 0.2],
	"build": [[["square", 300, 300, 0.05, 0.4, 0.0], ["square", 520, 520, 0.07, 0.4, 0.06]], 0.05],
	"demolish": [[["noise", 0, 0, 0.14, 0.5, 0.0], ["square", 200, 80, 0.12, 0.3, 0.0]], 0.05],
	"deny": [[["square", 150, 150, 0.1, 0.4, 0.0], ["square", 120, 120, 0.12, 0.4, 0.12]], 0.15],
	"coin": [[["sine", 1200, 1200, 0.05, 0.3, 0.0], ["sine", 1700, 1700, 0.07, 0.3, 0.05]], 0.12],
	"chime": [[["sine", 660, 880, 0.35, 0.4, 0.0], ["sine", 990, 990, 0.3, 0.2, 0.1]], 0.4],
	"menu": [[["tri", 600, 800, 0.1, 0.4, 0.0]], 0.1],
	"pick": [[["square", 900, 900, 0.06, 0.35, 0.0], ["square", 1200, 1200, 0.08, 0.35, 0.06]], 0.1],
	# the skill sounds (see skill_sounds.gd): each is a base that individual skills retune
	"s_fire": [[["noise", 0, 0, 0.35, 0.45, 0.0], ["saw", 320, 110, 0.3, 0.35, 0.0], ["sine", 90, 60, 0.3, 0.3, 0.0]], 0.08],
	"s_ice": [[["sine", 1800, 1200, 0.25, 0.4, 0.0], ["sine", 2400, 2000, 0.2, 0.3, 0.05], ["noise", 0, 0, 0.05, 0.2, 0.0]], 0.08],
	"s_poison": [[["sine", 200, 420, 0.18, 0.4, 0.0], ["sine", 420, 180, 0.18, 0.35, 0.16], ["noise", 0, 0, 0.12, 0.15, 0.0]], 0.08],
	"s_bone": [[["square", 900, 500, 0.05, 0.4, 0.0], ["square", 800, 450, 0.05, 0.4, 0.07], ["square", 700, 400, 0.06, 0.4, 0.14], ["noise", 0, 0, 0.04, 0.3, 0.0]], 0.08],
	"s_wind": [[["noise", 0, 0, 0.45, 0.35, 0.0], ["sine", 500, 950, 0.4, 0.15, 0.0]], 0.1],
	"s_thunder": [[["noise", 0, 0, 0.5, 0.55, 0.0], ["saw", 80, 40, 0.5, 0.45, 0.0], ["square", 2000, 300, 0.08, 0.35, 0.0]], 0.1],
	"s_quake": [[["sine", 70, 30, 0.6, 0.8, 0.0], ["noise", 0, 0, 0.4, 0.4, 0.05]], 0.15],
	"s_growl": [[["saw", 110, 70, 0.5, 0.5, 0.0], ["saw", 116, 76, 0.5, 0.4, 0.0], ["noise", 0, 0, 0.3, 0.15, 0.0]], 0.2],
	"s_zap": [[["square", 1800, 300, 0.12, 0.35, 0.0], ["saw", 900, 100, 0.15, 0.3, 0.0], ["noise", 0, 0, 0.1, 0.3, 0.0]], 0.08],
	"s_heal": [[["sine", 520, 780, 0.25, 0.4, 0.0], ["sine", 780, 1040, 0.25, 0.4, 0.12], ["sine", 1040, 1040, 0.25, 0.3, 0.24]], 0.15],
	"s_curse": [[["saw", 220, 110, 0.5, 0.35, 0.0], ["sine", 110, 55, 0.5, 0.5, 0.0], ["noise", 0, 0, 0.2, 0.15, 0.1]], 0.15],
	"s_drain": [[["sine", 200, 900, 0.35, 0.4, 0.0], ["saw", 150, 450, 0.3, 0.2, 0.05]], 0.12],
	"s_buff": [[["tri", 400, 800, 0.18, 0.4, 0.0], ["tri", 600, 1200, 0.18, 0.4, 0.1]], 0.1],
	"s_spirit": [[["sine", 900, 400, 0.35, 0.35, 0.0], ["sine", 1350, 600, 0.35, 0.2, 0.0]], 0.1],
	"s_rock": [[["noise", 0, 0, 0.12, 0.55, 0.0], ["sine", 120, 60, 0.2, 0.6, 0.0], ["square", 200, 90, 0.1, 0.3, 0.0]], 0.08],
	"s_claw": [[["noise", 0, 0, 0.08, 0.45, 0.0], ["saw", 1500, 500, 0.1, 0.3, 0.0], ["saw", 1300, 400, 0.1, 0.3, 0.06]], 0.06],
	"s_goo": [[["sine", 200, 500, 0.1, 0.45, 0.0], ["sine", 500, 150, 0.12, 0.45, 0.1]], 0.07],
	"s_leaf": [[["noise", 0, 0, 0.3, 0.22, 0.0], ["tri", 1000, 1400, 0.15, 0.25, 0.05]], 0.1],
	"s_hell": [[["saw", 140, 50, 0.6, 0.45, 0.0], ["noise", 0, 0, 0.35, 0.3, 0.0], ["sine", 70, 35, 0.6, 0.5, 0.0]], 0.15],
	"s_holy": [[["sine", 880, 1760, 0.45, 0.3, 0.0], ["sine", 1320, 1320, 0.45, 0.22, 0.05], ["sine", 1760, 1760, 0.4, 0.18, 0.1]], 0.2],
	"s_shield": [[["square", 400, 300, 0.05, 0.4, 0.0], ["noise", 0, 0, 0.12, 0.3, 0.0], ["sine", 800, 1200, 0.2, 0.3, 0.04]], 0.08],
	"s_dash": [[["sine", 300, 1200, 0.15, 0.4, 0.0], ["noise", 0, 0, 0.2, 0.25, 0.0]], 0.08],
	"s_blast": [[["noise", 0, 0, 0.3, 0.6, 0.0], ["sine", 200, 50, 0.3, 0.6, 0.0], ["saw", 120, 40, 0.35, 0.3, 0.0]], 0.12],
}

static var enabled := true
static var master_db := -4.0
static var _streams := {}
static var _last_play := {}
static var _pool: Array[AudioStreamPlayer] = []
static var _holder: Node = null


## Every sound's name, for the tests.
static func names() -> Array:
	return SOUNDS.keys()


## Build (once) and return the stream for a sound.
static func stream_for(sound: String) -> AudioStreamWAV:
	if _streams.has(sound):
		return _streams[sound]
	var recipe: Array = SOUNDS[sound][0]
	var total := 0.0
	for part in recipe:
		total = maxf(total, float(part[5]) + float(part[3]))
	var count := int(total * RATE)
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	for part in recipe:
		var start := int(float(part[5]) * RATE)
		var length := int(float(part[3]) * RATE)
		var phase := 0.0
		for i in length:
			var t := float(i) / maxf(length - 1, 1)
			var hz := lerpf(float(part[1]), float(part[2]), t)
			phase += hz / RATE
			var v := 0.0
			match part[0]:
				"sine":
					v = sin(TAU * phase)
				"square":
					v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"saw":
					v = fmod(phase, 1.0) * 2.0 - 1.0
				"tri":
					v = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
				"noise":
					v = rng.randf_range(-1.0, 1.0)
			# a quick fade in, then a smooth fade out, so nothing clicks
			var env := minf(float(i) / 80.0, 1.0) * pow(1.0 - t, 1.5)
			var idx := start + i
			if idx < count:
				mix[idx] += v * env * float(part[4])
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, clampi(roundi(mix[i] * 12000.0), -32768, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	_streams[sound] = s
	return s


static func _ensure(tree: SceneTree) -> bool:
	if _holder != null and is_instance_valid(_holder) and _holder.is_inside_tree():
		return true
	if tree == null or tree.root == null:
		return false
	_holder = Node.new()
	_holder.name = "SfxPlayers"
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	_pool.clear()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		_holder.add_child(p)
		_pool.append(p)
	tree.root.add_child.call_deferred(_holder)
	return false  # the players join the tree at the end of this frame


## Play a sound for everyone. volume_db adds to the master volume; pitch 1.0 is normal.
static func play(tree: SceneTree, sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	if not enabled or not SOUNDS.has(sound) or not _ensure(tree):
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sound, -100000)) < int(float(SOUNDS[sound][1]) * 1000.0):
		return false
	for p in _pool:
		if not p.playing:
			_last_play[sound] = now
			p.stream = stream_for(sound)
			p.volume_db = master_db + volume_db
			p.pitch_scale = pitch
			p.play()
			return true
	return false


## A sound at a place: quieter with distance from 小怪, and skipped when far away.
static func play_at(tree: SceneTree, sound: String, pos: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> bool:
	var listener = tree.get_first_node_in_group("player") if tree != null else null
	if listener == null:
		return play(tree, sound, volume_db, pitch)
	var d: float = pos.distance_to(listener.global_position)
	if d > HEARD_WITHIN:
		return false
	return play(tree, sound, volume_db - 14.0 * d / HEARD_WITHIN, pitch)

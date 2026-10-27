extends Node
## Random events. One at a time, every minute or two once the first couple of minutes are over:
##   meteor shower  red marks warn where meteors will land; they hurt villagers, buildings and 小怪
##   earthquake     the ground shakes and cracks, villagers stagger, buildings take damage
##   raid           a war horn, then a big wave of villagers charges in from one side
##   treasure rain  stars fall and turn into EXP stones, bones and chests
## Each starts with a warning banner and its own music (see music_track), and ends with a notice.

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")
const MeteorScript := preload("res://meteor.gd")
const FallerScript := preload("res://faller.gd")
const CracksScript := preload("res://cracks.gd")
const TreasureScript := preload("res://treasure.gd")

const FIRST_AT := 120.0           # seconds into the run before the first event
const GAP_MIN := 70.0
const GAP_MAX := 130.0

const INFO := {
	"meteor": {"warn": 3.0, "length": 16.0, "banner": "METEOR SHOWER! Stay away from the red marks"},
	"quake": {"warn": 2.0, "length": 6.0, "banner": "The ground rumbles... EARTHQUAKE!"},
	"raid": {"warn": 5.0, "length": 1.0, "banner": "WAR HORN! A raid is coming"},
	"rain": {"warn": 1.5, "length": 18.0, "banner": "TREASURE RAIN! Gather what falls"},
}

var main: Node2D
var enabled := true
var rng := RandomNumberGenerator.new()
var gap_left := FIRST_AT
var pending := ""         ## the event being announced
var warn_left := 0.0
var active := ""          ## the event running now
var active_left := 0.0
var _tick := 0.0
var _quake_pulse := 0.0
var _raid_side := Vector2.LEFT
var started := {}          ## event name -> how many times it has started
var last := ""


func _ready() -> void:
	rng.randomize()
	gap_left = FIRST_AT + rng.randf_range(0.0, 30.0)


## The music that fits what is going on, or "" when no event is on.
func music_track() -> String:
	var e := active if active != "" else pending
	match e:
		"meteor":
			return "meteor"
		"quake":
			return "quake"
		"raid":
			return "raid"
		"rain":
			return "treasure"
	return ""


func busy() -> bool:
	return active != "" or pending != ""


func _process(delta: float) -> void:
	if main == null or main.game_over or main.player == null or main.player.hp <= 0:
		return
	if not busy():
		if not enabled or main.elapsed < FIRST_AT:
			return
		gap_left -= delta
		if gap_left <= 0.0:
			start(_pick())
		return
	if pending != "":
		warn_left -= delta
		if pending == "raid" and int(warn_left * 2.0) != int((warn_left + delta) * 2.0) and warn_left > 0.0:
			Sfx.play(main.get_tree(), "warn", -6.0)  # the horn keeps sounding while the raid gathers
		if warn_left <= 0.0:
			_begin(pending)
			pending = ""
		return
	active_left -= delta
	_tick -= delta
	_run(active, delta)
	if active_left <= 0.0:
		_finish()


func _pick() -> String:
	var options: Array = INFO.keys()
	options.erase(last)
	if main.elapsed < 240.0:
		options.erase("raid")  # no raids in the first minutes
	return options[rng.randi_range(0, options.size() - 1)]


## Announce an event; it begins after its warning time. Also called by tests.
func start(name: String) -> void:
	if not INFO.has(name) or busy():
		return
	pending = name
	warn_left = float(INFO[name]["warn"])
	last = name
	started[name] = int(started.get(name, 0)) + 1
	var text: String = INFO[name]["banner"]
	if name == "raid":
		_raid_side = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][rng.randi_range(0, 3)]
		var names := {Vector2.LEFT: "west", Vector2.RIGHT: "east", Vector2.UP: "north", Vector2.DOWN: "south"}
		text += " from the %s" % names[_raid_side]
	main._say(text)
	main._update_music()


func _begin(name: String) -> void:
	active = name
	active_left = float(INFO[name]["length"])
	_tick = 0.0
	_quake_pulse = 0.0
	if name == "raid":
		_spawn_raid()
	elif name == "quake":
		Sfx.play(main.get_tree(), "explosion", -2.0)
	main._update_music()


func _finish() -> void:
	var name := active
	active = ""
	gap_left = rng.randf_range(GAP_MIN, GAP_MAX)
	match name:
		"meteor":
			main._say("The sky is quiet again.")
		"quake":
			main._say("The shaking stops.")
		"rain":
			main._say("The treasure rain ends.")
	main._update_music()


func _run(name: String, delta: float) -> void:
	var p = main.player
	match name:
		"meteor":
			if _tick <= 0.0:
				_tick = rng.randf_range(0.35, 0.6)
				_drop_meteor()
		"quake":
			main.shake(5.0)
			_quake_pulse -= delta
			if _quake_pulse <= 0.0:
				_quake_pulse = 0.5
				_quake_pulse_effect()
			if active_left <= delta:
				_quake_damage_buildings()
		"rain":
			if _tick <= 0.0:
				_tick = rng.randf_range(0.45, 0.7)
				_drop_treasure()


# --- meteor shower ---

func _drop_meteor() -> void:
	var p = main.player
	var pos: Vector2
	var roll := rng.randf()
	var foes: Array = main.get_tree().get_nodes_in_group("enemies")
	if roll < 0.5 or foes.is_empty():
		pos = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 240.0)
	else:
		pos = foes[rng.randi_range(0, foes.size() - 1)].global_position + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
	var tile: Vector2i = main.tile_of(pos)
	if main.trees.has(tile):
		return
	var m = MeteorScript.new()
	m.position = pos
	m.damage = maxi(3, ceili(p.effective_bite() * 4.0))
	m.player_damage = maxi(1, roundi(p.max_hp * 0.12))
	main.add_child(m)


# --- earthquake ---

func _quake_pulse_effect() -> void:
	var p = main.player
	Sfx.play(main.get_tree(), "explosion", -9.0, 0.6)
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.global_position.distance_to(p.global_position) < 520.0:
			e.stun_left = maxf(e.stun_left, 0.45)
			e.take_hit(1, Vector2.ZERO, true)
	if p.global_position.x >= 0.0:
		p.slow_left = maxf(p.slow_left, 0.6)  # the ground heaves under 小怪 too
	for k in 2:
		var c = CracksScript.new()
		c.position = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 300.0)
		c.seed_value = rng.randi()
		main.add_child(c)
		main.move_child(c, 0)


func _quake_damage_buildings() -> void:
	var p = main.player
	for s in main.get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and s.global_position.distance_to(p.global_position) < 600.0:
			s.take_hit(2, Vector2.ZERO)


# --- raid ---

func _spawn_raid() -> void:
	var p = main.player
	var count := mini(10 + int(p.level / 4) + main.village_level * 2, 40)
	var along := _raid_side.rotated(PI * 0.5)
	var center: Vector2 = p.global_position + _raid_side * 620.0
	var made := 0
	for i in count:
		var pos: Vector2 = center + along * (float(i) - count * 0.5) * 16.0 + _raid_side * rng.randf_range(0.0, 120.0)
		var t: Vector2i = main.tile_of(pos)
		if t.x < 2 or t.y < 2 or t.x > main.COLS - 3 or t.y > main.ROWS - 3 or main.trees.has(t):
			continue
		var stage := clampi(main.village_level - 1 + rng.randi_range(0, 1), 0, 4)
		var v = main._spawn_villager(pos, stage)
		v.force_chase = true
		made += 1
	main._say("RAID! %d villagers charge in!" % made)
	Sfx.play(main.get_tree(), "warn", -2.0)


# --- treasure rain ---

func _drop_treasure() -> void:
	var p = main.player
	for tries in 8:
		var pos: Vector2 = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40.0, 280.0)
		var t: Vector2i = main.tile_of(pos)
		if main.trees.has(t) or main.water.has(t):
			continue
		var f = FallerScript.new()
		f.position = pos
		var roll := rng.randf()
		f.kind = "stone" if roll < 0.7 else ("bones" if roll < 0.9 else "chest")
		f.amount = maxi(3, 3 + int(p.level / 2)) if f.kind == "stone" else rng.randi_range(8, 24)
		main.add_child(f)
		return

extends Node
## Random events. One at a time, the first about a minute in, then every minute or so. Small events come
## first; medium ones unlock after 4 minutes and the big ones after 8, and newer tiers are picked a little more
## often. Each event has a warning banner, its own effects, and its own music (see music_track).
##
##  tier 1   treasure rain   lightning storm   toxic fog
##  tier 2   meteor shower   earthquake   blood moon   solar eclipse   flood   wandering merchant   comet
##  tier 3   raid   stampede   mimic chests   rival hero   developer attack (a giant bug)

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")
const MeteorScript := preload("res://meteor.gd")
const FallerScript := preload("res://faller.gd")
const CracksScript := preload("res://cracks.gd")
const TreasureScript := preload("res://treasure.gd")
const StrikeScript := preload("res://strike.gd")
const FogScript := preload("res://fog.gd")
const StampedeScript := preload("res://stampede.gd")
const MerchantScript := preload("res://merchant.gd")
const ChickenScript := preload("res://chicken.gd")
const PicnicScript := preload("res://picnic.gd")
const UfoScript := preload("res://ufo.gd")

const FIRST_AT := 60.0
const TIER_AT := [60.0, 240.0, 480.0]     # when each tier of events unlocks (seconds into the run)
const GAP_MIN := 55.0
const GAP_MAX := 100.0

const INFO := {
	# tier 1: small
	"rain": {"tier": 1, "warn": 1.5, "length": 18.0, "music": "treasure", "banner": "TREASURE RAIN! Gather what falls"},
	"lightning": {"tier": 1, "warn": 2.5, "length": 18.0, "music": "meteor", "banner": "A STORM rolls in. Watch the crackling marks!"},
	"picnic": {"tier": 1, "warn": 2.0, "length": 32.0, "music": "peace", "banner": "A VILLAGER PICNIC! They are busy eating... the second bite wakes them all"},
	"fog": {"tier": 1, "warn": 3.0, "length": 38.0, "music": "hidden", "banner": "TOXIC FOG drifts in. Keep out of the green cloud"},
	# tier 2: medium
	"meteor": {"tier": 2, "warn": 3.0, "length": 16.0, "music": "meteor", "banner": "METEOR SHOWER! Stay away from the red marks"},
	"quake": {"tier": 2, "warn": 2.0, "length": 6.0, "music": "quake", "banner": "The ground rumbles... EARTHQUAKE!"},
	"blood": {"tier": 2, "warn": 3.0, "length": 50.0, "music": "hidden", "banner": "A BLOOD MOON rises! Villagers are stronger, but pay double bones"},
	"eclipse": {"tier": 2, "warn": 3.0, "length": 40.0, "music": "hidden", "banner": "SOLAR ECLIPSE! Sudden night falls"},
	"flood": {"tier": 2, "warn": 3.0, "length": 34.0, "music": "quake", "banner": "HEAVY RAIN! The ponds are rising. Do not stand in water!"},
	"merchant": {"tier": 2, "warn": 2.0, "length": 60.0, "music": "peace", "banner": "A WANDERING MERCHANT has set up camp nearby"},
	"chicken": {"tier": 2, "warn": 2.5, "length": 32.0, "music": "treasure", "banner": "CHICKEN REBELLION! The chickens fight the villagers (a hurt you can eat one)"},
	"comet": {"tier": 2, "warn": 3.5, "length": 5.0, "music": "treasure", "banner": "A COMET is falling! Run to where it lands"},
	# tier 3: big
	"raid": {"tier": 3, "warn": 5.0, "length": 1.0, "music": "raid", "banner": "WAR HORN! A raid is coming"},
	"stampede": {"tier": 3, "warn": 2.5, "length": 12.0, "music": "raid", "banner": "STAMPEDE! Get out of the red lane"},
	"ufo": {"tier": 3, "warn": 3.0, "length": 36.0, "music": "hidden", "banner": "A UFO! It beams villagers up and drops them far away. Dodge the beam!"},
	"mimic": {"tier": 3, "warn": 2.0, "length": 4.0, "music": "", "banner": "Treasure chests glitter nearby... how lucky"},
	"rival": {"tier": 3, "warn": 4.0, "length": 100.0, "music": "hidden", "banner": "A RIVAL HERO hunts you! Defeat it for a gold chest"},
	"bug": {"tier": 3, "warn": 3.0, "length": 120.0, "music": "raid", "banner": "DEVELOPER ATTACK! A bug escaped from production"},
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
var _target = null        ## the villager of a rival or bug event
var _picnickers: Array = []
var _picnic_hits := 0
var _flood_added: Array[Vector2i] = []
var _flood_step := 0.0
var started := {}          ## event name -> how many times it has started
var last := ""


func _ready() -> void:
	rng.randomize()
	gap_left = FIRST_AT + rng.randf_range(0.0, 15.0)


## The music that fits what is going on, or "" when no event wants its own.
func music_track() -> String:
	var e := active if active != "" else pending
	return String(INFO[e]["music"]) if INFO.has(e) else ""


func busy() -> bool:
	return active != "" or pending != ""


func tier_unlocked(tier: int) -> bool:
	return main != null and main.elapsed >= float(TIER_AT[tier - 1])


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


## A random event from the unlocked tiers; the newest tier is favoured, the same one never twice in a row.
func _pick() -> String:
	var names: Array = []
	var weights: Array = []
	var top := 1
	for t in 3:
		if tier_unlocked(t + 1):
			top = t + 1
	for n in INFO:
		var tier: int = INFO[n]["tier"]
		if n == last or not tier_unlocked(tier):
			continue
		var w := 1.0 + 0.8 * float(tier - 1)
		if tier < top:
			w *= 0.5  # once bigger events exist the small ones become rarer
		names.append(n)
		weights.append(w)
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return names[i]
	return names[names.size() - 1]


## Announce an event; it begins after its warning time. Also called by tests.
func start(name: String) -> void:
	if not INFO.has(name) or busy():
		return
	pending = name
	warn_left = float(INFO[name]["warn"])
	last = name
	started[name] = int(started.get(name, 0)) + 1
	var text: String = INFO[name]["banner"]
	if name == "raid" or name == "stampede":
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
	match name:
		"raid":
			_spawn_raid()
		"quake":
			Sfx.play(main.get_tree(), "explosion", -2.0)
		"fog":
			_spawn_fog()
		"blood":
			main.blood_moon = true
			main.eclipse_left = active_left
		"eclipse":
			main.blood_moon = false
			main.eclipse_left = active_left
		"flood":
			_flood_step = 0.0
		"merchant":
			_spawn_merchant()
		"comet":
			_spawn_comet()
		"stampede":
			_spawn_stampede()
		"mimic":
			_spawn_mimics()
		"picnic":
			_spawn_picnic()
		"chicken":
			_spawn_chickens()
		"ufo":
			_spawn_ufo()
		"rival":
			_spawn_rival()
		"bug":
			_spawn_bug()
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
		"lightning":
			main._say("The storm passes.")
		"fog":
			main._say("The fog thins out.")
		"blood":
			main._say("The blood moon sets.")
		"eclipse":
			main._say("The sun returns.")
		"flood":
			_drain_flood()
			main._say("The water recedes.")
		"merchant":
			main._say("The merchant moves on.")
		"rival":
			main._say("The rival hero is gone.")
		"bug":
			main._say("The bug crawled away...")
		"picnic":
			_wake_picnic(false)
			main._say("The picnic is over.")
		"chicken":
			for c in main.get_tree().get_nodes_in_group("chickens"):
				c.leave()
			main._say("The chickens strut off, victorious.")
		"ufo":
			for u in main.get_tree().get_nodes_in_group("ufos"):
				u.leave()
			main._say("The UFO flies away.")
	_target = null
	main._update_music()


func _run(name: String, delta: float) -> void:
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
		"lightning":
			if _tick <= 0.0:
				_tick = rng.randf_range(0.8, 1.5)
				_drop_strike()
		"flood":
			_flood_step -= delta
			if _flood_step <= 0.0 and active_left > 8.0:
				_flood_step = 6.0
				_flood_grow()
		"rival", "bug":
			if not is_instance_valid(_target) or _target.is_queued_for_deletion():
				if name == "bug":
					main._say("The bug is squashed!")
				else:
					main._say("The rival hero falls!")
				_target = null
				active_left = 0.0


## A walkable spot between min and max pixels from 小怪, or Vector2.INF when none was found.
func _free_spot(dmin: float, dmax: float) -> Vector2:
	var p = main.player
	for i in 24:
		var pos: Vector2 = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(dmin, dmax)
		var t: Vector2i = main.tile_of(pos)
		if t.x < 3 or t.y < 3 or t.x > main.COLS - 4 or t.y > main.ROWS - 4:
			continue
		if main.trees.has(t) or main.water.has(t) or main.built.has(t):
			continue
		return pos
	return Vector2.INF


# --- meteor shower ---

func _drop_meteor() -> void:
	var p = main.player
	var pos: Vector2
	var foes: Array = main.get_tree().get_nodes_in_group("enemies")
	if rng.randf() < 0.5 or foes.is_empty():
		pos = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 240.0)
	else:
		pos = foes[rng.randi_range(0, foes.size() - 1)].global_position + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
	if main.trees.has(main.tile_of(pos)):
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
		f.kind = "stone" if roll < 0.75 else ("bones" if roll < 0.95 else "chest")
		f.amount = maxi(2, 2 + int(p.level / 3)) if f.kind == "stone" else rng.randi_range(4, 12)
		main.add_child(f)
		return


# --- lightning storm ---

func _drop_strike() -> void:
	var p = main.player
	var pos: Vector2
	var towers: Array = main.get_tree().get_nodes_in_group("towers")
	if rng.randf() < 0.3 and not towers.is_empty():
		pos = towers[rng.randi_range(0, towers.size() - 1)].global_position
	else:
		pos = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 260.0)
	var s = StrikeScript.new()
	s.position = pos
	s.damage = maxi(3, ceili(p.effective_bite() * 3.0))
	s.player_damage = maxi(1, roundi(p.max_hp * 0.1))
	main.add_child(s)


# --- toxic fog ---

func _spawn_fog() -> void:
	var p = main.player
	var from: Vector2 = p.global_position + Vector2.from_angle(rng.randf() * TAU) * 650.0
	var f = FogScript.new()
	f.position = from
	f.drift = (p.global_position - from).normalized() * 28.0
	f.life = active_left - 2.0
	main.add_child(f)


# --- flood: the ponds creep outward, then drain back ---

func _flood_grow() -> void:
	var fresh: Array[Vector2i] = []
	for c in main.water.keys():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var t: Vector2i = c + d
			if main.water.has(t) or fresh.has(t) or main.trees.has(t) or main.built.has(t):
				continue
			if t.x < 2 or t.y < 2 or t.x > main.COLS - 3 or t.y > main.ROWS - 3:
				continue
			if Vector2(t - main.START_TILE).length() < 12.0:
				continue  # the base meadow stays dry
			fresh.append(t)
	for t in fresh:
		main.water[t] = true
		_flood_added.append(t)
	Sfx.play(main.get_tree(), "explosion", -10.0, 0.5)
	main.shake(2.0)


func _drain_flood() -> void:
	for t in _flood_added:
		main.water.erase(t)
	_flood_added.clear()


# --- wandering merchant ---

func _spawn_merchant() -> void:
	var pos := _free_spot(220.0, 380.0)
	if pos == Vector2.INF:
		pos = main.player.global_position + Vector2(260, 0)
	var m = MerchantScript.new()
	m.position = pos
	main.add_child(m)


# --- comet ---

func _spawn_comet() -> void:
	var pos := _free_spot(200.0, 320.0)
	if pos == Vector2.INF:
		pos = main.player.global_position + Vector2(0, 220)
	var p = main.player
	for i in 12:
		var f = FallerScript.new()
		f.position = pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 70.0)
		f.fall = 1.0 + float(i) * 0.1
		f.kind = "stone" if i < 9 else ("bones" if i < 11 else "chest")
		f.amount = maxi(3, 4 + int(p.level / 3)) if f.kind == "stone" else rng.randi_range(10, 25)
		main.add_child(f)
	main._say("The comet lands near the marked spot!")


# --- stampede ---

func _spawn_stampede() -> void:
	var p = main.player
	var s = StampedeScript.new()
	s.heading = -_raid_side
	s.position = p.global_position + (-_raid_side).rotated(PI * 0.5) * rng.randf_range(-70.0, 70.0)
	main.add_child(s)


# --- mimic chests ---

func _spawn_mimics() -> void:
	for i in 2:
		var pos := _free_spot(120.0, 260.0)
		if pos == Vector2.INF:
			continue
		var c = TreasureScript.new()
		c.tier = "mimic"
		c.position = pos
		main.add_child(c)
	for i in 1:
		var pos2 := _free_spot(120.0, 280.0)
		if pos2 == Vector2.INF:
			continue
		var real = TreasureScript.new()
		real.tier = "silver"
		real.position = pos2
		main.add_child(real)


# --- rival hero and the bug ---

func _spawn_rival() -> void:
	var pos := _free_spot(520.0, 700.0)
	if pos == Vector2.INF:
		pos = main.player.global_position + Vector2(560, 0)
	var v = main._spawn_villager(pos, 4, 3, 1)
	v.rival = true
	v.title_override = "Rival Hero"
	v.max_hp = roundi(v.max_hp * 1.6)
	v.hp = v.max_hp
	v.force_chase = true
	_target = v


func _spawn_bug() -> void:
	var p = main.player
	var pos := _free_spot(450.0, 650.0)
	if pos == Vector2.INF:
		pos = p.global_position + Vector2(500, 0)
	var v = main._spawn_villager(pos, 4, 0)
	v.bug = true
	v.title_override = "BUG #404"
	v.body_scale = 2.4
	v.max_hp = 120 + p.level * 6
	v.hp = v.max_hp
	v.damage = 2
	v.speed = 78.0
	v.xp_value = 120
	v.bones_value = 40
	v.force_chase = true
	_target = v


# --- villager picnic: they sit and eat; the second bite wakes them all ---

func _spawn_picnic() -> void:
	var pos := _free_spot(240.0, 380.0)
	if pos == Vector2.INF:
		pos = main.player.global_position + Vector2(280, 0)
	var blanket = PicnicScript.new()
	blanket.position = pos
	blanket.life = active_left + 3.0
	main.add_child(blanket)
	main.move_child(blanket, 0)
	_picnickers.clear()
	_picnic_hits = 0
	for i in 6:
		var a := float(i) / 6.0 * TAU
		var v = main._spawn_villager(pos + Vector2.from_angle(a) * Vector2(40.0, 26.0), rng.randi_range(0, 1))
		v.calm = true
		_picnickers.append(v)


## Called by a picnicker that is hit. The first hit is free; the second wakes everyone.
func picnic_hit(_who) -> void:
	_picnic_hits += 1
	if _picnic_hits >= 2:
		_wake_picnic(true)


func _wake_picnic(angry: bool) -> void:
	var said := false
	for v in _picnickers:
		if is_instance_valid(v) and v.calm:
			v.calm = false
			v.force_chase = angry
			if angry and not said:
				v.say("HEY! That's MY sandwich!", 2.6)
				said = true
	_picnickers.clear()
	if angry:
		main._say("The picnic wakes up, and it's angry!")
		Sfx.play(main.get_tree(), "warn", -3.0)


# --- chicken rebellion ---

func _spawn_chickens() -> void:
	var p = main.player
	for i in 14:
		var c = ChickenScript.new()
		c.position = p.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(50.0, 150.0)
		main.add_child(c)
	Sfx.play(main.get_tree(), "coin", -4.0, 1.5)


# --- UFO ---

func _spawn_ufo() -> void:
	var u = UfoScript.new()
	u.main = main
	u.position = main.player.global_position + Vector2(-420.0, -260.0)
	main.add_child(u)

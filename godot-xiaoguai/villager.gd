extends CharacterBody2D
## The village. Humans come in 10 lines of 5 forms each, and 3 hidden forms beyond them.
## They evolve while they live; every villager that respawns is born at the current
## village level. They chase 小怪 from anywhere, walk around trees and walls, shoot from
## range (some lines) and use a skill every few seconds.
##
## Hidden forms (reachable from a line's last form at night, or by a day/night change):
##   Parasite Hero (hero + demon parasite) -> Dark Hero -> GOD

signal defeated(xp: int, bones: int, by_tower: bool)

const BoltScript := preload("res://bolt.gd")
const ZoneScript := preload("res://zone.gd")
const Sfx := preload("res://sfx.gd")
const ExpStone := preload("res://exp_stone.gd")
const TreasureLoot := preload("res://treasure.gd")
const Popups := preload("res://popups.gd")

const MAX_STAGE := 4          ## each line has 5 forms: stage 0 to 4
const EVOLVE_AFTER := 45.0    ## seconds alive before a villager moves to its next form
const HIDDEN_CHECK := 40.0    ## a last-form villager rolls for the hidden form this often...
const HIDDEN_CHANCE := 0.3    ## ...with this chance, but only at night
const PARASITE_TO_DARK := 60.0
const DARK_TO_GOD := 90.0     ## also needs village level 5
const HIT_COOLDOWN := 1.0
const SHOOT_COOLDOWN := 1.6
const CHARGE_TIME := 0.35
const STRUCTURE_AGGRO := 55.0 ## a tower or wall this close (and nearer than 小怪) draws their attack
const LOS_RANGE := 900.0      ## beyond this they just walk straight; closer, they steer around obstacles

## Base stats for forms 1 to 5; each line then scales them with hp / dmg / spd.
## Bites are 3.3x as fast as they were, so every villager has 1.25x the health it used to (bosses 1.5x).
const HP_SCALE := 1.25
const BOSS_HP_SCALE := 1.5
const HP := [2, 6, 12, 20, 32]
const DMG := [1, 1, 2, 3, 4]
const SPEED := [55.0, 62.0, 70.0, 78.0, 86.0]
const XP := [4, 8, 13, 19, 26]
const BONES := [1, 2, 3, 5, 8]
const SIZE := [1.0, 1.1, 1.2, 1.35, 1.5]

## Placeholder names; edit freely. Each line leans a different way.
const LINES := [
	{"name": "Farmer", "forms": ["Villager", "Farmer", "Harvester", "Scythe Master", "Harvest Lord"], "hp": 1.3, "dmg": 0.8, "spd": 0.9},
	{"name": "Woodsman", "forms": ["Woodcutter", "Lumberjack", "Axeman", "Berserker", "Forest Warden"], "hp": 1.0, "dmg": 1.4, "spd": 0.9},
	{"name": "Hunter", "forms": ["Hunter", "Archer", "Ranger", "Marksman", "Sniper"], "hp": 0.7, "dmg": 1.0, "spd": 1.3},
	{"name": "Militia", "forms": ["Militia", "Footman", "Soldier", "Veteran", "Captain"], "hp": 1.0, "dmg": 1.0, "spd": 1.0},
	{"name": "Knight", "forms": ["Squire", "Knight", "Paladin", "Crusader", "Templar"], "hp": 1.5, "dmg": 1.0, "spd": 0.8},
	{"name": "Priest", "forms": ["Acolyte", "Priest", "Cleric", "High Priest", "Saint"], "hp": 1.1, "dmg": 0.8, "spd": 1.0},
	{"name": "Mage", "forms": ["Apprentice", "Mage", "Battlemage", "Archmage", "Grand Magus"], "hp": 0.7, "dmg": 1.5, "spd": 0.9},
	{"name": "Smith", "forms": ["Smith", "Armorer", "Forgemaster", "Iron Smith", "Titan Smith"], "hp": 1.6, "dmg": 1.2, "spd": 0.7},
	{"name": "Thief", "forms": ["Thief", "Rogue", "Assassin", "Shadow Blade", "Night Master"], "hp": 0.8, "dmg": 1.1, "spd": 1.7},
	{"name": "Noble", "forms": ["Noble", "Lord", "Duke", "King", "Emperor"], "hp": 1.2, "dmg": 1.0, "spd": 1.0},
]

const HIDDEN := [
	{"name": "Parasite Hero", "hp": 60, "dmg": 5, "spd": 95.0, "xp": 60, "bones": 15, "size": 1.7},
	{"name": "Dark Hero", "hp": 100, "dmg": 8, "spd": 105.0, "xp": 100, "bones": 25, "size": 1.9},
	{"name": "GOD", "hp": 200, "dmg": 12, "spd": 110.0, "xp": 250, "bones": 60, "size": 2.4},
]

## Ranged basic attacks by line (index into LINES). mult scales their damage.
## Only archers, priests and mages shoot (and the hidden bosses). Villagers fight in melee; assassins do not shoot but run fast.
const RANGED := {
	2: {"range": 230.0, "speed": 330.0, "mult": 0.8, "color": Color("e8e0a0")},  # Hunter: arrows
	5: {"range": 150.0, "speed": 200.0, "mult": 0.6, "color": Color("fff2a0")},  # Priest: holy bolts
	6: {"range": 210.0, "speed": 240.0, "mult": 0.9, "color": Color("a060ff")},  # Mage: magic bolts
}
const HIDDEN_RANGED := {"range": 260.0, "speed": 300.0, "mult": 1.0, "color": Color("ff4060")}

## Each profession (line) learns several attacks as it evolves: [form index, skill]. The
## skills, with their base cooldowns in SKILL_COOLDOWN:
##   slow = mud ball that slows 小怪      net = net bolt that slows         pierce = bolt that passes through
##   axe = heavy thrown axe               volley = three bolts at once      smite = lightning strike on 小怪
##   fireball = delayed blast on 小怪     bomb = big slow blast on 小怪     slam = ground slam around itself
##   nova = wide burst around itself      charge = rush at 小怪             blink = teleport next to 小怪
##   shield = take half damage            rage = +30% damage and speed      rally = buff allies nearby
##   heal = heal allies nearby            summon = call two helpers
const LINE_SKILLS := [
	[[1, "slow"], [2, "pierce"], [4, "slam"]],                      # Farmer
	[[1, "axe"], [2, "slam"], [3, "rage"]],                         # Woodsman
	[[1, "net"], [2, "volley"], [3, "pierce"]],                     # Hunter
	[[1, "shield"], [2, "rally"], [3, "charge"]],                   # Militia
	[[1, "shield"], [2, "charge"], [4, "slam"]],                    # Knight
	[[1, "heal"], [2, "smite"], [4, "nova"]],                       # Priest
	[[1, "fireball"], [2, "smite"], [3, "volley"], [4, "nova"]],    # Mage
	[[1, "slam"], [2, "bomb"], [3, "shield"], [4, "pierce"]],       # Smith
	[[1, "charge"], [2, "blink"], [3, "volley"], [4, "rage"]],      # Thief
	[[1, "rally"], [2, "summon"], [3, "shield"], [4, "smite"]],     # Noble
]
const HIDDEN_SKILLS := [
	["spore_burst", "charge", "rage", "pierce"],        # Parasite Hero
	["shadow_barrage", "fireball", "nova", "blink", "shield"],   # Dark Hero
	["judgment", "smite", "nova", "slam", "heal", "rally"],   # GOD
]
const SKILL_COOLDOWN := {
	"slow": 6.0, "net": 7.0, "pierce": 6.0, "axe": 6.0, "volley": 7.0, "smite": 7.0,
	"fireball": 9.0, "bomb": 10.0, "slam": 8.0, "nova": 10.0, "charge": 8.0, "blink": 9.0,
	"shield": 12.0, "rage": 14.0, "rally": 14.0, "heal": 10.0, "summon": 22.0,
	"spore_burst": 14.0, "shadow_barrage": 16.0, "judgment": 20.0,
}

var line := 0
var stage := 0
var secret := -1             ## hidden form: -1 none, 0 Parasite Hero, 1 Dark Hero, 2 GOD
var hp := 2
var max_hp := 2
var damage := 1
var speed := 55.0
var xp_value := 4
var bones_value := 1
var body_scale := 1.0
var form_age := 0.0          ## seconds spent in the current form
var hit_cd := 0.0
var shoot_cd := 0.0
var skill_cd := 3.0          ## short pause between any two skills
var skill_timers := {}       ## skill -> seconds until it can be used again
var shield_left := 0.0       ## shield: take half damage
var buff_left := 0.0         ## rally or rage: +30% damage and speed
var stun_left := 0.0
var charge_left := 0.0
var charge_dir := Vector2.ZERO
var cast_flash := 0.0
var cast_color := Color.WHITE
var flash := 0.0
var evolve_flash := 0.0
var knock := Vector2.ZERO
var statuses := {}            ## status name -> seconds left: burn chill freeze root shock poison bleed charm curse
var poison_stacks := 0
var freeze_immune := 0.0     ## after a freeze they cannot be frozen again for a while
var dot_t := 0.0
var los := true              ## clear straight line to the target (refreshed a few times a second)
var path := PackedVector2Array()
var path_i := 0
var repath_cd := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	add_to_group("enemies")
	line = clampi(line, 0, LINES.size() - 1)
	stage = clampi(stage, 0, MAX_STAGE)
	_apply_form()
	hp = max_hp
	skill_cd = randf_range(2.0, 6.0)
	repath_cd = randf() * 0.4


func form_name() -> String:
	if title_override != "":
		return title_override
	if secret >= 0:
		return HIDDEN[secret]["name"]
	return LINES[line]["forms"][stage]


## Early in the game villagers cannot shoot or use skills: the level switches them on.
func _unlocked(what: String) -> bool:
	var level_node = get_parent()
	return not level_node.has_method(what) or level_node.call(what)


const SHOOTERS := [2, 5, 6]   ## Hunter, Priest and Mage: their bows and spells work from the first second


func _is_shooter() -> bool:
	return secret < 0 and SHOOTERS.has(line)


func ranged_config() -> Dictionary:
	if not _is_shooter() and not _unlocked("ranged_unlocked"):
		return {}
	if secret >= 0:
		return HIDDEN_RANGED
	return RANGED.get(line, {})


## Every skill this villager knows right now (none early in the game, see skills_unlocked).
func available_skills() -> Array:
	var out: Array = []
	if not _is_shooter() and not _unlocked("skills_unlocked"):
		return out
	if secret >= 0:
		return HIDDEN_SKILLS[secret].duplicate()
	for entry in LINE_SKILLS[line]:
		if stage >= entry[0]:
			out.append(entry[1])
	return out


## The first skill it knows, or "" if it has none yet.
func skill_name() -> String:
	var all := available_skills()
	return all[0] if not all.is_empty() else ""


## How far this villager can notice 小怪 (grows during the first minutes).
var guard_home := Vector2.INF     ## a guard stays near this spot (a castle) and only fights what comes close
var guard_range := 520.0       ## it notices 小怪 only when he is this close to its post
var guard_leash := 760.0       ## and never goes farther than this from it
var guard_until := 0.0         ## the run time (seconds) when it is released and hunts like the others
var calm := false              ## sitting at a picnic: no walking, no fighting until woken
var say_text := ""             ## what the speech bubble says
var say_left := 0.0
var say_cd := randf_range(2.0, 9.0)
var lines_override: Array = []  ## if set, the only things this villager says
var mimic := false             ## a chest that bit back (events)
var rival := false             ## the rival hero (events)
var bug := false               ## the developer's escaped bug (events)
var title_override := ""       ## a special name shown instead of the form name
var force_chase := false      ## raiders know where 小怪 is from the start


func _chase_radius() -> float:
	if force_chase:
		return INF
	var level_node = get_parent()
	return level_node.chase_radius() if level_node.has_method("chase_radius") else INF


## Days make villagers stronger (the level decides how much): damage and speed.
func _power() -> float:
	var level_node = get_parent()
	var p := 1.0
	if level_node.has_method("enemy_power"):
		p = level_node.enemy_power()
	return p * (1.3 if buff_left > 0.0 else 1.0)


func effective_damage() -> int:
	return ceili(damage * _power())


func effective_speed() -> float:
	var level_node = get_parent()
	var early: float = level_node.enemy_speed_mult() if level_node.has_method("enemy_speed_mult") else 1.0
	return speed * (1.0 + (_power() - 1.0) * 0.5) * early * (0.65 if has_status("chill") else 1.0) * (1.3 if enraged else 1.0)


func _apply_form() -> void:
	if secret >= 0:
		var h: Dictionary = HIDDEN[secret]
		max_hp = roundi(int(h["hp"]) * BOSS_HP_SCALE)
		damage = h["dmg"]
		speed = h["spd"]
		xp_value = h["xp"]
		bones_value = h["bones"]
		body_scale = h["size"]
		return
	var l: Dictionary = LINES[line]
	max_hp = maxi(1, roundi(HP[stage] * l["hp"] * HP_SCALE))
	damage = maxi(1, roundi(DMG[stage] * l["dmg"]))
	speed = SPEED[stage] * l["spd"]
	xp_value = XP[stage]
	bones_value = BONES[stage]
	body_scale = SIZE[stage]


## Move to another form, keeping the health gained and showing a flash.
func change_form(new_stage: int, new_secret: int) -> void:
	var old_max := max_hp
	stage = new_stage
	secret = new_secret
	_apply_form()
	hp += max_hp - old_max
	form_age = 0.0
	evolve_flash = 0.6


func apply_stun(seconds: float) -> void:
	stun_left = maxf(stun_left, seconds)


func _is_night() -> bool:
	var level_node = get_parent()
	return level_node.has_method("is_night") and level_node.is_night()


func _village_level() -> int:
	var level_node = get_parent()
	var v = level_node.get("village_level")
	return v if v != null else 1


func _grow(delta: float) -> void:
	form_age += delta
	if secret < 0:
		if stage < MAX_STAGE:
			if form_age >= EVOLVE_AFTER:
				change_form(stage + 1, -1)
		elif form_age >= HIDDEN_CHECK:
			form_age = 0.0
			if _is_night() and randf() < HIDDEN_CHANCE:
				change_form(stage, 0)
	elif secret == 0 and form_age >= PARASITE_TO_DARK:
		change_form(stage, 1)
	elif secret == 1 and form_age >= DARK_TO_GOD and _village_level() >= 5:
		change_form(stage, 2)


# --- steering: walk straight when the way is clear, otherwise follow an A* path ---

func _nav_update(target_pos: Vector2, delta: float) -> void:
	repath_cd -= delta
	if repath_cd > 0.0:
		return
	var nav = get_parent()
	if not nav.has_method("has_clear_line"):
		los = true
		return
	var dist := global_position.distance_to(target_pos)
	repath_cd = (0.8 if dist > 600.0 else 0.4) + randf() * 0.2
	if dist > LOS_RANGE:
		los = true
		path = PackedVector2Array()
		return
	los = nav.has_clear_line(global_position, target_pos)
	if los:
		path = PackedVector2Array()
		path_i = 0
	else:
		path = nav.find_path(global_position, target_pos)
		path_i = 1


func _steer(target_pos: Vector2) -> Vector2:
	if los or path.is_empty():
		return (target_pos - global_position).normalized()
	while path_i < path.size() and global_position.distance_to(path[path_i]) < 14.0:
		path_i += 1
	if path_i < path.size():
		return (path[path_i] - global_position).normalized()
	return (target_pos - global_position).normalized()


# --- attacks and skills ---

func _add_to_level(node: Node2D) -> void:
	get_parent().add_child.call_deferred(node)


func _spawn_bolt(dir: Vector2, spd: float, dmg: int, color: Color, effect: String = "", pierce: bool = false, life: float = 2.0, look: String = "") -> void:
	var b = BoltScript.new()
	b.position = global_position
	b.dir = dir
	b.speed = spd
	b.damage = dmg
	b.color = color
	b.effect = effect
	b.pierce = pierce
	b.life = life
	b.team = "enemy"
	if line == 2 and secret < 0:
		b.sprite = "fx_enemy_arrow"  # the hunters shoot pixel-art arrows
	b.style = look if look != "" else _enemy_bolt_style()
	Sfx.play_at(get_tree(), "shoot", global_position, -9.0)
	_add_to_level(b)


func _spawn_zone(pos: Vector2, rad: float, delay: float, dmg: int, color: Color, fx: String = "") -> void:
	var z = ZoneScript.new()
	z.fx = fx
	z.position = pos
	z.radius = rad
	z.delay = delay
	z.damage = dmg
	z.color = color
	z.team = "enemy"
	_add_to_level(z)


func _shoot(target, cfg: Dictionary) -> void:
	shoot_cd = SHOOT_COOLDOWN
	var dir: Vector2 = (target.global_position - global_position).normalized()
	_spawn_bolt(dir, cfg["speed"], maxi(1, roundi(effective_damage() * cfg["mult"])), cfg["color"])


## A short pause between any two skills (each skill also has its own cooldown).
func skill_cooldown() -> float:
	if secret >= 0:
		return 0.85 if enraged else 1.2
	return maxf(1.5, 3.0 - stage * 0.3)


func _allies_near(radius: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= radius:
			out.append(e)
	return out


func _bolt_color() -> Color:
	var cfg: Dictionary = RANGED.get(line, {})
	return cfg.get("color", Color("e8e0a0"))


## Pick any skill that is off cooldown and makes sense now, and use it. True if one fired.
func use_skill(target, dist: float) -> bool:
	var options := available_skills()
	options.shuffle()
	for id in options:
		if float(skill_timers.get(id, 0.0)) > 0.0:
			continue
		if use_skill_id(id, target, dist):
			return true
	return false


## Use one specific skill if its conditions are met (range, line of sight, allies...).
## On success it starts that skill's own cooldown and returns true.
func use_skill_id(id: String, target, dist: float) -> bool:
	var to: Vector2 = target.global_position - global_position
	var aim := to.normalized()
	var dmg := effective_damage()
	var fired := false
	match id:
		"spore_burst":
			if dist < 460.0:
				_fan(14, 150.0, maxi(1, roundi(dmg * 0.7)), Color("7ae040"), 0.0, 2.4)
				cast_color = Color("7ae040")
				fired = true
		"shadow_barrage":
			if dist < 520.0:
				for w in 3:
					get_tree().create_timer(0.35 * w).timeout.connect(func():
						if is_instance_valid(self) and hp > 0:
							_fan(12, 210.0, maxi(1, roundi(dmg * 0.6)), Color("a050e0"), 0.13 * w, 2.0))
				_spawn_zone(global_position, 70.0, 0.6, maxi(1, roundi(dmg * 1.2)), Color("a050e0"))
				cast_color = Color("a050e0")
				fired = true
		"judgment":
			if dist < 560.0:
				for k in 6:
					var spot: Vector2 = target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 110.0)
					_spawn_zone(spot, 40.0, 0.9 + 0.12 * k, maxi(1, roundi(dmg * 1.8)), Color("ffe680"))
				_spawn_zone(target.global_position, 120.0, 1.5, maxi(1, roundi(dmg * 2.2)), Color("fff2a0"))
				cast_color = Color("ffe680")
				fired = true
		"slow":
			if dist < 200.0 and los:
				_spawn_bolt(aim, 180.0, 1, Color("7d5e38"), "slow", false, 2.0, "mud")
				cast_color = Color("7d5e38")
				fired = true
		"net":
			if dist < 260.0 and los:
				_spawn_bolt(aim, 260.0, 1, Color("e8e8f0"), "slow", false, 2.0, "net")
				cast_color = Color("e8e8f0")
				fired = true
		"pierce":
			if dist < 300.0 and los:
				_spawn_bolt(aim, 300.0, maxi(1, roundi(dmg * 0.9)), _bolt_color(), "", true, 1.4, "javelin")
				cast_color = _bolt_color()
				fired = true
		"axe":
			if dist < 190.0 and los:
				_spawn_bolt(aim, 230.0, maxi(1, roundi(dmg * 1.8)), Color("b0a090"), "", false, 2.0, "axe")
				cast_color = Color("b0a090")
				fired = true
		"volley":
			if dist < 260.0 and los:
				for a in [-0.25, 0.0, 0.25]:
					_spawn_bolt(aim.rotated(a), 330.0, maxi(1, roundi(dmg * 0.7)), _bolt_color(), "", false, 2.0, "arrow")
				cast_color = _bolt_color()
				fired = true
		"smite":
			if dist < 320.0:
				_spawn_zone(target.global_position, 36.0, 0.5, maxi(1, roundi(dmg * 1.6)), Color("fff2a0"))
				cast_color = Color("fff2a0")
				fired = true
		"fireball":
			if dist < 280.0:
				_spawn_zone(target.global_position, 50.0, 0.9, maxi(1, roundi(dmg * 2.0)), Color(1.0, 0.45, 0.2), "fx_fireball_explosion")
				cast_color = Color(1.0, 0.45, 0.2)
				fired = true
		"bomb":
			if dist < 260.0:
				_spawn_zone(target.global_position, 62.0, 1.2, maxi(1, roundi(dmg * 2.2)), Color("e08a3a"), "fx_fireball_explosion")
				cast_color = Color("e08a3a")
				fired = true
		"slam":
			if dist < 70.0:
				_spawn_zone(global_position, 55.0, 0.6, maxi(1, roundi(dmg * 1.5)), Color(0.95, 0.8, 0.3))
				cast_color = Color(0.95, 0.8, 0.3)
				fired = true
		"nova":
			if dist < 110.0:
				_spawn_zone(global_position, 75.0, 0.7, maxi(1, roundi(dmg * 1.4)), Color("ffe680"))
				cast_color = Color("ffe680")
				fired = true
		"charge":
			if dist > 60.0 and dist < 220.0 and los:
				charge_dir = aim
				charge_left = CHARGE_TIME
				hit_cd = 0.0
				cast_color = Color(1, 1, 1)
				fired = true
		"blink":
			if dist > 100.0 and dist < 420.0:
				var spot: Vector2 = target.global_position - aim * 40.0
				var level_node = get_parent()
				if not (level_node.has_method("is_solid_at") and level_node.is_solid_at(spot)):
					global_position = spot
					hit_cd = 0.0
					cast_color = Color("b070ff")
					fired = true
		"shield":
			if shield_left <= 0.0 and dist < 260.0:
				shield_left = 4.0
				cast_color = Color("70d0ff")
				fired = true
		"rage":
			if buff_left <= 0.0 and dist < 260.0:
				buff_left = 5.0
				cast_color = Color("ff5030")
				fired = true
		"heal":
			for a in _allies_near(120.0):
				if a.hp < a.max_hp * 0.7:
					a.hp = mini(a.max_hp, a.hp + maxi(1, roundi(a.max_hp * 0.35)))
					a.evolve_flash = 0.4
					FxMark.spawn(get_parent(), a.global_position + Vector2(0, -6), "fx_heal_sparkle", 0.6)
					fired = true
			cast_color = Color("5ae07a")
		"rally":
			if dist < 450.0:
				var group := _allies_near(150.0)
				if group.size() >= 3:
					for a in group:
						a.buff_left = 6.0
					cast_color = Color("ffb040")
					fired = true
		"summon":
			var level_node = get_parent()
			if dist < 400.0 and level_node.has_method("target_population") \
					and get_tree().get_nodes_in_group("enemies").size() < level_node.target_population() + 15:
				for k in 2:
					level_node.call_deferred("_spawn_villager", global_position + Vector2(-20 + 40 * k, 14), 0, line)
				cast_color = Color("ffd040")
				fired = true
	if fired:
		var base := float(SKILL_COOLDOWN.get(id, 8.0))
		skill_timers[id] = base * (0.7 if secret >= 0 else 1.0)
		cast_flash = 0.4
	return fired


## Villagers far off screen think and move only every fourth tick (with the time of all four), which saves a lot of
## work on phones; anything near 小怪, hidden bosses and chasers close by run every tick.
const FAR_LOD := 1100.0
var _lod_tick := 0
var _lod_time := 0.0


func _physics_process(delta: float) -> void:
	if secret < 0 and not Engine.has_meta("deterministic_map"):  # (the tests need every villager on every tick)
		var near_player = get_tree().get_first_node_in_group("player")
		if near_player != null and near_player.global_position.distance_squared_to(global_position) > FAR_LOD * FAR_LOD:
			_lod_tick += 1
			_lod_time += delta
			if _lod_tick % 4 != 0:
				return
			delta = _lod_time
			_lod_time = 0.0
		else:
			_lod_time = 0.0
	hit_cd = maxf(hit_cd - delta, 0.0)
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	skill_cd = maxf(skill_cd - delta, 0.0)
	flash = maxf(flash - delta, 0.0)
	evolve_flash = maxf(evolve_flash - delta, 0.0)
	cast_flash = maxf(cast_flash - delta, 0.0)
	buff_left = maxf(buff_left - delta, 0.0)
	exposed_left = maxf(exposed_left - delta, 0.0)
	shield_left = maxf(shield_left - delta, 0.0)
	for id in skill_timers:
		skill_timers[id] = maxf(float(skill_timers[id]) - delta, 0.0)
	knock = knock.move_toward(Vector2.ZERO, 800.0 * delta)
	_grow(delta)
	_tick_statuses(delta)
	say_left = maxf(say_left - delta, 0.0)
	say_cd -= delta
	if say_cd <= 0.0:
		say_cd = randf_range(7.0, 15.0)
		_maybe_talk()
	if calm:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if is_queued_for_deletion():
		return

	if stun_left > 0.0 or has_status("freeze"):
		stun_left = maxf(stun_left - delta, 0.0)
		velocity = knock
		move_and_slide()
		queue_redraw()
		return

	# Always chase 小怪, from anywhere on the map. A tower or wall that is close enough to
	# be in the way (and nearer than 小怪) gets attacked instead.
	var target = null
	var reach := 0.0
	var best := INF
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.hp > 0:
		var seen: float = player.global_position.distance_to(global_position)
		if seen <= _chase_radius():
			best = seen
			target = player
			reach = 10.0 + player.body_radius
			if _guarding() and (player.global_position.distance_to(guard_home) > guard_range or global_position.distance_to(guard_home) > guard_leash):
				target = null  # a guard keeps to its post until the guards are released
				best = INF
	var struct_best := minf(STRUCTURE_AGGRO, best)
	for t in get_tree().get_nodes_in_group("structures"):
		var d: float = t.global_position.distance_to(global_position)
		if d < struct_best:
			struct_best = d
			target = t
			reach = 30.0  # a tower or wall is 28 to 30 px wide, and hits knock them back a little

	if has_status("charm"):
		target = _nearest_foe(400.0)  # a charmed villager fights for 小怪
		reach = 26.0

	var dir := Vector2.ZERO
	var move_speed := effective_speed()
	if charge_left > 0.0:
		charge_left -= delta
		dir = charge_dir
		move_speed *= 3.5
		if target != null and hit_cd == 0.0 and target.global_position.distance_to(global_position) < reach:
			hit_cd = HIT_COOLDOWN
			target.take_hit(effective_damage(), dir)
			Sfx.play(get_tree(), "hit_slash", -2.0)
	elif target != null:
		var to: Vector2 = target.global_position - global_position
		var dist := to.length()
		_nav_update(target.global_position, delta)
		var cfg: Dictionary = {} if has_status("charm") else ranged_config()
		var standing := false
		if not cfg.is_empty() and dist <= cfg["range"] and los:
			standing = true  # stand and shoot
			if dist < cfg["range"] * 0.45:
				dir = -to.normalized() * 0.6  # back off a little
			if shoot_cd == 0.0:
				_shoot(target, cfg)
		if not standing:
			dir = _steer(target.global_position)
		if dist < reach and hit_cd == 0.0:
			hit_cd = HIT_COOLDOWN
			target.take_hit(effective_damage(), to.normalized())
			SkillFx.spawn_fx(get_parent(), target.global_position, "slash", Color(1.0, 0.3, 0.25), to.normalized(), 1.1)
			Sfx.play(get_tree(), "hit_slash", -2.0)
		if skill_cd == 0.0 and not has_status("charm"):
			if use_skill(target, dist):
				skill_cd = skill_cooldown()
			else:
				skill_cd = 0.5  # nothing to use it on yet; look again shortly
	if target == null and _guarding() and global_position.distance_to(guard_home) > 48.0:
		_nav_update(guard_home, delta)
		dir = _steer(guard_home) * 0.7  # back to the post
	if has_status("root"):
		dir = Vector2.ZERO  # rooted: cannot walk, but can still shoot and use skills
	velocity = dir * move_speed + knock
	move_and_slide()
	queue_redraw()


# --- status effects ---

func has_status(status_name: String) -> bool:
	return float(statuses.get(status_name, 0.0)) > 0.0


## Put a status on this villager. Returns false if it resisted: the hidden forms cannot be
## frozen, rooted or charmed, and a freeze cannot be repeated right away.
func apply_status(status_name: String, seconds: float, stacks: int = 1) -> bool:
	if secret >= 0 and status_name in ["freeze", "root", "charm"]:
		return false
	if status_name == "freeze":
		if freeze_immune > 0.0:
			return false
		seconds = minf(seconds, 1.2)
		freeze_immune = seconds + 4.0
	if status_name == "poison":
		poison_stacks = mini(poison_stacks + stacks, 3)
	statuses[status_name] = maxf(float(statuses.get(status_name, 0.0)), seconds)
	return true


func _tick_statuses(delta: float) -> void:
	freeze_immune = maxf(freeze_immune - delta, 0.0)
	for s in statuses.keys():
		statuses[s] = float(statuses[s]) - delta
		if statuses[s] <= 0.0:
			statuses.erase(s)
			if s == "poison":
				poison_stacks = 0
	if statuses.is_empty():
		dot_t = 0.0
		return
	dot_t += delta
	if dot_t >= 1.0:  # burn, poison (per stack) and bleed hurt once a second
		dot_t -= 1.0
		var tick := 0
		if has_status("burn"):
			tick += 1
		if has_status("poison"):
			tick += poison_stacks
		if has_status("bleed"):
			tick += 1
		if tick > 0:
			hurt(tick)


## Damage over time and other hits that should not knock the villager around.
func hurt(dmg: int) -> void:
	if is_queued_for_deletion():
		return
	hp -= dmg
	flash = 0.1
	var tint := Popups.WHITE
	if has_status("burn"):
		tint = Popups.BURN
	elif has_status("poison"):
		tint = Popups.POISON
	elif has_status("bleed"):
		tint = Popups.BLEED
	Popups.damage(get_tree(), global_position + Vector2(0, -16.0 * body_scale), dmg, tint)
	if hp <= 0:
		Sfx.play_at(get_tree(), "die_enemy", global_position, -5.0)
		_boss_loot()
		_death_burst()
		defeated.emit(xp_value, bones_value, false)
		queue_free()


## The nearest other villager that is not charmed (the target of a charmed villager).
func _nearest_foe(radius: float):
	var best = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or e.is_queued_for_deletion() or e.has_status("charm"):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func take_hit(dmg: int, dir: Vector2, by_tower: bool = false) -> void:
	if is_queued_for_deletion():
		return
	if calm:
		_picnic_hit()
	var amount := ceili(dmg * 0.5) if shield_left > 0.0 else dmg
	if exposed_left > 0.0:
		amount = ceili(amount * 1.5)
	if has_status("curse"):
		amount = ceili(amount * 1.5)
	hp -= amount
	flash = 0.15
	if not by_tower:
		knock = dir * 260.0  # towers hurt but never push villagers back
	Popups.damage(get_tree(), global_position + Vector2(0, -16.0 * body_scale), amount, Popups.TOWER if by_tower else Popups.WHITE)
	Sfx.play_at(get_tree(), "die_enemy" if hp <= 0 else "hit", global_position, -5.0 if hp <= 0 else -7.0)
	if hp > 0 and say_left <= 0.0 and randf() < 0.1 and secret < 0:
		say(HURT_LINES[randi() % HURT_LINES.size()], 1.6)
	if secret >= 0 and hp > 0:
		_check_phase()
	Juice.hit(get_parent(), global_position + Vector2(0, -6.0 * body_scale), dir, float(amount) / maxf(1.0, float(max_hp)) + 0.25, Color(0.7, 0.85, 1.0) if by_tower else Color(1.0, 0.92, 0.65))
	if hp > 0 and has_status("shock") and randf() < 0.25:
		# shocked villagers pass part of every hit on to the nearest other villager
		var other = _nearest_foe(120.0)
		if other != null:
			other.hurt(maxi(1, int(amount / 2.0)))
	if hp <= 0:
		_boss_loot()
		_death_burst()
		if by_tower:
			ExpStone.spawn(get_parent(), global_position, xp_value)  # towers and pets leave an EXP stone to pick up
		defeated.emit(xp_value, bones_value, by_tower)
		queue_free()


func _draw() -> void:
	var sc := body_scale
	var squash := clampf(flash * 1.4, 0.0, 0.2)   # a quick squash and stretch when hit
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc * (1.0 + squash), sc * (1.0 - squash)))
	draw_circle(Vector2(0, 8), 7.0, Color(0, 0, 0, 0.25))

	var shirt := Color.from_hsv(float(line) / LINES.size(), 0.5, 0.7)
	if secret == 0:
		shirt = Color("5a2a5a")
		draw_circle(Vector2(0, -2), 15.0, Color(0.9, 0.2, 0.3, 0.2))
	elif secret == 1:
		shirt = Color("1a1020")
		draw_circle(Vector2(0, -2), 15.0, Color(0.5, 0.2, 0.8, 0.25))
	elif secret == 2:
		shirt = Color("fff2c0")
		draw_circle(Vector2(0, -2), 16.0, Color(1, 0.9, 0.4, 0.3))
	if buff_left > 0.0:
		draw_circle(Vector2(0, -2), 13.0, Color(1.0, 0.7, 0.2, 0.25))
	if shield_left > 0.0:
		draw_arc(Vector2(0, -2), 14.0, 0.0, TAU, 20, Color("70d0ff"), 2.0)
	var hat := shirt.lightened(0.35)
	var skin := Color("c9a27a")
	if flash > 0.0:
		shirt = Color.WHITE
		skin = Color.WHITE

	var art := Sprites.villager(line, stage, secret)
	if mimic:
		_draw_mimic()
	elif bug:
		_draw_bug()
	elif art != "" and Sprites.draw(self, art, int(Time.get_ticks_msec() / 500.0) % 2, 22.0, velocity.x < -6.0, Color(2, 2, 2) if flash > 0.0 else Color.WHITE, Vector2i.ZERO, (Time.get_ticks_msec() * 0.016 + float(get_instance_id() % 7)) if velocity.length() > 12.0 else -1.0):
		pass
	else:
		draw_rect(Rect2(-6, -2, 12, 12), shirt)
		draw_circle(Vector2(0, -6), 5.0, skin)
		draw_rect(Rect2(-8, -10, 16, 3), hat)
		draw_rect(Rect2(-4, -14, 8, 5), hat)

		if secret < 0:
			if stage >= 2:
				draw_line(Vector2(9, 8), Vector2(9, -12), Color("7a7a82"), 1.5)  # weapon
				draw_line(Vector2(6, -12), Vector2(12, -12), Color("7a7a82"), 1.5)
			if stage >= 3:
				draw_circle(Vector2(-8, 3), 4.0, Color("a0a0aa"))  # shield
			if stage >= 4:
				draw_rect(Rect2(-1, -19, 2, 5), Color("d03030"))  # plume
		else:
			# demon horns on every hidden form
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -12), Vector2(-2, -12), Vector2(-6, -19)]), Color("c02030"))
			draw_colored_polygon(PackedVector2Array([Vector2(5, -12), Vector2(2, -12), Vector2(6, -19)]), Color("c02030"))
			if secret == 0:
				draw_line(Vector2(-6, 2), Vector2(-11, 8), Color("5ac040"), 1.5)  # parasite tendrils
				draw_line(Vector2(6, 2), Vector2(11, 8), Color("5ac040"), 1.5)
			elif secret == 1:
				draw_colored_polygon(PackedVector2Array([Vector2(-8, -2), Vector2(8, -2), Vector2(12, 14), Vector2(-12, 14)]), Color(0.1, 0.05, 0.15, 0.7))
			else:
				draw_arc(Vector2(0, -20), 6.0, 0.0, TAU, 20, Color("ffe680"), 2.0)  # halo
				draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-18, -8), Vector2(-16, 6)]), Color(1, 1, 1, 0.8))
				draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(18, -8), Vector2(16, 6)]), Color(1, 1, 1, 0.8))

	if evolve_flash > 0.0:
		draw_arc(Vector2(0, -2), 12.0 + (0.6 - evolve_flash) * 20.0, 0.0, TAU, 24, Color(1, 1, 1, evolve_flash), 2.0)
	if cast_flash > 0.0:
		draw_arc(Vector2(0, -2), 16.0, 0.0, TAU, 24, Color(cast_color, cast_flash * 2.0), 3.0)
	if stun_left > 0.0:
		draw_arc(Vector2(0, -20), 6.0, 0.0, TAU, 12, Color("ffe680"), 2.0)
	# status marks: the pixel-art marks in a row above the head (shock and charm have no art yet)
	var marks: Array[String] = []
	for st in ["burn", "chill", "freeze", "root", "poison", "bleed", "curse"]:
		if has_status(st):
			marks.append("status_" + st)
	if stun_left > 0.0:
		marks.append("status_stun")
	for i in marks.size():
		var mt := Sprites.tex(marks[i])
		if mt != null:
			draw_texture_rect(mt, Rect2(-marks.size() * 5.0 + i * 10.0 + 1.0, -34.0 - 8.0 * sc, 9.0, 9.0), false)
	Juice.draw_status_aura(self, self, sc)
	if has_status("freeze"):
		draw_rect(Rect2(-8, -12, 16, 22), Color(0.6, 0.85, 1.0, 0.45))
	if has_status("shock"):
		draw_line(Vector2(-3, -14), Vector2(1, -10), Color("fff060"), 2.0)
		draw_line(Vector2(1, -10), Vector2(-1, -6), Color("fff060"), 2.0)
	if has_status("charm"):
		draw_circle(Vector2(-3, -18), 2.2, Color("ff70a0"))
		draw_circle(Vector2(3, -18), 2.2, Color("ff70a0"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label_color := Color(1, 0.85, 0.4) if secret >= 0 else Color(1, 1, 1, 0.9)
	draw_string(ThemeDB.fallback_font, Vector2(-30, -22 - 8 * sc), form_name(), HORIZONTAL_ALIGNMENT_CENTER, 60, 8, label_color)
	if calm:
		_draw_sandwich()
	if say_left > 0.0 and say_text != "":
		_draw_bubble(sc)


## Mimics, the rival hero and the bug pay out a gold chest where they fall.
func _boss_loot() -> void:
	if not (mimic or rival or bug or secret >= 0):
		return
	var level_node = get_parent()
	if level_node == null:
		return
	var chest = TreasureLoot.new()
	chest.tier = "gold"
	chest.position = global_position
	level_node.call_deferred("add_child", chest)
	if secret >= 0:
		# a hidden boss leaves two gold chests
		var second = TreasureLoot.new()
		second.tier = "gold"
		second.position = global_position + Vector2(26, 6)
		chest.position = global_position + Vector2(-26, 6)
		level_node.call_deferred("add_child", second)
		Popups.text(get_tree(), global_position + Vector2(0, -40.0), "BOSS DEFEATED!", Popups.BIG, 22)
		SkillFx.spawn_levelup(level_node)
		return
	Popups.text(get_tree(), global_position + Vector2(0, -30.0), "DEFEATED!", Popups.BIG, 18)
	if bug:
		SkillFx.spawn_levelup(level_node)


## A chest with teeth: open lid full of fangs, a red tongue, glaring eyes and stubby legs.
func _draw_mimic() -> void:
	var t := Time.get_ticks_msec() * 0.012
	var snap := 3.0 + absf(sin(t)) * 4.0
	var legs := sin(t * 1.5) * 1.5
	draw_rect(Rect2(-9, 8, 4, 3 + legs), Color("5a3b1c"))
	draw_rect(Rect2(5, 8, 4, 3 - legs), Color("5a3b1c"))
	draw_rect(Rect2(-10, 0, 20, 10), Color("c99a2a"))
	draw_rect(Rect2(-10, 0, 20, 10), Color("6a4a10"), false, 1.5)
	draw_rect(Rect2(-10, 3, 20, 2), Color("6a4a10"))
	draw_rect(Rect2(-9, 1, 18, 3), Color("2a0a10"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 2), Vector2(3, 2), Vector2(2, 7), Vector2(-2, 7)]), Color("d03050"))
	for k in 6:
		var x := -8.0 + float(k) * 3.2
		draw_colored_polygon(PackedVector2Array([Vector2(x, 1), Vector2(x + 3.0, 1), Vector2(x + 1.5, 4.5)]), Color.WHITE)
	var lid := PackedVector2Array([Vector2(-10, -snap + 1), Vector2(-8, -snap - 7), Vector2(0, -snap - 9), Vector2(8, -snap - 7), Vector2(10, -snap + 1)])
	draw_colored_polygon(lid, Color("e0b040"))
	draw_polyline(lid, Color("6a4a10"), 1.5)
	for k in 6:
		var x2 := -8.0 + float(k) * 3.2
		draw_colored_polygon(PackedVector2Array([Vector2(x2, -snap + 1), Vector2(x2 + 3.0, -snap + 1), Vector2(x2 + 1.5, -snap + 5.0)]), Color.WHITE)
	draw_circle(Vector2(-4, -snap - 3), 1.8, Color("ff3030"))
	draw_circle(Vector2(4, -snap - 3), 1.8, Color("ff3030"))


## The escaped bug: a glitching beetle with a split shell, six scurrying legs and red eyes.
func _draw_bug() -> void:
	var t := Time.get_ticks_msec() * 0.015
	var glitch := int(Time.get_ticks_msec() / 110.0) % 7 == 0
	var shell := PackedVector2Array()
	for i in 18:
		var a := float(i) / 18.0 * TAU
		shell.append(Vector2(cos(a) * 12.0, sin(a) * 9.0 + 1.0))
	for k in 3:
		var sy := -5.0 + float(k) * 6.0
		var off := 3.0 if glitch and k == 1 else 0.0
		draw_line(Vector2(-10 + off, sy + 9.0), Vector2(-12.0 + off, sy + 12.0 + sin(t + float(k)) * 2.0), Color("203020"), 2.0)
		draw_line(Vector2(10 + off, sy + 9.0), Vector2(12.0 + off, sy + 12.0 - sin(t + float(k)) * 2.0), Color("203020"), 2.0)
	draw_colored_polygon(shell, Color("2a7a50"))
	draw_polyline(shell + PackedVector2Array([shell[0]]), Color("0a2a1a"), 1.5)
	draw_line(Vector2(0, -8), Vector2(0, 10), Color("0a2a1a"), 1.5)
	draw_circle(Vector2(-5, -1), 2.2, Color(1, 1, 1, 0.25))
	draw_circle(Vector2(5, 3), 2.2, Color(1, 1, 1, 0.25))
	draw_circle(Vector2(0, -11), 5.0, Color("1a5a38"))
	draw_circle(Vector2(-2, -12), 1.5, Color("ff2020"))
	draw_circle(Vector2(2, -12), 1.5, Color("ff2020"))
	draw_line(Vector2(-2, -15), Vector2(-6, -21 + sin(t) * 2.0), Color("0a2a1a"), 1.5)
	draw_line(Vector2(2, -15), Vector2(6, -21 - sin(t) * 2.0), Color("0a2a1a"), 1.5)
	if glitch:
		draw_rect(Rect2(-14, -2, 28, 2), Color(0.2, 1.0, 0.8, 0.7))
		draw_rect(Rect2(-12, 5, 24, 1.5), Color(1.0, 0.2, 0.6, 0.7))


## Souls and sparkles instead of just vanishing; the colour follows the profession.
func _death_burst() -> void:
	if randf() < 0.3 and not (mimic or bug):
		Popups.text(get_tree(), global_position + Vector2(0, -26.0 * body_scale), LAST_WORDS[randi() % LAST_WORDS.size()], Popups.WHITE, 11)
	var tint := Color.from_hsv(float(line) / float(LINES.size()), 0.45, 1.0)
	if secret >= 0:
		tint = [Color("5ac040"), Color("a050e0"), Color("ffd040")][secret]
	Juice.death(get_parent(), global_position + Vector2(0, -4.0 * body_scale), body_scale, tint)
	if body_scale >= 1.6 or mimic or rival or bug:
		Juice.punch(get_parent(), 0.03)
		Juice.hitstop(get_tree(), 0.06)


# --- talking villagers ---

const GENERAL_LINES := ["Is that a potato?", "Mom said no!", "I have a family!", "Nice teeth...", "It's just a small monster!", "Where's my sword?",
	"I didn't sign up for this", "Is it lunch time?", "Don't bite me, I taste bad!", "Who left the gate open?", "Wait, is that legal?", "I'm on my break!"]
const HURT_LINES := ["Ouch!", "My hat!", "That's rude!", "I felt that.", "Medic?!", "Not the face!"]
const LAST_WORDS := ["Tell my cow...", "Worth it.", "I regret nothing.", "Rematch?", "Dang.", "Bye, cruel world!"]
const HIDDEN_LINES := ["You cannot escape.", "Kneel.", "...", "Foolish monster.", "Come closer."]
const PICNIC_LINES := ["Nom nom nom", "Best sandwich ever!", "Beautiful day!", "Pass the thermos", "Who brought pickles?", "Zzz... lunch..."]
## by profession (index into LINES): Farmer, Woodsman, Hunter, Militia, Knight, Priest, Mage, Smith, Thief, Noble
const PROFESSION_LINES := [
	["My crops!", "The wheat!", "Not the pumpkins!"],
	["Timber?!", "I only came for wood!", "My axe is bigger!"],
	["I swear it was a deer", "Stay still!", "I never miss. Usually."],
	["Hold the line!", "Left, right, left!", "Is it on the schedule?"],
	["For honour!", "I'm not scared. My armour is.", "Charge!"],
	["Bless this mess", "Have you tried praying?", "Be healed! ...maybe."],
	["I read about this", "It's a spell, I promise", "Hold on, wrong scroll"],
	["I just forged that!", "That's a fine dent", "Hammer time!"],
	["I'm just passing by", "Nothing in my pockets!", "Ever seen a hat like this?"],
	["Do you know who I am?", "My lawyers will hear of this", "Guards! ...hello?"],
]


func say(text: String, secs: float = 2.4) -> void:
	say_text = text
	say_left = secs


func _talkers() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.say_left > 0.0:
			n += 1
	return n


func _maybe_talk() -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or stun_left > 0.0 or say_left > 0.0:
		return
	if global_position.distance_to(pl.global_position) > 420.0 or _talkers() >= 3:
		return
	var pool: Array
	if not lines_override.is_empty():
		pool = lines_override
	elif calm:
		pool = PICNIC_LINES
	elif hp < max_hp * 0.4:
		pool = HURT_LINES
	elif secret >= 0:
		pool = HIDDEN_LINES
	elif randf() < 0.45:
		pool = PROFESSION_LINES[line]
	else:
		pool = GENERAL_LINES
	say(pool[randi() % pool.size()])


func _draw_bubble(sc: float) -> void:
	var font := ThemeDB.fallback_font
	var size := 9
	var w := font.get_string_size(say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 10.0
	var a := minf(1.0, say_left / 0.4)
	var y := -42.0 - 8.0 * sc
	var r := Rect2(-w * 0.5, y - 12.0, w, 14.0)
	draw_rect(r.grow(1.0), Color(0.1, 0.1, 0.15, 0.85 * a))
	draw_rect(r, Color(1, 1, 1, 0.95 * a))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, y + 2.0), Vector2(3, y + 2.0), Vector2(0, y + 7.0)]), Color(1, 1, 1, 0.95 * a))
	draw_string(font, Vector2(-w * 0.5 + 5.0, y - 1.5), say_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.1, 0.15, a))


func _draw_sandwich() -> void:
	var nom := sin(Time.get_ticks_msec() * 0.012) * 0.8
	draw_rect(Rect2(5, 3 + nom, 7, 2.5), Color(0.9, 0.75, 0.45))
	draw_rect(Rect2(5, 5.5 + nom, 7, 1.5), Color(0.4, 0.8, 0.3))
	draw_rect(Rect2(5, 7 + nom, 7, 2.5), Color(0.9, 0.75, 0.45))


## Hitting a picnicker is noted by the picnic event (the second hit wakes everyone).
func _picnic_hit() -> void:
	var main = get_parent()
	if main != null and main.get("events") != null:
		main.events.picnic_hit(self)


## True while this villager is a guard on duty (it has a post and the guards have not been released yet).
func _guarding() -> bool:
	if guard_home == Vector2.INF:
		return false
	var level_node = get_parent()
	var now: float = float(level_node.get("elapsed")) if level_node != null and level_node.get("elapsed") != null else 0.0
	return now < guard_until


# --- the hidden bosses: their own shot looks and burst skills ---

const BURST_SKILL := ["spore_burst", "shadow_barrage", "judgment"]
var phase_done := 0
var enraged := false         ## a hidden boss below a third of its health: faster, quicker skills
var exposed_left := 0.0       ## the weak point is open: the boss takes 50% more damage


## What this villager's projectiles look like (see SkillFx.draw_bolt). Hunters use the arrow sprite.
func _enemy_bolt_style() -> String:
	if secret >= 0:
		return ["spore", "shadow", "divine"][secret]
	match line:
		5:
			return "holy"
		6:
			return "magic"
	return ""


## A ring of bolts, rotated by `turn` radians.
func _fan(n: int, speed: float, dmg: int, color: Color, turn: float, life: float) -> void:
	for i in n:
		_spawn_bolt(Vector2.from_angle(turn + float(i) / n * TAU), speed, dmg, color, "", false, life)


## At two thirds and one third of its health a hidden boss bursts at once, whatever its cooldown.
func _check_phase() -> void:
	var frac := float(hp) / maxf(1.0, float(max_hp))
	var step := 0 if frac > 0.66 else (1 if frac > 0.33 else 2)
	if step <= phase_done:
		return
	phase_done = step
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	say(["The spores wake!", "Shadows, rise!", "Judgment!"][secret], 2.2)
	use_skill_id(BURST_SKILL[secret], pl, 120.0)
	skill_cd = skill_cooldown()
	if step == 1:
		_summon_guards(3)
	else:
		# the last phase: it enrages (faster, quicker skills) but is left gasping, its weak point wide open
		enraged = true
		exposed_left = 4.0
		stun_left = maxf(stun_left, 1.2)
		flash = 0.4
		Popups.text(get_tree(), global_position + Vector2(0, -34.0 * body_scale), "WEAK POINT!", Popups.BIG, 20)
		SkillFx.spawn_fx(get_parent(), global_position, "impact", Color("ffe680"), Vector2.RIGHT, 2.5)
		Sfx.play(get_tree(), "warn", -2.0)


## The boss calls guards: a few ordinary villagers that fight at its side.
func _summon_guards(n: int) -> void:
	var level_node = get_parent()
	if level_node == null or not level_node.has_method("_spawn_villager"):
		return
	for k in n:
		var spot := global_position + Vector2.from_angle(TAU * float(k) / float(n)) * 44.0
		var g = level_node.call("_spawn_villager", spot, 2, -1, -1)
		g.force_chase = true
	Popups.text(get_tree(), global_position + Vector2(0, -34.0 * body_scale), "Guards, rise!", Popups.BIG, 16)

extends CharacterBody2D
## 小怪. He starts as a tiny Xiao Guai and levels up from EXP. Every level offers a skill
## to learn. Every 5 levels he evolves; the first evolution (level 5) lets you pick which
## of the 26 monster lines to follow, and each later evolution is the next form in it.
## Between evolutions he visibly grows a little with every level.

const LinesData := preload("res://lines.gd")
const SkillsData := preload("res://skills.gd")
const TreasureData := preload("res://treasure.gd")
const SPECIAL_COLORS := {"overdrive": Color("ff5030"), "frenzy": Color("ffa030"), "ironwill": Color("a0b0d0"), "secondwind": Color("60e090"),
	"phoenix": Color("ff8a30"), "cleave": Color("e0e0ff"), "stormcaller": Color("a0c0ff"), "bloodmoon": Color("e02040"),
	"gravity": Color("a070ff"), "titan": Color("d0a060"), "mastery": Color("ffd040"), "bonehoard": Color("ffd860")}
const BoltScript := preload("res://bolt.gd")
const ZoneScript := preload("res://zone.gd")
const Sfx := preload("res://sfx.gd")
const Popups := preload("res://popups.gd")
const AbilitiesData := preload("res://abilities.gd")
const PoolScript := preload("res://pool.gd")
const BreathScript := preload("res://breath.gd")
const HelperScript := preload("res://helper.gd")

signal hp_changed(hp: int)
signal died
signal xp_changed
signal leveled(level: int)    ## a new level (a skill pick comes every 3rd, a special every 12th)
signal line_needed            ## level 10 reached: pick the evolution line
signal evolved(stage: int)

const MAX_LEVEL := 100
const EVOLVE_EVERY := 10      ## a new form every 10 levels; the first one (level 10) picks the line
const SKILL_EVERY := 3        ## a normal skill pick every 3 levels
const SPECIAL_EVERY := 12     ## a special skill pick every 12 levels (12, 24 ... 96)
const LAST_STAGE := 10        ## stage 0 is Xiao Guai; stages 1 to 10 are the line's 10 forms

const SPEED := 130.0
const SPRINT_MULT := 2.2
const SPRINT_MAX := 10.0       ## seconds of sprint available
const SPRINT_COOLDOWN := 15.0  ## lockout after running out
const ROLL_SPEED := 340.0
const ROLL_TIME := 0.25
const ROLL_INVULN := 0.35
const ROLL_COOLDOWN := 0.9
const LUNGE_SPEED := 320.0
const LUNGE_TIME := 0.2
const LUNGE_COOLDOWN := 3.0

## Base stats for stage 0 (Xiao Guai) and the 10 forms. Each family then biases them.
const HP := [5, 7, 9, 11, 14, 17, 21, 26, 32, 40, 50]
const BITE := [1, 1, 1, 2, 2, 2, 3, 3, 4, 5, 6]               ## damage per bite
const BITE_CD := [0.35, 0.33, 0.30, 0.30, 0.27, 0.25, 0.25, 0.22, 0.20, 0.18, 0.16]
const REACH := [30.0, 33.0, 36.0, 40.0, 44.0, 48.0, 53.0, 58.0, 63.0, 70.0, 78.0]
const SIZE := [1.0, 1.1, 1.25, 1.4, 1.55, 1.75, 1.95, 2.2, 2.5, 2.9, 3.3]
const SPEED_UP := [1.0, 1.03, 1.06, 1.09, 1.12, 1.15, 1.18, 1.2, 1.23, 1.25, 1.28]

## One dictionary per stage. Keys: name, hp, speed, bite, cd, range, scale, zoom, body, light.
var stages: Array = []
var line := -1                 ## chosen at the first evolution
var needs_line := false        ## level 3 reached but no line picked yet
var level := 1
var xp := 0
var stage := 0
var skills := {}               ## skill id -> rank
var skill_cd := {}             ## active skill id -> seconds left
var slow_left := 0.0           ## hit by a mud ball
var level_flash := 0.0         ## a ring that pops out on every level-up
var specials := {}             ## special skills picked every 12 levels: id -> true
var phoenix_used := false
var wind_cd := 0.0             ## Second Wind cooldown
var ab_cd := {}                ## signature ability cooldowns
var still_time := 0.0          ## seconds spent standing still (Rooted, Nature regeneration)
var trait_t := 0.0
var regen_acc := 0.0
var kill_heal_acc := 0.0       ## fractions of HP from Soul Drain
var bite_heal_acc := 0.0       ## fractions of HP from bite lifesteal
var ghosts: Array = []         # afterimages while sprinting or rolling: {pos, flip, frame, age}
var _ghost_t := 0.0
var _dust_t := 0.0
var buffs := {}               ## timed treasure buffs: id -> seconds left
var relics := {}              ## permanent treasure relics: id -> how many       ## fractions of HP from form-skill regeneration
var nature_t := 0.0
var trail_t := 0.0
var mist_t := 0.0
var spark_chance := 0.15       ## Dragon family: chance that a bite also sparks onto a second villager
var max_hp := 5
var hp := 5
var body_radius := 8.0
var facing := Vector2.DOWN
var move_target := Vector2.ZERO
var has_target := false
var bite_dir := Vector2.DOWN
var sprint_energy := SPRINT_MAX
var sprint_cd := 0.0
var sprinting := false
var roll_left := 0.0
var roll_cd := 0.0
var roll_dir := Vector2.DOWN
var lunge_left := 0.0
var lunge_cd := 0.0
var lunge_dir := Vector2.DOWN
var lunge_hit: Array[int] = []
var bite_cd := 0.0
var bite_flash := 0.0
var invuln := 0.0
var knock := Vector2.ZERO
var circle := CircleShape2D.new()


func _init() -> void:
	_build_stages()


## He grows 4% bigger with every level inside a form (up to 16%), so you can see him grow.
func growth_scale() -> float:
	var into_form := (level - stage * EVOLVE_EVERY) if stage > 0 else (level - 1)
	return 1.0 + 0.025 * clampi(into_form, 0, EVOLVE_EVERY - 1)


## The EXP curve: total EXP to reach level l is xp_coef * (l - 1) ^ xp_pow, then the part above
## the middle level (50) is multiplied by xp_late_scale, so the first half is quick and the
## second half slow. xp_scale scales everything. The pacing simulation (tests/pacing_sim.gd)
## sets these to hit the target: the final form (level 100) around 15 to 16 minutes.
static var xp_coef := 0.8
static var xp_pow := 2.35
static var xp_scale := 1.0
static var xp_late_scale := 1.0
const MIDDLE_LEVEL := 50


## XP needed in total to reach level l.
static func xp_for_level(l: int) -> int:
	if l <= 1:
		return 0
	var cost := xp_coef * pow(l - 1, xp_pow) * xp_scale
	if l > MIDDLE_LEVEL:
		var at_middle := xp_coef * pow(MIDDLE_LEVEL - 1, xp_pow) * xp_scale
		cost = at_middle + (cost - at_middle) * xp_late_scale
	return roundi(cost)


## The stage a level belongs to: Xiao Guai before level 10, then a new form every 10 levels.
static func stage_for_level(l: int) -> int:
	if l < EVOLVE_EVERY:
		return 0
	return mini(int(l / float(EVOLVE_EVERY)), LAST_STAGE)


func _stage_dict(i: int, stage_name: String, body: Color, hp_m: float, dmg_m: float, spd_m: float) -> Dictionary:
	return {
		"name": stage_name, "hp": roundi(HP[i] * hp_m), "speed": SPEED_UP[i] * spd_m,
		"bite": maxi(1, roundi(BITE[i] * dmg_m)), "cd": BITE_CD[i], "range": REACH[i],
		"scale": SIZE[i], "zoom": 2.0 - 0.085 * i, "body": body, "light": body.lightened(0.25),
	}


func _build_stages() -> void:
	stages = [_stage_dict(0, "Xiao Guai", Color("b02e4e"), 1.0, 1.0, 1.0)]
	if line < 0:
		return
	var l: Dictionary = LinesData.LINES[line]
	var fam: Dictionary = LinesData.FAMILIES[l["family"]]
	var hue: float = LinesData.hue_of(line)
	for f in 10:
		var body := Color.from_hsv(hue, 0.55, clampf(0.78 - 0.04 * f, 0.3, 0.9))
		stages.append(_stage_dict(f + 1, l["forms"][f], body, fam["hp"], fam["dmg"], fam["spd"]))


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	add_to_group("player")
	_apply_stage(false)


func rank(id: String) -> int:
	return int(skills.get(id, 0))


func _apply_stage(heal: bool) -> void:
	var s: Dictionary = stages[stage]
	max_hp = roundi(int(s["hp"]) * (1.0 + 0.2 * rank("hide") + form_mod("hp")) * (1.5 if specials.has("ironwill") else 1.0))
	body_radius = 8.0 * s["scale"]
	circle.radius = body_radius
	if heal:
		hp = max_hp
		hp_changed.emit(hp)
	else:
		hp = mini(hp, max_hp)


## EXP comes from every bite landed and every villager defeated.
func add_xp(amount: int) -> void:
	xp += amount
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
		level_flash = 0.8
		SkillFx.spawn_levelup(self)
		Popups.text(get_tree(), global_position + Vector2(0, -34.0), "LEVEL UP!", Popups.HEAL, 16)
		hp = mini(max_hp, hp + roundi(max_hp * 0.2))
		hp_changed.emit(hp)
		leveled.emit(level)
		_check_evolution()
	xp_changed.emit()


func _check_evolution() -> void:
	var want := stage_for_level(level)
	if want <= stage:
		return
	if line < 0:
		if not needs_line:
			needs_line = true
			line_needed.emit()
		return
	stage = want
	_apply_stage(true)
	invuln = 1.5
	if stage == LAST_STAGE:
		learn("doom")  # the final form earns the strongest skill
	evolved.emit(stage)


## The first evolution: pick one of the 26 lines. Later evolutions follow it.
func choose_line(i: int) -> void:
	line = clampi(i, 0, LinesData.LINES.size() - 1)
	needs_line = false
	_build_stages()
	_check_evolution()


## Learn a skill or raise its rank.
func learn(id: String) -> void:
	if SkillsData.info(id).is_empty():
		return
	var old_max := max_hp
	skills[id] = mini(rank(id) + 1, int(SkillsData.info(id)["max"]))
	SkillSounds.play(get_tree(), id, -9.0)
	if SkillsData.info(id).get("auto", false) and not skill_cd.has(id):
		skill_cd[id] = 0.0
	if id == "hide" or SkillsData.info(id).get("mods", {}).has("hp"):
		_apply_stage(false)
		hp += max_hp - old_max
		hp_changed.emit(hp)


## Take a special skill (the 12th-level pick). One of each, never twice.
func learn_special(id: String) -> void:
	if not SkillsData.SPECIALS.has(id) or specials.has(id):
		return
	specials[id] = true
	SkillSounds.play(get_tree(), id, -3.0)
	var sp_col: Color = SPECIAL_COLORS.get(id, Color.WHITE)
	match id:
		"ironwill":
			SkillFx.spawn_fx(self, Vector2.ZERO, "guard")
		"bonehoard":
			SkillFx.spawn_fx(self, Vector2(0, -6), "coins")
		"mastery":
			SkillFx.spawn_levelup(self)
		_:
			SkillFx.spawn_fx(self, Vector2.ZERO, "pick", sp_col)
	if id == "ironwill":
		_apply_stage(false)
		hp = mini(max_hp, hp + roundi(max_hp * 0.5))
		hp_changed.emit(hp)
	elif id == "mastery":
		for sid in skills.keys():
			skills[sid] = mini(int(skills[sid]) + 1, int(SkillsData.info(sid)["max"]))
		_apply_stage(false)
		hp_changed.emit(hp)


## Called when a villager 小怪 fought is defeated (not a tower kill).
func on_kill() -> void:
	var drain := rank("drain")
	if drain > 0 and hp > 0:
		kill_heal_acc += 0.5 * drain
		var whole := int(kill_heal_acc)
		if whole > 0:
			kill_heal_acc -= whole
			hp = mini(max_hp, hp + whole)
			hp_changed.emit(hp)
			Popups.text(get_tree(), global_position + Vector2(0, -22.0), "+%d" % whole, Popups.HEAL, 13)


func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	bite_cd = maxf(bite_cd - delta, 0.0)
	bite_flash = maxf(bite_flash - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	roll_cd = maxf(roll_cd - delta, 0.0)
	lunge_cd = maxf(lunge_cd - delta, 0.0)
	slow_left = maxf(slow_left - delta, 0.0)
	level_flash = maxf(level_flash - delta, 0.0)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)

	# The mouse aims in any direction. Left-click walks to that spot; hold it to follow
	# the cursor. WASD works too and cancels a click target.
	var touch: bool = bool(get_parent().get("touch_mode"))
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0 and not touch:
		facing = to_mouse.normalized()

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch and dir != Vector2.ZERO:
		facing = dir.normalized()
	if dir != Vector2.ZERO:
		has_target = false
	elif touch:
		has_target = false
	elif Input.is_action_pressed("move_mouse") and get_viewport().gui_get_hovered_control() == null and not bool(get_parent().get("remove_armed")):
		move_target = get_global_mouse_position()
		has_target = true
	if dir == Vector2.ZERO and has_target:
		var to_target := move_target - global_position
		if to_target.length() > 6.0:
			dir = to_target.normalized()
		else:
			has_target = false

	var busy := roll_left > 0.0 or lunge_left > 0.0
	if Input.is_action_just_pressed("dodge") and roll_cd == 0.0 and not busy:
		roll_dir = dir.normalized() if dir != Vector2.ZERO else facing
		roll_left = ROLL_TIME
		roll_cd = ROLL_COOLDOWN
		invuln = maxf(invuln, ROLL_INVULN)
		Sfx.play(get_tree(), "roll")
	elif Input.is_action_just_pressed("lunge") and lunge_cd == 0.0 and not busy:
		if touch:
			var near = _nearest_enemy_to(260.0)
			if near != null:
				facing = (near.global_position - global_position).normalized()
		lunge_dir = facing
		lunge_left = LUNGE_TIME
		lunge_cd = LUNGE_COOLDOWN
		lunge_hit.clear()
		Sfx.play(get_tree(), "lunge")

	_update_sprint(delta, dir != Vector2.ZERO)
	var speed_mult: float = stages[stage]["speed"] * (1.0 + (_power() - 1.0) * 0.4)
	speed_mult *= 1.0 + 0.08 * rank("paws")
	speed_mult *= trait_speed()
	if slow_left > 0.0:
		speed_mult *= 0.5
	if roll_left > 0.0:
		roll_left -= delta
		velocity = roll_dir * ROLL_SPEED * speed_mult
	elif lunge_left > 0.0:
		lunge_left -= delta
		velocity = lunge_dir * LUNGE_SPEED * speed_mult
		_lunge_strike()
	else:
		velocity = dir * SPEED * speed_mult * (SPRINT_MULT if sprinting else 1.0) * _terrain_mult()
	velocity += knock
	move_and_slide()

	if dir == Vector2.ZERO and not busy and knock.length() < 10.0:
		still_time += delta
	else:
		still_time = 0.0

	if bite_cd == 0.0:
		_auto_bite()
	_update_skills(delta)
	_juice_tick(delta)
	_update_ability(delta)

	modulate.a = 0.4 if invuln > 0.0 and roll_left == 0.0 and int(invuln * 20.0) % 2 == 0 else 1.0
	queue_redraw()


## Nights make him stronger (the level decides how much): bite damage and speed.
func _power() -> float:
	var level_node = get_parent()
	var p := 1.0
	if level_node.has_method("player_power"):
		p = level_node.player_power()
	if specials.has("bloodmoon"):
		p = maxf(p, 1.5)  # Blood Moon: night strength all day
	return p


func effective_bite() -> int:
	var overdrive := 1.4 if specials.has("overdrive") else 1.0
	return ceili(int(stages[stage]["bite"]) * _power() * (1.0 + 0.25 * rank("fangs") + form_mod("bite") + (form_mod("night_bite") if _night() else 0.0)) * overdrive)


## Mud and other terrain can slow him down; the level decides.
func _terrain_mult() -> float:
	var level_node = get_parent()
	if level_node.has_method("speed_mult_at"):
		return level_node.speed_mult_at(global_position)
	return 1.0


## Hold Shift to sprint. 10 s of sprint, then a 15 s cooldown before it refills.
## Releasing early recharges slowly (the same rate: empty to full in 15 s).
## The closest enemy within reach, for the touch controls' auto-aimed lunge.
func _nearest_enemy_to(reach: float):
	var best = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _update_sprint(delta: float, moving: bool) -> void:
	if sprint_cd > 0.0:
		sprint_cd = maxf(sprint_cd - delta, 0.0)
		sprinting = false
		if sprint_cd == 0.0:
			sprint_energy = SPRINT_MAX
		return
	sprinting = Input.is_action_pressed("sprint") and moving
	if sprinting:
		sprint_energy -= delta
		if sprint_energy <= 0.0:
			sprint_energy = 0.0
			sprinting = false
			sprint_cd = SPRINT_COOLDOWN
	else:
		sprint_energy = minf(sprint_energy + delta * SPRINT_MAX / SPRINT_COOLDOWN, SPRINT_MAX)


## Right-click lunge: a fast forward charge that bites everything it touches once.
func _lunge_strike() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var id := e.get_instance_id()
		if id in lunge_hit:
			continue
		if e.global_position.distance_to(global_position) <= 14.0 + body_radius:
			lunge_hit.append(id)
			e.take_hit(effective_bite() * 2, lunge_dir)
			add_xp(1)


func _auto_bite() -> void:
	var s: Dictionary = stages[stage]
	var target = null
	var best: float = float(s["range"]) * (1.3 if specials.has("titan") else 1.0) * (1.0 + form_mod("reach"))
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(global_position)
		if d <= best:
			best = d
			target = e
	if target == null:
		return
	bite_cd = float(s["cd"]) * (1.0 - 0.1 * rank("jaws") - form_mod("jaws")) * (0.75 if specials.has("frenzy") else 1.0)
	bite_flash = 0.12
	bite_dir = (target.global_position - global_position).normalized()
	Sfx.play(get_tree(), "bite", -9.0)
	var bite := effective_bite()
	target.take_hit(bite, bite_dir)
	on_bite_landed(target, bite)
	SkillFx.spawn_tooth(get_parent(), target.global_position, bite_dir, maxf(0.8, float(s["scale"]) * 0.8))
	if specials.has("overdrive"):
		SkillFx.spawn_fx(get_parent(), target.global_position, "impact", Color.WHITE, bite_dir, 1.2)
		SkillSounds.play_at(get_tree(), "overdrive", target.global_position, -10.0)
	if specials.has("titan"):
		SkillFx.spawn_fx(get_parent(), global_position + bite_dir * 14.0, "slash", Color.WHITE, bite_dir, 1.6)
		SkillSounds.play_at(get_tree(), "titan", global_position, -12.0)
	if specials.has("frenzy"):
		SkillFx.spawn_fx(get_parent(), global_position, "frenzy", Color.WHITE, bite_dir, 1.0)
	add_xp(1)


# --- family traits and the line's signature ability ---

func family() -> String:
	return LinesData.LINES[line]["family"] if line >= 0 else ""


## {id, name, rank} of the signature ability unlocked right now, or {} (before form 3, or no
## ability built for this line yet).
func ability() -> Dictionary:
	if line < 0 or not AbilitiesData.ABILITIES.has(line):
		return {}
	var r := AbilitiesData.rank_for_stage(stage)
	if r == 0:
		return {}
	var a: Dictionary = AbilitiesData.ABILITIES[line]
	return {"id": a["id"], "name": a["name"], "rank": r}


func _night() -> bool:
	var level_node = get_parent()
	return level_node != null and level_node.has_method("is_night") and level_node.is_night()


## Speed bonuses and penalties from the family and the ability, added together.
func trait_speed() -> float:
	var bonus := 0.0
	if family() == "Beast":
		bonus += 0.25 if _night() else 0.10
	var ab := ability()
	if not ab.is_empty():
		if ab["id"] == "pack_howl" and _night():
			bonus += 0.40
		if ab["id"] == "stone_skin":
			bonus -= 0.10
	return 1.0 + bonus + form_mod("speed")


## Material shells and Stone Skin take damage off every hit (never below 1).
func reduce_damage(dmg: int) -> int:
	var cut := 0
	if family() == "Material":
		cut += 1
	var ab := ability()
	if not ab.is_empty() and ab["id"] == "stone_skin":
		cut += 1 + int(ab["rank"])  # 2, 3, 4
	cut += roundi(form_mod("cut"))
	return maxi(1, dmg - cut)


func _nearest_enemy(radius: float):
	var best = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _slime_blob(taken: int) -> void:
	var foe = _nearest_enemy(300.0)
	if foe == null:
		return
	var b = BoltScript.new()
	b.position = global_position
	b.dir = (foe.global_position - global_position).normalized()
	b.speed = 260.0
	b.damage = maxi(1, ceili(taken * 0.2))
	b.team = "player"
	b.color = Color("7ad0ff")
	b.source = self
	_add_to_level(b)


func _spawn_helper(kind: String, life: float, dmg: int) -> void:
	var h = HelperScript.new()
	h.kind = kind
	h.life = life
	h.damage = dmg
	h.position = global_position + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0))
	_add_to_level(h)


## Called after every bite: lifesteal, bleeding bites and the Dragon spark.
func on_bite_landed(target, dmg: int) -> void:
	_form_on_bite(target, dmg)
	if specials.has("cleave"):
		var extra := 0
		for e in _enemies_within(float(stages[stage]["range"]) * (1.3 if specials.has("titan") else 1.0)):
			if e != target and is_instance_valid(e) and not e.is_queued_for_deletion() and extra < 2:
				extra += 1
				e.take_hit(dmg, (e.global_position - global_position).normalized())
				SkillFx.spawn_fx(get_parent(), e.global_position, "slash", Color.WHITE, (e.global_position - global_position).normalized(), 1.0)
				SkillSounds.play_at(get_tree(), "cleave", e.global_position, -6.0)
	var ab := ability()
	if not ab.is_empty() and ab["id"] == "blood_drain":
		var frac: float = [0.06, 0.09, 0.12][int(ab["rank"]) - 1]
		var healed := maxi(1, roundi(dmg * frac * 0.7))
		hp = mini(max_hp, hp + healed)
		hp_changed.emit(hp)
		Popups.text(get_tree(), global_position + Vector2(0, -22.0), "+%d" % healed, Popups.HEAL, 13)
	if not ab.is_empty() and ab["id"] == "pack_howl" and _night() and is_instance_valid(target):
		target.apply_status("bleed", 4.0)
	if family() == "Dragon" and randf() < spark_chance:
		for e in _enemies_within(float(stages[stage]["range"]) + 40.0):
			if e != target and is_instance_valid(e) and not e.is_queued_for_deletion():
				e.take_hit(dmg, (e.global_position - global_position).normalized())
				break


## Blood Drain rank 3: a red mist makes every villager within 70 px bleed. Returns how many.
func crimson_mist() -> int:
	var caught := _enemies_within(70.0)
	for e in caught:
		e.apply_status("bleed", 3.0)
	return caught.size()


func _cd(id: String) -> float:
	return float(ab_cd.get(id, 0.0))


## A cone of fire at a villager: damage, a burn, and the picture of it.
func breathe(to: Vector2, spread: float, status: String) -> int:
	var dir := to.normalized()
	var vis = BreathScript.new()
	vis.position = global_position
	vis.dir = dir
	vis.spread = spread
	vis.length = 170.0
	_add_to_level(vis)
	var dmg := ceili(effective_bite() * 1.5)
	var hit := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var v: Vector2 = e.global_position - global_position
		if v.length() <= 170.0 and absf(dir.angle_to(v)) <= spread:
			e.take_hit(dmg, v.normalized())
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				e.apply_status(status, 4.0)
			add_xp(1)
			hit += 1
	Sfx.play(get_tree(), "roar", -6.0)
	return hit


func _drop_pool(rank_now: int) -> void:
	var p = PoolScript.new()
	p.position = global_position
	p.radius = 20.0
	p.life = [4.0, 6.0, 8.0][rank_now - 1]
	p.status = "burn"
	p.status_time = 3.0
	_add_to_level(p)


func _player_zone(pos: Vector2, rad: float, delay: float, dmg: int, color: Color, stun: float = 0.0, status: String = "") -> void:
	var z = ZoneScript.new()
	z.position = pos
	z.radius = rad
	z.delay = delay
	z.damage = dmg
	z.team = "player"
	z.color = color
	z.stun = stun
	z.status = status
	z.status_time = 3.0
	z.source = self
	_add_to_level(z)


func _update_ability(delta: float) -> void:
	for bid in buffs.keys():
		buffs[bid] = float(buffs[bid]) - delta
		if float(buffs[bid]) <= 0.0:
			buffs.erase(bid)
	for k in ab_cd.keys():
		ab_cd[k] = maxf(float(ab_cd[k]) - delta, 0.0)

	# special skills that work over time
	wind_cd = maxf(wind_cd - delta, 0.0)
	if specials.has("secondwind") and wind_cd == 0.0 and hp > 0 and hp < max_hp * 0.25:
		wind_cd = 90.0
		hp = mini(max_hp, hp + roundi(max_hp * 0.3))
		hp_changed.emit(hp)
		Popups.text(get_tree(), global_position + Vector2(0, -22.0), "Second Wind!", Popups.HEAL, 16)
		SkillFx.spawn_fx(self, Vector2.ZERO, "heal")
		SkillSounds.play(get_tree(), "secondwind", -2.0)
	if specials.has("gravity"):
		for e in _enemies_within(160.0):
			e.global_position = e.global_position.move_toward(global_position, 35.0 * delta)

	_form_regen(delta)

	# family traits, from form 1
	var fam := family()
	trait_t += delta
	if trait_t >= 1.7:
		trait_t -= 1.7
		if fam == "Undead" and _night() and hp < max_hp:
			hp += 1
			hp_changed.emit(hp)
	if fam == "Nature":
		if still_time >= 1.0:
			nature_t += delta
			if nature_t >= 4.5:
				nature_t = 0.0
				if hp < max_hp:
					hp += 1
					hp_changed.emit(hp)
		else:
			nature_t = 0.0

	var ab := ability()
	if ab.is_empty():
		return
	var r: int = ab["rank"]
	match ab["id"]:
		"blood_drain":
			if r >= 3:  # Crimson Mist
				mist_t += delta
				if mist_t >= 1.0:
					mist_t = 0.0
					crimson_mist()
		"bone_servants":
			if _cd("bone_servants") == 0.0 and _enemies_within(250.0).size() >= 3:
				ab_cd["bone_servants"] = 12.0
				for i in r + 1:  # 2, 3, 4
					_spawn_helper("skeleton", 10.0, maxi(1, roundi(effective_bite() * 0.5)))
				Sfx.play(get_tree(), "chime", -3.0)
		"molten_trail":
			if sprinting:
				trail_t += delta
				if trail_t >= 0.25:
					trail_t = 0.0
					_drop_pool(r)
		"fire_breath":
			if _cd("fire_breath") == 0.0:
				var near = _nearest_enemy(220.0)
				if near != null:
					ab_cd["fire_breath"] = [8.0, 6.0, 5.0][r - 1]
					breathe(near.global_position - global_position, 1.0 if r >= 3 else 0.5, "burn")
		"pack_howl":
			if r >= 3 and _night() and _cd("pack_howl") == 0.0 and not _enemies_within(300.0).is_empty():
				ab_cd["pack_howl"] = 20.0
				for i in 2:
					_spawn_helper("wolf", 12.0, maxi(1, roundi(effective_bite() * 0.6)))
		"rooted":
			if still_time >= 2.0 and _cd("rooted") == 0.0:
				var caught := _enemies_within(90.0 + 30.0 * r)  # 120, 150, 180
				if not caught.is_empty():
					ab_cd["rooted"] = 6.0
					for e in caught:
						e.apply_status("root", 2.0)
						e.hurt(1)
		"stone_skin":
			if r >= 3 and _cd("stone_skin") == 0.0 and not _enemies_within(150.0).is_empty():
				ab_cd["stone_skin"] = 12.0
				_player_zone(global_position, 110.0, 0.2, ceili(effective_bite() * 2.0), Color("a08060"), 1.0)
		"hellfire_rain":
			if _cd("hellfire_rain") == 0.0:
				var targets := _enemies_within(350.0)
				if not targets.is_empty():
					ab_cd["hellfire_rain"] = [10.0, 8.0, 6.0][r - 1]
					targets.shuffle()
					for i in mini(r + 2, targets.size()):  # 3, 4, 5 fireballs
						_player_zone(targets[i].global_position, 40.0, 0.8, ceili(effective_bite() * 2.0), Color(1.0, 0.4, 0.1), 0.0, "burn")


# --- auto skills: Bone Nova, Spirit Bolt, Roar trigger on their own; Shadow Step is a dodge ---

func _enemies_within(radius: float) -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= radius:
			out.append(e)
	return out


func _update_skills(delta: float) -> void:
	for id in skill_cd:
		skill_cd[id] = maxf(float(skill_cd[id]) - delta, 0.0)
	if skill_cd.get("nova", 1.0) == 0.0 and not _enemies_within(70.0 + 12.0 * rank("nova")).is_empty():
		cast("nova")
	if skill_cd.get("bolt", 1.0) == 0.0:
		var near := _enemies_within(260.0)
		if not near.is_empty():
			var nearest = near[0]
			for e in near:
				if e.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position):
					nearest = e
			cast("bolt", (nearest.global_position - global_position).normalized())
	if skill_cd.get("roar", 1.0) == 0.0:
		var surrounded := _enemies_within(110.0).size() >= 4
		var desperate := hp <= max_hp * 0.3 and not _enemies_within(150.0).is_empty()
		if surrounded or desperate:
			cast("roar")
	_update_form_autos()
	if skill_cd.get("doom", 1.0) == 0.0:
		if _enemies_within(320.0).size() >= 6 or (hp <= max_hp * 0.3 and _enemies_within(250.0).size() >= 2):
			cast("doom")


func _add_to_level(node: Node2D) -> void:
	get_parent().add_child.call_deferred(node)


## Fire an auto skill now (the triggers above call this). aim is the direction for Spirit
## Bolt; it defaults to where 小怪 faces. Returns false if it isn't learned or is cooling down.
func cast(id: String, aim: Vector2 = Vector2.ZERO) -> bool:
	if rank(id) == 0 or float(skill_cd.get(id, 0.0)) > 0.0:
		return false
	if SkillsData.form_skills().has(id):
		return _cast_form(id)
	var direction := aim if aim != Vector2.ZERO else facing
	var r := rank(id)
	var power := 1.0 + 0.3 * (r - 1)
	if SkillsData.form_skills().has(id):
		return _cast_form(id)
	match id:
		"nova":
			var z = ZoneScript.new()
			z.position = global_position
			z.radius = 90.0 + 12.0 * r
			z.delay = 0.0
			z.damage = ceili(effective_bite() * 3.0 * power)
			z.team = "player"
			z.color = Color("a070ff")
			z.style = "nova"
			z.dur = 0.6
			z.stun = 0.5
			z.source = self
			_add_to_level(z)
		"bolt":
			var b = BoltScript.new()
			b.position = global_position
			b.dir = direction
			b.speed = 380.0
			b.damage = ceili(effective_bite() * 3.0 * power)
			b.team = "player"
			b.color = Color("c9a0ff")
			b.style = "spirit"
			b.pierce = true
			b.life = 1.2
			b.radius = 7.0
			b.source = self
			_add_to_level(b)
		"step":
			blink(direction)
		"roar":
			var z = ZoneScript.new()
			z.position = global_position
			z.radius = 150.0 + 10.0 * r
			z.delay = 0.0
			z.damage = 0
			z.team = "player"
			z.color = Color("ff8040")
			z.style = "roar"
			z.dur = 0.55
			z.knock = 450.0
			z.stun = 1.2 + 0.3 * r
			z.source = self
			_add_to_level(z)
		"doom":
			var z = ZoneScript.new()
			z.position = global_position
			z.radius = 380.0
			z.delay = 0.6
			z.damage = ceili(effective_bite() * 10.0)
			z.team = "player"
			z.color = Color("ff2040")
			z.style = "doom"
			z.dur = 0.8
			z.knock = 500.0
			z.stun = 1.5
			z.source = self
			_add_to_level(z)
		_:
			return false
	skill_cd[id] = float(SkillsData.SKILLS[id]["cd"]) * (1.0 - 0.1 * (r - 1)) * (0.65 if specials.has("stormcaller") else 1.0)
	if specials.has("stormcaller"):
		SkillFx.spawn_fx(self, Vector2.ZERO, "spark")
		SkillSounds.play(get_tree(), "stormcaller", -10.0)
	Juice.cast_burst(get_parent(), global_position, _skill_color(id))
	Sfx.play(get_tree(), "dodge" if id == "step" else id)  # sounds are named nova, bolt, roar, doom
	return true


## Jump up to 80 px in a direction (stops at trees and structures) and be untouchable briefly.
func blink(direction: Vector2) -> void:
	var level_node = get_parent()
	var pos := global_position
	var travelled := 0.0
	while travelled < 80.0 + 10.0 * rank("step"):
		var next := pos + direction.normalized() * 8.0
		if level_node.has_method("is_solid_at") and level_node.is_solid_at(next):
			break
		pos = next
		travelled += 8.0
	global_position = pos
	invuln = maxf(invuln, 0.4)


## Shadow Step: 10% per rank (up to 50%) to dodge a hit. It has a short cooldown.
func dodge_chance() -> float:
	return minf(0.1 * rank("step"), 0.5)


func take_hit(dmg: int, dir: Vector2) -> void:
	if invuln > 0.0 or hp <= 0:
		return
	if rank("step") > 0 and float(skill_cd.get("step", 0.0)) == 0.0 and randf() < dodge_chance():
		skill_cd["step"] = float(SkillsData.SKILLS["step"]["cd"])
		blink(-dir if dir != Vector2.ZERO else -facing)
		Sfx.play(get_tree(), "dodge")
		Popups.text(get_tree(), global_position + Vector2(0, -22.0), "Dodge!", Popups.HEAL, 16)
		return
	dmg = reduce_damage(dmg)
	hp -= dmg
	Popups.damage(get_tree(), global_position + Vector2(0, -22.0 * stages[stage]["scale"]), dmg, Popups.HURT)
	invuln = 0.8
	knock = dir * 220.0
	hp_changed.emit(hp)
	if hp <= 0 and specials.has("phoenix") and not phoenix_used:
		phoenix_used = true  # Phoenix: one comeback per run
		hp = roundi(max_hp * 0.4)
		invuln = 2.0
		hp_changed.emit(hp)
		_player_zone(global_position, 160.0, 0.0, ceili(effective_bite() * 5.0), Color("ff8a30"), 1.5)
		Popups.text(get_tree(), global_position + Vector2(0, -26.0), "Phoenix!", Popups.BIG, 20)
		SkillFx.spawn_fx(self, Vector2.ZERO, "phoenix")
		SkillSounds.play(get_tree(), "phoenix", -1.0)
		Sfx.play(get_tree(), "evolve")
		return
	Sfx.play(get_tree(), "death" if hp <= 0 else "hurt")
	if hp > 0 and family() == "Slime":
		_slime_blob(dmg)
	if hp <= 0:
		died.emit()
		queue_redraw()


func _draw() -> void:
	if hp <= 0:
		return
	var s: Dictionary = stages[stage]
	var sc: float = float(s["scale"]) * growth_scale()
	var body: Color = s["body"]
	var light: Color = s["light"]
	if lunge_left > 0.0:
		draw_line(-lunge_dir * 22.0 * sc, Vector2.ZERO, Color(1, 1, 1, 0.45), 7.0 * sc)
	var spin := 0.0
	if roll_left > 0.0:
		spin = (1.0 - roll_left / ROLL_TIME) * TAU
	draw_set_transform(Vector2.ZERO, spin, Vector2(sc, sc) * (0.85 if roll_left > 0.0 else 1.0))
	draw_circle(Vector2(0, 7), 7.0, Color(0, 0, 0, 0.25))
	if stage >= 10:
		draw_circle(Vector2.ZERO, 15.0, Color(0.9, 0.1, 0.2, 0.18))
	var art := ""
	if line >= 0:
		art = Sprites.hero(LinesData.LINES[line]["forms"], stage)
	elif stage == 0:
		art = "xiaoguai_base"
	if art != "":
		# afterimages trail behind while sprinting, rolling or lunging
		for g in ghosts:
			var ga: float = 1.0 - float(g["age"]) / 0.32
			draw_set_transform(g["pos"] - global_position, 0.0, Vector2(sc, sc))
			Sprites.draw(self, art, int(g["frame"]), 22.0, bool(g["flip"]), Color(0.55, 0.85, 1.0, 0.38 * ga))
		if not ghosts.is_empty():
			draw_set_transform(Vector2.ZERO, spin, Vector2(sc, sc) * (0.85 if roll_left > 0.0 else 1.0))
	if art != "" and Sprites.draw(self, art, int(Time.get_ticks_msec() / 500.0) % 2, 22.0, facing.x < -0.2, Color(2, 2, 2) if bite_flash > 0.0 else Color.WHITE, Vector2i(roundi(clampf(facing.x * 2.0, -1.0, 1.0)), roundi(clampf(facing.y * 2.0, -1.0, 1.0))), (Time.get_ticks_msec() * 0.016) if velocity.length() > 12.0 else -1.0):
		pass
	else:
		# from the 9th form on he wears a cape
		if stage >= 9:
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(10, -2), Vector2(14, 13), Vector2(-14, 13)]), body.darkened(0.6))
		# body
		draw_circle(Vector2.ZERO, 9.0, body)
		draw_circle(Vector2(-2, -3), 4.0, light)
		# horns
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(-3, -6), Vector2(-6, -12)]), Color("f2e6c9"))
		draw_colored_polygon(PackedVector2Array([Vector2(6, -6), Vector2(3, -6), Vector2(6, -12)]), Color("f2e6c9"))
		# eyes look where he faces; red from the 5th form on
		var look := facing * 1.5
		var eye := Color("ff3030") if stage >= 5 else Color.WHITE
		var pupil := Color.WHITE if stage >= 5 else Color.BLACK
		draw_circle(Vector2(-3, -1) + look, 2.2, eye)
		draw_circle(Vector2(3, -1) + look, 2.2, eye)
		draw_circle(Vector2(-3, -1) + look * 1.6, 1.0, pupil)
		draw_circle(Vector2(3, -1) + look * 1.6, 1.0, pupil)
		# fangs from the 6th form on
		if stage >= 6:
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 4), Vector2(-1, 4), Vector2(-2, 7)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(1, 4), Vector2(3, 4), Vector2(2, 7)]), Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Juice.draw_family_aura(self, family(), velocity.length() > 20.0)
	if not buffs.is_empty():
		Juice.draw_buff_aura(self, buffs, facing)
	if specials.has("gravity"):
		SkillFx.draw_gravity(self, Time.get_ticks_msec() * 0.001, 160.0)
	if specials.has("bloodmoon"):
		SkillFx.draw_bloodmoon(self, Time.get_ticks_msec() * 0.001)
	if slow_left > 0.0:
		draw_arc(Vector2.ZERO, 12.0 * sc, 0.0, TAU, 16, Color("7d5e38"), 2.0)
	if has_target:
		draw_arc(to_local(move_target), 6.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 1.5)
	if bite_flash > 0.0:
		draw_arc(bite_dir * 16.0 * sc, 12.0 * sc, bite_dir.angle() - 1.0, bite_dir.angle() + 1.0, 12, Color.WHITE, 2.5 * sc)


# --- form skills (skills.gd FORM_LIST): unlocked by the line and the form, picked at level-ups ---

## Sum of one modifier over every form skill owned, times its rank.
func form_mod(key: String) -> float:
	var total := 0.0
	for rid in relics:
		total += float(TreasureData.RELICS[rid]["mods"].get(key, 0.0)) * int(relics[rid])
	for bid in buffs:
		total += float(TreasureData.BUFFS[bid]["mods"].get(key, 0.0))
	var all := SkillsData.form_skills()
	for id in skills:
		if all.has(id) and all[id].get("mods", {}).has(key):
			total += float(all[id]["mods"][key]) * int(skills[id])
	return total


## On-bite statuses and healing from form skills.
func _form_on_bite(target, dmg: int) -> void:
	var all := SkillsData.form_skills()
	var drain := form_mod("drain")
	if drain > 0.0:
		bite_heal_acc += dmg * drain
		var healed := int(bite_heal_acc)
		if healed > 0:
			bite_heal_acc -= healed
			hp = mini(max_hp, hp + healed)
			hp_changed.emit(hp)
	for id in skills:
		if not all.has(id) or not all[id].has("onbite") or not is_instance_valid(target):
			continue
		var ob: Dictionary = all[id]["onbite"]
		if randf() < float(ob["chance"]) * int(skills[id]):
			target.apply_status(ob["status"], float(ob["secs"]))
			SkillSounds.play_at(get_tree(), id, target.global_position)
			FxMark.spawn(get_parent(), target.global_position + Vector2(0, -10), "fx_proc_" + str(ob["status"]))


func _form_regen(delta: float) -> void:
	var per_sec := form_mod("regen")
	if per_sec <= 0.0 or hp >= max_hp:
		return
	regen_acc += per_sec * delta
	if regen_acc >= 1.0:
		var whole := int(regen_acc)
		regen_acc -= whole
		hp = mini(max_hp, hp + whole)
		hp_changed.emit(hp)


## Automatic form skills fire when a villager comes inside their blast radius.
func _update_form_autos() -> void:
	var all := SkillsData.form_skills()
	for id in skills:
		if all.has(id) and all[id].has("auto") and float(skill_cd.get(id, 0.0)) == 0.0:
			var a: Dictionary = all[id]["auto"]
			# volleys reach out to their radius; blasts wait until villagers are inside
			var trigger := float(a["radius"]) * (1.0 if a.get("volley", false) else 0.9)
			if not _enemies_within(trigger).is_empty():
				cast(id)


func _cast_form(id: String) -> bool:
	var a: Dictionary = SkillsData.form_skills()[id]["auto"]
	var r := rank(id)
	if a.get("volley", false):
		return _cast_volley(id, a, r)
	var z = ZoneScript.new()
	z.position = global_position
	z.radius = float(a["radius"]) * (1.0 + 0.1 * (r - 1))
	z.delay = 0.0
	z.damage = ceili(effective_bite() * float(a["mult"]) * (1.0 + 0.3 * (r - 1)))
	z.team = "player"
	z.color = Color(str(a["color"]))
	z.stun = float(a.get("stun", 0.0))
	z.status = str(a.get("status", ""))
	z.status_time = float(a.get("secs", 0.0))
	z.fx = str(a.get("fx", ""))
	z.source = self
	if a.has("style"):
		z.style = str(a["style"])
		z.dur = 0.65
	_add_to_level(z)
	skill_cd[id] = float(a["cd"]) * (1.0 - 0.1 * (r - 1)) * (0.65 if specials.has("stormcaller") else 1.0)
	if specials.has("stormcaller"):
		SkillFx.spawn_fx(self, Vector2.ZERO, "spark")
	Juice.cast_burst(get_parent(), global_position, _skill_color(id))
	SkillSounds.play(get_tree(), id)
	return true


## Volley skills: shots + rank - 1 bolts, each at a different near villager when there are several.
func _cast_volley(id: String, a: Dictionary, r: int) -> bool:
	var near := _enemies_within(float(a["radius"]))
	if near.is_empty():
		return false
	near.sort_custom(func(x, y): return x.global_position.distance_to(global_position) < y.global_position.distance_to(global_position))
	var count := int(a["shots"]) + r - 1
	for i in count:
		var target = near[i % near.size()]
		var fan := 0.0 if near.size() > 1 else (float(i) - float(count - 1) * 0.5) * 0.18
		var aim: Vector2 = (target.global_position - global_position).normalized().rotated(fan)
		var b = BoltScript.new()
		b.position = global_position + aim * 10.0
		b.dir = aim
		b.speed = 330.0
		b.damage = ceili(effective_bite() * float(a["mult"]) * (1.0 + 0.2 * (r - 1)))
		b.team = "player"
		b.color = Color(str(a["color"]))
		b.style = str(a["style"])
		b.pierce = b.style == "spear" or b.style == "claw"
		b.life = float(a["radius"]) / 330.0 + 0.25
		b.radius = 6.0
		b.status = str(a.get("status", ""))
		b.status_time = float(a.get("secs", 0.0))
		b.source = self
		_add_to_level(b)
	skill_cd[id] = float(a["cd"]) * (1.0 - 0.1 * (r - 1)) * (0.65 if specials.has("stormcaller") else 1.0)
	if specials.has("stormcaller"):
		SkillFx.spawn_fx(self, Vector2.ZERO, "spark")
	Juice.cast_burst(get_parent(), global_position, _skill_color(id))
	SkillSounds.play(get_tree(), id)
	return true


## A timed treasure buff (Rage, Swift, Mend, Ward). Picking the same one again refreshes it.
func add_buff(id: String, secs: float) -> void:
	if not TreasureData.BUFFS.has(id):
		return
	buffs[id] = maxf(float(buffs.get(id, 0.0)), secs)


## A permanent treasure relic; it stacks.
func add_relic(id: String) -> void:
	if not TreasureData.RELICS.has(id):
		return
	var old_max := max_hp
	relics[id] = mini(int(relics.get(id, 0)) + 1, TreasureData.MAX_RELIC)
	if TreasureData.RELICS[id]["mods"].has("hp"):
		_apply_stage(false)
		hp += max_hp - old_max
		hp_changed.emit(hp)


## The colour of a skill's light and sparks.
func _skill_color(id: String) -> Color:
	var info: Dictionary = SkillsData.info(id)
	if info.has("auto") and typeof(info["auto"]) == TYPE_DICTIONARY and info["auto"].has("color"):
		return Color(str(info["auto"]["color"]))
	match id:
		"nova":
			return Color("a070ff")
		"bolt":
			return Color("c9a0ff")
		"roar":
			return Color("ff8040")
		"step":
			return Color("60d0ff")
		"doom":
			return Color("ff2040")
	return Color("ffd080")


## Afterimages and dust, called every physics frame.
func _juice_tick(delta: float) -> void:
	var fast := sprinting or roll_left > 0.0 or lunge_left > 0.0
	for g in ghosts:
		g["age"] = float(g["age"]) + delta
	ghosts = ghosts.filter(func(g): return float(g["age"]) < 0.32)
	if fast:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.035
			ghosts.append({"pos": global_position, "flip": facing.x < -0.2, "frame": int(Time.get_ticks_msec() / 500.0) % 2, "age": 0.0})
	if velocity.length() > 40.0 and roll_left <= 0.0:
		_dust_t -= delta
		if _dust_t <= 0.0:
			_dust_t = 0.16 if not sprinting else 0.08
			var fam := family()
			var tint := Color(0.75, 0.68, 0.55)
			if fam == "Undead":
				tint = Color(0.5, 0.75, 0.6)
			elif fam == "Slime":
				tint = Color(0.5, 0.8, 1.0)
			elif fam == "Nature":
				tint = Color(0.5, 0.75, 0.4)
			Juice.dust(get_parent(), global_position + Vector2(0, 9.0), tint)

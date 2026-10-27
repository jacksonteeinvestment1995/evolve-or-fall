extends CharacterBody2D
## 小怪. He starts as a tiny Xiao Guai and levels up from EXP. Every level offers a skill
## to learn. Every 5 levels he evolves; the first evolution (level 5) lets you pick which
## of the 26 monster lines to follow, and each later evolution is the next form in it.
## Between evolutions he visibly grows a little with every level.

const LinesData := preload("res://lines.gd")
const SkillsData := preload("res://skills.gd")
const BoltScript := preload("res://bolt.gd")
const ZoneScript := preload("res://zone.gd")
const Sfx := preload("res://sfx.gd")

signal hp_changed(hp: int)
signal died
signal xp_changed
signal leveled(level: int)    ## a new level: time to pick a skill
signal line_needed            ## level 5 reached: pick the evolution line
signal evolved(stage: int)

const MAX_LEVEL := 50
const EVOLVE_EVERY := 5
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
	return 1.0 + 0.04 * clampi(into_form, 0, EVOLVE_EVERY - 1)


## XP needed in total to reach level l. The curve is gentle at the start (level 5 takes
## about a minute or two) and gets steep in the middle game: the last levels, and so the
## final form with its strongest skill, take far more than the first ones.
static func xp_for_level(l: int) -> int:
	if l <= 1:
		return 0
	return roundi(2.2 * pow(l - 1, 2.35))


## The stage a level belongs to: Xiao Guai before level 5, then a new form every 5 levels.
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
	stages = [_stage_dict(0, "Xiao Guai", Color("7a4fd0"), 1.0, 1.0, 1.0)]
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
	max_hp = roundi(int(s["hp"]) * (1.0 + 0.2 * rank("hide")))
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
		hp = mini(max_hp, hp + roundi(max_hp * 0.3))
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
	if not SkillsData.SKILLS.has(id):
		return
	var old_max := max_hp
	skills[id] = mini(rank(id) + 1, int(SkillsData.SKILLS[id]["max"]))
	if SkillsData.SKILLS[id].get("auto", false) and not skill_cd.has(id):
		skill_cd[id] = 0.0
	if id == "hide":
		_apply_stage(false)
		hp += max_hp - old_max
		hp_changed.emit(hp)


## Called when a villager 小怪 fought is defeated (not a tower kill).
func on_kill() -> void:
	var drain := rank("drain")
	if drain > 0 and hp > 0:
		hp = mini(max_hp, hp + drain)
		hp_changed.emit(hp)


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
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		facing = to_mouse.normalized()

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		has_target = false
	elif Input.is_action_pressed("move_mouse"):
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
		lunge_dir = facing
		lunge_left = LUNGE_TIME
		lunge_cd = LUNGE_COOLDOWN
		lunge_hit.clear()
		Sfx.play(get_tree(), "lunge")

	_update_sprint(delta, dir != Vector2.ZERO)
	var speed_mult: float = stages[stage]["speed"] * (1.0 + (_power() - 1.0) * 0.4)
	speed_mult *= 1.0 + 0.08 * rank("paws")
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

	if bite_cd == 0.0:
		_auto_bite()
	_update_skills(delta)

	modulate.a = 0.4 if invuln > 0.0 and roll_left == 0.0 and int(invuln * 20.0) % 2 == 0 else 1.0
	queue_redraw()


## Nights make him stronger (the level decides how much): bite damage and speed.
func _power() -> float:
	var level_node = get_parent()
	if level_node.has_method("player_power"):
		return level_node.player_power()
	return 1.0


func effective_bite() -> int:
	return ceili(int(stages[stage]["bite"]) * _power() * (1.0 + 0.25 * rank("fangs")))


## Mud and other terrain can slow him down; the level decides.
func _terrain_mult() -> float:
	var level_node = get_parent()
	if level_node.has_method("speed_mult_at"):
		return level_node.speed_mult_at(global_position)
	return 1.0


## Hold Shift to sprint. 10 s of sprint, then a 15 s cooldown before it refills.
## Releasing early recharges slowly (the same rate: empty to full in 15 s).
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
	var best: float = s["range"]
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = e.global_position.distance_to(global_position)
		if d <= best:
			best = d
			target = e
	if target == null:
		return
	bite_cd = float(s["cd"]) * (1.0 - 0.1 * rank("jaws"))
	bite_flash = 0.12
	bite_dir = (target.global_position - global_position).normalized()
	Sfx.play(get_tree(), "bite", -9.0)
	target.take_hit(effective_bite(), bite_dir)
	add_xp(1)


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
	var direction := aim if aim != Vector2.ZERO else facing
	var r := rank(id)
	var power := 1.0 + 0.3 * (r - 1)
	match id:
		"nova":
			var z = ZoneScript.new()
			z.position = global_position
			z.radius = 90.0 + 12.0 * r
			z.delay = 0.0
			z.damage = ceili(effective_bite() * 3.0 * power)
			z.team = "player"
			z.color = Color("a070ff")
			z.stun = 0.5
			z.source = self
			_add_to_level(z)
		"bolt":
			var b = BoltScript.new()
			b.position = global_position
			b.dir = direction
			b.speed = 380.0
			b.damage = ceili(effective_bite() * 4.0 * power)
			b.team = "player"
			b.color = Color("c9a0ff")
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
			z.knock = 500.0
			z.stun = 1.5
			z.source = self
			_add_to_level(z)
		_:
			return false
	skill_cd[id] = float(SkillsData.SKILLS[id]["cd"]) * (1.0 - 0.1 * (r - 1))
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
		return
	hp -= dmg
	invuln = 0.8
	knock = dir * 220.0
	hp_changed.emit(hp)
	Sfx.play(get_tree(), "death" if hp <= 0 else "hurt")
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
	if level_flash > 0.0:
		draw_arc(Vector2.ZERO, (14.0 + (0.8 - level_flash) * 40.0) * sc, 0.0, TAU, 32, Color(1, 0.9, 0.4, level_flash), 3.0)
	if slow_left > 0.0:
		draw_arc(Vector2.ZERO, 12.0 * sc, 0.0, TAU, 16, Color("7d5e38"), 2.0)
	if has_target:
		draw_arc(to_local(move_target), 6.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 1.5)
	if bite_flash > 0.0:
		draw_arc(bite_dir * 16.0 * sc, 12.0 * sc, bite_dir.angle() - 1.0, bite_dir.angle() + 1.0, 12, Color.WHITE, 2.5 * sc)

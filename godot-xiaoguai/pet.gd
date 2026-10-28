extends CharacterBody2D
## A pet: a companion that hatches from an egg (merchant, gold chests) and stays for the whole run. It follows
## 小怪, bites villagers that come near, and gains a level for every few kills 小怪 makes. At level 3 it evolves, at
## level 5 it is fully grown. Up to MAX_PETS at once. Villagers ignore pets, and pet kills drop EXP stones.

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")

const MAX_PETS := 3
const MAX_LEVEL := 5
const EVOLVE_LEVEL := 3

const SPECIES := {
	"wolf": {"name": "Wolf Pup", "evo": "Dire Wolf", "speed": 135.0, "dmg": 1, "cd": 0.8, "color": Color("a8a8b8"), "eye": Color("ff5a5a")},
	"imp": {"name": "Bone Imp", "evo": "Bone Fiend", "speed": 105.0, "dmg": 2, "cd": 1.0, "color": Color("c8b4e8"), "eye": Color("ffe060")},
	"slime": {"name": "Pet Slime", "evo": "King Slime", "speed": 90.0, "dmg": 1, "cd": 0.7, "color": Color("6ad06a"), "eye": Color("103010"), "status": "slow"},
	"sprite": {"name": "Fire Sprite", "evo": "Phoenix Chick", "speed": 120.0, "dmg": 1, "cd": 0.9, "color": Color("ff9a30"), "eye": Color("fff0a0"), "status": "burn"},
}

var species := "wolf"
var level := 1
var kills_progress := 0
var slot := 0                 ## which of the pets this is, so they spread out around 小怪
var bite_cd := 0.0
var _t := randf() * TAU
var _flash := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2  # villagers and 小怪 walk through pets; pets still stop at trees
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	add_to_group("pets")
	z_index = 2


func info() -> Dictionary:
	return SPECIES[species]


func evolved() -> bool:
	return level >= EVOLVE_LEVEL


func form_name() -> String:
	return info()["evo"] if evolved() else info()["name"]


## Kills 小怪 needs to make for this pet to reach the next level.
func kills_needed() -> int:
	return 4 + 3 * level


func damage() -> int:
	var owner_level := 1
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null:
		owner_level = int(pl.level)
	return ceili(1.25 * (int(info()["dmg"]) + (level - 1) + int(owner_level / 10.0) + (2 if evolved() else 0)))  # villagers have 1.25x the health


## 小怪 made a kill: the pet learns from it.
func gain_xp(n: int = 1) -> void:
	if level >= MAX_LEVEL:
		return
	kills_progress += n
	while level < MAX_LEVEL and kills_progress >= kills_needed():
		kills_progress -= kills_needed()
		level += 1
		_flash = 1.0
		var text := "%s Lv %d" % [info()["name"], level]
		if level == EVOLVE_LEVEL:
			text = "%s evolved into %s!" % [info()["name"], info()["evo"]]
		Popups.text(get_tree(), global_position + Vector2(0, -20), text, Popups.BIG, 14)
		Sfx.play(get_tree(), "levelup", -6.0)
		SkillFx.spawn_levelup(self)
	if level >= MAX_LEVEL:
		kills_progress = 0


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	bite_cd = maxf(bite_cd - delta, 0.0)
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or pl.hp <= 0:
		velocity = Vector2.ZERO
		return
	var home: Vector2 = pl.global_position + Vector2.from_angle(float(slot) * 2.1 + _t * 0.15) * 34.0
	var spd: float = float(info()["speed"]) * (1.0 + 0.06 * (level - 1))
	# the nearest villager that is near both the pet and 小怪
	var target = null
	var best := 240.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best and e.global_position.distance_to(pl.global_position) < 360.0:
			best = d
			target = e
	var dir := Vector2.ZERO
	if target != null:
		dir = (target.global_position - global_position).normalized()
		if best < 16.0 + 2.0 * level and bite_cd == 0.0:
			bite_cd = float(info()["cd"]) * (1.0 - 0.06 * (level - 1))
			target.take_hit(damage(), dir, true)  # a pet's kill drops an EXP stone, not direct EXP
			if info().has("status") and is_instance_valid(target) and not target.is_queued_for_deletion():
				target.apply_status(info()["status"], 2.5)
	else:
		var to_home := home - global_position
		if to_home.length() > 12.0:
			dir = to_home.normalized() * minf(to_home.length() / 60.0, 1.0)
		if global_position.distance_to(pl.global_position) > 420.0:
			global_position = home  # lost it: catch up
			reset_physics_interpolation()
	velocity = dir * spd
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	var c: Color = info()["color"]
	var eye: Color = info()["eye"]
	var s := 1.0 + 0.12 * float(level - 1)
	var bob := sin(_t * 9.0) * 0.8 if velocity.length() > 10.0 else sin(_t * 2.0) * 0.4
	draw_circle(Vector2(0, 6 * s), 5.0 * s, Color(0, 0, 0, 0.25))
	if evolved():
		draw_circle(Vector2(0, bob), 10.0 * s, Color(c, 0.14 + 0.06 * sin(_t * 4.0)))
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(s, s))
	match species:
		"wolf":
			draw_circle(Vector2.ZERO, 5.5, c)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -3), Vector2(-3, -3), Vector2(-4, -9)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -3), Vector2(3, -3), Vector2(4, -9)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(-3, 3), Vector2(3, 3), Vector2(0, 7)]), c.darkened(0.15))
			if evolved():
				draw_line(Vector2(-5, 0), Vector2(-9, 3), c.lightened(0.2), 2.0)
		"imp":
			draw_circle(Vector2(0, -1), 5.0, c)
			draw_rect(Rect2(-3, 3, 6, 5), c.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -5), Vector2(-2, -5), Vector2(-4, -10)]), Color("e04040"))
			draw_colored_polygon(PackedVector2Array([Vector2(4, -5), Vector2(2, -5), Vector2(4, -10)]), Color("e04040"))
			if evolved():
				draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-12, -5), Vector2(-5, 3)]), Color("7a3aa0"))
				draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(12, -5), Vector2(5, 3)]), Color("7a3aa0"))
		"slime":
			draw_circle(Vector2(0, 1), 6.0, c)
			draw_circle(Vector2(0, 3), 6.5, c.darkened(0.1))
			draw_circle(Vector2(-2, -1), 1.8, Color(1, 1, 1, 0.5))
			if evolved():
				draw_colored_polygon(PackedVector2Array([Vector2(-5, -5), Vector2(-3, -9), Vector2(0, -6), Vector2(3, -9), Vector2(5, -5)]), Color("ffd84a"))
		"sprite":
			var f := 1.0 + 0.15 * sin(_t * 12.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -9 * f), Vector2(5, 0), Vector2(3, 6), Vector2(-3, 6), Vector2(-5, 0)]), c)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(2.5, 2), Vector2(1.5, 5), Vector2(-1.5, 5), Vector2(-2.5, 2)]), Color(1, 0.9, 0.5))
			if evolved():
				draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-11, -4), Vector2(-4, 3)]), Color("ffb030"))
				draw_colored_polygon(PackedVector2Array([Vector2(5, 0), Vector2(11, -4), Vector2(4, 3)]), Color("ffb030"))
	if species != "sprite":
		draw_circle(Vector2(-2, -1), 1.0, eye)
		draw_circle(Vector2(2, -1), 1.0, eye)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# level pips above the head, and a flash when it grows
	for i in level:
		draw_circle(Vector2((float(i) - float(level - 1) * 0.5) * 4.0, -13.0 * s), 1.3, Color("ffd84a"))
	if _flash > 0.0:
		draw_arc(Vector2.ZERO, 8.0 + (1.0 - _flash) * 16.0, 0, TAU, 20, Color(1, 0.9, 0.4, _flash), 2.0)

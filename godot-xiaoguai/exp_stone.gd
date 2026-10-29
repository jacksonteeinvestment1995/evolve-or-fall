extends Node2D
## An EXP stone. When a pet or a tower finishes a villager, its EXP drops here as a stone instead of
## going straight to 小怪: walk over it to take the EXP (it drifts toward you once you are close).

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")

const LIFETIME := 45.0
const PICKUP := 16.0
const MAGNET := 64.0           # the pull radius without the EXP Magnet skill
const MAGNET_PER_RANK := 90.0   # and what each rank of it adds

var value := 1
var age := 0.0
var bob_phase := 0.0


static func spawn(parent: Node, pos: Vector2, xp: int) -> void:
	if parent == null or xp <= 0:
		return
	# in a huge crowd the stones join up instead of piling into hundreds of nodes
	var near = null
	var stones: Array = parent.get_tree().get_nodes_in_group("exp_stones")
	if stones.size() > 90:
		var best := 140.0
		for st in stones:
			var d: float = st.global_position.distance_to(pos)
			if d < best:
				best = d
				near = st
	if near != null:
		near.value += xp
		near.age = 0.0
		return
	var s = load("res://exp_stone.gd").new()
	s.value = xp
	s.position = pos
	parent.call_deferred("add_child", s)


func _ready() -> void:
	add_to_group("exp_stones")
	bob_phase = randf() * TAU
	z_index = 2


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0:
		var d: float = pl.global_position.distance_to(global_position)
		var reach: float = MAGNET + MAGNET_PER_RANK * pl.rank("magnet")
		if d < reach:
			# the nearer, the faster; stones pulled from far away still arrive quickly
			global_position = global_position.move_toward(pl.global_position, (90.0 + (reach - d) * 3.0) * delta)
		if d < PICKUP + pl.body_radius * 0.5:
			_collect(pl)
			return
	queue_redraw()


func _collect(pl) -> void:
	var level_node = get_parent()
	var amount := value
	if level_node != null and level_node.has_method("catchup"):
		amount = roundi(value * level_node.catchup())
	pl.add_xp(amount)
	Sfx.play(get_tree(), "coin", -8.0)
	Popups.text(get_tree(), global_position + Vector2(0, -12), "+%d EXP" % amount, Popups.HEAL, 12)
	queue_free()


func _draw() -> void:
	if age > LIFETIME - 8.0 and int(age * 6.0) % 2 == 0:
		return
	var big := clampf(0.8 + float(value) * 0.04, 0.8, 1.8)
	var bob := sin(age * 4.0 + bob_phase) * 2.0
	var glow := 0.5 + 0.5 * sin(age * 5.0 + bob_phase)
	draw_circle(Vector2(0, 7), 5.0 * big, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(0, bob), 10.0 * big, Color(0.5, 0.9, 1.0, 0.12 + 0.1 * glow))
	var tex := Sprites.tex("icon_exp_orb")
	if tex != null:
		var fh := tex.get_height()
		var frame := int(age * 4.0) % maxi(1, tex.get_width() / fh)
		var sz := 14.0 * big
		draw_texture_rect_region(tex, Rect2(-sz * 0.5, bob - sz * 0.5, sz, sz), Rect2(frame * fh, 0, fh, fh))
	else:
		draw_circle(Vector2(0, bob), 4.0 * big, Color("8fd8ff"))

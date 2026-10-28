extends Node2D
## A rebel chicken (the chicken rebellion event). It runs at the nearest villager and pecks it; towers-style kills
## drop EXP stones. It stays near 小怪, and if 小怪 is hurt he can eat one he walks into for a snack.

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")

var age := 0.0
var retire := false
var _retire_t := 0.0
var _flee := Vector2.RIGHT
var _target = null
var _target_t := 0.0
var _peck_cd := 0.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _face := 1.0
var _step := randf() * TAU
var speed := 100.0


func _ready() -> void:
	add_to_group("chickens")
	z_index = 3
	_flee = Vector2.from_angle(randf() * TAU)


func leave() -> void:
	retire = true


func _physics_process(delta: float) -> void:
	age += delta
	_peck_cd = maxf(_peck_cd - delta, 0.0)
	var main = get_parent()
	var pl = get_tree().get_first_node_in_group("player")
	if retire:
		_retire_t += delta
		position += _flee * 140.0 * delta
		_face = 1.0 if _flee.x >= 0.0 else -1.0
		_step += delta * 18.0
		if _retire_t > 2.0:
			queue_free()
		queue_redraw()
		return
	# a hurt 小怪 can eat a chicken he walks into
	if pl != null and pl.hp > 0 and pl.hp < pl.max_hp * 0.6 and pl.global_position.distance_to(global_position) < 14.0 + pl.body_radius * 0.5:
		var heal := maxi(1, roundi(pl.max_hp * 0.08))
		pl.hp = mini(pl.max_hp, pl.hp + heal)
		pl.hp_changed.emit(pl.hp)
		pl.add_buff("swift", 8.0)
		Popups.text(get_tree(), global_position + Vector2(0, -16), "Cluck! +%d HP" % heal, Popups.HEAL, 13)
		Sfx.play(get_tree(), "coin", -6.0, 1.4)
		Juice.death(main, global_position, 0.6, Color(1, 0.95, 0.8))
		queue_free()
		return
	_target_t -= delta
	if _target_t <= 0.0:
		_target_t = 0.4
		_target = _nearest_enemy(420.0)
	var dir := Vector2.ZERO
	if is_instance_valid(_target):
		var to: Vector2 = _target.global_position - global_position
		if to.length() > 10.0:
			dir = to.normalized()
		elif _peck_cd <= 0.0:
			_peck_cd = 0.7
			var dmg := 1 + int((pl.level if pl != null else 1) / 8)
			_target.take_hit(dmg, to.normalized(), true)
			Sfx.play_at(get_tree(), "hit", global_position, -12.0, 1.6)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.0, 2.2)
			_wander = Vector2.from_angle(randf() * TAU) * 0.6
		dir = _wander
		if pl != null and pl.global_position.distance_to(global_position) > 260.0:
			dir = (pl.global_position - global_position).normalized()
	if dir != Vector2.ZERO:
		var next := global_position + dir * speed * delta
		if main.has_method("is_solid_at") and main.is_solid_at(next):
			_wander = _wander.rotated(PI * 0.6)
		else:
			position += dir * speed * delta
			_step += delta * 16.0
			if absf(dir.x) > 0.1:
				_face = 1.0 if dir.x > 0.0 else -1.0
	queue_redraw()


func _nearest_enemy(radius: float):
	var best = null
	var best_d := radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _draw() -> void:
	var f := _face
	var hop := absf(sin(_step)) * 1.5
	var peck := 1.0 if _peck_cd > 0.5 else 0.0
	var alpha := 1.0 - smoothstep(1.2, 2.0, _retire_t) if retire else 1.0
	draw_circle(Vector2(0, 6), 6.0, Color(0, 0, 0, 0.22 * alpha))
	# legs
	var l := sin(_step) * 2.0
	draw_line(Vector2(-1.5, 4 - hop), Vector2(-1.5 + l * 0.4, 7), Color(0.95, 0.6, 0.2, alpha), 1.4)
	draw_line(Vector2(1.5, 4 - hop), Vector2(1.5 - l * 0.4, 7), Color(0.95, 0.6, 0.2, alpha), 1.4)
	# body, tail and wing
	draw_colored_polygon(PackedVector2Array([Vector2(-f * 5.0, -1 - hop), Vector2(-f * 9.0, -6 - hop), Vector2(-f * 7.0, 1 - hop)]), Color(0.9, 0.9, 0.88, alpha))
	draw_circle(Vector2(0, -hop), 5.6, Color(1.0, 0.98, 0.94, alpha))
	draw_circle(Vector2(-f * 0.5, 0.8 - hop), 3.4, Color(0.88, 0.86, 0.8, alpha))
	# head, comb, beak, eye
	var head := Vector2(f * 4.2, -4.5 - hop + peck * 4.0)
	draw_circle(head, 3.2, Color(1.0, 0.98, 0.94, alpha))
	draw_circle(head + Vector2(-f * 0.4, -3.2), 1.4, Color(0.9, 0.2, 0.2, alpha))
	draw_circle(head + Vector2(f * 0.6, -3.0), 1.1, Color(0.9, 0.2, 0.2, alpha))
	draw_colored_polygon(PackedVector2Array([head + Vector2(f * 2.8, -0.5), head + Vector2(f * 5.6, 0.4), head + Vector2(f * 2.8, 1.4)]), Color(1.0, 0.7, 0.2, alpha))
	draw_circle(head + Vector2(f * 1.0, -0.8), 0.7, Color(0.1, 0.1, 0.1, alpha))
	# a little war scarf
	draw_line(head + Vector2(-f * 1.5, 2.6), head + Vector2(-f * 5.5, 3.6 + sin(_step) * 0.6), Color(0.9, 0.2, 0.25, alpha), 1.6)

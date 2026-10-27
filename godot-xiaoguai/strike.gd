extends Node2D
## One lightning strike: a crackling mark on the ground, then a jagged bolt from the clouds. It stuns and
## hurts everything near the spot. Towers draw the bolts (they take damage but zap nearby villagers).

const Sfx := preload("res://sfx.gd")

var warn := 0.9
var radius := 34.0
var damage := 4
var player_damage := 1
var age := 0.0
var struck := false
var _bolt: PackedVector2Array


func _ready() -> void:
	z_index = 4
	var r := RandomNumberGenerator.new()
	r.randomize()
	_bolt = PackedVector2Array([Vector2(r.randf_range(-12, 12), -300.0)])
	var y := -300.0
	while y < -8.0:
		y += r.randf_range(26.0, 46.0)
		_bolt.append(Vector2(r.randf_range(-14.0, 14.0) * (1.0 - clampf(-y / 300.0, 0.0, 1.0)), minf(y, 0.0)))


func _physics_process(delta: float) -> void:
	age += delta
	if not struck and age >= warn:
		_strike()
	if age >= warn + 0.5:
		queue_free()
		return
	queue_redraw()


func _strike() -> void:
	struck = true
	var main = get_parent()
	Sfx.play(get_tree(), "explosion", -5.0, 1.4)
	if main.has_method("shake"):
		main.shake(4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.global_position.distance_to(global_position) <= radius:
			e.stun_left = maxf(e.stun_left, 1.2)
			e.take_hit(damage, (e.global_position - global_position).normalized(), true)
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				e.apply_status("shock", 4.0)
	for s in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and s.global_position.distance_to(global_position) <= radius:
			s.take_hit(2, Vector2.ZERO)
			if s.is_in_group("towers"):
				_tower_zap(s)
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0 and pl.global_position.distance_to(global_position) <= radius + pl.body_radius * 0.5:
		pl.invuln = 0.0
		pl.take_hit(player_damage, (pl.global_position - global_position).normalized())


## A struck tower arcs the lightning on to villagers around it.
func _tower_zap(tower) -> void:
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if hits >= 4:
			break
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.global_position.distance_to(tower.global_position) <= 150.0:
			e.take_hit(damage, (e.global_position - tower.global_position).normalized(), true)
			hits += 1


func _draw() -> void:
	if not struck:
		var k := age / warn
		var pulse := 0.5 + 0.5 * sin(age * 30.0)
		# a crackling mark: short zigzag arcs around the spot, tightening as the strike nears
		for i in 6:
			var a := float(i) * TAU / 6.0 + age * 3.0
			var d := Vector2.from_angle(a)
			var n := d.rotated(PI * 0.5)
			var rr := radius * (1.0 - 0.3 * k)
			draw_polyline(PackedVector2Array([d * rr, d * rr * 0.8 + n * 5.0, d * rr * 0.6 - n * 4.0, d * rr * 0.4 + n * 3.0]), Color(0.8, 0.9, 1.0, 0.5 + 0.4 * pulse), 1.8)
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color(1, 1, 0.8, 0.9), 1.5)
		draw_line(Vector2(0, -5), Vector2(0, 5), Color(1, 1, 0.8, 0.9), 1.5)
		return
	var t := (age - warn) / 0.5
	var a2 := 1.0 - t
	draw_polyline(_bolt, Color(0.6, 0.75, 1.0, a2 * 0.6), 9.0)
	draw_polyline(_bolt, Color(1.0, 1.0, 1.0, a2), 3.5)
	draw_circle(Vector2.ZERO, radius * (0.4 + 0.5 * t), Color(0.85, 0.92, 1.0, 0.5 * a2))
	for i in 8:
		var d2 := Vector2.from_angle(float(i) * TAU / 8.0 + 0.3)
		draw_line(d2 * 6.0, d2 * (radius * (0.6 + t)), Color(1, 1, 0.9, a2), 1.6)

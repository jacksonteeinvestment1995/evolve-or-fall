extends Node2D
## One meteor: a warning mark on the ground, a flaming rock that falls from the sky, then the blast.
## The blast hurts villagers, buildings and 小怪 alike, sets them alight, and leaves a glowing crater.

const Sfx := preload("res://sfx.gd")

var warn := 1.3
var fall := 0.35
var radius := 40.0
var damage := 4
var player_damage := 1
var age := 0.0
var hit := false


func _ready() -> void:
	z_index = 3


func _physics_process(delta: float) -> void:
	age += delta
	if not hit and age >= warn + fall:
		_impact()
	if age >= warn + fall + 3.5:
		queue_free()
		return
	queue_redraw()


func _impact() -> void:
	hit = true
	var main = get_parent()
	Sfx.play(get_tree(), "explosion", -4.0)
	if main.has_method("shake"):
		main.shake(7.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.global_position.distance_to(global_position) <= radius:
			e.take_hit(damage, (e.global_position - global_position).normalized(), true)
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				e.apply_status("burn", 4.0)
	for s in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and s.global_position.distance_to(global_position) <= radius:
			s.take_hit(2, Vector2.ZERO)
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0 and pl.global_position.distance_to(global_position) <= radius + pl.body_radius * 0.5:
		pl.invuln = 0.0
		pl.take_hit(player_damage, (pl.global_position - global_position).normalized())


func _draw() -> void:
	if age < warn + fall:
		# the warning mark: spinning corner brackets and pulsing triangles pointing in
		var k := clampf(age / warn, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(age * 14.0)
		var rot := age * 1.6
		for i in 4:
			var a := rot + float(i) * PI * 0.5
			var d := Vector2.from_angle(a)
			var n := d.rotated(PI * 0.5)
			var base := d * radius
			draw_polyline(PackedVector2Array([base + n * 9.0 - d * 3.0, base, base - n * 9.0 - d * 3.0]), Color(1.0, 0.25 + 0.3 * pulse, 0.15, 0.9), 2.4)
			draw_colored_polygon(PackedVector2Array([d * (radius - 8.0) + n * 4.0, d * (radius * (0.45 + 0.2 * pulse)), d * (radius - 8.0) - n * 4.0]), Color(1.0, 0.3, 0.1, 0.35 + 0.4 * k))
		draw_line(Vector2(-6, 0), Vector2(6, 0), Color(1, 0.8, 0.5, 0.8), 1.5)
		draw_line(Vector2(0, -6), Vector2(0, 6), Color(1, 0.8, 0.5, 0.8), 1.5)
		if age > warn:
			# the rock itself, streaking in from the upper left
			var f := (age - warn) / fall
			var head := Vector2(-110.0, -260.0) * (1.0 - f)
			for i in 7:
				var tpos := head + Vector2(-110.0, -260.0).normalized() * float(i) * 14.0 * (1.0 - f * 0.5)
				draw_circle(tpos, 9.0 - float(i) * 1.1, Color(1.0, 0.5 - float(i) * 0.05, 0.1, 0.8 - float(i) * 0.1))
			draw_colored_polygon(PackedVector2Array([head + Vector2(-9, -5), head + Vector2(-2, -11), head + Vector2(9, -4), head + Vector2(8, 7), head + Vector2(-3, 10), head + Vector2(-10, 3)]), Color(0.45, 0.2, 0.12))
			draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -4), head + Vector2(3, -6), head + Vector2(5, 1), head + Vector2(-3, 3)]), Color(1.0, 0.7, 0.2))
		return
	var t := age - warn - fall
	var fade := 1.0 - smoothstep(1.5, 3.5, t)
	# the blast: a white core, shock rays and flying embers
	if t < 0.4:
		var b := t / 0.4
		draw_circle(Vector2.ZERO, radius * (0.7 - 0.4 * b), Color(1.0, 0.95, 0.7, 1.0 - b))
		for i in 10:
			var d := Vector2.from_angle(float(i) * TAU / 10.0 + 0.2)
			draw_colored_polygon(PackedVector2Array([d * 6.0 + d.rotated(PI * 0.5) * 3.0, d * (radius * (0.5 + 1.1 * b)), d * 6.0 - d.rotated(PI * 0.5) * 3.0]), Color(1.0, 0.55, 0.15, 1.0 - b))
		for i in 12:
			var d2 := Vector2.from_angle(float(i) * 0.53 + 1.0)
			var rr := radius * (0.4 + 1.2 * b) * (0.6 + 0.4 * fposmod(float(i) * 0.37, 1.0))
			draw_circle(d2 * rr + Vector2(0, b * b * 20.0), 2.0 * (1.0 - b), Color(1.0, 0.7, 0.2, 1.0 - b))
	# the crater with glowing cracks
	var pts := PackedVector2Array()
	for i in 14:
		var a := float(i) / 14.0 * TAU
		pts.append(Vector2.from_angle(a) * radius * 0.62 * (0.85 + 0.15 * sin(float(i) * 2.9)))
	draw_colored_polygon(pts, Color(0.12, 0.06, 0.04, 0.8 * fade))
	for i in 7:
		var d3 := Vector2.from_angle(float(i) * 0.9 + 0.3)
		draw_polyline(PackedVector2Array([d3 * 5.0, d3.rotated(0.2) * radius * 0.4, d3 * radius * 0.7]), Color(1.0, 0.45, 0.1, fade * (0.6 + 0.4 * sin(age * 8.0 + float(i)))), 1.6)

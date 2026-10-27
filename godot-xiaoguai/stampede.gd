extends Node2D
## A stampede: a herd of wild boars charges across the map in a wide band and tramples everything in its
## way (villagers, buildings and 小怪). A faint red lane shows where it will run.

const Sfx := preload("res://sfx.gd")

var heading := Vector2.RIGHT
var speed := 240.0
var band := 300.0
var length := 1500.0
var age := 0.0
var warn := 4.0
var _animals: Array = []   # [lane offset, lead offset, bob phase]
var _hit := {}


func _ready() -> void:
	z_index = 4
	var r := RandomNumberGenerator.new()
	r.randomize()
	for i in 16:
		_animals.append([r.randf_range(-band * 0.5, band * 0.5), r.randf_range(0.0, 140.0), r.randf() * TAU])


func _physics_process(delta: float) -> void:
	age += delta
	var run := maxf(age - warn, 0.0)
	if run > 0.0:
		for a in _animals:
			_trample(_pos_of(a, run))
	if run * speed > length + 200.0:
		queue_free()
		return
	queue_redraw()


## Where an animal is: the herd starts a screen away behind the lane and runs along the heading.
func _pos_of(a: Array, run: float) -> Vector2:
	var side := heading.rotated(PI * 0.5)
	return position - heading * (length * 0.5) + heading * (run * speed - float(a[1])) + side * float(a[0])


func _trample(pos: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and not _hit.has(e.get_instance_id()) and e.global_position.distance_to(pos) < 20.0:
			_hit[e.get_instance_id()] = true
			e.take_hit(8, heading, true)
			if is_instance_valid(e):
				e.knock = heading * 380.0
	for s in get_tree().get_nodes_in_group("structures"):
		if is_instance_valid(s) and not _hit.has(s.get_instance_id()) and s.global_position.distance_to(pos) < 22.0:
			_hit[s.get_instance_id()] = true
			s.take_hit(3, heading)
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0 and not _hit.has(pl.get_instance_id()) and pl.global_position.distance_to(pos) < 18.0 + pl.body_radius * 0.5:
		_hit[pl.get_instance_id()] = true
		pl.invuln = 0.0
		pl.take_hit(maxi(1, roundi(pl.max_hp * 0.15)), heading)


func _draw() -> void:
	var side := heading.rotated(PI * 0.5)
	var run := maxf(age - warn, 0.0)
	# the lane: a faint red strip with arrows pointing the way
	var lane_a := -heading * length * 0.5
	var lane_b := heading * length * 0.5
	if age < warn + 2.0:
		var a := 0.25 * (0.6 + 0.4 * sin(age * 8.0)) * (1.0 - smoothstep(warn, warn + 2.0, age))
		draw_colored_polygon(PackedVector2Array([lane_a - side * band * 0.5, lane_b - side * band * 0.5, lane_b + side * band * 0.5, lane_a + side * band * 0.5]), Color(1.0, 0.15, 0.1, a))
		for i in 7:
			var c := heading * (float(i) - 3.0) * 110.0 + heading * fposmod(age * 90.0, 110.0)
			draw_polyline(PackedVector2Array([c - heading * 12.0 + side * 12.0, c + heading * 6.0, c - heading * 12.0 - side * 12.0]), Color(1.0, 0.4, 0.3, a * 3.0), 2.5)
	# the herd
	if run > 0.0:
		for a2 in _animals:
			var p := _pos_of(a2, run) - position
			var bob := sin(run * 16.0 + float(a2[2])) * 2.0
			draw_circle(p + Vector2(0, 7), 8.0, Color(0, 0, 0, 0.25))
			for k in 3:
				draw_circle(p - heading * (8.0 + float(k) * 7.0) + Vector2(0, 8 + bob), 4.0 - float(k), Color(0.7, 0.6, 0.45, 0.35 - float(k) * 0.1))
			var dirx := 1.0 if heading.x >= 0.0 else -1.0
			draw_ellipse_like(p + Vector2(0, bob), dirx)


func draw_ellipse_like(p: Vector2, dirx: float) -> void:
	var body := PackedVector2Array()
	for i in 14:
		var a := float(i) / 14.0 * TAU
		body.append(p + Vector2(cos(a) * 11.0, sin(a) * 6.5))
	draw_colored_polygon(body, Color(0.42, 0.28, 0.2))
	draw_circle(p + Vector2(dirx * 10.0, -1), 4.5, Color(0.36, 0.23, 0.16))
	draw_colored_polygon(PackedVector2Array([p + Vector2(dirx * 13.0, 2), p + Vector2(dirx * 17.0, 4), p + Vector2(dirx * 12.0, 4)]), Color.WHITE)
	draw_circle(p + Vector2(dirx * 12.0, -2), 1.0, Color("ff3030"))
	for k in 4:
		draw_line(p + Vector2(-7.0 + float(k) * 4.5, 5), p + Vector2(-7.0 + float(k) * 4.5 + sin(Time.get_ticks_msec() * 0.03 + float(k)) * 2.0, 10), Color(0.25, 0.16, 0.1), 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(dirx * 7.0, -5), p + Vector2(dirx * 9.0, -9), p + Vector2(dirx * 10.0, -4)]), Color(0.3, 0.2, 0.14))

extends Node2D
## A UFO. It drifts over the village and beams villagers up, then drops them somewhere far away ("WHEEE!").
## Now and then it eyes 小怪 too: a beam appears over him with a warning, and if he is still there when it
## closes he is dropped somewhere else (nothing worse than a long walk back).

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")

var main: Node2D
var max_grabs := 6
var grabs := 0
var leaving := false
var age := 0.0
var _phase := "seek"      # seek, beam, leave
var _t := 0.0
var _target = null        # a villager, or the player
var _on_player := false
var _lift := 0.0
var _beam_len := 0.0


func _ready() -> void:
	z_index = 8
	add_to_group("ufos")


func leave() -> void:
	leaving = true
	_phase = "leave"


func _physics_process(delta: float) -> void:
	age += delta
	_t += delta
	var pl = get_tree().get_first_node_in_group("player")
	match _phase:
		"seek":
			if not is_instance_valid(_target) or _t > 8.0:
				_pick_target(pl)
			if is_instance_valid(_target):
				var to: Vector2 = _target.global_position - global_position
				position += to.limit_length(150.0 * delta)
				if to.length() < 8.0:
					_phase = "beam"
					_t = 0.0
					_lift = 0.0
					Sfx.play(get_tree(), "warn", -5.0, 0.8)
					if _on_player:
						Popups.text(get_tree(), global_position + Vector2(0, -34), "RUN!", Popups.BIG, 18)
			elif grabs >= max_grabs:
				leave()
		"beam":
			if not is_instance_valid(_target):
				_phase = "seek"
				_t = 0.0
			else:
				position = position.move_toward(_target.global_position, 40.0 * delta)
				if _on_player:
					# the player can step out of the beam before it closes
					if _t > 1.3:
						if pl.global_position.distance_to(global_position) < 24.0:
							_drop(pl)
						else:
							Popups.text(get_tree(), pl.global_position + Vector2(0, -26), "Missed!", Popups.HEAL, 14)
						_finish_grab()
				else:
					_target.stun_left = maxf(_target.stun_left, 0.5)
					_lift = minf(_lift + 30.0 * delta, 40.0)
					_target.global_position = global_position + Vector2(0, -_lift * 0.4)
					if _t > 2.0:
						_drop(_target)
						_finish_grab()
		"leave":
			position += Vector2(60.0, -140.0) * delta
			if _t > 3.0 and age > 4.0:
				queue_free()
	if _phase == "leave" and _t > 4.0:
		queue_free()
	queue_redraw()


func _pick_target(pl) -> void:
	_target = null
	_on_player = false
	_t = 0.0
	if grabs >= max_grabs:
		return
	if pl != null and pl.global_position.distance_to(global_position) < 140.0 and randf() < 0.12:
		_target = pl
		_on_player = true
		return
	var foes: Array = get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and not e.bug and not e.mimic and not e.rival)
	if foes.is_empty():
		return
	foes.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	_target = foes[randi() % mini(5, foes.size())]


func _finish_grab() -> void:
	grabs += 1
	_target = null
	_on_player = false
	_phase = "seek"
	_t = 0.0
	_lift = 0.0


## Drop whoever it caught somewhere far away.
func _drop(who) -> void:
	var pos := Vector2.INF
	for i in 20:
		var p: Vector2 = who.global_position + Vector2.from_angle(randf() * TAU) * randf_range(450.0, 800.0)
		var t: Vector2i = main.tile_of(p)
		if t.x < 3 or t.y < 3 or t.x > main.COLS - 4 or t.y > main.ROWS - 4 or main.trees.has(t) or main.water.has(t):
			continue
		pos = p
		break
	if pos == Vector2.INF:
		return
	Juice.light(main, who.global_position, Color(0.6, 1.0, 0.7), 1.4, 1.2, 0.4)
	who.global_position = pos
	Juice.light(main, pos, Color(0.6, 1.0, 0.7), 1.4, 1.2, 0.4)
	if who == get_tree().get_first_node_in_group("player"):
		who.invuln = maxf(who.invuln, 1.0)
		who.has_target = false
		Popups.text(get_tree(), pos + Vector2(0, -26), "Abducted!", Popups.BIG, 16)
		if main.cam != null:
			main.cam.global_position = pos
		main.shake(6.0)
	else:
		who.stun_left = 0.6
		if who.has_method("say"):
			who.say("WHEEEEE!", 2.0)


func _draw() -> void:
	var s := Vector2(0, -78.0 + sin(age * 2.0) * 3.0)
	# the beam
	if _phase == "beam":
		var k := 0.5 + 0.5 * sin(age * 16.0)
		var top := s + Vector2(0, 6)
		var a := 0.22 + 0.12 * k
		if _on_player and _t < 1.3:
			a = 0.12 + 0.2 * k   # the warning flicker
		draw_colored_polygon(PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0), Vector2(26, 6), Vector2(-26, 6)]), Color(0.6, 1.0, 0.7, a))
		for i in 6:
			var f := fposmod(age * 1.5 + float(i) * 0.17, 1.0)
			draw_circle(Vector2(sin(float(i) * 2.0 + age * 3.0) * 14.0 * (1.0 - f * 0.4), 4.0 - f * 80.0 + 0.0), 1.4, Color(0.9, 1.0, 0.8, 0.8 * (1.0 - f)))
	# the saucer: dome, metal rim, blinking lights
	draw_circle(Vector2(0, 6), 14.0, Color(0, 0, 0, 0.16))
	var dome := PackedVector2Array()
	for i in 11:
		var a2 := PI + float(i) / 10.0 * PI
		dome.append(s + Vector2(cos(a2) * 9.0, sin(a2) * 8.0 - 3.0))
	draw_colored_polygon(dome, Color(0.55, 0.85, 1.0, 0.75))
	draw_circle(s + Vector2(-3, -8), 1.6, Color(1, 1, 1, 0.8))
	var rim := PackedVector2Array()
	for i in 16:
		var a3 := float(i) / 16.0 * TAU
		rim.append(s + Vector2(cos(a3) * 18.0, sin(a3) * 5.5))
	draw_colored_polygon(rim, Color(0.7, 0.72, 0.8))
	draw_polyline(rim + PackedVector2Array([rim[0]]), Color(0.3, 0.32, 0.4), 1.5)
	for i in 5:
		var on := int(age * 6.0 + float(i)) % 3 == 0
		draw_circle(s + Vector2(-12.0 + float(i) * 6.0, 2.0 + 0.0), 1.5, Color(1.0, 0.9, 0.3) if on else Color(0.9, 0.3, 0.3))

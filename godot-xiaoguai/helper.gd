extends CharacterBody2D
## A helper that fights for 小怪 for a short while: Bone Servants raise skeletons, Pack Howl
## calls wolf pups. It walks to the nearest villager and bites it.

var life := 10.0
var damage := 1
var speed := 95.0
var kind := "skeleton"   ## "skeleton" or "wolf"
var bite_cd := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2  # villagers and 小怪 walk through helpers; helpers still stop at trees
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	add_to_group("allies")


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	bite_cd = maxf(bite_cd - delta, 0.0)
	var target = null
	var best := 500.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = e
	var dir := Vector2.ZERO
	if target != null:
		dir = (target.global_position - global_position).normalized()
		if best < 16.0 and bite_cd == 0.0:
			bite_cd = 0.8
			target.take_hit(damage, dir)
	velocity = dir * speed
	move_and_slide()
	queue_redraw()


func _draw() -> void:
	var fade := clampf(life / 1.5, 0.0, 1.0)
	draw_circle(Vector2(0, 5), 5.0, Color(0, 0, 0, 0.25 * fade))
	if kind == "wolf":
		draw_circle(Vector2.ZERO, 5.5, Color(0.62, 0.62, 0.7, fade))
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -3), Vector2(-3, -3), Vector2(-4, -9)]), Color(0.62, 0.62, 0.7, fade))
		draw_colored_polygon(PackedVector2Array([Vector2(5, -3), Vector2(3, -3), Vector2(4, -9)]), Color(0.62, 0.62, 0.7, fade))
		draw_circle(Vector2(-2, -1), 1.0, Color(1, 0.3, 0.3, fade))
		draw_circle(Vector2(2, -1), 1.0, Color(1, 0.3, 0.3, fade))
	else:
		draw_circle(Vector2(0, -1), 5.0, Color(0.93, 0.9, 0.8, fade))
		draw_rect(Rect2(-3, 3, 6, 5), Color(0.85, 0.82, 0.72, fade))
		draw_circle(Vector2(-2, -2), 1.3, Color(0.1, 0.05, 0.15, fade))
		draw_circle(Vector2(2, -2), 1.3, Color(0.1, 0.05, 0.15, fade))

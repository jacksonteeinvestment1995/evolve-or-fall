extends Node2D
## A patch on the ground that puts a status on every villager standing in it
## (Molten Trail leaves burning goo).

var radius := 20.0
var life := 5.0
var status := "burn"
var status_time := 3.0
var damage := 0
var tick := 0.4
var color := Color(1.0, 0.5, 0.1)
var _t := 0.0


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_t += delta
	if _t >= tick:
		_t = 0.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) <= radius:
				if damage > 0:
					e.hurt(damage)
				e.apply_status(status, status_time)
	queue_redraw()


func _draw() -> void:
	var a := clampf(life / 1.0, 0.0, 1.0) * 0.6
	draw_circle(Vector2.ZERO, radius, Color(color, a * 0.6))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(color.lightened(0.3), a), 2.0)

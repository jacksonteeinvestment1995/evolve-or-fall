extends Node2D
## The placement preview under the mouse: green where you can build, red where you can't.

var valid := true
var reach := 0.0  ## a tower's shooting range, drawn as a ring


func _draw() -> void:
	var c := Color(0.3, 1.0, 0.4) if valid else Color(1.0, 0.3, 0.3)
	draw_rect(Rect2(-16, -16, 32, 32), Color(c, 0.35))
	draw_rect(Rect2(-16, -16, 32, 32), Color(c, 0.9), false, 2.0)
	if reach > 0.0:
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(c, 0.6), 1.5)

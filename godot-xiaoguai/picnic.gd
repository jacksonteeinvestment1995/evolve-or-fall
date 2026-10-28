extends Node2D
## The picnic blanket the villagers sit around: a red and white cloth, a basket, sandwiches and a thermos.

var life := 36.0
var age := 0.0


func _ready() -> void:
	z_index = 0


func _physics_process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - smoothstep(life - 3.0, life, age)
	var w := 96.0
	var h := 64.0
	draw_rect(Rect2(-w * 0.5 + 3, -h * 0.5 + 4, w, h), Color(0, 0, 0, 0.18 * a))
	for iy in 8:
		for ix in 12:
			var c := Color(0.85, 0.15, 0.2, a) if (ix + iy) % 2 == 0 else Color(0.97, 0.94, 0.9, a)
			draw_rect(Rect2(-w * 0.5 + ix * (w / 12.0), -h * 0.5 + iy * (h / 8.0), w / 12.0 + 0.5, h / 8.0 + 0.5), c)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.5, 0.08, 0.1, a), false, 1.5)
	# the basket
	draw_rect(Rect2(-8, -6, 16, 11), Color(0.7, 0.5, 0.25, a))
	draw_rect(Rect2(-8, -6, 16, 11), Color(0.4, 0.25, 0.1, a), false, 1.2)
	draw_arc(Vector2(0, -6), 6.0, PI, TAU, 8, Color(0.4, 0.25, 0.1, a), 1.5)
	# sandwiches and a thermos
	for k in 3:
		var p := Vector2(-26.0 + k * 9.0, 12.0)
		draw_rect(Rect2(p, Vector2(7, 3)), Color(0.9, 0.75, 0.45, a))
		draw_rect(Rect2(p + Vector2(0, 3), Vector2(7, 1.5)), Color(0.4, 0.8, 0.3, a))
		draw_rect(Rect2(p + Vector2(0, 4.5), Vector2(7, 3)), Color(0.9, 0.75, 0.45, a))
	draw_rect(Rect2(20, 6, 5, 12), Color(0.3, 0.55, 0.85, a))
	draw_rect(Rect2(20, 4, 5, 3), Color(0.8, 0.8, 0.85, a))

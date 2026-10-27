extends Node2D
## The picture of a cone of fire or ice, fading out. The damage is done where it is cast.

var dir := Vector2.RIGHT
var spread := 0.5
var length := 170.0
var color := Color(1.0, 0.5, 0.1)
var age := 0.0
const LIFE := 0.35


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - age / LIFE
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		pts.append(dir.rotated(lerpf(-spread, spread, i / 8.0)) * length * (0.6 + 0.4 * (age / LIFE)))
	draw_colored_polygon(pts, Color(color, 0.55 * a))
	draw_polyline(pts, Color(color.lightened(0.4), a), 2.0)

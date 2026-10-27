extends StaticBody2D
## A bone wall: one tile that blocks movement. Villagers path around it, or chew through it
## if it is the nearest thing in their way. The map never lets walls and towers seal off
## every route, so there is always a way in.

signal destroyed(tile: Vector2i)

const COST := 5
const MAX_HP := 20

var tile := Vector2i.ZERO
var invested := 0       ## bones spent on it; removing it refunds half
var hp := MAX_HP


func _ready() -> void:
	add_to_group("structures")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 30)
	shape.shape = rect
	add_child(shape)


func take_hit(dmg: int, _dir: Vector2) -> void:
	hp -= dmg
	queue_redraw()
	if hp <= 0:
		destroyed.emit(tile)
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-15, -15, 30, 30), Color("d8d2c0"))
	draw_rect(Rect2(-15, -15, 30, 30), Color("8a8472"), false, 2.0)
	draw_line(Vector2(-15, 0), Vector2(15, 0), Color("8a8472"), 1.5)
	draw_line(Vector2(0, -15), Vector2(0, 0), Color("8a8472"), 1.5)
	draw_line(Vector2(-7, 0), Vector2(-7, 15), Color("8a8472"), 1.5)
	draw_line(Vector2(8, 0), Vector2(8, 15), Color("8a8472"), 1.5)
	if hp < MAX_HP:
		draw_rect(Rect2(-14, -20, 28, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -20, 28.0 * hp / MAX_HP, 3), Color("e04040"))

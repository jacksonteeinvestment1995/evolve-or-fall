extends StaticBody2D
## A bone wall: one tile that blocks movement. Villagers path around it, or chew through it
## if it is the nearest thing in their way. The map never lets walls and towers seal off
## every route, so there is always a way in.

const Popups := preload("res://popups.gd")

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
	Popups.damage(get_tree(), global_position + Vector2(0, -22), dmg, Popups.STRUCTURE)
	queue_redraw()
	if hp <= 0:
		destroyed.emit(tile)
		queue_free()


func _draw() -> void:
	# the pixel-art bone wall; it shows its cracked version when it is hurt
	var tex := Sprites.tex("bone_wall_damaged" if hp * 2 <= MAX_HP else "bone_wall")
	if tex != null:
		draw_texture_rect_region(tex, Rect2(-16, -16, 32, 32), Rect2(0, 0, 32, 32))
	else:
		draw_rect(Rect2(-15, -15, 30, 30), Color("d8d2c0"))
		draw_rect(Rect2(-15, -15, 30, 30), Color("8a8472"), false, 2.0)
	if hp < MAX_HP:
		draw_rect(Rect2(-14, -20, 28, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-14, -20, 28.0 * hp / MAX_HP, 3), Color("e04040"))

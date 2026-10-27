extends Node2D
## The wandering merchant. Walk up to open the shop; he leaves after about a minute.

const Popups := preload("res://popups.gd")

const STAY := 60.0

var age := 0.0
var cooldown := 0.0


func _ready() -> void:
	add_to_group("merchants")
	z_index = 2


func _physics_process(delta: float) -> void:
	age += delta
	cooldown = maxf(cooldown - delta, 0.0)
	if age >= STAY:
		Popups.text(get_tree(), global_position + Vector2(0, -26), "Safe travels!", Popups.WHITE, 12)
		queue_free()
		return
	var main = get_parent()
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0 and cooldown == 0.0 and not main.menu_open and pl.global_position.distance_to(global_position) < 34.0:
		cooldown = 3.0
		main.open_shop(self)
	queue_redraw()


func _draw() -> void:
	var bob := sin(age * 3.0) * 1.2
	var left := clampf((STAY - age) / 6.0, 0.0, 1.0)
	draw_circle(Vector2(0, 11), 11.0, Color(0, 0, 0, 0.25))
	# a lantern's glow
	draw_circle(Vector2(13, 0 + bob), 11.0, Color(1.0, 0.8, 0.4, 0.14 + 0.06 * sin(age * 6.0)))
	# the pack
	draw_rect(Rect2(-12, -8 + bob, 9, 14), Color("8a5a2b"))
	draw_rect(Rect2(-12, -8 + bob, 9, 14), Color("4a2e12"), false, 1.2)
	draw_rect(Rect2(-12, -3 + bob, 9, 2), Color("c9a060"))
	# the cloak and hood
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -2 + bob), Vector2(6, -2 + bob), Vector2(9, 11), Vector2(-9, 11)]), Color("3a6a8a"))
	draw_circle(Vector2(0, -7 + bob), 6.0, Color("2a5070"))
	draw_circle(Vector2(0, -6 + bob), 3.6, Color("e8c8a0"))
	draw_circle(Vector2(-1.4, -6.5 + bob), 0.8, Color("201010"))
	draw_circle(Vector2(1.4, -6.5 + bob), 0.8, Color("201010"))
	draw_arc(Vector2(0, -5 + bob), 1.8, 0.2, PI - 0.2, 6, Color("a05040"), 1.0)
	# the lantern on a stick
	draw_line(Vector2(7, 2 + bob), Vector2(13, -6 + bob), Color("5a3b22"), 1.5)
	draw_rect(Rect2(10.5, -7 + bob, 5, 6), Color("ffd060"))
	draw_rect(Rect2(10.5, -7 + bob, 5, 6), Color("5a3b22"), false, 1.0)
	# a bobbing coin sign
	var sy := -22.0 + sin(age * 4.0) * 2.0
	draw_circle(Vector2(0, sy), 5.0, Color("ffd040"))
	draw_circle(Vector2(0, sy), 5.0, Color("8a6010"), false, 1.2)
	draw_line(Vector2(0, sy - 3), Vector2(0, sy + 3), Color("8a6010"), 1.5)
	if left < 1.0 and int(age * 4.0) % 2 == 0:
		draw_rect(Rect2(-8, -30, 16, 2), Color(1, 1, 1, 0.5 * (1.0 - left)))

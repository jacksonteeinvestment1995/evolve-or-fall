extends StaticBody2D
## A bone tower, placed anywhere you like. It shoots the nearest villager in range.
## Build on it again (E with the cursor over it) to upgrade. Kills made by towers give
## bones but no EXP.

const Popups := preload("res://popups.gd")

signal destroyed(tile: Vector2i)

const MAX_LEVEL := 3
const COSTS := [15, 25, 40]           ## bones: build, upgrade to 2, upgrade to 3
const DAMAGE := [1, 2, 3]
const RATE := [1.0, 0.8, 0.6]         ## seconds between shots
const REACH := [120.0, 140.0, 160.0]

var tile := Vector2i.ZERO
var invested := 0                     ## bones spent on it; removing it refunds half
var level := 1
var max_hp := 12
var hp := 12
var cd := 0.0
var shot_to := Vector2.ZERO
var shot_flash := 0.0


func _ready() -> void:
	add_to_group("towers")
	add_to_group("structures")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	shape.shape = rect
	add_child(shape)


func upgrade() -> void:
	level = mini(level + 1, MAX_LEVEL)
	max_hp = 12 + (level - 1) * 6
	hp = max_hp


func _physics_process(delta: float) -> void:
	cd = maxf(cd - delta, 0.0)
	shot_flash = maxf(shot_flash - delta, 0.0)
	if cd == 0.0:
		var target = null
		var best: float = REACH[level - 1]
		for e in get_tree().get_nodes_in_group("enemies"):
			var d: float = e.global_position.distance_to(global_position)
			if d <= best:
				best = d
				target = e
		if target != null:
			cd = RATE[level - 1]
			shot_to = target.global_position - global_position
			shot_flash = 0.1
			target.take_hit(DAMAGE[level - 1], shot_to.normalized(), true)
	queue_redraw()


func take_hit(dmg: int, _dir: Vector2) -> void:
	hp -= dmg
	Popups.damage(get_tree(), global_position + Vector2(0, -26), dmg, Popups.STRUCTURE)
	if hp <= 0:
		destroyed.emit(tile)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 8), 13.0, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(-9, -2, 18, 12), Color("8a8a92"))
	draw_rect(Rect2(-7, -14, 14, 14), Color("b0b0b8"))
	for k in 3:
		draw_rect(Rect2(-7 + k * 5, -18, 4, 4), Color("b0b0b8"))
	draw_circle(Vector2(0, -8), 3.0, Color("f2e6c9"))  # a skull in the window
	for k in level:
		draw_circle(Vector2(-4 + k * 4, 13), 1.6, Color("ffd84a"))
	if hp < max_hp:
		draw_rect(Rect2(-10, -24, 20, 3), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-10, -24, 20.0 * hp / max_hp, 3), Color("e04040"))
	if shot_flash > 0.0:
		draw_line(Vector2(0, -8), shot_to, Color("f2e6c9"), 2.0)

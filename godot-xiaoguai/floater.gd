extends Node2D
## A number that floats up and fades: how much damage a hit did.

var text := ""
var color := Color.WHITE
var font_size := 14
var life := 0.85
var vel := Vector2(0, -46)
var age := 0.0


func _ready() -> void:
	z_index = 30
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _exit_tree() -> void:
	var popups = load("res://popups.gd")  # loaded here, not preloaded: popups.gd preloads this file
	popups.active = maxi(popups.active - 1, 0)


func _physics_process(delta: float) -> void:
	age += delta
	position += vel * delta
	vel.y *= 0.95
	if age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - pow(age / life, 2.0)
	var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - age / 0.12)  # a quick pop when it appears
	var size := int(font_size * pop)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, size, 4, Color(0, 0, 0, a * 0.9))
	draw_string(font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, size, Color(color, a))

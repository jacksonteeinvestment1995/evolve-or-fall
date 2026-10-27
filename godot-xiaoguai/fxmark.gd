class_name FxMark
extends Node2D
## A short sprite animation that follows nothing: plays its strip once where it is spawned, then frees itself.

var strip := ""
var life := 0.45
var age := 0.0


static func spawn(parent: Node, pos: Vector2, name: String, life_time: float = 0.45) -> void:
	if Sprites.tex(name) == null:
		return
	var m := FxMark.new()
	m.strip = name
	m.life = life_time
	m.position = pos
	m.z_index = 20
	parent.add_child(m)


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := Sprites.tex(strip)
	if t == null:
		return
	var fh := t.get_height()
	var frame := clampi(int(age / life * (t.get_width() / fh)), 0, t.get_width() / fh - 1)
	draw_texture_rect_region(t, Rect2(-fh, -fh, fh * 2.0, fh * 2.0), Rect2(frame * fh, 0, fh, fh), Color(1, 1, 1, minf(1.0, (1.0 - age / life) * 2.0)))

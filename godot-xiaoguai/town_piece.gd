extends Node2D
## One building or prop of a town. Its position is the bottom-left corner of its footprint; the sprite rises from
## there. The main scene sorts children by y, so characters south of the position draw in front and those north of
## it draw behind. A magenta box shows when the art is missing.

var sprite := ""


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var t := Sprites.tex(sprite)
	if t != null:
		draw_texture(t, Vector2(0, -t.get_height()))
	else:
		draw_rect(Rect2(0, -48, 64, 48), Color(0.8, 0.2, 0.8, 0.6))
		draw_string(ThemeDB.fallback_font, Vector2(2, -20), sprite, HORIZONTAL_ALIGNMENT_LEFT, 60, 8, Color.WHITE)

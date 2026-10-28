extends Node2D
## The trees, swaying in the wind. Each tree is drawn in 4-pixel strips: the crown leans a pixel or two while the
## trunk stays put (the idea from the HD-2D preview). Only trees near the camera are drawn.

const TILE := 32
const STRIP := 4

var cells := {}      # Vector2i -> true (also holds pond tiles, which are skipped)
var water := {}
var skip := {}       # town tiles: solid, but not trees
var cam: Camera2D
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var textures := [Sprites.tex("tree_1"), Sprites.tex("tree_2")]
	if textures[0] == null:
		return
	var rect := Rect2(-1e9, -1e9, 2e9, 2e9)
	if cam != null:
		var c := cam.get_screen_center_position()
		var half := Vector2(1280, 720) / cam.zoom * 0.5 + Vector2(TILE, TILE * 2)
		rect = Rect2(c - half, half * 2.0)
	var x0 := floori(rect.position.x / TILE)
	var x1 := ceili(rect.end.x / TILE)
	var y0 := floori(rect.position.y / TILE)
	var y1 := ceili(rect.end.y / TILE) + 2
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c2 := Vector2i(x, y)
			if not cells.has(c2) or water.has(c2) or skip.has(c2):
				continue
			var tex: Texture2D = textures[(x + y) % 2]
			var h := tex.get_height()
			var top := float((y + 1) * TILE - h)
			var phase := float((x * 7 + y * 13) % 17)
			var r := 0
			while r < h:
				var k := 1.0 - minf(1.0, float(r) / (h * 0.62))     # 1 at the crown, 0 at the trunk
				var dx := roundf(sin(_t * 1.3 + phase + float(r) * 0.05) * 1.6 * k)
				var n := mini(STRIP, h - r)
				draw_texture_rect_region(tex, Rect2(x * TILE + dx, top + r, TILE, n), Rect2(0, r, tex.get_width(), n))
				r += n

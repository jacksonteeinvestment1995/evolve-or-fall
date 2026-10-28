extends Node2D
## Ponds. Cells are water tiles; a cell touching grass gets the matching shore edge tile
## (bits N=1, E=2, S=4, W=8 mark grass neighbours; art/export/shore_*), so ponds blend into the meadow.

const TILE := 32
const EDGE := {1: "edge_n", 2: "edge_e", 4: "edge_s", 8: "edge_w", 3: "corner_ne", 6: "corner_se", 12: "corner_sw", 9: "corner_nw"}

var base := "tile_water"       ## the plain tile
var edge_prefix := "shore_"    ## shore_edge_n ... or pathedge_edge_n ...

var cells := {}
var cam: Camera2D
var _t := 0.0
var _cache := {}
var _cache_size := -1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _frame_of(t: Texture2D) -> Rect2:
	var fh := t.get_height()
	var n := maxi(1, t.get_width() / fh)
	return Rect2((int(_t * 3.0) % n) * fh, 0, fh, fh)


func _tex_for(c: Vector2i, water_tex: Texture2D) -> Texture2D:
	var mask := 0
	for pair in [[Vector2i(0, -1), 1], [Vector2i(1, 0), 2], [Vector2i(0, 1), 4], [Vector2i(-1, 0), 8]]:
		if not cells.has(c + pair[0]):
			mask |= pair[1]
	var name := ""
	if mask == 0:
		for pair in [[Vector2i(1, -1), "ne"], [Vector2i(1, 1), "se"], [Vector2i(-1, 1), "sw"], [Vector2i(-1, -1), "nw"]]:
			if not cells.has(c + pair[0]):
				name = edge_prefix + "inner_" + pair[1]
				break
	else:
		name = edge_prefix + EDGE[mask] if EDGE.has(mask) else ""
	var tex: Texture2D = Sprites.tex(name) if name != "" else null
	return tex if tex != null else water_tex


## Only the cells near the camera are drawn, and each cell's tile is worked out once.
func _draw() -> void:
	var water_tex := Sprites.tex(base)
	if water_tex == null:
		return
	if _cache_size != cells.size():
		_cache.clear()
		_cache_size = cells.size()
	var rect := Rect2(-1e9, -1e9, 2e9, 2e9)
	if cam != null:
		var center := cam.get_screen_center_position()
		var half := get_viewport_rect().size / cam.zoom * 0.5 + Vector2(TILE, TILE)
		rect = Rect2(center - half, half * 2.0)
	var x0 := maxi(floori(rect.position.x / TILE), -1)
	var x1 := ceili(rect.end.x / TILE)
	var y0 := maxi(floori(rect.position.y / TILE), -1)
	var y1 := ceili(rect.end.y / TILE)
	if cam == null:
		for c in cells:
			_draw_cell(c, water_tex)
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c2 := Vector2i(x, y)
			if cells.has(c2):
				_draw_cell(c2, water_tex)


func _draw_cell(c: Vector2i, water_tex: Texture2D) -> void:
	var tex: Texture2D = _cache.get(c)
	if tex == null:
		tex = _tex_for(c, water_tex)
		_cache[c] = tex
	draw_texture_rect_region(tex, Rect2(c.x * TILE, c.y * TILE, TILE, TILE), _frame_of(tex))

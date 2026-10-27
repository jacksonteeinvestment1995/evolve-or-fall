extends Node2D
## Ponds. Cells are water tiles; a cell touching grass gets the matching shore edge tile
## (bits N=1, E=2, S=4, W=8 mark grass neighbours; art/export/shore_*), so ponds blend into the meadow.

const TILE := 32
const EDGE := {1: "edge_n", 2: "edge_e", 4: "edge_s", 8: "edge_w", 3: "corner_ne", 6: "corner_se", 12: "corner_sw", 9: "corner_nw"}

var base := "tile_water"       ## the plain tile
var edge_prefix := "shore_"    ## shore_edge_n ... or pathedge_edge_n ...

var cells := {}
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _frame_of(t: Texture2D) -> Rect2:
	var fh := t.get_height()
	var n := maxi(1, t.get_width() / fh)
	return Rect2((int(_t * 3.0) % n) * fh, 0, fh, fh)


func _draw() -> void:
	var water_tex := Sprites.tex(base)
	if water_tex == null:
		return
	for c in cells:
		var r := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
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
		if tex == null:
			tex = water_tex
		draw_texture_rect_region(tex, r, _frame_of(tex))

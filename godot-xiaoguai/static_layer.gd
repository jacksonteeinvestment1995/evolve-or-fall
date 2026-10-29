extends Node2D
## The still things on the ground: the soft shadows under every tree and all the props (rocks, flowers, bushes, the
## biome props, fences, gravestones). They used to be drawn inside main.gd's own _draw, which meant every one of them,
## the whole map's worth, was replayed to the renderer on every frame even when far off screen. This layer draws only
## the tiles around the camera (a few more than the screen shows) and redraws only when the camera leaves that area.

const TILE := 32
const MARGIN := 5

var main: Node2D
var cam: Camera2D
var _covered := Rect2i()


func _ready() -> void:
	z_index = -4   # on the ground: over the meadow, under everything that walks or grows


func _process(_delta: float) -> void:
	if cam == null or main == null:
		return
	var c := cam.get_screen_center_position()
	var half := get_viewport_rect().size / cam.zoom * 0.5
	var need := Rect2i(Vector2i(floori((c.x - half.x) / TILE), floori((c.y - half.y) / TILE)), Vector2i(ceili(half.x * 2.0 / TILE) + 1, ceili(half.y * 2.0 / TILE) + 1))
	if not _covered.encloses(need):
		_covered = need.grow(MARGIN)
		queue_redraw()


func _draw() -> void:
	if main == null or _covered.size == Vector2i.ZERO:
		return
	var x0 := maxi(_covered.position.x, 0)
	var y0 := maxi(_covered.position.y, 0)
	var x1 := mini(_covered.end.x, main.COLS)
	var y1 := mini(_covered.end.y, main.ROWS)
	# tree shadows first, then the props over them
	for y in range(y0, y1 + 2):
		for x in range(x0, x1):
			var t := Vector2i(x, y)
			if main.trees.has(t) and not main.water.has(t) and not main.buildings.has(t):
				var c := Vector2(t.x + 0.5, t.y + 0.5) * TILE
				main._shadow(c + Vector2(0, 14), 13.0, 4.0, 11.0, self)
				main._shadow(c + Vector2(0, 7), 10.0, 4.5, 18.0, self)
	for y in range(y0, y1 + 2):
		for x in range(x0, x1):
			var t2 := Vector2i(x, y)
			if main.props.has(t2):
				main._draw_prop(t2, main.props[t2], self)

extends Node2D
## The meadow. Only the grass tiles around the camera are drawn (a few more than the screen shows), and they are
## redrawn only when the camera walks out of that area, instead of recording all 18000 tiles every time.

const TILE := 32
const MARGIN := 4

var cam: Camera2D
var cols := 1
var rows := 1
var _covered := Rect2i()


func _process(_delta: float) -> void:
	if cam == null:
		return
	var c := cam.get_screen_center_position()
	var half := get_viewport_rect().size / cam.zoom * 0.5
	var need := Rect2i(Vector2i(floori((c.x - half.x) / TILE), floori((c.y - half.y) / TILE)), Vector2i(ceili(half.x * 2.0 / TILE) + 1, ceili(half.y * 2.0 / TILE) + 1))
	if not _covered.encloses(need):
		_covered = need.grow(MARGIN)
		queue_redraw()


func _draw() -> void:
	var grass := [Sprites.tex("grass_1"), Sprites.tex("grass_2"), Sprites.tex("grass_3")]
	if grass[0] == null or _covered.size == Vector2i.ZERO:
		return
	var x0 := maxi(_covered.position.x, 0)
	var y0 := maxi(_covered.position.y, 0)
	var x1 := mini(_covered.end.x, cols)
	var y1 := mini(_covered.end.y, rows)
	draw_rect(Rect2(x0 * TILE, y0 * TILE, (x1 - x0) * TILE, (y1 - y0) * TILE), Color("5b8a3c"))
	# one texture at a time, so the renderer can batch each pass into a single draw
	for which in 3:
		for y in range(y0, y1):
			for x in range(x0, x1):
				var pick := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff  # a stable pseudo-random pick: no flicker, no rows
				if (pick % 3 if pick % 7 < 2 else 0) == which:
					draw_texture_rect(grass[which], Rect2(x * TILE, y * TILE, TILE, TILE), false)

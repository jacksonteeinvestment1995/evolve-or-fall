extends Node2D
## The mud patches, alive: slow shimmer, bubbles that swell and pop, and rounded corners instead of square
## ones. Each mud tile is a polygon with the mud texture; a convex corner is rounded off and a concave corner is
## filled in with a small fillet, so a patch looks like one blob. Only tiles near the camera are drawn.

const TILE := 32
const ROUND := 11.0       # corner radius in pixels
const ARC_STEPS := 4

var cells := {}
var cam: Camera2D
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


static func _hash(c: Vector2i, salt: int = 0) -> float:
	var h := (c.x * 73856093) ^ (c.y * 19349663) ^ (salt * 83492791)
	return float(h & 0xffff) / 65535.0


func _tile_poly(c: Vector2i) -> PackedVector2Array:
	var x0 := float(c.x * TILE)
	var y0 := float(c.y * TILE)
	var x1 := x0 + TILE
	var y1 := y0 + TILE
	var n := cells.has(c + Vector2i(0, -1))
	var e := cells.has(c + Vector2i(1, 0))
	var s := cells.has(c + Vector2i(0, 1))
	var w := cells.has(c + Vector2i(-1, 0))
	var pts := PackedVector2Array()
	# going clockwise from the top-left corner; a corner is rounded when both of its sides are open
	_corner(pts, Vector2(x0, y0), Vector2(1, 1), not n and not w, PI, PI * 1.5)
	_corner(pts, Vector2(x1, y0), Vector2(-1, 1), not n and not e, PI * 1.5, TAU)
	_corner(pts, Vector2(x1, y1), Vector2(-1, -1), not s and not e, 0.0, PI * 0.5)
	_corner(pts, Vector2(x0, y1), Vector2(1, -1), not s and not w, PI * 0.5, PI)
	return pts


func _corner(pts: PackedVector2Array, p: Vector2, inward: Vector2, round_it: bool, a0: float, a1: float) -> void:
	if not round_it:
		pts.append(p)
		return
	var center := p + inward * ROUND
	for i in ARC_STEPS + 1:
		var a := lerpf(a0, a1, float(i) / ARC_STEPS)
		pts.append(center + Vector2(cos(a), sin(a)) * ROUND)


## The little triangle-ish fillet that fills a concave corner (both side neighbours are mud, the diagonal is not).
func _fillets(c: Vector2i, tex: Texture2D) -> void:
	var x0 := float(c.x * TILE)
	var y0 := float(c.y * TILE)
	var x1 := x0 + TILE
	var y1 := y0 + TILE
	var spec := [
		[Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2(x0, y0), Vector2(-1, -1)],
		[Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, -1), Vector2(x1, y0), Vector2(1, -1)],
		[Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2(x1, y1), Vector2(1, 1)],
		[Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2(x0, y1), Vector2(-1, 1)],
	]
	for sp in spec:
		if cells.has(c + sp[0]) and cells.has(c + sp[1]) and not cells.has(c + sp[2]):
			var corner: Vector2 = sp[3]
			var out: Vector2 = sp[4]   # towards the empty diagonal tile
			# the fillet sits in the diagonal tile's corner: corner point, one step along each edge, and an arc between
			var a_pt := corner + Vector2(out.x * ROUND, 0)
			var b_pt := corner + Vector2(0, out.y * ROUND)
			var pts := PackedVector2Array([corner, a_pt])
			var center := corner + out * ROUND
			var ang_a := (a_pt - center).angle()
			var ang_b := (b_pt - center).angle()
			var d := wrapf(ang_b - ang_a, -PI, PI)
			for i in range(1, ARC_STEPS):
				var a := ang_a + d * float(i) / ARC_STEPS
				pts.append(center + Vector2(cos(a), sin(a)) * ROUND)
			pts.append(b_pt)
			_draw_poly(pts, tex)


func _draw_poly(pts: PackedVector2Array, tex: Texture2D, tint: Color = Color.WHITE) -> void:
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2(fposmod(p.x, TILE) / TILE, fposmod(p.y, TILE) / TILE))
	# fposmod breaks UVs on tiles that touch the far edge: use the tile's own origin instead
	var o := Vector2(floorf(pts[0].x / TILE) * TILE, floorf(pts[0].y / TILE) * TILE)
	uvs.clear()
	for p in pts:
		uvs.append(((p - o) / TILE).clamp(Vector2.ZERO, Vector2.ONE))
	draw_polygon(pts, PackedColorArray([tint]), uvs, tex)


func _draw() -> void:
	var tex := Sprites.tex("mud")
	if tex == null or cells.is_empty():
		return
	var rect := Rect2(-1e9, -1e9, 2e9, 2e9)
	if cam != null:
		var c := cam.get_screen_center_position()
		var half := Vector2(1280, 720) / cam.zoom * 0.5 + Vector2(TILE, TILE)
		rect = Rect2(c - half, half * 2.0)
	var x0 := floori(rect.position.x / TILE)
	var x1 := ceili(rect.end.x / TILE)
	var y0 := floori(rect.position.y / TILE)
	var y1 := ceili(rect.end.y / TILE)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := Vector2i(x, y)
			if not cells.has(c):
				continue
			var shimmer := 0.045 * sin(_t * 1.4 + float(x) * 0.6 + float(y) * 0.9)
			var tint := Color(1.0 + shimmer, 1.0 + shimmer * 0.7, 1.0 + shimmer * 0.4)
			var pts := _tile_poly(c)
			_draw_poly(pts, tex, tint)
			_fillets(c, tex)
			_bubble(c)


## A bubble swells on some tiles, then pops with a ring and a few droplets.
func _bubble(c: Vector2i) -> void:
	if _hash(c, 1) > 0.3:
		return
	var cycle := 3.5 + _hash(c, 2) * 3.0
	var life := 1.8
	var t := fposmod(_t + _hash(c, 3) * cycle, cycle)
	if t > life:
		return
	var base := Vector2(c.x * TILE + 6.0 + _hash(c, 4) * (TILE - 12.0), c.y * TILE + 6.0 + _hash(c, 5) * (TILE - 12.0))
	var k := t / life
	if k < 0.72:
		var g := k / 0.72
		var r := 1.0 + 4.6 * g
		draw_circle(base + Vector2(0, 1.2), r + 0.8, Color(0.15, 0.08, 0.04, 0.45))
		draw_circle(base, r, Color(0.52, 0.36, 0.2, 0.9))
		draw_arc(base, r, 0.0, TAU, 12, Color(0.28, 0.17, 0.08, 0.9), 1.0)
		draw_circle(base + Vector2(-r * 0.35, -r * 0.4), maxf(0.7, r * 0.3), Color(0.95, 0.85, 0.65, 0.9))
	else:
		var p := (k - 0.72) / 0.28
		draw_arc(base, 5.6 + 5.0 * p, 0.0, TAU, 16, Color(0.7, 0.52, 0.32, 1.0 - p), 1.2)
		for i in 4:
			var a := float(i) * TAU / 4.0 + _hash(c, 6) * 3.0
			var d := Vector2.from_angle(a) * (4.0 + 7.0 * p)
			draw_circle(base + d + Vector2(0, -3.0 * sin(p * PI)), 1.1 * (1.0 - p), Color(0.6, 0.42, 0.24, 1.0 - p))

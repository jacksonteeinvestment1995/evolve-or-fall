extends Control
## The minimap: a round radar in the top right corner that follows 小怪 and shows the land around him.
## White = 小怪 (with a facing tick), red = villagers (bigger form, bigger dot), blue = towers, grey = walls,
## big pulsing dots = hidden enemies (always shown), a gold "$" = the wandering merchant, small squares = unopened
## chests. The map starts in fog and stays revealed where 小怪 has walked within REVEAL tiles.

const SCALE := 3.0          # screen pixels per tile
const RADIUS := 100.0       # the radar's radius in pixels (so it shows about 33 tiles each way)
const REVEAL := 12          # tiles (about 400 px)
const HIDDEN_COLORS := [Color("5ac040"), Color("a050e0"), Color("ffd040")]

var main_node: Node2D
var fog_on := true
var _terrain: ImageTexture
var _fog_img: Image
var _fog_tex: ImageTexture
var _last_tile := Vector2i(-99, -99)
var _t := 0.0
var _acc := 0.0
var _cols := 1
var _rows := 1
var _circle := PackedVector2Array()


func setup(main: Node2D) -> void:
	main_node = main
	_cols = main.COLS
	_rows = main.ROWS
	custom_minimum_size = Vector2(RADIUS * 2.0 + 16.0, RADIUS * 2.0 + 16.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	for y in _rows:
		for x in _cols:
			var t := Vector2i(x, y)
			var c := Color("4a7a36")
			if main.water.has(t):
				c = Color("2f5fb0")
			elif main.trees.has(t):
				c = Color("24491f")
			elif main.mud.has(t):
				c = Color("6b4f2f")
			elif main.paths.has(t):
				c = Color("8a8794")
			img.set_pixel(x, y, c)
	_terrain = ImageTexture.create_from_image(img)
	_fog_img = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.03, 0.04, 0.08, 0.92))
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	for i in 64:
		var a := float(i) / 64.0 * TAU
		_circle.append(Vector2(cos(a), sin(a)) * RADIUS)


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 0.1:
		_acc = 0.0
		_reveal()
		queue_redraw()


func _reveal() -> void:
	if main_node == null or main_node.player == null:
		return
	var tile: Vector2i = main_node.tile_of(main_node.player.global_position)
	if tile == _last_tile:
		return
	_last_tile = tile
	for dy in range(-REVEAL, REVEAL + 1):
		for dx in range(-REVEAL, REVEAL + 1):
			if dx * dx + dy * dy > REVEAL * REVEAL:
				continue
			var p := tile + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < _cols and p.y < _rows:
				_fog_img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	_fog_tex.update(_fog_img)


func _revealed(tile: Vector2i) -> bool:
	return not fog_on or _fog_img.get_pixel(clampi(tile.x, 0, _cols - 1), clampi(tile.y, 0, _rows - 1)).a < 0.5


## The circle clipped to the map rectangle (Sutherland-Hodgman), so the texture never has to stretch past its edge.
func _clipped(center_tile: Vector2) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for p in _circle:
		poly.append(center_tile + p / SCALE)   # in tile coordinates
	var lo := Vector2.ZERO
	var hi := Vector2(_cols, _rows)
	for edge in 4:
		var out := PackedVector2Array()
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var ina := _inside(a, edge, lo, hi)
			var inb := _inside(b, edge, lo, hi)
			if ina:
				out.append(a)
			if ina != inb:
				out.append(_cut(a, b, edge, lo, hi))
		poly = out
		if poly.is_empty():
			break
	return poly


func _inside(p: Vector2, edge: int, lo: Vector2, hi: Vector2) -> bool:
	match edge:
		0:
			return p.x >= lo.x
		1:
			return p.x <= hi.x
		2:
			return p.y >= lo.y
	return p.y <= hi.y


func _cut(a: Vector2, b: Vector2, edge: int, lo: Vector2, hi: Vector2) -> Vector2:
	var t := 0.0
	match edge:
		0:
			t = (lo.x - a.x) / (b.x - a.x)
		1:
			t = (hi.x - a.x) / (b.x - a.x)
		2:
			t = (lo.y - a.y) / (b.y - a.y)
		_:
			t = (hi.y - a.y) / (b.y - a.y)
	return a.lerp(b, t)


func _draw() -> void:
	if _terrain == null or main_node == null or main_node.player == null:
		return
	var tile_px: float = main_node.TILE
	var pp_tile: Vector2 = main_node.player.global_position / tile_px
	var c := size * 0.5
	var night: bool = main_node.is_night()
	# backing disc
	draw_circle(c, RADIUS + 4.0, Color(0.04, 0.04, 0.08, 0.85))
	# terrain and fog, both mapped onto the same clipped disc
	var poly := _clipped(pp_tile)
	if poly.size() >= 3:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for q in poly:
			pts.append(c + (q - pp_tile) * SCALE)
			uvs.append(Vector2(q.x / _cols, q.y / _rows))
		draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.95)]), uvs, _terrain)
		if fog_on:
			draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _fog_tex)
	# markers, only inside the disc
	var to_screen := func(world: Vector2) -> Vector2: return c + (world / tile_px - pp_tile) * SCALE
	var inside := func(p: Vector2, margin: float = 3.0) -> bool: return p.distance_to(c) <= RADIUS - margin
	for s in get_tree().get_nodes_in_group("structures"):
		var sp: Vector2 = to_screen.call(s.global_position)
		if inside.call(sp) and _revealed(main_node.tile_of(s.global_position)):
			var col := Color("4aa0ff") if s.is_in_group("towers") else Color("a0a0a8")
			draw_rect(Rect2(sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col)
	for ch in get_tree().get_nodes_in_group("treasures"):
		var cp: Vector2 = to_screen.call(ch.global_position)
		if ch.opened or not inside.call(cp) or not _revealed(main_node.tile_of(ch.global_position)):
			continue
		draw_rect(Rect2(cp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), ch.TIERS[ch.tier]["trim"])
		draw_rect(Rect2(cp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(0, 0, 0, 0.8), false, 0.8)
	for m in get_tree().get_nodes_in_group("merchants"):
		var mp: Vector2 = to_screen.call(m.global_position)
		if inside.call(mp):
			draw_circle(mp, 4.0, Color("ffd040"))
			draw_circle(mp, 4.0, Color("6a4a10"), false, 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ep: Vector2 = to_screen.call(e.global_position)
		var secret: int = e.get("secret") if e.get("secret") != null else -1
		if secret >= 0:
			# hidden enemies are shown even outside the circle: pinned to its edge, pointing the way
			var dir := ep - c
			var pin := ep if dir.length() <= RADIUS - 5.0 else c + dir.normalized() * (RADIUS - 5.0)
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_circle(pin, 4.0 + pulse * 1.8, Color(HIDDEN_COLORS[clampi(secret, 0, 2)], 0.35))
			draw_circle(pin, 3.0, HIDDEN_COLORS[clampi(secret, 0, 2)])
		elif inside.call(ep) and _revealed(main_node.tile_of(e.global_position)):
			var stage: int = e.get("stage") if e.get("stage") != null else 0
			var sz := 2.2 + minf(float(stage), 4.0) * 0.5
			draw_rect(Rect2(ep - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color("e04040"))
	# 小怪 in the middle, with what the camera sees
	draw_circle(c, 3.4, Color.WHITE)
	draw_line(c, c + main_node.player.facing * 8.0, Color.WHITE, 1.8)
	var view := Vector2(1280, 720) / 2.0 / tile_px * SCALE
	draw_rect(Rect2(c - view * 0.5, view), Color(1, 1, 1, 0.35), false, 1.0)
	# the rim
	draw_arc(c, RADIUS + 2.0, 0.0, TAU, 72, Color(0.5, 0.6, 1.0, 0.85) if night else Color(1.0, 0.88, 0.55, 0.9), 3.0)
	draw_arc(c, RADIUS - 1.0, 0.0, TAU, 72, Color(0, 0, 0, 0.5), 1.5)
	# a small north mark
	draw_string(ThemeDB.fallback_font, c + Vector2(-4, -RADIUS + 13.0), "N", HORIZONTAL_ALIGNMENT_LEFT, 12, 11, Color(1, 1, 1, 0.75))

extends Control
## Bottom-left minimap (design-abilities.md section 1): the whole map shrunk to a small panel.
## White = 小怪 (with a facing tick), red = villagers (bigger form, bigger dot), blue = towers,
## grey = walls, big pulsing dots = hidden enemies (always shown). The map starts in fog and stays
## revealed where 小怪 has walked within REVEAL tiles; villagers only show in the revealed part.

const SCALE := 1.2          # screen pixels per tile
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


func setup(main: Node2D) -> void:
	main_node = main
	_cols = main.COLS
	_rows = main.ROWS
	custom_minimum_size = Vector2(_cols, _rows) * SCALE
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
			img.set_pixel(x, y, c)
	_terrain = ImageTexture.create_from_image(img)
	_fog_img = Image.create(_cols, _rows, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.03, 0.04, 0.08, 0.92))
	_fog_tex = ImageTexture.create_from_image(_fog_img)


func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 0.2:
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


func _draw() -> void:
	if _terrain == null or main_node == null or main_node.player == null:
		return
	var panel := Rect2(Vector2.ZERO, Vector2(_cols, _rows) * SCALE)
	draw_rect(panel.grow(3.0), Color(0.05, 0.05, 0.1, 0.8))
	draw_texture_rect(_terrain, panel, false, Color(1, 1, 1, 0.9))
	if fog_on:
		draw_texture_rect(_fog_tex, panel, false)
	var night: bool = main_node.is_night()
	draw_rect(panel.grow(3.0), Color(0.5, 0.6, 1.0, 0.7) if night else Color(1.0, 0.9, 0.6, 0.7), false, 2.0)
	var tile_px: float = main_node.TILE
	for s in get_tree().get_nodes_in_group("structures"):
		var tt: Vector2i = main_node.tile_of(s.global_position)
		if _revealed(tt):
			var col := Color("4aa0ff") if s.is_in_group("towers") else Color("a0a0a8")
			draw_rect(Rect2(Vector2(tt) * SCALE - Vector2(0.5, 0.5), Vector2(2.2, 2.2)), col)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var tv: Vector2i = main_node.tile_of(e.global_position)
		var secret: int = e.get("secret") if e.get("secret") != null else -1
		var pos: Vector2 = e.global_position / tile_px * SCALE
		if secret >= 0:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_circle(pos, 3.2 + pulse * 1.6, Color(HIDDEN_COLORS[clampi(secret, 0, 2)], 0.35))
			draw_circle(pos, 2.3, HIDDEN_COLORS[clampi(secret, 0, 2)])
		elif _revealed(tv):
			var stage: int = e.get("stage") if e.get("stage") != null else 0
			var sz := 1.6 + minf(float(stage), 4.0) * 0.4
			draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color("e04040"))
	var pp: Vector2 = main_node.player.global_position / tile_px * SCALE
	draw_circle(pp, 2.6, Color.WHITE)
	draw_line(pp, pp + main_node.player.facing * 6.0, Color.WHITE, 1.5)
	# what the camera sees right now
	var view := Vector2(1280, 720) / 2.0 / tile_px * SCALE
	draw_rect(Rect2(pp - view * 0.5, view), Color(1, 1, 1, 0.45), false, 1.0)

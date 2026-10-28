extends Node2D
## The ground of the villages and castles: paved courtyards, gate aprons and the wooden bridges over the moat,
## plus soft shadows under every building and the warm lamps that switch on at night. The buildings themselves are
## separate nodes (town_piece.gd) added to the main scene, which sorts everything by height so characters walk
## behind a house and in front of it. towns.gd makes the layout.

const TILE := 32
const PieceScript := preload("res://town_piece.gd")

var main: Node2D
var layout := {}
var cam: Camera2D
var _t := 0.0
var _lamps: Array = []


## Called once by main after the layer is in the scene: sort by height, create every building, place the lamps.
func build() -> void:
	main.y_sort_enabled = true
	for p in layout.get("pieces", []):
		var n := PieceScript.new()
		n.sprite = p["name"]
		n.position = p["pos"]
		main.add_child(n)
	for pos in layout.get("lights", []):
		var l := PointLight2D.new()
		l.texture = Juice.radial()
		l.texture_scale = 0.8
		l.color = Color(1.0, 0.78, 0.45)
		l.energy = 0.0
		l.position = pos
		add_child(l)
		_lamps.append(l)


func _process(delta: float) -> void:
	_t += delta
	var dark := clampf(1.0 - main.daylight() * 1.4, 0.0, 1.0) if main != null else 0.0
	var center := cam.get_screen_center_position() if cam != null else Vector2.ZERO
	for l in _lamps:
		var near: bool = l.position.distance_to(center) < 700.0
		l.visible = near and dark > 0.02
		if l.visible:
			l.energy = dark * (0.9 + 0.1 * sin(_t * 7.0 + l.position.x))
	queue_redraw()


func _view() -> Rect2:
	if cam == null:
		return Rect2(-1e9, -1e9, 2e9, 2e9)
	var c := cam.get_screen_center_position()
	var half := Vector2(1280, 720) / cam.zoom * 0.5 + Vector2(TILE * 3, TILE * 4)
	return Rect2(c - half, half * 2.0)


func _draw() -> void:
	if main == null:
		return
	var view := _view()
	var floor_tex := Sprites.tex("stone_path")
	if floor_tex != null:
		for t in main.floors:
			var p := Vector2(t) * TILE
			if view.has_point(p):
				draw_texture_rect(floor_tex, Rect2(p, Vector2(TILE, TILE)), false, Color(0.9, 0.88, 0.93))
	# the bridges over the moat: planks across, with rails
	for t in main.bridges:
		var p2 := Vector2(t) * TILE
		if not view.has_point(p2):
			continue
		draw_rect(Rect2(p2, Vector2(TILE, TILE)), Color(0.5, 0.34, 0.2))
		for k in 4:
			draw_line(p2 + Vector2(0, 4.0 + k * 8.0), p2 + Vector2(TILE, 4.0 + k * 8.0), Color(0.3, 0.2, 0.1), 1.4)
		for k in 4:
			draw_line(p2 + Vector2(7.0 + k * 9.0, 0), p2 + Vector2(7.0 + k * 9.0, 3), Color(0.62, 0.45, 0.28), 1.0)
		draw_rect(Rect2(p2, Vector2(TILE, TILE)), Color(0.22, 0.14, 0.07), false, 1.0)
	# soft shadows under each building (light from the top left)
	if main.shadow_tex != null:
		for p3 in layout.get("pieces", []):
			var bl: Vector2 = p3["pos"]
			if not view.has_point(bl):
				continue
			var w: float = p3["w"]
			var rx := w * 0.55
			draw_texture_rect(main.shadow_tex, Rect2(bl.x + w * 0.5 - rx + 6.0, bl.y - 9.0, rx * 2.0, 22.0), false)

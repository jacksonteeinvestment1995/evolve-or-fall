extends Node2D
## Draws the villages and castles (towns.gd makes the layout): paved courtyards, castle walls with battlements,
## corner towers with pointed roofs and waving flags, the keep, gates, and village houses with chimney smoke, glowing
## windows at night and a well. Everything is drawn in code; only what is near the camera is drawn.

const TILE := 32

var main: Node2D
var layout := {}
var cam: Camera2D
var _t := 0.0
var _lamps: Array = []   # [PointLight2D, world position]

const ROOFS := [Color("b8402f"), Color("3f67b8"), Color("8a5f36"), Color("4f8f4f"), Color("8a4fa0")]


func _ready() -> void:
	# one warm lamp per house, and torches at the castle gates and keeps; switched on at night, near the camera
	for v in layout.get("villages", []):
		for h in v["houses"]:
			_lamp(Vector2(h["rect"].get_center()) * TILE + Vector2(0, 10), 0.75)
	var castles: Array = layout.get("small", []).duplicate()
	if not layout.get("big", {}).is_empty():
		castles.append(layout["big"])
	for c in castles:
		var g: Rect2i = c["gate"]
		for end in [Vector2(g.position) * TILE, Vector2(g.end) * TILE]:
			_lamp(end, 0.9)
		if c["kind"] == "big":
			_lamp(Vector2(c["keep"].get_center()) * TILE, 1.6)


func _lamp(pos: Vector2, size: float) -> void:
	var l := PointLight2D.new()
	l.texture = Juice.radial()
	l.texture_scale = size
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


func _rect_px(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


func _draw() -> void:
	if main == null:
		return
	var view := _view()
	var floor_tex := Sprites.tex("stone_path")
	# courtyards and gate aprons
	if floor_tex != null:
		for t in main.floors:
			var p := Vector2(t) * TILE
			if view.has_point(p):
				draw_texture_rect(floor_tex, Rect2(p, Vector2(TILE, TILE)), false, Color(0.92, 0.9, 0.95))
	# village ground: a little worn earth around the houses
	for v in layout.get("villages", []):
		for h in v["houses"]:
			var r := _rect_px(h["rect"])
			if r.grow(40).intersects(view):
				_house(r, int(h["seed"]))
		var wl: Vector2i = v["well"]
		if wl.x >= 0 and view.has_point(Vector2(wl) * TILE):
			_well(Vector2(wl) * TILE)
	var castles: Array = layout.get("small", []).duplicate()
	if not layout.get("big", {}).is_empty():
		castles.append(layout["big"])
	for c in castles:
		if _rect_px(c["rect"]).grow(120).intersects(view):
			_castle(c, view)


# --- houses ---

func _house(r: Rect2, seed_v: int) -> void:
	var roof: Color = ROOFS[abs(seed_v) % ROOFS.size()]
	draw_rect(Rect2(r.position + Vector2(5, r.size.y - 8), Vector2(r.size.x, 14)), Color(0.05, 0.03, 0.08, 0.22))
	var wall_h := r.size.y * 0.52
	var body := Rect2(r.position + Vector2(2, r.size.y - wall_h), Vector2(r.size.x - 4, wall_h))
	draw_rect(body, Color(0.86, 0.8, 0.68))
	# timber frame and a stone base
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - 7), Vector2(body.size.x, 7)), Color(0.55, 0.52, 0.5))
	for i in int(body.size.x / 21.0) + 1:
		draw_rect(Rect2(body.position + Vector2(i * 21.0, 0), Vector2(2, body.size.y - 7)), Color(0.45, 0.32, 0.2))
	draw_rect(body, Color(0.3, 0.2, 0.12), false, 1.5)
	# the door and two windows
	var door := Rect2(body.position + Vector2(body.size.x * 0.5 - 6.0, body.size.y - 19.0), Vector2(12, 19))
	draw_rect(door, Color(0.45, 0.28, 0.14))
	draw_rect(door, Color(0.25, 0.15, 0.08), false, 1.2)
	draw_circle(door.position + Vector2(9.5, 10), 1.1, Color(0.9, 0.8, 0.4))
	var dark := clampf(1.0 - main.daylight() * 1.4, 0.0, 1.0)
	for wx in [0.2, 0.74]:
		var w := Rect2(body.position + Vector2(body.size.x * wx - 4.0, 6.0), Vector2(9, 9))
		draw_rect(w, Color(0.45, 0.6, 0.75).lerp(Color(1.0, 0.85, 0.4), dark))
		draw_rect(w, Color(0.3, 0.2, 0.12), false, 1.2)
		draw_line(w.position + Vector2(4.5, 0), w.position + Vector2(4.5, 9), Color(0.3, 0.2, 0.12), 1.0)
	# the roof: overhanging gable with tile rows
	var ro := 5.0
	var top := r.position.y + 2.0
	var roof_pts := PackedVector2Array([Vector2(r.position.x - ro, body.position.y + 3.0), Vector2(r.position.x + r.size.x * 0.5, top), Vector2(r.end.x + ro, body.position.y + 3.0)])
	draw_colored_polygon(roof_pts, roof)
	for k in 4:
		var yy := top + 6.0 + k * 6.0
		var f := (yy - top) / maxf(body.position.y + 3.0 - top, 1.0)
		draw_line(Vector2(lerpf(r.position.x + r.size.x * 0.5, r.position.x - ro, f), yy), Vector2(lerpf(r.position.x + r.size.x * 0.5, r.end.x + ro, f), yy), roof.darkened(0.3), 1.2)
	draw_polyline(roof_pts, roof.darkened(0.5), 1.5)
	# chimney with drifting smoke
	var chim := Vector2(r.position.x + r.size.x * 0.72, top + 4.0)
	draw_rect(Rect2(chim, Vector2(7, 11)), Color(0.5, 0.45, 0.42))
	for i in 3:
		var f2 := fposmod(_t * 0.5 + float(i) * 0.33 + float(seed_v % 7) * 0.1, 1.0)
		draw_circle(chim + Vector2(3.5 + sin(f2 * 5.0 + float(i)) * 3.0, -f2 * 26.0), 2.0 + f2 * 3.5, Color(0.85, 0.85, 0.9, 0.38 * (1.0 - f2)))


func _well(p: Vector2) -> void:
	var c := p + Vector2(TILE, TILE) * 0.5
	draw_circle(c + Vector2(2, 6), 11.0, Color(0, 0, 0, 0.2))
	draw_circle(c, 10.0, Color(0.58, 0.56, 0.55))
	draw_circle(c, 7.5, Color(0.2, 0.4, 0.7))
	draw_arc(c, 8.5, 0.0, TAU, 20, Color(0.35, 0.33, 0.32), 1.5)
	draw_rect(Rect2(c + Vector2(-10, -16), Vector2(2, 14)), Color(0.45, 0.3, 0.16))
	draw_rect(Rect2(c + Vector2(8, -16), Vector2(2, 14)), Color(0.45, 0.3, 0.16))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -15), c + Vector2(0, -24), c + Vector2(13, -15)]), Color(0.65, 0.3, 0.22))


# --- castles ---

func _castle(c: Dictionary, view: Rect2) -> void:
	var rect: Rect2i = c["rect"]
	var big: bool = c["kind"] == "big"
	var roof_col := Color("a83a3a") if big else Color("3a5fa8")
	# the walls, tile by tile
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if main.buildings.get(t, "") == "wall" and view.has_point(Vector2(t) * TILE):
				_wall_tile(Vector2(t) * TILE)
	# the keep (big castle)
	if big and not c["keep"].size == Vector2i.ZERO:
		_keep(_rect_px(c["keep"]), c["gate_dir"])
	# the gate: open wooden doors and a banner either side
	_gate(c)
	# the towers on top of everything
	for tw in c["towers"]:
		_tower(_rect_px(tw), roof_col, big)


func _wall_tile(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(3, 4), Vector2(TILE, TILE)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(p, Vector2(TILE, TILE)), Color(0.6, 0.58, 0.58))
	for row in 4:
		var y := p.y + 8.0 + row * 8.0
		draw_line(Vector2(p.x, y), Vector2(p.x + TILE, y), Color(0.42, 0.4, 0.42), 1.0)
		var off := 8.0 if row % 2 == 0 else 0.0
		for j in 2:
			draw_line(Vector2(p.x + off + j * 16.0, y), Vector2(p.x + off + j * 16.0, y + 8.0), Color(0.42, 0.4, 0.42), 1.0)
	draw_rect(Rect2(p, Vector2(TILE, 8)), Color(0.72, 0.7, 0.7))
	for m in 3:
		draw_rect(Rect2(p + Vector2(m * 11.0 + 1.0, -4.0), Vector2(8, 5)), Color(0.66, 0.64, 0.64))
		draw_rect(Rect2(p + Vector2(m * 11.0 + 1.0, -4.0), Vector2(8, 5)), Color(0.35, 0.33, 0.35), false, 1.0)
	draw_rect(Rect2(p + Vector2(0, TILE - 5), Vector2(TILE, 5)), Color(0.45, 0.43, 0.44))


func _tower(r: Rect2, roof: Color, big: bool) -> void:
	draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.2))
	draw_rect(r, Color(0.66, 0.64, 0.64))
	for row in int(r.size.y / 8.0):
		var y := r.position.y + 8.0 + row * 8.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.45, 0.43, 0.45), 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color(0.76, 0.74, 0.74))
	draw_rect(r, Color(0.32, 0.3, 0.34), false, 1.8)
	# an arrow slit
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.5 - 1.5, r.size.y * 0.45), Vector2(3, 10)), Color(0.12, 0.1, 0.14))
	# the pointed roof, overhanging
	var apex := r.position + Vector2(r.size.x * 0.5, -r.size.y * 0.7)
	var pts := PackedVector2Array([r.position + Vector2(-4, 3), apex, r.position + Vector2(r.size.x + 4, 3)])
	draw_colored_polygon(pts, roof)
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.5, 3), apex, r.position + Vector2(r.size.x + 4, 3)]), roof.darkened(0.22))
	draw_polyline(pts, roof.darkened(0.5), 1.5)
	# a flag waving in the wind
	var pole := apex
	draw_line(pole, pole + Vector2(0, -16), Color(0.35, 0.25, 0.15), 1.5)
	var w := sin(_t * 4.0 + r.position.x) * 2.5
	draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -16), pole + Vector2(11, -13 + w), pole + Vector2(0, -9)]), Color("e8c23a") if big else Color("f0f0f0"))


func _keep(r: Rect2, gate_dir: Vector2i) -> void:
	draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.22))
	draw_rect(r, Color(0.7, 0.68, 0.66))
	for row in int(r.size.y / 10.0):
		var y := r.position.y + 12.0 + row * 10.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.48, 0.46, 0.47), 1.0)
	draw_rect(r, Color(0.3, 0.28, 0.32), false, 2.0)
	# a big door on the side facing the gate, and tall windows
	var door := Rect2(r.position + Vector2(r.size.x * 0.5 - 14.0, r.size.y - 38.0), Vector2(28, 38))
	draw_rect(door, Color(0.4, 0.25, 0.12))
	draw_rect(door, Color(0.2, 0.12, 0.06), false, 1.5)
	draw_line(door.position + Vector2(14, 0), door.position + Vector2(14, 38), Color(0.2, 0.12, 0.06), 1.2)
	var dark := clampf(1.0 - main.daylight() * 1.4, 0.0, 1.0)
	for k in 3:
		var w := Rect2(r.position + Vector2(18.0 + k * 62.0, 30.0), Vector2(14, 22))
		draw_rect(w, Color(0.4, 0.55, 0.75).lerp(Color(1.0, 0.85, 0.4), dark))
		draw_rect(w, Color(0.25, 0.2, 0.2), false, 1.5)
	# a steep slate roof and banners
	var apex := r.position + Vector2(r.size.x * 0.5, -46.0)
	var pts := PackedVector2Array([r.position + Vector2(-8, 6), apex, r.position + Vector2(r.size.x + 8, 6)])
	draw_colored_polygon(pts, Color(0.36, 0.38, 0.5))
	draw_colored_polygon(PackedVector2Array([apex, r.position + Vector2(r.size.x + 8, 6), r.position + Vector2(r.size.x * 0.5, 6)]), Color(0.28, 0.3, 0.42))
	for row in 6:
		var yy := apex.y + 8.0 + row * 8.0
		var f := (yy - apex.y) / (r.position.y + 6.0 - apex.y)
		draw_line(Vector2(lerpf(apex.x, r.position.x - 8.0, f), yy), Vector2(lerpf(apex.x, r.end.x + 8.0, f), yy), Color(0.22, 0.24, 0.34), 1.2)
	draw_polyline(pts, Color(0.15, 0.16, 0.25), 2.0)
	for bx in [0.18, 0.82]:
		var bp := r.position + Vector2(r.size.x * bx, 8.0)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-5, 0), bp + Vector2(5, 0), bp + Vector2(5, 26), bp + Vector2(0, 21), bp + Vector2(-5, 26)]), Color("b22a3a"))


func _gate(c: Dictionary) -> void:
	var g: Rect2 = _rect_px(c["gate"])
	var dir: Vector2i = c["gate_dir"]
	# a stone arch above the opening, and the two doors swung back against the walls
	if dir.x != 0:
		draw_rect(Rect2(g.position + Vector2(-4, -8), Vector2(TILE + 8, 8)), Color(0.55, 0.53, 0.54))
		draw_rect(Rect2(g.position + Vector2(-4, g.size.y), Vector2(TILE + 8, 8)), Color(0.55, 0.53, 0.54))
		draw_rect(Rect2(g.position + Vector2(10, -2), Vector2(12, 3)), Color(0.4, 0.25, 0.12))
		draw_rect(Rect2(g.position + Vector2(10, g.size.y - 1), Vector2(12, 3)), Color(0.4, 0.25, 0.12))
	else:
		draw_rect(Rect2(g.position + Vector2(-8, -4), Vector2(8, TILE + 8)), Color(0.55, 0.53, 0.54))
		draw_rect(Rect2(g.position + Vector2(g.size.x, -4), Vector2(8, TILE + 8)), Color(0.55, 0.53, 0.54))
		draw_rect(Rect2(g.position + Vector2(-2, 10), Vector2(3, 12)), Color(0.4, 0.25, 0.12))
		draw_rect(Rect2(g.position + Vector2(g.size.x - 1, 10), Vector2(3, 12)), Color(0.4, 0.25, 0.12))

extends Node2D
## Life and weather on top of the map, drawn around the camera and never touching gameplay:
##   meadow   butterflies by day, fireflies at night      snow     drifting flakes
##   desert   blown dust and now and then tumbling grit    swamp    fireflies and rising spores
##   graveyard pale wisps and a few crows                  autumn   falling leaves
## Every few minutes the weather turns: rain (snow flurries in the snow) or a drifting fog, for about a minute.

const Biomes := preload("res://biomes.gd")

const BUDGET := 80

var main: Node2D
var weather := "clear"
var weather_left := 0.0
var next_weather := 150.0
var _t := 0.0
var _odd := false
var _parts: Array = []     ## {k kind, p position, v velocity, life, max, s seed}
var _crows := 0
var _fog := 0.0            ## 0..1 fade of the fog overlay
var _rain := 0.0           ## 0..1 fade of the rain
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 60   # over everything in the world, under the HUD
	_rng.randomize()
	next_weather = _rng.randf_range(150.0, 240.0)


func _view() -> Rect2:
	if main == null or main.cam == null:
		return Rect2()
	var c: Vector2 = main.cam.get_screen_center_position()
	var half: Vector2 = get_viewport_rect().size / main.cam.zoom * 0.5 + Vector2(40, 40)
	return Rect2(c - half, half * 2.0)


func _biome_at(p: Vector2) -> int:
	return int(main.biome.get(main.tile_of(p), 0))


func _process(delta: float) -> void:
	if main == null or main.cam == null:
		return
	_t += delta
	_update_weather(delta)
	var view := _view()
	# move and retire
	for i in range(_parts.size() - 1, -1, -1):
		var q: Dictionary = _parts[i]
		q["life"] -= delta
		var kind: String = q["k"]
		q["p"] += q["v"] * delta
		match kind:
			"butterfly", "firefly", "spore", "wisp":
				q["v"] = (q["v"] + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-40, 40)) * delta).limit_length(32.0 if kind != "wisp" else 16.0)
				if kind == "spore" or kind == "wisp":
					q["v"] += Vector2(0, -14.0 * delta)
			"snow", "leaf":
				q["v"].x += sin(_t * 2.0 + float(q["s"])) * 30.0 * delta
		if q["life"] <= 0.0 or not view.grow(60.0).has_point(q["p"]):
			if kind == "crow":
				_crows = maxi(_crows - 1, 0)
			var hit: bool = kind == "rain" and q["life"] <= 0.0 and _rng.randf() < 0.6
			var at: Vector2 = q["p"]
			_parts.remove_at(i)
			if hit:
				_parts.append({"k": "splash", "p": at, "v": Vector2.ZERO, "life": 0.22, "max": 0.22, "s": 0.0})
	_spawn(view, delta)
	_odd = not _odd
	if _odd:
		queue_redraw()  # drawn every other frame: the motion is slow, and recording the drawing costs


func _spawn(view: Rect2, delta: float) -> void:
	if _parts.size() < BUDGET:
		for attempt in 3:
			var p := view.position + Vector2(_rng.randf() * view.size.x, _rng.randf() * view.size.y)
			var b := _biome_at(p)
			var night: bool = main.is_night()
			var kind := ""
			match b:
				Biomes.SNOW:
					kind = "snow"
				Biomes.DESERT:
					kind = "dust"
				Biomes.SWAMP:
					kind = "firefly" if _rng.randf() < 0.5 else "spore"
				Biomes.GRAVEYARD:
					kind = "wisp"
				Biomes.AUTUMN:
					kind = "leaf"
				_:
					kind = "firefly" if night else ("butterfly" if _rng.randf() < 0.5 else "")
			var chance := 0.35
			if kind == "wisp" or kind == "spore":
				chance = 0.12
			elif kind == "dust":
				chance = 0.2
			if kind == "" or _rng.randf() > chance:
				continue
			_parts.append(_make(kind, p, view))
	# a rare crow over the graveyard
	if _crows < 3 and _rng.randf() < delta * 0.25:
		var p2 := Vector2(view.position.x - 20.0, view.position.y + _rng.randf() * view.size.y * 0.6)
		if _biome_at(view.get_center()) == Biomes.GRAVEYARD:
			_crows += 1
			_parts.append({"k": "crow", "p": p2, "v": Vector2(_rng.randf_range(55, 85), _rng.randf_range(-8, 8)), "life": 14.0, "max": 14.0, "s": _rng.randf() * 9.0})
	# weather particles: rain or flurries
	if _rain > 0.05:
		var n := int(ceil(float(BUDGET) * 1.5 * _rain * delta * 10.0 * 0.12))
		for k in n:
			# drops start anywhere over the view and fall for a moment, so the whole screen gets rain
			var p3 := view.position + Vector2(_rng.randf() * view.size.x, _rng.randf() * view.size.y - 40.0)
			var snowy := _biome_at(p3) == Biomes.SNOW
			var life := _rng.randf_range(0.25, 0.55) if not snowy else 3.5
			_parts.append({"k": "flurry" if snowy else "rain", "p": p3, "v": Vector2(-30, 55) if snowy else Vector2(-70, 400), "life": life, "max": life, "s": _rng.randf() * 9.0})


func _make(kind: String, p: Vector2, view: Rect2) -> Dictionary:
	var v := Vector2.ZERO
	var life := 8.0
	match kind:
		"snow":
			v = Vector2(_rng.randf_range(-8, 8), _rng.randf_range(24, 44))
			life = 10.0
		"dust":
			v = Vector2(_rng.randf_range(30, 55), _rng.randf_range(-4, 4))
			life = 5.0
		"leaf":
			v = Vector2(_rng.randf_range(-12, 12), _rng.randf_range(18, 30))
			life = 10.0
		"butterfly", "firefly":
			v = Vector2.from_angle(_rng.randf() * TAU) * 14.0
			life = _rng.randf_range(6.0, 12.0)
		"spore", "wisp":
			v = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-14, -6))
			life = _rng.randf_range(5.0, 9.0)
	return {"k": kind, "p": p, "v": v, "life": life, "max": life, "s": _rng.randf() * 9.0}


func _update_weather(delta: float) -> void:
	if weather == "clear":
		next_weather -= delta
		if next_weather <= 0.0:
			weather = "rain" if _rng.randf() < 0.65 else "fog"
			weather_left = _rng.randf_range(40.0, 70.0)
			if main.has_method("_say"):
				main._say("It starts to rain..." if weather == "rain" else "A fog rolls in...")
	else:
		weather_left -= delta
		if weather_left <= 0.0:
			weather = "clear"
			next_weather = _rng.randf_range(120.0, 300.0)
	_rain = move_toward(_rain, 1.0 if weather == "rain" else 0.0, delta * 0.4)
	_fog = move_toward(_fog, 1.0 if weather == "fog" else 0.0, delta * 0.3)


## A convex ellipse as a polygon (soft fog banks and glows).
func _ell(c: Vector2, rx: float, ry: float, col: Color, n: int = 16) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	if main == null or main.cam == null:
		return
	var view := _view()
	# a cool, darker wash while it rains
	if _rain > 0.01:
		draw_rect(view, Color(0.08, 0.12, 0.22, 0.22 * _rain))
	# fog: a pale veil, and wide soft banks drifting slowly across, each built from stacked faint ellipses
	if _fog > 0.01:
		draw_rect(view, Color(0.76, 0.8, 0.88, 0.14 * _fog))
		for k in 6:
			var f := fposmod(_t * 0.012 + float(k) * 0.167, 1.0)
			var c := Vector2(view.position.x + f * (view.size.x + 400.0) - 200.0, view.position.y + view.size.y * (0.1 + 0.8 * fposmod(float(k) * 0.37, 1.0)))
			c.y += sin(_t * 0.2 + k) * 10.0
			for j in 4:
				var g := 1.0 - 0.2 * j
				_ell(c, 190.0 * g, 46.0 * g, Color(0.86, 0.89, 0.95, 0.06 * _fog))
	for q in _parts:
		var p: Vector2 = q["p"]
		var f: float = clampf(float(q["life"]) / float(q["max"]), 0.0, 1.0)
		var fade := minf(f * 3.0, 1.0) * minf((1.0 - f) * 6.0 + 0.2, 1.0)
		match q["k"]:
			"snow":
				draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 1, 0.85 * fade))
			"flurry":
				draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1, 1, 1, 0.9))
			"rain":
				var dir: Vector2 = Vector2(q["v"]).normalized()
				draw_line(p - dir * 16.0, p, Color(0.74, 0.84, 1.0, 0.42), 1.0)
				draw_line(p - dir * 5.0, p, Color(0.9, 0.95, 1.0, 0.75), 1.0)
			"splash":
				# a tiny crown of droplets where a drop lands
				var k2 := 1.0 - f
				var up := -2.0 - 2.0 * k2 + 4.0 * k2 * k2
				draw_line(p + Vector2(-1, 0), p + Vector2(-3.0 - 2.0 * k2, up), Color(0.85, 0.92, 1.0, 0.7 * f), 1.0)
				draw_line(p + Vector2(1, 0), p + Vector2(3.0 + 2.0 * k2, up), Color(0.85, 0.92, 1.0, 0.7 * f), 1.0)
				draw_line(p + Vector2(-2.0 - 3.0 * k2, 1), p + Vector2(2.0 + 3.0 * k2, 1), Color(0.8, 0.9, 1.0, 0.35 * f), 1.0)
			"dust":
				draw_line(p, p + Vector2(-4, 0), Color(0.9, 0.78, 0.55, 0.4 * fade), 1.0)
			"leaf":
				var a: float = _t * 2.5 + float(q["s"])
				draw_colored_polygon(PackedVector2Array([p + Vector2(cos(a), sin(a)) * 3.0, p + Vector2(cos(a + 2.1), sin(a + 2.1)) * 1.6, p + Vector2(cos(a + 4.2), sin(a + 4.2)) * 1.6]), Color(0.9, 0.45 + 0.3 * fposmod(float(q["s"]), 1.0), 0.12, 0.9 * fade))
			"butterfly":
				var flap := absf(sin(_t * 14.0 + float(q["s"])))
				var col := Color.from_hsv(fposmod(float(q["s"]) * 0.17, 1.0), 0.55, 1.0, 0.95 * fade)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(-4, -3.0 * flap - 1), p + Vector2(-2, 2)]), col)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(4, -3.0 * flap - 1), p + Vector2(2, 2)]), col)
			"firefly":
				var pulse := 0.5 + 0.5 * sin(_t * 3.0 + float(q["s"]) * 2.0)
				draw_circle(p, 4.0, Color(0.8, 1.0, 0.4, 0.14 * pulse * fade))
				draw_circle(p, 1.4, Color(1.0, 1.0, 0.6, (0.55 + 0.4 * pulse) * fade))
			"spore":
				draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(0.6, 0.95, 0.5, 0.45 * fade))
			"wisp":
				# a pale soul light with a short tail that sways behind it
				var pw := 0.5 + 0.5 * sin(_t * 2.0 + float(q["s"]))
				var tail := Vector2(sin(_t * 1.7 + float(q["s"])) * 3.0, 6.0)
				_ell(p, 7.0, 6.0, Color(0.55, 0.6, 1.0, 0.08 * fade), 10)
				draw_line(p, p + tail, Color(0.7, 0.75, 1.0, 0.25 * fade), 2.0)
				draw_circle(p, 2.0, Color(0.82, 0.88, 1.0, (0.4 + 0.35 * pw) * fade))
			"crow":
				var wing := sin(_t * 12.0 + float(q["s"])) * 4.0
				draw_line(p + Vector2(-6, wing), p, Color(0.05, 0.04, 0.08), 2.0)
				draw_line(p, p + Vector2(6, wing), Color(0.05, 0.04, 0.08), 2.0)
				draw_circle(p, 1.8, Color(0.05, 0.04, 0.08))

extends Node2D
## The start spot: a patch of living flesh with a small blood pit in the middle, ringed with bone teeth and swaying
## tentacles, like the maw of something buried under the village. 小怪 begins his run beside it. Standing at its rim
## mends a little health (one HP every few seconds), so it is a place to fall back to.

const Popups := preload("res://popups.gd")

const RADIUS := 112.0         ## the flesh patch
const POOL := Vector2(28.0, 20.0)
const HEAL_RADIUS := 52.0
const HEAL_EVERY := 3.0

var heals := true            ## the rival's lair is the same nest, smaller, and mends nobody
var _t := 0.0
var _redraw_in := 0.0
var _heal := 0.0
var _lumps: Array = []        ## [offset, radius, shade]
var _veins: Array = []        ## polylines of points, from the pit outward
var _arms: Array = []         ## [angle, length, phase]
var _teeth: Array = []        ## [angle, size, lean]
var _eyes: Array = []         ## [offset, phase]
var _pebbles: Array = []


func _ready() -> void:
	z_index = -4   # on the ground: above the meadow, under everything that walks
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in 26:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * RADIUS * 0.8
		_lumps.append([Vector2.from_angle(a) * d, rng.randf_range(14.0, 34.0), rng.randf()])
	for i in 9:
		var a := float(i) / 9.0 * TAU + rng.randf_range(-0.2, 0.2)
		var pts: Array = []
		var p := Vector2.from_angle(a) * 30.0
		var dir := a
		for k in 6:
			pts.append(p)
			dir += rng.randf_range(-0.5, 0.5)
			p += Vector2.from_angle(dir) * rng.randf_range(10.0, 18.0)
		_veins.append(pts)
	for i in 7:
		_arms.append([float(i) / 7.0 * TAU + rng.randf_range(-0.15, 0.15), rng.randf_range(46.0, 70.0), rng.randf() * TAU])
	for i in 16:
		_teeth.append([float(i) / 16.0 * TAU + rng.randf_range(-0.06, 0.06), rng.randf_range(7.0, 12.0), rng.randf_range(-0.25, 0.25)])
	for i in 4:
		var a := rng.randf() * TAU
		_eyes.append([Vector2.from_angle(a) * rng.randf_range(62.0, 96.0), rng.randf() * TAU])
	for i in 12:
		var a := rng.randf() * TAU
		_pebbles.append(Vector2.from_angle(a) * rng.randf_range(40.0, 100.0))


func _process(delta: float) -> void:
	_t += delta
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	var d: float = pl.global_position.distance_to(global_position)
	if heals and d < HEAL_RADIUS and pl.hp > 0 and pl.hp < pl.max_hp:
		_heal += delta
		if _heal >= HEAL_EVERY:
			_heal = 0.0
			pl.hp = mini(pl.max_hp, pl.hp + 1)
			pl.hp_changed.emit(pl.hp)
			Popups.text(get_tree(), pl.global_position + Vector2(0, -24), "+1", Popups.HEAL, 13)
	else:
		_heal = 0.0
	_redraw_in -= delta
	if d < 900.0 and _redraw_in <= 0.0:
		_redraw_in = 0.045  # about 20 redraws a second is plenty for the slow motion
		queue_redraw()


func _draw() -> void:
	var tm := _t
	# a red glow on the ground around the whole patch
	for i in 5:
		var f := float(i) / 5.0
		draw_circle(Vector2.ZERO, RADIUS * (1.15 - 0.2 * f), Color(0.5, 0.05, 0.08, 0.05 + 0.03 * f))
	# living flesh: overlapping lumps, darker at the edge, with a wet sheen that pulses
	var beat := 0.5 + 0.5 * sin(tm * 1.6)
	for l in _lumps:
		var shade: float = l[2]
		var c := Color(0.36 + 0.22 * shade, 0.07 + 0.06 * shade, 0.1 + 0.06 * shade, 0.78)
		draw_circle(l[0], l[1], c)
		draw_circle(l[0] + Vector2(-l[1] * 0.25, -l[1] * 0.3), l[1] * 0.35, Color(0.62, 0.16, 0.2, 0.18 + 0.1 * beat))
	# veins running out from the pit, throbbing
	for v in _veins:
		var pts := PackedVector2Array()
		for p in v:
			pts.append(p)
		draw_polyline(pts, Color(0.72, 0.12, 0.16, 0.55 + 0.25 * beat), 2.0)
		draw_polyline(pts, Color(0.35, 0.04, 0.08, 0.7), 4.0)
	# little bones and ribs scattered on the flesh
	for pb in _pebbles:
		draw_line(pb + Vector2(-3, 1), pb + Vector2(3, -1), Color(0.88, 0.82, 0.66), 2.0)
		draw_circle(pb + Vector2(3, -1), 1.4, Color(0.92, 0.86, 0.7))
	# the raised rim of the pit
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.78))
	draw_circle(Vector2.ZERO, POOL.x + 14.0, Color(0.16, 0.04, 0.08))
	draw_circle(Vector2.ZERO, POOL.x + 9.0, Color(0.3, 0.08, 0.12))
	# the pool: dark blood with a deep centre
	draw_circle(Vector2.ZERO, POOL.x + 3.0, Color(0.12, 0.01, 0.03))
	draw_circle(Vector2.ZERO, POOL.x, Color(0.46, 0.03, 0.07))
	draw_circle(Vector2(0, 2), POOL.x * 0.62, Color(0.28, 0.01, 0.04))
	draw_circle(Vector2.ZERO, POOL.x * 0.3, Color(0.06, 0.0, 0.01))
	# ripples spreading across it
	for k in 3:
		var f := fposmod(tm * 0.5 + float(k) / 3.0, 1.0)
		draw_arc(Vector2.ZERO, POOL.x * (0.2 + 0.8 * f), 0.0, TAU, 28, Color(1.0, 0.35, 0.35, 0.5 * (1.0 - f)), 1.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# bubbles that swell and pop
	for k in 5:
		var f := fposmod(tm * 0.7 + float(k) * 0.37, 1.0)
		var ang := float(k) * 1.9
		var pos := Vector2.from_angle(ang) * POOL.x * 0.55 * (0.4 + 0.6 * fposmod(float(k) * 0.43, 1.0))
		pos.y *= 0.78
		if f < 0.85:
			draw_circle(pos, 1.0 + 3.0 * f, Color(0.85, 0.2, 0.22, 0.65))
			draw_circle(pos + Vector2(-1, -1), 0.8, Color(1, 0.8, 0.8, 0.6))
		else:
			draw_arc(pos, 4.0 + 8.0 * (f - 0.85), 0.0, TAU, 10, Color(1, 0.5, 0.5, 0.6 * (1.0 - (f - 0.85) / 0.15)), 1.0)
	# blood drips rising and falling back in
	for k in 4:
		var f := fposmod(tm * 0.9 + float(k) * 0.25, 1.0)
		var x := (float(k) - 1.5) * 9.0
		var y := -10.0 - 22.0 * sin(f * PI)
		draw_circle(Vector2(x, y), 1.8 * (1.0 - 0.4 * f), Color(0.8, 0.08, 0.1, 0.9 * (1.0 - f * 0.4)))
	# the tentacles: swaying arms with pale suckers, reaching out of the flesh
	for a in _arms:
		var ang: float = a[0]
		var ln: float = a[1]
		var ph: float = a[2]
		var pts := PackedVector2Array()
		var seg := 9
		for i in range(seg + 1):
			var u := float(i) / seg
			var sway := sin(tm * 1.4 + ph + u * 3.0) * 8.0 * u
			var base := Vector2.from_angle(ang) * (POOL.x + 10.0 + ln * u)
			pts.append(base + Vector2.from_angle(ang + PI * 0.5) * sway + Vector2(0, -6.0 * sin(u * PI)))
		draw_polyline(pts, Color(0.16, 0.07, 0.15), 8.0)
		draw_polyline(pts, Color(0.3, 0.14, 0.26), 5.0)
		for i in range(2, seg, 2):
			draw_circle(pts[i] + Vector2(0, 1), 1.6, Color(0.9, 0.78, 0.66, 0.8))
		draw_circle(pts[seg], 3.0, Color(0.3, 0.14, 0.26))
	# the bone teeth ringing the rim, a little different each, leaning in
	for t in _teeth:
		var ang: float = t[0]
		var sz: float = t[1]
		var base := Vector2.from_angle(ang) * (POOL.x + 6.0)
		base.y *= 0.78
		var inward := -Vector2.from_angle(ang + float(t[2]))
		inward.y *= 0.78
		var side := inward.orthogonal()
		var tip := base + inward * sz * 1.5 + Vector2(0, -sz * 0.5)
		draw_colored_polygon(PackedVector2Array([base + side * sz * 0.38, base - side * sz * 0.38, tip]), Color(0.93, 0.85, 0.58))
		draw_colored_polygon(PackedVector2Array([base, base - side * sz * 0.38, tip]), Color(0.74, 0.62, 0.38))
	# eyes that open and close on the flesh, watching
	for e in _eyes:
		var open := maxf(sin(tm * 0.9 + float(e[1])), -0.2) * 0.5 + 0.5
		var p: Vector2 = e[0]
		draw_circle(p, 5.0, Color(0.2, 0.04, 0.07))
		draw_circle(p, 3.6 * open + 0.4, Color(0.95, 0.85, 0.3))
		draw_circle(p + Vector2(0.6, 0), 1.4 * open, Color(0.1, 0.0, 0.0))

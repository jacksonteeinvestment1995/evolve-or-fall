class_name SkillFx
extends Node2D
## Styled skill effects drawn in code: tooth marks for bites, flying bones for Bone Nova, a ghost wisp
## for Spirit Bolt, shockwave arcs for Roar, cracked rays for Final Calamity. Zones and bolts call the
## static draw_* helpers from their own _draw; tooth marks are short-lived nodes (spawn_tooth).

var kind := "tooth"
var dir := Vector2.RIGHT
var sc := 1.0
var age := 0.0
var life := 0.5


static func spawn_tooth(parent: Node, pos: Vector2, bite_dir: Vector2, scale: float = 1.0) -> void:
	if parent == null:
		return
	var fx := SkillFx.new()
	fx.kind = "tooth"
	fx.position = pos
	fx.dir = bite_dir if bite_dir != Vector2.ZERO else Vector2.RIGHT
	fx.sc = scale
	fx.z_index = 15
	parent.add_child(fx)


func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if kind == "tooth":
		draw_tooth(self, dir, sc, age / life)


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


## Two rows of fangs close on the target, leave a toothed bite mark, and flick out a few blood drops.
static func draw_tooth(ci: CanvasItem, dir: Vector2, sc: float, t: float) -> void:
	var side := dir.rotated(PI * 0.5)
	var close := clampf(t / 0.28, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.55, 1.0, t)
	var gap := lerpf(11.0, 2.2, _ease_out(close)) * sc
	var teeth := 6
	for row in [-1, 1]:
		for i in teeth:
			var u := (float(i) / (teeth - 1) - 0.5) * 2.0          # -1 .. 1 along the jaw
			var along := side * u * 11.0 * sc
			var curve := dir * float(row) * (gap + u * u * 4.0 * sc)   # jaws curve around the target
			var base: Vector2 = along + curve
			var tip: Vector2 = base - dir * float(row) * (5.5 - absf(u) * 2.0) * sc
			var w := side * 1.7 * sc
			ci.draw_colored_polygon(PackedVector2Array([base - w, base + w, tip]), Color(0.96, 0.93, 0.84, alpha))
			ci.draw_colored_polygon(PackedVector2Array([tip - w * 0.35 + (base - tip) * 0.35, tip + w * 0.35 + (base - tip) * 0.35, tip]), Color(0.62, 0.08, 0.12, alpha))
	if close >= 1.0:
		# the dents the teeth leave behind
		for row in [-1, 1]:
			for i in teeth:
				var u2 := (float(i) / (teeth - 1) - 0.5) * 2.0
				var p: Vector2 = side * u2 * 11.0 * sc + dir * float(row) * (gap + u2 * u2 * 4.0 * sc)
				ci.draw_circle(p, 1.1 * sc, Color(0.45, 0.04, 0.08, alpha * 0.9))
		for k in 3:
			var ang := dir.angle() + (k - 1) * 0.9 + 1.2
			var d := (t - 0.28) * 55.0 * sc
			ci.draw_circle(Vector2.from_angle(ang) * d + Vector2(0, d * d * 0.012), 1.6 * sc, Color(0.8, 0.08, 0.1, alpha))


static func _bone(ci: CanvasItem, pos: Vector2, ang: float, len: float, col: Color) -> void:
	var a := Vector2.from_angle(ang) * len * 0.5
	var n := Vector2.from_angle(ang + PI * 0.5) * 1.5
	ci.draw_line(pos - a, pos + a, col, 2.2)
	for end in [-1.0, 1.0]:
		var e: Vector2 = pos + a * end
		ci.draw_circle(e + n, 1.7, col)
		ci.draw_circle(e - n, 1.7, col)


## Bone Nova: a ring of bones spinning outward, with white sparks and a flash at the centre.
static func draw_bone_nova(ci: CanvasItem, radius: float, t: float, tint: Color) -> void:
	var e := _ease_out(clampf(t, 0.0, 1.0))
	var a := 1.0 - smoothstep(0.55, 1.0, t)
	ci.draw_circle(Vector2.ZERO, radius * 0.5 * (1.0 - t), Color(tint.lightened(0.5), 0.35 * (1.0 - t)))
	for i in 11:
		var ang := float(i) * TAU / 11.0 + 0.2
		var r := radius * (0.2 + 0.8 * e) * (0.88 + 0.12 * sin(float(i) * 2.3))
		_bone(ci, Vector2.from_angle(ang) * r, ang + t * 9.0 + float(i), 11.0, Color(0.95, 0.92, 0.82, a))
	for i in 18:
		var ang2 := float(i) * TAU / 18.0 + 0.5 + sin(float(i) * 7.1) * 0.15
		var r2 := radius * (0.3 + 0.75 * e) * (0.7 + 0.3 * fposmod(float(i) * 0.37, 1.0))
		var c := Vector2.from_angle(ang2) * r2
		var s := (1.5 + fposmod(float(i) * 0.61, 1.0) * 1.5) * (1.0 - t * 0.6)
		var col := Color(1, 1, 1, a) if i % 2 == 0 else Color(tint.lightened(0.4), a)
		ci.draw_line(c - Vector2(s, 0), c + Vector2(s, 0), col, 1.2)
		ci.draw_line(c - Vector2(0, s), c + Vector2(0, s), col, 1.2)
	ci.draw_arc(Vector2.ZERO, radius * e, 0.0, TAU, 40, Color(tint.lightened(0.6), a * 0.55), 1.5)


## Roar: three jagged shockwave arcs and radiating sound lines.
static func draw_roar(ci: CanvasItem, radius: float, t: float, tint: Color) -> void:
	var e := _ease_out(clampf(t, 0.0, 1.0))
	var a := 1.0 - smoothstep(0.45, 1.0, t)
	for k in 3:
		var r := radius * e * (0.45 + 0.27 * k)
		var pts := PackedVector2Array()
		for j in 49:
			var ang := float(j) / 48.0 * TAU
			pts.append(Vector2.from_angle(ang) * (r + sin(ang * 11.0 + float(k) * 2.0) * 2.2))
		ci.draw_polyline(pts, Color(tint.lightened(0.25 * float(k)), a * (0.9 - 0.2 * float(k))), 2.4 - 0.4 * float(k))
	for j in 14:
		var ang2 := float(j) / 14.0 * TAU + 0.2
		ci.draw_line(Vector2.from_angle(ang2) * radius * e * 0.5, Vector2.from_angle(ang2) * radius * e * 0.82, Color(1, 0.95, 0.8, a * 0.7), 1.6)


## Final Calamity: a dark red pool, cracks racing outward and a jagged ring.
static func draw_doom(ci: CanvasItem, radius: float, t: float, tint: Color) -> void:
	var e := _ease_out(clampf(t, 0.0, 1.0))
	var a := 1.0 - smoothstep(0.6, 1.0, t)
	ci.draw_circle(Vector2.ZERO, radius * e, Color(0.25, 0.0, 0.05, 0.3 * a))
	for j in 16:
		var ang := float(j) / 16.0 * TAU + 0.1
		var pts := PackedVector2Array([Vector2.ZERO])
		var d := radius * e
		for s in range(1, 7):
			var frac := float(s) / 6.0
			pts.append(Vector2.from_angle(ang + sin(float(j * 7 + s * 3)) * 0.12) * d * frac)
		ci.draw_polyline(pts, Color(1.0, 0.45 + 0.4 * fposmod(float(j) * 0.37, 1.0), 0.3, a), 2.0)
	var ring := PackedVector2Array()
	for j in 61:
		var ang2 := float(j) / 60.0 * TAU
		ring.append(Vector2.from_angle(ang2) * (radius * e + sin(ang2 * 17.0) * 3.0))
	ci.draw_polyline(ring, Color(tint.lightened(0.3), a), 3.0)


## Spirit Bolt: a ghost wisp with hollow eyes and a wavering tail of fading flame.
static func draw_wisp(ci: CanvasItem, dir: Vector2, radius: float, tint: Color) -> void:
	var tm := Time.get_ticks_msec() * 0.012
	var back := -dir
	var side := dir.rotated(PI * 0.5)
	for i in 6:
		var f := float(i + 1) / 6.0
		var wob := sin(tm + float(i) * 1.3) * 3.5 * f
		var c := back * f * radius * 3.4 + side * wob
		ci.draw_circle(c, radius * (1.0 - f * 0.75), Color(tint, 0.5 * (1.0 - f)))
	for i in 4:
		var f2 := fposmod(tm * 0.06 + float(i) * 0.27, 1.0)
		ci.draw_circle(back * f2 * radius * 4.0 + side * sin(float(i) * 5.0 + tm * 0.5) * radius * 1.1, 1.2, Color(1, 1, 1, 1.0 - f2))
	ci.draw_circle(Vector2.ZERO, radius * 1.15, Color(tint, 0.35))
	ci.draw_circle(Vector2.ZERO, radius, Color(0.92, 0.88, 1.0))
	var eye_a := side * radius * 0.38
	ci.draw_circle(dir * radius * 0.25 + eye_a, radius * 0.22, Color(0.15, 0.1, 0.3))
	ci.draw_circle(dir * radius * 0.25 - eye_a, radius * 0.22, Color(0.15, 0.1, 0.3))

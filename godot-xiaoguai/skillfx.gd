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
var tint := Color.WHITE


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
	elif kind == "levelup":
		draw_levelup(self, age / life)
	else:
		draw_special(self, kind, age / life, dir, sc, tint)


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


## Styled player bolts for the volley skills: acid, spear, orb, glob, fire, claw, seed, rock and hell.
static func draw_bolt(ci: CanvasItem, style: String, dir: Vector2, radius: float, tint: Color) -> void:
	var tm := Time.get_ticks_msec() * 0.01
	var side := dir.rotated(PI * 0.5)
	match style:
		"axe":
			# a spinning axe: a handle with a curved blade, turning as it flies
			var spin := tm * 1.6
			var d2 := Vector2.from_angle(spin)
			var n2 := d2.orthogonal()
			ci.draw_line(-d2 * radius * 1.6, d2 * radius * 1.6, Color(0.5, 0.33, 0.18), 2.4)
			ci.draw_colored_polygon(PackedVector2Array([d2 * radius * 1.7 + n2 * radius * 0.2, d2 * radius * 0.7 + n2 * radius * 1.9, d2 * radius * 0.2 + n2 * radius * 0.4, d2 * radius * 0.9 - n2 * radius * 0.2]), Color(0.78, 0.8, 0.86))
			ci.draw_polyline(PackedVector2Array([d2 * radius * 1.7 + n2 * radius * 0.2, d2 * radius * 0.7 + n2 * radius * 1.9, d2 * radius * 0.2 + n2 * radius * 0.4]), Color(0.3, 0.32, 0.38), 1.2)
		"net":
			# a woven net: a ring with crossing strands
			ci.draw_arc(Vector2.ZERO, radius * 1.7, 0, TAU, 16, Color(0.92, 0.92, 0.96), 1.6)
			for k in 3:
				var an := float(k) / 3.0 * PI + tm * 0.2
				ci.draw_line(Vector2.from_angle(an) * radius * 1.7, -Vector2.from_angle(an) * radius * 1.7, Color(0.92, 0.92, 0.96, 0.9), 1.1)
			ci.draw_arc(Vector2.ZERO, radius * 0.9, 0, TAU, 12, Color(0.92, 0.92, 0.96, 0.8), 1.0)
		"javelin":
			# a long barbed javelin
			ci.draw_line(-dir * radius * 4.0, dir * radius * 1.6, Color(0.55, 0.4, 0.25), 2.2)
			ci.draw_colored_polygon(PackedVector2Array([dir * radius * 3.0, dir * radius * 1.4 + side * 3.0, dir * radius * 1.4 - side * 3.0]), Color(0.9, 0.9, 0.95))
			ci.draw_line(-dir * radius * 4.0 + side * 2.5, -dir * radius * 3.2, Color(0.8, 0.2, 0.2), 1.6)
			ci.draw_line(-dir * radius * 4.0 - side * 2.5, -dir * radius * 3.2, Color(0.8, 0.2, 0.2), 1.6)
		"arrow":
			# a feathered arrow
			ci.draw_line(-dir * radius * 3.2, dir * radius * 1.8, Color(0.6, 0.45, 0.28), 1.8)
			ci.draw_colored_polygon(PackedVector2Array([dir * radius * 3.0, dir * radius * 1.6 + side * 2.4, dir * radius * 1.6 - side * 2.4]), Color(0.85, 0.87, 0.92))
			for sgn in [-1.0, 1.0]:
				ci.draw_line(-dir * radius * 3.2, -dir * radius * 4.0 + side * sgn * 2.6, Color(0.85, 0.25, 0.25), 1.4)
		"mud":
			# a lump of mud that drips
			ci.draw_circle(Vector2.ZERO, radius * 1.2, Color(0.4, 0.28, 0.14))
			ci.draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.4, Color(0.55, 0.4, 0.22))
			for i in 3:
				ci.draw_circle(-dir * (radius * (1.4 + float(i) * 0.9)) + side * sin(tm + float(i) * 2.0) * radius * 0.5, 1.6 - 0.3 * float(i), Color(0.4, 0.28, 0.14, 0.8))
		"fire":
			for i in 5:
				var f := float(i + 1) / 5.0
				ci.draw_circle(-dir * f * radius * 3.2 + side * sin(tm + float(i)) * 2.0, radius * (1.0 - f * 0.7), Color(1.0, 0.45 + 0.4 * f, 0.1, 0.7 * (1.0 - f)))
			ci.draw_circle(Vector2.ZERO, radius * 1.1, Color(1.0, 0.5, 0.1))
			ci.draw_circle(Vector2.ZERO, radius * 0.65, Color(1.0, 0.9, 0.4))
		"acid":
			ci.draw_circle(Vector2.ZERO, radius * 1.1 + sin(tm * 1.5) * 0.6, Color(0.35, 0.8, 0.2))
			ci.draw_circle(-side * radius * 0.4 - dir * radius * 0.3, radius * 0.4, Color(0.7, 1.0, 0.4))
			for i in 3:
				ci.draw_circle(-dir * (radius * (1.4 + float(i))) + side * sin(tm + float(i) * 2.0) * radius * 0.7, 1.4, Color(0.5, 0.9, 0.3, 0.7))
		"spear":
			var d := Vector2.from_angle(dir.angle() + sin(tm * 0.8) * 0.35)
			var n := d.rotated(PI * 0.5)
			ci.draw_line(-d * radius * 2.4, d * radius * 1.4, Color(0.93, 0.9, 0.78), 2.2)
			ci.draw_colored_polygon(PackedVector2Array([d * radius * 2.6, d * radius * 1.2 + n * 2.2, d * radius * 1.2 - n * 2.2]), Color(1, 1, 0.95))
			ci.draw_circle(-d * radius * 2.4 + n * 1.4, 1.5, Color(0.93, 0.9, 0.78))
			ci.draw_circle(-d * radius * 2.4 - n * 1.4, 1.5, Color(0.93, 0.9, 0.78))
		"orb":
			ci.draw_circle(Vector2.ZERO, radius * 1.5, Color(tint, 0.25))
			ci.draw_circle(Vector2.ZERO, radius, Color(tint.lightened(0.5), 0.8))
			ci.draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
			for i in 3:
				ci.draw_circle(Vector2.from_angle(tm * 0.5 + float(i) * TAU / 3.0) * radius * 1.7, 1.3, Color(1, 1, 1, 0.9))
		"glob":
			var sq := 1.0 + sin(tm * 1.2) * 0.12
			ci.draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(sq, 1.0 / sq))
			ci.draw_circle(Vector2.ZERO, radius * 1.15, Color(0.25, 0.55, 1.0))
			ci.draw_circle(Vector2(-radius * 0.3, -radius * 0.4), radius * 0.4, Color(0.7, 0.9, 1.0))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_circle(-dir * radius * 1.8, radius * 0.5, Color(0.25, 0.55, 1.0, 0.6))
		"claw":
			for k in 3:
				var o := side * (float(k) - 1.0) * radius * 1.1
				var pts := PackedVector2Array()
				for j in 7:
					var u := float(j) / 6.0
					pts.append(o - dir * radius * 1.6 * (1.0 - u) + side * sin(u * PI) * radius * 0.5 * (1.0 if k != 1 else -1.0))
				ci.draw_polyline(pts, Color(0.97, 0.92, 0.8, 0.95), 2.0 - 0.3 * float(k))
		"seed":
			ci.draw_set_transform(Vector2.ZERO, dir.angle() + tm * 0.7, Vector2(1.5, 1.0))
			ci.draw_circle(Vector2.ZERO, radius, Color(0.55, 0.38, 0.2))
			ci.draw_circle(Vector2(radius * 0.2, 0), radius * 0.45, Color(0.7, 0.55, 0.3))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([-dir * radius, -dir * radius * 2.6 + side * 3.0, -dir * radius * 2.0]), Color(0.4, 0.8, 0.3, 0.9))
		"rock":
			var pts2 := PackedVector2Array()
			for j in 7:
				pts2.append(Vector2.from_angle(tm * 0.6 + float(j) / 7.0 * TAU) * radius * (1.0 + 0.3 * sin(float(j) * 2.7)))
			ci.draw_colored_polygon(pts2, Color(0.55, 0.45, 0.35))
			ci.draw_polyline(pts2 + PackedVector2Array([pts2[0]]), Color(0.3, 0.24, 0.2), 1.2)
			ci.draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.3, Color(0.75, 0.65, 0.5))
		"hell":
			for i in 4:
				var f2 := float(i + 1) / 4.0
				ci.draw_circle(-dir * f2 * radius * 3.0 + side * sin(tm * 1.3 + float(i)) * 2.5, radius * (1.0 - f2 * 0.6), Color(0.8, 0.1, 0.35, 0.6 * (1.0 - f2)))
			ci.draw_circle(Vector2.ZERO, radius * 1.1, Color(0.15, 0.02, 0.12))
			ci.draw_circle(Vector2.ZERO, radius * 0.7, Color(0.9, 0.15, 0.4))
			ci.draw_circle(dir * radius * 0.2, radius * 0.3, Color(1.0, 0.8, 0.5))
		"magic":
			# a violet arcane orb: runes circling it and sparks spiralling off
			ci.draw_circle(Vector2.ZERO, radius * 1.7, Color(0.6, 0.3, 1.0, 0.22))
			ci.draw_circle(Vector2.ZERO, radius * 0.9, Color(0.75, 0.5, 1.0))
			ci.draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1))
			for i in 4:
				var a := tm * 0.5 + float(i) * TAU / 4.0
				var rp := Vector2.from_angle(a) * radius * 1.6
				ci.draw_rect(Rect2(rp - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Color(0.9, 0.8, 1.0))
			for i in 3:
				var f := fposmod(tm * 0.08 + float(i) * 0.33, 1.0)
				ci.draw_circle(-dir * f * radius * 4.0 + side * sin(f * 9.0 + float(i)) * radius * 0.8, 1.3, Color(0.8, 0.6, 1.0, 1.0 - f))
		"holy":
			# a golden star-cross of light
			ci.draw_circle(Vector2.ZERO, radius * 1.6, Color(1.0, 0.95, 0.5, 0.25))
			var rot := tm * 0.1
			for k in 2:
				var d := Vector2.from_angle(rot + float(k) * PI * 0.5)
				var n := d.rotated(PI * 0.5)
				ci.draw_colored_polygon(PackedVector2Array([d * radius * 2.2, n * radius * 0.35, -d * radius * 2.2, -n * radius * 0.35]), Color(1.0, 0.95, 0.6))
			ci.draw_circle(Vector2.ZERO, radius * 0.6, Color(1, 1, 1))
			ci.draw_line(-dir * radius * 3.0, -dir * radius, Color(1.0, 0.95, 0.6, 0.5), 1.5)
		"spore":
			# a green spore pod with wriggling tendrils and drips
			ci.draw_circle(Vector2.ZERO, radius * 1.15, Color(0.3, 0.6, 0.2))
			ci.draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.4, Color(0.7, 0.95, 0.4))
			for i in 3:
				var base := Vector2.from_angle(float(i) * 2.1 + tm * 0.1) * radius
				ci.draw_line(base, base * 1.8 + side * sin(tm * 0.4 + float(i)) * 2.0, Color(0.4, 0.8, 0.25), 1.6)
			for i in 2:
				ci.draw_circle(-dir * (radius * (1.6 + float(i) * 1.2)) + side * sin(tm + float(i) * 3.0) * 2.0, 1.4, Color(0.6, 0.95, 0.3, 0.7))
		"shadow":
			# a spinning crescent blade of darkness with a violet edge
			var ang := tm * 0.7
			var pts := PackedVector2Array()
			for j in 9:
				var a2 := ang + 0.3 + float(j) / 8.0 * (PI * 1.4)
				pts.append(Vector2.from_angle(a2) * radius * 2.0)
			for j in 9:
				var a3 := ang + 0.3 + float(8 - j) / 8.0 * (PI * 1.4)
				pts.append(Vector2.from_angle(a3 + 0.15) * radius * 1.2)
			ci.draw_colored_polygon(pts, Color(0.12, 0.05, 0.2))
			ci.draw_polyline(pts.slice(0, 9), Color(0.7, 0.3, 1.0), 1.6)
			ci.draw_circle(-dir * radius * 2.0, radius * 0.6, Color(0.5, 0.2, 0.8, 0.3))
		"divine":
			# a lance of golden light with a halo and trailing feathers
			var lance := PackedVector2Array([dir * radius * 3.4, side * radius * 0.5, -dir * radius * 2.4, -side * radius * 0.5])
			ci.draw_colored_polygon(lance, Color(1.0, 0.9, 0.4))
			ci.draw_polyline(lance + PackedVector2Array([lance[0]]), Color(1, 1, 0.9), 1.2)
			ci.draw_arc(dir * radius * 0.4, radius * 1.4, 0.0, TAU, 14, Color(1.0, 0.95, 0.6, 0.6), 1.4)
			for i in 3:
				var f2 := fposmod(tm * 0.06 + float(i) * 0.33, 1.0)
				ci.draw_colored_polygon(PackedVector2Array([-dir * (radius * 2.6 + f2 * 8.0) + side * (float(i) - 1.0) * 3.0, -dir * (radius * 3.4 + f2 * 8.0) + side * (float(i) - 1.0) * 3.0 + side * 1.6, -dir * (radius * 3.4 + f2 * 8.0) + side * (float(i) - 1.0) * 3.0 - side * 1.6]), Color(1.0, 0.95, 0.7, 0.8 * (1.0 - f2)))
		_:
			ci.draw_line(-dir * radius * 2.5, Vector2.ZERO, Color(tint, 0.4), radius)
			ci.draw_circle(Vector2.ZERO, radius, tint)


## Themed bursts for the style skills: cloud, flames, spikes, droplets, waves, rubble and shards.
static func draw_burst(ci: CanvasItem, motif: String, radius: float, t: float, tint: Color) -> void:
	var e := _ease_out(clampf(t, 0.0, 1.0))
	var a := 1.0 - smoothstep(0.5, 1.0, t)
	match motif:
		"cloud":
			for i in 10:
				var ang := float(i) * TAU / 10.0 + t * 1.4
				var r := radius * (0.25 + 0.65 * e) * (0.75 + 0.25 * sin(float(i) * 3.1))
				var c := Vector2.from_angle(ang) * r
				var pr := radius * (0.18 + 0.14 * e) * (0.8 + 0.2 * sin(float(i) * 1.7))
				ci.draw_circle(c, pr, Color(tint, 0.38 * a))
				ci.draw_circle(c + Vector2(-pr * 0.25, -pr * 0.25), pr * 0.55, Color(tint.lightened(0.35), 0.3 * a))
			ci.draw_circle(Vector2.ZERO, radius * 0.4 * e, Color(tint, 0.3 * a))
		"flames":
			for i in 12:
				var ang2 := float(i) * TAU / 12.0 + t * 3.5
				var base := Vector2.from_angle(ang2) * radius * (0.2 + 0.7 * e)
				var outward := Vector2.from_angle(ang2 + 0.6)
				var side := outward.rotated(PI * 0.5)
				var hgt := radius * 0.28 * (1.0 - t * 0.5)
				ci.draw_colored_polygon(PackedVector2Array([base + side * hgt * 0.35, base + outward * hgt, base - side * hgt * 0.35]), Color(tint, 0.85 * a))
				ci.draw_colored_polygon(PackedVector2Array([base + side * hgt * 0.15, base + outward * hgt * 0.65, base - side * hgt * 0.15]), Color(1.0, 0.85, 0.35, 0.9 * a))
		"spikes":
			for i in 14:
				var d := Vector2.from_angle(float(i) * TAU / 14.0)
				var base_r := radius * 0.35
				var length := radius * 0.65 * e * (0.7 + 0.3 * fposmod(float(i) * 0.37, 1.0))
				var n := d.rotated(PI * 0.5) * 4.0
				ci.draw_colored_polygon(PackedVector2Array([d * base_r + n, d * (base_r + length), d * base_r - n]), Color(tint.lightened(0.15), a))
			ci.draw_arc(Vector2.ZERO, radius * 0.35, 0.0, TAU, 36, Color(tint.lightened(0.4), a * 0.7), 1.5)
		"droplets":
			for i in 16:
				var reach := radius * e * (0.55 + 0.45 * fposmod(float(i) * 0.53, 1.0))
				var pos := Vector2.from_angle(float(i) * TAU / 16.0 + 0.3) * reach + Vector2(0, -sin(t * PI) * radius * 0.25)
				ci.draw_circle(pos, 2.4 * (1.0 - t * 0.4), Color(tint, a))
				ci.draw_circle(pos + Vector2(-0.7, -0.7), 0.9, Color(1, 1, 1, a * 0.9))
		"waves":
			for k in 3:
				var rr := radius * e * (0.35 + 0.3 * float(k))
				for j in 6:
					var mid := float(j) * TAU / 6.0 + float(k) * 0.3
					ci.draw_arc(Vector2.ZERO, rr, mid - 0.3, mid + 0.3, 8, Color(tint.lightened(0.25 * float(k)), a * (0.9 - 0.2 * float(k))), 2.4)
		"rubble":
			for i in 13:
				var r5 := radius * (0.25 + 0.7 * fposmod(float(i) * 0.41, 1.0))
				var fall := (1.0 - smoothstep(0.0, 0.45, t)) * 40.0
				var c5 := Vector2.from_angle(float(i) * TAU / 13.0 + 0.4) * r5 + Vector2(0, -fall)
				var sz := 3.0 + fposmod(float(i) * 0.77, 1.0) * 3.5
				var pts := PackedVector2Array()
				for j in 6:
					pts.append(c5 + Vector2.from_angle(float(j) / 6.0 * TAU + float(i)) * sz * (0.8 + 0.3 * sin(float(j) * 2.1 + float(i))))
				ci.draw_colored_polygon(pts, Color(tint, a))
			if t > 0.4:
				for i in 6:
					ci.draw_circle(Vector2.from_angle(float(i) * 1.1) * radius * (0.3 + 0.5 * e), 7.0 * e, Color(0.8, 0.72, 0.6, 0.18 * a))
		_:
			for i in 10:
				var d6 := Vector2.from_angle(float(i) * TAU / 10.0)
				var n6 := d6.rotated(PI * 0.5) * 3.0
				ci.draw_colored_polygon(PackedVector2Array([d6 * radius * 0.2 * e + n6, d6 * radius * e, d6 * radius * 0.2 * e - n6]), Color(tint.lightened(0.3), a))


## Level up: a pillar of light, rising gold stars and chevrons, and a burst of sparks. No ring.
static func spawn_levelup(parent: Node2D) -> void:
	if parent == null:
		return
	var fx := SkillFx.new()
	fx.kind = "levelup"
	fx.life = 1.3
	fx.z_index = 30
	parent.add_child(fx)


static func _star(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.28, -s * 0.28), c + Vector2(s, 0), c + Vector2(s * 0.28, s * 0.28),
		c + Vector2(0, s), c + Vector2(-s * 0.28, s * 0.28), c + Vector2(-s, 0), c + Vector2(-s * 0.28, -s * 0.28)]), col)


static func draw_levelup(ci: CanvasItem, t: float) -> void:
	var rise := _ease_out(clampf(t * 1.6, 0.0, 1.0))
	var fade := 1.0 - smoothstep(0.55, 1.0, t)
	var height := 90.0 * rise
	# pillar: stacked soft bars, brightest at the feet
	for i in 6:
		var w := 14.0 - float(i) * 1.8
		var a := (0.30 - float(i) * 0.04) * fade
		ci.draw_rect(Rect2(-w * 0.5, -height, w, height + 4.0), Color(1.0, 0.92, 0.5, a))
	ci.draw_rect(Rect2(-1.5, -height, 3.0, height + 4.0), Color(1, 1, 0.9, 0.7 * fade))
	# rising stars
	for i in 10:
		var speed := 0.55 + fposmod(float(i) * 0.37, 1.0) * 0.8
		var y := -fposmod(t * speed * 120.0 + float(i) * 13.0, 100.0)
		var x := sin(float(i) * 2.4 + t * 5.0) * (6.0 + fposmod(float(i) * 0.61, 1.0) * 10.0)
		var tw := 0.6 + 0.4 * sin(t * 18.0 + float(i) * 3.0)
		_star(ci, Vector2(x, y), 2.0 + fposmod(float(i) * 0.43, 1.0) * 2.5, Color(1.0, 0.9 + 0.1 * tw, 0.5, fade * tw))
	# chevrons climbing the beam
	for k in 3:
		var cy := -fposmod(t * 140.0 + float(k) * 32.0, 96.0)
		var ca := fade * (1.0 - absf(cy) / 100.0)
		ci.draw_polyline(PackedVector2Array([Vector2(-6, cy + 4), Vector2(0, cy - 3), Vector2(6, cy + 4)]), Color(1.0, 0.95, 0.6, ca), 2.0)
	# a burst of spark lines at the feet at the start
	if t < 0.4:
		var b := t / 0.4
		for j in 14:
			var ang := float(j) / 14.0 * TAU + 0.2
			var d := Vector2.from_angle(ang) * Vector2(1.0, 0.5)
			ci.draw_line(d * 8.0 * (1.0 + b * 2.0), d * 22.0 * (1.0 + b * 2.4), Color(1, 0.95, 0.6, 1.0 - b), 1.6)


# --- special skills: effects when they trigger, and auras while they are active ---

## A timed effect node. kind: heal, phoenix, slash, guard, coins, pick, impact, frenzy, spark.
## follow = true puts it on the parent (the player) so it moves with him; otherwise it stays put.
static func spawn_fx(parent: Node, pos: Vector2, kind: String, tint: Color = Color.WHITE, dir: Vector2 = Vector2.RIGHT, scale: float = 1.0) -> void:
	if parent == null:
		return
	var fx := SkillFx.new()
	fx.kind = kind
	fx.position = pos
	fx.dir = dir if dir != Vector2.ZERO else Vector2.RIGHT
	fx.sc = scale
	fx.tint = tint
	fx.z_index = 25
	match kind:
		"heal":
			fx.life = 1.0
		"phoenix":
			fx.life = 1.5
		"slash":
			fx.life = 0.28
		"guard":
			fx.life = 0.8
		"coins":
			fx.life = 1.0
		"pick":
			fx.life = 0.9
		"impact":
			fx.life = 0.3
		"frenzy":
			fx.life = 0.22
		"spark":
			fx.life = 0.3
	parent.add_child(fx)


static func draw_special(ci: CanvasItem, kind: String, t: float, dir: Vector2, sc: float, tint: Color) -> void:
	var e := _ease_out(clampf(t, 0.0, 1.0))
	var a := 1.0 - smoothstep(0.55, 1.0, t)
	match kind:
		"heal":
			# an angel's wings of light and rising crosses
			for side in [-1.0, 1.0]:
				for k in 4:
					var ang := -0.5 - float(k) * 0.28
					var d := Vector2(side * cos(ang), sin(ang))
					ci.draw_line(Vector2(side * 3.0, -4.0), Vector2(side * 3.0, -4.0) + d * (14.0 + float(k) * 5.0) * e, Color(0.85, 1.0, 0.9, a * 0.85), 2.2 - float(k) * 0.3)
			for i in 6:
				var x := sin(float(i) * 2.1) * 12.0
				var y := -fposmod(t * 70.0 + float(i) * 11.0, 52.0)
				var cs := 2.2 + fposmod(float(i) * 0.7, 1.0)
				ci.draw_rect(Rect2(x - 0.8, y - cs, 1.6, cs * 2.0), Color(0.5, 1.0, 0.6, a))
				ci.draw_rect(Rect2(x - cs, y - 0.8, cs * 2.0, 1.6), Color(0.5, 1.0, 0.6, a))
		"phoenix":
			# a firebird with spread wings climbs and bursts into feathers
			var up := -26.0 * e
			for side in ([-1.0, 1.0] if e > 0.12 else []):
				var root := Vector2(side * 4.0, up)
				var tip := Vector2(side * 38.0 * e, up - 14.0 * e)
				var low := Vector2(side * 26.0 * e, up + 8.0 * e)
				var top := Vector2(side * 28.0 * e, up - 22.0 * e)
				# two convex triangles make the wing (a concave polygon fails to triangulate)
				ci.draw_colored_polygon(PackedVector2Array([root, top, tip]), Color(1.0, 0.45, 0.1, 0.85 * a))
				ci.draw_colored_polygon(PackedVector2Array([root, tip, low]), Color(1.0, 0.55, 0.1, 0.85 * a))
				ci.draw_colored_polygon(PackedVector2Array([root, Vector2(side * 20.0 * e, up - 10.0 * e), Vector2(side * 14.0 * e, up + 2.0)]), Color(1.0, 0.9, 0.35, a))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, up - 10.0), Vector2(5, up), Vector2(0, up + 14.0), Vector2(-5, up)]), Color(1.0, 0.7, 0.15, a))
			ci.draw_circle(Vector2(0, up - 8.0), 3.0, Color(1.0, 0.95, 0.6, a))
			for i in 12:
				var ang2 := float(i) * 0.9 + t * 2.0
				var p := Vector2(cos(ang2) * (10.0 + t * 40.0), up + sin(ang2) * 8.0 + t * 24.0)
				ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(2.5, 5.0), p + Vector2(-2.5, 5.0)]), Color(1.0, 0.6 + 0.3 * fposmod(float(i) * 0.37, 1.0), 0.15, a))
		"slash":
			# a crescent sweep: bright edge, soft trail
			var base := dir.angle()
			var r := 16.0 * sc
			for k in 4:
				var f := float(k) / 4.0
				var pts := PackedVector2Array()
				for j in 9:
					var u := float(j) / 8.0
					var ang3 := base - 1.1 + u * 2.2 - f * 0.25
					pts.append(Vector2.from_angle(ang3) * (r - f * 3.0 * sc) * (0.6 + 0.4 * sin(u * PI)) * (0.4 + 0.6 * e))
				ci.draw_polyline(pts, Color(1, 1, 1, a * (1.0 - f * 0.7)), 3.0 - f * 0.6)
		"guard":
			# shield plates snap into place around the body
			for i in 6:
				var ang4 := float(i) * TAU / 6.0
				var c := Vector2.from_angle(ang4) * (24.0 - 12.0 * e)
				var n := Vector2.from_angle(ang4)
				var s2 := n.rotated(PI * 0.5)
				ci.draw_colored_polygon(PackedVector2Array([c + s2 * 5.0, c + n * 4.0, c - s2 * 5.0, c - n * 3.0]), Color(0.75, 0.8, 0.9, a))
				ci.draw_polyline(PackedVector2Array([c + s2 * 5.0, c + n * 4.0, c - s2 * 5.0]), Color(1, 1, 1, a), 1.4)
			ci.draw_circle(Vector2.ZERO, 6.0 * (1.0 - t), Color(1, 1, 1, 0.5 * a))
		"coins":
			for i in 10:
				var ang5 := -PI * 0.5 + (float(i) - 4.5) * 0.28
				var v := 60.0 + fposmod(float(i) * 0.43, 1.0) * 40.0
				var p2 := Vector2.from_angle(ang5) * v * t + Vector2(0, 90.0 * t * t)
				var squash := absf(cos(t * 14.0 + float(i)))
				ci.draw_set_transform(p2, 0.0, Vector2(squash, 1.0))
				ci.draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.82, 0.2, a))
				ci.draw_circle(Vector2(-0.8, -0.8), 1.2, Color(1.0, 1.0, 0.7, a))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pick":
			# a rare skill is chosen: a big star bursts with long rays in its colour
			for i in 8:
				var ang6 := float(i) * TAU / 8.0 + t * 1.2
				var d2 := Vector2.from_angle(ang6)
				ci.draw_line(d2 * 8.0, d2 * (14.0 + 30.0 * e), Color(tint, a), 2.4)
			_star(ci, Vector2(0, -8.0 * e), 6.0 + 8.0 * (1.0 - t), Color(tint.lightened(0.5), a))
			_star(ci, Vector2(0, -8.0 * e), 3.0, Color(1, 1, 1, a))
		"impact":
			# a hard hit: a red star burst on the target
			for i in 6:
				var ang7 := float(i) * TAU / 6.0 + 0.3
				var d3 := Vector2.from_angle(ang7)
				ci.draw_colored_polygon(PackedVector2Array([d3 * 3.0 + d3.rotated(PI * 0.5) * 2.0, d3 * (8.0 + 10.0 * e) * sc, d3 * 3.0 - d3.rotated(PI * 0.5) * 2.0]), Color(1.0, 0.3, 0.2, a))
			_star(ci, Vector2.ZERO, 5.0 * (1.0 - t), Color(1, 0.95, 0.7, a))
		"frenzy":
			# speed lines trailing the bite
			var side2 := dir.rotated(PI * 0.5)
			for i in 5:
				var off := side2 * (float(i) - 2.0) * 4.0
				ci.draw_line(off - dir * 6.0, off - dir * (16.0 + 10.0 * e), Color(1, 0.85, 0.5, a), 1.6)
		"spark":
			# little electric arcs around the caster
			for i in 6:
				var ang8 := float(i) * TAU / 6.0 + t * 8.0
				var p3 := Vector2.from_angle(ang8) * (10.0 + 8.0 * e)
				var mid := p3.rotated(0.35) * 0.7
				ci.draw_polyline(PackedVector2Array([Vector2.from_angle(ang8) * 5.0, mid, p3]), Color(0.85, 0.9, 1.0, a), 1.5)


## Gravity Maw (while active): dots spiral inward toward the body, with streaming arcs.
static func draw_gravity(ci: CanvasItem, tm: float, radius: float) -> void:
	for i in 16:
		var f := fposmod(tm * 0.35 + float(i) / 16.0, 1.0)
		var ang := float(i) * 2.399 + (1.0 - f) * 3.0
		var r := radius * (1.0 - f) + 8.0
		ci.draw_circle(Vector2.from_angle(ang) * r, 1.0 + f * 1.6, Color(0.7, 0.55, 1.0, 0.15 + 0.5 * f))
	for k in 3:
		var base := tm * 0.6 + float(k) * TAU / 3.0
		var pts := PackedVector2Array()
		for j in 14:
			var u := float(j) / 13.0
			pts.append(Vector2.from_angle(base + (1.0 - u) * 2.6) * (radius * 0.9 * (1.0 - u) + 10.0))
		ci.draw_polyline(pts, Color(0.55, 0.4, 0.95, 0.28), 1.4)


## Blood Moon (while active): a red crescent above the head and drifting crimson wisps.
static func draw_bloodmoon(ci: CanvasItem, tm: float) -> void:
	var c := Vector2(0, -26.0 + sin(tm * 1.5) * 1.5)
	ci.draw_circle(c, 7.0, Color(0.85, 0.1, 0.15, 0.9))
	ci.draw_circle(c + Vector2(3.0, -1.5), 6.2, Color(0.1, 0.02, 0.08, 1.0))
	ci.draw_circle(c, 12.0, Color(0.9, 0.1, 0.2, 0.12))
	for i in 5:
		var f := fposmod(tm * 0.4 + float(i) * 0.2, 1.0)
		var x := sin(float(i) * 2.7 + tm) * 10.0
		ci.draw_circle(Vector2(x, 6.0 - f * 30.0), 2.2 * (1.0 - f), Color(0.9, 0.1, 0.2, 0.5 * (1.0 - f)))


# --- enemy attacks: shapes that cannot be mistaken for 小怪's own circles ---

## The warning before an enemy ground attack: a hatched red danger area with a spiked rim, a pie that fills as the
## strike gets closer, and a warning triangle in the middle.
static func draw_danger_warn(ci: CanvasItem, radius: float, f: float, tint: Color) -> void:
	var tm := Time.get_ticks_msec() * 0.001
	var red := Color(1.0, 0.22, 0.18)
	var hot := red.lerp(tint, 0.3)
	# the pie that fills up: the nearer the strike, the fuller
	var steps := 28
	if f > 0.02:
		for i in steps:
			var a0 := -PI / 2.0 + TAU * f * float(i) / steps
			var a1 := -PI / 2.0 + TAU * f * float(i + 1) / steps
			ci.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * radius, Vector2.from_angle(a1) * radius]), Color(hot, 0.22))
	# diagonal hatching, clipped to the circle
	ci.draw_set_transform(Vector2.ZERO, PI / 4.0, Vector2.ONE)
	var y := -radius + 4.0
	while y < radius:
		var w := sqrt(maxf(radius * radius - y * y, 0.0))
		ci.draw_line(Vector2(-w, y), Vector2(w, y), Color(hot, 0.35), 1.6)
		y += 9.0
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a spiked rim that turns slowly
	var rim := PackedVector2Array()
	var spikes := 20
	for i in range(spikes * 2 + 1):
		var a := float(i) / float(spikes * 2) * TAU + tm * 0.8
		rim.append(Vector2.from_angle(a) * (radius * (1.0 if i % 2 == 0 else 1.13)))
	ci.draw_polyline(rim, Color(hot, 0.95), 2.0)
	# the warning triangle with an exclamation mark, blinking faster as the strike nears
	var blink := 0.55 + 0.45 * sin(tm * (6.0 + 14.0 * f))
	var s := clampf(radius * 0.3, 7.0, 18.0)
	var tri := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.95, s * 0.7), Vector2(-s * 0.95, s * 0.7)])
	ci.draw_colored_polygon(tri, Color(1.0, 0.85, 0.2, 0.85 * blink))
	ci.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.3, 0.05, 0.05, blink), 2.0)
	ci.draw_line(Vector2(0, -s * 0.35), Vector2(0, s * 0.2), Color(0.3, 0.05, 0.05, blink), 2.4)
	ci.draw_circle(Vector2(0, s * 0.45), 1.5, Color(0.3, 0.05, 0.05, blink))


## The enemy ground attack going off: jagged shards flung out from the middle (not a plain circle).
static func draw_danger_burst(ci: CanvasItem, radius: float, st: float, tint: Color) -> void:
	var a := 1.0 - st
	var n := 16
	for i in n:
		var ang := float(i) / float(n) * TAU + 0.2
		var d := Vector2.from_angle(ang)
		var side := d.orthogonal()
		var len := radius * (0.55 + 0.55 * minf(st * 3.0, 1.0)) * (0.8 + 0.4 * float(i % 3) / 2.0)
		var w := radius * 0.09
		ci.draw_colored_polygon(PackedVector2Array([d * len, d * len * 0.35 + side * w, d * len * 0.35 - side * w]), Color(1.0, 0.3 + 0.4 * float(i % 2), 0.2, a * 0.9))
	ci.draw_circle(Vector2.ZERO, radius * 0.35 * a, Color(1, 0.95, 0.7, a * 0.8))
	ci.draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * minf(st * 2.5, 1.0)), 0, TAU, 32, Color(1, 0.4, 0.25, a * 0.8), 3.0)

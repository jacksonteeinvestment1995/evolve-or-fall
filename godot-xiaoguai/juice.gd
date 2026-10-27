class_name Juice
extends RefCounted
## The "juice": little animated touches that make fights feel alive, in the spirit of modern HD-2D games
## (Octopath Traveler and friends): impact slashes and sparks with a flash of light, enemies that burst into
## souls and sparkles, status auras that move, afterimages and dust when 小怪 runs, ambient particles for
## each monster family, buff auras, ground scorch marks, and a small camera punch on heavy blows.
## Everything is drawn in code; the nodes free themselves.

static var _radial: GradientTexture2D
static var enabled := true


static func radial() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial


# ---------------------------------------------------------------- spawners

static func hit(parent: Node, pos: Vector2, dir: Vector2, power: float, tint: Color = Color(1.0, 0.95, 0.7)) -> void:
	if not enabled or parent == null:
		return
	var fx := HitFx.new()
	fx.position = pos
	fx.dir = dir if dir != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
	fx.power = clampf(power, 0.2, 1.5)
	fx.tint = tint
	parent.add_child(fx)
	light(parent, pos, tint, 0.55 + fx.power * 0.5, 1.1, 0.16)


static func death(parent: Node, pos: Vector2, size: float, tint: Color) -> void:
	if not enabled or parent == null:
		return
	var fx := DeathFx.new()
	fx.position = pos
	fx.size = size
	fx.tint = tint
	parent.add_child(fx)
	light(parent, pos, tint, 0.9 * size, 1.2, 0.4)


static func dust(parent: Node, pos: Vector2, tint: Color = Color(0.75, 0.68, 0.55)) -> void:
	if not enabled or parent == null:
		return
	var fx := DustFx.new()
	fx.position = pos
	fx.tint = tint
	parent.add_child(fx)


## A quick additive flash of light (HD-2D games light every impact).
static func light(parent: Node, pos: Vector2, color: Color, size: float = 1.0, energy: float = 1.2, life: float = 0.3) -> void:
	if not enabled or parent == null:
		return
	var l := LightFlash.new()
	l.position = pos
	l.color = color
	l.texture = radial()
	l.texture_scale = size
	l.energy = energy
	l.start_energy = energy
	l.life = life
	l.z_index = 10
	parent.add_child(l)


## A scorch / frost / crack mark left on the ground for a moment. It sits under the units.
static func scorch(parent: Node, pos: Vector2, radius: float, tint: Color, life: float = 2.2) -> void:
	if not enabled or parent == null:
		return
	var s := Scorch.new()
	s.position = pos
	s.radius = radius
	s.tint = tint
	s.life = life
	parent.add_child(s)
	parent.move_child(s, 0)


## A burst of sparks and a flash where a skill is cast.
static func cast_burst(parent: Node, pos: Vector2, color: Color) -> void:
	if not enabled or parent == null:
		return
	light(parent, pos, color, 1.4, 1.3, 0.35)
	var fx := HitFx.new()
	fx.position = pos
	fx.dir = Vector2.UP
	fx.power = 1.0
	fx.tint = color
	fx.rays = 12
	parent.add_child(fx)


static func punch(main: Node, amount: float) -> void:
	if enabled and main != null and main.has_method("punch"):
		main.call("punch", amount)


## A very short slow-motion beat on a heavy blow.
static func hitstop(tree: SceneTree, seconds: float = 0.05) -> void:
	if not enabled or tree == null or tree.paused or Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.12
	tree.create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


# ---------------------------------------------------------------- the nodes

class HitFx extends Node2D:
	var dir := Vector2.RIGHT
	var power := 0.5
	var tint := Color(1, 0.95, 0.7)
	var rays := 8
	var age := 0.0
	var life := 0.28

	func _ready() -> void:
		z_index = 22

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := age / life
		var a := 1.0 - t
		var e := 1.0 - (1.0 - t) * (1.0 - t)
		# a slash across the hit, along the blow
		var n := dir.rotated(PI * 0.5)
		var len := (14.0 + 18.0 * power) * (0.4 + 0.6 * e)
		if a > 0.08:
			draw_colored_polygon(PackedVector2Array([-dir * len, n * 2.2 * a, dir * len, -n * 2.2 * a]), Color(1, 1, 1, a))
			draw_colored_polygon(PackedVector2Array([-dir * len * 0.7, n * 4.0 * a, dir * len * 0.7, -n * 4.0 * a]), Color(tint, 0.45 * a))
		# sparks
		for i in rays:
			var ang := dir.angle() + (float(i) / rays - 0.5) * 2.6 + PI * 0.5 * 0.0
			var d := Vector2.from_angle(ang)
			draw_line(d * (4.0 + 6.0 * e), d * (8.0 + (16.0 + 14.0 * power) * e), Color(tint.lightened(0.4), a), 1.6)
		if 6.0 * (1.0 - t) * (0.6 + power) > 0.6:
			draw_colored_polygon(_star_pts(Vector2.ZERO, 6.0 * (1.0 - t) * (0.6 + power), 0.35), Color(1, 1, 0.95, a))

	func _star_pts(c: Vector2, s: float, k: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * k, -s * k), c + Vector2(s, 0), c + Vector2(s * k, s * k),
				c + Vector2(0, s), c + Vector2(-s * k, s * k), c + Vector2(-s, 0), c + Vector2(-s * k, -s * k)])


class DeathFx extends Node2D:
	var size := 1.0
	var tint := Color.WHITE
	var age := 0.0
	var life := 1.0

	func _ready() -> void:
		z_index = 22

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := age / life
		var a := 1.0 - smoothstep(0.35, 1.0, t)
		# the flash
		if t < 0.25:
			var f := t / 0.25
			var s := (10.0 + 18.0 * f) * size
			draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.22, -s * 0.22), Vector2(s, 0), Vector2(s * 0.22, s * 0.22), Vector2(0, s), Vector2(-s * 0.22, s * 0.22), Vector2(-s, 0), Vector2(-s * 0.22, -s * 0.22)]), Color(1, 1, 1, 1.0 - f))
		# the soul rises: a little teardrop with a glow
		var rise := -6.0 - 38.0 * (1.0 - pow(1.0 - t, 2.0)) * size
		var sw := sin(t * 14.0) * 2.5 * size
		var sp := Vector2(sw, rise)
		draw_circle(sp, 7.0 * size, Color(tint, 0.18 * a))
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -6.0 * size), sp + Vector2(4.0 * size, 1.0 * size), sp + Vector2(0, 3.0 * size), sp + Vector2(-4.0 * size, 1.0 * size)]), Color(tint.lightened(0.5), 0.9 * a))
		draw_circle(sp + Vector2(-1.2, -0.5), 0.9, Color(0.1, 0.1, 0.2, a))
		draw_circle(sp + Vector2(1.2, -0.5), 0.9, Color(0.1, 0.1, 0.2, a))
		# sparkles flying out and falling
		for i in 12:
			var ang := float(i) * 2.399
			var sp2 := 16.0 + 22.0 * fposmod(float(i) * 0.37, 1.0)
			var d := Vector2.from_angle(ang) * sp2 * (1.0 - pow(1.0 - t, 2.0)) * size
			d.y += 26.0 * t * t
			var c := Color(tint.lightened(0.3), a) if i % 2 == 0 else Color(1, 0.95, 0.6, a)
			var r := 1.8 * (1.0 - t * 0.6)
			draw_rect(Rect2(d - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), c)


class DustFx extends Node2D:
	var tint := Color(0.75, 0.68, 0.55)
	var age := 0.0
	var life := 0.5

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := age / life
		for i in 3:
			var d := Vector2((float(i) - 1.0) * 5.0 * (0.4 + t), -3.0 * t - float(i % 2) * 2.0)
			draw_circle(d, 2.0 + 3.0 * t, Color(tint, 0.35 * (1.0 - t)))


class LightFlash extends PointLight2D:
	var life := 0.3
	var start_energy := 1.0
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		energy = start_energy * (1.0 - age / life)
		if age >= life:
			queue_free()


class Scorch extends Node2D:
	var radius := 30.0
	var tint := Color(1.0, 0.5, 0.2)
	var life := 2.2
	var age := 0.0
	var seed_v := randi()

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - smoothstep(life * 0.4, life, age)
		var r := RandomNumberGenerator.new()
		r.seed = seed_v
		var pts := PackedVector2Array()
		for i in 16:
			var ang := float(i) / 16.0 * TAU
			pts.append(Vector2.from_angle(ang) * radius * r.randf_range(0.7, 1.0))
		draw_colored_polygon(pts, Color(0.08, 0.05, 0.04, 0.5 * a))
		for i in 7:
			var d := Vector2.from_angle(r.randf() * TAU) * radius * r.randf_range(0.2, 0.75)
			var glow := 0.5 + 0.5 * sin(age * 6.0 + float(i))
			draw_circle(d, 1.5 + glow, Color(tint, 0.6 * a * glow))


# ---------------------------------------------------------------- auras (drawn by the owner's _draw)

## Moving status effects around a villager (the fixed marks above its head stay as they were).
static func draw_status_aura(ci: CanvasItem, v, sc: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if v.has_status("burn"):
		for i in 6:
			var x := (float(i) - 2.5) * 3.2
			var h := 7.0 + 5.0 * sin(t * 11.0 + float(i) * 1.9)
			var base := Vector2(x, 8.0)
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-2.0, 0), base + Vector2(0, -h), base + Vector2(2.0, 0)]), Color(1.0, 0.45, 0.1, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.0, 0), base + Vector2(0, -h * 0.6), base + Vector2(1.0, 0)]), Color(1.0, 0.9, 0.35, 0.9))
	if v.has_status("poison"):
		for i in 5:
			var f := fposmod(t * 0.7 + float(i) * 0.2, 1.0)
			var p := Vector2(sin(float(i) * 2.1 + t) * 6.0, 6.0 - f * 20.0)
			ci.draw_circle(p, 1.4 + f * 1.4, Color(0.45, 0.9, 0.25, 0.7 * (1.0 - f)))
			ci.draw_circle(p + Vector2(-0.5, -0.5), 0.5, Color(1, 1, 1, 0.6 * (1.0 - f)))
	if v.has_status("chill") or v.has_status("freeze"):
		for i in 4:
			var ang := t * 1.6 + float(i) * TAU / 4.0
			var p := Vector2(cos(ang) * 10.0, sin(ang) * 5.0 + 2.0)
			var d := Vector2.from_angle(ang + PI * 0.5)
			ci.draw_colored_polygon(PackedVector2Array([p + d * 2.5, p + Vector2.from_angle(ang) * 3.5, p - d * 2.5]), Color(0.7, 0.92, 1.0, 0.9))
	if v.has_status("bleed"):
		for i in 3:
			var f := fposmod(t * 1.3 + float(i) * 0.33, 1.0)
			var p := Vector2((float(i) - 1.0) * 5.0, -2.0 + f * 14.0)
			ci.draw_circle(p, 1.3, Color(0.85, 0.1, 0.12, 1.0 - f * 0.5))
			ci.draw_line(p, p + Vector2(0, -3.0 * (1.0 - f)), Color(0.85, 0.1, 0.12, 0.6), 1.0)
	if v.has_status("curse"):
		for i in 3:
			var ang := -t * 2.2 + float(i) * TAU / 3.0
			var p := Vector2(cos(ang) * 9.0, sin(ang) * 4.0 - 4.0)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2.6), p + Vector2(1.8, 0), p + Vector2(0, 2.6), p + Vector2(-1.8, 0)]), Color(0.7, 0.35, 0.95, 0.9))
	if v.has_status("shock"):
		for i in 3:
			if int(t * 14.0 + float(i)) % 2 == 0:
				var a := float(i) * 2.1 + floorf(t * 14.0)
				var p := Vector2.from_angle(a) * 9.0
				ci.draw_polyline(PackedVector2Array([p, p * 0.6 + Vector2(2.0, -2.0), p * 0.3 + Vector2(-2.0, 1.0)]), Color(1.0, 1.0, 0.5, 0.95), 1.4)
	if v.stun_left > 0.0:
		for i in 3:
			var ang := t * 5.0 + float(i) * TAU / 3.0
			var p := Vector2(cos(ang) * 7.0, -16.0 - 6.0 * sc + sin(ang) * 2.5)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -2.5), p + Vector2(0.8, -0.8), p + Vector2(2.5, 0), p + Vector2(0.8, 0.8), p + Vector2(0, 2.5), p + Vector2(-0.8, 0.8), p + Vector2(-2.5, 0), p + Vector2(-0.8, -0.8)]), Color(1.0, 0.9, 0.3, 0.95))


## Ambient particles that fit each monster family, floating around 小怪.
static func draw_family_aura(ci: CanvasItem, family: String, moving: bool) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in 6:
		var f := fposmod(t * 0.55 + float(i) / 6.0, 1.0)
		var a := sin(f * PI)
		var x := sin(float(i) * 2.3 + t * 0.8) * 9.0
		var p := Vector2(x, 8.0 - f * 28.0)
		match family:
			"Undead":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3.0), p + Vector2(1.6, 0.5), p + Vector2(0, 2.0), p + Vector2(-1.6, 0.5)]), Color(0.55, 1.0, 0.7, 0.55 * a))
			"Slime":
				ci.draw_circle(p, 1.6 + 1.2 * f, Color(0.5, 0.85, 1.0, 0.45 * a))
				ci.draw_circle(p + Vector2(-0.5, -0.5), 0.5, Color(1, 1, 1, 0.7 * a))
			"Dragon":
				ci.draw_rect(Rect2(p, Vector2(1.6, 1.6)), Color(1.0, 0.55 + 0.3 * f, 0.15, 0.8 * a))
			"Beast":
				if moving:
					ci.draw_circle(Vector2(x * 0.8, 9.0 - f * 4.0), 1.5 + f, Color(0.7, 0.6, 0.45, 0.4 * a))
			"Nature":
				var rot := t * 3.0 + float(i)
				var d := Vector2.from_angle(rot)
				ci.draw_colored_polygon(PackedVector2Array([p + d * 2.4, p + d.rotated(PI * 0.5) * 1.1, p - d * 2.4, p - d.rotated(PI * 0.5) * 1.1]), Color(0.4, 0.85, 0.3, 0.7 * a))
			"Material":
				var rot2 := t * 1.2 + float(i) * 1.1
				var op := Vector2(cos(rot2) * 11.0, sin(rot2) * 5.0 - 2.0)
				ci.draw_rect(Rect2(op, Vector2(2.2, 2.2)), Color(0.65, 0.55, 0.45, 0.8))
			"Demon":
				ci.draw_rect(Rect2(p, Vector2(1.5, 1.5)), Color(1.0, 0.25 + 0.2 * f, 0.4, 0.8 * a))
				ci.draw_line(p, p + Vector2(0, 3.0 * a), Color(0.9, 0.2, 0.3, 0.4 * a), 1.0)


## Auras for the timed treasure buffs.
static func draw_buff_aura(ci: CanvasItem, buffs: Dictionary, facing: Vector2) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if buffs.has("rage"):
		for i in 7:
			var x := (float(i) - 3.0) * 3.4
			var h := 9.0 + 6.0 * sin(t * 13.0 + float(i) * 2.0)
			var b := Vector2(x, 9.0)
			ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-2.0, 0), b + Vector2(0.5, -h), b + Vector2(2.0, 0)]), Color(1.0, 0.2, 0.1, 0.5))
	if buffs.has("swift"):
		var side := facing.rotated(PI * 0.5)
		for i in 4:
			var f := fposmod(t * 2.0 + float(i) * 0.25, 1.0)
			var o := side * (float(i) - 1.5) * 4.0
			ci.draw_line(o - facing * (6.0 + 12.0 * f), o - facing * (12.0 + 22.0 * f), Color(0.6, 0.9, 1.0, 0.7 * (1.0 - f)), 1.4)
	if buffs.has("mend"):
		for i in 4:
			var f := fposmod(t * 0.8 + float(i) * 0.25, 1.0)
			var p := Vector2(sin(float(i) * 2.5 + t) * 8.0, 6.0 - f * 24.0)
			ci.draw_rect(Rect2(p.x - 0.7, p.y - 2.2, 1.4, 4.4), Color(0.4, 1.0, 0.55, 0.9 * (1.0 - f)))
			ci.draw_rect(Rect2(p.x - 2.2, p.y - 0.7, 4.4, 1.4), Color(0.4, 1.0, 0.55, 0.9 * (1.0 - f)))
	if buffs.has("ward"):
		for i in 6:
			var ang := t * 1.4 + float(i) * TAU / 6.0
			var c := Vector2(cos(ang) * 13.0, sin(ang) * 7.0 - 1.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2.5), c + Vector2(2.0, 0), c + Vector2(0, 2.5), c + Vector2(-2.0, 0)]), Color(0.75, 0.8, 1.0, 0.8))

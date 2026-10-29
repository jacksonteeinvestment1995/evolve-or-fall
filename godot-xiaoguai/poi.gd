extends Node2D
## A point of interest on the map, worth walking to:
##   shrine  gives a random buff for 45 seconds, then rests for 150 seconds
##   spring  heals 5% of max HP every 1.2 seconds while 小怪 stands in it
##   crypt   opens once: an ambush of villagers, guarding a silver (or gold) chest
##   tower   a ruined watch tower: climb it once for a wide look at the map (it clears the minimap fog) and 25 bones

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")
const TreasureScript := preload("res://treasure.gd")

const REACH := {"shrine": 30.0, "spring": 46.0, "crypt": 32.0, "tower": 34.0}
const TITLES := {"shrine": "Shrine", "spring": "Healing Spring", "crypt": "Crypt", "tower": "Ruined Tower"}
const SHRINE_BUFF_SECONDS := 45.0
const SHRINE_REST := 150.0

var kind := "shrine"
var used := false          ## crypts and towers work once
var rest := 0.0            ## shrine cooldown
var _t := randf() * TAU
var _acc := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("pois")
	z_index = 1
	_rng.randomize()


func tile_title() -> String:
	return TITLES.get(kind, kind)


func _physics_process(delta: float) -> void:
	_t += delta
	rest = maxf(rest - delta, 0.0)
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or pl.hp <= 0:
		queue_redraw()
		return
	var d: float = pl.global_position.distance_to(global_position)
	if d <= float(REACH[kind]) + pl.body_radius * 0.4:
		match kind:
			"shrine":
				if rest <= 0.0:
					_shrine(pl)
			"spring":
				if pl.hp < pl.max_hp:
					_acc += delta
					if _acc >= 1.2:
						_acc = 0.0
						var heal := maxi(1, ceili(pl.max_hp * 0.05))
						pl.hp = mini(pl.max_hp, pl.hp + heal)
						pl.hp_changed.emit(pl.hp)
						Popups.text(get_tree(), pl.global_position + Vector2(0, -24), "+%d" % heal, Popups.HEAL, 13)
						Sfx.play(get_tree(), "chime", -9.0)
			"crypt":
				if not used:
					_open_crypt(pl)
			"tower":
				if not used:
					_climb_tower(pl)
	else:
		_acc = 0.0
	queue_redraw()


func _shrine(pl) -> void:
	var ids: Array = TreasureScript.BUFFS.keys()
	var id: String = ids[_rng.randi_range(0, ids.size() - 1)]
	pl.add_buff(id, SHRINE_BUFF_SECONDS)
	rest = SHRINE_REST
	Popups.text(get_tree(), global_position + Vector2(0, -44), "Shrine: %s! (%s)" % [TreasureScript.BUFFS[id]["name"], TreasureScript.BUFFS[id]["desc"]], Popups.BIG, 14)
	Sfx.play(get_tree(), "pick")
	SkillFx.spawn_levelup(self)


func _open_crypt(pl) -> void:
	used = true
	var main = get_parent()
	Popups.text(get_tree(), global_position + Vector2(0, -44), "The crypt opens!", Popups.BLEED, 16)
	Sfx.play(get_tree(), "warn", -1.0)
	if main.has_method("_spawn_villager"):
		for k in 5:
			var a := float(k) / 5.0 * TAU
			var v = main.call("_spawn_villager", global_position + Vector2.from_angle(a) * 46.0, 2, _rng.randi_range(0, 9), -1)
			v.force_chase = true
	var chest = TreasureScript.new()
	chest.tier = "gold" if _rng.randf() < 0.3 else "silver"
	chest.position = global_position + Vector2(0, 26)
	main.call_deferred("add_child", chest)


func _climb_tower(pl) -> void:
	used = true
	var main = get_parent()
	Popups.text(get_tree(), global_position + Vector2(0, -52), "The view clears.  +25 bones", Popups.HEAL, 14)
	Sfx.play(get_tree(), "coin")
	if main.get("bones") != null:
		main.set("bones", int(main.get("bones")) + 25)
	if main.get("minimap") != null and main.minimap.has_method("reveal_area"):
		main.minimap.reveal_area(main.tile_of(global_position), 55)


func _draw() -> void:
	var tm := _t
	match kind:
		"shrine":
			_draw_shrine(tm)
		"spring":
			_draw_spring(tm)
		"crypt":
			_draw_crypt(tm)
		"tower":
			_draw_tower(tm)


## A convex ellipse as a polygon (always valid, cheaper than a scaled circle).
func _ell(c: Vector2, rx: float, ry: float, col: Color, n: int = 14) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


## The soft shadow every POI casts to the lower right (light from the top left).
func _shadow(c: Vector2, rx: float, ry: float) -> void:
	_ell(c + Vector2(4, 1), rx, ry, Color(0.05, 0.02, 0.1, 0.16))
	_ell(c + Vector2(3, 0), rx * 0.78, ry * 0.75, Color(0.05, 0.02, 0.1, 0.16))


# --- shrine: a stone obelisk on a round dais under a floating orb; gold and alive when ready, grey while it rests ---

func _draw_shrine(tm: float) -> void:
	var ready := rest <= 0.0
	var gold := Color(1.0, 0.82, 0.32)
	var glow := gold if ready else Color(0.55, 0.62, 0.8)
	_shadow(Vector2(0, 6), 26.0, 9.0)
	# the round dais: a lit rim, a darker face, flagstones
	_ell(Vector2(0, 6), 24.0, 9.5, Color("4e4a5a"))
	_ell(Vector2(0, 4), 24.0, 9.0, Color("8a8698"))
	_ell(Vector2(-1, 3), 21.0, 7.5, Color("a29eb0"))
	draw_line(Vector2(-12, 0), Vector2(-15, 7), Color("7a7688"), 1.0)
	draw_line(Vector2(13, 0), Vector2(16, 7), Color("7a7688"), 1.0)
	draw_line(Vector2(0, -4), Vector2(0, -2), Color("7a7688"), 1.0)
	# runes on the dais that turn slowly, bright when ready
	for k in 8:
		var a := tm * (0.7 if ready else 0.12) + float(k) / 8.0 * TAU
		var p := Vector2(cos(a) * 18.0, 3.0 + sin(a) * 6.5)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(glow, 0.95 if ready else 0.45))
	# the obelisk: tapered, lit on the left, shaded on the right
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 2), Vector2(-4, -26), Vector2(4, -26), Vector2(6, 2)]), Color("9894a8"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 2), Vector2(-4, -26), Vector2(-1, -26), Vector2(-2, 2)]), Color("c4c0d2"))
	draw_colored_polygon(PackedVector2Array([Vector2(2, 2), Vector2(2, -26), Vector2(4, -26), Vector2(6, 2)]), Color("6a667a"))
	draw_rect(Rect2(-8, -30, 16, 4), Color("8a8698"))
	draw_rect(Rect2(-8, -30, 16, 1), Color("d4d0e0"))
	draw_rect(Rect2(-8, -27, 16, 1), Color("5a566a"))
	# the carved rune line glows while the shrine is ready
	for k in 4:
		var y := -22.0 + k * 5.0
		draw_rect(Rect2(-1, y, 2, 3), Color(glow, (0.6 + 0.4 * sin(tm * 3.0 + k)) if ready else 0.3))
	# two candles on the dais
	for cx in [-14.0, 13.0]:
		draw_rect(Rect2(cx - 1, -3, 2, 5), Color("efe4c8"))
		if ready:
			var fl := 0.8 + 0.3 * sin(tm * 13.0 + cx)
			_ell(Vector2(cx, -5), 3.5 * fl, 3.5 * fl, Color(1.0, 0.7, 0.3, 0.22), 8)
			draw_rect(Rect2(cx - 0.5, -6.0 - fl, 1, 2.0 + fl), Color(1.0, 0.85, 0.4))
	# the orb above the obelisk
	var bob := sin(tm * 2.0) * 2.0
	var orb := Vector2(0, -40 + bob)
	if ready:
		# a soft beam and a warm halo, with sparks drifting up
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -30), Vector2(-2, -64), Vector2(2, -64), Vector2(5, -30)]), Color(1.0, 0.9, 0.5, 0.1))
		for i in 4:
			_ell(orb, 15.0 - 3.2 * i, 15.0 - 3.2 * i, Color(1.0, 0.82, 0.32, 0.06 + 0.06 * i), 16)
		for k in 4:
			var f := fposmod(tm * 0.45 + float(k) * 0.25, 1.0)
			var sp := Vector2(sin(tm * 1.5 + k * 2.0) * 9.0, -30.0 - 26.0 * f)
			draw_rect(Rect2(sp, Vector2(1.5, 1.5)), Color(1.0, 0.92, 0.6, 1.0 - f))
		_ell(orb, 5.5, 5.5, Color("ffc83a"), 12)
		_ell(orb + Vector2(-1, -1), 3.8, 3.8, Color("ffe89a"), 10)
	else:
		_ell(orb, 5.0, 5.0, Color("6a7090"), 12)
		_ell(orb + Vector2(-1, -1), 3.0, 3.0, Color("8a92b4"), 10)
		draw_arc(orb, 9.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - rest / SHRINE_REST), 24, Color(1, 0.88, 0.5, 0.8), 1.5)
	draw_rect(Rect2(orb + Vector2(-2.5, -2.5), Vector2(1.5, 1.5)), Color(1, 1, 1, 0.9))


# --- spring: a pool ringed with mossy stones, clear water, ripples and healing motes rising ---

func _draw_spring(tm: float) -> void:
	_shadow(Vector2(0, 4), 34.0, 14.0)
	# damp earth and the stone ring
	_ell(Vector2(0, 2), 33.0, 16.0, Color(0.2, 0.26, 0.14, 0.45))
	_ell(Vector2(0, 1), 28.0, 13.5, Color("6a7064"))
	# the water: clear turquoise at the edge, deeper in the middle, the sky caught in the top left
	_ell(Vector2(0, 1), 25.0, 11.5, Color("5ad0d8"))
	_ell(Vector2(1, 2), 21.0, 9.0, Color("38aecb"))
	_ell(Vector2(2, 3), 14.0, 5.5, Color("2a88b8"))
	_ell(Vector2(-9, -3), 9.0, 2.6, Color(0.9, 1.0, 1.0, 0.45), 10)
	# ripples spreading from the spring's eye
	for k in 3:
		var f := fposmod(tm * 0.45 + float(k) / 3.0, 1.0)
		draw_arc(Vector2(2, 2), 3.0 + 17.0 * f, 0.0, TAU, 20, Color(0.8, 0.97, 1.0, 0.5 * (1.0 - f)), 1.0)
	# stones round the rim: lit tops, moss on a few
	for k in 11:
		var a := float(k) / 11.0 * TAU + 0.2
		var p := Vector2(cos(a) * 27.0, 1.0 + sin(a) * 13.0)
		var r := 4.0 + 1.5 * float((k * 7) % 3) * 0.5
		_ell(p + Vector2(0.5, 1.0), r, r * 0.65, Color("6e7080"), 8)
		_ell(p + Vector2(-0.6, -0.4), r * 0.75, r * 0.45, Color("c2c2cc"), 8)
		if k % 3 == 0:
			draw_rect(Rect2(p + Vector2(-2, -2), Vector2(3, 1)), Color("6a9a4a"))
	# a lily pad with a flower, and reeds at the back
	_ell(Vector2(-8, 4), 4.0, 1.8, Color("4a8a3a"), 10)
	draw_rect(Rect2(-9, 2.5, 2, 1.5), Color("f4c8dc"))
	for k in 4:
		var x := 14.0 + k * 3.0
		draw_line(Vector2(x, -9), Vector2(x + 1.0, -21.0 + (k % 2) * 4.0), Color("5e7a3a"), 1.0)
	draw_rect(Rect2(16.5, -20, 2, 4), Color("6a4a2a"))
	# healing motes rising from the water
	for k in 6:
		var f := fposmod(tm * 0.35 + float(k) * 0.167, 1.0)
		var x := sin(float(k) * 2.4) * 15.0 + sin(tm + k) * 2.0
		var p := Vector2(x, 2.0 - 30.0 * f)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.7, 1.0, 0.85, 0.85 * (1.0 - f)))
		if k % 2 == 0:
			_ell(p + Vector2(1, 1), 3.5, 3.5, Color(0.5, 1.0, 0.8, 0.12 * (1.0 - f)), 8)
	draw_rect(Rect2(-12, -2, 3, 1), Color(1, 1, 1, 0.5 + 0.4 * sin(tm * 2.0)))


# --- crypt: a stone mausoleum with a pediment and two braziers; sealed, or broken open with mist pouring out ---

func _draw_crypt(tm: float) -> void:
	var open := used
	_shadow(Vector2(2, 8), 32.0, 10.0)
	# the plinth
	draw_rect(Rect2(-27, 2, 54, 7), Color("4a4658"))
	draw_rect(Rect2(-27, 2, 54, 1), Color("8a869a"))
	# the walls: lit on the left, dark on the right, block lines
	draw_rect(Rect2(-23, -22, 46, 24), Color("7c7890"))
	draw_rect(Rect2(-23, -22, 6, 24), Color("9c98b0"))
	draw_rect(Rect2(17, -22, 6, 24), Color("54506a"))
	for y in [-16.0, -10.0, -4.0]:
		draw_line(Vector2(-23, y), Vector2(23, y), Color(0.2, 0.18, 0.28, 0.35), 1.0)
	# the pediment roof
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -22), Vector2(0, -36), Vector2(27, -22)]), Color("5a566e"))
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -22), Vector2(0, -36), Vector2(0, -22)]), Color("7a768e"))
	draw_line(Vector2(-27, -22), Vector2(0, -36), Color("a8a4bc"), 1.0)
	draw_rect(Rect2(-28, -23, 56, 2), Color("8e8aa2"))
	# a skull carved in the gable
	_ell(Vector2(0, -28), 3.2, 3.0, Color("d8d0b8"), 10)
	draw_rect(Rect2(-2, -29, 1, 1), Color("2a2030"))
	draw_rect(Rect2(1, -29, 1, 1), Color("2a2030"))
	# the arched doorway
	var door := Color(0.05, 0.03, 0.08)
	draw_rect(Rect2(-8, -12, 16, 14), door)
	_ell(Vector2(0, -12), 8.0, 6.0, door, 12)
	draw_arc(Vector2(0, -12), 9.0, PI, TAU, 10, Color("a8a4bc"), 1.0)
	if open:
		# the slab lies broken to one side, mist and a cold glow pour out
		_ell(Vector2(0, -2), 7.0, 6.0, Color(0.5, 0.3, 0.8, 0.25 + 0.1 * sin(tm * 2.0)), 12)
		draw_colored_polygon(PackedVector2Array([Vector2(12, 9), Vector2(14, -6), Vector2(20, -5), Vector2(19, 9)]), Color("5e5a70"))
		draw_line(Vector2(14, -6), Vector2(20, -5), Color("9894aa"), 1.0)
		for k in 5:
			var f := fposmod(tm * 0.35 + float(k) * 0.2, 1.0)
			var p := Vector2(sin(tm * 0.8 + k * 1.7) * 5.0 + (k - 2) * 2.0, 2.0 - 34.0 * f)
			_ell(p, 3.0 + 5.0 * f, 2.0 + 3.0 * f, Color(0.68, 0.55, 0.9, 0.28 * (1.0 - f)), 10)
	else:
		# the sealed stone door, banded in iron with a ring
		draw_rect(Rect2(-7, -12, 14, 14), Color("5e5a70"))
		_ell(Vector2(0, -12), 7.0, 5.0, Color("5e5a70"), 12)
		draw_rect(Rect2(-7, -12, 3, 14), Color("78748a"))
		draw_line(Vector2(0, -16), Vector2(0, 2), Color("3a364a"), 1.0)
		draw_rect(Rect2(-7, -8, 14, 1), Color("3e3a3a"))
		draw_rect(Rect2(-7, -2, 14, 1), Color("3e3a3a"))
		draw_arc(Vector2(3, -4), 1.6, 0.0, TAU, 8, Color("b0a080"), 1.0)
	# moss and a crack
	draw_rect(Rect2(-23, 0, 5, 2), Color("4a6a3a"))
	draw_rect(Rect2(15, -22, 4, 2), Color("4a6a3a"))
	draw_line(Vector2(12, -18), Vector2(15, -12), Color(0.2, 0.18, 0.28, 0.6), 1.0)
	# two braziers that flicker (a ghostly green once the crypt is open)
	for sx in [-22.0, 22.0]:
		draw_rect(Rect2(sx - 1.5, -6, 3, 15), Color("3a3446"))
		draw_rect(Rect2(sx - 4, -8, 8, 3), Color("5a5468"))
		var fl := 1.0 + 0.22 * sin(tm * 11.0 + sx)
		var hot := Color(0.55, 1.0, 0.65) if open else Color(1.0, 0.72, 0.25)
		var halo := Color(0.4, 1.0, 0.6, 0.18) if open else Color(1.0, 0.5, 0.15, 0.2)
		_ell(Vector2(sx, -12), 8.0 * fl, 7.0 * fl, halo, 12)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 3, -8), Vector2(sx, -8.0 - 8.0 * fl), Vector2(sx + 3, -8)]), hot)
		draw_colored_polygon(PackedVector2Array([Vector2(sx - 1.5, -8), Vector2(sx, -8.0 - 4.0 * fl), Vector2(sx + 1.5, -8)]), Color(1, 1, 0.85))


# --- tower: a round ruined watch tower with ivy; a beacon calls while unclimbed, a red banner flies once climbed ---

func _draw_tower(tm: float) -> void:
	_shadow(Vector2(4, 8), 22.0, 8.0)
	# rubble at the foot
	for p in [Vector2(-17, 7), Vector2(15, 8), Vector2(19, 5), Vector2(-13, 9)]:
		_ell(p, 3.0, 2.0, Color("6a667a"), 8)
		_ell(p + Vector2(-0.6, -0.6), 2.0, 1.2, Color("9a96a8"), 8)
	# the round body in vertical bands, light on the left
	var bands := [Color("aaa6b8"), Color("948fa6"), Color("807c92"), Color("6c687e"), Color("5a566c")]
	for i in bands.size():
		draw_rect(Rect2(-13.0 + i * 5.2, -38, 5.4, 46), bands[i])
	_ell(Vector2(0, 8), 13.0, 3.0, Color("5a566c"), 12)
	# the stone courses, staggered
	for row in 8:
		var y := -34.0 + row * 5.5
		draw_line(Vector2(-13, y), Vector2(13, y), Color(0.15, 0.12, 0.22, 0.32), 1.0)
		var off := 3.0 if row % 2 == 0 else 0.0
		for x in [-9.0, -2.0, 5.0]:
			draw_line(Vector2(x + off, y), Vector2(x + off, y + 5.5), Color(0.15, 0.12, 0.22, 0.22), 1.0)
	# the broken crown
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -38), Vector2(-14, -44), Vector2(-9, -44), Vector2(-8, -40), Vector2(-4, -40), Vector2(-3, -47), Vector2(2, -47), Vector2(3, -41)]), Color("9a96aa"))
	draw_colored_polygon(PackedVector2Array([Vector2(3, -41), Vector2(8, -41), Vector2(9, -45), Vector2(14, -45), Vector2(14, -38), Vector2(-14, -38)]), Color("75718a"))
	draw_line(Vector2(-14, -44), Vector2(-9, -44), Color("cac6d8"), 1.0)
	draw_line(Vector2(-3, -47), Vector2(2, -47), Color("cac6d8"), 1.0)
	# an arched window and the wooden door
	draw_rect(Rect2(-3, -28, 5, 7), Color(0.06, 0.04, 0.1))
	_ell(Vector2(-0.5, -28), 2.5, 2.0, Color(0.06, 0.04, 0.1), 8)
	draw_rect(Rect2(-4, -4, 8, 12), Color("5a3a22"))
	_ell(Vector2(0, -4), 4.0, 3.0, Color("5a3a22"), 10)
	draw_rect(Rect2(-4, -4, 2, 12), Color("7a5232"))
	draw_rect(Rect2(1, 1, 1, 1), Color("c8a860"))
	# ivy climbing the left side
	for v in [[-12.0, -36.0, 26.0], [-8.0, -20.0, 14.0], [9.0, -30.0, 10.0]]:
		var vx: float = v[0]
		var vy: float = v[1]
		var vl: float = v[2]
		draw_line(Vector2(vx, vy), Vector2(vx + 1.0, vy + vl), Color("3a6a2e"), 1.0)
		for k in int(vl / 5.0):
			var lp := Vector2(vx + (1.5 if k % 2 == 0 else -1.5), vy + 2.0 + k * 5.0)
			_ell(lp, 2.0, 1.4, Color("4e8a3a") if k % 2 == 0 else Color("6aa04a"), 6)
	if used:
		# a red banner flies from the top
		draw_line(Vector2(-1, -47), Vector2(-1, -62), Color("4a3a2a"), 1.5)
		var w := sin(tm * 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -62), Vector2(10, -60.0 + w * 1.5), Vector2(10, -55.0 + w * 1.5), Vector2(-0.5, -55)]), Color("c83a30"))
		draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -62), Vector2(10, -60.0 + w * 1.5), Vector2(10, -59.0 + w * 1.5), Vector2(-0.5, -61)]), Color("e8604a"))
	else:
		# a beacon of cold light on the top: worth the climb
		var pulse := 0.5 + 0.5 * sin(tm * 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -47), Vector2(-7, -78), Vector2(7, -78), Vector2(3, -47)]), Color(0.6, 0.85, 1.0, 0.07 + 0.04 * pulse))
		_ell(Vector2(0, -51), 9.0 + 2.0 * pulse, 7.0 + 2.0 * pulse, Color(0.5, 0.8, 1.0, 0.16 + 0.1 * pulse), 14)
		_ell(Vector2(0, -51), 3.5, 3.5, Color(0.7, 0.9, 1.0), 10)
		draw_rect(Rect2(-1.5, -53, 2, 2), Color(1, 1, 1))
		for k in 3:
			var a := tm * 1.2 + float(k) * TAU / 3.0
			draw_rect(Rect2(Vector2(cos(a) * 9.0, -51.0 + sin(a) * 4.0), Vector2(1.5, 1.5)), Color(0.85, 0.95, 1.0, 0.8))

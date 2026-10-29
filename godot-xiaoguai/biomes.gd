extends RefCounted
## The map's biomes. Far from the start the meadow gives way to patches of snow, desert, swamp, graveyard and autumn
## forest, each with its own ground colour, tinted trees and hand-drawn props. The start meadow stays green. The swamp
## also slows 小怪 a little. generate() returns tile -> biome id (meadow tiles are simply absent).

const SNOW := 1
const DESERT := 2
const SWAMP := 3
const GRAVEYARD := 4
const AUTUMN := 5

const NAMES := {SNOW: "Frozen Waste", DESERT: "Bone Desert", SWAMP: "Murk Swamp", GRAVEYARD: "Hollow Graveyard", AUTUMN: "Ember Woods"}

const GROUND := {
	SNOW: [Color("e8f0fa"), Color("d6e2f2"), Color("c4d4ea")],
	DESERT: [Color("d9bd82"), Color("caa96a"), Color("bd9a5c")],
	SWAMP: [Color("3f5b3f"), Color("354f39"), Color("2c4333")],
	GRAVEYARD: [Color("5d5972"), Color("514d66"), Color("464258")],
}
## A rough leaf colour per biome (trees.gd recolours the leaves with a small shader; this is the reference).
const TREE_TINT := {
	SNOW: Color(0.86, 0.95, 1.15), DESERT: Color(1.25, 1.05, 0.62), SWAMP: Color(0.6, 0.78, 0.62),
	GRAVEYARD: Color(0.64, 0.56, 0.76), AUTUMN: Color(1.35, 0.85, 0.45),
}
const AUTUMN_GRASS := Color(1.3, 0.88, 0.52)
const SWAMP_SLOW := 0.85

const PROPS := {
	SNOW: ["bp_snow_rock", "bp_ice_crystal", "bp_snowdrift", "bp_frost_bush", "bp_frost_bush", "bp_snow_rock", "bp_snowman"],
	DESERT: ["bp_cactus", "bp_dune_rock", "bp_bones", "bp_cactus", "bp_cactus", "bp_dune_rock"],
	SWAMP: ["bp_mushrooms", "bp_reeds", "bp_swamp_stump", "bp_reeds", "bp_lily", "bp_lily"],
	GRAVEYARD: ["bp_cross", "bp_skull_pile", "bp_dead_bush", "bp_tomb", "bp_tomb", "bp_cross", "bp_jack"],
	AUTUMN: ["bp_leaf_pile", "bp_pumpkin", "bp_mushrooms", "bp_leaf_pile", "bp_pumpkin", "bp_dead_bush"],
}


static func _noise(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	return float(h & 0xffff) / 65535.0


## Patches far from the start; each tile belongs to the nearest patch if it is inside it (with a ragged edge).
static func generate(rng: RandomNumberGenerator, cols: int, rows: int, start: Vector2i) -> Dictionary:
	var types := [SNOW, DESERT, SWAMP, GRAVEYARD, AUTUMN, SNOW, SWAMP]
	var patches: Array = []
	for t in types:
		for attempt in 120:
			var c := Vector2(rng.randf_range(26.0, cols - 26.0), rng.randf_range(16.0, rows - 16.0))
			if c.distance_to(Vector2(start)) < 38.0:
				continue
			var ok := true
			for p in patches:
				if c.distance_to(p["c"]) < 40.0:
					ok = false
					break
			if ok:
				patches.append({"c": c, "t": t, "rx": rng.randf_range(17.0, 26.0), "ry": rng.randf_range(13.0, 19.0)})
				break
	var out := {}
	for y in rows:
		for x in cols:
			var best := 0
			var best_v := 1.0
			for p in patches:
				var dx: float = (x - p["c"].x) / p["rx"]
				var dy: float = (y - p["c"].y) / p["ry"]
				var v := dx * dx + dy * dy + (_noise(x, y) - 0.5) * 0.4
				if v < best_v:
					best_v = v
					best = p["t"]
			if best != 0 and Vector2(x - start.x, y - start.y).length() > 30.0:
				out[Vector2i(x, y)] = best
	return out


## Scatter the biome props over free biome tiles (they are decoration: nothing collides with them).
static func scatter_props(main, rng: RandomNumberGenerator) -> void:
	for t in main.biome:
		if rng.randf() > 0.05:
			continue
		if main.trees.has(t) or main.mud.has(t) or main.water.has(t) or main.paths.has(t) or main.props.has(t) or main.floors.has(t) or main.buildings.has(t):
			continue
		var list: Array = PROPS.get(main.biome[t], [])
		if list.is_empty():
			continue
		main.props[t] = list[rng.randi_range(0, list.size() - 1)]


## The ground colour of one biome tile (a stable variation, so the ground does not flicker).
static func ground_color(biome: int, x: int, y: int) -> Color:
	var shades: Array = GROUND[biome]
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
	return shades[0] if h % 5 < 3 else shades[(h / 5) % shades.size()]


# --- the props, drawn by hand ---
# Each prop is drawn in its own little frame (origin at its foot, light from the top left), mirrored and sized a
# little differently per tile so a field of them never looks stamped. About 8 to 20 draw calls each.

const SHADOW := Color(0.06, 0.03, 0.12, 0.26)


static func _h(foot: Vector2, salt: int) -> float:
	var h := (int(foot.x) * 73856093) ^ (int(foot.y) * 19349663) ^ (salt * 83492791)
	return float(h & 0xffff) / 65535.0


## A convex ellipse as a polygon (always valid).
static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, n: int = 12) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


## A triangle (a fan piece), skipped when it has no area.
static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if absf((b - a).cross(c - a)) < 0.01:
		return
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)


static func draw_prop(ci: CanvasItem, name: String, foot: Vector2) -> void:
	var flip := -1.0 if _h(foot, 1) < 0.5 else 1.0
	var sc := 0.88 + 0.26 * _h(foot, 2)
	var v := _h(foot, 3)
	# the soft shadow falls to the lower right, under the prop's own frame
	_ell(ci, foot + Vector2(3, 0), 10.0 * sc, 3.2 * sc, SHADOW)
	ci.draw_set_transform(foot, 0.0, Vector2(sc * flip, sc))
	match name:
		"bp_cactus":
			_cactus(ci, v)
		"bp_dune_rock":
			_tri(ci, Vector2(-11, 0), Vector2(-8, -12), Vector2(10, 0), Color("a77e4e"))
			_tri(ci, Vector2(-8, -12), Vector2(7, -14), Vector2(10, 0), Color("8c6440"))
			_tri(ci, Vector2(7, -14), Vector2(12, -5), Vector2(10, 0), Color("74512f"))
			_tri(ci, Vector2(-8, -12), Vector2(-1, -16), Vector2(7, -14), Color("d9b07a"))
			ci.draw_line(Vector2(-9, -6), Vector2(9, -7), Color(0.4, 0.25, 0.14, 0.5), 1.0)
			ci.draw_line(Vector2(-7, -10), Vector2(6, -11), Color(1.0, 0.86, 0.6, 0.45), 1.0)
			_ell(ci, Vector2(15, -1), 3.0, 2.0, Color("9a7248"))
			_ell(ci, Vector2(14.5, -1.8), 1.6, 0.9, Color("c9a06c"))
		"bp_bones":
			# a horned skull bleaching in the sand, with a few ribs
			for k in 3:
				var x := 4.0 + 4.0 * k
				ci.draw_arc(Vector2(x, 0), 5.0, PI, TAU, 8, Color("d8cdb0"), 1.4)
			ci.draw_line(Vector2(2, -1), Vector2(15, -1), Color("cfc3a4"), 1.4)
			ci.draw_arc(Vector2(-8, -8), 7.0, PI * 1.05, PI * 1.6, 8, Color("efe6cc"), 2.0)
			ci.draw_arc(Vector2(2, -8), 7.0, PI * 1.4, PI * 1.95, 8, Color("efe6cc"), 2.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -9), Vector2(1, -9), Vector2(0, -3), Vector2(-2, 1), Vector2(-4, 1), Vector2(-6, -3)]), Color("efe6cc"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -9), Vector2(-3, -9), Vector2(-4, 1), Vector2(-6, -3)]), Color("fffaf0"))
			ci.draw_rect(Rect2(-6, -7, 2, 2), Color("3a2a26"))
			ci.draw_rect(Rect2(-2, -7, 2, 2), Color("3a2a26"))
			ci.draw_rect(Rect2(-4, -2, 1, 2), Color("8a7a64"))
		"bp_snow_rock":
			_tri(ci, Vector2(-11, 0), Vector2(-8, -10), Vector2(11, 0), Color("6e7690"))
			_tri(ci, Vector2(-8, -10), Vector2(6, -13), Vector2(11, 0), Color("5a6078"))
			_tri(ci, Vector2(6, -13), Vector2(12, -4), Vector2(11, 0), Color("4a4f66"))
			_tri(ci, Vector2(-9, -8), Vector2(-1, -15), Vector2(7, -12), Color("f4f8ff"))
			_tri(ci, Vector2(-9, -8), Vector2(7, -12), Vector2(3, -9), Color("dbe6f6"))
			_tri(ci, Vector2(7, -12), Vector2(11, -6), Vector2(5, -9), Color("c8d6ee"))
			ci.draw_line(Vector2(-6, -5), Vector2(3, -4), Color(1, 1, 1, 0.25), 1.0)
		"bp_ice_crystal":
			_ell(ci, Vector2(0, -3), 12.0, 6.0, Color(0.6, 0.85, 1.0, 0.12))
			for k in [[-6.0, 11.0, -0.25], [1.0, 19.0, 0.05], [7.0, 12.0, 0.3], [-1.0, 8.0, -0.6]]:
				_shard(ci, Vector2(k[0], 0), k[1], k[2])
			ci.draw_rect(Rect2(0, -17, 1, 1), Color.WHITE)
		"bp_snowdrift":
			_ell(ci, Vector2(0, -3), 12.0, 5.0, Color("b9c8e2"))
			_ell(ci, Vector2(-3, -5), 9.0, 5.0, Color("dfe9f8"))
			_ell(ci, Vector2(4, -4), 7.0, 4.0, Color("d2def2"))
			_ell(ci, Vector2(-4, -7), 5.0, 2.6, Color("f8fbff"))
			ci.draw_line(Vector2(5, -8), Vector2(8, -14), Color("5a4a3a"), 1.0)
			ci.draw_line(Vector2(7, -11), Vector2(10, -12), Color("5a4a3a"), 1.0)
		"bp_frost_bush":
			_ell(ci, Vector2(0, -6), 10.0, 7.0, Color("2f5a52"))
			_ell(ci, Vector2(-2, -8), 7.0, 5.0, Color("3e7066"))
			_ell(ci, Vector2(-3, -11), 7.0, 2.6, Color("eef4ff"))
			_ell(ci, Vector2(4, -8), 4.0, 2.0, Color("dce6f8"))
			_ell(ci, Vector2(-6, -5), 2.5, 1.4, Color("dce6f8"))
			ci.draw_rect(Rect2(3, -6, 2, 2), Color("c8344a"))
			ci.draw_rect(Rect2(-1, -4, 2, 2), Color("c8344a"))
		"bp_snowman":
			_ell(ci, Vector2(0, -6), 8.0, 6.5, Color("dbe5f5"))
			_ell(ci, Vector2(-1.5, -7.5), 6.0, 4.5, Color("f6f9ff"))
			_ell(ci, Vector2(0, -16), 5.5, 5.0, Color("dbe5f5"))
			_ell(ci, Vector2(-1, -17), 4.0, 3.6, Color("f6f9ff"))
			ci.draw_rect(Rect2(-6, -22, 11, 2), Color("2a2430"))
			ci.draw_rect(Rect2(-4, -27, 7, 5), Color("2a2430"))
			ci.draw_rect(Rect2(-4, -23, 7, 1), Color("b83a3a"))
			ci.draw_rect(Rect2(-2, -18, 1, 1), Color("1a1820"))
			ci.draw_rect(Rect2(2, -18, 1, 1), Color("1a1820"))
			_tri(ci, Vector2(0, -16), Vector2(6, -15), Vector2(0, -14.6), Color("f0882a"))
			ci.draw_line(Vector2(-5, -12), Vector2(-11, -16), Color("5a4030"), 1.0)
			ci.draw_line(Vector2(5, -12), Vector2(10, -15), Color("5a4030"), 1.0)
			ci.draw_rect(Rect2(-5, -12, 10, 2), Color("c84040"))
		"bp_mushrooms":
			for k in [[-6.0, 7.0, 4.5], [3.0, 11.0, 5.5], [9.0, 5.0, 3.5]]:
				_toadstool(ci, Vector2(k[0], 0), k[1], k[2], Color("c8342e") if v < 0.7 else Color("d8782c"))
		"bp_reeds":
			_ell(ci, Vector2(0, -1), 10.0, 3.0, Color(0.1, 0.18, 0.18, 0.55))
			for k in [[-7.0, 13.0, -1.5], [-3.0, 19.0, 0.5], [1.0, 16.0, 2.0], [5.0, 21.0, 1.0], [8.0, 12.0, 3.0]]:
				var x: float = k[0]
				var h: float = k[1]
				var lean: float = k[2]
				ci.draw_line(Vector2(x, 0), Vector2(x + lean, -h), Color("5e7a3a"), 1.0)
				ci.draw_rect(Rect2(x + lean - 1.0, -h - 1.0, 2.5, 5.0), Color("5a3a22"))
				ci.draw_rect(Rect2(x + lean - 1.0, -h - 1.0, 1.0, 4.0), Color("8a5a32"))
			ci.draw_line(Vector2(-2, 0), Vector2(-9, -9), Color("7a9a4a"), 1.0)
			ci.draw_line(Vector2(3, 0), Vector2(10, -7), Color("6a8a3e"), 1.0)
		"bp_swamp_stump":
			_tri(ci, Vector2(-9, 0), Vector2(-6, -4), Vector2(-3, 0), Color("3a2a1e"))
			_tri(ci, Vector2(3, 0), Vector2(6, -4), Vector2(10, 0), Color("3a2a1e"))
			ci.draw_rect(Rect2(-6, -12, 12, 12), Color("4e3a28"))
			ci.draw_rect(Rect2(-6, -12, 3, 12), Color("6a5034"))
			ci.draw_rect(Rect2(3, -12, 3, 12), Color("3a2a1c"))
			_ell(ci, Vector2(0, -12), 6.0, 2.5, Color("7a6040"))
			_ell(ci, Vector2(0, -12), 3.5, 1.4, Color("2a1c12"))
			_ell(ci, Vector2(-4, -8), 3.0, 4.0, Color("4a7a36"))
			_ell(ci, Vector2(-4.5, -9), 1.6, 2.0, Color("6a9a46"))
			ci.draw_rect(Rect2(4, -7, 3, 1), Color("b8e070"))
			ci.draw_rect(Rect2(4, -5, 2, 1), Color("b8e070"))
			_ell(ci, Vector2(10, -1), 1.4, 1.4, Color(0.6, 1.0, 0.5, 0.85))
		"bp_lily":
			_ell(ci, Vector2(0, -1), 13.0, 4.5, Color("1a2e2c"))
			_ell(ci, Vector2(0, -1.5), 11.0, 3.5, Color("223c38"))
			_ell(ci, Vector2(-5, -2), 4.0, 2.0, Color("4a8a3a"))
			_ell(ci, Vector2(4, 0), 3.5, 1.6, Color("3e7a32"))
			_ell(ci, Vector2(5, -3), 2.6, 1.3, Color("5a9a44"))
			ci.draw_line(Vector2(-5, -2), Vector2(-2, -2), Color("223c38"), 1.0)
			_ell(ci, Vector2(-5, -3.5), 1.8, 1.2, Color("f2c6d8"))
			ci.draw_rect(Rect2(-5.5, -4, 1, 1), Color("fff0a0"))
			ci.draw_line(Vector2(-9, 0), Vector2(-3, 0), Color(0.6, 0.75, 0.75, 0.4), 1.0)
		"bp_cross":
			# a weathered stone cross on a grave mound
			_ell(ci, Vector2(1, -2), 10.0, 3.5, Color("3e3a3a"))
			_ell(ci, Vector2(0, -3), 8.0, 2.5, Color("4e4840"))
			ci.draw_rect(Rect2(-2, -21, 5, 19), Color("7c788c"))
			ci.draw_rect(Rect2(-7, -16, 15, 4), Color("7c788c"))
			ci.draw_rect(Rect2(-2, -21, 2, 19), Color("a4a0b4"))
			ci.draw_rect(Rect2(-7, -16, 15, 1), Color("a4a0b4"))
			ci.draw_rect(Rect2(2, -21, 1, 19), Color("5c586a"))
			ci.draw_rect(Rect2(-7, -13, 15, 1), Color("5c586a"))
			ci.draw_rect(Rect2(-1, -8, 2, 2), Color("5a7a3a"))
			ci.draw_rect(Rect2(3, -4, 2, 1), Color("6a8a42"))
		"bp_tomb":
			_ell(ci, Vector2(1, -2), 11.0, 3.5, Color("3e3a3a"))
			ci.draw_rect(Rect2(-7, -15, 14, 14), Color("6e6a80"))
			_ell(ci, Vector2(0, -15), 7.0, 5.0, Color("6e6a80"))
			ci.draw_rect(Rect2(-7, -15, 3, 14), Color("8e8aa0"))
			ci.draw_rect(Rect2(4, -15, 3, 14), Color("56526a"))
			ci.draw_rect(Rect2(-1, -15, 2, 8), Color("4a4660"))
			ci.draw_rect(Rect2(-3, -13, 6, 2), Color("4a4660"))
			ci.draw_line(Vector2(2, -6), Vector2(5, -3), Color("3a364a"), 1.0)
			_ell(ci, Vector2(-5, -1.5), 3.0, 1.5, Color("4a6a36"))
			ci.draw_rect(Rect2(5, -3, 2, 2), Color("d8d2b8"))
		"bp_skull_pile":
			for k in [[-5.0, -3.0], [5.0, -3.0], [0.0, -9.0]]:
				_skull(ci, Vector2(k[0], k[1]))
			ci.draw_line(Vector2(-9, 0), Vector2(-2, -1), Color("d8d0b8"), 1.5)
		"bp_dead_bush":
			var bc := Color("3c2e2a")
			for a in [[-0.9, 11.0], [-0.35, 16.0], [0.25, 14.0], [0.85, 10.0]]:
				var ang: float = a[0]
				var ln: float = a[1]
				var d := Vector2(sin(ang), -cos(ang)) * ln
				ci.draw_line(Vector2.ZERO, d, bc, 1.5)
				ci.draw_line(d * 0.55, d * 0.55 + Vector2(signf(ang + 0.01) * 4.0, -4.0), bc, 1.0)
				ci.draw_line(d * 0.85, d * 0.85 + Vector2(-signf(ang + 0.01) * 3.0, -3.0), bc, 1.0)
			ci.draw_line(Vector2(-1, -1), Vector2(-6, -10), Color("5a4a40"), 1.0)
		"bp_leaf_pile":
			_ell(ci, Vector2(0, -3), 12.0, 4.5, Color("8a3a18"))
			_ell(ci, Vector2(-1, -5), 10.0, 4.0, Color("b8501c"))
			_ell(ci, Vector2(-3, -6), 6.0, 2.6, Color("d8742a"))
			for k in [[-8.0, -3.0, Color("e8a030")], [6.0, -2.0, Color("c8401c")], [0.0, -8.0, Color("f0b83c")], [-4.0, -1.0, Color("a83418")], [9.0, -4.0, Color("e88a2a")], [3.0, -5.0, Color("f2c04a")]]:
				_ell(ci, Vector2(k[0], k[1]), 2.2, 1.2, k[2], 6)
			ci.draw_line(Vector2(14, 1), Vector2(17, -1), Color("d86a20"), 1.0)
		"bp_pumpkin":
			_pumpkin(ci, Vector2.ZERO, false)
			if v > 0.6:
				_pumpkin(ci, Vector2(-11, 1), false, 0.6)
		"bp_jack":
			_pumpkin(ci, Vector2.ZERO, true)
		_:
			ci.draw_circle(Vector2(0, -4), 4.0, Color(1, 0, 1, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _cactus(ci: CanvasItem, v: float) -> void:
	var h := 18.0 + 8.0 * v
	var dark := Color("3e7a3a")
	var mid := Color("58984a")
	var lite := Color("86c06a")
	ci.draw_rect(Rect2(-3.5, -h, 7, h), mid)
	_ell(ci, Vector2(0, -h), 3.5, 3.0, mid, 8)
	ci.draw_rect(Rect2(1.5, -h, 2, h), dark)
	ci.draw_rect(Rect2(-2.5, -h, 1.5, h - 1), lite)
	# two arms, at different heights
	var ay := -h * 0.55
	ci.draw_rect(Rect2(-10, ay, 7, 4), mid)
	ci.draw_rect(Rect2(-10, ay - 8, 4, 10), mid)
	_ell(ci, Vector2(-8, ay - 8), 2.0, 2.0, mid, 6)
	ci.draw_rect(Rect2(-10, ay - 8, 1.2, 10), lite)
	if v > 0.3:
		var by := -h * 0.38
		ci.draw_rect(Rect2(3, by, 6, 4), mid)
		ci.draw_rect(Rect2(6, by - 7, 4, 9), mid)
		_ell(ci, Vector2(8, by - 7), 2.0, 2.0, mid, 6)
		ci.draw_rect(Rect2(8.6, by - 7, 1.4, 9), dark)
	for k in 4:
		ci.draw_rect(Rect2(-1, -h + 4.0 + k * 5.0, 1, 1), Color(1, 1, 0.85, 0.8))
	if v > 0.55:
		_ell(ci, Vector2(0, -h - 2.5), 2.2, 1.6, Color("f06a8a"), 6)
		ci.draw_rect(Rect2(-0.5, -h - 3, 1, 1), Color("ffe08a"))


static func _shard(ci: CanvasItem, base: Vector2, h: float, lean: float) -> void:
	var tip := base + Vector2(lean * h, -h)
	var l := base + Vector2(-3, 0)
	var r := base + Vector2(3, 0)
	var mid := base + Vector2(lean * h * 0.15, -h * 0.15)
	_tri(ci, l, tip, mid, Color(0.78, 0.94, 1.0, 0.95))
	_tri(ci, mid, tip, r, Color(0.42, 0.7, 0.92, 0.95))
	ci.draw_line(l.lerp(tip, 0.2) + Vector2(0.8, 0), l.lerp(tip, 0.75) + Vector2(0.6, 0), Color(1, 1, 1, 0.85), 1.0)


static func _toadstool(ci: CanvasItem, base: Vector2, h: float, r: float, cap: Color) -> void:
	ci.draw_rect(Rect2(base.x - 1.5, base.y - h, 3, h), Color("e8dcc0"))
	ci.draw_rect(Rect2(base.x + 0.5, base.y - h, 1, h), Color("b8a888"))
	var top := base + Vector2(0, -h)
	_ell(ci, top + Vector2(0, 1), r, r * 0.45, Color("8a6a50"), 10)
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-r, 1), top + Vector2(-r * 0.7, -r * 0.6), top + Vector2(0, -r * 0.85), top + Vector2(r * 0.7, -r * 0.6), top + Vector2(r, 1)]), cap)
	_tri(ci, top + Vector2(-r * 0.7, -r * 0.6), top + Vector2(0, -r * 0.85), top + Vector2(-r * 0.2, -r * 0.3), cap.lightened(0.25))
	ci.draw_rect(Rect2(top.x - r * 0.5, top.y - r * 0.45, 1.5, 1.5), Color(1, 0.97, 0.9))
	ci.draw_rect(Rect2(top.x + r * 0.25, top.y - r * 0.2, 1.5, 1.5), Color(1, 0.97, 0.9))


static func _skull(ci: CanvasItem, c: Vector2) -> void:
	_ell(ci, c, 4.5, 4.0, Color("d8d0b8"), 10)
	_ell(ci, c + Vector2(-0.8, -0.8), 3.4, 3.0, Color("f0e8d4"), 10)
	ci.draw_rect(Rect2(c.x - 2.5, c.y + 2.5, 5, 2), Color("d8d0b8"))
	ci.draw_rect(Rect2(c.x - 2.6, c.y - 0.5, 2, 2), Color("2a2030"))
	ci.draw_rect(Rect2(c.x + 0.6, c.y - 0.5, 2, 2), Color("2a2030"))
	ci.draw_rect(Rect2(c.x - 0.3, c.y + 2, 1, 1), Color("4a4040"))


static func _pumpkin(ci: CanvasItem, c: Vector2, lit: bool, s: float = 1.0) -> void:
	if lit:
		_ell(ci, c + Vector2(0, -6), 14.0, 8.0, Color(1.0, 0.6, 0.2, 0.18))
	_ell(ci, c + Vector2(-4, -5) * s, 4.5 * s, 5.0 * s, Color("c85a14"), 10)
	_ell(ci, c + Vector2(4, -5) * s, 4.5 * s, 5.0 * s, Color("b04c10"), 10)
	_ell(ci, c + Vector2(0, -5.5) * s, 4.5 * s, 5.5 * s, Color("e87a22"), 10)
	_ell(ci, c + Vector2(-1.5, -7.5) * s, 2.0 * s, 2.5 * s, Color("f8a24a"), 8)
	ci.draw_rect(Rect2(c + Vector2(-1, -12.5) * s, Vector2(2, 3.5) * s), Color("4a5a24"))
	ci.draw_line(c + Vector2(1, -11) * s, c + Vector2(5, -12) * s, Color("5a7a2a"), 1.0)
	if lit:
		_tri(ci, c + Vector2(-4, -7), c + Vector2(-2, -7), c + Vector2(-3, -9), Color("ffe070"))
		_tri(ci, c + Vector2(2, -7), c + Vector2(4, -7), c + Vector2(3, -9), Color("ffe070"))
		ci.draw_rect(Rect2(c + Vector2(-4, -4), Vector2(8, 2)), Color("ffd060"))
		ci.draw_rect(Rect2(c + Vector2(-2, -4), Vector2(1, 1)), Color("c85a14"))
		ci.draw_rect(Rect2(c + Vector2(1, -3), Vector2(1, 1)), Color("c85a14"))

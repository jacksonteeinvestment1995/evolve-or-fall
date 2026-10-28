class_name Towns
extends RefCounted
## Villages and castles, placed at random every time the game starts (see main.gd). generate() clears room for
## them, marks solid tiles in main.buildings (and main.trees, so they block walking and path-finding), and
## returns a layout whose "pieces" list is every sprite to draw (the town layer turns each into a node):
##   one BIG castle in a map corner (16 x 16 tiles) behind a moat, with a gatehouse, corner towers, mid-wall
##   towers, a keep, barracks, stables, tents and market stalls in its courtyard
##   2 to 3 SMALL castles (8 x 8 tiles), moated, with four towers, a gate and a hall
##   4 to 7 VILLAGES with cottages, houses, an inn, a barn, a well and market stalls, dirt paths and props
## populate() then fills them: residents in villages, soldiers and chests in castles.

const BIG := 16
const SMALL := 8

## sprite name -> [footprint in tiles, sprite size in px]
const KIT := {
	"village_cottage": [Vector2i(2, 2), Vector2i(64, 80)],
	"village_house_a": [Vector2i(3, 2), Vector2i(96, 80)],
	"village_house_b": [Vector2i(3, 2), Vector2i(96, 88)],
	"village_inn": [Vector2i(4, 3), Vector2i(128, 112)],
	"village_barn": [Vector2i(4, 3), Vector2i(128, 104)],
	"prop_stall_red": [Vector2i(2, 1), Vector2i(64, 56)],
	"prop_stall_blue": [Vector2i(2, 1), Vector2i(64, 56)],
	"prop_stall_green": [Vector2i(2, 1), Vector2i(64, 56)],
	"prop_well": [Vector2i(1, 1), Vector2i(32, 48)],
	"prop_cart": [Vector2i(2, 1), Vector2i(64, 40)],
	"prop_tent_a": [Vector2i(2, 2), Vector2i(64, 56)],
	"prop_tent_b": [Vector2i(2, 2), Vector2i(64, 56)],
	"castle_tower_big": [Vector2i(3, 3), Vector2i(96, 136)],
	"castle_tower_small": [Vector2i(2, 2), Vector2i(64, 104)],
	"castle_tower_mid": [Vector2i(2, 2), Vector2i(64, 88)],
	"castle_keep": [Vector2i(6, 6), Vector2i(192, 176)],
	"castle_barracks": [Vector2i(3, 2), Vector2i(96, 80)],
	"castle_stable": [Vector2i(3, 2), Vector2i(96, 72)],
}
const SMALL_PROPS := ["prop_barrels", "prop_haystack", "prop_woodpile", "prop_bench", "prop_planter", "prop_signpost", "prop_lamppost"]


static func generate(main: Node2D, rng: RandomNumberGenerator) -> Dictionary:
	var layout := {"big": {}, "small": [], "villages": [], "pieces": [], "lights": []}
	var used: Array[Rect2i] = [Rect2i(main.START_TILE - Vector2i(18, 18), Vector2i(37, 37))]   # the base meadow stays free
	var cols: int = main.COLS
	var rows: int = main.ROWS
	# --- the big castle: a corner away from the start (the start is top left) ---
	var corners := [Vector2i(cols - BIG - 5, 5), Vector2i(cols - BIG - 5, rows - BIG - 5), Vector2i(5, rows - BIG - 5)]
	var corner: Vector2i = corners[rng.randi_range(0, corners.size() - 1)]
	var big_rect := Rect2i(corner, Vector2i(BIG, BIG))
	var gate_dir := Vector2i(-1, 0) if big_rect.position.x > cols / 2 else Vector2i(1, 0)
	layout["big"] = _castle(main, rng, layout, big_rect, gate_dir, "big")
	used.append(big_rect.grow(6))
	# --- small castles ---
	var want := rng.randi_range(2, 3)
	var tries := 0
	while layout["small"].size() < want and tries < 250:
		tries += 1
		var pos := Vector2i(rng.randi_range(8, cols - SMALL - 9), rng.randi_range(8, rows - SMALL - 9))
		var rect := Rect2i(pos, Vector2i(SMALL, SMALL))
		if _blocked(rect.grow(6), used, main) or Vector2(pos - main.START_TILE).length() < 45.0:
			continue
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		layout["small"].append(_castle(main, rng, layout, rect, dirs[rng.randi_range(0, 3)], "small"))
		used.append(rect.grow(6))
	# --- villages ---
	var vcount := rng.randi_range(4, 7)
	tries = 0
	while layout["villages"].size() < vcount and tries < 300:
		tries += 1
		var center := Vector2i(rng.randi_range(16, cols - 17), rng.randi_range(13, rows - 14))
		if Vector2(center - main.START_TILE).length() < 32.0:
			continue
		var area := Rect2i(center - Vector2i(10, 8), Vector2i(21, 17))
		if _blocked(area, used, main):
			continue
		var village := _village(main, rng, layout, center, used)
		if village["houses"].size() >= 3:
			layout["villages"].append(village)
			used.append(area)
	return layout


static func _blocked(rect: Rect2i, used: Array[Rect2i], main: Node2D) -> bool:
	for u in used:
		if u.intersects(rect):
			return true
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if main.water.has(Vector2i(x, y)):
				return true
	return false


## Remove trees, mud, water and paths from a rectangle (towns need flat, clear ground).
static func _clear(main: Node2D, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if t.x > 0 and t.y > 0 and t.x < main.COLS - 1 and t.y < main.ROWS - 1:
				main.trees.erase(t)
				main.mud.erase(t)
				main.water.erase(t)
				main.paths.erase(t)


static func _solid(main: Node2D, t: Vector2i, kind: String) -> void:
	main.buildings[t] = kind
	main.trees[t] = true


## Add a sprite to draw, anchored at the bottom-left corner of its footprint (tile coordinates).
static func _piece(layout: Dictionary, sprite: String, foot_tl: Vector2i, foot: Vector2i, light: bool = false) -> void:
	var bl := Vector2(foot_tl.x * 32, (foot_tl.y + foot.y) * 32)
	layout["pieces"].append({"name": sprite, "pos": bl, "w": foot.x * 32})
	if light:
		layout["lights"].append(bl + Vector2(foot.x * 16, -foot.y * 16))


static func _footprint_free(main: Node2D, rect: Rect2i, need_floor: bool = false) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			if main.buildings.has(t) or main.trees.has(t) or main.water.has(t):
				return false
			if need_floor and not main.floors.has(t):
				return false
	return true


# --- castles ---

static func _castle(main: Node2D, rng: RandomNumberGenerator, layout: Dictionary, rect: Rect2i, gate_dir: Vector2i, kind: String) -> Dictionary:
	_clear(main, rect.grow(4))
	var big := kind == "big"
	var tower := 3 if big else 2
	var gate_w := 3
	var towers: Array[Rect2i] = [
		Rect2i(rect.position, Vector2i(tower, tower)),
		Rect2i(Vector2i(rect.end.x - tower, rect.position.y), Vector2i(tower, tower)),
		Rect2i(Vector2i(rect.position.x, rect.end.y - tower), Vector2i(tower, tower)),
		Rect2i(rect.end - Vector2i(tower, tower), Vector2i(tower, tower)),
	]
	var center := rect.get_center()
	var gate := Rect2i()
	if gate_dir.x != 0:
		var gx := rect.position.x if gate_dir.x < 0 else rect.end.x - 1
		gate = Rect2i(Vector2i(gx, center.y - gate_w / 2), Vector2i(1, gate_w))
	else:
		var gy := rect.position.y if gate_dir.y < 0 else rect.end.y - 1
		gate = Rect2i(Vector2i(center.x - gate_w / 2, gy), Vector2i(gate_w, 1))
	# mid-wall towers (big castle): the middle of each wall except the gate's
	var mids: Array[Rect2i] = []
	if big:
		var m := rect.get_center()
		var cands := [
			Rect2i(Vector2i(m.x - 1, rect.position.y), Vector2i(2, 2)),
			Rect2i(Vector2i(m.x - 1, rect.end.y - 2), Vector2i(2, 2)),
			Rect2i(Vector2i(rect.position.x, m.y - 1), Vector2i(2, 2)),
			Rect2i(Vector2i(rect.end.x - 2, m.y - 1), Vector2i(2, 2)),
		]
		for cnd in cands:
			if not cnd.intersects(gate.grow(1)):
				mids.append(cnd)
	var keep := Rect2i()
	if big:
		var kx := rect.position.x + 3 if gate_dir.x > 0 else rect.end.x - 9
		keep = Rect2i(Vector2i(kx, center.y - 3), Vector2i(6, 6))
	# the walls, towers and courtyard
	var gate_flank: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			var edge := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
			var covered := false
			for tw in towers:
				if tw.has_point(t):
					covered = true
			for tw in mids:
				if tw.has_point(t):
					covered = true
			if covered:
				_solid(main, t, "tower")
			elif keep.has_point(t):
				_solid(main, t, "keep")
			elif edge and not gate.has_point(t):
				_solid(main, t, "wall")
				if gate.grow(1).has_point(t) and not gate.has_point(t):
					gate_flank.append(t)
			else:
				main.floors[t] = true
	# pave the whole footprint, so no grass shows under walls, towers and the keep
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			main.floors[Vector2i(x, y)] = true
	# wall pieces: a few variants and torches
	for t in main.buildings:
		if main.buildings[t] == "wall" and rect.has_point(t):
			var h := absi((t.x * 73856093) ^ (t.y * 19349663)) % 11
			var sprite := "castle_wall_a" if h % 2 == 0 else "castle_wall_b"
			var torch := h == 3
			if gate_flank.has(t):
				sprite = "castle_gate_pillar"
				torch = true
			elif torch:
				sprite = "castle_wall_torch"
			_piece(layout, sprite, t, Vector2i(1, 1), torch)
	for tw in towers:
		_piece(layout, "castle_tower_big" if big else "castle_tower_small", tw.position, tw.size)
	for tw in mids:
		_piece(layout, "castle_tower_mid", tw.position, tw.size)
	if big:
		_piece(layout, "castle_keep", keep.position, keep.size, true)
	if gate_dir.y == 0 and gate_dir.x == 0:
		pass
	elif gate_dir.x == 0:
		# the arch above a gate in a horizontal wall
		layout["pieces"].append({"name": "castle_gate_h", "pos": Vector2(gate.position.x * 32, (gate.position.y + 1) * 32), "w": gate_w * 32})
	# a paved apron in front of the gate, and the moat with a bridge across it
	for k in 4:
		for y in range(gate.position.y, gate.end.y):
			for x in range(gate.position.x, gate.end.x):
				var ft := Vector2i(x, y) + gate_dir * (k + 1)
				if k < 2:
					main.bridges[ft] = true
				else:
					main.floors[ft] = true
	var bridge_len := 2
	var moat: Array[Vector2i] = []
	for y in range(rect.position.y - 2, rect.end.y + 2):
		for x in range(rect.position.x - 2, rect.end.x + 2):
			var t := Vector2i(x, y)
			if rect.has_point(t):
				continue
			if t.x < 1 or t.y < 1 or t.x > main.COLS - 2 or t.y > main.ROWS - 2:
				continue
			if main.bridges.has(t):
				continue
			main.water[t] = true
			main.trees.erase(t)
			moat.append(t)
	var yard := {"rect": rect, "gate": gate, "gate_dir": gate_dir, "kind": kind, "towers": towers, "keep": keep, "moat": moat}
	_furnish(main, rng, layout, yard)
	return yard


## Buildings, tents, stalls and props in the courtyard, leaving a free lane from the gate to the middle.
static func _furnish(main: Node2D, rng: RandomNumberGenerator, layout: Dictionary, c: Dictionary) -> void:
	var rect: Rect2i = c["rect"]
	var gate: Rect2i = c["gate"]
	var dir: Vector2i = c["gate_dir"]
	var lane := gate.grow(0)
	lane = Rect2i(gate.position - dir * 0, gate.size)
	var lane_tiles := {}
	for k in range(0, 8):
		for y in range(gate.position.y, gate.end.y):
			for x in range(gate.position.x, gate.end.x):
				lane_tiles[Vector2i(x, y) - dir * k] = true
	var plan: Array = []
	if c["kind"] == "big":
		plan = ["castle_barracks", "castle_barracks", "castle_stable", "prop_stall_red", "prop_stall_blue", "prop_tent_a", "prop_tent_b", "prop_tent_a", "prop_cart"]
	else:
		plan = ["castle_barracks" if rng.randf() < 0.5 else "castle_stable", "prop_tent_a" if rng.randf() < 0.5 else "prop_tent_b"]
	for name in plan:
		var foot: Vector2i = KIT[name][0]
		for i in 40:
			var pos := Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 1 - foot.x), rng.randi_range(rect.position.y + 1, rect.end.y - 1 - foot.y))
			var r := Rect2i(pos, foot)
			var ok := _footprint_free(main, r.grow(0), true)
			if ok:
				for y in range(r.position.y - 1, r.end.y + 1):
					for x in range(r.position.x - 1, r.end.x + 1):
						if lane_tiles.has(Vector2i(x, y)):
							ok = false
			if ok:
				for t in _tiles(r):
					_solid(main, t, "hall")
				_piece(layout, name, pos, foot)
				break
	# small props between the buildings
	for i in (10 if c["kind"] == "big" else 4):
		var t := Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 2), rng.randi_range(rect.position.y + 1, rect.end.y - 2))
		if main.floors.has(t) and not main.buildings.has(t) and not lane_tiles.has(t) and not main.decor.has(t):
			var sp: String = SMALL_PROPS[rng.randi_range(0, SMALL_PROPS.size() - 1)]
			main.decor[t] = sp
			_piece(layout, sp, t, Vector2i(1, 1), sp == "prop_lamppost")


static func _tiles(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2i(x, y))
	return out


# --- villages ---

static func _village(main: Node2D, rng: RandomNumberGenerator, layout: Dictionary, center: Vector2i, used: Array[Rect2i]) -> Dictionary:
	_clear(main, Rect2i(center - Vector2i(10, 8), Vector2i(21, 17)))
	var houses: Array = []
	var taken: Array[Rect2i] = []
	var want := rng.randi_range(3, 6)
	var has_inn := false
	var has_barn := false
	for i in 60:
		if houses.size() >= want:
			break
		var types := ["village_cottage", "village_house_a", "village_house_b", "village_house_a", "village_cottage"]
		if not has_inn and houses.size() >= 2:
			types.append("village_inn")
			types.append("village_inn")
		if not has_barn and houses.size() >= 2:
			types.append("village_barn")
		var type: String = types[rng.randi_range(0, types.size() - 1)]
		var foot: Vector2i = KIT[type][0]
		var pos := center + Vector2i(rng.randi_range(-8, 6), rng.randi_range(-6, 4))
		var rect := Rect2i(pos, foot)
		var ok := true
		# keep a ring of space around the plaza (the well and stalls)
		if rect.grow(1).intersects(Rect2i(center - Vector2i(2, 2), Vector2i(5, 5))):
			ok = false
		for h in taken:
			if h.grow(1).intersects(rect):
				ok = false
		if not ok or _blocked(rect, used, main):
			continue
		taken.append(rect)
		if type == "village_inn":
			has_inn = true
		if type == "village_barn":
			has_barn = true
		houses.append({"rect": rect, "seed": rng.randi(), "type": type})
	for h in houses:
		for t in _tiles(h["rect"]):
			_solid(main, t, "house")
		_piece(layout, h["type"], h["rect"].position, h["rect"].size, true)
		# a dirt path from the door to the plaza
		var door := Vector2i(h["rect"].position.x + h["rect"].size.x / 2, h["rect"].end.y)
		_path(main, door, center)
	# the plaza: a well with market stalls around it
	_solid(main, center, "well")
	_piece(layout, "prop_well", center, Vector2i(1, 1))
	for t in _tiles(Rect2i(center - Vector2i(2, 2), Vector2i(5, 5))):
		if not main.buildings.has(t):
			main.dirt[t] = true
	var stalls := ["prop_stall_red", "prop_stall_blue", "prop_stall_green"]
	var slots := [Vector2i(-3, -2), Vector2i(2, -2), Vector2i(-3, 2), Vector2i(2, 2)]
	for i in rng.randi_range(2, 3):
		var s: Vector2i = center + slots[i]
		var r := Rect2i(s, Vector2i(2, 1))
		if _footprint_free(main, r):
			for t in _tiles(r):
				_solid(main, t, "stall")
			_piece(layout, stalls[i % 3], s, r.size)
	# props: barrels, haystacks, lamp posts and the like beside the houses and paths
	for k in rng.randi_range(10, 16):
		var t := center + Vector2i(rng.randi_range(-9, 9), rng.randi_range(-7, 7))
		if not main.buildings.has(t) and not main.trees.has(t) and not main.decor.has(t) and not main.dirt.has(t):
			var sp: String = SMALL_PROPS[rng.randi_range(0, SMALL_PROPS.size() - 1)]
			main.decor[t] = sp
			_piece(layout, sp, t, Vector2i(1, 1), sp == "prop_lamppost")
	# fences and bushes on free tiles (no collision)
	for h in houses:
		var rect: Rect2i = h["rect"]
		for k in rng.randi_range(1, 3):
			var t := Vector2i(rng.randi_range(rect.position.x - 1, rect.end.x), rect.end.y + 1)
			if not main.buildings.has(t) and not main.trees.has(t) and not main.dirt.has(t) and not main.decor.has(t):
				main.props[t] = ["prop_fence", "prop_bush", "prop_flowers_1", "prop_flowers_2"][rng.randi_range(0, 3)]
	return {"center": center, "houses": houses, "well": center}


## An L-shaped dirt path from a to b (one tile wide, not through buildings).
static func _path(main: Node2D, a: Vector2i, b: Vector2i) -> void:
	var p := a
	while p.x != b.x:
		if not main.buildings.has(p):
			main.dirt[p] = true
		p.x += signi(b.x - p.x)
	while p.y != b.y:
		if not main.buildings.has(p):
			main.dirt[p] = true
		p.y += signi(b.y - p.y)


# --- people and loot ---

## Fill the towns: residents in the villages, soldiers and a chest in each castle, a big garrison in the big one.
static func populate(main: Node2D, layout: Dictionary, rng: RandomNumberGenerator) -> void:
	for v in layout["villages"]:
		var n := rng.randi_range(4, 8)
		for i in n:
			var spot := _free_near(main, v["center"], 5, rng)
			if spot.x >= 0:
				main._spawn_villager(main._tile_center(spot), rng.randi_range(0, 1))
	for c in layout["small"]:
		_garrison(main, c, rng.randi_range(4, 6), 1, 2, rng)
		_chest(main, c, "silver" if rng.randf() < 0.6 else "wood", rng)
	var big: Dictionary = layout["big"]
	if not big.is_empty():
		_garrison(main, big, rng.randi_range(12, 16), 3, 4, rng)
		_chest(main, big, "gold", rng)
		_chest(main, big, "gold" if rng.randf() < 0.6 else "silver", rng)


static func _free_near(main: Node2D, center: Vector2i, radius: int, rng: RandomNumberGenerator) -> Vector2i:
	for i in 30:
		var t: Vector2i = center + Vector2i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius))
		if t.x > 1 and t.y > 1 and t.x < main.COLS - 2 and t.y < main.ROWS - 2 and not main.trees.has(t) and not main.water.has(t):
			return t
	return Vector2i(-1, -1)


static func _courtyard(c: Dictionary, rng: RandomNumberGenerator, main: Node2D) -> Vector2i:
	var rect: Rect2i = c["rect"]
	for i in 60:
		var t := Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 2), rng.randi_range(rect.position.y + 1, rect.end.y - 2))
		if main.floors.has(t) and not main.trees.has(t):
			return t
	return Vector2i(-1, -1)


## Soldiers (knights, militia and nobles) standing in the courtyard.
static func _garrison(main: Node2D, c: Dictionary, count: int, stage_min: int, stage_max: int, rng: RandomNumberGenerator) -> void:
	var lines := [4, 3, 9, 3, 4]
	for i in count:
		var t := _courtyard(c, rng, main)
		if t.x >= 0:
			var v = main._spawn_villager(main._tile_center(t), rng.randi_range(stage_min, stage_max), lines[rng.randi_range(0, lines.size() - 1)])
			v.guard_home = Vector2(c["rect"].get_center()) * 32.0
			v.guard_range = 700.0 if c["kind"] == "big" else 480.0
			v.guard_leash = 900.0 if c["kind"] == "big" else 620.0
			v.guard_until = main.GUARD_RELEASE if c["kind"] == "big" else 780.0


static func _chest(main: Node2D, c: Dictionary, tier: String, rng: RandomNumberGenerator) -> void:
	var t := _courtyard(c, rng, main)
	if t.x < 0:
		return
	var chest = main.TreasureScript.new()
	chest.tier = tier
	chest.position = main._tile_center(t)
	main.treasure_spots.append(chest)

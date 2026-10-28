class_name Towns
extends RefCounted
## Villages and castles, placed at random every time the game starts (see main.gd). generate() clears room for
## them, marks their solid tiles in main.buildings (and main.trees, so they block walking and path-finding), marks
## castle courtyards in main.floors, and returns the layout the town layer draws:
##   one BIG castle in a map corner (16 x 16 tiles, 4 corner towers, a keep, a wide gate toward the map's middle)
##   2 to 3 SMALL castles (8 x 8 tiles, 4 small towers, a gate on a random side)
##   4 to 7 VILLAGES of 3 to 6 houses, with a well and some fences
## populate() then fills them: residents in villages, soldiers and chests in castles.

const BIG := 16
const SMALL := 8


static func generate(main: Node2D, rng: RandomNumberGenerator) -> Dictionary:
	var layout := {"big": {}, "small": [], "villages": []}
	var used: Array[Rect2i] = [Rect2i(main.START_TILE - Vector2i(18, 18), Vector2i(37, 37))]   # the base meadow stays free
	var cols: int = main.COLS
	var rows: int = main.ROWS
	# --- the big castle: a corner away from the start (the start is top left) ---
	var corners := [Vector2i(cols - BIG - 3, 3), Vector2i(cols - BIG - 3, rows - BIG - 3), Vector2i(3, rows - BIG - 3)]
	var corner: Vector2i = corners[rng.randi_range(0, corners.size() - 1)]
	var big_rect := Rect2i(corner, Vector2i(BIG, BIG))
	var gate_dir := Vector2i(-1, 0) if big_rect.position.x > cols / 2 else Vector2i(1, 0)
	layout["big"] = _castle(main, big_rect, gate_dir, "big")
	used.append(big_rect.grow(4))
	# --- small castles ---
	var want := rng.randi_range(2, 3)
	var tries := 0
	while layout["small"].size() < want and tries < 200:
		tries += 1
		var pos := Vector2i(rng.randi_range(6, cols - SMALL - 7), rng.randi_range(6, rows - SMALL - 7))
		var rect := Rect2i(pos, Vector2i(SMALL, SMALL))
		if _blocked(rect.grow(5), used, main) or Vector2(pos - main.START_TILE).length() < 45.0:
			continue
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		layout["small"].append(_castle(main, rect, dirs[rng.randi_range(0, 3)], "small"))
		used.append(rect.grow(5))
	# --- villages ---
	var vcount := rng.randi_range(4, 7)
	tries = 0
	while layout["villages"].size() < vcount and tries < 300:
		tries += 1
		var center := Vector2i(rng.randi_range(14, cols - 15), rng.randi_range(12, rows - 13))
		if Vector2(center - main.START_TILE).length() < 32.0:
			continue
		var area := Rect2i(center - Vector2i(8, 7), Vector2i(17, 15))
		if _blocked(area, used, main):
			continue
		var village := _village(main, rng, center, used)
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


## Remove trees and mud from a rectangle (towns need flat, clear ground).
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


# --- castles ---

static func _castle(main: Node2D, rect: Rect2i, gate_dir: Vector2i, kind: String) -> Dictionary:
	_clear(main, rect.grow(2))
	var tower := 3 if kind == "big" else 2
	var gate_w := 3 if kind == "big" else 2
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
	var keep := Rect2i()
	if kind == "big":
		# the keep sits at the back, opposite the gate
		var kx := rect.position.x + 2 if gate_dir.x > 0 else rect.end.x - 8
		keep = Rect2i(Vector2i(kx, center.y - 3), Vector2i(6, 6))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var t := Vector2i(x, y)
			var edge := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
			var in_tower := false
			for tw in towers:
				if tw.has_point(t):
					in_tower = true
			if in_tower:
				_solid(main, t, "tower")
			elif keep.has_point(t):
				_solid(main, t, "keep")
			elif edge and not gate.has_point(t):
				_solid(main, t, "wall")
			else:
				main.floors[t] = true
	# a paved apron in front of the gate
	var out := Rect2i(gate.position + gate_dir, gate.size) if gate_dir.x == 0 else Rect2i(gate.position + gate_dir, gate.size)
	for k in 3:
		var shift := gate_dir * k
		for y in range(gate.position.y, gate.end.y):
			for x in range(gate.position.x, gate.end.x):
				main.floors[Vector2i(x, y) + shift + gate_dir] = true
	return {"rect": rect, "gate": gate, "gate_dir": gate_dir, "kind": kind, "towers": towers, "keep": keep, "out": out}


# --- villages ---

static func _village(main: Node2D, rng: RandomNumberGenerator, center: Vector2i, used: Array[Rect2i]) -> Dictionary:
	var houses: Array = []
	var taken: Array[Rect2i] = []
	var want := rng.randi_range(3, 6)
	for i in 40:
		if houses.size() >= want:
			break
		var size := Vector2i(rng.randi_range(2, 3), 2)
		var pos := center + Vector2i(rng.randi_range(-6, 5), rng.randi_range(-5, 4))
		var rect := Rect2i(pos, size)
		var ok := true
		for h in taken:
			if h.grow(1).intersects(rect):
				ok = false
		if not ok or _blocked(rect, used, main):
			continue
		taken.append(rect)
		houses.append({"rect": rect, "seed": rng.randi()})
	_clear(main, Rect2i(center - Vector2i(8, 7), Vector2i(17, 15)))
	for h in houses:
		for y in range(h["rect"].position.y, h["rect"].end.y):
			for x in range(h["rect"].position.x, h["rect"].end.x):
				_solid(main, Vector2i(x, y), "house")
	# a well in the middle (a free tile near the centre)
	var well := Vector2i(-1, -1)
	for r in 4:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var t: Vector2i = center + d * (r + 1)
			if well.x < 0 and not main.buildings.has(t):
				well = t
	if well.x >= 0:
		_solid(main, well, "well")
	# fences and bushes on free tiles around the houses (no collision)
	for h in houses:
		var rect: Rect2i = h["rect"]
		for k in rng.randi_range(1, 3):
			var t := Vector2i(rng.randi_range(rect.position.x - 1, rect.end.x), rect.end.y)
			if not main.buildings.has(t) and not main.trees.has(t):
				main.props[t] = ["prop_fence", "prop_bush", "prop_flowers_1", "prop_flowers_2"][rng.randi_range(0, 3)]
	return {"center": center, "houses": houses, "well": well}


# --- people and loot ---

## Fill the towns: residents in the villages, soldiers and a chest in each castle, a big garrison in the big one.
static func populate(main: Node2D, layout: Dictionary, rng: RandomNumberGenerator) -> void:
	for v in layout["villages"]:
		var n := rng.randi_range(3, 6)
		for i in n:
			var h = v["houses"][rng.randi_range(0, v["houses"].size() - 1)]
			var spot := _free_near(main, h["rect"].get_center(), 4, rng)
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
	for i in 40:
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
			main._spawn_villager(main._tile_center(t), rng.randi_range(stage_min, stage_max), lines[rng.randi_range(0, lines.size() - 1)])


static func _chest(main: Node2D, c: Dictionary, tier: String, rng: RandomNumberGenerator) -> void:
	var t := _courtyard(c, rng, main)
	if t.x < 0:
		return
	var chest = main.TreasureScript.new()
	chest.tier = tier
	chest.position = main._tile_center(t)
	main.treasure_spots.append(chest)

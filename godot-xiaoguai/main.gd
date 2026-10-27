extends Node2D
## Stage 1: the forest edge. The map is generated from SEED, so it stays the same
## every run. Change the numbers below to reshape it.

const TILE := 32
const COLS := 180               # 180 x 100 = 18000 tiles: 5x the 80 x 45 map, 25x the first one
const ROWS := 100
const SEED := 7
const TREE_CLUSTERS := 110      # few and small, so paths stay open
const MUD_PATCHES := 70
const MUD_SLOW := 0.5
const START_TILE := Vector2i(4, 4)

## The village grows slowly at first and fastest near the end of RAMP_SECONDS (20 min).
const VILLAGER_COUNT := 30      # villagers on the map at the start (a gentle start)
const ELITE_COUNT := 0          # this many of the farthest start at ELITE_STAGE (the 3rd form)
const ELITE_STAGE := 2

## A gentle start: for the first minutes villagers are slower, notice 小怪 only when close,
## and cannot shoot or use skills. Each of these switches on as the game goes on.
const GRACE_SECONDS := 180.0    # until then: no day bonus, no ranged attacks, slower walking
const SKILLS_AT := 360.0        # villager skills switch on
const HIDDEN_FROM := 600.0      # hidden enemies can appear from here
const CHASE_START := 450.0      # villagers notice 小怪 only this close at first...
const CHASE_FULL_AT := 600.0    # ...growing until they chase from anywhere
const EARLY_SPEED := 0.75       # villager walking speed at the very start
const RAMP_SECONDS := 1200.0
const POP_TIME_END := 120       # how many the clock alone allows once the 20 minutes are up...
const POP_PER_STAGE := 22       # ...plus this many more for every evolution 小怪 has gone through
const POP_CAP := 360            # never more than this alive at once
const SPAWN_SLOW := 3.0         # seconds between respawns at the start...
const SPAWN_FAST := 0.3         # ...and at the end of the ramp
const SPAWN_MIN_DISTANCE := 800.0
const KILLS_PER_VILLAGE_LEVEL := 30  # village level 1 to 5 sets the form new villagers are born in
const VILLAGE_TIERS := ["Novice", "Trained", "Veteran", "Elite", "Master"]
const HIDDEN_SPAWN_CHANCE := 0.6     # at each dawn and dusk

## Day and night. Days make villagers stronger; nights make 小怪 stronger.
const DAY_SECONDS := 60.0
const NIGHT_SECONDS := 60.0
const START_CLOCK := 15.0         # the game starts in the morning
const NIGHT_TINT := Color(0.32, 0.38, 0.62)
const DAY_ENEMY_POWER := 1.5      # villager damage x1.5 (and speed +25%) by day
const NIGHT_PLAYER_POWER := 1.5   # bite damage x1.5 (and speed +20%) by night

## Building: towers and bone walls go wherever you point, within reach of 小怪. They can never
## close off every way in.
const START_BONES := 30
const BUILD_REACH := 260.0
const WALL_COST := 5

const PlayerScript := preload("res://player.gd")
const VillagerScript := preload("res://villager.gd")
const TowerScript := preload("res://tower.gd")
const WallScript := preload("res://wall.gd")
const GhostScript := preload("res://ghost.gd")
const LinesData := preload("res://lines.gd")
const SkillsData := preload("res://skills.gd")
const Sfx := preload("res://sfx.gd")
const MusicScript := preload("res://music.gd")

var trees := {}  # Vector2i -> true
var mud := {}    # Vector2i -> true
var built := {}  # Vector2i -> tower or wall standing there
var open_tiles: Array[Vector2i] = []  # grass reachable from the start
var ref_tiles: Array[Vector2i] = []   # far-away tiles that must always reach 小怪
var astar := AStarGrid2D.new()
var bones := START_BONES
var build_item := "wall"  # "wall" or "tower": press 1 or 2 (or B) to switch
var hotbar: Array[Label] = []
var music: Node
var credit: Label
var kills := 0
var village_level := 1
var elapsed := 0.0
var announced := {}
var clock := START_CLOCK
var last_phase := 0
var tint: CanvasModulate
var spawn_cd := SPAWN_SLOW
var rng := RandomNumberGenerator.new()
var player
var cam: Camera2D
var ghost: Node2D
var ghost_tile := Vector2i(-1, -1)
var ghost_error := ""
var ghost_dirty := true
var hud: Label
var banner: Label
var evo_banner: Label
var notice: Label
var evo_timer := 0.0
var notice_timer := 0.0
var game_over := false
var menu_layer: CanvasLayer
var menu_root: Control
var menu_open := false
var menu_queue: Array = []
var menu_kind := ""  # what the open menu is: "line", "skill" or "special"
var pause_on_menu := true  # the game stops while a level-up menu is open (tests turn this off)


func _ready() -> void:
	rng.randomize()
	_setup_input()
	_generate()
	for t in trees:
		_add_tree_body(Vector2(t.x + 0.5, t.y + 0.5) * TILE)
	_spawn_player(_tile_center(START_TILE))
	last_phase = int(clock / DAY_SECONDS)
	tint = CanvasModulate.new()
	add_child(tint)
	ghost = GhostScript.new()
	ghost.z_index = 5
	add_child(ghost)
	_build_hud()
	music = MusicScript.new()
	add_child(music)
	_update_music()
	_update_daynight()
	_update_hud()


# --- music ---

## Music follows how far 小怪 has evolved; nights have their own calmer track, and the
## final forms get the final boss theme.
func wanted_track() -> String:
	var s: int = player.stage
	if s >= 9:
		return "final"
	if is_night():
		return "night"
	if s >= 6:
		return "battle3"
	if s >= 3:
		return "battle2"
	return "battle1"


func _update_music() -> void:
	music.play_track(wanted_track())
	var text: String = music.credit_text()
	credit.text = "♪ " + text if text != "" else ""


# --- time ---

## 0.0 at midnight, 1.0 at noon. Crosses 0.5 at dawn (clock 0) and dusk.
func daylight() -> float:
	var cycle := DAY_SECONDS + NIGHT_SECONDS
	return 0.5 + 0.5 * cos(TAU * (fposmod(clock, cycle) - DAY_SECONDS * 0.5) / cycle)


func is_night() -> bool:
	return fposmod(clock, DAY_SECONDS + NIGHT_SECONDS) >= DAY_SECONDS


func enemy_power() -> float:
	if elapsed < GRACE_SECONDS:
		return 1.0
	return 1.0 if is_night() else DAY_ENEMY_POWER


func ranged_unlocked() -> bool:
	return elapsed >= GRACE_SECONDS


func skills_unlocked() -> bool:
	return elapsed >= SKILLS_AT


## How far villagers can notice 小怪. Small at first, then the whole map.
func chase_radius() -> float:
	if elapsed >= CHASE_FULL_AT:
		return INF
	return lerpf(CHASE_START, 4000.0, elapsed / CHASE_FULL_AT)


func enemy_speed_mult() -> float:
	return lerpf(EARLY_SPEED, 1.0, clampf(elapsed / GRACE_SECONDS, 0.0, 1.0))


func player_power() -> float:
	return NIGHT_PLAYER_POWER if is_night() else 1.0


func _update_daynight() -> void:
	tint.color = NIGHT_TINT.lerp(Color.WHITE, smoothstep(0.1, 0.9, daylight()))


# --- map ---

func _tile_center(t: Vector2i) -> Vector2:
	return (Vector2(t) + Vector2(0.5, 0.5)) * TILE


func tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(maxi(int(pos.x / TILE), 0), maxi(int(pos.y / TILE), 0))


func _generate() -> void:
	var gen := RandomNumberGenerator.new()
	gen.seed = SEED

	# Solid ring of trees around the map.
	for x in COLS:
		trees[Vector2i(x, 0)] = true
		trees[Vector2i(x, ROWS - 1)] = true
	for y in ROWS:
		trees[Vector2i(0, y)] = true
		trees[Vector2i(COLS - 1, y)] = true

	# Small, loose tree clumps.
	for i in TREE_CLUSTERS:
		var c := Vector2i(gen.randi_range(2, COLS - 3), gen.randi_range(2, ROWS - 3))
		var r := gen.randi_range(1, 2)
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + 1 and gen.randf() < 0.6:
					trees[c + Vector2i(dx, dy)] = true

	# Mud patches.
	for i in MUD_PATCHES:
		var c := Vector2i(gen.randi_range(4, COLS - 5), gen.randi_range(4, ROWS - 5))
		var rx := gen.randi_range(2, 5)
		var ry := gen.randi_range(2, 3)
		for dx in range(-rx, rx + 1):
			for dy in range(-ry, ry + 1):
				if float(dx * dx) / (rx * rx) + float(dy * dy) / (ry * ry) <= 1.0:
					mud[c + Vector2i(dx, dy)] = true

	# A clear meadow around the start: the base to defend.
	for dx in range(-13, 14):
		for dy in range(-13, 14):
			var t := START_TILE + Vector2i(dx, dy)
			if t.x > 0 and t.y > 0 and t.x < COLS - 1 and t.y < ROWS - 1:
				trees.erase(t)
				mud.erase(t)

	_find_open_tiles()
	_build_nav()

	# Starting villagers: spread out, reachable, never near the start.
	var placed: Array[Vector2i] = []
	var tries := 0
	while placed.size() < VILLAGER_COUNT and tries < 8000:
		tries += 1
		var t: Vector2i = open_tiles[gen.randi_range(0, open_tiles.size() - 1)]
		if mud.has(t) or Vector2(t - START_TILE).length() < 14.0:
			continue
		var clear := true
		for o in placed:
			if Vector2(t - o).length() < 4.0:
				clear = false
				break
		if clear:
			placed.append(t)
	placed.sort_custom(func(a, b): return Vector2(a - START_TILE).length() > Vector2(b - START_TILE).length())
	for i in placed.size():
		_spawn_villager(_tile_center(placed[i]), ELITE_STAGE if i < ELITE_COUNT else 0, gen.randi_range(0, VillagerScript.LINES.size() - 1))


## Every grass tile 小怪 can walk to from the start. Villagers only spawn on these.
func _find_open_tiles() -> void:
	var seen := {START_TILE: true}
	var queue: Array[Vector2i] = [START_TILE]
	var i := 0
	while i < queue.size():
		var t: Vector2i = queue[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if n.x < 1 or n.y < 1 or n.x > COLS - 2 or n.y > ROWS - 2:
				continue
			if trees.has(n) or seen.has(n):
				continue
			seen[n] = true
			queue.append(n)
	open_tiles = queue


## The walking grid villagers use to go around trees, towers and walls.
func _build_nav() -> void:
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE, TILE) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for t in trees:
		astar.set_point_solid(t, true)
	# Far-off tiles that must always keep a route to 小怪: the farthest corner, the middle
	# of the map and the top-right.
	var far_tile := START_TILE
	var mid_tile := START_TILE
	var corner_tile := START_TILE
	var far_best := -1.0
	var mid_best := INF
	var corner_best := INF
	for t in open_tiles:
		var d_far := Vector2(t - START_TILE).length()
		if d_far > far_best:
			far_best = d_far
			far_tile = t
		var d_mid := Vector2(t - Vector2i(COLS / 2, ROWS / 2)).length()
		if d_mid < mid_best:
			mid_best = d_mid
			mid_tile = t
		var d_corner := Vector2(t - Vector2i(COLS - 5, 5)).length()
		if d_corner < corner_best:
			corner_best = d_corner
			corner_tile = t
	ref_tiles = [far_tile, mid_tile, corner_tile]


func is_solid_at(pos: Vector2) -> bool:
	var t := tile_of(pos)
	return trees.has(t) or built.has(t)


## True if a villager-sized body can walk the straight line from a to b.
## Far lines are not checked: nobody needs to steer around anything from that distance.
func has_clear_line(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	if d > 900.0:
		return false
	var steps := int(d / 14.0)
	var dir := (b - a) / maxf(d, 1.0)
	var side := dir.orthogonal() * 9.0
	for i in range(1, steps):
		var p := a + dir * 14.0 * i
		if is_solid_at(p) or is_solid_at(p + side) or is_solid_at(p - side):
			return false
	return true


func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ta := tile_of(a)
	var tb := tile_of(b)
	ta = Vector2i(clampi(ta.x, 0, COLS - 1), clampi(ta.y, 0, ROWS - 1))
	tb = Vector2i(clampi(tb.x, 0, COLS - 1), clampi(tb.y, 0, ROWS - 1))
	if astar.is_point_solid(ta) or astar.is_point_solid(tb):
		return PackedVector2Array()
	return astar.get_point_path(ta, tb)


func speed_mult_at(pos: Vector2) -> float:
	return MUD_SLOW if mud.has(tile_of(pos)) else 1.0


## Put a tree on a tile (used by the tests to build obstacles).
func block_tile(t: Vector2i) -> void:
	trees[t] = true
	astar.set_point_solid(t, true)
	_add_tree_body(_tile_center(t))
	queue_redraw()


# --- building ---

## Every far tile still reaches both the start and 小怪's tile.
func routes_open() -> bool:
	var targets: Array[Vector2i] = [START_TILE, tile_of(player.global_position)]
	for r in ref_tiles:
		if astar.is_point_solid(r):
			continue
		for t in targets:
			if astar.is_point_solid(t):
				continue
			if astar.get_id_path(r, t).is_empty():
				return false
	return true


func build_cost(kind: String, tile: Vector2i) -> int:
	var base: int = WALL_COST
	if kind != "wall":
		base = TowerScript.COSTS[0]
		var existing = built.get(tile)
		if existing != null and is_instance_valid(existing) and existing.has_method("upgrade"):
			base = TowerScript.COSTS[mini(existing.level, TowerScript.MAX_LEVEL - 1)]
	if player != null and player.specials.has("bonehoard"):
		return maxi(1, roundi(base * 0.7))  # Bone Hoard: 30% cheaper
	return base


## "" if kind (tower or wall) can go on this tile, otherwise the reason it can't.
func build_error(tile: Vector2i, kind: String) -> String:
	if player == null:
		return "No player"
	if tile.x < 1 or tile.y < 1 or tile.x > COLS - 2 or tile.y > ROWS - 2:
		return "Out of bounds"
	var center := _tile_center(tile)
	if center.distance_to(player.global_position) > BUILD_REACH:
		return "Too far from you"
	var existing = built.get(tile)
	if existing != null and is_instance_valid(existing):
		if kind == "tower" and existing.has_method("upgrade"):
			if existing.level >= TowerScript.MAX_LEVEL:
				return "Tower is at max level"
			return "" if bones >= build_cost(kind, tile) else "Need %d bones" % build_cost(kind, tile)
		return "Occupied"
	if trees.has(tile):
		return "A tree is there"
	if center.distance_to(player.global_position) < 26.0:
		return "Too close to you"
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(center) < 22.0:
			return "A villager is in the way"
	if bones < build_cost(kind, tile):
		return "Need %d bones" % build_cost(kind, tile)
	astar.set_point_solid(tile, true)
	var open := routes_open()
	astar.set_point_solid(tile, false)
	if not open:
		return "Would block every way in"
	return ""


## Build or upgrade on a tile. Returns true if something was built.
func place_at(tile: Vector2i, kind: String) -> bool:
	if build_error(tile, kind) != "":
		return false
	var existing = built.get(tile)
	var cost := build_cost(kind, tile)
	bones -= cost
	ghost_dirty = true
	Sfx.play(get_tree(), "build")
	if existing != null and is_instance_valid(existing):
		existing.upgrade()
		existing.invested += cost
		return true
	var s = TowerScript.new() if kind == "tower" else WallScript.new()
	s.invested = cost
	s.tile = tile
	s.position = _tile_center(tile)
	s.destroyed.connect(_on_structure_destroyed)
	add_child(s)
	built[tile] = s
	astar.set_point_solid(tile, true)
	return true


func _on_structure_destroyed(tile: Vector2i) -> void:
	built.erase(tile)
	astar.set_point_solid(tile, false)
	ghost_dirty = true


## E: build the selected item under the mouse (or upgrade the tower there).
func try_build() -> bool:
	var ok := place_at(tile_of(get_global_mouse_position()), build_item)
	if not ok:
		Sfx.play(get_tree(), "deny")
	return ok


## What removing the structure on this tile would give back (half of what was spent), or -1.
func refund_at(tile: Vector2i) -> int:
	var s = built.get(tile)
	if s == null or not is_instance_valid(s):
		return -1
	return int(s.invested / 2)


## X: take down the tower or wall on a tile (within reach) and get half the bones back.
## This also frees the tile for walking and pathing, so nothing can trap 小怪.
func demolish_at(tile: Vector2i) -> bool:
	var s = built.get(tile)
	if s == null or not is_instance_valid(s):
		return false
	if _tile_center(tile).distance_to(player.global_position) > BUILD_REACH:
		return false
	bones += int(s.invested / 2)
	built.erase(tile)
	astar.set_point_solid(tile, false)
	s.queue_free()
	ghost_dirty = true
	Sfx.play(get_tree(), "demolish")
	return true


func try_demolish() -> bool:
	return demolish_at(tile_of(get_global_mouse_position()))


# --- setup ---

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("dodge", [KEY_SPACE])
	_add_action("build", [KEY_E])
	_add_action("build_next", [KEY_B])
	_add_action("pick_tower", [KEY_1])
	_add_action("pick_wall", [KEY_2])
	_add_action("demolish", [KEY_X])
	_add_action("lunge", [])
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("lunge", right)
	_add_action("restart", [KEY_R])
	_add_action("move_mouse", [])
	var hold := InputEventMouseButton.new()
	hold.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("move_mouse", hold)


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _add_tree_body(p: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = p
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE - 4, TILE - 4)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


## stage 0 to 4 is the form within the line; line -1 picks one of the 10 lines at random;
## secret 0 to 2 spawns a hidden form (Parasite Hero, Dark Hero, GOD).
func _spawn_villager(p: Vector2, stage: int, line: int = -1, secret: int = -1):
	var v = VillagerScript.new()
	v.stage = stage
	v.secret = secret
	v.line = line if line >= 0 else rng.randi_range(0, VillagerScript.LINES.size() - 1)
	v.position = p
	v.defeated.connect(_on_villager_defeated)
	add_child(v)
	return v


func _spawn_player(p: Vector2) -> void:
	player = PlayerScript.new()
	player.position = p
	add_child(player)
	player.hp_changed.connect(_on_hp_changed)
	player.died.connect(_on_player_died)
	player.evolved.connect(_on_evolved)
	player.leveled.connect(_on_leveled)
	player.line_needed.connect(_on_line_needed)

	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = COLS * TILE
	cam.limit_bottom = ROWS * TILE
	cam.position_smoothing_enabled = true
	player.add_child(cam)


# --- HUD ---

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	layer.add_child(hud)

	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 36)
	banner.visible = false
	layer.add_child(banner)

	evo_banner = _top_label(layer, 170, 40, Color("ffd84a"))
	notice = _top_label(layer, 250, 26, Color("ff7a7a"))

	# the build bar along the bottom: pick what to build, or remove
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -56
	bar.offset_bottom = -12
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.add_theme_constant_override("separation", 36)
	layer.add_child(bar)
	for i in 3:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		bar.add_child(l)
		hotbar.append(l)

	# music credit, bottom right (the final track is CC-BY and needs it)
	credit = Label.new()
	credit.anchor_left = 1.0
	credit.anchor_right = 1.0
	credit.anchor_top = 1.0
	credit.anchor_bottom = 1.0
	credit.offset_left = -520
	credit.offset_right = -14
	credit.offset_top = -34
	credit.offset_bottom = -8
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.add_theme_font_size_override("font_size", 14)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	credit.add_theme_color_override("font_outline_color", Color.BLACK)
	credit.add_theme_constant_override("outline_size", 5)
	layer.add_child(credit)

	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)


func _top_label(layer: CanvasLayer, top: float, size: int, color: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.offset_top = top
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.visible = false
	layer.add_child(l)
	return l


## How many villagers may be alive. Time raises it slowly at first and fastest near 20 minutes,
## and every evolution 小怪 goes through adds a big batch more.
## The EXP curve is built so the final form (level 100) arrives around 16 minutes. A player who
## falls behind that pace earns up to 60% more EXP from villagers, so slow runs still finish.
const TARGET_FINAL_SECONDS := 960.0


func catchup() -> float:
	var expected := 100.0 * clampf(elapsed / TARGET_FINAL_SECONDS, 0.0, 1.0)
	return clampf(1.0 + (expected - player.level) / 40.0, 1.0, 1.6)


func target_population() -> int:
	var f := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	var by_time := VILLAGER_COUNT + roundi((POP_TIME_END - VILLAGER_COUNT) * f * f)
	return mini(POP_CAP, by_time + player.stage * POP_PER_STAGE)


func spawn_interval() -> float:
	var f := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	return lerpf(SPAWN_SLOW, SPAWN_FAST, f * f) / (1.0 + 0.1 * player.stage)


func _update_hud() -> void:
	var s: Dictionary = player.stages[player.stage]
	var xp_text := "MAX"
	if player.level < player.MAX_LEVEL:
		xp_text = "%d/%d" % [player.xp, player.xp_for_level(player.level + 1)]
	var form_text := "first evolution at Lv %d: pick a line" % player.EVOLVE_EVERY
	if player.line >= 0:
		var tier := 1 if player.stage <= 2 else (2 if player.stage <= 5 else (3 if player.stage <= 8 else 4))
		form_text = "%s, form %d/10, tier %d" % [player.LinesData.LINES[player.line]["family"], maxi(player.stage, 0), tier]
		if player.stage < player.LAST_STAGE:
			form_text += ", next form at Lv %d" % ((player.stage + 1) * player.EVOLVE_EVERY)
	var cycle := DAY_SECONDS + NIGHT_SECONDS
	var phase := fposmod(clock, cycle)
	var time_text := "DAY %d, %ds left: villagers stronger" % [int(clock / cycle) + 1, ceili(DAY_SECONDS - phase)]
	if is_night():
		time_text = "NIGHT %d, %ds left: you are stronger" % [int(clock / cycle) + 1, ceili(cycle - phase)]
	var sprint := "Sprint %.1fs" % player.sprint_energy
	if player.sprint_cd > 0.0:
		sprint = "Sprint recharging %ds" % ceili(player.sprint_cd)
	var roll := "Roll ready" if player.roll_cd == 0.0 else "Roll %.1fs" % player.roll_cd
	var lunge := "Lunge ready" if player.lunge_cd == 0.0 else "Lunge %.1fs" % player.lunge_cd
	var alive := get_tree().get_nodes_in_group("enemies").size()
	var skill_bits: Array[String] = []
	for id in player.skills:
		var info: Dictionary = SkillsData.SKILLS[id]
		if info.get("auto", false):
			var cd: float = player.skill_cd.get(id, 0.0)
			skill_bits.append("%s r%d %s" % [info["name"], player.skills[id], "ready" if cd <= 0.0 else "%.1fs" % cd])
		else:
			skill_bits.append("%s r%d" % [info["name"], player.skills[id]])
	var skill_text := "Skills: " + (", ".join(skill_bits) if not skill_bits.is_empty() else "none yet (one every level)")
	if not player.specials.is_empty():
		var names: Array[String] = []
		for sid in player.specials:
			names.append(SkillsData.SPECIALS[sid]["name"])
		skill_text += "\nSpecials: " + ", ".join(names)
	if player.line >= 0:
		var trait_text: String = player.AbilitiesData.FAMILY_TRAITS[player.family()]
		var ab: Dictionary = player.ability()
		skill_text += "\nFamily trait: %s" % trait_text
		if not ab.is_empty():
			skill_text += "    Ability: %s (rank %d)" % [ab["name"], ab["rank"]]
		elif player.AbilitiesData.ABILITIES.has(player.line):
			skill_text += "    Ability: unlocks at form 3"
	hud.text = "%s  Lv %d/%d  EXP %s  (%s)  HP %d/%d    %s\nBones %d    Kills %d    Villagers %d/%d    Village Lv %d/5 (%s)\n%s    %s    %s\n%s\n%s\nLeft-click walk (hold to follow)  |  Shift sprint  |  Space roll  |  Right-click lunge  |  1 / 2 pick item  |  E build  |  X remove  |  R restart" % [
		s["name"], player.level, player.MAX_LEVEL, xp_text, form_text, player.hp, player.max_hp, time_text,
		bones, kills, alive, target_population(), village_level, VILLAGE_TIERS[village_level - 1],
		sprint, roll, lunge, skill_text, _build_prompt()]


func _build_prompt() -> String:
	var tile := tile_of(get_global_mouse_position())
	var refund := refund_at(tile)
	if refund >= 0:
		var up := ""
		if build_item == "tower" and built[tile].has_method("upgrade"):
			up = "    E: upgrade (%s)" % (ghost_error if ghost_error != "" else "%d bones" % build_cost("tower", tile))
		return "X: remove it (+%d bones)%s" % [refund, up]
	var item := "TOWER (%d bones)" % TowerScript.COSTS[0] if build_item == "tower" else "BONE WALL (%d bones)" % WALL_COST
	var status := "E to build" if ghost_error == "" else ghost_error
	return "Building: %s    %s" % [item, status]


func _update_hotbar() -> void:
	var tower_cost := build_cost("tower", Vector2i(-1, -1))
	var wall_cost := build_cost("wall", Vector2i(-1, -1))
	var slots := [["[1] TOWER  %d" % tower_cost, "tower", tower_cost],
			["[2] BONE WALL  %d" % wall_cost, "wall", wall_cost]]
	for i in 2:
		var selected: bool = build_item == slots[i][1]
		hotbar[i].text = ("▶ " if selected else "   ") + slots[i][0]
		var c := Color("ffd84a") if selected else Color(1, 1, 1, 0.75)
		if bones < int(slots[i][2]):
			c = Color("ff7a7a") if selected else Color(1, 0.55, 0.55, 0.7)
		hotbar[i].add_theme_color_override("font_color", c)
	hotbar[2].text = "[X] REMOVE (half back)"
	hotbar[2].add_theme_color_override("font_color", Color(1, 1, 1, 0.75))


# --- level-ups, evolution lines and skills ---

## Every level gets the sound and the ring; a normal skill pick comes every 3rd level and a
## special skill pick every 12th (12, 24, 36 ... 96).
func _on_leveled(new_level: int) -> void:
	Sfx.play(get_tree(), "levelup")
	if new_level % player.SKILL_EVERY == 0:
		menu_queue.append({"type": "skill"})
	if new_level % player.SPECIAL_EVERY == 0:
		menu_queue.append({"type": "special"})
	_next_menu()


func _on_line_needed() -> void:
	menu_queue.push_front({"type": "line"})
	_next_menu()


func _next_menu() -> void:
	if menu_open or menu_queue.is_empty():
		return
	var item: Dictionary = menu_queue.pop_front()
	menu_kind = item["type"]
	if item["type"] == "line":
		var entries: Array[String] = []
		for i in LinesData.LINES.size():
			var soon := "" if LinesData.released(i) else "   (coming soon)"
			entries.append("%d. %s  [%s]%s" % [i + 1, LinesData.title(i), LinesData.LINES[i]["family"], soon])
		_open_menu("FIRST EVOLUTION: choose your evolution line", entries, func(i): if LinesData.released(i): pick_line(i), 2, 440)
	elif item["type"] == "special":
		var specials := SkillsData.roll_specials(player.specials, rng, 3)
		if specials.is_empty():
			_next_menu()
			return
		var special_entries: Array[String] = []
		for id in specials:
			var info: Dictionary = SkillsData.SPECIALS[id]
			special_entries.append("%d. %s\n    %s" % [special_entries.size() + 1, info["name"], info["desc"]])
		_open_menu("LEVEL %d: choose a SPECIAL skill" % player.level, special_entries, func(i): pick_special(specials[i]), 1, 620)
	else:
		var options := SkillsData.roll(player.skills, rng, 3)
		if options.is_empty():
			_next_menu()
			return
		var entries: Array[String] = []
		for id in options:
			var info: Dictionary = SkillsData.SKILLS[id]
			var r: int = player.rank(id)
			var key_text := "  [auto]" if info.get("auto", false) else ""
			entries.append("%d. %s   rank %d → %d%s\n    %s" % [entries.size() + 1, info["name"], r, r + 1, key_text, info["desc"]])
		_open_menu("LEVEL %d: choose a skill" % player.level, entries, func(i): pick_skill(options[i]), 1, 620)


func _open_menu(title: String, entries: Array[String], on_pick: Callable, columns: int, width: int) -> void:
	Sfx.play(get_tree(), "menu")
	menu_open = true
	get_tree().paused = pause_on_menu
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width * columns + 20, mini(560, 60 * ceili(entries.size() / float(columns)) + 20))
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	scroll.add_child(grid)
	for i in entries.size():
		var b := Button.new()
		b.text = entries[i]
		b.custom_minimum_size = Vector2(width, 44 if columns > 1 else 70)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): on_pick.call(i))
		if i < 9:
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_1 + i
			var sc := Shortcut.new()
			sc.events = [ev]
			b.shortcut = sc
		grid.add_child(b)
	menu_layer.add_child(menu_root)


func _close_menu() -> void:
	Sfx.play(get_tree(), "pick")
	if menu_root != null:
		menu_root.queue_free()
		menu_root = null
	menu_open = false
	get_tree().paused = false


## The first-evolution menu (or tests) picks a line.
func pick_line(i: int) -> void:
	_close_menu()
	player.choose_line(i)
	_next_menu()


## A level-up menu (or tests) picks a skill.
func pick_skill(id: String) -> void:
	_close_menu()
	player.learn(id)
	_next_menu()


## The special-skill menu (every 12th level, or tests) picks a special.
func pick_special(id: String) -> void:
	_close_menu()
	player.learn_special(id)
	_next_menu()


# --- events ---

func _on_hp_changed(_hp: int) -> void:
	_update_hud()


func _on_villager_defeated(xp: int, bones_gain: int, by_tower: bool) -> void:
	kills += 1
	Sfx.play(get_tree(), "coin", -6.0)
	village_level = mini(VILLAGE_TIERS.size(), 1 + int(kills / float(KILLS_PER_VILLAGE_LEVEL)))
	bones += roundi(bones_gain * (1.0 + 0.25 * player.rank("greed")) * (2.0 if player.specials.has("bonehoard") else 1.0))
	if player.family() == "Demon":
		bones += 1  # Demon trait: every kill drops an extra bone
	if not by_tower:
		player.add_xp(roundi(xp * catchup()))
		player.on_kill()


func _on_evolved(stage: int) -> void:
	var text := "EVOLVED!\n%s" % player.stages[stage]["name"]
	Sfx.play(get_tree(), "win" if stage == player.LAST_STAGE else "evolve")
	_update_music()
	if stage == player.LAST_STAGE:
		text = "STAGE 1 CLEAR!\n%s rises. Keep defending." % player.stages[stage]["name"]
		evo_timer = 6.0
	else:
		evo_timer = 3.0
	evo_banner.text = text
	evo_banner.visible = true
	var z: float = player.stages[stage]["zoom"]
	create_tween().tween_property(cam, "zoom", Vector2(z, z), 0.8)


func _on_player_died() -> void:
	game_over = true
	banner.text = "Defeated...\nPress R to try again"
	banner.visible = true


func _say(text: String) -> void:
	Sfx.play(get_tree(), "chime", -4.0)
	notice.text = text
	notice.visible = true
	notice_timer = 5.0


## The village grows slowly at first and fastest near the end of the ramp. Missing
## villagers respawn at the current village level.
func _update_spawner(delta: float) -> void:
	spawn_cd -= delta
	if spawn_cd > 0.0:
		return
	spawn_cd = spawn_interval()
	var deficit := target_population() - get_tree().get_nodes_in_group("enemies").size()
	if deficit <= 0:
		return
	for i in clampi(1 + int(deficit / 12.0), 1, 6):  # a big gap fills in faster
		spawn_far(village_level - 1)


## Spawn one villager somewhere reachable and far from 小怪. Returns it, or null.
func spawn_far(stage: int, secret: int = -1):
	for i in 30:
		var t: Vector2i = open_tiles[rng.randi_range(0, open_tiles.size() - 1)]
		var p := _tile_center(t)
		if p.distance_to(player.global_position) < SPAWN_MIN_DISTANCE:
			continue
		return _spawn_villager(p, stage, -1, secret)
	return null


## At every dawn and dusk there is a chance that a hidden enemy appears.
func _on_phase_change() -> void:
	if elapsed < HIDDEN_FROM or rng.randf() > HIDDEN_SPAWN_CHANCE:
		return
	var count := 1 + int(elapsed / 400.0)
	var secret := 0
	if elapsed > 900.0 and village_level >= 5 and rng.randf() < 0.15:
		secret = 2
	elif elapsed > 800.0 and rng.randf() < 0.4:
		secret = 1
	var spawned := 0
	for i in count:
		if spawn_far(VillagerScript.MAX_STAGE, secret) != null:
			spawned += 1
	if spawned > 0:
		_say("%s stirs in the dark..." % VillagerScript.HIDDEN[secret]["name"] if is_night() else "%s walks in the light..." % VillagerScript.HIDDEN[secret]["name"])


func _process(delta: float) -> void:
	if not game_over:
		elapsed += delta
		clock += delta
		_update_spawner(delta)
		for step in [[GRACE_SECONDS, "Villagers can shoot now, and daylight makes them stronger"],
				[SKILLS_AT, "Villagers have learned their skills"],
				[HIDDEN_FROM, "Hidden enemies may appear at dawn and dusk"]]:
			if elapsed >= step[0] and not announced.has(step[0]):
				announced[step[0]] = true
				_say(step[1])
		var phase := int(clock / DAY_SECONDS)
		if phase != last_phase:
			last_phase = phase
			Sfx.play(get_tree(), "chime", -8.0)
			_update_music()
			_on_phase_change()
	_update_daynight()
	_update_ghost(delta)
	_update_hotbar()
	_update_hud()
	if evo_timer > 0.0:
		evo_timer -= delta
		if evo_timer <= 0.0:
			evo_banner.visible = false
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			notice.visible = false
	if not game_over and not menu_open:
		if Input.is_action_just_pressed("build_next"):
			build_item = "wall" if build_item == "tower" else "tower"
			ghost_dirty = true
		if Input.is_action_just_pressed("pick_tower"):
			build_item = "tower"
			ghost_dirty = true
		if Input.is_action_just_pressed("pick_wall"):
			build_item = "wall"
			ghost_dirty = true
		if Input.is_action_just_pressed("build"):
			try_build()
		if Input.is_action_just_pressed("demolish"):
			try_demolish()
	if Input.is_action_just_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()


func _update_ghost(_delta: float) -> void:
	var tile := tile_of(get_global_mouse_position())
	if tile != ghost_tile or ghost_dirty:
		ghost_tile = tile
		ghost_dirty = false
		ghost_error = build_error(tile, build_item)
		ghost.position = _tile_center(tile)
		ghost.valid = ghost_error == ""
		ghost.reach = TowerScript.REACH[0] if build_item == "tower" else 0.0
		ghost.queue_redraw()
	ghost.visible = not game_over and not menu_open


func _draw() -> void:
	draw_rect(Rect2(0, 0, COLS * TILE, ROWS * TILE), Color("5b8a3c"))
	for y in ROWS:
		for x in COLS:
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color(1, 1, 1, 0.04))

	for m in mud:
		var r := Rect2(m.x * TILE, m.y * TILE, TILE, TILE)
		draw_rect(r, Color("6b4f2f"))
		draw_circle(r.position + Vector2(9, 11), 4.0, Color("55401f"))
		draw_circle(r.position + Vector2(22, 20), 5.0, Color("7d5e38"))

	for t in trees:
		var c := Vector2(t.x + 0.5, t.y + 0.5) * TILE
		draw_circle(c + Vector2(0, 8), 13.0, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(c.x - 3, c.y, 6, 12), Color("5a3b22"))
		draw_circle(c + Vector2(0, -4), 14.0, Color("2f6b2f"))
		draw_circle(c + Vector2(-4, -8), 6.0, Color("3f8a3f"))

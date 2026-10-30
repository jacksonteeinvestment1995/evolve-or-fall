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
const PATH_FAST := 1.15          # stone paths: a bit quicker to walk
const WATER_SLOW := 0.65         # wading is slow...
const DROWN_SECONDS := 10.0      # ...and anything that stays in water this long drowns
const START_TILE := Vector2i(4, 4)

## The village grows slowly at first and fastest near the end of RAMP_SECONDS (20 min).
const VILLAGER_COUNT := 30      # villagers on the map at the start (a gentle start)
const ELITE_COUNT := 0          # this many of the farthest start at ELITE_STAGE (the 3rd form)
const ELITE_STAGE := 2

## A gentle start: for the first minutes villagers are slower, notice 小怪 only when close,
## and cannot shoot or use skills. Each of these switches on as the game goes on.
const GRACE_SECONDS := 180.0    # until then: no day bonus, no ranged attacks, slower walking
const SKILL_ICONS := {"hide": "tough_hide", "fangs": "sharp_fangs", "paws": "swift_paws", "jaws": "quick_jaws", "drain": "soul_drain", "greed": "bone_collector", "nova": "bone_nova", "bolt": "spirit_bolt", "step": "shadow_step", "frost_shards": "frost_shards", "meteor_call": "meteor_call", "chain_zap": "chain_zap", "thorn_ring": "thorn_ring", "spirit_lance": "spirit_lance"}
const SKILLS_AT := 360.0        # villager skills switch on
const HIDDEN_FROM := 600.0      # hidden enemies can appear from here (10 minutes in)...
const GUARD_RELEASE := 1200.0    # ...and they wait in the big castle until 20 minutes, then go hunting
const CHASE_START := 450.0      # villagers notice 小怪 only this close at first...
const CHASE_FULL_AT := 300.0    # ...growing until, after five minutes, they find 小怪 from anywhere (they now really arrive, so the swarm builds slowly)
const EARLY_SPEED := 0.75       # villager walking speed at the very start
const RAMP_SECONDS := 1200.0
const POP_TIME_END := 120       # how many the clock alone allows once the 20 minutes are up...
const POP_PER_STAGE := 22       # ...plus this many more for every evolution 小怪 has gone through
const POP_CAP := 200            # never more than this alive at once (a crowd this big already slows a phone)
const SPAWN_SLOW := 3.0         # seconds between respawns at the start...
const SPAWN_FAST := 0.3         # ...and at the end of the ramp
const SPAWN_MIN_DISTANCE := 800.0
const KILLS_PER_VILLAGE_LEVEL := 30  # village level 1 to 5 sets the form new villagers are born in
const VILLAGE_TIERS := ["Novice", "Trained", "Veteran", "Elite", "Master"]
const HIDDEN_SPAWN_CHANCE := 0.6     # at each dawn and dusk
const GOD_AT := 900.0               # GOD, the last boss, descends at 15 minutes
const RIVAL_AT := 3.0               # the rival hero (the enemy's own main character) is there from the very start: 3 seconds in
const RIVAL_START_MIN := 3000.0    # the rival starts this far from 小怪 (about a minute's walk), so he has time to grow first
const RIVAL_START_MAX := 4600.0
const RIVAL_ABSORB := 0.4           # the rival absorbs this share of the EXP of everything 小怪 defeats
const RIVAL_RESPAWN := 30.0         # ...and returns this many seconds after 小怪 defeats it
const DUEL_AT := 1200.0             # at 20 minutes it is the final duel: no more respawns
const RIVAL_SKILL_POOL := ["pierce", "volley", "smite", "fireball", "bomb", "slam", "nova", "charge", "blink", "shield", "rage", "heal", "axe", "slow", "frost_shards", "thorn_ring", "spirit_lance", "meteor_call", "chain_zap"]
const RIVAL_ATTACK_SKILLS := ["frost_shards", "thorn_ring", "spirit_lance", "meteor_call", "chain_zap", "fireball", "volley", "pierce", "slam", "nova"]

## Day and night. Days make villagers stronger; nights make 小怪 stronger.
const DAY_SECONDS := 60.0
const NIGHT_SECONDS := 60.0
const START_CLOCK := 15.0         # the game starts in the morning
const NIGHT_TINT := Color(0.40, 0.47, 0.76)  # the reference night grade (124, 140, 206)
const DAY_TINT := Color(1.0, 0.94, 0.84)    # the reference day grade (255, 240, 214)
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
const PerksData := preload("res://perks.gd")
const ExpStone := preload("res://exp_stone.gd")
const Biomes := preload("res://biomes.gd")
const PoiScript := preload("res://poi.gd")
const TreasureScript := preload("res://treasure.gd")
const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")
const MusicScript := preload("res://music.gd")

var trees := {}  # Vector2i -> true
var mud := {}    # Vector2i -> true
var built := {}  # Vector2i -> tower or wall standing there
var open_tiles: Array[Vector2i] = []  # grass reachable from the start
var open_lookup := {}                 # the same tiles as a lookup table
var ref_tiles: Array[Vector2i] = []   # far-away tiles that must always reach 小怪
var astar := AStarGrid2D.new()
var bones := START_BONES
var build_item := "wall"  # "wall" or "tower": press 1 or 2 (or B) to switch
var hotbar: Array = []   # the two build buttons, then the remove label
var music: Node
var credit: Label
var kills := 0
var village_level := 1
var elapsed := 0.0
var announced := {}
var clock := START_CLOCK
var last_phase := 0
var tint: CanvasModulate
var glow_light: PointLight2D
var hd2d_mat: ShaderMaterial
var eclipse_left := 0.0         # seconds of artificial night left (eclipse, blood moon)
var eclipse_t := 0.0            # 0 day .. 1 full artificial night, eased
var blood_moon := false
var events: Node               # random events (events.gd)
var remove_armed := false        # the remove button is on: the next click on a building takes it back
var map_seed := SEED             # random at every launch (the tests keep the fixed SEED)
var buildings := {}            # Vector2i -> "wall", "tower", "keep", "house" or "well": solid town tiles
var floors := {}               # Vector2i -> true: castle courtyards and gate aprons
var bridges := {}              # Vector2i -> true: wooden bridges over a castle moat
var dirt := {}                 # Vector2i -> true: village dirt paths and plazas (a little faster to walk)
var decor := {}                # Vector2i -> sprite name: town props that stand on one tile
var layout := {}               # the towns (see towns.gd)
var _town_tiles: Array[Vector2i] = []
var town_population := 0       # villagers living in the towns at the start (they count toward the target)
var punch_amp := 0.0            # a short zoom-in pulse on heavy blows
var shake_amp := 0.0           # camera shake in pixels, decays by itself
var calm_time := 0.0           # seconds with no villager nearby (for the quiet music)
var _music_tick := 0.0
var treasure_spots: Array = []   # chests made during generation, added to the scene in _ready
var minimap: Control
var skillbar: Control
var motes: CPUParticles2D
var bokeh: CPUParticles2D
var radial_tex: GradientTexture2D
var shadow_tex: GradientTexture2D
var water := {}   # Vector2i -> true: pond tiles (also solid, like trees)
var paths := {}   # Vector2i -> true: stone path tiles (walkable, a little faster)
var props := {}   # Vector2i -> prop sprite name: scenery with no collision
var spawn_cd := SPAWN_SLOW
var rng := RandomNumberGenerator.new()
var player
var cam: Camera2D
var ghost: Node2D
var ghost_tile := Vector2i(-1, -1)
var ghost_error := ""
var ghost_dirty := true
var hud: Control
var playables: Node
var god_spawned := false
var biome := {}               # tile -> biome id (snow, desert, swamp, graveyard, autumn); the meadow is absent
var rival_home := Vector2.INF  # where the rival's lair is; it returns there after every fall
var ambient: Node2D
var _chaser_t := 0.0
var start_pit: Node2D
## The rival's state outlives its body: it keeps its line, EXP, level and skills across respawns.
var rival := {"line": -1, "xp": 0, "level": 1, "skills": [], "node": null, "respawn": -1.0, "falls": 0, "duel": false, "skip_xp": false}
var perk_every := PerksData.PERK_EVERY   ## a perk card pick every this many levels (the tests turn it off)
var touch_mode := false   ## the on-screen controls are showing: walk with the stick, build in front of 小怪
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
const MenuCards := preload("res://menu_cards.gd")
## On a touchscreen one layout pixel comes out about this many CSS pixels, so text and buttons are big enough to read
## and tap on a phone (the plain 720-wide layout gave about 0.54).
const UI_CSS_PER_UNIT := 0.86
const TOUCH_HUD_SCALE := 1.1
var view_zoom := 1.0        ## extra camera zoom that keeps the world the same size on screen when the phone layout grows
var ui_portrait := false
var touch_ui: Control      ## the on-screen joystick and buttons (touch_controls.gd)
var hotbar_bar: HBoxContainer
var hud_layer: CanvasLayer   ## the HUD's layer, hidden while a level-up menu is up
var perf_notice: Control     ## the "turn on graphics acceleration" notice (perf_notice.gd), web only
var start_gate: Control      ## the "TAP TO START" panel (start_gate.gd) while it is up
var _away := false           ## the page lost focus mid-run on a phone: ask for a tap (and so the sound) when it is back
var hotbar_parts: Array = []  ## per build button: the phone look's pieces (name, cost) and the desktop icon and key badge


func _ready() -> void:
	Engine.time_scale = 1.0  # a perfect-dodge slow-mo must never carry over into a restart
	if OS.has_feature("web") or DisplayServer.is_touchscreen_available():
		Engine.physics_ticks_per_second = 30  # half the physics work; interpolation keeps the motion smooth
	rng.randomize()
	if not Engine.has_meta("deterministic_map"):
		map_seed = randi()
	_setup_input()
	_generate()
	for t in trees:
		_add_tree_body(Vector2(t.x + 0.5, t.y + 0.5) * TILE)
	for chest in treasure_spots:
		add_child(chest)
	_spawn_player(_tile_center(START_TILE))
	# the start spot: a patch of living flesh with a small blood pit, and 小怪 begins on top of its mouth
	start_pit = preload("res://start_pit.gd").new()
	start_pit.position = _tile_center(START_TILE)  # 小怪 stands right on top of the maw
	add_child(start_pit)
	move_child(start_pit, 0)
	last_phase = int(clock / DAY_SECONDS)
	tint = CanvasModulate.new()
	add_child(tint)
	ghost = GhostScript.new()
	ghost.z_index = 5
	add_child(ghost)
	_build_hd2d()
	_build_hud()
	events = preload("res://events.gd").new()
	events.main = self
	add_child(events)
	music = MusicScript.new()
	add_child(music)
	_update_music()
	_update_daynight()
	_update_hud()
	get_window().size_changed.connect(_fit_screen)
	_fit_screen()
	var touch := CanvasLayer.new()
	touch.layer = 3
	add_child(touch)
	touch_ui = preload("res://touch_controls.gd").new()
	touch.add_child(touch_ui)
	if needs_start_gate():
		open_start_gate("TAP TO START")
	var notice_layer := CanvasLayer.new()
	notice_layer.layer = 11
	add_child(notice_layer)
	perf_notice = preload("res://perf_notice.gd").new()
	notice_layer.add_child(perf_notice)
	# YouTube Playables: the first frame is up, then the game is ready to play
	playables = preload("res://playables.gd").new()
	add_child(playables)
	playables.first_frame_ready()
	await get_tree().process_frame
	playables.game_ready()


## Phones held upright get a tall layout (720 wide) and everything else a wide one (1280 wide). On a touchscreen the
## layout is sized from the screen's CSS pixels instead, so a phone shows the HUD, buttons and menus about 1.6x bigger;
## the camera zooms out by the same amount, so the world keeps its size on screen.
func _fit_screen() -> void:
	var win := get_window()
	var ws := Vector2(win.size)
	var portrait := ws.y > ws.x
	ui_portrait = portrait
	var base := Vector2(720, 1280) if portrait else Vector2(1280, 720)
	var fit := base
	if touch_mode and ws.x > 0.0 and ws.y > 0.0:
		var css_short := minf(ws.x, ws.y) / maxf(DisplayServer.screen_get_scale(), 1.0)
		var short_side := clampf(roundf(css_short / UI_CSS_PER_UNIT), 400.0, 720.0)
		var long_side := roundf(short_side * 16.0 / 9.0)
		fit = Vector2(short_side, long_side) if portrait else Vector2(long_side, short_side)
	win.content_scale_size = Vector2i(fit)
	view_zoom = 1.0
	if fit != base:
		view_zoom = minf(ws.x / base.x, ws.y / base.y) / minf(ws.x / fit.x, ws.y / fit.y)
	_layout_ui()


## Places the HUD pieces: the desktop layout as it always was, or the phone one (the minimap compact in the top right
## corner, labelled build buttons, on an upright screen a stacked HUD with the skill icons under it). On a phone the
## pieces are sized from the screen so none of them overlaps another or the touch buttons.
func _layout_ui() -> void:
	if hud == null:
		return
	var portrait := ui_portrait
	var t := touch_mode
	var vs := get_viewport().get_visible_rect().size
	hud.set_mode(t, t and portrait)
	if t:
		var hs := TOUCH_HUD_SCALE if (portrait and vs.x >= 440.0) else 1.0
		hud.scale = Vector2(hs, hs)
		hud.position = Vector2(14, 10)
	else:
		hud.scale = Vector2.ONE
		hud.position = Vector2(12, 6 if portrait else 12)
	var plate: Rect2 = hud._layout()["plate"]
	var hud_bottom: float = hud.position.y + plate.end.y * hud.scale.y
	var hud_right: float = hud.position.x + plate.end.x * hud.scale.x
	# the build bar: centred between the stick and the button cluster on a wide phone
	var stick_right := 140.0
	var cluster_left := vs.x - 240.0
	if minimap != null:
		var ms := 1.0 if not portrait else 0.7
		if t:
			# upright: as big as fits beside the HUD; wide: about 27% of the screen height (MOBA style)
			ms = clampf((vs.x - hud_right - 16.0) / minimap.size.x, 0.45, 0.7) if portrait else clampf(vs.y * 0.27 / minimap.size.y, 0.45, 0.7)
		var edge := 8.0 if t else 12.0
		minimap.pivot_offset = Vector2(minimap.size.x, 0.0)
		minimap.scale = Vector2(ms, ms)
		minimap.offset_left = -(minimap.size.x + edge)
		minimap.offset_right = -edge
		minimap.offset_top = 8.0 if t else (128.0 if portrait else 10.0)
		minimap.offset_bottom = minimap.offset_top + minimap.size.y
	var mid_shift := 0.0 if (portrait or not t) else ((stick_right + cluster_left) * 0.5 - vs.x * 0.5)
	if hotbar_bar != null:
		hotbar_bar.visible = not t   # on a phone the round BUILD / SWAP / REMOVE buttons do the same job
		hotbar_bar.add_theme_constant_override("separation", (8 if not portrait else 10) if t else 36)
		hotbar_bar.offset_bottom = -14.0 if t else -12.0
		hotbar_bar.offset_top = hotbar_bar.offset_bottom - (44.0 if t else 44.0)
		hotbar_bar.offset_left = mid_shift
		hotbar_bar.offset_right = mid_shift
		for i in hotbar.size():
			_style_hotbar_button(i, t)
			if t and not portrait:
				hotbar[i].custom_minimum_size = Vector2(104, 52)
	if skillbar != null:
		if t and portrait:
			skillbar.set_layout(44.0, maxi(4, int((vs.x - 12.0 - 56.0) / 50.0)), true)
			skillbar.anchor_left = 0.0
			skillbar.anchor_right = 0.0
			skillbar.anchor_top = 0.0
			skillbar.anchor_bottom = 0.0
			skillbar.offset_left = 12.0
			skillbar.offset_right = 12.0 + skillbar.size.x
			skillbar.offset_top = hud_bottom + 8.0
			skillbar.offset_bottom = skillbar.offset_top + skillbar.size.y
		else:
			var per: int = skillbar.PER_ROW if not t else maxi(4, int((cluster_left - stick_right - 24.0) / 46.0))
			skillbar.set_layout(skillbar.SLOT, per, false)
			var lift := 84.0 if t else 78.0
			skillbar.anchor_left = 0.5
			skillbar.anchor_right = 0.5
			skillbar.anchor_top = 1.0
			skillbar.anchor_bottom = 1.0
			skillbar.offset_left = -skillbar.size.x * 0.5 + mid_shift
			skillbar.offset_right = skillbar.size.x * 0.5 + mid_shift
			skillbar.offset_top = -(skillbar.size.y + lift)
			skillbar.offset_bottom = -lift
	if credit != null:
		if t:
			credit.anchor_left = 0.0
			credit.offset_left = 12
			credit.offset_right = -12
			credit.offset_top = -20
			credit.offset_bottom = -3
			credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			credit.add_theme_font_size_override("font_size", 11)
		else:
			credit.anchor_left = 1.0
			credit.offset_left = -520
			credit.offset_right = -14
			credit.offset_top = -34
			credit.offset_bottom = -8
			credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			credit.add_theme_font_size_override("font_size", 14)
	# the evolution banner and the red notices: wrapped and kept clear of the HUD on a phone (see _place_notices)
	for row in [[evo_banner, 170.0, 40, 26], [notice, 250.0, 26, 20]]:
		var l: Label = row[0]
		if l == null:
			continue
		l.anchor_left = 0.0 if t else 0.5
		l.anchor_right = 0.0 if t else 0.5
		l.offset_left = 16.0 if t else 0.0
		l.offset_right = vs.x - 16.0 if t else 0.0
		l.offset_top = row[1]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if t else TextServer.AUTOWRAP_OFF
		l.add_theme_font_size_override("font_size", row[3] if t else row[2])
	if t:
		_place_notices()


## The screen rectangles the HUD pieces take on a phone (plate, minimap, skill icons, boss bar, build bar).
func hud_rects() -> Array:
	var out: Array = []
	if hud == null:
		return out
	var plate: Rect2 = hud._layout()["plate"]
	out.append(Rect2(hud.position + plate.position * hud.scale, plate.size * hud.scale))
	if minimap != null:
		out.append(Rect2(minimap.get_global_rect().position, minimap.size * minimap.scale))
	if skillbar != null and skillbar.used_height() > 0.0:
		var sr: Rect2 = skillbar.get_global_rect()
		out.append(Rect2(sr.position.x, sr.end.y - skillbar.used_height() if not skillbar.from_top else sr.position.y, sr.size.x, skillbar.used_height()))
	if hotbar_bar != null and hotbar_bar.visible:
		out.append(hotbar_bar.get_global_rect())
	for c in hud.get_parent().get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("boss_bar.gd") and c.visible:
			out.append(Rect2(c.position, c.size))
	return out


## Stacks the visible notices under the HUD on a phone and narrows them around anything they would cover.
func _place_notices() -> void:
	var vs := get_viewport().get_visible_rect().size
	var rects := hud_rects()
	if touch_ui != null and touch_ui.has_method("ui_rects"):
		rects.append_array(touch_ui.ui_rects())
	var y := 0.0
	for r in hud_rects().slice(0, 1):
		y = r.end.y + 8.0
	if ui_portrait:
		for r in rects:
			if r.position.y < vs.y * 0.3:
				y = maxf(y, r.end.y + 8.0)  # below the stacked HUD, skill icons, minimap and "?"
	for l in [notice, evo_banner]:
		if l == null or not l.visible:
			continue
		var left := 16.0
		var right := vs.x - 16.0
		var px: int = l.get_theme_font_size("font_size")
		var h := 0.0
		for pass_i in 3:
			h = l.get_theme_font("font").get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, right - left, px).y + 4.0
			var box := Rect2(left, y, right - left, h)
			for r in rects:
				if r.intersects(box):
					if r.get_center().x > vs.x * 0.5:
						right = minf(right, r.position.x - 8.0)
					else:
						left = maxf(left, r.end.x + 8.0)
		l.offset_left = left
		l.offset_right = maxf(right, left + 60.0)
		l.offset_top = y
		y += h + 6.0


## Where the boss bar goes on a phone (Vector2.INF: its usual desktop spot): under the skill icons and the "?" when
## upright, under the HUD plate when wide.
func boss_bar_spot(w: float) -> Vector2:
	if not touch_mode or hud == null:
		return Vector2.INF
	var vs := get_viewport().get_visible_rect().size
	if ui_portrait and skillbar != null:
		return Vector2((vs.x - w) * 0.5, maxf(skillbar.offset_top + skillbar.used_height(), 224.0) + 4.0)
	return Vector2(16, hud.position.y + Rect2(hud._layout()["plate"]).end.y * hud.scale.y + 8.0)

## A build button's look: the desktop icon + price + key badge, or on a phone a labelled card
## (picture, TOWER / WALL / REMOVE, and the price in bones).
func _style_hotbar_button(i: int, t: bool) -> void:
	var btn: Button = hotbar[i]
	var part: Dictionary = hotbar_parts[i]
	part["inner"].visible = t
	part["badge"].visible = not t
	btn.icon = null if t else part["icon"]
	btn.custom_minimum_size = Vector2(96, 44) if t else Vector2(104, 58)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		btn.remove_theme_stylebox_override(st)
	if t:
		btn.text = ""
		var gold := Color("ffd84a") if i < 2 else Color("ff7a5a")
		btn.add_theme_stylebox_override("normal", _panel_box(Color(0.05, 0.06, 0.1, 0.78), Color(1, 1, 1, 0.28), 2))
		btn.add_theme_stylebox_override("hover", _panel_box(Color(0.05, 0.06, 0.1, 0.78), Color(1, 1, 1, 0.28), 2))
		btn.add_theme_stylebox_override("pressed", _panel_box(Color(gold.darkened(0.6), 0.85), gold, 3))
		btn.add_theme_stylebox_override("hover_pressed", _panel_box(Color(gold.darkened(0.6), 0.85), gold, 3))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _panel_box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(10)
	return b


## Where building and removing happen: under the mouse, or a step in front of 小怪 on a touchscreen.
func aim_point() -> Vector2:
	if touch_mode and player != null:
		return player.global_position + player.facing * 56.0
	return get_global_mouse_position()


## True while the game itself wants the tree paused (a level-up menu), so a resume from YouTube does not undo it.
func wants_pause() -> bool:
	return (menu_open and pause_on_menu) or start_gate != null


## A phone browser stays silent until a real tap on a real button, so touch devices start behind "TAP TO START"
## (never in headless runs or when a test sets the "no_start_gate" meta; desktops start right away).
func needs_start_gate() -> bool:
	if DisplayServer.get_name() == "headless" or Engine.has_meta("no_start_gate"):
		return false
	return preload("res://touch_controls.gd")._has_touchscreen()


func open_start_gate(text: String) -> void:
	if start_gate != null:
		return
	_reset_touch()
	var layer := CanvasLayer.new()
	layer.layer = 12
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	start_gate = preload("res://start_gate.gd").new()
	start_gate.title = text
	layer.add_child(start_gate)
	start_gate.started.connect(close_start_gate)
	get_tree().paused = true


func close_start_gate() -> void:
	if start_gate == null:
		return
	start_gate.get_parent().queue_free()
	start_gate = null
	_away = false
	get_tree().paused = wants_pause()
	_reset_touch()
	Sfx.play(get_tree(), "select")


func _notification(what: int) -> void:
	# back from another app or tab on a phone: the browser may have muted the page, a tap on the panel unmutes it
	if not OS.has_feature("web") or not touch_mode or game_over:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_away = true
	elif (what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN) and _away:
		open_start_gate("TAP TO CONTINUE")


# --- music ---

## Music follows how far 小怪 has evolved; nights have their own calmer track, and the
## final forms get the final boss theme.
func wanted_track() -> String:
	# what is happening decides first: an event, then danger, then a hidden enemy nearby
	var ev: String = events.music_track() if events != null else ""
	if ev != "":
		return ev
	if player.hp > 0 and player.hp <= player.max_hp * 0.3:
		return "danger"
	if _hidden_near():
		return "hidden"
	var s: int = player.stage
	if calm_time > 14.0 and not is_night() and s < 9:
		return "peace"
	if s >= 9:
		return "final"
	if is_night():
		return "pool:night"
	if s >= 6:
		return "pool:late"
	if s >= 3:
		return "pool:mid"
	return "pool:early"


## A hidden enemy (Parasite Hero, Dark Hero or GOD) within about 900 px.
func _hidden_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("secret") != null and int(e.get("secret")) >= 0 and e.global_position.distance_to(player.global_position) < 900.0:
			return true
	return false


## Shake the camera (events and big blasts call this); the shake fades by itself.
func punch(amount: float) -> void:
	punch_amp = maxf(punch_amp, amount)


func shake(amount: float) -> void:
	shake_amp = maxf(shake_amp, amount)


func _update_music() -> void:
	var want := wanted_track()
	if want.begins_with("pool:"):
		music.play_pool(want.substr(5))
	else:
		music.play_single(want)
	var text: String = music.credit_text()
	credit.text = "♪ " + text if text != "" else ""


# --- time ---

## 0.0 at midnight, 1.0 at noon. Crosses 0.5 at dawn (clock 0) and dusk.
func daylight() -> float:
	var cycle := DAY_SECONDS + NIGHT_SECONDS
	return (0.5 + 0.5 * cos(TAU * (fposmod(clock, cycle) - DAY_SECONDS * 0.5) / cycle)) * (1.0 - eclipse_t)


func is_night() -> bool:
	return fposmod(clock, DAY_SECONDS + NIGHT_SECONDS) >= DAY_SECONDS or eclipse_t > 0.5


## Villagers spawned at 5 minutes have 1.7x their health, at 10 minutes 2.4x, at 15 minutes 3.1x, at 20 minutes 3.9x
## (like the swarms of a survivor game that grow tougher with the clock), and hit up to 1.7x as hard by 15 minutes.
static func hp_mult_at(seconds: float) -> float:
	return 1.0 + seconds / 420.0


static func damage_mult_at(seconds: float) -> float:
	return 1.0 + seconds / 900.0


## How many villagers may chase 小怪 at once: 6 at the start, one more every 10 seconds, up to 130. The nearest ones get
## the places; the rest wait for them to fall. Without this, every villager on the map arrives together.
func chase_budget() -> int:
	return mini(130, 6 + int(elapsed / 10.0))


func _update_chasers(delta: float) -> void:
	_chaser_t -= delta
	if _chaser_t > 0.0 or player == null or Engine.has_meta("deterministic_map"):
		return
	_chaser_t = 0.5
	var list: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			list.append([e.global_position.distance_squared_to(player.global_position), e])
	list.sort_custom(func(a, b): return a[0] < b[0])
	var budget := chase_budget()
	for i in list.size():
		list[i][1].chase_ok = i < budget


func enemy_hp_mult() -> float:
	return 1.0 if Engine.has_meta("deterministic_map") else hp_mult_at(elapsed)  # (the tests jump the clock around)


func enemy_damage_mult() -> float:
	return 1.0 if Engine.has_meta("deterministic_map") else damage_mult_at(elapsed)


func enemy_power() -> float:
	if elapsed < GRACE_SECONDS:
		return 1.0
	return (1.0 if is_night() else DAY_ENEMY_POWER) * (1.4 if blood_moon and eclipse_t > 0.5 else 1.0)


func ranged_unlocked() -> bool:
	return elapsed >= GRACE_SECONDS


func skills_unlocked() -> bool:
	return elapsed >= SKILLS_AT


## How far villagers can notice 小怪. Small at first, then the whole map.
func chase_radius() -> float:
	if elapsed >= CHASE_FULL_AT:
		return INF
	return lerpf(CHASE_START, 6000.0, elapsed / CHASE_FULL_AT)


func enemy_speed_mult() -> float:
	return lerpf(EARLY_SPEED, 1.0, clampf(elapsed / GRACE_SECONDS, 0.0, 1.0)) * (1.2 if blood_moon and eclipse_t > 0.5 else 1.0)


func player_power() -> float:
	return NIGHT_PLAYER_POWER if is_night() else 1.0


## The HD-2D finish, ported from art/preview.src.html: a screen shader (bloom, tilt-shift, light
## shafts or moon wash, vignette), pollen by day and fireflies by night, soft bokeh, warm lights in the
## tower windows, and a lantern around 小怪 at night.
func _build_hd2d() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	radial_tex = GradientTexture2D.new()
	radial_tex.gradient = grad
	radial_tex.fill = GradientTexture2D.FILL_RADIAL
	radial_tex.fill_from = Vector2(0.5, 0.5)
	radial_tex.fill_to = Vector2(1.0, 0.5)
	radial_tex.width = 256
	radial_tex.height = 256
	var shade := Gradient.new()
	shade.set_color(0, Color(0.08, 0.04, 0.16, 0.55))
	shade.add_point(0.6, Color(0.08, 0.04, 0.16, 0.3))
	shade.set_color(shade.get_point_count() - 1, Color(0.08, 0.04, 0.16, 0.0))
	shadow_tex = GradientTexture2D.new()
	shadow_tex.gradient = shade
	shadow_tex.fill = GradientTexture2D.FILL_RADIAL
	shadow_tex.fill_from = Vector2(0.5, 0.5)
	shadow_tex.fill_to = Vector2(1.0, 0.5)
	shadow_tex.width = 64
	shadow_tex.height = 64

	var tree_layer := preload("res://trees.gd").new()
	tree_layer.cells = trees
	tree_layer.water = water
	tree_layer.skip = buildings
	tree_layer.cam = cam
	tree_layer.biome = biome
	add_child(tree_layer)
	move_child(tree_layer, 0)
	var ground_layer := preload("res://ground_layer.gd").new()
	var static_layer := preload("res://static_layer.gd").new()
	static_layer.main = self
	static_layer.cam = cam
	add_child(static_layer)
	move_child(static_layer, 0)
	ground_layer.cam = cam
	ground_layer.biome = biome
	ground_layer.cols = COLS
	ground_layer.rows = ROWS
	ground_layer.z_index = -5  # under everything else: the shadows and props main draws, the ponds, the mud
	add_child(ground_layer)
	move_child(ground_layer, 0)
	var mud_layer := preload("res://mud.gd").new()
	mud_layer.cells = mud
	mud_layer.cam = cam
	add_child(mud_layer)
	move_child(mud_layer, 0)
	var dirt_layer := preload("res://mud.gd").new()
	dirt_layer.cells = dirt
	dirt_layer.cam = cam
	dirt_layer.tex_name = "dirt"
	dirt_layer.bubbles = false
	add_child(dirt_layer)
	move_child(dirt_layer, 0)
	var town_layer := preload("res://town_layer.gd").new()
	town_layer.main = self
	town_layer.layout = layout
	town_layer.cam = cam
	add_child(town_layer)
	move_child(town_layer, 0)
	town_layer.build()
	var path_layer := preload("res://water.gd").new()
	path_layer.cells = paths
	path_layer.cam = cam
	path_layer.base = "stone_path"
	path_layer.edge_prefix = "pathedge_"
	add_child(path_layer)
	move_child(path_layer, 0)
	var pond_layer := preload("res://water.gd").new()
	pond_layer.cells = water
	pond_layer.cam = cam
	add_child(pond_layer)
	move_child(pond_layer, 0)  # draw under the player, villagers and buildings so their whole bodies show in water

	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hd2d_mat = ShaderMaterial.new()
	# phones and browsers get the light finish: the full one reads the whole screen back every frame
	hd2d_mat.shader = load("res://hd2d_lite.gdshader" if OS.has_feature("web") or DisplayServer.is_touchscreen_available() else "res://hd2d.gdshader")
	rect.material = hd2d_mat
	layer.add_child(rect)
	add_child(layer)

	# pollen by day, fireflies by night (46 motes as in the reference), plus 7 drifting bokeh discs
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	motes = CPUParticles2D.new()
	motes.amount = 46
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(660, 370)
	motes.direction = Vector2(0.6, -0.4)
	motes.spread = 70.0
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 16.0
	motes.gravity = Vector2.ZERO
	motes.scale_amount_min = 0.012
	motes.scale_amount_max = 0.035
	motes.texture = radial_tex
	motes.color_ramp = fade
	motes.material = add_mat
	motes.position = Vector2(640, 360)
	layer.add_child(motes)
	bokeh = CPUParticles2D.new()
	bokeh.amount = 7
	bokeh.lifetime = 40.0
	bokeh.preprocess = 40.0
	bokeh.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bokeh.emission_rect_extents = Vector2(700, 60)
	bokeh.direction = Vector2(1, 0)
	bokeh.spread = 5.0
	bokeh.initial_velocity_min = 8.0
	bokeh.initial_velocity_max = 12.0
	bokeh.gravity = Vector2.ZERO
	bokeh.scale_amount_min = 0.25
	bokeh.scale_amount_max = 0.5
	bokeh.texture = radial_tex
	bokeh.color_ramp = fade
	bokeh.material = add_mat
	bokeh.position = Vector2(640, 640)
	layer.add_child(bokeh)

	glow_light = PointLight2D.new()
	glow_light.texture = radial_tex
	glow_light.color = Color(1.0, 0.85, 0.6)
	glow_light.texture_scale = 0.6
	glow_light.energy = 0.0
	glow_light.z_index = 4
	player.add_child(glow_light)


## Day to night: the warm or blue multiply grade (the reference's), shafts or moon wash, lights, motes.
func _update_daynight() -> void:
	var day := smoothstep(0.1, 0.9, daylight())
	tint.color = NIGHT_TINT.lerp(DAY_TINT, day)
	if blood_moon:
		tint.color = tint.color.lerp(Color(0.8, 0.28, 0.34), eclipse_t * 0.65)
	if hd2d_mat != null:
		hd2d_mat.set_shader_parameter("night", 1.0 - day)
	if glow_light != null:
		glow_light.energy = lerpf(0.55, 0.0, day)
	if motes != null:
		motes.color = Color(1.0, 0.94, 0.75, 0.7).lerp(Color(0.75, 1.0, 0.6, 1.0), 1.0 - day)
		bokeh.color = Color(1.0, 0.9, 0.67, 0.14).lerp(Color(0.59, 0.67, 1.0, 0.16), 1.0 - day)
	_update_tower_lamps(day)


## Warm light in every tower's window: strong at night, faint by day, with a flicker.
func _update_tower_lamps(day: float) -> void:
	if radial_tex == null:
		return
	for tw in get_tree().get_nodes_in_group("towers"):
		var lamp: PointLight2D = tw.get_node_or_null("Lamp")
		if lamp == null:
			lamp = PointLight2D.new()
			lamp.name = "Lamp"
			lamp.texture = radial_tex
			lamp.color = Color(1.0, 0.67, 0.31)
			lamp.position = Vector2(0, -6)
			tw.add_child(lamp)
		var flick := 0.85 + 0.15 * sin(elapsed * 9.0 + tw.position.x) * sin(elapsed * 3.1 + tw.position.x)
		lamp.texture_scale = lerpf(0.6, 0.25, day)
		lamp.energy = lerpf(1.0, 0.3, day) * flick


# --- ponds and scenery ---

## Ponds away from the base. You can wade in (slowly) but drown after 10 seconds, and so does everything else.
func _make_ponds(gen: RandomNumberGenerator) -> void:
	var made := 0
	var tries := 0
	while made < 18 and tries < 600:
		tries += 1
		var c := Vector2i(gen.randi_range(10, COLS - 11), gen.randi_range(8, ROWS - 9))
		if Vector2(c - START_TILE).length() < 16.0:
			continue
		var rx := gen.randi_range(3, 7)
		var ry := gen.randi_range(2, 5)
		var pond := {}
		var clear := true
		for dx in range(-rx, rx + 1):
			for dy in range(-ry, ry + 1):
				if float(dx * dx) / (rx * rx) + float(dy * dy) / (ry * ry) <= 1.0:
					var t := c + Vector2i(dx, dy)
					if trees.has(t) or mud.has(t):
						clear = false
					pond[t] = true
		if not clear:
			continue
		# trim thin tips: every shore tile needs a drawn edge, so no cell may touch grass on 3 sides
		var changed := true
		while changed:
			changed = false
			for t in pond.keys():
				var open_sides := 0
				for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					if not pond.has(t + d):
						open_sides += 1
				if open_sides >= 3:
					pond.erase(t)
					changed = true
		for t in pond:
			water[t] = true
		made += 1


## Three winding stone paths leaving the base meadow toward the far corners and the middle. Two tiles wide so the
## edge tiles fit; they skip trees, water and mud.
func _make_paths(gen: RandomNumberGenerator) -> void:
	var goals := [Vector2i(COLS - 10, 14), Vector2i(14, ROWS - 10), Vector2i(COLS / 2, ROWS / 2)]
	for goal in goals:
		var pos := Vector2(START_TILE) + (Vector2(goal) - Vector2(START_TILE)).normalized() * 9.0
		var target := Vector2(goal)
		var heading := (target - pos).normalized()
		for step in 400:
			if pos.distance_to(target) < 4.0:
				break
			heading = (heading + (target - pos).normalized() * 0.18 + Vector2.from_angle(gen.randf_range(-0.5, 0.5)) * 0.25).normalized()
			pos += heading
			var c := Vector2i(roundi(pos.x), roundi(pos.y))
			for dx in range(0, 2):
				for dy in range(0, 2):
					var t := c + Vector2i(dx, dy)
					if t.x > 1 and t.y > 1 and t.x < COLS - 2 and t.y < ROWS - 2 and not trees.has(t) and not water.has(t) and not mud.has(t):
						paths[t] = true
	# trim thin tips like the ponds, so every path tile has a drawn edge
	var changed := true
	while changed:
		changed = false
		for t in paths.keys():
			var open_sides := 0
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				if not paths.has(t + d):
					open_sides += 1
			if open_sides >= 3:
				paths.erase(t)
				changed = true


## Bushes, rocks, flowers, fences and gravestones: scenery with no collision.
func _scatter_props() -> void:
	var pr := RandomNumberGenerator.new()
	pr.seed = map_seed + 77
	var names := ["prop_bush", "prop_rocks_1", "prop_rocks_2", "prop_flowers_1", "prop_flowers_2", "prop_flowers_1", "prop_flowers_2", "prop_bush"]
	for i in 650:
		var t := Vector2i(pr.randi_range(2, COLS - 3), pr.randi_range(2, ROWS - 3))
		if trees.has(t) or mud.has(t) or water.has(t) or paths.has(t) or props.has(t) or biome.has(t) or Vector2(t - START_TILE).length() < 4.0:
			continue
		props[t] = names[pr.randi_range(0, names.size() - 1)]
	for k in 7:
		var g := Vector2i(pr.randi_range(12, COLS - 13), pr.randi_range(10, ROWS - 11))
		if Vector2(g - START_TILE).length() < 16.0:
			continue
		for j in 3:
			var t := g + Vector2i(j * 2, pr.randi_range(0, 1))
			if not trees.has(t) and not mud.has(t) and not water.has(t):
				props[t] = "prop_gravestone"
	for k in 6:
		var f := Vector2i(pr.randi_range(12, COLS - 20), pr.randi_range(10, ROWS - 11))
		if Vector2(f - START_TILE).length() < 14.0:
			continue
		for j in 6:
			var t := f + Vector2i(j, 0)
			if not trees.has(t) and not mud.has(t) and not water.has(t):
				props[t] = "prop_fence"


## A soft shadow under something, falling to the lower right (light from the top left).
func _shadow(foot: Vector2, rx: float, ry: float, shift: float = 0.0, ci: CanvasItem = null) -> void:
	if shadow_tex != null:
		(ci if ci != null else self).draw_texture_rect(shadow_tex, Rect2(foot.x + shift - rx, foot.y - ry, rx * 2.0, ry * 2.0), false)


func _draw_prop(t: Vector2i, name: String, ci: CanvasItem = null) -> void:
	var o: CanvasItem = ci if ci != null else self
	if name.begins_with("bp_"):
		Biomes.draw_prop(o, name, Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE - 1))
		return
	var tex := Sprites.tex(name)
	if tex == null:
		return
	var w := tex.get_width()
	var h := tex.get_height()
	var foot := Vector2(t.x * TILE + TILE * 0.5, (t.y + 1) * TILE - 1)
	_shadow(foot, maxf(5.0, w * (0.25 if name.begins_with("prop_fence") else 0.2)), 2.5, 2.0, o)
	o.draw_texture(tex, Vector2(t.x * TILE + (TILE - w) * 0.5, (t.y + 1) * TILE - h))


## Shrines, healing springs, crypts and ruined towers, spread over the map far from the start and from each other.
func _scatter_pois(rng: RandomNumberGenerator) -> void:
	var plan := ["shrine", "shrine", "shrine", "spring", "spring", "spring", "crypt", "crypt", "crypt", "tower", "tower"]
	var placed: Array[Vector2i] = []
	for kind in plan:
		var best := Vector2i(-1, -1)
		for tries in 400:
			var t: Vector2i = open_tiles[rng.randi_range(0, open_tiles.size() - 1)]
			if Vector2(t - START_TILE).length() < 26.0:
				continue
			if not _poi_spot_free(t):
				continue
			var spaced := true
			for o in placed:
				if Vector2(t - o).length() < 20.0:
					spaced = false
					break
			if not spaced:
				continue
			var b: int = int(biome.get(t, 0))
			# crypts like the graveyard, springs the swamp and the meadow; for the others anywhere will do
			if kind == "crypt" and b != Biomes.GRAVEYARD and tries < 300:
				continue
			if kind == "spring" and (b == Biomes.DESERT or b == Biomes.SNOW) and tries < 300:
				continue
			best = t
			break
		if best.x < 0:
			continue
		placed.append(best)
		props[best] = "_poi"
		var poi = PoiScript.new()
		poi.kind = kind
		poi.position = _tile_center(best)
		add_child(poi)


## A free 3 by 3 patch with no trees, water, mud, paths, buildings or props.
func _poi_spot_free(t: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := t + Vector2i(dx, dy)
			if trees.has(c) or water.has(c) or mud.has(c) or paths.has(c) or props.has(c) or floors.has(c) or buildings.has(c):
				return false
	return true


## Chests: mostly wooden near the base, silver and gold further out, a few cursed ones anywhere.
func _scatter_treasures() -> void:
	var tr := RandomNumberGenerator.new()
	tr.seed = map_seed + 99
	var placed: Array[Vector2i] = []
	var plan := {"wood": 14, "silver": 6, "gold": 3, "cursed": 2}
	for tier in plan:
		var count: int = plan[tier]
		var tries := 0
		while count > 0 and tries < 4000:
			tries += 1
			var t: Vector2i = open_tiles[tr.randi_range(0, open_tiles.size() - 1)]
			var dist := Vector2(t - START_TILE).length()
			if trees.has(t) or mud.has(t) or water.has(t) or props.has(t) or dist < 9.0:
				continue
			if tier == "silver" and dist < 25.0:
				continue
			if tier == "gold" and dist < 55.0:
				continue
			var near := false
			for o in placed:
				if Vector2(o - t).length() < 7.0:
					near = true
					break
			if near:
				continue
			placed.append(t)
			count -= 1
			var chest = TreasureScript.new()
			chest.tier = tier
			chest.position = _tile_center(t)
			treasure_spots.append(chest)


# --- map ---

func _tile_center(t: Vector2i) -> Vector2:
	return (Vector2(t) + Vector2(0.5, 0.5)) * TILE


func tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(maxi(int(pos.x / TILE), 0), maxi(int(pos.y / TILE), 0))


func _generate() -> void:
	var gen := RandomNumberGenerator.new()
	gen.seed = map_seed

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

	_make_ponds(gen)
	_make_paths(gen)
	layout = Towns.generate(self, gen)
	_find_open_tiles()
	var biome_rng := RandomNumberGenerator.new()
	biome_rng.seed = map_seed + 1234
	biome = Biomes.generate(biome_rng, COLS, ROWS, START_TILE)
	_build_nav()
	_scatter_props()
	Biomes.scatter_props(self, biome_rng)
	_scatter_treasures()
	_scatter_pois(biome_rng)

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
	_make_town_tiles()
	if not Engine.has_meta("deterministic_map"):
		var before := get_child_count()
		Towns.populate(self, layout, gen)  # residents, soldiers and chests
		town_population = get_child_count() - before - treasure_spots.size() + treasure_spots.size()


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
	open_lookup = seen   # every tile with a walkable route from the start (castle pockets walled in are not here)


## The walking grid villagers use to go around trees, towers and walls.
func _build_nav() -> void:
	astar.region = Rect2i(0, 0, COLS, ROWS)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE, TILE) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for t in trees:
		astar.set_point_solid(t, true)
	# Water is passable but costly (a swimmer drowns), so routes go around ponds and the moat, over a bridge if there is one.
	for t in water:
		if not bridges.has(t):
			astar.set_point_weight_scale(t, 6.0)
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
	var t := tile_of(pos)
	if int(biome.get(t, 0)) == Biomes.SWAMP and not water.has(t):
		return Biomes.SWAMP_SLOW * (MUD_SLOW if mud.has(t) else 1.0)
	if water.has(t):
		return WATER_SLOW
	if paths.has(t):
		return PATH_FAST
	if dirt.has(t):
		return 1.1
	return MUD_SLOW if mud.has(t) else 1.0


func is_water_at(pos: Vector2) -> bool:
	return water.has(tile_of(pos))


## Time spent in water per body (instance id -> seconds). Leaving the water cools it down twice as fast.
var drown := {}


## Anything that stays in water for DROWN_SECONDS drowns: 小怪 and villagers alike. Villagers that
## drown give no EXP or bones, so luring them into a pond is not a farm.
func _update_drowning(delta: float) -> void:
	if water.is_empty():
		return
	var bodies: Array = get_tree().get_nodes_in_group("enemies").duplicate()
	if player != null and player.hp > 0:
		bodies.append(player)
	var alive := {}
	for b in bodies:
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			continue
		if b != player and b.immune():
			continue  # GOD walks through water
		var id: int = b.get_instance_id()
		alive[id] = true
		var t: float = drown.get(id, 0.0)
		if is_water_at(b.global_position):
			t += delta
			if b == player:
				var left := ceili(DROWN_SECONDS - t)
				if t >= DROWN_SECONDS * 0.5 and int(t) != int(t - delta):
					Popups.text(get_tree(), b.global_position + Vector2(0, -26), "Drowning %d" % maxi(left, 0), Popups.WHITE, 15)
			if t >= DROWN_SECONDS:
				_drown(b)
				drown.erase(id)
				continue
		else:
			t = maxf(t - delta * 2.0, 0.0)
		if t > 0.0:
			drown[id] = t
		else:
			drown.erase(id)
	for id in drown.keys():
		if not alive.has(id):
			drown.erase(id)


func _drown(b) -> void:
	if b == player:
		player.invuln = 0.0
		player.take_hit(999999, Vector2.ZERO)
	else:
		b.xp_value = 0
		b.bones_value = 0
		b.hurt(999999)


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
	if water.has(tile):
		return "Cannot build on water"
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
	var ok := place_at(tile_of(aim_point()), build_item)
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
	return demolish_at(tile_of(aim_point()))


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
	_add_action("lunge", [])  # the old separate lunge; the roll does its job now
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("dodge", right)  # right click rolls too
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
## The order villagers join the fight, weakest first: Farmer, Woodsman, Hunter, Militia, Mage, Priest,
## Knight, Thief, Smith, Noble. Then the hidden forms (Parasite Hero, Dark Hero and GOD) at the very end.
const ROSTER := [0, 1, 2, 3, 6, 5, 4, 8, 7, 9]
const ROSTER_STEP := 90.0         # a new profession every 90 seconds, or every 8 levels of 小怪


func roster_size() -> int:
	var by_time := int(elapsed / ROSTER_STEP)
	var by_level := int(player.level / 8) if player != null else 0
	return clampi(1 + maxi(by_time, by_level), 1, ROSTER.size())


## Which profession a new villager is: only the unlocked ones, newer (stronger) ones a little more often.
func roster_line() -> int:
	var n := roster_size()
	var total := 0.0
	for i in n:
		total += 1.0 + 0.6 * i
	var roll := rng.randf() * total
	for i in n:
		roll -= 1.0 + 0.6 * i
		if roll <= 0.0:
			return ROSTER[i]
	return ROSTER[n - 1]


func _spawn_villager(p: Vector2, stage: int, line: int = -1, secret: int = -1):
	var v = VillagerScript.new()
	v.stage = stage
	v.secret = secret
	v.line = line if line >= 0 else (roster_line() if secret < 0 else rng.randi_range(0, VillagerScript.LINES.size() - 1))
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
	layer.layer = 2  # above the HD-2D finish
	add_child(layer)
	hud_layer = layer
	hud = preload("res://hud_panel.gd").new()
	hud.position = Vector2(16, 12)
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
	hotbar_bar = bar
	var hotbar_icons := ["icon_build_tower", "icon_build_wall", "icon_build_remove"]
	var hotbar_tips := ["Tower (key 1): shoots the nearest villager. Build on it again to upgrade.", "Bone wall (key 2): blocks the way.", "Remove (key X): take back a tower or wall under the mouse for half its bones."]
	for i in 3:
		var ic := Sprites.icon(hotbar_icons[i], 2)
		# all three are clickable icon buttons: tower, bone wall, and remove (click it, then click a building)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon = ic
		btn.expand_icon = false
		btn.custom_minimum_size = Vector2(104, 58)
		btn.tooltip_text = hotbar_tips[i]
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_constant_override("icon_max_width", 48)
		if i < 2:
			var which := "tower" if i == 0 else "wall"
			btn.pressed.connect(func():
				build_item = which
				remove_armed = false
				ghost_dirty = true
				_update_hotbar())
		else:
			btn.pressed.connect(func():
				remove_armed = not remove_armed
				_update_hotbar())
		# a number badge in the corner: the key that picks this button (1 tower, 2 wall, X remove)
		var badge := Label.new()
		badge.text = ["1", "2", "X"][i]
		badge.position = Vector2(5, -1)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", 20)
		badge.add_theme_color_override("font_color", Color("ffe27a"))
		badge.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
		badge.add_theme_constant_override("outline_size", 7)
		btn.add_child(badge)
		# the phone look: the picture, what it is, and its price in bones (shown instead of the icon and key)
		var inner := HBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 5
		inner.offset_right = -4
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 4)
		inner.visible = false
		var pic := TextureRect.new()
		pic.texture = ic
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(32, 32)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(pic)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.add_theme_constant_override("separation", -2)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(words)
		var what := Label.new()
		what.text = ["TOWER", "WALL", "REMOVE"][i]
		what.add_theme_font_size_override("font_size", 12)
		what.add_theme_color_override("font_color", Color("ffe08a"))
		what.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0))
		what.add_theme_constant_override("outline_size", 4)
		words.add_child(what)
		var price := HBoxContainer.new()
		price.add_theme_constant_override("separation", 3)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_child(price)
		var bone := TextureRect.new()
		bone.texture = Sprites.icon("icon_bone", 2)
		bone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bone.custom_minimum_size = Vector2(14, 14)
		bone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.add_child(bone)
		var cost_l := Label.new()
		cost_l.text = "+50%" if i == 2 else ""
		cost_l.add_theme_font_size_override("font_size", 12 if i == 2 else 15)
		cost_l.add_theme_color_override("font_outline_color", Color.BLACK)
		cost_l.add_theme_constant_override("outline_size", 4)
		price.add_child(cost_l)
		btn.add_child(inner)
		bar.add_child(btn)
		hotbar.append(btn)
		hotbar_parts.append({"inner": inner, "cost": cost_l, "badge": badge, "icon": ic})

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

	layer.add_child(preload("res://boss_bar.gd").new())
	ambient = preload("res://ambient.gd").new()
	ambient.main = self
	add_child(ambient)
	minimap = preload("res://minimap.gd").new()
	layer.add_child(minimap)
	minimap.setup(self)
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -(minimap.size.x + 12.0)
	minimap.offset_right = -12.0
	minimap.offset_top = 10.0
	minimap.offset_bottom = 10.0 + minimap.size.y

	skillbar = preload("res://skillbar.gd").new()
	layer.add_child(skillbar)
	skillbar.setup(self)
	skillbar.anchor_left = 0.5
	skillbar.anchor_right = 0.5
	skillbar.anchor_top = 1.0
	skillbar.anchor_bottom = 1.0
	skillbar.offset_left = -skillbar.size.x * 0.5
	skillbar.offset_right = skillbar.size.x * 0.5
	skillbar.offset_top = -(skillbar.size.y + 78.0)
	skillbar.offset_bottom = -78.0

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
	return mini(POP_CAP, by_time + player.stage * POP_PER_STAGE + town_population)


func spawn_interval() -> float:
	var f := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	return lerpf(SPAWN_SLOW, SPAWN_FAST, f * f) / (1.0 + 0.1 * player.stage)


func _update_hud() -> void:
	var cycle := DAY_SECONDS + NIGHT_SECONDS
	var phase := fposmod(clock, cycle)
	var night := is_night()
	var buffs: Array = []
	for bid in player.buffs:
		buffs.append({"color": TreasureScript.BUFFS[bid]["color"], "secs": ceili(float(player.buffs[bid]))})
	var relics: Array = []
	for rid in player.relics:
		relics.append({"n": int(player.relics[rid])})
	var tile := tile_of(aim_point())
	var refund := refund_at(tile)
	var upgrade_text := ""
	if refund >= 0 and build_item == "tower" and built[tile].has_method("upgrade"):
		upgrade_text = ghost_error if ghost_error != "" else str(build_cost("tower", tile))
	var ab: Dictionary = player.ability() if player.line >= 0 else {}
	hud.set_info({
		"level": player.level, "xp": player.xp,
		"xp_max": player.xp_for_level(player.level + 1) if player.level < player.MAX_LEVEL else 0,
		"hp": player.hp, "max_hp": player.max_hp,
		"night": night, "day": int(clock / cycle) + 1,
		"phase_left": (cycle - phase) if night else (DAY_SECONDS - phase), "phase_len": NIGHT_SECONDS if night else DAY_SECONDS,
		"bones": bones, "kills": kills, "alive": get_tree().get_nodes_in_group("enemies").size(),
		"target_pop": target_population(), "village_level": village_level,
		"sprint": player.sprint_energy, "sprint_max": player.SPRINT_MAX, "sprint_cd": player.sprint_cd, "sprint_cd_max": player.SPRINT_COOLDOWN,
		"roll_cd": player.roll_cd, "roll_cd_max": player.ROLL_COOLDOWN,
		"lunge_cd": player.lunge_cd, "lunge_cd_max": player.LUNGE_COOLDOWN,
		"buffs": buffs, "relics": relics,
		"remove_refund": refund, "upgrade_text": upgrade_text,
		"build_item": build_item, "build_error": ghost_error,
		"build_cost": TowerScript.COSTS[0] if build_item == "tower" else WALL_COST,
		"ability": ab.get("name", ""),
		"combo": player.combo, "combo_frac": clampf(player.combo_t / player.combo_window(), 0.0, 1.0), "counter": player.counter_t > 0.0,
	})


func _update_hotbar() -> void:
	var costs := [build_cost("tower", Vector2i(-1, -1)), build_cost("wall", Vector2i(-1, -1))]
	var kinds := ["tower", "wall"]
	for i in 2:
		var selected: bool = build_item == kinds[i]
		var btn: Button = hotbar[i]
		btn.text = " %d" % costs[i]
		btn.set_pressed_no_signal(selected)
		var c := Color("ffd84a") if selected else Color(1, 1, 1, 0.85)
		if bones < int(costs[i]):
			c = Color("ff7a7a") if selected else Color(1, 0.55, 0.55, 0.8)  # too expensive right now
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(key, c)
		if touch_mode and i < hotbar_parts.size():
			btn.text = ""
			var cl: Label = hotbar_parts[i]["cost"]
			cl.text = str(costs[i])
			cl.add_theme_color_override("font_color", c if bones >= int(costs[i]) else Color("ff7a7a"))
	hotbar[2].text = ""
	hotbar[2].set_pressed_no_signal(remove_armed)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		hotbar[2].add_theme_color_override(key, Color("ff7a5a") if remove_armed else Color(1, 1, 1, 0.75))


# --- level-ups, evolution lines and skills ---

## Every level gets the sound and the ring; a normal skill pick comes every 3rd level and a
## special skill pick every 12th (12, 24, 36 ... 96).
func _on_leveled(new_level: int) -> void:
	Sfx.play(get_tree(), "levelup")
	# every 12th level offers a special skill INSTEAD of the normal skill pick
	if new_level % player.SKILL_EVERY == 0 and new_level % player.SPECIAL_EVERY != 0:
		menu_queue.append({"type": "skill"})
	if new_level % player.SPECIAL_EVERY == 0:
		menu_queue.append({"type": "special"})
	if new_level % perk_every == 0:
		menu_queue.append({"type": "perk"})
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
		# only the finished lines are offered, each with a picture of its first form
		var entries: Array[String] = []
		var line_ids: Array[int] = []
		var line_icons: Array = []
		for i in LinesData.LINES.size():
			if not LinesData.released(i):
				continue
			line_ids.append(i)
			entries.append("%d. %s  [%s]\n%s" % [entries.size() + 1, LinesData.title(i), LinesData.LINES[i]["family"], _line_blurb(i)])
			var art := Sprites.hero(LinesData.LINES[i]["forms"], 1)
			line_icons.append(Sprites.first_frame_icon(art, 3) if art != "" else null)
		var line_cards: Array = []
		for k in line_ids.size():
			var li: int = line_ids[k]
			var fam: String = LinesData.LINES[li]["family"]
			var fam_col := Color.from_hsv(float(LinesData.FAMILIES[fam]["hue"]), 0.55, 1.0)
			line_cards.append({"icon": line_icons[k], "name": LinesData.LINES[li]["forms"][0], "short": _line_blurb(li).strip_edges(),
				"short_narrow": " | ".join(_line_blurb(li).strip_edges().split(" | ").slice(0, 2)),
				"tag": fam.to_upper(), "tag_col": fam_col, "accent": fam_col})
		_open_menu("LEVEL %d: pick your evolution line" % player.level, entries, func(i): pick_line(line_ids[i]), 1, 680, line_icons, 62, line_cards)
	elif item["type"] == "perk":
		var cards := PerksData.roll(player.perks, rng, 3)
		if cards.is_empty():
			_next_menu()
			return
		var perk_entries: Array[String] = []
		for id in cards:
			var info: Dictionary = PerksData.PERKS[id]
			var have: int = int(player.perks.get(id, 0))
			perk_entries.append("%d. %s   %d -> %d\n    %s" % [perk_entries.size() + 1, info["name"], have, have + 1, info["desc"]])
		var perk_cards: Array = []
		for id in cards:
			var pinfo: Dictionary = PerksData.PERKS[id]
			perk_cards.append({"icon": Sprites.icon("icon_perk_" + id, 3), "name": pinfo["name"], "short": pinfo.get("short", pinfo["desc"]),
				"tag": "UPGRADE", "tag_col": pinfo["color"], "accent": pinfo["color"], "rank": int(player.perks.get(id, 0)), "max": int(pinfo["max"])})
		_open_menu("LEVEL %d: pick an upgrade" % player.level, perk_entries, func(i): pick_perk(cards[i]), 1, 620, cards.map(func(pid): return Sprites.icon("icon_perk_" + pid)), 0, perk_cards)
	elif item["type"] == "special":
		var specials := SkillsData.roll_specials(player.specials, rng, 3)
		if specials.is_empty():
			_next_menu()
			return
		var special_entries: Array[String] = []
		for id in specials:
			var info: Dictionary = SkillsData.SPECIALS[id]
			special_entries.append("%d. %s\n    %s" % [special_entries.size() + 1, info["name"], info["desc"]])
		var special_cards: Array = []
		for id in specials:
			special_cards.append({"icon": Sprites.icon("icon_sp_" + id, 3), "name": SkillsData.SPECIALS[id]["name"], "short": SkillsData.short_text(id),
				"tag": "SPECIAL", "tag_col": Color("ffd84a"), "accent": Color("ffd84a")})
		_open_menu("LEVEL %d: pick a special skill" % player.level, special_entries, func(i): pick_special(specials[i]), 1, 620, specials.map(func(sid): return Sprites.icon("icon_sp_" + sid)), 0, special_cards)
	else:
		var options := SkillsData.roll(player.skills, rng, 3, player.line, player.stage)
		if options.is_empty():
			_next_menu()
			return
		var entries: Array[String] = []
		for id in options:
			var info: Dictionary = SkillsData.info(id)
			var r: int = player.rank(id)
			var key_text := "  [auto]" if info.get("auto", false) else ""
			entries.append("%d. %s   rank %d -> %d%s\n    %s\n    %s" % [entries.size() + 1, info["name"], r, r + 1, key_text, info["desc"], _skill_origin(id)])
		var icons: Array = []
		var skill_cards: Array = []
		for id in options:
			var icon_name: String = "icon_fs_" + id if SkillsData.form_skills().has(id) else "icon_" + str(SKILL_ICONS.get(id, id))
			icons.append(Sprites.icon(icon_name))
			var sinfo: Dictionary = SkillsData.info(id)
			var own_line := SkillsData.form_skills().has(id)
			var tag_col := Color("ff9a4a") if own_line else Color("7ab8ff")
			skill_cards.append({"icon": Sprites.icon(icon_name, 3), "name": sinfo["name"], "short": SkillsData.short_text(id),
				"tag": "LINE" if own_line else "GENERAL", "tag_col": tag_col, "accent": tag_col,
				"auto": sinfo.has("auto"), "rank": player.rank(id), "max": int(sinfo.get("max", 1))})
		_open_menu("LEVEL %d: pick a skill" % player.level, entries, func(i): pick_skill(options[i]), 1, 620, icons, 0, skill_cards)


## A menu over the dimmed game. With `cards` (one dictionary per entry, see menu_cards.gd) it shows big picture cards;
## without, the plain text list (the merchant). `entries` stay the plain-text version of the choices either way.
func _open_menu(title: String, entries: Array[String], on_pick: Callable, columns: int, width: int, icons: Array = [], fixed_row_h: int = 0, cards: Array = []) -> void:
	Sfx.play(get_tree(), "menu")
	menu_open = true
	_reset_touch()
	if hud_layer != null:
		hud_layer.visible = false
	get_tree().paused = pause_on_menu
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(dim)
	if not cards.is_empty():
		_build_cards(title, cards, on_pick)
		menu_layer.add_child(menu_root)
		return
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
	# tall enough for every row, so a normal pick never needs scrolling (only the 26-line list does)
	var row_h := (fixed_row_h if fixed_row_h > 0 else (56 if (columns > 1 and not icons.is_empty()) else (44 if columns > 1 else 70))) + 4
	scroll.custom_minimum_size = Vector2(width * columns + 28, mini(640 if fixed_row_h > 0 else 600, row_h * ceili(entries.size() / float(columns)) + 16))
	box.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # text wraps, so there is never a sideways scrollbar
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for i in entries.size():
		var b := Button.new()
		b.text = entries[i]
		b.custom_minimum_size = Vector2(width, fixed_row_h if fixed_row_h > 0 else ((56 if not icons.is_empty() else 44) if columns > 1 else 70))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i < icons.size() and icons[i] != null:
			b.icon = icons[i]
			b.expand_icon = false
		b.pressed.connect(func(): on_pick.call(i))
		if i < 9:
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_1 + i
			var sc := Shortcut.new()
			sc.events = [ev]
			b.shortcut = sc
		grid.add_child(b)
	menu_layer.add_child(menu_root)


## Big picture cards in as many columns as the screen needs so they never scroll (the 9 evolution lines take 1 column
## on an upright phone, 3 on a wide one).
func _build_cards(title: String, cards: Array, on_pick: Callable) -> void:
	var vs := get_viewport().get_visible_rect().size
	var many := cards.size() > 4
	var m := MenuCards.metrics(many)
	var gap := 8.0
	var avail := vs - Vector2(32, 104)
	var min_h := 60.0 if many else 92.0
	# the fewest columns that give comfortable cards (80 px tall, 300 px wide); else the fewest that fit at all
	var cols := 0
	for c in [1, 2, 3]:
		if cols == 0 and ceili(cards.size() / float(c)) * (80.0 + gap) <= avail.y and (avail.x - gap * (c - 1)) / c >= 300.0:
			cols = c
	if cols == 0:
		cols = 1
		while cols < 3 and ceili(cards.size() / float(cols)) * (min_h + gap) > avail.y:
			cols += 1
	var w := minf(560.0 if many else 600.0, (avail.x - gap * (cols - 1)) / cols)
	if not many and w < 480.0:
		m["h"] = 118  # a narrow phone card: room for the short line to wrap once
	var fit_h := int(avail.y / ceili(cards.size() / float(cols)) - gap)
	m["h"] = clampi(fit_h, int(min_h), 100) if many else clampi(fit_h, int(min_h), int(m["h"]))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	var parts := title.split(": ", true, 1)
	var head := Label.new()
	head.text = parts[0]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", Color("ffd84a"))
	head.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0))
	head.add_theme_constant_override("outline_size", 8)
	box.add_child(head)
	if parts.size() > 1:
		var sub := Label.new()
		sub.text = parts[1].substr(0, 1).to_upper() + parts[1].substr(1)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 22)
		sub.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
		sub.add_theme_color_override("font_outline_color", Color.BLACK)
		sub.add_theme_constant_override("outline_size", 5)
		box.add_child(sub)
	var rows := ceili(cards.size() / float(cols))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(w * cols + gap * (cols - 1), minf(rows * (float(m["h"]) + gap), avail.y))
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = cols
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	scroll.add_child(grid)
	for i in cards.size():
		var b := MenuCards.card(cards[i], w, m, i + 1 if (i < 9 and not touch_mode) else 0)
		b.pressed.connect(func(): on_pick.call(i))
		if i < 9:
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_1 + i
			var sc := Shortcut.new()
			sc.events = [ev]
			b.shortcut = sc
		grid.add_child(b)


## Let go of every touch the on-screen controls hold (a menu opening or closing must never leave the stick or a held
## button stuck).
func _reset_touch() -> void:
	if touch_ui != null and touch_ui.has_method("reset_touch"):
		touch_ui.reset_touch()


func _close_menu() -> void:
	Sfx.play(get_tree(), "select")
	if menu_root != null:
		menu_root.queue_free()
		menu_root = null
	menu_open = false
	get_tree().paused = false
	if hud_layer != null:
		hud_layer.visible = true
	_reset_touch()


## The first-evolution menu (or tests) picks a line.
func pick_line(i: int) -> void:
	_close_menu()
	player.choose_line(i)
	_next_menu()


## What sets an evolution line apart, in three short lines for the level-10 menu: the family's trait (shared by every
## line of the family), the line's own signature ability, and the skills only this line can learn.
const SHORT_TRAITS := {"Undead": "Night regen", "Slime": "Splits blobs", "Dragon": "Bite sparks", "Beast": "Fast", "Nature": "Rest to heal", "Material": "-1 damage taken", "Demon": "+1 bone per kill"}


func _line_blurb(i: int) -> String:
	var fam: String = LinesData.LINES[i]["family"]
	var ability := "no ability yet"
	if player.AbilitiesData.ABILITIES.has(i):
		ability = str(player.AbilitiesData.ABILITIES[i]["name"])
	var names: Array[String] = []
	for e in SkillsData.FORM_LIST:
		if int(e[1]) == i:
			names.append(str(e[3]))
	var skills := ", ".join(names.slice(0, 2))
	if names.size() > 2:
		skills += " +%d" % (names.size() - 2)
	return "   %s | %s | %s" % [SHORT_TRAITS.get(fam, fam), ability, skills]


## Where a skill comes from: every line learns the general ones, and each line also has skills of its own.
func _skill_origin(id: String) -> String:
	var fs := SkillsData.form_skills()
	if fs.has(id):
		var l: int = int(fs[id]["line"])
		return "[%s line skill - unlocked at form %s]" % [LinesData.LINES[l]["forms"][0], LinesData.LINES[l]["forms"][clampi(int(fs[id]["form"]) - 1, 0, 9)]]
	return "[general skill - every line can learn it]"


## A level-up menu (or tests) picks a skill.
func pick_skill(id: String) -> void:
	_close_menu()
	player.learn(id)
	_next_menu()


## The special-skill menu (every 12th level, or tests) picks a special.
func pick_perk(id: String) -> void:
	_close_menu()
	player.add_perk(id)
	Popups.text(get_tree(), player.global_position + Vector2(0, -34.0), PerksData.PERKS[id]["name"] + "!", Popups.BIG, 16)
	_next_menu()


func pick_special(id: String) -> void:
	_close_menu()
	player.learn_special(id)
	_next_menu()


# --- events ---

func _on_hp_changed(_hp: int) -> void:
	_update_hud()


func _on_villager_defeated(xp: int, bones_gain: int, by_tower: bool) -> void:
	kills += 1
	if bool(rival["skip_xp"]):
		rival["skip_xp"] = false
	else:
		rival_gain(xp)
	Sfx.play(get_tree(), "coin", -6.0)
	village_level = mini(VILLAGE_TIERS.size(), 1 + int(kills / float(KILLS_PER_VILLAGE_LEVEL)))
	bones += roundi(bones_gain * (1.0 + 0.25 * player.rank("greed")) * (2.0 if player.specials.has("bonehoard") else 1.0) * (2.0 if blood_moon and eclipse_t > 0.5 else 1.0))
	if player.family() == "Demon":
		bones += 1  # Demon trait: every kill drops an extra bone
	if not by_tower:
		player.on_kill()  # (EXP no longer comes from a kill itself: the villager drops an EXP stone to pick up)


func _on_evolved(stage: int) -> void:
	var text := "EVOLVED!\n%s" % player.stages[stage]["name"]
	Sfx.play(get_tree(), "win" if stage == player.LAST_STAGE else "evolve")
	_update_music()
	if stage == player.LAST_STAGE:
		text = "STAGE 1 CLEAR!\n%s rises. Keep defending." % player.stages[stage]["name"]
		evo_timer = 6.0
	else:
		evo_timer = 3.0
		var fresh_skills: Array[String] = []
		var before := SkillsData.form_pool(player.line, stage - 1) if stage > 0 else []
		for id in SkillsData.form_pool(player.line, stage):
			if not before.has(id):
				fresh_skills.append(str(SkillsData.form_skills()[id]["name"]))
		if not fresh_skills.is_empty():
			text += "\nNew line skills to pick: %s" % ", ".join(fresh_skills)
			evo_timer = 5.0
		if player.AbilitiesData.rank_for_stage(stage) > player.AbilitiesData.rank_for_stage(stage - 1) and player.ability().has("name"):
			text += "\nAbility upgraded: %s" % player.ability()["name"]
			evo_timer = 5.0
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
		if secret < 0 and not _town_tiles.is_empty() and rng.randf() < 0.4:
			t = _town_tiles[rng.randi_range(0, _town_tiles.size() - 1)]  # new villagers often turn up in a town
		var p := _tile_center(t)
		if p.distance_to(player.global_position) < SPAWN_MIN_DISTANCE:
			continue
		return _spawn_villager(p, stage, -1, secret)
	return null


## A hidden boss appears inside the big castle and stays there as its guard until GUARD_RELEASE.
func spawn_boss(secret: int):
	var big: Dictionary = layout.get("big", {})
	if big.is_empty():
		return spawn_far(VillagerScript.MAX_STAGE, secret)
	var rect: Rect2i = big["rect"]
	for i in 60:
		var t := Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 2), rng.randi_range(rect.position.y + 1, rect.end.y - 2))
		if floors.has(t) and not trees.has(t) and open_lookup.has(t):  # never in a walled-in pocket with no way out
			var v = _spawn_villager(_tile_center(t), VillagerScript.MAX_STAGE, -1, secret)
			v.guard_home = Vector2(rect.get_center()) * TILE
			v.guard_range = 700.0
			v.guard_leash = 900.0
			v.guard_until = GUARD_RELEASE
			return v
	return spawn_far(VillagerScript.MAX_STAGE, secret)


## At every dawn and dusk there is a chance that a hidden enemy appears.
func _on_phase_change() -> void:
	if elapsed < HIDDEN_FROM or rng.randf() > HIDDEN_SPAWN_CHANCE:
		return
	var count := 1 + int(elapsed / 400.0)
	var secret := 0
	if elapsed > 780.0 and rng.randf() < 0.4:
		secret = 1
	var spawned := 0
	for i in count:
		if spawn_boss(secret) != null:
			spawned += 1
	if spawned > 0:
		_say("%s gathers in the big castle..." % VillagerScript.HIDDEN[secret]["name"])


## GOD descends: the last boss. It does not wait in the castle; it hunts 小怪 at once.
func _check_god() -> void:
	if god_spawned or elapsed < GOD_AT or game_over or player == null or Engine.has_meta("deterministic_map"):  # (the tests jump the clock around)
		return
	spawn_god()


# --- the rival hero ---

## Pick the rival's evolution line (a different one most runs) and bring it into the world when its time comes.
func _update_rival(delta: float) -> void:
	if Engine.has_meta("deterministic_map") or game_over or player == null:
		return
	if int(rival["line"]) < 0:
		var lines: Array = []
		for i in LinesData.LINES.size():
			if LinesData.released(i) and i != player.line:
				lines.append(i)
		rival["line"] = lines[rng.randi_range(0, lines.size() - 1)]
		for k in 2:  # it can hit you with skills from the first second
			var open: Array = RIVAL_ATTACK_SKILLS.filter(func(id): return not rival["skills"].has(id))
			rival["skills"].append(open[rng.randi_range(0, open.size() - 1)])
	var node = rival["node"]
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		if elapsed >= DUEL_AT and not bool(rival["duel"]):
			_start_duel(node)
		return
	if float(rival["respawn"]) > 0.0:
		rival["respawn"] = float(rival["respawn"]) - delta
		if float(rival["respawn"]) > 0.0:
			return
	if elapsed < RIVAL_AT or bool(rival["duel"]) and int(rival["falls"]) > 0:
		return
	spawn_rival()


func spawn_rival():
	# not inside the castle courtyard: somewhere in the open, far from 小怪 (so he has a minute or two to grow before the
	# rival arrives), with a walkable route to him
	var spot := Vector2.INF
	for i in 80:
		var t: Vector2i = open_tiles[rng.randi_range(0, open_tiles.size() - 1)]
		var p := _tile_center(t)
		var d := p.distance_to(player.global_position)
		if d < RIVAL_START_MIN or d > RIVAL_START_MAX or water.has(t) or floors.has(t):
			continue
		if find_path(p, player.global_position).is_empty():
			continue
		spot = p
		break
	if spot == Vector2.INF:
		var far = spawn_far(VillagerScript.MAX_STAGE)
		if far == null:
			return null
		spot = far.global_position
		far.queue_free()
	if rival_home != Vector2.INF:
		spot = rival_home
	else:
		rival_home = spot
		var lair = preload("res://start_pit.gd").new()
		lair.heals = false
		lair.scale = Vector2(0.62, 0.62)
		lair.position = spot
		add_child(lair)
		move_child(lair, 0)
	var v = _spawn_villager(spot, 3, 0, -1)
	v.hero_down.connect(_on_rival_down)
	_refresh_rival(v, true)
	rival["node"] = v
	rival["respawn"] = -1.0
	_say("The rival hero rises (%s line). It will fight you until the end." % LinesData.LINES[int(rival["line"])]["forms"][0] if int(rival["falls"]) == 0 else "The rival hero is back, Lv %d." % int(rival["level"]))
	return v


func rival_stage() -> int:
	return PlayerScript.stage_for_level(int(rival["level"]))


func _refresh_rival(v, full_heal: bool) -> void:
	v.setup_rival(int(rival["line"]), int(rival["level"]), rival_stage(), rival["skills"], full_heal)


## Everything 小怪 defeats feeds the rival: it absorbs RIVAL_ABSORB (40%) of that EXP.
func rival_gain(xp: int) -> void:
	if int(rival["line"]) < 0:
		return
	rival["xp"] = int(rival["xp"]) + maxi(1, roundi(xp * RIVAL_ABSORB))
	var before_stage := rival_stage()
	var grew := false
	while int(rival["level"]) < PlayerScript.MAX_LEVEL and int(rival["xp"]) >= PlayerScript.xp_for_level(int(rival["level"]) + 1):
		rival["level"] = int(rival["level"]) + 1
		grew = true
		if int(rival["level"]) % 2 == 0 and rival["skills"].size() < 12:
			var open: Array = RIVAL_SKILL_POOL.filter(func(id): return not rival["skills"].has(id))
			if not open.is_empty():
				rival["skills"].append(open[rng.randi_range(0, open.size() - 1)])
	if not grew:
		return
	var node = rival["node"]
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		_refresh_rival(node, false)
		if rival_stage() > before_stage:
			_say("The rival hero evolved into %s!" % node.form_name().capitalize())
			Sfx.play(get_tree(), "warn", -3.0)


func _on_rival_down(v) -> void:
	rival["skip_xp"] = true  # its own death is not EXP for itself
	rival["node"] = null
	rival["falls"] = int(rival["falls"]) + 1
	if bool(rival["duel"]):
		game_over = true
		banner.text = "VICTORY!\nYou defeated the rival hero"
		banner.visible = true
		Sfx.play(get_tree(), "win")
		return
	rival["respawn"] = RIVAL_RESPAWN
	_say("The rival hero fell. It returns in %d seconds, stronger." % int(RIVAL_RESPAWN))


## 20 minutes: the rival heals fully, never respawns again, and the game ends when one of you falls.
func _start_duel(v) -> void:
	rival["duel"] = true
	v.hp = v.max_hp
	banner.text = "FINAL DUEL\n%s" % v.form_name()
	banner.visible = true
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(banner) and not game_over:
			banner.visible = false)
	Sfx.play(get_tree(), "warn", 2.0)
	shake_amp = maxf(shake_amp, 6.0)
	_say("The final duel! Defeat the rival hero to win.")


func spawn_god():
	god_spawned = true
	var v = spawn_boss(2)
	if v == null:
		return null
	v.guard_until = 0.0
	v.force_chase = true
	banner.text = "GOD DESCENDS"
	banner.visible = true
	notice_timer = 0.0
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(banner):
			banner.visible = false)
	Sfx.play(get_tree(), "warn", 2.0)
	shake_amp = maxf(shake_amp, 6.0)
	_say("GOD has descended. It cannot be slowed, burned, rooted, drowned or killed in one blow.")
	return v


func _process(delta: float) -> void:
	_update_chasers(delta)
	_check_god()
	_update_rival(delta)
	if eclipse_left > 0.0:
		eclipse_left -= delta
	eclipse_t = move_toward(eclipse_t, 1.0 if eclipse_left > 0.0 else 0.0, delta * 0.5)
	if eclipse_t <= 0.0:
		blood_moon = false
	if cam != null:
		cam.zoom = Vector2(2.0, 2.0) * view_zoom * (1.0 + punch_amp)
		punch_amp = move_toward(punch_amp, 0.0, delta * 0.18)
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amp if shake_amp > 0.05 else Vector2.ZERO
		shake_amp = move_toward(shake_amp, 0.0, delta * 14.0)
	if not game_over and player != null:
		var near := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.global_position.distance_to(player.global_position) < 380.0:
				near = true
				break
		calm_time = 0.0 if near else calm_time + delta
		_music_tick += delta
		if _music_tick >= 1.0:
			_music_tick = 0.0
			_update_music()
	if not game_over:
		elapsed += delta
		clock += delta
		_update_spawner(delta)
		_update_drowning(delta)
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
	if touch_mode:
		_place_notices()
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
		if remove_armed and Input.is_action_just_pressed("move_mouse") and get_viewport().gui_get_hovered_control() == null:
			try_demolish()
	if Input.is_action_just_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()


func _update_ghost(_delta: float) -> void:
	var tile := tile_of(aim_point())
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
	var grass := [Sprites.tex("grass_1"), Sprites.tex("grass_2"), Sprites.tex("grass_3")]
	var mud_tex := Sprites.tex("mud")
	var tree_tex := [Sprites.tex("tree_1"), Sprites.tex("tree_2")]
	var art := grass[0] != null
	if not art:
		draw_rect(Rect2(0, 0, COLS * TILE, ROWS * TILE), Color("5b8a3c"))
	if not art:  # no grass art: a faint checkerboard (with art, ground_layer.gd draws the meadow near the camera)
		for y in ROWS:
			for x in COLS:
				if (x + y) % 2 == 0:
					draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color(1, 1, 1, 0.04))

	for m in mud:
		var r := Rect2(m.x * TILE, m.y * TILE, TILE, TILE)
		if mud_tex != null:
			continue  # the animated mud layer (mud.gd) draws mud with bubbles and rounded corners
		draw_rect(r, Color("6b4f2f"))
		draw_circle(r.position + Vector2(9, 11), 4.0, Color("55401f"))
		draw_circle(r.position + Vector2(22, 20), 5.0, Color("7d5e38"))

	if art:
		return  # props and tree shadows come from static_layer.gd, near the camera only
	for t in props:
		_draw_prop(t, props[t])

	for t in trees:
		if water.has(t) or buildings.has(t):
			continue
		var c := Vector2(t.x + 0.5, t.y + 0.5) * TILE
		_shadow(c + Vector2(0, 14), 13.0, 4.0, 11.0)
		_shadow(c + Vector2(0, 7), 10.0, 4.5, 18.0)
		var tt: Texture2D = tree_tex[(t.x + t.y) % 2]
		if tt != null:
			continue  # the swaying tree layer (trees.gd) draws the tree itself
		draw_circle(c + Vector2(0, 8), 13.0, Color(0, 0, 0, 0.25))
		draw_rect(Rect2(c.x - 3, c.y, 6, 12), Color("5a3b22"))
		draw_circle(c + Vector2(0, -4), 14.0, Color("2f6b2f"))
		draw_circle(c + Vector2(-4, -8), 6.0, Color("3f8a3f"))


# --- the wandering merchant's shop ---

const SHOP := [
	{"name": "Healing potion", "cost": 25, "desc": "restore all your HP"},
	{"name": "Rage tonic", "cost": 35, "desc": "+40% bite damage for 60 seconds"},
	{"name": "Mystery relic", "cost": 90, "desc": "a random permanent relic"},
	{"name": "EXP pouch", "cost": 60, "desc": "a pile of EXP right now"},
]


func open_shop(merchant) -> void:
	if menu_open:
		return
	menu_kind = "merchant"
	var entries: Array[String] = []
	for i in SHOP.size():
		entries.append("%d. %s  (%d bones)\n    %s" % [i + 1, SHOP[i]["name"], SHOP[i]["cost"], SHOP[i]["desc"]])
	entries.append("%d. Leave" % (SHOP.size() + 1))
	_open_menu("MERCHANT   (you have %d bones)" % bones, entries, func(i): _shop_pick(i, merchant), 1, 560)


func _shop_pick(i: int, merchant) -> void:
	_close_menu()
	if i >= SHOP.size():
		return
	var item: Dictionary = SHOP[i]
	if bones < int(item["cost"]):
		_say("Not enough bones.")
		return
	bones -= int(item["cost"])
	match i:
		0:
			player.hp = player.max_hp
			player.hp_changed.emit(player.hp)
		1:
			player.add_buff("rage", 60.0)
		2:
			var ids: Array = player.TreasureData.RELICS.keys()
			player.add_relic(ids[rng.randi_range(0, ids.size() - 1)])
		3:
			ExpStone.spawn(self, player.global_position, 10 + 4 * player.level)  # a pile of EXP at your feet
	Sfx.play(get_tree(), "coin")
	_say("Bought: %s" % item["name"])


## Free tiles around village wells and inside castle courtyards: where new villagers like to appear.
func _make_town_tiles() -> void:
	_town_tiles.clear()
	var open_set := {}
	for t in open_tiles:
		open_set[t] = true
	for v in layout.get("villages", []):
		for dy in range(-5, 6):
			for dx in range(-6, 7):
				var t: Vector2i = v["center"] + Vector2i(dx, dy)
				if open_set.has(t) and not mud.has(t):
					_town_tiles.append(t)
	for c in layout.get("small", []) + ([layout["big"]] if not layout.get("big", {}).is_empty() else []):
		for t in floors:
			if c["rect"].has_point(t) and open_set.has(t):
				_town_tiles.append(t)

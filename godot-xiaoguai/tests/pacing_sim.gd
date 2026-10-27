extends SceneTree
## A simple bot plays the game in fast forward and reports how fast it levels, evolves and
## whether it survives. It is NOT a good player: it hunts the nearest villager, flees when
## hurt, picks skills from a fixed list and drops a tower now and then. Use it to compare
## pacing between tunings, not as proof of how a person will do.
##
## Run: Godot_console.exe --headless --path . --script tests/pacing_sim.gd -- <line> <minutes> <speed>
##   line: monster line index to pick at level 5 (0 Vampire, 10 Elder Dragon, 22 Demon Lord)
##   minutes: game minutes to simulate (default 30)   speed: time scale (default 10)

const PREFER := ["hide", "fangs", "jaws", "drain", "paws", "nova", "bolt", "step", "roar", "greed"]
const SPECIAL_PREFER := ["ironwill", "overdrive", "secondwind", "cleave", "frenzy", "phoenix", "bloodmoon", "stormcaller", "titan", "gravity", "mastery", "bonehoard"]

var main
var line_idx := 0
var minutes := 30.0
var next_report := 60.0
var last_kills := 0
var last_xp := 0
var next_tower := 30.0
var stage_times := {}
var level_times := {}
var picked_line := false
## "hunt" (default): hold click toward the nearest villager, flee when badly hurt: the "brainless" player.
## "idle": never move, only the auto bite, towers and skills work.
## "smart": hunts, flees earlier, sprints away, rolls when hit, builds more towers and walls.
var mode := "hunt"
var last_hp := 0
var press_release := []
var immortal := false      ## refill HP every frame: measures how fast he levels and how much damage he takes
var damage_taken := 0
var last_damage := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		line_idx = int(args[0])
	if args.size() > 1:
		minutes = float(args[1])
	var speed := 10.0
	if args.size() > 2:
		speed = float(args[2])
	if args.size() > 3:
		immortal = args[3] == "1"
	if args.size() > 4:
		load("res://player.gd").xp_scale = float(args[4])
		print("EXP cost scale x%s" % args[4])
	if args.size() > 5:
		mode = args[5]
		print("bot mode: " + mode)
	if args.size() > 6:
		load("res://player.gd").xp_late_scale = float(args[6])
		print("late-game EXP cost scale x%s" % args[6])
	if args.size() > 7:
		load("res://player.gd").xp_coef = float(args[7])
	if args.size() > 8:
		load("res://player.gd").xp_pow = float(args[8])
	print("EXP curve: coef %.2f, power %.2f, late x%.1f" % [load("res://player.gd").xp_coef, load("res://player.gd").xp_pow, load("res://player.gd").xp_late_scale])
	Engine.max_physics_steps_per_frame = 600
	Engine.time_scale = speed
	main = load("res://main.tscn").instantiate()
	main.pause_on_menu = false
	root.add_child(main)
	for i in 5:
		await physics_frame
	print("pacing sim: line %d (%s), %.0f game minutes at x%.0f" % [line_idx, main.LinesData.title(line_idx), minutes, speed])
	var started := Time.get_ticks_msec()
	while true:
		await physics_frame
		if _step():
			break
	print("real time used: %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _handle_menus() -> void:
	var p = main.player
	var guard := 0
	while main.menu_open and guard < 100:
		guard += 1
		if main.menu_kind == "line" or p.needs_line:
			main.pick_line(line_idx)
			continue
		if main.menu_kind == "special":
			var sp: Array = main.SkillsData.roll_specials(p.specials, main.rng, 3)
			var pick: String = sp[0] if not sp.is_empty() else "overdrive"
			for want in SPECIAL_PREFER:
				if sp.has(want):
					pick = want
					break
			main.pick_special(pick)
			continue
		var options: Array = main.SkillsData.roll(p.skills, main.rng, 3)
		var choice: String = options[0] if not options.is_empty() else "hide"
		for want in PREFER:
			if options.has(want):
				choice = want
				break
		main.pick_skill(choice)


func _step() -> bool:
	var p = main.player
	if main.menu_open:
		_handle_menus()
	if immortal and p.hp < p.max_hp:
		damage_taken += p.max_hp - p.hp
		p.hp = p.max_hp
		main.game_over = false
	if p.hp <= 0:
		print("DEAD at game time %.1f min (level %d, stage %d, kills %d)" % [main.elapsed / 60.0, p.level, p.stage, main.kills])
		return true
	var t: float = main.elapsed
	if not level_times.has(p.level):
		level_times[p.level] = t
	if not stage_times.has(p.stage):
		stage_times[p.stage] = t
	# move: hunt the nearest villager, flee when hurt and crowded
	var foes: Array = get_nodes_in_group("enemies")
	var nearest = null
	var best := INF
	var close := 0
	var centroid := Vector2.ZERO
	for e in foes:
		var d: float = e.global_position.distance_to(p.global_position)
		if d < best:
			best = d
			nearest = e
		if d < 140.0:
			close += 1
			centroid += e.global_position
	for a in press_release:
		Input.action_release(a)
	press_release.clear()
	var flee_at := 0.5 if mode == "smart" else 0.35
	var fleeing: bool = close > 0 and p.hp < p.max_hp * flee_at and (mode == "smart" or close >= 1)
	if mode == "idle":
		p.has_target = false
	elif fleeing:
		centroid /= close
		p.move_target = p.global_position + (p.global_position - centroid).normalized() * 200.0
		p.has_target = true
		if mode == "smart":
			Input.action_press("sprint")
			press_release.append("sprint")
	elif nearest != null:
		p.move_target = nearest.global_position
		p.has_target = true
	if mode == "smart" and p.hp < last_hp and p.roll_cd == 0.0:
		Input.action_press("dodge")  # roll when hit
		press_release.append("dodge")
	last_hp = p.hp
	# now and then, put a tower (or in smart mode also a wall) down beside us
	var every := 10.0 if mode == "smart" else 20.0
	if t >= next_tower and main.bones >= 15:
		next_tower = t + every
		var tile: Vector2i = main.tile_of(p.global_position + Vector2(70, 0))
		main.build_item = "tower"
		if not main.place_at(tile, "tower"):
			main.place_at(main.tile_of(p.global_position + Vector2(-70, 0)), "tower")
		if mode == "smart":
			main.build_item = "wall"
			for off in [Vector2(70, 40), Vector2(70, -40), Vector2(40, 70)]:
				main.place_at(main.tile_of(p.global_position + off), "wall")
	if t >= next_report:
		next_report += 60.0
		var kills_now: int = main.kills
		var xp_now: int = p.xp
		print("min %2d | lvl %2d stage %2d | max hp %3d, damage taken +%4d | villagers %3d (cap %3d) | kills +%3d (%4d) | xp +%5d | bones %4d | towers %d | %s" % [
			int(t / 60.0), p.level, p.stage, p.max_hp, damage_taken - last_damage, foes.size(), main.target_population(),
			kills_now - last_kills, kills_now, xp_now - last_xp, main.bones,
			get_nodes_in_group("towers").size(), p.stages[p.stage]["name"]])
		last_kills = kills_now
		last_xp = xp_now
		last_damage = damage_taken
	if t >= minutes * 60.0:
		print("END at %.1f game minutes: level %d, stage %d (%s), kills %d" % [t / 60.0, p.level, p.stage, p.stages[p.stage]["name"], main.kills])
		var marks := []
		for s in stage_times.keys():
			marks.append("form %d at %.1f min" % [s, float(stage_times[s]) / 60.0])
		print("evolutions: " + ", ".join(marks))
		var lv := []
		for l in [10, 25, 50, 75, 100]:
			lv.append("level %d at %s" % [l, ("%.1f min" % (float(level_times[l]) / 60.0)) if level_times.has(l) else "never"])
		print("milestones: " + ", ".join(lv))
		return true
	return false

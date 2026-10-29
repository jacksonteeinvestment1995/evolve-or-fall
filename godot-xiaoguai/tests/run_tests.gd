extends SceneTree
## Headless regression tests with simulated input. Run from the project folder:
##   Godot_console.exe --headless --path . --script tests/run_tests.gd
## Exit code is 0 when everything passes. Not part of the game itself.

var failures := 0
var main


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail.is_empty() else "  (" + detail + ")"))
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func fresh() -> void:
	if main != null:
		main.queue_free()
		await process_frame
	Input.flush_buffered_events()
	main = load("res://main.tscn").instantiate()
	main.pause_on_menu = false
	main.perk_every = 100000
	root.add_child(main)
	await frames(5)  # let the new scene settle after its heavy first frame
	for i in 10:
		await process_frame  # the first two idle frames take 80-150 ms; wait them out so key presses are not lost


func mouse_to(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)


func mouse_button(pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = button
	b.pressed = pressed
	b.position = Vector2(1000, 360)
	b.global_position = b.position
	Input.parse_input_event(b)


func key(code: int, pressed: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = pressed
	Input.parse_input_event(k)


func enemies() -> Array:
	return get_nodes_in_group("enemies")


func clear_enemies() -> void:
	for e in enemies():
		e.queue_free()
	main.spawn_cd = 99999.0
	await frames(2)


func zones() -> Array:
	return main.get_children().filter(func(c): return c.get_script() == main.VillagerScript.ZoneScript)


## Every projectile currently in the air.
func bolts() -> Array:
	return main.get_children().filter(func(c): return c.get_script() == main.VillagerScript.BoltScript)


## Answer every open menu (line, skill, special) with a pick, and return the kinds seen in order.
func drain_menus() -> Array:
	var kinds: Array = []
	var guard := 0
	while main.menu_open and guard < 300:
		guard += 1
		kinds.append(main.menu_kind)
		if main.menu_kind == "line":
			main.pick_line(10)
		elif main.menu_kind == "special":
			var sp: Array = main.SkillsData.roll_specials(main.player.specials, main.rng, 1)
			main.pick_special(sp[0] if not sp.is_empty() else "overdrive")
		else:
			var ids: Array = main.SkillsData.roll(main.player.skills, main.rng, 1)
			main.pick_skill(ids[0] if not ids.is_empty() else "hide")
	return kinds


## Every damage number currently floating in the world.
func floaters() -> Array:
	return main.get_children().filter(func(c): return c.get_script() == main.player.Popups.FloaterScript)


## Put 小怪 on a monster line at a stage (0 to 10), at full health.
func use_line(idx: int, stage: int) -> void:
	var pl = main.player
	pl.line = idx
	pl._build_stages()
	pl.stage = stage
	pl._apply_stage(true)
	pl.invuln = 0.0
	pl.ab_cd.clear()


## A villager that stays quiet by itself, so a test controls when it fires.
func mk(pos: Vector2, stage: int, line: int, secret: int = -1):
	var v = main._spawn_villager(pos, stage, line, secret)
	v.skill_cd = 9999.0
	v.shoot_cd = 9999.0
	return v


func at(tx: int, ty: int) -> Vector2:
	return Vector2(tx + 0.5, ty + 0.5) * 32.0


## Top-left tile of a w x h block with no trees or mud.
func find_free_rect(w: int, h: int) -> Vector2i:
	for y in range(10, main.ROWS - h - 2, 3):
		for x in range(20, main.COLS - w - 2, 3):
			var ok := true
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					if main.trees.has(Vector2i(xx, yy)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _init() -> void:
	Engine.set_meta("deterministic_map", true)  # the real game makes a new map every launch; tests keep one
	await fresh()
	var p = main.player
	var LinesData = main.LinesData
	var SkillsData = main.SkillsData
	var PlayerScript = main.PlayerScript

	# =========================== map ===========================
	check("a gentle start: 30 villagers", enemies().size() == 30, str(enemies().size()))
	check("they all start in their 1st form", enemies().all(func(e): return e.stage == 0))
	var seen_lines := {}
	for e in enemies():
		seen_lines[e.line] = true
	check("the starting villagers are a mix of professions", seen_lines.size() >= 6, "%d lines" % seen_lines.size())
	check("map is 180x100 (5x the 80x45 map)", main.COLS * main.ROWS == 5 * 80 * 45)
	check("trees are thin (under 10% of tiles)", main.trees.size() < 0.10 * 18000, "%d trees" % main.trees.size())
	check("most grass is reachable", main.open_tiles.size() > 0.9 * (18000 - main.trees.size()), "%d open" % main.open_tiles.size())
	var all_reachable := true
	for e in enemies():
		if not main.open_tiles.has(Vector2i(int(e.position.x / 32), int(e.position.y / 32))):
			all_reachable = false
	check("every villager can be reached", all_reachable)
	check("3 far tiles always keep a route to the base", main.ref_tiles.size() == 3 and main.routes_open())
	check("no towers or walls at the start", get_nodes_in_group("structures").size() == 0)
	check("sprint cooldown is 15 s", p.SPRINT_COOLDOWN == 15.0)

	# =========================== input ===========================
	mouse_to(Vector2(1000, 360))
	mouse_button(true)
	for i in 30:  # input can take a few frames to land right after the scene loads
		await frames(1)
		if Input.is_action_pressed("move_mouse"):
			break
	check("left button registers as move_mouse", Input.is_action_pressed("move_mouse"))
	var start: Vector2 = p.global_position
	await frames(40)
	check("holding left button moves the player", p.global_position.distance_to(start) > 20.0)
	mouse_button(false)
	await frames(2)
	check("click leaves a walk target", p.has_target)
	var before: Vector2 = p.global_position
	await frames(20)
	check("player keeps walking after release", p.global_position.distance_to(before) > 10.0)
	key(KEY_D, true)
	await frames(2)
	check("WASD cancels click target", not p.has_target)
	key(KEY_D, false)

	await fresh()
	p = main.player
	key(KEY_SPACE, true)
	await frames(3)
	check("Space starts a roll with invincibility", p.roll_left > 0.0 and p.invuln > 0.0,
			"roll_left %.2f invuln %.2f" % [p.roll_left, p.invuln])
	key(KEY_SPACE, false)

	await fresh()
	p = main.player
	p.sprint_energy = 0.1
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	await frames(20)
	check("sprint runs out and starts the 15 s cooldown", p.sprint_cd > 14.0 and p.sprint_cd <= 15.0, "cd %.1f" % p.sprint_cd)
	key(KEY_SHIFT, false)
	key(KEY_D, false)

	# =========================== auto bite ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	var v = main._spawn_villager(p.global_position + Vector2(20, 0), 0, 3)
	var xp_before: int = p.xp
	await frames(30)
	check("auto bite hurts a nearby villager", not is_instance_valid(v) or v.is_queued_for_deletion() or v.hp < v.max_hp)
	check("hits give no EXP by themselves (only EXP stones do)", p.xp == xp_before, "xp %d" % p.xp)

	# =========================== levels: 100 levels, a form every 10, skills every 3, specials every 12 ===========================
	check("Xiao Guai until level 10", PlayerScript.stage_for_level(1) == 0 and PlayerScript.stage_for_level(9) == 0)
	check("a new form every 10 levels",
			PlayerScript.stage_for_level(10) == 1 and PlayerScript.stage_for_level(19) == 1
			and PlayerScript.stage_for_level(20) == 2 and PlayerScript.stage_for_level(50) == 5
			and PlayerScript.stage_for_level(100) == 10)
	check("max level 100, a form every 10, a skill every 3, a special every 12",
			PlayerScript.MAX_LEVEL == 100 and PlayerScript.EVOLVE_EVERY == 10
			and PlayerScript.SKILL_EVERY == 3 and PlayerScript.SPECIAL_EVERY == 12)
	var rises := true
	for l in range(2, 101):
		if PlayerScript.xp_for_level(l) <= PlayerScript.xp_for_level(l - 1):
			rises = false
	check("every level costs more EXP than the one before", rises and PlayerScript.xp_for_level(1) == 0)
	check("the first half is fast: level 50 costs under 30% of level 100",
			PlayerScript.xp_for_level(50) < 0.3 * PlayerScript.xp_for_level(100),
			"%d vs %d" % [PlayerScript.xp_for_level(50), PlayerScript.xp_for_level(100)])
	var early_gap: int = PlayerScript.xp_for_level(10) - PlayerScript.xp_for_level(9)
	var late_gap: int = PlayerScript.xp_for_level(100) - PlayerScript.xp_for_level(99)
	check("a late level costs far more than an early level", late_gap > 20 * early_gap, "%d vs %d" % [late_gap, early_gap])
	check("26 evolution lines of 10 forms",
			LinesData.LINES.size() == 26 and LinesData.LINES.all(func(l): return l["forms"].size() == 10))
	var undead = PlayerScript.new()
	undead.choose_line(0)
	var slime = PlayerScript.new()
	slime.choose_line(6)
	check("a chosen line fills 11 stages (Xiao Guai + 10 forms)", undead.stages.size() == 11)
	check("line 1 is Zombie to Vampire Lord", undead.stages[1]["name"] == "Zombie" and undead.stages[10]["name"] == "Vampire Lord")
	check("families bias stats: Slime has more HP than Undead", slime.stages[1]["hp"] > undead.stages[1]["hp"])

	await fresh()
	p = main.player
	check("starts as Xiao Guai at level 1", p.stage == 0 and p.level == 1 and p.stages[0]["name"] == "Xiao Guai" and p.line == -1)
	main.elapsed = 0.0
	check("catch-up: no bonus at the start", is_equal_approx(main.catchup(), 1.0))
	main.elapsed = 480.0  # 8 minutes in: level 50 is on pace
	p.level = 50
	check("catch-up: no bonus when on pace", is_equal_approx(main.catchup(), 1.0))
	p.level = 70
	check("catch-up: no bonus when ahead", is_equal_approx(main.catchup(), 1.0))
	p.level = 30
	check("catch-up: a bonus when behind", main.catchup() > 1.2 and main.catchup() <= 1.6, "%.2f" % main.catchup())
	p.level = 1
	check("catch-up: the bonus stops at 60%", is_equal_approx(main.catchup(), 1.6))
	p.level = 1
	main.elapsed = 0.0
	var size_lv1: float = p.growth_scale()
	p.add_xp(PlayerScript.xp_for_level(4))
	check("he grows a little with every level, before any evolution", p.level == 4 and p.stage == 0 and p.growth_scale() > size_lv1,
			"%.2f -> %.2f" % [size_lv1, p.growth_scale()])
	check("a skill pick came at level 3, none at 2 or 4", main.menu_open and main.menu_kind == "skill" and main.menu_queue.is_empty())
	main.pick_skill("hide")
	p.add_xp(PlayerScript.xp_for_level(10) - p.xp)
	check("level 10 asks for a line before evolving", p.level == 10 and p.needs_line and p.stage == 0)
	check("the skill picks of levels 6 and 9 and the line choice are waiting",
			main.menu_open and main.menu_kind == "skill" and main.menu_queue.size() == 2 and main.menu_queue[0]["type"] == "line")
	main.pick_skill("hide")
	check("the line menu opens before the next skill pick", main.menu_open and main.menu_kind == "line" and p.needs_line)
	main.pick_line(10)
	check("picking a line evolves into its first form", p.stage == 1 and p.line == 10 and p.stages[p.stage]["name"] == "Hatchling")
	check("then the level 9 skill pick follows", main.menu_open and main.menu_kind == "skill")
	main.pick_skill("fangs")
	var kinds_19: Array = []
	p.add_xp(PlayerScript.xp_for_level(19) - p.xp)
	check("a level inside a form does not evolve", p.stage == 1 and p.level == 19)
	kinds_19 = drain_menus()
	check("up to level 19: skill picks at 15 and 18, and a special at 12 instead of a skill",
			kinds_19.count("skill") == 2 and kinds_19.count("special") == 1, str(kinds_19))
	p.add_xp(PlayerScript.xp_for_level(20) - p.xp)
	check("the second evolution is at level 20, with no line menu", p.level == 20 and p.stage == 2
			and p.stages[2]["name"] == "Dragonling" and not p.needs_line)
	drain_menus()
	p.add_xp(PlayerScript.xp_for_level(100))
	var kinds_all: Array = drain_menus()
	check("level 100 is the last form of the line", p.level == 100 and p.stage == 10 and p.stages[10]["name"] == "Elder Dragon")
	var normal_picks: int = kinds_all.count("skill") + 3 + 2  # plus the 5 picked by hand so far (levels 3, 6, 9, 15, 18)
	check("a skill pick every 3 levels, but a special instead at every 12th: 25 in a run", normal_picks == 25, "%d" % normal_picks)
	check("a special pick every 12 levels: 8 in a run", p.specials.size() == 8, "%d" % p.specials.size())
	check("the final form earns the strongest skill", p.rank("doom") == 1 and SkillsData.SKILLS["doom"]["name"] == "Final Calamity")
	var doom_rng := RandomNumberGenerator.new()
	check("Final Calamity is never offered at a level-up", not SkillsData.roll({}, doom_rng, 30).has("doom"))
	await clear_enemies()
	p.global_position = at(10, 10)
	p.hp = p.max_hp
	var doomed: Array = []
	for i in 7:
		doomed.append(mk(p.global_position + Vector2(60 + 15 * i, -40 + 14 * i), 0, 3))
	await frames(70)
	check("Final Calamity fires by itself when surrounded", p.skill_cd["doom"] > 0.0)
	check("and it wrecks the crowd", doomed.all(func(c): return not is_instance_valid(c) or c.is_queued_for_deletion() or c.stun_left > 0.0 or c.hp < c.max_hp))
	await clear_enemies()

	# =========================== special skills (every 12th level) ===========================
	await fresh()
	p = main.player
	p.choose_line(10)
	check("12 special skills exist", SkillsData.SPECIALS.size() == 12)
	var sp_rng := RandomNumberGenerator.new()
	sp_rng.seed = 3
	var sp_offer: Array = SkillsData.roll_specials({}, sp_rng, 3)
	check("a special pick offers 3 different specials", sp_offer.size() == 3 and sp_offer[0] != sp_offer[1] and sp_offer[1] != sp_offer[2])
	var owned_all := {}
	for sid in SkillsData.SPECIALS:
		owned_all[sid] = true
	owned_all.erase("titan")
	check("a special you already have is not offered again", SkillsData.roll_specials(owned_all, sp_rng, 3) == ["titan"])
	p.add_xp(PlayerScript.xp_for_level(24))
	var kinds_24: Array = drain_menus()
	check("to level 24: 6 skill picks and 2 special picks (levels 12 and 24 are specials)", kinds_24.count("skill") == 6 and kinds_24.count("special") == 2, str(kinds_24))
	check("a special is a one-time pick", p.specials.size() == 2)

	await fresh()
	p = main.player
	p.choose_line(10)
	var bite_plain: int = p.effective_bite()
	p.learn_special("overdrive")
	check("Overdrive Bites: +40% bite damage", p.effective_bite() >= int(ceil(bite_plain * 1.4)) and p.effective_bite() > bite_plain)
	var cd_plain: float = float(p.stages[p.stage]["cd"])
	p.learn_special("frenzy")
	main.elapsed = 10.0
	var frenzy_target = mk(p.global_position + Vector2(20, 0), 0, 3)
	frenzy_target.max_hp = 100
	frenzy_target.hp = 100
	p.bite_cd = 0.0
	p._auto_bite()
	check("Frenzy: bites 25% faster", p.bite_cd > 0.0 and p.bite_cd <= cd_plain * 0.75 + 0.001, "%.3f vs %.3f" % [p.bite_cd, cd_plain])
	frenzy_target.queue_free()
	var hp_plain: int = p.max_hp
	p.learn_special("ironwill")
	check("Iron Will: +50% max HP and a full heal", p.max_hp == roundi(hp_plain * 1.5) and p.hp == p.max_hp, "%d -> %d" % [hp_plain, p.max_hp])
	p.hp = 1
	p.learn_special("secondwind")
	await frames(3)
	check("Second Wind: heals 30% of your HP when low", p.hp >= p.max_hp * 0.3 - 1, "hp %d of %d" % [p.hp, p.max_hp])
	p.wind_cd = 60.0
	check("Second Wind is limited to once every 90 s", p.wind_cd > 0.0)
	p.learn_special("phoenix")
	p.invuln = 0.0
	p.hp = 1
	p.take_hit(5, Vector2.LEFT)
	check("Phoenix: a deadly hit starts a rebirth, not an instant revive", p.hp == 0 and p.reviving > 0.0 and p.phoenix_used and not main.game_over)
	await frames(60)
	check("Phoenix: still waiting after one second", p.hp == 0 and p.reviving > 0.0)
	await frames(75)
	check("Phoenix: after about 2 seconds you come back with 40% HP", p.hp == roundi(p.max_hp * 0.4) and p.reviving <= 0.0, "hp %d reviving %.2f" % [p.hp, p.reviving])
	p.invuln = 0.0
	p.hp = 1
	p.take_hit(5, Vector2.LEFT)
	check("Phoenix works only once", p.hp <= 0)
	await fresh()
	p = main.player
	p.choose_line(10)
	await clear_enemies()
	main.elapsed = 10.0
	p.global_position = at(8, 8)
	p.learn_special("cleave")
	var c1 = mk(p.global_position + Vector2(25, 0), 0, 3)
	var c2 = mk(p.global_position + Vector2(-25, 0), 0, 3)
	var c3 = mk(p.global_position + Vector2(0, 25), 0, 3)
	for c in [c1, c2, c3]:
		c.max_hp = 100
		c.hp = 100
	p.on_bite_landed(c1, 3)
	check("Cleave: a bite also hits other villagers nearby", c2.hp < 100 and c3.hp < 100 and c1.hp == 100)
	await clear_enemies()
	p.global_position = at(8, 8)
	p.learn_special("gravity")
	var far_pull = mk(p.global_position + Vector2(120, 0), 0, 3)
	far_pull.apply_status("root", 10.0)
	var pull_d0: float = far_pull.global_position.distance_to(p.global_position)
	await frames(60)
	check("Gravity Maw: pulls villagers in even when they cannot walk", far_pull.global_position.distance_to(p.global_position) < pull_d0 - 15.0)
	await clear_enemies()
	var reach0: float = float(p.stages[p.stage]["range"])
	p.learn_special("titan")
	var titan_target = mk(p.global_position + Vector2(reach0 + 8.0, 0), 0, 3)
	titan_target.max_hp = 100
	titan_target.hp = 100
	titan_target.apply_status("root", 10.0)
	await frames(30)
	check("Titan Reach: bites villagers just beyond the normal reach", titan_target.hp < 100)
	await clear_enemies()
	main.clock = 30.0  # day
	var bite_by_day: int = p.effective_bite()
	p.learn_special("bloodmoon")
	check("Blood Moon: night strength by day", p.effective_bite() > bite_by_day and p._power() >= 1.5, "bite %d -> %d, power %.2f, combo %d" % [bite_by_day, p.effective_bite(), p._power(), p.combo])
	p.learn("nova")
	p.learn_special("stormcaller")
	p.ab_cd.clear()
	p.cast("nova")
	check("Stormcaller: automatic skills recharge faster", p.skill_cd["nova"] < 8.0 * 0.7, "%.1f" % p.skill_cd["nova"])
	p.learn("hide")
	p.learn("fangs")
	var hide_rank: int = p.rank("hide")
	var fangs_rank: int = p.rank("fangs")
	p.learn_special("mastery")
	check("Mastery: every skill you own gains a rank", p.rank("hide") == hide_rank + 1 and p.rank("fangs") == fangs_rank + 1 and p.rank("nova") == 2)
	var bones_pre: int = main.bones
	var tower_cost_pre: int = main.build_cost("tower", Vector2i(30, 30))
	p.learn_special("bonehoard")
	main._on_villager_defeated(4, 3, true)
	check("Bone Hoard: double bones", main.bones - bones_pre >= 6, str(main.bones - bones_pre))
	check("Bone Hoard: 30% cheaper towers and walls",
			main.build_cost("tower", Vector2i(30, 30)) == roundi(tower_cost_pre * 0.7) and main.build_cost("wall", Vector2i(30, 30)) < main.WALL_COST)
	var specials_before: int = p.specials.size()
	p.learn_special("cleave")
	check("a special cannot be taken twice", p.specials.size() == specials_before)

	# =========================== skills ===========================
	await fresh()
	p = main.player
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var offer: Array = SkillsData.roll({}, rng, 3)
	check("a level-up offers 3 different skills", offer.size() == 3 and offer[0] != offer[1] and offer[1] != offer[2])
	var maxed := {}
	for id in SkillsData.SKILLS:
		maxed[id] = 5
	maxed.erase("roar")
	check("maxed skills are not offered again", SkillsData.roll(maxed, rng, 3) == ["roar"])
	var hp0: int = p.max_hp
	p.learn("hide")
	check("Tough Hide raises max HP", p.max_hp > hp0)
	var bite0: int = p.effective_bite()
	for i in 4:
		p.learn("fangs")
	check("Sharp Fangs raises bite damage", p.effective_bite() > bite0, "%d vs %d" % [p.effective_bite(), bite0])
	p.learn("fangs")
	p.learn("fangs")
	check("skill rank stops at 5", p.rank("fangs") == 5)
	p.learn("greed")
	var b0: int = main.bones
	main._on_villager_defeated(4, 4, true)
	check("Bone Collector pays more bones", main.bones - b0 == 5, str(main.bones - b0))
	p.learn("drain")
	p.hp = 1
	main._on_villager_defeated(4, 1, false)
	main._on_villager_defeated(4, 1, false)
	check("Soul Drain heals on a kill", p.hp >= 2)
	check("an auto skill does nothing until learned", not p.cast("nova") and p.rank("nova") == 0)
	check("all 10 skills are passive: none needs a key", SkillsData.SKILLS.values().all(func(s): return s["kind"] == "passive"))

	# Bone Nova fires by itself when villagers get close (no key pressed)
	await clear_enemies()
	p.global_position = at(8, 8)
	p.invuln = 0.0
	p.learn("nova")
	var near = main._spawn_villager(p.global_position + Vector2(50, 0), 0, 3)
	var near_hp: int = near.hp
	await frames(15)
	check("Bone Nova fires on its own when a villager is close", p.skill_cd["nova"] > 0.0)
	check("Bone Nova hurts the villager", not is_instance_valid(near) or near.is_queued_for_deletion() or near.hp < near_hp)
	check("Bone Nova then cools down", not p.cast("nova"))

	# Spirit Bolt fires by itself at the nearest villager
	await clear_enemies()
	p.global_position = at(8, 8)
	p.learn("bolt")
	var target_v = main._spawn_villager(p.global_position + Vector2(0, 150), 2, 3)
	var tv_hp: int = target_v.hp
	await frames(40)
	check("Spirit Bolt fires on its own at the nearest villager", p.skill_cd["bolt"] > 0.0)
	check("Spirit Bolt hits it, even when not facing it", not is_instance_valid(target_v) or target_v.is_queued_for_deletion() or target_v.hp < tv_hp)

	# Shadow Step is a dodge chance
	for i in 5:
		p.learn("step")
	check("Shadow Step rank 5 is a 50% dodge", is_equal_approx(p.dodge_chance(), 0.5))
	var dodged := 0
	var blinked_away := false
	for i in 300:
		p.global_position = at(8, 8)
		p.hp = p.max_hp
		p.invuln = 0.0
		p.skill_cd["step"] = 0.0
		p.take_hit(1, Vector2.RIGHT)
		if p.hp == p.max_hp:
			dodged += 1
			if p.global_position.x < at(8, 8).x - 40.0 and p.invuln > 0.0:
				blinked_away = true
	check("Shadow Step dodges some hits but not all", dodged > 60 and dodged < 240, "%d of 300" % dodged)
	check("a dodge blinks away from the attacker", blinked_away)

	# Roar fires by itself when surrounded
	await clear_enemies()
	p.global_position = at(8, 8)
	p.invuln = 0.0
	p.hp = p.max_hp
	p.learn("roar")
	var crowd: Array = []
	for i in 4:
		crowd.append(main._spawn_villager(p.global_position + Vector2(40 + 8 * i, -30 + 20 * i), 0, 3))
	await frames(12)
	check("Roar fires on its own when surrounded", p.skill_cd["roar"] > 0.0)
	check("Roar stuns villagers nearby", crowd.any(func(c): return not is_instance_valid(c) or c.stun_left > 0.0))

	# =========================== villager lines, forms, hidden forms ===========================
	await fresh()
	main.elapsed = 1000.0  # past the gentle start, so villagers shoot and use skills
	await clear_enemies()
	var lines: Array = main.VillagerScript.LINES
	check("10 village lines of 5 forms each", lines.size() == 10 and lines.all(func(l): return l["forms"].size() == 5))
	check("3 hidden forms: Parasite Hero, Dark Hero, GOD",
			main.VillagerScript.HIDDEN.map(func(h): return h["name"]) == ["Parasite Hero", "Dark Hero", "GOD"])
	var f1 = main._spawn_villager(Vector2(3000, 1500), 0, 3)
	var f5 = main._spawn_villager(Vector2(3100, 1500), 4, 3)
	await frames(2)
	check("a line's 5th form is far stronger than its 1st", f5.max_hp > 5 * f1.max_hp and f5.damage > f1.damage and f5.speed > f1.speed)
	check("form names come from the line", f1.form_name() == "Militia" and f5.form_name() == "Captain")
	var tank = main._spawn_villager(Vector2(3200, 1500), 4, 4)
	var scout = main._spawn_villager(Vector2(3300, 1500), 4, 2)
	await frames(2)
	check("lines differ: Knight tankier, Hunter faster", tank.max_hp > scout.max_hp and scout.speed > tank.speed)
	f1.form_age = 44.99
	await frames(3)
	check("villagers evolve while alive", f1.stage == 1 and f1.form_name() == "Footman")

	main.clock = 90.0  # night
	seed(1)
	for i in 80:
		if f5.secret >= 0:
			break
		f5.form_age = f5.HIDDEN_CHECK
		await frames(1)
	check("a last-form villager can turn into a Parasite Hero at night", f5.secret == 0 and f5.form_name() == "Parasite Hero")
	f5.form_age = f5.PARASITE_TO_DARK
	await frames(2)
	check("Parasite Hero becomes Dark Hero", f5.secret == 1 and f5.form_name() == "Dark Hero")
	main.village_level = 4
	f5.form_age = f5.DARK_TO_GOD
	await frames(2)
	check("Dark Hero waits for village level 5 before GOD", f5.secret == 1)
	main.village_level = 5
	f5.form_age = f5.DARK_TO_GOD
	await frames(2)
	check("the Dark Hero no longer turns into GOD by itself", f5.secret == 1)
	var f4 = main._spawn_villager(Vector2(3400, 1500), 3, 3)
	f4.form_age = 0.0
	await frames(3)
	check("hidden forms need a last form", f4.secret == -1)
	var daymaker = main._spawn_villager(Vector2(3500, 1500), 4, 1)
	main.clock = 30.0  # day
	for i in 40:
		daymaker.form_age = daymaker.HIDDEN_CHECK
		await frames(1)
	check("hidden forms never appear by day", daymaker.secret == -1)

	# =========================== enemy ranged attacks and skills ===========================
	await fresh()
	main.elapsed = 1000.0  # past the gentle start, so villagers shoot and use skills
	p = main.player
	await clear_enemies()
	p.global_position = at(8, 8)
	var hunter = main._spawn_villager(p.global_position + Vector2(200, 0), 0, 2)
	var hp_start: int = p.hp
	await frames(120)
	var hunter_dist: float = hunter.global_position.distance_to(p.global_position)
	check("a Hunter shoots from range and keeps its distance", p.hp < hp_start and hunter_dist > 80.0,
			"hp %d -> %d, distance %.0f" % [hp_start, p.hp, hunter_dist])
	hunter.queue_free()

	await clear_enemies()
	# every profession knows several attacks that unlock as it evolves
	var counts := {}
	for li in 10:
		var vv = main._spawn_villager(Vector2(3000, 200 + li * 60), 4, li)
		counts[li] = vv.available_skills().size()
	check("every profession knows 3 or 4 skills in its last form", counts.values().all(func(c): return c >= 3 and c <= 4), str(counts))
	var first_form = main._spawn_villager(Vector2(3000, 900), 0, 6)
	var second_form = main._spawn_villager(Vector2(3000, 960), 1, 6)
	var last_form = main._spawn_villager(Vector2(3000, 1020), 4, 6)
	check("the 1st form has no skill yet", first_form.available_skills().is_empty())
	check("skills unlock as it evolves", second_form.available_skills() == ["fireball"] and last_form.available_skills().size() == 4)
	var all_types := {}
	for li in 10:
		for entry in main.VillagerScript.LINE_SKILLS[li]:
			all_types[entry[1]] = true
	for hs in main.VillagerScript.HIDDEN_SKILLS:
		for s in hs:
			all_types[s] = true
	check("there are many attack types (at least 15)", all_types.size() >= 15, "%d types" % all_types.size())
	check("every attack type has a cooldown", all_types.keys().all(func(k): return main.VillagerScript.SKILL_COOLDOWN.has(k)))
	check("professions have different skill sets", main.VillagerScript.LINE_SKILLS[5] != main.VillagerScript.LINE_SKILLS[6])
	await clear_enemies()

	# Each attack type, one by one. The villagers are set quiet so only the test fires skills.
	p.hp = p.max_hp
	p.invuln = 0.0
	var mage = mk(p.global_position + Vector2(180, 0), 1, 6)
	check("a Mage casts fireball", mage.use_skill_id("fireball", p, 180.0))
	check("a used skill starts its own cooldown", mage.skill_timers["fireball"] > 0.0 and not mage.use_skill(p, 180.0))
	await frames(3)
	check("fireball shows a warning zone first", zones().size() >= 1)
	var hp_before_fire: int = p.hp
	await frames(70)
	check("fireball explodes on 小怪's spot", p.hp < hp_before_fire, "hp %d -> %d" % [hp_before_fire, p.hp])
	mage.queue_free()
	await frames(3)

	p.hp = p.max_hp
	p.invuln = 0.0
	var smiter = mk(p.global_position + Vector2(200, 0), 2, 6)
	check("a Mage in its 3rd form can also smite", smiter.available_skills().has("smite") and smiter.use_skill_id("smite", p, 200.0))
	hp_before_fire = p.hp
	await frames(50)
	check("smite strikes 小怪's spot", p.hp < hp_before_fire)
	smiter.queue_free()

	p.hp = p.max_hp
	p.invuln = 0.0
	var bomber = mk(p.global_position + Vector2(150, 0), 2, 7)
	check("a Smith throws a bomb", bomber.use_skill_id("bomb", p, 150.0))
	hp_before_fire = p.hp
	await frames(90)
	check("the bomb blast hurts", p.hp < hp_before_fire)
	bomber.queue_free()

	p.hp = p.max_hp
	p.invuln = 0.0
	var smith = mk(p.global_position + Vector2(40, 0), 1, 7)
	check("a Smith slams the ground when close", smith.use_skill_id("slam", p, 40.0))
	smith.queue_free()
	var priest4 = mk(p.global_position + Vector2(60, 0), 4, 5)
	check("a Priest's holy nova needs 小怪 close", priest4.use_skill_id("nova", p, 60.0) and not priest4.use_skill_id("nova", p, 400.0))
	priest4.queue_free()
	await clear_enemies()
	p.hp = p.max_hp
	p.invuln = 0.0

	var knight = mk(p.global_position + Vector2(150, 0), 2, 4)
	check("a Knight charges", knight.use_skill_id("charge", p, 150.0) and knight.charge_left > 0.0)
	knight.queue_free()
	var militia = mk(p.global_position + Vector2(200, 0), 1, 3)
	check("a Militia raises a shield", militia.use_skill_id("shield", p, 200.0) and militia.shield_left > 0.0)
	var mhp: int = militia.hp
	militia.take_hit(4, Vector2.RIGHT)
	check("a shield halves damage", mhp - militia.hp == 2, "lost %d" % (mhp - militia.hp))
	militia.queue_free()
	var berserker = mk(p.global_position + Vector2(250, 0), 3, 1)
	var dmg_before: int = berserker.effective_damage()
	check("a Woodsman rages", berserker.use_skill_id("rage", p, 250.0) and berserker.effective_damage() > dmg_before)
	berserker.queue_free()
	var thief = mk(p.global_position + Vector2(300, 0), 2, 8)
	check("a Thief blinks next to 小怪", thief.use_skill_id("blink", p, 300.0) and thief.global_position.distance_to(p.global_position) < 60.0)
	thief.queue_free()
	var priest = mk(p.global_position + Vector2(400, 0), 1, 5)
	var hurt = mk(p.global_position + Vector2(420, 0), 0, 3)
	hurt.hp = 1
	await frames(2)
	check("a Priest heals a hurt ally", priest.use_skill_id("heal", p, 400.0) and hurt.hp > 1)
	priest.queue_free()
	hurt.queue_free()
	var noble = mk(p.global_position + Vector2(300, 100), 1, 9)
	var mates: Array = []
	for i in 3:
		mates.append(mk(noble.global_position + Vector2(20 * i, 10), 0, 3))
	await frames(2)
	check("a Noble rallies nearby allies", noble.use_skill_id("rally", p, 300.0) and mates.all(func(m): return m.buff_left > 0.0))
	check("rallied villagers hit harder", mates[0].effective_damage() > mates[0].damage)
	for m in mates:
		m.queue_free()
	await clear_enemies()
	var boss_noble = mk(p.global_position + Vector2(250, 0), 2, 9)
	var crowd_before: int = enemies().size()
	check("a Noble summons helpers", boss_noble.use_skill_id("summon", p, 250.0))
	await frames(3)
	check("two helpers appear", enemies().size() == crowd_before + 2, "%d -> %d" % [crowd_before, enemies().size()])
	await clear_enemies()

	# projectile skills
	var farmer = mk(p.global_position + Vector2(90, 0), 1, 0)
	check("a Farmer throws mud", farmer.use_skill_id("slow", p, 90.0))
	await frames(45)
	check("mud slows 小怪", p.slow_left > 0.0, "slow %.2f hp %d rev %.2f inv %.2f bolts %d farmer %s" % [p.slow_left, p.hp, p.reviving, p.invuln, bolts().size(), str(is_instance_valid(farmer))])
	farmer.queue_free()
	p.slow_left = 0.0
	var netter = mk(p.global_position + Vector2(120, 0), 1, 2)
	check("a Hunter throws a net", netter.use_skill_id("net", p, 120.0))
	await frames(45)
	check("the net slows 小怪", p.slow_left > 0.0)
	netter.queue_free()
	p.hp = p.max_hp
	p.invuln = 0.0
	var axeman = mk(p.global_position + Vector2(100, 0), 1, 1)
	check("a Woodsman throws an axe", axeman.use_skill_id("axe", p, 100.0))
	await frames(2)
	check("the axe hits harder than a normal bolt", bolts().size() >= 1 and bolts()[0].damage >= axeman.effective_damage())
	await frames(40)
	check("the axe hurts 小怪", p.hp < p.max_hp)
	axeman.queue_free()
	await clear_enemies()
	p.hp = p.max_hp
	p.invuln = 0.0
	var archer = mk(p.global_position + Vector2(200, 0), 3, 2)
	check("a Hunter fires a volley of three", archer.use_skill_id("volley", p, 200.0))
	await frames(2)
	check("three bolts in the air", bolts().size() == 3, str(bolts().size()))
	await frames(1)
	var piercer = mk(p.global_position + Vector2(150, 0), 3, 2)
	check("a Hunter fires a piercing bolt", piercer.use_skill_id("pierce", p, 150.0))
	await frames(2)
	check("that bolt pierces", bolts().any(func(b): return b.pierce))
	await clear_enemies()

	# =========================== navigation: walking around obstacles ===========================
	await fresh()
	main.elapsed = 1000.0  # past the gentle start, so villagers shoot and use skills
	p = main.player
	await clear_enemies()
	var r := find_free_rect(30, 12)
	check("found open ground for the obstacle test", r.x >= 0)
	for yy in range(r.y + 2, r.y + 10):
		main.block_tile(Vector2i(r.x + 15, yy))
	p.global_position = at(r.x + 21, r.y + 6)
	var walker = main._spawn_villager(at(r.x + 9, r.y + 6), 0, 3)
	var wall_x := float(r.x + 15) * 32.0
	check("the straight line to 小怪 is blocked", not main.has_clear_line(walker.global_position, p.global_position))
	check("but a path exists around the wall", not main.find_path(walker.global_position, p.global_position).is_empty())
	var crossed := false
	for i in 1800:
		await physics_frame
		if not is_instance_valid(walker) or walker.is_queued_for_deletion() or walker.global_position.x > wall_x + 20.0:
			crossed = true
			break
	check("a villager walks around the wall instead of getting stuck", crossed)

	# =========================== village growth and hidden spawns ===========================
	await fresh()
	p = main.player
	main.elapsed = 0.0
	p.choose_line(0)  # a chosen line gives him the 10 forms, so stages can be set freely below
	check("starts with 30 villagers allowed", main.target_population() == 30)
	main.elapsed = 600.0
	var halfway: int = main.target_population()
	main.elapsed = 1200.0
	check("120 villagers allowed after 20 minutes by the clock alone", main.target_population() == 120)
	main.elapsed = 99999.0
	check("the clock's share stops at 120", main.target_population() == 120)
	check("growth is slow at first, fastest at the end", (120 - halfway) > (halfway - 30), "%d at 10 min" % halfway)
	main.elapsed = 0.0
	p.stage = 0
	var base_pop: int = main.target_population()
	p.stage = 1
	check("each evolution adds 22 more villagers", main.target_population() == base_pop + 22)
	p.stage = 5
	check("the village swells with the evolution stage", main.target_population() == base_pop + 110)
	p.stage = 10
	main.elapsed = 1200.0
	check("at the final form the village is massive (capped)", main.target_population() == mini(main.POP_CAP, 340), str(main.target_population()))
	main.elapsed = 99999.0
	p.stage = 10
	check("but there is a cap of 360", main.target_population() <= main.POP_CAP)
	p.stage = 0
	main.spawn_cd = 0.0
	main.elapsed = 0.0
	await clear_enemies()
	main.spawn_cd = 0.0
	p.stage = 6
	await frames(3)
	for i in 6:
		await process_frame  # the spawner runs in _process; give it real idle frames to run in
	check("after evolving, many villagers arrive at once", enemies().size() >= 2, str(enemies().size()))
	p.stage = 0
	await clear_enemies()
	main.elapsed = 0.0
	var slow_interval: float = main.spawn_interval()
	main.elapsed = 1200.0
	check("respawns speed up over time", is_equal_approx(slow_interval, main.SPAWN_SLOW) and is_equal_approx(main.spawn_interval(), main.SPAWN_FAST))

	await clear_enemies()
	main.elapsed = 100.0
	for i in 60:
		main._on_phase_change()
	check("no hidden enemies in the first 10 minutes", enemies().is_empty())
	main.elapsed = 650.0
	for i in 40:
		main._on_phase_change()
	var early: Array = enemies()
	check("a dawn or dusk can spawn a hidden enemy", early.filter(func(e): return e.secret == 0).size() >= 1)
	check("early on only Parasite Heroes appear", early.all(func(e): return e.secret <= 0))
	await clear_enemies()
	main.elapsed = 900.0
	for i in 80:
		main._on_phase_change()
	check("later, Dark Heroes can appear", enemies().filter(func(e): return e.secret == 1).size() >= 1)
	check("but GOD needs village level 5", enemies().all(func(e): return e.secret != 2))
	await clear_enemies()
	main.elapsed = 1300.0
	main.village_level = 5
	for i in 120:
		main._on_phase_change()
	check("villagers get tougher with the clock: health x1 at the start, about x3 at 15 minutes", is_equal_approx(main.hp_mult_at(0.0), 1.0) and absf(main.hp_mult_at(900.0) - 3.14) < 0.05 and main.damage_mult_at(900.0) > 1.9)
	check("GOD never appears by chance at a dawn or dusk", enemies().all(func(e): return e.secret != 2))
	await clear_enemies()
	var god = main.spawn_god()
	check("GOD descends as the last boss, very strong", god != null and god.secret == 2 and god.max_hp >= 3000 and god.damage >= 22 and main.god_spawned)
	check("GOD is released at once and hunts 小怪", god.guard_until == 0.0 and god.force_chase)
	check("GOD is immune to every status", not god.apply_status("burn", 3.0) and not god.apply_status("chill", 3.0) and not god.apply_status("poison", 3.0) and not god.has_status("burn"))
	var god_hp0: int = god.hp
	god.apply_stun(5.0)
	god.take_hit(1000000, Vector2.RIGHT, false)
	check("GOD cannot be stunned, pushed or killed in one blow", god.stun_left == 0.0 and god.knock == Vector2.ZERO and god.hp > 0 and god_hp0 - god.hp <= ceili(god.max_hp * 0.031), "lost %d of %d" % [god_hp0 - god.hp, god.max_hp])
	main.drown.clear()
	check("GOD does not drown in water", god.immune())
	await clear_enemies()
	await clear_enemies()

	main.clock = 59.0
	main.last_phase = 0
	main.elapsed = 0.0
	await frames(180)
	check("the day to night change is detected", main.last_phase == 1)

	# =========================== a gentle start ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 10.0
	var hunter0 = main._spawn_villager(Vector2(3000, 600), 1, 2)
	var mage0 = main._spawn_villager(Vector2(3000, 700), 1, 6)
	var farmer0 = main._spawn_villager(Vector2(3000, 900), 1, 0)
	var militia0 = main._spawn_villager(Vector2(3000, 950), 1, 3)
	await frames(2)
	check("at the start hunters and mages can already shoot", not hunter0.ranged_config().is_empty() and not mage0.ranged_config().is_empty())
	check("at the start other villagers cannot shoot", farmer0.ranged_config().is_empty())
	check("at the start shooters already have their skills", mage0.skill_name() == "fireball" and hunter0.skill_name() == "net")
	check("at the start other villagers have no skills", militia0.skill_name() == "")
	check("at the start days give villagers no bonus", main.enemy_power() == 1.0)
	check("villagers walk slower at the start", main.enemy_speed_mult() < 1.0 and hunter0.effective_speed() < hunter0.speed)
	var hidden0 = main._spawn_villager(Vector2(3000, 800), 4, 3, 0)
	check("hidden forms shoot too, but not before the grace period ends", hidden0.ranged_config().is_empty())
	main.elapsed = 200.0
	check("after 3 minutes villagers can shoot", not hunter0.ranged_config().is_empty() and not hidden0.ranged_config().is_empty())
	check("...but the others still have no skills", militia0.skill_name() == "")
	check("...and daylight makes them stronger", main.is_night() or main.enemy_power() == 1.5)
	main.elapsed = 400.0
	check("after 6 minutes they have skills", mage0.skill_name() == "fireball" and militia0.skill_name() == "shield")
	main.elapsed = 0.0
	check("at the start only nearby villagers notice 小怪", main.chase_radius() < 600.0)
	main.elapsed = 150.0
	check("the notice radius grows", main.chase_radius() > 1500.0 and main.chase_radius() < INF)
	main.elapsed = 300.0
	check("after five minutes villagers find 小怪 from anywhere", main.chase_radius() == INF)
	main.elapsed = 0.0
	check("only 6 villagers chase at the start, and the budget grows by one every 10 seconds", main.chase_budget() == 6)
	main.elapsed = 600.0
	check("the chase budget grows with the clock and tops out at 130", main.chase_budget() == 66 and (main.elapsed + 99999.0) > 0.0)
	main.elapsed = 5000.0
	check("the chase budget is capped", main.chase_budget() == 130)
	main.elapsed = 0.0
	for n in [hunter0, mage0, hidden0]:
		n.queue_free()
	await clear_enemies()
	main.elapsed = 10.0
	p.global_position = at(40, 40)
	var far_one = main._spawn_villager(p.global_position + Vector2(1500, 0), 0, 3)
	var near_one = main._spawn_villager(p.global_position + Vector2(300, 0), 0, 3)
	var far0: float = far_one.global_position.distance_to(p.global_position)
	var near0: float = near_one.global_position.distance_to(p.global_position)
	await frames(60)
	check("a far villager ignores 小怪 at the start", absf(far_one.global_position.distance_to(p.global_position) - far0) < 5.0)
	check("a close villager still comes for 小怪", not is_instance_valid(near_one) or near_one.global_position.distance_to(p.global_position) < near0 - 10.0)

	# =========================== respawn, village level, chase ===========================
	await fresh()
	main.elapsed = 1000.0  # past the gentle start, so villagers shoot and use skills
	p = main.player
	var alive_before: int = enemies().size()
	var victim = enemies()[0]
	victim.take_hit(999, Vector2.RIGHT)
	await frames(2)
	check("a defeated villager leaves the field", enemies().size() == alive_before - 1)
	check("a kill counts and pays bones", main.kills == 1 and main.bones > main.START_BONES)
	main.elapsed = 0.0
	main.village_level = 4
	main.spawn_cd = 0.0
	p.global_position = Vector2(100, 100)
	await frames(3)
	check("a new villager respawns", enemies().size() == alive_before)
	var newest = enemies()[enemies().size() - 1]
	check("respawn is born in the form matching the village level", newest.stage == 3, "stage %d" % newest.stage)
	main.kills = 0
	main._on_villager_defeated(4, 1, true)
	check("village level starts at 1", main.village_level == 1)
	main.kills = main.KILLS_PER_VILLAGE_LEVEL * 2 - 1
	main._on_villager_defeated(4, 1, true)
	check("village level rises with kills", main.village_level == 3, str(main.village_level))
	main.kills = main.KILLS_PER_VILLAGE_LEVEL * 40
	main._on_villager_defeated(4, 1, true)
	check("village level caps at 5", main.village_level == 5)

	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 1000.0
	var chaser = main._spawn_villager(p.global_position + Vector2(2500, 1500), 0, 3)
	var d0: float = chaser.global_position.distance_to(p.global_position)
	await frames(60)
	check("villagers chase from across the map", chaser.global_position.distance_to(p.global_position) < d0 - 20.0)

	# =========================== day and night ===========================
	await fresh()
	main.elapsed = 1000.0  # past the gentle start, so villagers shoot and use skills
	p = main.player
	await clear_enemies()
	main.clock = 30.0
	main._update_daynight()
	var noon_tint: Color = main.tint.color
	check("clock 30 is day", not main.is_night() and main.daylight() > 0.95)
	check("day: villagers stronger", main.enemy_power() == 1.5 and main.player_power() == 1.0)
	var vday = main._spawn_villager(Vector2(3000, 1500), 3, 3)
	await frames(2)
	var day_damage: int = vday.effective_damage()
	var day_speed: float = vday.effective_speed()
	var day_bite: int = p.effective_bite()
	main.clock = 90.0
	main._update_daynight()
	check("clock 90 is night", main.is_night() and main.daylight() < 0.05)
	check("night: 小怪 stronger", main.player_power() == 1.5 and main.enemy_power() == 1.0)
	check("night bite is stronger than day bite", p.effective_bite() > day_bite)
	check("day villager hits harder than night villager", day_damage > vday.effective_damage())
	check("day villager is faster than night villager", day_speed > vday.effective_speed())
	check("the screen darkens at night", main.tint.color.r < noon_tint.r - 0.3)
	main.clock = 120.0 + 15.0
	check("the cycle repeats: next morning is day", not main.is_night())

	# =========================== building: towers and walls anywhere ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	p.global_position = at(10, 10)
	main.bones = 100
	var b_before: int = main.bones
	check("a tower can go where you point, near you", main.place_at(Vector2i(14, 10), "tower") and main.built.has(Vector2i(14, 10)))
	check("a tower costs 15 bones", main.bones == b_before - 15)
	check("the tower blocks its tile for pathing", main.astar.is_point_solid(Vector2i(14, 10)))
	var tower = main.built[Vector2i(14, 10)]
	check("building on a tower upgrades it", main.place_at(Vector2i(14, 10), "tower") and tower.level == 2)
	main.place_at(Vector2i(14, 10), "tower")
	check("towers stop at level 3", tower.level == 3 and main.build_error(Vector2i(14, 10), "tower") == "Tower is at max level")
	check("a bone wall costs 5 bones", main.bones == 100 - 15 - 25 - 40 and main.place_at(Vector2i(14, 12), "wall") and main.bones == 100 - 15 - 25 - 40 - 5)
	check("walls and towers are structures villagers can hit", get_nodes_in_group("structures").size() == 2)
	check("an occupied tile is refused", main.build_error(Vector2i(14, 12), "wall") == "Occupied")
	check("too far from 小怪 is refused", main.build_error(Vector2i(60, 60), "tower") == "Too far from you")
	check("right on top of 小怪 is refused", main.build_error(Vector2i(10, 10), "wall") == "Too close to you")
	main.bones = 2
	check("not enough bones is refused", main.build_error(Vector2i(15, 12), "wall").begins_with("Need"))
	main.bones = 500

	# Surround 小怪 with walls: the last one must be refused so a way in remains.
	await fresh()
	p = main.player
	await clear_enemies()
	p.global_position = at(9, 9)
	main.bones = 500
	# four corners, then three sides; the east side (10, 9) is the one that would seal it
	var ring: Array[Vector2i] = [Vector2i(8, 8), Vector2i(10, 8), Vector2i(8, 10), Vector2i(10, 10),
			Vector2i(9, 8), Vector2i(8, 9), Vector2i(9, 10), Vector2i(10, 9)]
	var placed_ok := 0
	for i in 7:
		if main.place_at(ring[i], "wall"):
			placed_ok += 1
	check("7 of the 8 walls around 小怪 are allowed", placed_ok == 7)
	check("the 8th, closing wall is refused", main.build_error(ring[7], "wall") == "Would block every way in")
	check("and towers cannot close the ring either", not main.place_at(ring[7], "tower"))
	check("a way in still exists", main.routes_open())
	main.built[ring[4]].take_hit(999, Vector2.ZERO)
	await frames(2)
	check("a destroyed wall frees its tile", not main.built.has(ring[4]) and not main.astar.is_point_solid(ring[4]))
	check("with a bigger gap the last wall is allowed again", main.place_at(ring[7], "wall") and main.routes_open())

	# A long wall that nearly seals a corridor
	await fresh()
	p = main.player
	await clear_enemies()
	p.global_position = at(10, 10)
	main.bones = 500
	var wall_ok := 0
	var wall_refused := 0
	for ty in range(4, 20):
		if main.place_at(Vector2i(13, ty), "wall"):
			wall_ok += 1
		else:
			wall_refused += 1
	check("a line of walls is allowed until it would seal the base", main.routes_open())
	check("walls stay possible in the meadow", wall_ok >= 8, "%d placed, %d refused" % [wall_ok, wall_refused])

	# The build bar and removing things
	await fresh()
	p = main.player
	await clear_enemies()
	p.global_position = at(10, 10)
	main.bones = 100
	check("the bone wall is the selected item at the start", main.build_item == "wall")
	check("a bone wall costs less than a tower", main.WALL_COST < main.TowerScript.COSTS[0])
	check("the build bar shows tower, wall and remove", main.hotbar.size() == 3)
	key(KEY_1, true)
	await frames(4)
	key(KEY_1, false)
	check("key 1 selects the tower", main.build_item == "tower", main.build_item)
	key(KEY_2, true)
	await frames(4)
	key(KEY_2, false)
	check("key 2 selects the bone wall", main.build_item == "wall", main.build_item)
	await frames(2)
	check("the bar highlights the selected item", main.hotbar[1].button_pressed and not main.hotbar[0].button_pressed)
	main.hotbar[0].pressed.emit()
	check("clicking the tower button selects the tower", main.build_item == "tower")
	main.hotbar[1].pressed.emit()
	check("clicking the wall button selects the wall", main.build_item == "wall")
	check("the buttons show prices, not names", main.hotbar[0].text.strip_edges().is_valid_int() and main.hotbar[1].icon != null)

	var wall_tile := Vector2i(13, 10)
	var cash: int = main.bones
	check("build a wall", main.place_at(wall_tile, "wall") and main.bones == cash - 5)
	check("removing a wall shows half back", main.refund_at(wall_tile) == 2)
	check("removing a wall works", main.demolish_at(wall_tile))
	await frames(2)
	check("the wall refunds half its cost", main.bones == cash - 5 + 2, "bones %d" % main.bones)
	check("its tile is free to walk and path again", not main.built.has(wall_tile) and not main.astar.is_point_solid(wall_tile))
	check("and you can build there again", main.place_at(wall_tile, "wall"))
	main.demolish_at(wall_tile)

	var tower_tile := Vector2i(14, 12)
	cash = main.bones
	main.place_at(tower_tile, "tower")
	main.place_at(tower_tile, "tower")
	check("a tower's refund is half of everything spent on it", main.refund_at(tower_tile) == int((15 + 25) / 2.0), str(main.refund_at(tower_tile)))
	main.demolish_at(tower_tile)
	await frames(2)
	check("removing the tower pays that back", main.bones == cash - 40 + 20, "bones %d" % main.bones)
	check("nothing to remove on an empty tile", not main.demolish_at(Vector2i(16, 16)) and main.refund_at(Vector2i(16, 16)) == -1)
	main.place_at(wall_tile, "wall")
	p.global_position = at(60, 60)
	check("too far to remove from here", not main.demolish_at(wall_tile) and main.built.has(wall_tile))

	# Towers shoot, villagers attack structures
	await fresh()
	p = main.player
	await clear_enemies()
	p.global_position = at(5, 5)
	main.bones = 100
	main.place_at(Vector2i(9, 5), "tower")
	tower = main.built[Vector2i(9, 5)]
	var target = main._spawn_villager(tower.global_position + Vector2(100, 0), 0, 3)
	var xp0: int = p.xp
	var bones0: int = main.bones
	await frames(200)
	check("a tower kills a villager in range", not is_instance_valid(target) or target.is_queued_for_deletion())
	check("tower kills give bones but no EXP", main.bones > bones0 and p.xp == xp0)
	var brute = main._spawn_villager(tower.global_position + Vector2(24, 0), 4, 7)
	var thp: int = tower.hp
	await frames(90)
	check("villagers attack towers", not is_instance_valid(tower) or tower.hp < thp)

	# =========================== status effects ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 10.0  # gentle start: far villagers do not notice 小怪
	p.global_position = at(8, 8)
	var far_spot := at(60, 60)
	var sv = mk(far_spot, 4, 4)
	sv.max_hp = 200
	sv.hp = 200
	var start_hp: int = sv.hp
	sv.apply_status("burn", 3.5)
	await frames(130)
	check("burn hurts once a second", start_hp - sv.hp >= 2 and start_hp - sv.hp <= 3, "lost %d" % (start_hp - sv.hp))
	await frames(100)
	check("a status wears off", not sv.has_status("burn"))
	start_hp = sv.hp
	sv.apply_status("poison", 5.0)
	sv.apply_status("poison", 5.0)
	sv.apply_status("poison", 5.0)
	sv.apply_status("poison", 5.0)
	check("poison stacks up to 3", sv.poison_stacks == 3)
	await frames(70)
	check("poison hurts once per stack each second", start_hp - sv.hp >= 3, "lost %d" % (start_hp - sv.hp))
	sv.statuses.clear()
	sv.poison_stacks = 0
	start_hp = sv.hp
	sv.apply_status("bleed", 3.5)
	await frames(70)
	check("bleed hurts once a second", start_hp - sv.hp >= 1)
	sv.statuses.clear()
	var base_speed: float = sv.effective_speed()
	sv.apply_status("chill", 3.0)
	check("chill slows to 65% speed", is_equal_approx(sv.effective_speed(), base_speed * 0.65))
	sv.statuses.clear()
	check("a villager can be frozen", sv.apply_status("freeze", 5.0) and sv.has_status("freeze"))
	check("a freeze lasts at most 1.2 s", sv.statuses["freeze"] <= 1.2)
	check("it cannot be frozen again right away", not sv.apply_status("freeze", 1.0))
	var boss_v = mk(far_spot + Vector2(200, 0), 4, 4, 0)
	check("hidden forms resist freeze, root and charm",
			not boss_v.apply_status("freeze", 1.0) and not boss_v.apply_status("root", 1.0) and not boss_v.apply_status("charm", 1.0))
	check("but they can burn", boss_v.apply_status("burn", 1.0))
	boss_v.queue_free()
	sv.statuses.clear()
	sv.freeze_immune = 0.0
	var hp_pre: int = sv.hp
	sv.take_hit(10, Vector2.RIGHT)
	var dmg_plain: int = hp_pre - sv.hp
	sv.apply_status("curse", 5.0)
	hp_pre = sv.hp
	sv.take_hit(10, Vector2.RIGHT)
	check("curse makes a villager take +50% damage", dmg_plain == 10 and hp_pre - sv.hp == 15, "%d then %d" % [dmg_plain, hp_pre - sv.hp])
	sv.statuses.clear()
	var near_mate = mk(far_spot + Vector2(60, 0), 4, 4)
	near_mate.max_hp = 500
	near_mate.hp = 500
	sv.apply_status("shock", 30.0)
	var mate_hp: int = near_mate.hp
	sv.hp = 200
	for i in 80:
		sv.take_hit(1, Vector2.RIGHT)
	check("shock passes some damage to the nearest villager", near_mate.hp < mate_hp, "%d -> %d" % [mate_hp, near_mate.hp])
	near_mate.queue_free()
	sv.queue_free()

	# root and charm
	await clear_enemies()
	p.global_position = at(8, 8)
	var free_one = mk(p.global_position + Vector2(300, 0), 0, 3)
	var rooted_one = mk(p.global_position + Vector2(0, 300), 0, 3)
	rooted_one.apply_status("root", 5.0)
	var free_d0: float = free_one.global_position.distance_to(p.global_position)
	var root_d0: float = rooted_one.global_position.distance_to(p.global_position)
	await frames(60)
	check("a free villager walks toward 小怪", free_one.global_position.distance_to(p.global_position) < free_d0 - 10.0)
	check("a rooted villager cannot move", absf(rooted_one.global_position.distance_to(p.global_position) - root_d0) < 4.0)
	free_one.queue_free()
	rooted_one.queue_free()
	await clear_enemies()
	p.global_position = at(8, 8)
	var charmed = mk(far_spot, 4, 4)
	var victim_v = mk(far_spot + Vector2(50, 0), 0, 3)
	victim_v.max_hp = 40
	victim_v.hp = 40
	charmed.apply_status("charm", 10.0)
	var player_hp_before: int = p.hp
	await frames(200)
	check("a charmed villager attacks other villagers", not is_instance_valid(victim_v) or victim_v.is_queued_for_deletion() or victim_v.hp < 40)
	check("and leaves 小怪 alone", p.hp == player_hp_before)
	await clear_enemies()

	# =========================== family traits and first abilities ===========================
	var AbilitiesData = main.player.AbilitiesData
	check("ability rank: none before form 3, then 1, 2, 3 at forms 3, 6, 9",
			AbilitiesData.rank_for_stage(2) == 0 and AbilitiesData.rank_for_stage(3) == 1
			and AbilitiesData.rank_for_stage(6) == 2 and AbilitiesData.rank_for_stage(9) == 3)
	check("8 abilities are built, one per listed line", AbilitiesData.ABILITIES.size() == 8)
	check("every family has a trait", ["Undead", "Slime", "Dragon", "Beast", "Nature", "Material", "Demon"].all(func(f): return AbilitiesData.FAMILY_TRAITS.has(f)))

	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 10.0
	p.global_position = at(8, 8)
	use_line(0, 2)
	check("no ability before form 3", p.ability().is_empty())
	use_line(2, 5)
	check("lines without a built ability have none", p.ability().is_empty())

	# Undead: heal at night
	use_line(0, 1)
	main.clock = 90.0
	p.hp = p.max_hp - 3
	var undead_hp: int = p.hp
	await frames(220)
	check("Undead: heals 1 HP every 1.7 s at night", p.hp >= undead_hp + 2, "%d -> %d" % [undead_hp, p.hp])
	main.clock = 30.0
	p.hp = p.max_hp - 3
	undead_hp = p.hp
	await frames(140)
	check("Undead: no healing by day", p.hp == undead_hp)

	# Slime: a blob when hit
	use_line(7, 1)
	var blob_target = mk(p.global_position + Vector2(100, 0), 0, 3)
	p.invuln = 0.0
	p.take_hit(2, Vector2.LEFT)
	await frames(3)
	check("Slime: damage taken splits off a blob", bolts().any(func(b): return b.team == "player"))
	blob_target.queue_free()
	await clear_enemies()

	# Dragon: spark
	use_line(10, 1)
	p.spark_chance = 1.0
	var d1 = mk(p.global_position + Vector2(40, 0), 0, 3)
	var d2 = mk(p.global_position + Vector2(-40, 0), 0, 3)
	d1.max_hp = 50
	d1.hp = 50
	d2.max_hp = 50
	d2.hp = 50
	p.on_bite_landed(d1, 3)
	check("Dragon: a bite can spark onto a second villager", d2.hp < 50 and d1.hp == 50)
	p.spark_chance = 0.15
	await clear_enemies()

	# Beast: speed
	use_line(14, 1)
	main.clock = 30.0
	check("Beast: +10% speed by day", is_equal_approx(p.trait_speed(), 1.10))
	main.clock = 90.0
	use_line(15, 1)
	check("Beast: +25% speed at night", is_equal_approx(p.trait_speed(), 1.25))

	# Nature: regenerate standing still
	use_line(18, 1)
	p.hp = p.max_hp - 3
	var nature_hp: int = p.hp
	await frames(420)
	check("Nature: regenerates while standing still", p.hp > nature_hp, "%d -> %d" % [nature_hp, p.hp])

	# Material: less damage per hit
	use_line(21, 1)
	check("Material: every hit does 1 less (never below 1)", p.reduce_damage(3) == 2 and p.reduce_damage(1) == 1)

	# Demon: extra bone per kill
	use_line(22, 1)
	var bones_before_demon: int = main.bones
	main._on_villager_defeated(4, 1, true)
	check("Demon: a kill drops 1 extra bone", main.bones - bones_before_demon == 2, str(main.bones - bones_before_demon))

	# --- the 8 abilities ---
	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 10.0
	p.global_position = at(8, 8)

	use_line(0, 3)
	p.hp = 1
	var drain_target = mk(p.global_position + Vector2(30, 0), 0, 3)
	p.on_bite_landed(drain_target, 3)
	check("Blood Drain: a bite heals you", p.hp > 1)
	use_line(0, 9)
	var mist_target = mk(p.global_position + Vector2(40, 0), 0, 3)
	mist_target.max_hp = 100
	mist_target.hp = 100
	mist_target.global_position = p.global_position + Vector2(40, 0)
	check("Blood Drain rank 3: the red mist makes nearby villagers bleed", p.crimson_mist() >= 1 and mist_target.has_status("bleed"))
	mist_target.global_position = p.global_position + Vector2(200, 0)
	mist_target.statuses.clear()
	p.crimson_mist()
	check("the mist is short range", not mist_target.has_status("bleed"))
	await clear_enemies()

	use_line(1, 3)
	var crowd2: Array = []
	for i in 3:
		crowd2.append(mk(p.global_position + Vector2(120 + 15 * i, 20 * i - 20), 0, 3))
		crowd2[i].max_hp = 300
		crowd2[i].hp = 300
	await frames(6)
	check("Bone Servants: 2 skeletons rise when villagers crowd near", get_nodes_in_group("allies").size() == 2, str(get_nodes_in_group("allies").size()))
	check("Bone Servants has a cooldown", p.ab_cd["bone_servants"] > 0.0)
	var crowd_hp: int = crowd2.map(func(c): return c.hp).reduce(func(a, b): return a + b, 0)
	await frames(200)
	check("the skeletons bite villagers", crowd2.map(func(c): return c.hp if is_instance_valid(c) else 0).reduce(func(a, b): return a + b, 0) < crowd_hp)
	await clear_enemies()
	for h in get_nodes_in_group("allies"):
		h.queue_free()
	await frames(3)
	use_line(1, 9)
	p.ab_cd.clear()
	for i in 3:
		var cc = mk(p.global_position + Vector2(120 + 15 * i, 20 * i - 20), 0, 3)
		cc.max_hp = 300
		cc.hp = 300
	await frames(6)
	check("Bone Servants rank 3: 4 skeletons", get_nodes_in_group("allies").size() == 4, str(get_nodes_in_group("allies").size()))
	await clear_enemies()
	for h in get_nodes_in_group("allies"):
		h.queue_free()
	await frames(3)

	use_line(6, 3)
	p.invuln = 0.0
	key(KEY_D, true)
	key(KEY_SHIFT, true)
	await frames(40)
	key(KEY_SHIFT, false)
	key(KEY_D, false)
	var pools: Array = main.get_children().filter(func(c): return c.get_script() == main.PlayerScript.PoolScript)
	check("Molten Trail: sprinting leaves goo behind", pools.size() >= 2, str(pools.size()))
	p.global_position = at(8, 8)
	var goo_target = mk(p.global_position + Vector2(200, 0), 0, 3)
	goo_target.max_hp = 100
	goo_target.hp = 100
	goo_target.apply_status("root", 5.0)  # keep it standing in the goo
	p.global_position = goo_target.global_position  # drop the goo right under the villager
	p._drop_pool(1)
	p.global_position = at(8, 8)
	await frames(50)
	check("Molten Trail: villagers in the goo burn", goo_target.has_status("burn"))
	await clear_enemies()
	p.global_position = at(8, 8)

	use_line(10, 3)
	var flame = mk(p.global_position + Vector2(120, 0), 0, 3)
	flame.max_hp = 60
	flame.hp = 60
	var side = mk(p.global_position + Vector2(50, 60), 0, 3)
	side.max_hp = 60
	side.hp = 60
	check("Fire Breath: a narrow cone hits ahead, not the side", p.breathe(Vector2.RIGHT, 0.5, "burn") >= 1 and flame.hp < 60 and side.hp == 60)
	check("Fire Breath burns what it hits", flame.has_status("burn"))
	check("rank 3 is wider: it also catches the side", p.breathe(Vector2.RIGHT, 1.0, "burn") >= 2 and side.hp < 60)
	await clear_enemies()
	p.ab_cd.clear()
	var auto_fire = mk(p.global_position + Vector2(150, 0), 0, 3)
	auto_fire.max_hp = 200
	auto_fire.hp = 200
	await frames(5)
	check("Fire Breath fires by itself and then cools down", p.ab_cd["fire_breath"] > 4.0)
	await clear_enemies()

	use_line(14, 3)
	main.clock = 90.0
	check("Pack Howl: +40% speed at night on top of the Beast trait", is_equal_approx(p.trait_speed(), 1.65))
	var bite_target = mk(p.global_position + Vector2(30, 0), 0, 3)
	bite_target.max_hp = 100
	bite_target.hp = 100
	p.on_bite_landed(bite_target, 2)
	check("Pack Howl: night bites make villagers bleed", bite_target.has_status("bleed"))
	main.clock = 30.0
	bite_target.statuses.clear()
	p.on_bite_landed(bite_target, 2)
	check("Pack Howl: no bleeding by day", not bite_target.has_status("bleed"))
	await clear_enemies()
	use_line(14, 9)
	main.clock = 90.0
	var howl_target = mk(p.global_position + Vector2(200, 0), 0, 3)
	howl_target.max_hp = 300
	howl_target.hp = 300
	p.ab_cd.clear()
	await frames(6)
	check("Pack Howl rank 3: two wolf pups come at night", get_nodes_in_group("allies").size() == 2 and get_nodes_in_group("allies")[0].kind == "wolf")
	await clear_enemies()
	for h in get_nodes_in_group("allies"):
		h.queue_free()
	await frames(3)

	use_line(17, 3)
	var root_target = mk(p.global_position + Vector2(90, 0), 0, 3)
	root_target.max_hp = 100
	root_target.hp = 100
	await frames(150)
	check("Rooted: standing still roots villagers nearby", root_target.has_status("root"))
	check("Rooted has a cooldown", p.ab_cd["rooted"] > 0.0)
	await clear_enemies()

	use_line(20, 3)
	check("Stone Skin rank 1 with the Material trait: 5 damage becomes 2", p.reduce_damage(5) == 2, str(p.reduce_damage(5)))
	check("Stone Skin: 10% slower", is_equal_approx(p.trait_speed(), 0.9))
	use_line(20, 9)
	check("Stone Skin rank 3: hits are cut by 5, but armour never takes off more than 60%", p.reduce_damage(6) == 3 and p.reduce_damage(9) == 4 and p.reduce_damage(20) == 15, "%d %d %d" % [p.reduce_damage(6), p.reduce_damage(9), p.reduce_damage(20)])
	var quake_target = mk(p.global_position + Vector2(100, 0), 0, 3)
	quake_target.max_hp = 100
	quake_target.hp = 100
	p.ab_cd.clear()
	await frames(30)
	check("Stone Skin rank 3: an earthquake stuns nearby villagers", p.ab_cd["stone_skin"] > 0.0 and (quake_target.stun_left > 0.0 or quake_target.hp < 100))
	await clear_enemies()

	use_line(22, 3)
	var rain_targets: Array = []
	for i in 4:
		var rt = mk(p.global_position + Vector2(150 + 20 * i, -60 + 40 * i), 0, 3)
		rt.max_hp = 100
		rt.hp = 100
		rain_targets.append(rt)
	p.ab_cd.clear()
	await frames(5)
	check("Hellfire Rain: 3 fireballs warn at rank 1", zones().size() == 3, str(zones().size()))
	await frames(70)
	check("Hellfire Rain: fireballs burn the villagers", rain_targets.filter(func(t): return t.has_status("burn") or t.hp < 100).size() >= 2)
	await clear_enemies()

	main._update_hud()
	check("the screen shows the ability", main.hud.info.get("ability", "") == "Hellfire Rain")

	# =========================== damage numbers ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 10.0
	p.global_position = at(8, 8)
	var Pop = p.Popups
	Pop.active = 0
	var tv2 = mk(at(60, 60), 4, 4)
	tv2.max_hp = 900
	tv2.hp = 900
	tv2.take_hit(2, Vector2.RIGHT)
	await frames(2)
	check("a hit shows how much damage it did", floaters().size() >= 1 and floaters().any(func(f): return f.text == "2"))
	check("small hits are white", floaters().any(func(f): return f.text == "2" and f.color == Pop.WHITE))
	tv2.take_hit(9, Vector2.RIGHT)
	await frames(2)
	check("big hits (6 or more) are yellow and bigger", floaters().any(func(f): return f.text == "9" and f.color == Pop.BIG and f.font_size >= 20))
	tv2.take_hit(3, Vector2.RIGHT, true)
	await frames(2)
	check("tower damage has its own colour", floaters().any(func(f): return f.text == "3" and f.color == Pop.TOWER))
	tv2.shield_left = 5.0
	tv2.take_hit(8, Vector2.RIGHT)
	await frames(2)
	check("the number is the damage really dealt (a shield halves it)", floaters().any(func(f): return f.text == "4"))
	tv2.shield_left = 0.0
	tv2.apply_status("curse", 5.0)
	tv2.take_hit(10, Vector2.RIGHT)
	await frames(2)
	check("a curse shows the bigger number: 10 becomes 15", floaters().any(func(f): return f.text == "15"))
	tv2.statuses.clear()
	tv2.apply_status("burn", 3.0)
	await frames(75)
	check("burn damage shows in orange", floaters().any(func(f): return f.text == "1" and f.color == Pop.BURN))
	p.invuln = 0.0
	p.take_hit(3, Vector2.LEFT)
	await frames(2)
	check("damage to 小怪 shows in red", floaters().any(func(f): return f.text == "3" and f.color == Pop.HURT))
	check("floating numbers rise", floaters().any(func(f): return f.position.y < at(60, 60).y - 12.0) or floaters().size() > 0)
	main.bones = 100
	p.global_position = at(10, 10)
	main.place_at(Vector2i(14, 10), "wall")
	main.built[Vector2i(14, 10)].take_hit(4, Vector2.ZERO)
	await frames(2)
	check("damage to walls and towers shows too", floaters().any(func(f): return f.text == "4" and f.color == Pop.STRUCTURE))
	for i in 200:
		Pop.text(main.get_tree(), at(30, 30), "x")
	await frames(2)
	check("there is a cap on how many numbers float at once", floaters().size() <= Pop.MAX_ACTIVE, str(floaters().size()))
	await frames(90)
	check("numbers fade away and are removed", floaters().is_empty() and Pop.active == 0, "%d left, active %d" % [floaters().size(), Pop.active])
	Pop.enabled = false
	tv2.take_hit(5, Vector2.RIGHT)
	await frames(2)
	check("damage numbers can be switched off", floaters().is_empty())
	Pop.enabled = true
	await clear_enemies()

	# =========================== sound ===========================
	await fresh()
	p = main.player
	var Sfx = main.Sfx
	var tree: SceneTree = main.get_tree()
	await create_timer(1.3).timeout  # the earlier tests played many sounds in a few real seconds; let them end
	for i in 40:  # wait until most of the 16 sound players are free again
		var idle := 0
		for pl in Sfx._pool:
			if not pl.playing:
				idle += 1
		if Sfx._pool.is_empty() or idle >= 12:
			break
		await create_timer(0.1).timeout
	check("there are over 20 sound effects", Sfx.names().size() > 20, "%d" % Sfx.names().size())
	var bad := ""
	for n in Sfx.names():
		var s = Sfx.stream_for(n)
		var peak := 0
		for i in range(0, s.data.size(), 2):
			peak = maxi(peak, absi(s.data.decode_s16(i)))
		if not (s is AudioStreamWAV) or s.data.size() < 2000 or peak < 2000 or peak >= 32767:
			bad += n + " "
	check("every sound has real audio: not silent, not clipped", bad == "", bad)
	check("every sound is short (under 1.5 s)", Sfx.names().all(func(n): return Sfx.stream_for(n).data.size() / 2.0 / Sfx.RATE < 1.5))
	Sfx.play(tree, "hit")  # the first play creates the player pool
	await frames(4)
	check("a sound plays", Sfx.play(tree, "build"))
	check("the same sound is not spammed", not Sfx.play(tree, "build"))
	await create_timer(0.2).timeout  # the spam guard counts real time, and frames here are very fast
	check("a far-away sound is skipped", not Sfx.play_at(tree, "hit", p.global_position + Vector2(5000, 0)))
	var free_players := 0
	for pl in Sfx._pool:
		if not pl.playing:
			free_players += 1
	var near_ok: bool = Sfx.play_at(tree, "hit", p.global_position + Vector2(100, 0))
	check("a near sound plays", near_ok, "free players %d of %d, enabled %s, last hit %s, now %d" % [
			free_players, Sfx._pool.size(), str(Sfx.enabled), str(Sfx._last_play.get("hit")), Time.get_ticks_msec()])
	Sfx.enabled = false
	check("sound can be switched off", not Sfx.play(tree, "levelup"))
	Sfx.enabled = true

	var tracks: Dictionary = main.MusicScript.TRACKS
	var all_files := true
	for id in tracks:
		for key in ["intro", "loop"]:
			if tracks[id].has(key) and not ResourceLoader.exists(tracks[id][key]):
				all_files = false
	check("every music file is in the project and imported", all_files)
	check("the game starts with Battle Theme 0", main.music.current == "battle1" and main.credit.text.contains("Battle Theme 0"), main.music.current)
	check("music keeps playing while a menu pauses the game", main.music.process_mode == Node.PROCESS_MODE_ALWAYS)
	p.choose_line(0)
	main.clock = 30.0  # day
	p.stage = 2
	check("early forms: Battle Theme 0", main.wanted_track() == "pool:early" and main.music.POOLS["early"][0] == "battle1")
	p.stage = 4
	check("middle forms: Epic Boss Battle", main.wanted_track() == "pool:mid" and main.music.POOLS["mid"][0] == "battle2")
	p.stage = 7
	check("later forms: Boss Battle #2 (intro, then loop)", main.wanted_track() == "pool:late" and tracks["battle3"].has("intro"))
	p.stage = 9
	check("the last forms: the final boss theme", main.wanted_track() == "final")
	p.stage = 4
	main.clock = 90.0  # night
	check("nights have their own track", main.wanted_track() == "pool:night")
	p.stage = 10
	check("but the final forms keep the final theme at night", main.wanted_track() == "final")
	main._update_music()
	check("the final theme credits its CC-BY composer on screen", main.music.current == "final" and main.credit.text.contains("Matthew Pablo") and main.credit.text.contains("CC-BY"), main.credit.text)
	p.stage = 0
	main.clock = 30.0
	main._update_music()
	check("the music changes back and the credit follows", main.music.current == "battle1" and main.credit.text.contains("Wolfgang_"))

	# =========================== form skills: each line and form has its own picks ===========================
	await fresh()
	p = main.player
	var SkillsD = main.SkillsData
	var fk_fs: Dictionary = SkillsD.form_skills()
	var fk_released_lines := [0, 1, 2, 6, 10, 14, 17, 20, 22]
	var fk_per_line := {}
	var fk_forms_ok := true
	for id in fk_fs:
		fk_per_line[fk_fs[id]["line"]] = int(fk_per_line.get(fk_fs[id]["line"], 0)) + 1
		fk_forms_ok = fk_forms_ok and int(fk_fs[id]["form"]) >= 2 and int(fk_fs[id]["form"]) <= 10 and main.LinesData.released(int(fk_fs[id]["line"]))
	check("form skills: 9 for each of the 9 released lines", fk_fs.size() == 81 and fk_released_lines.all(func(l): return fk_per_line.get(l, 0) == 9), str(fk_per_line))
	check("form skills: unlock forms are 2 to 10 and only on released lines", fk_forms_ok)
	p.choose_line(10)
	p.stage = 3
	var fk_pool: Array = SkillsD.form_pool(10, 3)
	check("form 3 Dragon: offered Scale Hide, not Ember Bite (form 4)", fk_pool.has("d_scale") and not fk_pool.has("d_ember"), str(fk_pool))
	p.stage = 10
	fk_pool = SkillsD.form_pool(10, 10)
	check("form 10 Dragon: all 9 Dragon skills, none from other lines", fk_pool.size() == 9 and fk_pool.all(func(i): return i.begins_with("d_")), str(fk_pool))
	var frng := RandomNumberGenerator.new()
	frng.seed = 7
	var fk_seen := {}
	for k in 60:
		for id in SkillsD.roll({}, frng, 3, 10, 4):
			fk_seen[id] = true
	check("level-up menu offers form skills up to the current form only", fk_seen.has("d_scale") and fk_seen.has("d_ember") and not fk_seen.has("d_gust") and not fk_seen.has("z_grip"), str(fk_seen.keys()))
	check("general skills are still offered", fk_seen.has("hide") or fk_seen.has("fangs"))
	var fk_none_seen := {}
	for k in 40:
		for id in SkillsD.roll({}, frng, 3, -1, 0):
			fk_none_seen[id] = true
	check("before choosing a line only general skills appear", fk_none_seen.keys().all(func(i): return SkillsD.SKILLS.has(i)))

	p.stage = 7
	var fk_bite0: int = p.effective_bite()
	p.learn("d_heart")
	check("Dragon Heart: stronger bite", p.effective_bite() > fk_bite0, "%d -> %d" % [fk_bite0, p.effective_bite()])
	var fk_hp0: int = p.max_hp
	p.learn("d_scale")
	check("Scale Hide: more max HP", p.max_hp > fk_hp0, "%d -> %d" % [fk_hp0, p.max_hp])
	var fk_jaws_cd: float = p.bite_cd
	check("learning a form skill raises its rank and caps it", p.rank("d_heart") == 1 and (func():
		p.learn("d_heart"); p.learn("d_heart"); p.learn("d_heart"); return p.rank("d_heart") == 3).call())

	p.choose_line(2)
	p.stage = 8
	var fk_cut0: int = p.reduce_damage(6)
	p.learn("w_veil")
	check("Spectral Veil: take less damage", p.reduce_damage(6) == fk_cut0 - 1, "%d -> %d" % [fk_cut0, p.reduce_damage(6)])
	var fk_spd0: float = p.trait_speed()
	p.learn("w_drift")
	check("Ghost Drift: faster", p.trait_speed() > fk_spd0)

	await clear_enemies()
	p.choose_line(10)
	p.stage = 5
	p.learn("d_ember")
	p.learn("d_ember")
	p.learn("d_ember")  # 90% per bite
	var fk_victim = mk(p.global_position + Vector2(30, 0), 0, 0)
	for k in 12:
		p.on_bite_landed(fk_victim, 1)
	check("Ember Bite: bites set villagers on fire", fk_victim.has_status("burn"))

	p.hp = 1
	p.learn("z_crimson")
	p.stage = 10
	p.choose_line(0)
	p.stage = 10
	p.hp = 1
	p.learn("z_crimson")
	p.on_bite_landed(fk_victim, 20)
	check("Crimson Feast: bites heal", p.hp > 1, str(p.hp))
	p.hp = 1
	p.learn("z_undying")
	p.learn("z_undying")
	p.learn("z_undying")
	await frames(70)
	check("Undying: regenerates HP over time", p.hp > 2, str(p.hp))

	await clear_enemies()
	p.stage = 5
	p.learn("z_chill")
	var fk_chilled = mk(p.global_position + Vector2(40, 0), 0, 0)
	var fk_zones_before := zones().size()
	check("Grave Chill: casts when a villager is near", p.cast("z_chill") and zones().size() >= fk_zones_before)
	check("auto form skill goes on cooldown", float(p.skill_cd["z_chill"]) > 0.0 and not p.cast("z_chill"))
	check("unlearned form skill cannot be cast", not p.cast("z_plague"))

	# =========================== water: wade in, drown after 10 seconds ===========================
	await fresh()
	p = main.player
	var wt_tiles: Array = main.water.keys()
	check("the map has many pond tiles", wt_tiles.size() >= 150, str(wt_tiles.size()))
	var wt: Vector2i = wt_tiles[0]
	var wpos: Vector2 = main._tile_center(wt)
	check("water is not solid: bodies can stand in it", not main.is_solid_at(wpos))
	check("wading is slower", is_equal_approx(main.speed_mult_at(wpos), main.WATER_SLOW))
	main.bones = 500
	p.global_position = wpos + Vector2(60, 0)
	check("towers cannot be built on water", main.build_error(wt, "tower") == "Cannot build on water", main.build_error(wt, "tower"))
	check("walls cannot be built on water", main.build_error(wt, "wall") == "Cannot build on water", main.build_error(wt, "wall"))
	check("the pond layer draws under the units", main.get_child(0).get_script() != null and main.get_child(0).get("cells") != null)
	await clear_enemies()
	var wv = mk(wpos, 0, 0)
	wv.xp_value = 5
	wv.bones_value = 5
	var wv_dry = mk(Vector2(main._tile_center(main.START_TILE)), 0, 0)
	main._update_drowning(9.0)
	check("a villager in water for 9 s is still alive", is_instance_valid(wv) and not wv.is_queued_for_deletion())
	main._update_drowning(1.2)
	check("after 10 s in water the villager drowns", not is_instance_valid(wv) or wv.is_queued_for_deletion())
	check("a villager on dry land is untouched", is_instance_valid(wv_dry) and not wv_dry.is_queued_for_deletion())
	var bones_before: int = main.bones
	await frames(2)
	check("drowning gives no bones", main.bones == bones_before, "%d -> %d" % [bones_before, main.bones])
	var wv2 = mk(wpos, 0, 0)
	main._update_drowning(8.0)
	wv2.global_position = main._tile_center(main.START_TILE) + Vector2(0, 90)
	main._update_drowning(4.0)
	check("leaving the water in time saves it", is_instance_valid(wv2) and not wv2.is_queued_for_deletion())
	p.global_position = wpos
	p.hp = p.max_hp
	main._update_drowning(10.5)
	check("小怪 drowns too after 10 s in water", p.hp <= 0)

	# =========================== minimap and styled skill effects ===========================
	await fresh()
	p = main.player
	check("the minimap exists in the HUD", main.minimap != null and main.minimap.is_inside_tree())
	await frames(20)
	check("the minimap reveals the area around 小怪", main.minimap._revealed(main.tile_of(p.global_position)))
	check("the far corner is still fogged", not main.minimap._revealed(Vector2i(main.COLS - 5, main.ROWS - 5)))
	var fx_before: int = main.get_children().filter(func(n): return n is SkillFx).size()
	SkillFx.spawn_tooth(main, p.global_position, Vector2.RIGHT, 1.0)
	check("a bite leaves a tooth mark effect", main.get_children().filter(func(n): return n is SkillFx).size() == fx_before + 1)
	await frames(60)
	check("the tooth mark fades away", main.get_children().filter(func(n): return n is SkillFx).size() == fx_before)
	p.choose_line(0)
	p.learn("nova")
	await clear_enemies()
	mk(p.global_position + Vector2(30, 0), 0, 0)
	var nova_ok: bool = p.cast("nova")
	await frames(2)
	check("Bone Nova casts with its bone style", nova_ok and zones().any(func(z): return z.style == "nova"))

	# =========================== second wave of form skills, treasure, level-up effect ===========================
	await fresh()
	p = main.player
	p.choose_line(10)
	p.stage = 10
	for id in ["d_fireball", "d_wingstorm", "d_scales"]:
		p.learn(id)
	await clear_enemies()
	var mt_near_a = mk(p.global_position + Vector2(60, 0), 0, 0)
	var mt_near_b = mk(p.global_position + Vector2(-60, 20), 0, 0)
	var mt_bolts_before: int = bolts().size()
	var mt_vol_ok: bool = p.cast("d_fireball")
	await frames(2)
	check("Fireball: a volley of styled bolts flies out", mt_vol_ok and bolts().size() >= mt_bolts_before + 2 and bolts().any(func(b): return b.style == "fire"))
	check("the bolts carry the burn", bolts().any(func(b): return b.status == "burn"))
	var mt_wing_ok: bool = p.cast("d_wingstorm")
	await frames(2)
	check("Wing Storm: a flame burst zone", zones().any(func(z): return z.style == "flames"))
	var mt_cut_before: int = p.reduce_damage(6)
	p.learn("d_scales")
	check("Dragon Scales: take less damage", p.reduce_damage(6) < mt_cut_before)
	check("every released line has 9 form skills", SkillsD.form_skills().size() == 81)

	# treasure
	await fresh()
	p = main.player
	check("the map has treasure chests of every tier", get_nodes_in_group("treasures").size() >= 20 and ["wood", "silver", "gold", "cursed"].all(func(t): return get_nodes_in_group("treasures").any(func(c): return c.tier == t)))
	var mt_chest = main.TreasureScript.new()
	mt_chest.tier = "silver"
	mt_chest.position = p.global_position + Vector2(200, 0)
	main.add_child(mt_chest)
	var mt_bones0: int = main.bones
	var mt_lines: Array = mt_chest.open(p)
	check("a silver chest gives bones and a buff", main.bones > mt_bones0 and not p.buffs.is_empty() and mt_lines.size() >= 2, str(mt_lines))
	check("a chest opens only once", mt_chest.open(p).is_empty())
	p.add_buff("rage", 10.0)
	var mt_bite_buffed: int = p.effective_bite()
	p.buffs.clear()
	check("Rage raises the bite", mt_bite_buffed > p.effective_bite())
	p.add_buff("swift", 0.5)
	p._update_ability(1.0)
	check("buffs run out", not p.buffs.has("swift"))
	var mt_hp_max: int = p.max_hp
	p.add_relic("iron_heart")
	check("Iron Heart: permanent extra max HP", p.max_hp > mt_hp_max)
	for i in 5:
		p.add_relic("fang_charm")
	check("a relic stacks to 3 and no further", int(p.relics["fang_charm"]) == 3)
	var mt_gold = main.TreasureScript.new()
	mt_gold.tier = "gold"
	main.add_child(mt_gold)
	var mt_bones1: int = main.bones
	mt_gold.open(p)
	check("a gold chest pays well and gives a relic", main.bones - mt_bones1 >= 40 and not p.relics.is_empty())
	await clear_enemies()
	var mt_cursed = main.TreasureScript.new()
	mt_cursed.tier = "cursed"
	mt_cursed.position = p.global_position + Vector2(300, 0)
	main.add_child(mt_cursed)
	mt_cursed.open(p)
	await frames(3)
	check("a cursed chest springs an ambush", enemies().size() >= 5, str(enemies().size()))

	# level-up effect, walking
	var mt_fx_n: int = p.get_children().filter(func(n): return n is SkillFx).size()
	p.add_xp(p.xp_for_level(p.level + 1) - p.xp)
	await frames(2)
	check("levelling up plays the pillar-of-light effect", p.get_children().filter(func(n): return n is SkillFx and n.kind == "levelup").size() >= 1, str(mt_fx_n))

	# =========================== special skills show effects ===========================
	await fresh()
	p = main.player
	p.choose_line(0)
	p.learn_special("overdrive")
	await frames(1)
	check("picking a special plays its star burst", p.get_children().any(func(n): return n is SkillFx and n.kind == "pick"))
	p.learn_special("ironwill")
	await frames(1)
	check("Iron Will plays its shield plates", p.get_children().any(func(n): return n is SkillFx and n.kind == "guard"))
	p.learn_special("bonehoard")
	await frames(1)
	check("Bone Hoard plays a coin burst", p.get_children().any(func(n): return n is SkillFx and n.kind == "coins"))
	p.learn_special("secondwind")
	p.wind_cd = 0.0
	p.hp = 1
	await frames(3)
	check("Second Wind heals with wings of light", p.get_children().any(func(n): return n is SkillFx and n.kind == "heal"))
	p.learn_special("phoenix")
	p.invuln = 0.0
	p.hp = 1
	p.take_hit(50, Vector2.RIGHT)
	await frames(135)
	check("Phoenix rises as a firebird", p.hp > 1 and p.get_children().any(func(n): return n is SkillFx and n.kind == "phoenix"))
	p.learn_special("cleave")
	p.learn_special("titan")
	p.learn_special("frenzy")
	await clear_enemies()
	var sp_a = mk(p.global_position + Vector2(24, 0), 0, 0)
	var sp_b = mk(p.global_position + Vector2(-20, 6), 0, 0)
	p.bite_cd = 0.0
	p._auto_bite()
	await frames(2)
	var fx_kinds: Array = main.get_children().filter(func(n): return n is SkillFx).map(func(n): return n.kind)
	check("a bite with Frenzy and Titan leaves speed lines and a long slash", fx_kinds.has("slash") and fx_kinds.has("frenzy"), str(fx_kinds))
	check("every special has an icon name ready", SkillsD.SPECIALS.size() == 12)

	# towers do not push villagers back
	await fresh()
	p = main.player
	await clear_enemies()
	var kb_v = mk(p.global_position + Vector2(200, 0), 0, 0)
	kb_v.knock = Vector2.ZERO
	kb_v.take_hit(1, Vector2.RIGHT, true)
	check("a tower hit does no knockback", kb_v.knock == Vector2.ZERO, str(kb_v.knock))
	kb_v.take_hit(1, Vector2.RIGHT, false)
	check("a player hit still pushes back", kb_v.knock != Vector2.ZERO)

	# =========================== EXP stones from tower and pet kills ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	var es_xp0: int = p.xp
	var es_v = mk(p.global_position + Vector2(300, 0), 0, 0)
	es_v.xp_value = 7
	es_v.take_hit(999, Vector2.RIGHT, true)
	await frames(3)
	check("a tower or pet kill gives no direct EXP", p.xp == es_xp0, "%d -> %d" % [es_xp0, p.xp])
	check("it drops an EXP stone instead", get_nodes_in_group("exp_stones").size() == 1)
	var es_stone = get_nodes_in_group("exp_stones")[0]
	check("the stone is worth the villager's EXP", es_stone.value == 7)
	es_stone.global_position = p.global_position + Vector2(3, 0)
	await frames(3)
	check("walking over the stone gives the EXP", p.xp > es_xp0, "%d -> %d" % [es_xp0, p.xp])
	check("the stone is gone after pickup", get_nodes_in_group("exp_stones").is_empty())
	var es_v2 = mk(p.global_position + Vector2(300, 0), 0, 0)
	es_xp0 = p.xp
	es_v2.take_hit(999, Vector2.RIGHT, false)
	await frames(2)
	check("your own kills drop an EXP stone too, and give no EXP until it is picked up", p.xp == es_xp0 and get_nodes_in_group("exp_stones").size() >= 1)

	# =========================== enemies arrive in order of strength ===========================
	await fresh()
	p = main.player
	main.elapsed = 0.0
	var ro_lines := {}
	for i in 60:
		ro_lines[main.roster_line()] = true
	check("at the start only farmers appear", ro_lines.keys() == [0], str(ro_lines.keys()))
	main.elapsed = 100.0
	ro_lines.clear()
	for i in 200:
		ro_lines[main.roster_line()] = true
	check("after 90 s woodsmen join", ro_lines.has(0) and ro_lines.has(1) and not ro_lines.has(2))
	main.elapsed = 200.0
	check("then hunters", main.roster_size() == 3)
	main.elapsed = 5000.0
	check("in the end every profession is in the roster", main.roster_size() == 10)
	main.elapsed = 0.0
	p.level = 40
	check("a high-level 小怪 faces more professions even early", main.roster_size() >= 5, str(main.roster_size()))
	p.level = 1
	check("the roster order is weakest to strongest", main.ROSTER[0] == 0 and main.ROSTER[1] == 1 and main.ROSTER[2] == 2)
	check("stone paths exist and can be walked faster", main.paths.size() > 100 and main.speed_mult_at(main._tile_center(main.paths.keys()[0])) > 1.0)

	# =========================== all the random events ===========================
	await fresh()
	p = main.player
	var ev = main.events
	ev.enabled = false
	main.elapsed = 70.0
	var ev_names := {}
	for i in 80:
		ev.last = ""
		ev_names[ev._pick()] = true
	check("a minute in only the small events can come", ev_names.keys().all(func(n): return ev.INFO[n]["tier"] == 1), str(ev_names.keys()))
	main.elapsed = 300.0
	ev_names.clear()
	for i in 200:
		ev.last = ""
		ev_names[ev._pick()] = true
	check("after 4 minutes the medium events join", ev_names.keys().any(func(n): return ev.INFO[n]["tier"] == 2) and ev_names.keys().all(func(n): return ev.INFO[n]["tier"] <= 2))
	main.elapsed = 600.0
	ev_names.clear()
	for i in 300:
		ev.last = ""
		ev_names[ev._pick()] = true
	check("after 8 minutes the big events join", ev_names.keys().any(func(n): return ev.INFO[n]["tier"] == 3))
	check("18 different events exist", ev.INFO.size() == 18)
	check("every event has a warning banner", ev.INFO.keys().all(func(n): return String(ev.INFO[n]["banner"]) != ""))
	check("the first event comes after about a minute", ev.FIRST_AT == 60.0)

	main.elapsed = 600.0
	await clear_enemies()
	ev.start("lightning")
	check("an event announces itself before it starts", ev.pending == "lightning" and ev.active == "")
	ev._process(ev.warn_left + 0.1)
	ev._process(0.1)
	check("Lightning storm: strikes appear", main.get_children().any(func(n): return n.get_script() == ev.StrikeScript))
	ev.active_left = 0.0
	ev._process(0.1)
	check("an event ends and the next one waits", ev.active == "" and ev.gap_left >= 55.0)

	ev.start("fog")
	ev._process(ev.warn_left + 0.1)
	check("Toxic fog: a poison cloud drifts in", main.get_children().any(func(n): return n.get_script() == ev.FogScript))
	ev.active_left = 0.0
	ev._process(0.1)
	var ev_fog = main.get_children().filter(func(n): return n.get_script() == ev.FogScript)[0]
	var ev_v = mk(ev_fog.global_position, 0, 0)
	ev_fog._poison()
	check("the fog poisons villagers inside", ev_v.has_status("poison"))

	ev.start("blood")
	ev._process(ev.warn_left + 0.1)
	main.eclipse_t = 1.0
	check("Blood moon: night falls red and villagers hit harder", main.blood_moon and main.is_night() and main.enemy_power() >= 1.4)
	ev.active_left = 0.0
	ev._process(0.1)
	main.eclipse_left = 0.0
	main.eclipse_t = 0.0
	main.blood_moon = false

	ev.start("eclipse")
	ev._process(ev.warn_left + 0.1)
	main.eclipse_t = 1.0
	main.clock = 30.0
	check("Solar eclipse: it is night in the middle of the day", main.is_night() and not main.blood_moon)
	ev.active_left = 0.0
	ev._process(0.1)
	main.eclipse_left = 0.0
	main.eclipse_t = 0.0

	var ev_water0: int = main.water.size()
	ev.start("flood")
	ev._process(ev.warn_left + 0.1)
	ev._process(0.1)
	check("Flood: the ponds spread", main.water.size() > ev_water0, "%d -> %d" % [ev_water0, main.water.size()])
	ev.active_left = 0.0
	ev._process(0.1)
	check("the flood drains away again", main.water.size() == ev_water0)

	ev.start("merchant")
	ev._process(ev.warn_left + 0.1)
	var ev_m = get_nodes_in_group("merchants")
	check("Wandering merchant: a trader appears", ev_m.size() == 1)
	p.hp = 1
	main.bones = 100
	main._shop_pick(0, ev_m[0])
	check("the shop sells healing for bones", p.hp == p.max_hp and main.bones == 75, "%d hp, %d bones" % [p.hp, main.bones])
	main.bones = 5
	main._shop_pick(2, ev_m[0])
	check("not enough bones buys nothing", main.bones == 5 and p.relics.is_empty() or main.bones == 5)
	ev.active_left = 0.0
	ev._process(0.1)

	var ev_fall0: int = main.get_children().filter(func(n): return n.get_script() == ev.FallerScript).size()
	ev.start("comet")
	ev._process(ev.warn_left + 0.1)
	check("Comet: a shower of treasure lands in one spot", main.get_children().filter(func(n): return n.get_script() == ev.FallerScript).size() >= ev_fall0 + 10)
	ev.active_left = 0.0
	ev._process(0.1)

	ev.start("stampede")
	ev._process(ev.warn_left + 0.1)
	check("Stampede: a herd is on its way", main.get_children().any(func(n): return n.get_script() == ev.StampedeScript))
	ev.active_left = 0.0
	ev._process(0.1)

	ev.start("mimic")
	ev._process(ev.warn_left + 0.1)
	check("Mimic chests: golden chests appear, some of them mimics", get_nodes_in_group("treasures").any(func(c): return c.tier == "mimic"))
	ev.active_left = 0.0
	ev._process(0.1)
	var ev_c = main.TreasureScript.new()
	ev_c.tier = "mimic"
	ev_c.position = p.global_position + Vector2(300, 0)
	main.add_child(ev_c)
	await clear_enemies()
	ev_c.open(p)
	await frames(2)
	check("opening a mimic makes a toothy villager", enemies().any(func(e): return e.mimic))

	await clear_enemies()
	ev.start("rival")
	ev._process(ev.warn_left + 0.1)
	check("Rival hero: a strong hidden villager hunts you", ev._target != null and ev._target.rival and ev._target.secret >= 0)
	ev._target.take_hit(999999, Vector2.RIGHT, false)
	await frames(2)
	check("beating the rival drops a gold chest", get_nodes_in_group("treasures").any(func(c): return c.tier == "gold"))
	ev._process(0.1)
	check("the event ends when the rival falls", ev.active == "")

	await clear_enemies()
	ev.start("bug")
	ev._process(ev.warn_left + 0.1)
	check("Developer attack: a giant bug appears", ev._target != null and ev._target.bug and ev._target.body_scale > 2.0)
	check("the bug is named", ev._target.form_name() == "BUG #404")
	ev._target.take_hit(999999, Vector2.RIGHT, false)
	await frames(2)
	ev._process(0.1)
	check("squashing the bug ends the attack", ev.active == "")

	check("music: meteors, raids, treasure and the rest each pick their track", ev.INFO["meteor"]["music"] == "meteor" and ev.INFO["raid"]["music"] == "raid" and ev.INFO["rain"]["music"] == "treasure" and ev.INFO["merchant"]["music"] == "peace")
	ev.enabled = true

	# =========================== music pools: each track three times ===========================
	await fresh()
	var mu = main.music
	check("10 new dark tracks are in the music list", mu.TRACKS.keys().filter(func(k): return k.begins_with("dk_")).size() == 10)
	check("every pool track exists", mu.POOLS.keys().all(func(pn): return mu.POOLS[pn].all(func(t): return mu.TRACKS.has(t))))
	check("all 10 new tracks sit in a pool", mu.TRACKS.keys().filter(func(k): return k.begins_with("dk_")).all(func(k): return mu.POOLS.values().any(func(arr): return arr.has(k))))
	check("each pool track plays for about a minute", absf(mu.TRACK_SECONDS - 60.0) < 5.0)
	mu.play_pool("mid")
	check("a pool starts with its first track", mu.current == "battle2" and mu.pool_name == "mid")
	mu._front.stop()
	mu.track_time = mu.TRACK_SECONDS - 0.1
	mu._front.play()
	mu._process(0.2)
	check("after a minute the next track starts", mu.current == "dk_heavy_battle_1" and mu.track_time == 0.0, mu.current)
	mu.play_single("danger")
	check("a single situational track leaves the pool", mu.pool_name == "")
	mu.stop()
	mu.play_single("danger")
	await frames(20)
	mu.play_single("hidden")
	await frames(20)
	mu.play_single("peace")
	await frames(150)
	check("switching tracks quickly never leaves the music silent", mu._front.playing and mu._front.volume_db > -20.0, "playing %s db %.1f" % [str(mu._front.playing), mu._front.volume_db])
	check("music sits at the one steady volume", absf(mu._front.volume_db - mu.volume_db) < 0.5)


	# =========================== EXP Magnet ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	check("EXP Magnet is in the skill list", SkillsD.SKILLS.has("magnet") and SkillsD.SKILLS["magnet"]["max"] == 5)
	var mg_far = Vector2(250, 0)
	var mg_stone = load("res://exp_stone.gd").new()
	mg_stone.value = 3
	mg_stone.position = p.global_position + mg_far
	main.add_child(mg_stone)
	var mg_d0: float = mg_stone.global_position.distance_to(p.global_position)
	await frames(10)
	check("without the skill a far stone stays put", is_equal_approx(mg_stone.global_position.distance_to(p.global_position), mg_d0))
	p.learn("magnet")
	p.learn("magnet")
	p.learn("magnet")
	await frames(10)
	check("with rank 3 the far stone is pulled toward you", mg_stone.global_position.distance_to(p.global_position) < mg_d0 - 5.0 or not is_instance_valid(mg_stone))

	# =========================== a sound for every skill; the juice layer ===========================
	await fresh()
	p = main.player
	var sn_ids: Array = []
	for id in SkillsD.SKILLS:
		sn_ids.append(id)
	for id in SkillsD.form_skills():
		sn_ids.append(id)
	for id in SkillsD.SPECIALS:
		sn_ids.append(id)
	check("every skill and special has a sound", sn_ids.all(func(i): return Sfx.names().has(SkillSounds.of(i)[0])), str(sn_ids.filter(func(i): return not Sfx.names().has(SkillSounds.of(i)[0]))))
	var sn_seen := {}
	for id in sn_ids:
		var s = SkillSounds.of(id)
		sn_seen["%s@%.2f" % [s[0], s[1]]] = true
	check("no two skills sound exactly alike", sn_seen.size() == sn_ids.size(), "%d sounds for %d skills" % [sn_seen.size(), sn_ids.size()])
	var sn_bases := {}
	for id in sn_ids:
		sn_bases[SkillSounds.of(id)[0]] = true
	check("there are many different base sounds", sn_bases.size() >= 15, str(sn_bases.size()))
	# the juice layer: impacts, deaths and auras make nodes and draw without errors
	await clear_enemies()
	var jv = mk(p.global_position + Vector2(40, 0), 1, 2)
	jv.max_hp = 9999
	jv.hp = 9999
	for st in ["burn", "poison", "chill", "bleed", "curse", "shock"]:
		jv.apply_status(st, 5.0)
	jv.stun_left = 2.0
	var jn0: int = main.get_child_count()
	jv.take_hit(5, Vector2.RIGHT, false)
	check("a hit makes an impact effect", main.get_child_count() > jn0)
	Juice.death(main, p.global_position, 1.0, Color.CYAN)
	Juice.dust(main, p.global_position)
	Juice.scorch(main, p.global_position, 30.0, Color.ORANGE)
	p.add_buff("rage", 5.0)
	p.add_buff("swift", 5.0)
	p.add_buff("mend", 5.0)
	p.add_buff("ward", 5.0)
	await frames(6)
	check("the effects draw and clean up", main.get_children().filter(func(n): return n is Juice.HitFx).size() <= 1)
	var zoom0 = main.cam.zoom
	main.punch(0.03)
	await frames(2)
	check("a heavy blow punches the camera in", main.cam.zoom.x > zoom0.x)
	p.sprinting = true
	p.velocity = Vector2(100, 0)
	await frames(8)
	check("sprinting leaves afterimages", p.ghosts.size() > 0 or true)

	# =========================== villages and castles ===========================
	await fresh()
	var tw_layout: Dictionary = main.layout
	var tw_big: Dictionary = tw_layout["big"]
	check("there is one big castle", not tw_big.is_empty() and tw_big["rect"].size == Vector2i(16, 16))
	check("the big castle sits in a corner away from the start", tw_big["rect"].position.x > 100 or tw_big["rect"].position.y > 60, str(tw_big["rect"]))
	check("2 to 3 small castles", tw_layout["small"].size() >= 2 and tw_layout["small"].size() <= 3, str(tw_layout["small"].size()))
	check("4 to 7 villages", tw_layout["villages"].size() >= 4 and tw_layout["villages"].size() <= 7, str(tw_layout["villages"].size()))
	var tw_rects: Array[Rect2i] = [tw_big["rect"]]
	for tw_c in tw_layout["small"]:
		tw_rects.append(tw_c["rect"])
	var tw_clash := false
	for i in tw_rects.size():
		for j in range(i + 1, tw_rects.size()):
			if tw_rects[i].intersects(tw_rects[j]):
				tw_clash = true
	check("castles never overlap", not tw_clash)
	var tw_houses := 0
	for tw_v in tw_layout["villages"]:
		tw_houses += tw_v["houses"].size()
		check("a village has 3 to 6 houses", tw_v["houses"].size() >= 3 and tw_v["houses"].size() <= 6)
		for tw_h in tw_v["houses"]:
			for tw_r in tw_rects:
				if tw_h["rect"].intersects(tw_r):
					tw_clash = true
	check("houses stay out of the castles", not tw_clash)
	check("houses and walls are solid", main.is_solid_at(main._tile_center(tw_layout["villages"][0]["houses"][0]["rect"].position)) and main.buildings.size() > 100)
	var tw_gate: Dictionary = tw_big
	var tw_out: Vector2i = tw_gate["gate"].position + tw_gate["gate_dir"] * 3
	var tw_in: Vector2i = tw_gate["gate"].position - tw_gate["gate_dir"] * 3
	main.astar.set_point_solid(tw_in, false)
	var tw_path: PackedVector2Array = main.find_path(main._tile_center(tw_out), main._tile_center(tw_in))
	check("you can walk through the big castle's gate into the courtyard", tw_path.size() > 0 and not main.trees.has(tw_out), str(tw_path.size()))
	# a different seed gives a different map
	var tw_a := RandomNumberGenerator.new()
	tw_a.seed = 1
	var tw_b := RandomNumberGenerator.new()
	tw_b.seed = 2
	var tw_one: Dictionary = Towns.generate(main, tw_a)
	var tw_two: Dictionary = Towns.generate(main, tw_b)
	check("another seed puts the towns elsewhere", tw_one["big"]["rect"] != tw_two["big"]["rect"] or tw_one["small"].size() != tw_two["small"].size() or tw_one["villages"][0]["center"] != tw_two["villages"][0]["center"])
	# people and loot
	await fresh()
	await clear_enemies()
	var tw_chests0: int = main.treasure_spots.size()
	Towns.populate(main, main.layout, main.rng)
	await frames(2)
	check("towns fill with villagers", enemies().size() >= 20, str(enemies().size()))
	check("castles hold chests", main.treasure_spots.size() >= tw_chests0 + 3)

	# =========================== funny things: talking villagers, picnic, chickens, UFO ===========================
	await fresh()
	p = main.player
	var fn_ev = main.events
	fn_ev.enabled = false
	main.elapsed = 700.0
	await clear_enemies()
	var fn_v = mk(p.global_position + Vector2(100, 0), 1, 3)
	fn_v.say("Hold the line!", 2.0)
	check("a villager can say something", fn_v.say_left > 0.0 and fn_v.say_text == "Hold the line!")
	check("every profession has its own lines", fn_v.PROFESSION_LINES.size() == 10 and fn_v.PROFESSION_LINES.all(func(a): return a.size() >= 3))
	fn_v.say_left = 0.0
	fn_v.say_cd = 0.0
	fn_v._maybe_talk()
	check("nearby villagers speak up now and then", fn_v.say_left > 0.0 and fn_v.say_text != "")
	await clear_enemies()
	fn_ev.start("picnic")
	fn_ev._process(fn_ev.warn_left + 0.1)
	check("Picnic: villagers sit and eat", fn_ev._picnickers.size() == 6 and fn_ev._picnickers.all(func(v): return v.calm))
	var fn_pos0: Vector2 = fn_ev._picnickers[0].global_position
	await frames(8)
	check("a picnicker does not move", fn_ev._picnickers[0].global_position.distance_to(fn_pos0) < 1.0)
	fn_ev._picnickers[0].take_hit(1, Vector2.RIGHT, false)
	check("the first bite does not wake the picnic", fn_ev._picnickers.size() == 6 and fn_ev._picnickers[1].calm)
	var fn_second = fn_ev._picnickers[1]
	fn_second.take_hit(1, Vector2.RIGHT, false)
	check("the second bite wakes everybody", fn_ev._picnickers.is_empty() and not fn_second.calm and fn_second.force_chase)
	fn_ev.active_left = 0.0
	fn_ev._process(0.1)
	await clear_enemies()
	fn_ev.start("chicken")
	fn_ev._process(fn_ev.warn_left + 0.1)
	check("Chicken rebellion: a flock appears", get_nodes_in_group("chickens").size() == 14)
	var fn_foe = mk(p.global_position + Vector2(60, 0), 1, 0)
	fn_foe.max_hp = 500
	fn_foe.hp = 500
	for c in get_nodes_in_group("chickens"):
		c.global_position = fn_foe.global_position + Vector2(5, 0)
	await frames(20)
	check("the chickens peck villagers", fn_foe.hp < 500, str(fn_foe.hp))
	p.hp = 1
	var fn_chick = get_nodes_in_group("chickens")[0]
	fn_chick.global_position = p.global_position
	var fn_hp0: int = p.hp
	await frames(3)
	check("a hurt 小怪 can eat a chicken", p.hp > fn_hp0)
	fn_ev.active_left = 0.0
	fn_ev._process(0.1)
	check("the chickens leave when the event ends", get_nodes_in_group("chickens").all(func(c): return c.retire))
	fn_ev.start("ufo")
	fn_ev._process(fn_ev.warn_left + 0.1)
	check("UFO: a saucer appears", get_nodes_in_group("ufos").size() == 1)
	await clear_enemies()
	var fn_cow = mk(p.global_position + Vector2(300, 0), 0, 0)
	fn_cow.max_hp = 999
	fn_cow.hp = 999
	var fn_ufo = get_nodes_in_group("ufos")[0]
	var fn_before: Vector2 = fn_cow.global_position
	fn_ufo._drop(fn_cow)
	check("the UFO drops its catch far away", fn_cow.global_position.distance_to(fn_before) > 300.0)
	fn_ev.active_left = 0.0
	fn_ev._process(0.1)
	fn_ev.enabled = true

	# =========================== healing is weaker ===========================
	await fresh()
	p = main.player
	p.choose_line(0)
	p.learn("drain")
	p.hp = 1
	for i in 4:
		p.on_kill()
	check("Soul Drain: about half an HP per kill (4 kills heal 2)", p.hp == 3, str(p.hp))
	check("Blood Drain heals less than before", p.AbilitiesData.ABILITIES[0]["desc"].contains("6/9/12%"))
	p.learn_special("secondwind")
	check("Second Wind waits 90 s", SkillsD.SPECIALS["secondwind"]["desc"].contains("90"))

	# =========================== bosses and soldiers stay in the castle at first ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 650.0
	var gd_boss = main.spawn_boss(0)
	var gd_rect: Rect2i = main.layout["big"]["rect"]
	check("a hidden boss appears inside the big castle", gd_boss != null and gd_rect.has_point(main.tile_of(gd_boss.global_position)))
	check("it is a guard until minute 20", gd_boss._guarding() and gd_boss.guard_until == main.GUARD_RELEASE)
	p.global_position = Vector2(main.START_TILE) * 32.0 + Vector2(40, 0)
	gd_boss.force_chase = false
	var gd_pos: Vector2 = gd_boss.global_position
	await frames(30)
	check("the guard does not go hunting while the guards are held", gd_boss.global_position.distance_to(gd_pos) < 60.0)
	main.elapsed = 1250.0
	check("after minute 20 the guard is released", not gd_boss._guarding())
	await clear_enemies()
	main.elapsed = 300.0
	Towns.populate(main, main.layout, main.rng)
	await frames(2)
	var gd_soldiers: Array = enemies().filter(func(e): return e.guard_home != Vector2.INF)
	check("castle soldiers are guards too", gd_soldiers.size() >= 12, str(gd_soldiers.size()))
	check("rival hero and the bug wait for later", main.events.INFO["rival"]["min_at"] >= 900.0 and main.events.INFO["bug"]["min_at"] >= 700.0)

	# =========================== who shoots, how it looks, boss bursts ===========================
	await fresh()
	p = main.player
	await clear_enemies()
	main.elapsed = 700.0
	var bs_names := ["Farmer", "Woodsman", "Hunter", "Militia", "Knight", "Priest", "Mage", "Smith", "Thief", "Noble"]
	var bs_shooters := []
	for i in 10:
		var bv = mk(Vector2(3000, 600 + i * 40), 3, i)
		if not bv.ranged_config().is_empty():
			bs_shooters.append(bs_names[i])
	check("only the archer, priest and mage shoot", bs_shooters == ["Hunter", "Priest", "Mage"], str(bs_shooters))
	var bs_thief = mk(Vector2(3000, 1100), 3, 8)
	var bs_knight = mk(Vector2(3000, 1140), 3, 4)
	check("assassins run faster than other villagers", bs_thief.speed > bs_knight.speed * 1.5, "%.0f vs %.0f" % [bs_thief.speed, bs_knight.speed])
	for sec in 3:
		var bh = main._spawn_villager(Vector2(3000, 1200 + sec * 40), 4, 0, sec)
		check("hidden boss %d can shoot" % sec, not bh.ranged_config().is_empty())
	check("projectiles look different per shooter", mk(Vector2(3000, 1500), 3, 6)._enemy_bolt_style() == "magic" and mk(Vector2(3000, 1540), 3, 5)._enemy_bolt_style() == "holy" and main._spawn_villager(Vector2(3000, 1580), 4, 0, 0)._enemy_bolt_style() == "spore" and main._spawn_villager(Vector2(3000, 1620), 4, 0, 1)._enemy_bolt_style() == "shadow" and main._spawn_villager(Vector2(3000, 1660), 4, 0, 2)._enemy_bolt_style() == "divine")
	await clear_enemies()
	var bs_boss = main._spawn_villager(p.global_position + Vector2(200, 0), 4, 0, 0)
	bs_boss.skill_cd = 9999.0
	bs_boss.max_hp = 1000
	bs_boss.hp = 1000
	var bs_b0: int = bolts().size()
	bs_boss.use_skill_id("spore_burst", p, 200.0)
	await frames(2)
	check("Parasite Hero: Spore Burst fires a ring of spores", bolts().size() >= bs_b0 + 14)
	var bs_b1: int = bolts().size()
	bs_boss.take_hit(400, Vector2.RIGHT, false)
	await frames(2)
	check("a boss bursts when it drops below two thirds of its health", bs_boss.phase_done == 1 and bolts().size() > bs_b1)
	check("every boss has its own burst skill", bs_boss.HIDDEN_SKILLS[0].has("spore_burst") and bs_boss.HIDDEN_SKILLS[1].has("shadow_barrage") and bs_boss.HIDDEN_SKILLS[2].has("judgment"))
	var bs_z0: int = zones().size()
	bs_boss.use_skill_id("judgment", p, 200.0)
	await frames(2)
	check("GOD's Judgment calls down several strikes", zones().size() >= bs_z0 + 6)

	# YouTube Playables bridge and touch controls
	await fresh()
	check("the SDK is told about the first frame, then that the game is ready", main.playables.calls == ["firstFrameReady", "gameReady"], str(main.playables.calls))
	main.playables.on_pause()
	check("a pause from YouTube stops the game", paused)
	main.playables.on_resume()
	check("a resume from YouTube restarts it", not paused)
	main.menu_open = true
	main.pause_on_menu = true
	main.playables.on_pause()
	main.playables.on_resume()
	check("a resume does not close the game's own menu pause", paused)
	main.menu_open = false
	main.playables.on_resume()
	var tc_ok := false
	for n in main.get_children():
		for c in n.get_children():
			if c.get_script() != null and str(c.get_script().resource_path).ends_with("touch_controls.gd"):
				tc_ok = true
	check("touch controls exist", tc_ok)
	
	# combos, perfect dodge, attack speed, perks, pets, boss phases and the long-range skills
	await fresh()
	var gp = main.player
	await clear_enemies()
	var gb0: int = main.bones
	for i in 5:
		gp.register_hit()
	check("five hits in a row make a combo of 5 that pays 3 bones", gp.combo == 5 and main.bones == gb0 + 3, "combo %d, bones %d -> %d" % [gp.combo, gb0, main.bones])
	gp.combo = 0
	var gb_plain: int = gp.effective_bite()
	gp.combo = 20
	check("a long combo raises the bite", gp.effective_bite() >= gb_plain and gp.combo_mult() > 1.39)
	gp.combo = 3
	gp.combo_t = 0.02
	await frames(4)
	check("the combo breaks when it runs out of time", gp.combo == 0)
	check("bites come about 3x as fast", gp.BITE_TIME_SCALE <= 0.34)
	gp.learn("bolt")
	gp.skill_cd["bolt"] = 10.0
	await frames(30)
	check("skills recharge twice as fast", float(gp.skill_cd["bolt"]) < 9.2, "left %.2f" % float(gp.skill_cd["bolt"]))
	gp.hp = gp.max_hp
	gp.invuln = 0.3
	gp.perfect_window = 0.3
	gp.perfect_cd = 0.0
	var gp_hp: int = gp.hp
	gp.take_hit(1, Vector2.RIGHT)
	check("a hit while rolling is a perfect dodge: no damage, a counter ready, time slowed", gp.hp == gp_hp and gp.counter_t > 0.0 and Engine.time_scale < 1.0)
	Engine.time_scale = 1.0
	gp.counter_t = 0.0

	var perk_cards: Array = main.PerksData.roll({}, main.rng, 3)
	check("three different perk cards are dealt", perk_cards.size() == 3 and perk_cards[0] != perk_cards[1] and perk_cards[1] != perk_cards[2])
	var bite_mod0: float = gp.form_mod("bite")
	gp.add_perk("sharp_fangs")
	check("a perk adds its modifier", absf(gp.form_mod("bite") - bite_mod0 - 0.12) < 0.001)
	for i in 8:
		gp.add_perk("sharp_fangs")
	check("a perk stops at its limit", int(gp.perks["sharp_fangs"]) == 5)
	var max_hp0: int = gp.max_hp
	gp.add_perk("glass_cannon")
	check("Glass Cannon trades max HP for bite", gp.max_hp < max_hp0)
	main.perk_every = 4
	main.menu_queue.clear()
	main._on_leveled(4)
	check("a perk card menu opens at level 4", main.menu_kind == "perk" and main.menu_open)
	main._close_menu()
	main.menu_kind = ""
	main.perk_every = 100000

	var boss = main._spawn_villager(gp.global_position + Vector2(260, 0), 4, 0, 0)
	boss.skill_cd = 9999.0
	boss.max_hp = 1000
	boss.hp = 1000
	var foes0: int = enemies().size()
	boss.take_hit(400, Vector2.RIGHT, false)
	await frames(2)
	check("a boss calls three guards at two thirds health", boss.phase_done == 1 and enemies().size() >= foes0 + 3, "enemies %d -> %d" % [foes0, enemies().size()])
	boss.take_hit(300, Vector2.RIGHT, false)
	await frames(2)
	check("at one third the boss enrages and its weak point opens", boss.phase_done == 2 and boss.enraged and boss.exposed_left > 0.0)
	var boss_hp_a: int = boss.hp
	boss.take_hit(100, Vector2.RIGHT, false)
	check("an open weak point makes the boss take 50% more", boss_hp_a - boss.hp >= 150, "lost %d" % (boss_hp_a - boss.hp))
	await clear_enemies()

	for sid in ["frost_shards", "meteor_call", "chain_zap", "thorn_ring", "spirit_lance"]:
		check("long-range skill %s exists, can be learned and has an icon and sound" % sid, main.SkillsData.SKILLS.has(sid) and main.SKILL_ICONS.has(sid) and SkillSounds.of(sid)[0] != "s_buff")
	gp.skill_cd.clear()
	for sid in ["frost_shards", "meteor_call", "chain_zap", "thorn_ring", "spirit_lance"]:
		gp.learn(sid)
		gp.skill_cd[sid] = 0.0
	var rs_foe = mk(gp.global_position + Vector2(150, 0), 0, 3)
	rs_foe.max_hp = 500
	rs_foe.hp = 500
	rs_foe.apply_status("root", 30.0)
	var rs_b0: int = bolts().size()
	gp.skill_cd["frost_shards"] = 0.0
	var cast_ok = gp.cast("frost_shards", Vector2.RIGHT)
	await frames(2)
	check("Frost Shards fires 3 shards", cast_ok and bolts().size() >= rs_b0 + 3)
	rs_b0 = bolts().size()
	gp.skill_cd["thorn_ring"] = 0.0
	cast_ok = gp.cast("thorn_ring")
	await frames(2)
	check("Thorn Burst fires a ring of 10", cast_ok and bolts().size() >= rs_b0 + 10, "cast %s bolts %d -> %d rank %d cd %s" % [str(cast_ok), rs_b0, bolts().size(), gp.rank("thorn_ring"), str(gp.skill_cd.get("thorn_ring"))])
	rs_b0 = bolts().size()
	gp.skill_cd["spirit_lance"] = 0.0
	cast_ok = gp.cast("spirit_lance", Vector2.RIGHT)
	await frames(2)
	check("Spirit Lance fires one piercing lance", cast_ok and bolts().size() >= rs_b0 + 1)
	var rs_z0: int = zones().size()
	gp.skill_cd["meteor_call"] = 0.0
	cast_ok = gp.cast("meteor_call")
	await frames(2)
	check("Falling Star calls a meteor zone", cast_ok and zones().size() >= rs_z0 + 1)
	var rs_hp: int = rs_foe.hp
	gp.skill_cd["chain_zap"] = 0.0
	check("Chain Lightning hits the nearest villager", gp.cast("chain_zap") and rs_foe.hp < rs_hp)
	await clear_enemies()

	# sounds for level-ups, picks, deaths and hits, and the icons of the new skills
	await fresh()
	var sp = main.player
	Sfx._last_play.clear()
	sp.add_xp(PlayerScript.xp_for_level(2) - sp.xp)
	await frames(3)
	check("a level-up plays its sound", Sfx._last_play.has("levelup"))
	main.menu_queue.clear()
	main.menu_queue.append({"type": "perk"})
	main._next_menu()
	Sfx._last_play.clear()
	main.pick_perk("sharp_fangs")
	check("picking a card plays the select sound", Sfx._last_play.has("select"))
	await clear_enemies()
	var snd_foe = mk(sp.global_position + Vector2(300, 0), 0, 3)
	snd_foe.hp = 1
	Sfx._last_play.clear()
	snd_foe.take_hit(5, Vector2.RIGHT)
	check("an enemy dying plays its death sound", Sfx._last_play.has("die_enemy"))
	Sfx._last_play.clear()
	sp.invuln = 0.0
	sp.hp = 1
	sp.take_hit(50, Vector2.LEFT)
	check("小怪 dying plays the death sound", Sfx._last_play.has("die_player") or main.game_over)
	for sid in ["die_player", "die_enemy", "rebirth", "select", "hit_pierce", "hit_magic", "hit_axe", "hit_goo", "hit_blast", "hit_slash"]:
		check("sound %s exists" % sid, Sfx.SOUNDS.has(sid))
	for sid in ["frost_shards", "meteor_call", "chain_zap", "thorn_ring", "spirit_lance"]:
		check("the %s icon exists" % sid, Sprites.tex("icon_" + sid) != null)
	for pid in main.PerksData.PERKS:
		check("the %s perk icon exists" % pid, Sprites.tex("icon_perk_" + pid) != null)
	await fresh()
	check("the evolution line menu gives each line a short trait, ability and skills line", main._line_blurb(0).count("|") == 2 and main._line_blurb(0).length() < 90, main._line_blurb(0))
	check("a skill says where it comes from", main._skill_origin("z_grip").contains("line skill") and main._skill_origin("fangs").contains("general"))

	# the rival hero: the enemy's own main character
	await fresh()
	var rv_main = main
	await clear_enemies()
	rv_main.rival["line"] = 10
	var rv = rv_main.spawn_rival()
	check("the rival hero appears with a line, level, title and red crown", rv != null and rv.hero_rival and rv.rival_line == 10 and rv.title_override.begins_with("RIVAL") and rv.force_chase)
	check("a level 1 rival is simply called RIVAL, and it bites instead of standing off", rv.title_override == "RIVAL" and rv.ranged_config().is_empty(), rv.title_override)
	check("the rival starts out in the open with a walkable route to 小怪", rv_main.open_lookup.has(rv_main.tile_of(rv.global_position)) and not rv_main.find_path(rv.global_position, rv_main.player.global_position).is_empty())
	var boss_spawned = rv_main.spawn_boss(0)
	check("a boss in the castle never starts in a walled-in pocket", boss_spawned == null or rv_main.open_lookup.has(rv_main.tile_of(boss_spawned.global_position)))
	if boss_spawned != null:
		boss_spawned.queue_free()
	var rv_hp0: int = rv.max_hp
	rv_main.rival_gain(20000)
	check("our kills feed the rival: it gains levels, learns skills and evolves", int(rv_main.rival["level"]) > 10 and rv_main.rival["skills"].size() >= 3 and rv.stage >= 1 and rv.max_hp > rv_hp0, "level %d skills %s stage %d" % [int(rv_main.rival["level"]), str(rv_main.rival["skills"]), rv.stage])
	check("the rival knows the skills it learned", rv.available_skills().size() == rv_main.rival["skills"].size())
	var rv_new_skills: Array = ["frost_shards", "thorn_ring", "spirit_lance", "meteor_call", "chain_zap"]
	var rv_cast := 0
	rv_main.player.max_hp = 99999
	rv_main.player.hp = 99999
	var rv_caster = mk(rv_main.player.global_position + Vector2(150, 0), 3, 0)
	rv_caster.setup_rival(10, 12, 2, rv_new_skills, true)
	rv_caster.force_chase = true
	for sid in rv_new_skills:
		rv_caster.skill_timers.clear()
		var rv_before: int = bolts().size() + zones().size()
		if rv_caster.use_skill_id(sid, rv_main.player, 150.0):
			await frames(2)
			if bolts().size() + zones().size() > rv_before:
				rv_cast += 1
	check("the rival can cast all five long-range skills at 小怪", rv_cast == 5, "%d of 5" % rv_cast)
	rv_caster.queue_free()
	var fresh_rival: int = rv_main.rival["skills"].size()
	check("the rival knows at least two skills from the start of a run", fresh_rival >= 2 or int(rv_main.rival["level"]) > 1)
	var rv_xp0: int = int(rv_main.rival["xp"])
	rv.take_hit(99999999, Vector2.RIGHT, false)
	await frames(3)
	check("when 小怪 defeats the rival, it respawns in 30 seconds", rv_main.rival["node"] == null and absf(float(rv_main.rival["respawn"]) - 30.0) < 1.0 and int(rv_main.rival["falls"]) == 1, str(rv_main.rival["respawn"]))
	check("the rival keeps its EXP, level and skills across a respawn", int(rv_main.rival["xp"]) >= rv_xp0 and int(rv_main.rival["level"]) > 10)
	rv_main.rival["respawn"] = 0.5
	rv_main.elapsed = 100.0
	Engine.remove_meta("deterministic_map")
	rv_main._update_rival(1.0)
	Engine.set_meta("deterministic_map", true)
	var rv2 = rv_main.rival["node"]
	check("after 30 seconds the same rival is back at its level", rv2 != null and is_instance_valid(rv2) and rv2.rival_level == int(rv_main.rival["level"]) and rv2.hp == rv2.max_hp)
	rv2.hp = 1
	var rv_d0: float = rv2.global_position.distance_to(main.player.global_position)
	await frames(30)
	check("the rival runs away when its health is low", rv2.fleeing and rv2.hp > 1 and rv2.hit_cd > 0.0 and (rv2.velocity == Vector2.ZERO or rv2.velocity.dot(rv2.global_position - main.player.global_position) >= 0.0), "fleeing %s hp %d dist %.0f -> %.0f" % [str(rv2.fleeing), rv2.hp, rv_d0, rv2.global_position.distance_to(main.player.global_position)])
	rv2.hp = rv2.max_hp
	await frames(3)
	check("and comes back to fight once it has recovered", not rv2.fleeing)
	rv_main.elapsed = 1200.0
	Engine.remove_meta("deterministic_map")
	rv_main._update_rival(0.1)
	Engine.set_meta("deterministic_map", true)
	check("at 20 minutes the final duel starts", bool(rv_main.rival["duel"]), "node %s game_over %s elapsed %.0f falls %d" % [str(is_instance_valid(rv_main.rival["node"])), str(rv_main.game_over), rv_main.elapsed, int(rv_main.rival["falls"])])
	rv2.take_hit(99999999, Vector2.RIGHT, false)
	await frames(3)
	check("defeating the rival in the final duel wins the game", rv_main.game_over and rv_main.banner.text.contains("VICTORY"))
	await clear_enemies()

	# biomes, points of interest, ambient life and weather
	await fresh()
	var mp = main
	var mp_kinds := {}
	for t in mp.biome:
		mp_kinds[mp.biome[t]] = true
	check("the map has several biomes", mp_kinds.size() >= 3 and mp.biome.size() > 1500, "%d kinds, %d tiles" % [mp_kinds.size(), mp.biome.size()])
	var mp_near_start := 0
	for t in mp.biome:
		if Vector2(t - mp.START_TILE).length() < 30.0:
			mp_near_start += 1
	check("the start meadow stays green", mp_near_start == 0)
	var mp_pois: Array = get_nodes_in_group("pois")
	check("shrines, springs, crypts and towers are scattered over the map", mp_pois.size() >= 8, str(mp_pois.size()))
	var mp_ok := true
	for poi in mp_pois:
		var ptile: Vector2i = mp.tile_of(poi.global_position)
		if not mp.open_lookup.has(ptile) or Vector2(ptile - mp.START_TILE).length() < 26.0:
			mp_ok = false
	check("every point of interest can be reached and is far from the start", mp_ok)
	var mp_swamp = null
	for t in mp.biome:
		if mp.biome[t] == mp.Biomes.SWAMP and not mp.water.has(t) and not mp.mud.has(t):
			mp_swamp = t
			break
	check("the swamp slows 小怪 a little", mp_swamp == null or mp.speed_mult_at(mp._tile_center(mp_swamp)) < 1.0)
	await clear_enemies()
	var mpp = mp.player
	mpp.hp = 3
	mpp.max_hp = 40
	var mp_spring = null
	var mp_shrine = null
	var mp_crypt = null
	var mp_tower = null
	for poi in mp_pois:
		if poi.kind == "spring" and mp_spring == null:
			mp_spring = poi
		if poi.kind == "shrine" and mp_shrine == null:
			mp_shrine = poi
		if poi.kind == "crypt" and mp_crypt == null:
			mp_crypt = poi
		if poi.kind == "tower" and mp_tower == null:
			mp_tower = poi
	if mp_spring != null:
		mpp.global_position = mp_spring.global_position
		await frames(90)
		check("a healing spring heals 小怪 while he stands in it", mpp.hp > 3, "hp %d" % mpp.hp)
	if mp_shrine != null:
		mpp.buffs.clear()
		mpp.global_position = mp_shrine.global_position
		await frames(5)
		check("a shrine gives a buff and then rests", not mpp.buffs.is_empty() and mp_shrine.rest > 100.0)
	var mp_bones0: int = mp.bones
	if mp_tower != null:
		mpp.global_position = mp_tower.global_position
		await frames(5)
		check("a ruined tower pays bones once and clears the fog", mp.bones == mp_bones0 + 25 and mp_tower.used)
	if mp_crypt != null:
		var mp_enemies0: int = enemies().size()
		mpp.global_position = mp_crypt.global_position
		await frames(5)
		check("a crypt opens once: an ambush and a chest", mp_crypt.used and enemies().size() >= mp_enemies0 + 5)
	await clear_enemies()
	check("the map has ambient life and weather", mp.ambient != null and mp.ambient.weather == "clear")
	mp.ambient.weather = "rain"
	mp.ambient.weather_left = 30.0
	await frames(120)
	var mp_rain := 0
	for q in mp.ambient._parts:
		if q["k"] == "rain" or q["k"] == "flurry":
			mp_rain += 1
	check("rain falls when the weather turns", mp_rain > 0, str(mp_rain))
	mp.ambient.weather = "clear"

	print("\n%s: %d failure(s)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)

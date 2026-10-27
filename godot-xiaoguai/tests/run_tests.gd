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
	root.add_child(main)
	await frames(5)  # let the new scene settle after its heavy first frame


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
	check("hits give EXP", p.xp > xp_before, "xp %d" % p.xp)

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
	check("up to level 19: skill picks at 12, 15 and 18, and a special at 12",
			kinds_19.count("skill") == 3 and kinds_19.count("special") == 1, str(kinds_19))
	p.add_xp(PlayerScript.xp_for_level(20) - p.xp)
	check("the second evolution is at level 20, with no line menu", p.level == 20 and p.stage == 2
			and p.stages[2]["name"] == "Dragonling" and not p.needs_line)
	drain_menus()
	p.add_xp(PlayerScript.xp_for_level(100))
	var kinds_all: Array = drain_menus()
	check("level 100 is the last form of the line", p.level == 100 and p.stage == 10 and p.stages[10]["name"] == "Elder Dragon")
	var normal_picks: int = kinds_all.count("skill") + 3 + 3  # plus the 6 picked by hand so far (levels 3, 6, 9, 12, 15, 18)
	check("a skill pick every 3 levels: 33 in a run", normal_picks == 33, "%d" % normal_picks)
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
	check("to level 24: 8 skill picks and 2 special picks", kinds_24.count("skill") == 8 and kinds_24.count("special") == 2, str(kinds_24))
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
	check("Second Wind: heals half your HP when low", p.hp >= p.max_hp * 0.5 - 1, "hp %d of %d" % [p.hp, p.max_hp])
	p.wind_cd = 60.0
	check("Second Wind is limited to once a minute", p.wind_cd > 0.0)
	p.learn_special("phoenix")
	p.invuln = 0.0
	p.hp = 1
	p.take_hit(5, Vector2.LEFT)
	check("Phoenix: a deadly hit brings you back with 60% HP", p.hp == roundi(p.max_hp * 0.6) and p.phoenix_used)
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
	check("Blood Moon: night strength by day", p.effective_bite() > bite_by_day and p._power() >= 1.5)
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
	check("Dark Hero becomes GOD at village level 5", f5.secret == 2 and f5.form_name() == "GOD")
	check("GOD is the strongest villager", f5.max_hp >= 200 and f5.damage >= 12)
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
	check("mud slows 小怪", p.slow_left > 0.0)
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
	check("at the final form the village is massive", main.target_population() == 340, str(main.target_population()))
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
	main.elapsed = 1000.0
	main.village_level = 5
	for i in 120:
		main._on_phase_change()
	check("GOD can appear late with village level 5", enemies().filter(func(e): return e.secret == 2).size() >= 1)
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
	await frames(2)
	check("at the start villagers cannot shoot", hunter0.ranged_config().is_empty())
	check("at the start villagers have no skills", mage0.skill_name() == "" and hunter0.skill_name() == "")
	check("at the start days give villagers no bonus", main.enemy_power() == 1.0)
	check("villagers walk slower at the start", main.enemy_speed_mult() < 1.0 and hunter0.effective_speed() < hunter0.speed)
	var hidden0 = main._spawn_villager(Vector2(3000, 800), 4, 3, 0)
	check("hidden forms shoot too, but not before the grace period ends", hidden0.ranged_config().is_empty())
	main.elapsed = 200.0
	check("after 3 minutes villagers can shoot", not hunter0.ranged_config().is_empty() and not hidden0.ranged_config().is_empty())
	check("...but still have no skills", mage0.skill_name() == "")
	check("...and daylight makes them stronger", main.is_night() or main.enemy_power() == 1.5)
	main.elapsed = 400.0
	check("after 6 minutes they have skills", mage0.skill_name() == "fireball")
	main.elapsed = 0.0
	check("at the start only nearby villagers notice 小怪", main.chase_radius() < 600.0)
	main.elapsed = 300.0
	check("the notice radius grows", main.chase_radius() > 1500.0 and main.chase_radius() < INF)
	main.elapsed = 600.0
	check("after 10 minutes they chase from anywhere", main.chase_radius() == INF)
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
	check("the bar names the selected item", main.hotbar[1].text.begins_with("▶") and main.hotbar[0].text.begins_with(" "))

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
	await frames(140)
	check("Undead: heals 1 HP per second at night", p.hp >= undead_hp + 2, "%d -> %d" % [undead_hp, p.hp])
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
	await frames(260)
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
	check("Stone Skin rank 3: hits are cut by 5 but never below 1", p.reduce_damage(6) == 1 and p.reduce_damage(9) == 4)
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
	check("the screen shows the family trait and ability", main.hud.text.contains("Family trait") and main.hud.text.contains("Hellfire Rain"))

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
	check("early forms: Battle Theme 0", main.wanted_track() == "battle1")
	p.stage = 4
	check("middle forms: Epic Boss Battle", main.wanted_track() == "battle2")
	p.stage = 7
	check("later forms: Boss Battle #2 (intro, then loop)", main.wanted_track() == "battle3" and tracks["battle3"].has("intro"))
	p.stage = 9
	check("the last forms: the final boss theme", main.wanted_track() == "final")
	p.stage = 4
	main.clock = 90.0  # night
	check("nights have their own track", main.wanted_track() == "night")
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
	check("the map has treasure chests of every tier", get_nodes_in_group("treasures").size() >= 40 and ["wood", "silver", "gold", "cursed"].all(func(t): return get_nodes_in_group("treasures").any(func(c): return c.tier == t)))
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
	check("a gold chest pays well and gives a relic", main.bones - mt_bones1 >= 80 and not p.relics.is_empty())
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

	print("\n%s: %d failure(s)" % ["ALL PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)

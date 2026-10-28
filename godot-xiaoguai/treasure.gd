extends Node2D
## A treasure chest on the map. Walk onto it to open it. Four tiers:
##   wood    a few bones, now and then a short buff or a snack
##   silver  more bones, a buff, often a relic
##   gold    lots of bones, a relic, a buff and sometimes a free skill rank
##   cursed  an ambush of villagers, then the best loot
## Buffs last a while (Rage, Swift, Mend, Ward). Relics are permanent and stack up to MAX_RELIC times.

const Popups := preload("res://popups.gd")
const Sfx := preload("res://sfx.gd")
const SkillsData := preload("res://skills.gd")

const MAX_RELIC := 3

const BUFFS := {
	"rage": {"name": "Rage", "desc": "+40% bite damage", "mods": {"bite": 0.4}, "color": Color("ff6040")},
	"swift": {"name": "Swift", "desc": "+30% move speed", "mods": {"speed": 0.3}, "color": Color("60d0ff")},
	"mend": {"name": "Mend", "desc": "regenerate 0.9 HP per second", "mods": {"regen": 0.9}, "color": Color("70e070")},
	"ward": {"name": "Ward", "desc": "take 2 less damage", "mods": {"cut": 2}, "color": Color("c0c0ff")},
}

const RELICS := {
	"fang_charm": {"name": "Fang Charm", "desc": "+10% bite damage", "mods": {"bite": 0.1}},
	"iron_heart": {"name": "Iron Heart", "desc": "+12% max HP", "mods": {"hp": 0.12}},
	"wind_boots": {"name": "Wind Boots", "desc": "+6% move speed", "mods": {"speed": 0.06}},
	"vital_leaf": {"name": "Vital Leaf", "desc": "regenerate 0.25 HP per second", "mods": {"regen": 0.25}},
	"bone_ring": {"name": "Bone Ring", "desc": "heal 2.5% of bite damage", "mods": {"drain": 0.025}},
	"tough_shell": {"name": "Tough Shell", "desc": "take 1 less damage", "mods": {"cut": 1}},
}

const TIERS := {
	"wood": {"body": Color("8a5a2b"), "band": Color("5a3b1c"), "trim": Color("c9a060")},
	"silver": {"body": Color("7a8696"), "band": Color("4a5666"), "trim": Color("e6eef8")},
	"gold": {"body": Color("d4a02a"), "band": Color("8a5a10"), "trim": Color("fff0a0")},
	"cursed": {"body": Color("5a2a6a"), "band": Color("2a1038"), "trim": Color("e060ff")},
	"mimic": {"body": Color("d4a02a"), "band": Color("8a5a10"), "trim": Color("fff0a0")},   # looks like gold, bites
}

var tier := "wood"
var opened := false
var open_t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("treasures")
	rng.randomize()
	z_index = 1


func _physics_process(delta: float) -> void:
	if opened:
		open_t += delta
		if open_t > 6.0:
			queue_free()
		queue_redraw()
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.hp > 0 and pl.global_position.distance_to(global_position) < 20.0 + pl.body_radius * 0.5:
		open(pl)
	queue_redraw()


## Open the chest for the player and hand out the loot. Returns the lines of text that were shown.
func open(pl) -> Array[String]:
	var lines: Array[String] = []
	if opened:
		return lines
	opened = true
	Sfx.play(get_tree(), "pick")
	var level_node = get_parent()
	if tier == "mimic":
		_reveal_mimic(pl, level_node)
		return lines
	if tier == "cursed" and level_node.has_method("_spawn_villager"):
		for k in 6:
			var a := float(k) / 6.0 * TAU
			level_node.call("_spawn_villager", global_position + Vector2.from_angle(a) * 70.0, rng.randi_range(0, 2), -1)
		lines.append("AMBUSH!")
	var bones := 0
	match tier:
		"wood":
			bones = rng.randi_range(5, 12)
		"silver":
			bones = rng.randi_range(15, 30)
		"gold":
			bones = rng.randi_range(40, 75)
		"cursed":
			bones = rng.randi_range(60, 100)
	if level_node.get("bones") != null:
		level_node.set("bones", int(level_node.get("bones")) + bones)
	lines.append("+%d bones" % bones)
	if tier == "wood":
		if rng.randf() < 0.2:
			lines.append(_give_buff(pl, 15.0))
		elif rng.randf() < 0.1:
			var heal := roundi(pl.max_hp * 0.2)
			pl.hp = mini(pl.max_hp, pl.hp + heal)
			pl.hp_changed.emit(pl.hp)
			lines.append("+%d HP" % heal)
	elif tier == "silver":
		lines.append(_give_buff(pl, 20.0))
		if rng.randf() < 0.2:
			lines.append(_give_relic(pl))
	else:
		lines.append(_give_buff(pl, 25.0 if tier == "gold" else 30.0))
		if tier == "cursed" or rng.randf() < 0.6:
			lines.append(_give_relic(pl))
		if tier == "gold" and rng.randf() < 0.25:
			var pick: Array = SkillsData.roll(pl.skills, rng, 1, pl.line, pl.stage)
			if not pick.is_empty():
				pl.learn(pick[0])
				lines.append("Skill: %s +1" % SkillsData.info(pick[0])["name"])
		SkillFx.spawn_levelup(self)
	var y := -30.0
	for text in lines:
		Popups.text(get_tree(), global_position + Vector2(0, y), text, Popups.HEAL if not text.begins_with("AMBUSH") else Popups.BLEED, 14)
		y -= 14.0
	return lines


func _give_buff(pl, secs: float) -> String:
	var id: String = BUFFS.keys()[rng.randi_range(0, BUFFS.size() - 1)]
	pl.add_buff(id, secs)
	return "%s! %s (%ds)" % [BUFFS[id]["name"], BUFFS[id]["desc"], int(secs)]


func _give_relic(pl) -> String:
	var id: String = RELICS.keys()[rng.randi_range(0, RELICS.size() - 1)]
	if int(pl.relics.get(id, 0)) >= MAX_RELIC:
		for other in RELICS:
			if int(pl.relics.get(other, 0)) < MAX_RELIC:
				id = other
				break
	pl.add_relic(id)
	return "Relic: %s (%s)" % [RELICS[id]["name"], RELICS[id]["desc"]]


func _draw() -> void:
	var c: Dictionary = TIERS[tier]
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005 + position.x)
	draw_circle(Vector2(0, 9), 11.0, Color(0, 0, 0, 0.25))
	if not opened:
		if tier == "gold" or tier == "cursed" or tier == "mimic":
			draw_circle(Vector2(0, 0), 15.0 + pulse * 3.0, Color(c["trim"], 0.12 + 0.1 * pulse))
		# body
		draw_rect(Rect2(-10, -2, 20, 11), c["body"])
		draw_rect(Rect2(-10, -2, 20, 11), c["band"], false, 1.5)
		draw_rect(Rect2(-10, 2, 20, 2), c["band"])
		# lid: a half barrel
		var lid := PackedVector2Array([Vector2(-10, -2), Vector2(-8, -8), Vector2(0, -10), Vector2(8, -8), Vector2(10, -2)])
		draw_colored_polygon(lid, c["body"].lightened(0.12))
		draw_polyline(lid, c["band"], 1.5)
		draw_rect(Rect2(-1.5, -4, 3, 5), c["trim"])
		draw_rect(Rect2(-10, -2, 3, 11), c["band"])
		draw_rect(Rect2(7, -2, 3, 11), c["band"])
		if tier != "wood":
			var sp := fposmod(Time.get_ticks_msec() * 0.0015 + position.y, 1.0)
			SkillFx._star(self, Vector2(-6 + sp * 12.0, -12 - sp * 6.0), 2.0 * (1.0 - sp), Color(c["trim"], 1.0 - sp))
	else:
		var fade := 1.0 - smoothstep(4.0, 6.0, open_t)
		draw_rect(Rect2(-10, -2, 20, 11), Color(c["band"], fade))
		draw_rect(Rect2(-8, 0, 16, 4), Color(0.05, 0.02, 0.0, fade))
		var lid2 := PackedVector2Array([Vector2(-10, -4), Vector2(-9, -14), Vector2(9, -14), Vector2(10, -4)])
		draw_colored_polygon(lid2, Color(c["body"], fade))


## The chest was a mimic: it turns into a tough villager with teeth.
func _reveal_mimic(pl, level_node) -> void:
	Popups.text(get_tree(), global_position + Vector2(0, -26), "MIMIC!", Popups.BLEED, 18)
	Sfx.play(get_tree(), "warn", -2.0)
	if level_node.has_method("_spawn_villager"):
		var v = level_node.call("_spawn_villager", global_position, 3, 9)
		v.mimic = true
		v.title_override = "Mimic"
		v.max_hp = roundi(v.max_hp * 2.5)
		v.hp = v.max_hp
		v.damage += 1
		v.force_chase = true
		v.body_scale = 1.3
	queue_free()

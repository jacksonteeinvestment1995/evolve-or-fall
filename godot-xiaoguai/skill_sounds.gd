class_name SkillSounds
extends RefCounted
## One sound for every skill, special and treasure-free ability. About two dozen base sounds (see sfx.gd, the s_ ones)
## are matched to what the skill does (fire whoosh, ice chime, claw slash, heal chime...), and each skill that shares a
## base gets its own pitch, so no two skills sound the same. Skills play it when learned, when they fire and
## when their bite effect procs.

const SkillsData := preload("res://skills.gd")
const Sfx := preload("res://sfx.gd")

const STATUS := {"burn": "s_fire", "chill": "s_ice", "poison": "s_poison", "bleed": "s_claw", "curse": "s_curse", "root": "s_leaf", "shock": "s_zap", "stun": "s_rock"}
const STYLE := {"acid": "s_poison", "spear": "s_bone", "orb": "s_spirit", "glob": "s_goo", "fire": "s_fire", "claw": "s_claw", "seed": "s_leaf",
	"rock": "s_rock", "hell": "s_hell", "cloud": "s_poison", "flames": "s_fire", "spikes": "s_bone", "droplets": "s_goo", "waves": "s_growl", "rubble": "s_rock"}
const MODS := {"bite": "s_claw", "hp": "s_shield", "cut": "s_shield", "speed": "s_dash", "regen": "s_heal", "drain": "s_drain", "jaws": "s_bone", "reach": "s_dash", "night_bite": "s_curse"}
const OVERRIDE := {"w_wail": "s_spirit", "d_gust": "s_wind", "b_roar": "s_growl", "m_quake": "s_quake", "s_storm": "s_bone", "z_chill": "s_ice", "l_splash": "s_goo",
	"n_thorn": "s_leaf", "n_tangle": "s_leaf", "d_inferno": "s_blast", "e_spark": "s_hell"}
const GENERAL := {"hide": "s_shield", "fangs": "s_claw", "paws": "s_dash", "jaws": "s_bone", "drain": "s_drain", "greed": "coin", "nova": "nova", "bolt": "bolt",
	"step": "dodge", "roar": "roar", "doom": "doom", "magnet": "s_buff",
	"frost_shards": "s_ice", "meteor_call": "s_fire", "chain_zap": "s_zap", "thorn_ring": "s_leaf", "spirit_lance": "s_spirit"}
const SPECIAL := {"overdrive": "s_thunder", "frenzy": "s_claw", "ironwill": "s_rock", "secondwind": "s_heal", "phoenix": "s_fire", "cleave": "s_claw",
	"stormcaller": "s_zap", "bloodmoon": "s_curse", "gravity": "s_drain", "titan": "s_quake", "mastery": "s_holy", "bonehoard": "coin"}

static var _table := {}      # skill id -> [sound name, pitch]


## [sound, pitch] for a skill id (an ordinary skill, a form skill or a special).
static func of(id: String) -> Array:
	if _table.is_empty():
		_build()
	return _table.get(id, ["s_buff", 1.0])


static func _base_for(id: String) -> String:
	if GENERAL.has(id):
		return GENERAL[id]
	if SPECIAL.has(id):
		return SPECIAL[id]
	if OVERRIDE.has(id):
		return OVERRIDE[id]
	var info: Dictionary = SkillsData.form_skills().get(id, {})
	if info.has("auto"):
		var a: Dictionary = info["auto"]
		if a.has("style"):
			return STYLE.get(a["style"], "s_buff")
		if a.has("status"):
			return STATUS.get(a["status"], "s_buff")
		return "s_wind"
	if info.has("onbite"):
		return STATUS.get(info["onbite"]["status"], "s_claw")
	if info.has("mods"):
		for k in MODS:
			if info["mods"].has(k):
				return MODS[k]
	return "s_buff"


static func _build() -> void:
	var ids: Array = []
	for id in GENERAL:
		ids.append(id)
	for id in SkillsData.form_skills():
		ids.append(id)
	for id in SPECIAL:
		ids.append(id)
	# group the skills by base sound, then spread each group's pitches evenly over 0.65 .. 1.6 so every one differs
	var groups := {}
	for id in ids:
		var base := _base_for(id)
		if not groups.has(base):
			groups[base] = []
		groups[base].append(id)
	for base in groups:
		var list: Array = groups[base]
		for i in list.size():
			var pitch := 1.0 if list.size() == 1 else 0.65 * pow(1.6 / 0.65, float(i) / float(list.size() - 1))
			_table[list[i]] = [base, snappedf(pitch, 0.01)]


## Play a skill's sound everyone can hear.
static func play(tree: SceneTree, id: String, volume_db: float = -4.0) -> void:
	var s := of(id)
	Sfx.play(tree, s[0], volume_db, s[1])


## Play it where something happens (a bite effect on a villager, say).
static func play_at(tree: SceneTree, id: String, pos: Vector2, volume_db: float = -8.0) -> void:
	var s := of(id)
	Sfx.play_at(tree, s[0], pos, volume_db, s[1])

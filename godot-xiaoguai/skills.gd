extends RefCounted
## Skills 小怪 can learn. Every 3rd level offers 3 to choose from; picking one you already
## have raises its rank (up to max). They are all passive: stat skills work all the time, and
## "auto" skills (with a cooldown) trigger on their own, no keys.
## Every 12th level offers a SPECIAL skill instead: 3 of these stronger, one-time picks.

const SPECIALS := {
	"overdrive": {"name": "Overdrive Bites", "desc": "+40% bite damage"},
	"frenzy": {"name": "Frenzy", "desc": "Bite 25% faster"},
	"ironwill": {"name": "Iron Will", "desc": "+50% max HP, and heal to full now"},
	"secondwind": {"name": "Second Wind", "desc": "Below 25% HP, heal half of your HP (once a minute)"},
	"phoenix": {"name": "Phoenix", "desc": "Once per run: come back from death with 60% HP and a blast"},
	"cleave": {"name": "Cleave", "desc": "Every bite also hits up to 2 more villagers nearby"},
	"stormcaller": {"name": "Stormcaller", "desc": "Your automatic skills recharge 35% faster"},
	"bloodmoon": {"name": "Blood Moon", "desc": "You have night strength (+50% bite, +20% speed) all day long"},
	"gravity": {"name": "Gravity Maw", "desc": "Villagers near you are slowly pulled in"},
	"titan": {"name": "Titan Reach", "desc": "+30% bite reach"},
	"mastery": {"name": "Mastery", "desc": "Every skill you own gains a rank right now"},
	"bonehoard": {"name": "Bone Hoard", "desc": "Double bones, and towers and walls cost 30% less"},
}

const SKILLS := {
	"hide": {"name": "Tough Hide", "kind": "passive", "max": 5, "desc": "+20% max HP per rank"},
	"fangs": {"name": "Sharp Fangs", "kind": "passive", "max": 5, "desc": "+25% bite damage per rank"},
	"paws": {"name": "Swift Paws", "kind": "passive", "max": 5, "desc": "+8% move speed per rank"},
	"jaws": {"name": "Quick Jaws", "kind": "passive", "max": 5, "desc": "-10% time between bites per rank"},
	"drain": {"name": "Soul Drain", "kind": "passive", "max": 5, "desc": "Heal 1 HP for each villager you defeat, per rank"},
	"greed": {"name": "Bone Collector", "kind": "passive", "max": 5, "desc": "+25% bones from kills per rank"},
	"nova": {"name": "Bone Nova", "kind": "passive", "auto": true, "max": 5, "cd": 8.0, "desc": "Auto: blast around you when villagers close in (3x bite, brief stun)"},
	"bolt": {"name": "Spirit Bolt", "kind": "passive", "auto": true, "max": 5, "cd": 5.0, "desc": "Auto: piercing bolt at the nearest villager (3x bite)"},
	"step": {"name": "Shadow Step", "kind": "passive", "auto": true, "max": 5, "cd": 2.0, "desc": "Auto: 10% chance per rank to dodge a hit and blink away"},
	"magnet": {"name": "EXP Magnet", "kind": "passive", "max": 5, "desc": "Pulls EXP stones to you from further away (+90 px per rank)"},
	"roar": {"name": "Roar", "kind": "passive", "auto": true, "max": 5, "cd": 15.0, "desc": "Auto: when surrounded or low on HP, knocks back and stuns villagers"},
	# Not offered at level-ups: 小怪 gets it by reaching the final form (level 50).
	"doom": {"name": "Final Calamity", "kind": "passive", "auto": true, "ultimate": true, "max": 1, "cd": 25.0, "desc": "The strongest skill, earned by the final form: a huge blast that devastates and stuns everything around you"},
}


## Form skills: each released line has 6 of its own, offered in the level-up menu once 小怪 has
## reached the form that unlocks them. Every one has up to `max` ranks. Fields:
##   mods    per rank: bite, hp, speed, jaws (shorter bite wait), cut (flat damage taken), reach,
##           drain (share of bite damage healed), night_bite, regen (HP per second)
##   onbite  a status put on the bitten villager: chance per rank
##   auto    a blast around you when villagers are close: cd, radius, mult (x bite), stun, status
## Entry: [id, line index (see lines.gd), form, name, description, max rank, effect fields]
const FORM_LIST := [
	# Zombie line (0)
	["z_grip", 0, 2, "Rotting Grip", "+12% bite damage per rank", 3, {"mods": {"bite": 0.12}}],
	["z_plague", 0, 4, "Plague Bite", "Bites poison: 25% chance per rank", 3, {"onbite": {"status": "poison", "chance": 0.25, "secs": 5.0}}],
	["z_chill", 0, 5, "Grave Chill", "Auto: a freezing blast around you", 3, {"auto": {"fx": "fx_skill_frost", "cd": 10.0, "radius": 90.0, "mult": 0.5, "status": "chill", "secs": 3.0, "color": "8fd8ff"}}],
	["z_feast", 0, 7, "Night Feaster", "+25% bite damage per rank at night", 3, {"mods": {"night_bite": 0.25}}],
	["z_undying", 0, 8, "Undying", "Regenerate 0.7 HP per second per rank", 3, {"mods": {"regen": 0.7}}],
	["z_crimson", 0, 10, "Crimson Feast", "Heal 8% of bite damage per rank", 3, {"mods": {"drain": 0.08}}],
	# Skeleton line (1)
	["s_plating", 1, 2, "Bone Plating", "+15% max HP per rank", 3, {"mods": {"hp": 0.15}}],
	["s_spear", 1, 4, "Rib Spear", "+15% bite reach per rank", 3, {"mods": {"reach": 0.15}}],
	["s_marrow", 1, 5, "Marrow Rot", "Bites make villagers bleed: 25% per rank", 3, {"onbite": {"status": "bleed", "chance": 0.25, "secs": 4.0}}],
	["s_storm", 1, 7, "Bone Storm", "Auto: shards blast nearby villagers", 3, {"auto": {"fx": "fx_skill_bone", "cd": 12.0, "radius": 100.0, "mult": 2.0, "stun": 0.4, "color": "e8e0c8"}}],
	["s_gaze", 1, 8, "Dread Gaze", "Bites curse villagers: 20% per rank", 3, {"onbite": {"status": "curse", "chance": 0.2, "secs": 6.0}}],
	["s_pact", 1, 10, "Lich Pact", "+20% bite damage and 10% faster bites per rank", 3, {"mods": {"bite": 0.2, "jaws": 0.1}}],
	# Wisp line (2)
	["w_drift", 2, 2, "Ghost Drift", "+8% move speed per rank", 3, {"mods": {"speed": 0.08}}],
	["w_touch", 2, 4, "Chill Touch", "Bites chill villagers: 30% per rank", 3, {"onbite": {"status": "chill", "chance": 0.3, "secs": 3.0}}],
	["w_wail", 2, 5, "Wail", "Auto: a scream that stuns nearby villagers", 3, {"auto": {"fx": "fx_skill_scream", "cd": 12.0, "radius": 110.0, "mult": 0.5, "stun": 0.8, "color": "b0c0ff"}}],
	["w_haunt", 2, 7, "Haunt", "Bites curse villagers: 20% per rank", 3, {"onbite": {"status": "curse", "chance": 0.2, "secs": 6.0}}],
	["w_veil", 2, 8, "Spectral Veil", "Take 1 less damage per rank", 2, {"mods": {"cut": 1}}],
	["w_harvest", 2, 10, "Soul Harvest", "Heal 6% of bite damage and +5% speed per rank", 3, {"mods": {"drain": 0.06, "speed": 0.05}}],
	# Slime line (6)
	["l_gel", 6, 2, "Gel Body", "+15% max HP per rank", 3, {"mods": {"hp": 0.15}}],
	["l_goo", 6, 4, "Sticky Goo", "Bites slow villagers: 35% per rank", 3, {"onbite": {"status": "chill", "chance": 0.35, "secs": 3.0}}],
	["l_splash", 6, 5, "Magma Splash", "Auto: burning goo around you", 3, {"auto": {"fx": "fx_skill_magma", "cd": 8.0, "radius": 80.0, "mult": 1.0, "status": "burn", "secs": 4.0, "color": "ff8040"}}],
	["l_bounce", 6, 7, "Bounce", "+8% move speed per rank", 3, {"mods": {"speed": 0.08}}],
	["l_absorb", 6, 8, "Absorb", "Take 1 less damage per rank", 2, {"mods": {"cut": 1}}],
	["l_armor", 6, 10, "Gel Armor", "+20% max HP and +10% bite damage per rank", 3, {"mods": {"hp": 0.2, "bite": 0.1}}],
	# Dragon line (10)
	["d_scale", 10, 2, "Scale Hide", "+12% max HP per rank", 3, {"mods": {"hp": 0.12}}],
	["d_ember", 10, 4, "Ember Bite", "Bites burn villagers: 30% per rank", 3, {"onbite": {"status": "burn", "chance": 0.3, "secs": 4.0}}],
	["d_gust", 10, 5, "Wing Gust", "Auto: a gust that stuns nearby villagers", 3, {"auto": {"fx": "fx_skill_gust", "cd": 10.0, "radius": 110.0, "mult": 0.5, "stun": 0.5, "color": "ffd080"}}],
	["d_heart", 10, 7, "Dragon Heart", "+15% bite damage per rank", 3, {"mods": {"bite": 0.15}}],
	["d_inferno", 10, 8, "Inferno Burst", "Auto: a fire blast that burns", 3, {"auto": {"fx": "fx_skill_fire", "cd": 11.0, "radius": 120.0, "mult": 2.0, "status": "burn", "secs": 4.0, "color": "ff5020"}}],
	["d_might", 10, 10, "Dragon Might", "+20% bite damage and +10% max HP per rank", 3, {"mods": {"bite": 0.2, "hp": 0.1}}],
	# Beast line (14)
	["b_fangs", 14, 2, "Keen Fangs", "+12% bite damage per rank", 3, {"mods": {"bite": 0.12}}],
	["b_rake", 14, 4, "Claw Rake", "Bites make villagers bleed: 30% per rank", 3, {"onbite": {"status": "bleed", "chance": 0.3, "secs": 4.0}}],
	["b_sense", 14, 5, "Hunt Sense", "10% faster bites per rank", 3, {"mods": {"jaws": 0.1}}],
	["b_rush", 14, 7, "Feral Rush", "+8% move speed per rank", 3, {"mods": {"speed": 0.08}}],
	["b_roar", 14, 8, "Savage Roar", "Auto: a roar that stuns nearby villagers", 3, {"auto": {"fx": "fx_skill_roar", "cd": 14.0, "radius": 120.0, "mult": 0.0, "stun": 1.0, "color": "ff8040"}}],
	["b_alpha", 14, 10, "Alpha Bloodlust", "+15% bite damage and 8% faster bites per rank", 3, {"mods": {"bite": 0.15, "jaws": 0.08}}],
	# Nature line (17)
	["n_bark", 17, 2, "Thick Bark", "+15% max HP per rank", 3, {"mods": {"hp": 0.15}}],
	["n_thorn", 17, 4, "Thorn Burst", "Auto: thorns hit and root nearby villagers", 3, {"auto": {"fx": "fx_skill_thorn", "cd": 9.0, "radius": 70.0, "mult": 1.5, "status": "root", "secs": 1.5, "color": "5ac040"}}],
	["n_photo", 17, 5, "Photosynthesis", "Regenerate 0.6 HP per second per rank", 3, {"mods": {"regen": 0.6}}],
	["n_venom", 17, 7, "Venom Sting", "Bites poison: 30% per rank", 3, {"onbite": {"status": "poison", "chance": 0.3, "secs": 5.0}}],
	["n_tangle", 17, 8, "Entangle", "Auto: roots hold a wide ring of villagers", 3, {"auto": {"fx": "fx_skill_roots", "cd": 12.0, "radius": 130.0, "mult": 0.5, "status": "root", "secs": 2.0, "color": "3a8a30"}}],
	["n_bloom", 17, 10, "Bloom of Life", "Regenerate 1 HP per second and +10% max HP per rank", 3, {"mods": {"regen": 1.0, "hp": 0.1}}],
	# Material line (20)
	["m_shell", 20, 2, "Hardened Shell", "Take 1 less damage per rank", 2, {"mods": {"cut": 1}}],
	["m_fists", 20, 4, "Heavy Fists", "+15% bite damage per rank", 3, {"mods": {"bite": 0.15}}],
	["m_quake", 20, 5, "Quake Stomp", "Auto: a stomp that stuns nearby villagers", 3, {"auto": {"fx": "fx_skill_stomp", "cd": 10.0, "radius": 100.0, "mult": 1.5, "stun": 0.5, "color": "a08060"}}],
	["m_resolve", 20, 7, "Iron Resolve", "+20% max HP per rank", 3, {"mods": {"hp": 0.2}}],
	["m_core", 20, 8, "Molten Core", "Bites burn villagers: 25% per rank", 3, {"onbite": {"status": "burn", "chance": 0.25, "secs": 4.0}}],
	["m_titan", 20, 10, "Titan Mass", "+15% bite reach and +15% bite damage per rank", 3, {"mods": {"reach": 0.15, "bite": 0.15}}],
	# Demon line (22)
	["e_claws", 22, 2, "Imp Claws", "+10% bite damage per rank", 3, {"mods": {"bite": 0.1}}],
	["e_brand", 22, 4, "Fire Brand", "Bites burn villagers: 30% per rank", 3, {"onbite": {"status": "burn", "chance": 0.3, "secs": 4.0}}],
	["e_pact", 22, 5, "Dark Pact", "Heal 6% of bite damage per rank", 3, {"mods": {"drain": 0.06}}],
	["e_spark", 22, 7, "Hellspark", "Auto: hellfire burst around you", 3, {"auto": {"fx": "fx_skill_spark", "cd": 9.0, "radius": 100.0, "mult": 1.5, "status": "burn", "secs": 4.0, "color": "ff3030"}}],
	["e_curse", 22, 8, "Curse Mark", "Bites curse villagers: 25% per rank", 3, {"onbite": {"status": "curse", "chance": 0.25, "secs": 6.0}}],
	["e_might", 22, 10, "Infernal Might", "+20% bite damage and +5% speed per rank", 3, {"mods": {"bite": 0.2, "speed": 0.05}}],
	# --- second wave: forms 3, 6 and 9 of every released line. "volley" skills fire styled bolts at the
	# nearest villagers; "style" skills blast around you with a themed burst (not just a circle). ---
	# Zombie line (0)
	["z_spit", 0, 3, "Rot Spit", "Auto: spits acid blobs that poison", 3, {"auto": {"volley": true, "style": "acid", "shots": 1, "cd": 6.0, "radius": 230.0, "mult": 1.5, "status": "poison", "secs": 5.0, "color": "7ae040"}}],
	["z_cloud", 0, 6, "Plague Cloud", "Auto: a rotting cloud poisons everyone near", 3, {"auto": {"style": "cloud", "cd": 11.0, "radius": 95.0, "mult": 0.5, "status": "poison", "secs": 6.0, "color": "7ab040"}}],
	["z_surge", 0, 9, "Grave Surge", "+15% bite damage and regenerate 0.5 HP per second per rank", 3, {"mods": {"bite": 0.15, "regen": 0.5}}],
	# Skeleton line (1)
	["s_toss", 1, 3, "Bone Toss", "Auto: hurls spinning bone spears", 3, {"auto": {"volley": true, "style": "spear", "shots": 2, "cd": 5.0, "radius": 240.0, "mult": 1.2, "color": "e8e0c8"}}],
	["s_rattle", 1, 6, "Death Rattle", "Auto: bone spikes erupt and stun", 3, {"auto": {"style": "spikes", "cd": 11.0, "radius": 90.0, "mult": 1.5, "stun": 0.6, "color": "e8e0c8"}}],
	["s_ossuary", 1, 9, "Ossuary", "+15% max HP and take 1 less damage per rank", 2, {"mods": {"hp": 0.15, "cut": 1}}],
	# Wisp line (2)
	["w_orbs", 2, 3, "Wisp Orbs", "Auto: sends out chilling spirit orbs", 3, {"auto": {"volley": true, "style": "orb", "shots": 2, "cd": 6.0, "radius": 250.0, "mult": 1.2, "status": "chill", "secs": 3.0, "color": "b0c0ff"}}],
	["w_mist", 2, 6, "Haunting Mist", "Auto: a cold mist chills and curses", 3, {"auto": {"style": "cloud", "cd": 12.0, "radius": 100.0, "mult": 0.5, "status": "curse", "secs": 5.0, "color": "a8b8ff"}}],
	["w_phase", 2, 9, "Phase Shift", "+6% speed and take 1 less damage per rank", 2, {"mods": {"speed": 0.06, "cut": 1}}],
	# Slime line (6)
	["l_glob", 6, 3, "Goo Glob", "Auto: lobs sticky goo that slows", 3, {"auto": {"volley": true, "style": "glob", "shots": 2, "cd": 6.0, "radius": 220.0, "mult": 1.2, "status": "chill", "secs": 3.0, "color": "5aa0ff"}}],
	["l_burst", 6, 6, "Jelly Burst", "Auto: bursts into bouncing droplets", 3, {"auto": {"style": "droplets", "cd": 10.0, "radius": 95.0, "mult": 1.5, "color": "5aa0ff"}}],
	["l_ooze", 6, 9, "Endless Ooze", "+15% max HP and regenerate 0.5 HP per second per rank", 3, {"mods": {"hp": 0.15, "regen": 0.5}}],
	# Dragon line (10)
	["d_fireball", 10, 3, "Fireball", "Auto: throws fireballs that burn", 3, {"auto": {"volley": true, "style": "fire", "shots": 2, "cd": 6.0, "radius": 260.0, "mult": 1.6, "status": "burn", "secs": 4.0, "color": "ff7a20"}}],
	["d_wingstorm", 10, 6, "Wing Storm", "Auto: flames whirl around you", 3, {"auto": {"style": "flames", "cd": 10.0, "radius": 105.0, "mult": 1.8, "status": "burn", "secs": 4.0, "color": "ff5a20"}}],
	["d_scales", 10, 9, "Dragon Scales", "+10% max HP and take 1 less damage per rank", 2, {"mods": {"hp": 0.1, "cut": 1}}],
	# Beast line (14)
	["b_claw", 14, 3, "Claw Wave", "Auto: slashes that make villagers bleed", 3, {"auto": {"volley": true, "style": "claw", "shots": 3, "cd": 5.0, "radius": 200.0, "mult": 1.0, "status": "bleed", "secs": 4.0, "color": "f0e0c0"}}],
	["b_howl", 14, 6, "Moon Howl", "Auto: a howl that rattles and stuns", 3, {"auto": {"style": "waves", "cd": 13.0, "radius": 120.0, "mult": 0.5, "stun": 0.9, "color": "c0d0ff"}}],
	["b_pack", 14, 9, "Pack Leader", "+6% speed and +10% bite damage per rank", 3, {"mods": {"speed": 0.06, "bite": 0.1}}],
	# Nature line (17)
	["n_seeds", 17, 3, "Seed Shot", "Auto: fires poison seeds", 3, {"auto": {"volley": true, "style": "seed", "shots": 3, "cd": 5.5, "radius": 220.0, "mult": 1.0, "status": "poison", "secs": 5.0, "color": "7ad050"}}],
	["n_spores", 17, 6, "Spore Burst", "Auto: a burst of spores poisons nearby villagers", 3, {"auto": {"style": "cloud", "cd": 11.0, "radius": 100.0, "mult": 0.6, "status": "poison", "secs": 6.0, "color": "b0d070"}}],
	["n_grove", 17, 9, "Living Grove", "Regenerate 0.7 HP per second and +10% max HP per rank", 3, {"mods": {"regen": 0.7, "hp": 0.1}}],
	# Material line (20)
	["m_rocks", 20, 3, "Rock Throw", "Auto: hurls boulders", 3, {"auto": {"volley": true, "style": "rock", "shots": 1, "cd": 6.0, "radius": 230.0, "mult": 2.2, "stun": 0.4, "color": "a08060"}}],
	["m_slide", 20, 6, "Landslide", "Auto: rubble crashes down and stuns", 3, {"auto": {"style": "rubble", "cd": 12.0, "radius": 105.0, "mult": 1.8, "stun": 0.7, "color": "a08060"}}],
	["m_fortress", 20, 9, "Living Fortress", "Take 1 less damage and +15% max HP per rank", 2, {"mods": {"cut": 1, "hp": 0.15}}],
	# Demon line (22)
	["e_hellbolt", 22, 3, "Hellbolt", "Auto: fires burning dark bolts", 3, {"auto": {"volley": true, "style": "hell", "shots": 2, "cd": 5.5, "radius": 250.0, "mult": 1.5, "status": "burn", "secs": 4.0, "color": "e02060"}}],
	["e_ruin", 22, 6, "Rain of Ruin", "Auto: cursed flames burst around you", 3, {"auto": {"style": "flames", "cd": 11.0, "radius": 105.0, "mult": 1.6, "status": "curse", "secs": 5.0, "color": "c02050"}}],
	["e_dominion", 22, 9, "Dominion", "+15% bite damage and heal 5% of bite damage per rank", 3, {"mods": {"bite": 0.15, "drain": 0.05}}],
]

static var _form_cache := {}


## All form skills by id: {line, form, name, desc, max, kind, mods / onbite / auto}.
static func form_skills() -> Dictionary:
	if _form_cache.is_empty():
		for e in FORM_LIST:
			var d: Dictionary = {"line": e[1], "form": e[2], "name": e[3], "desc": e[4], "max": e[5], "kind": "form"}
			d.merge(e[6])
			if d.has("auto"):
				d["cd"] = d["auto"]["cd"]
			_form_cache[e[0]] = d
	return _form_cache


## The skill's info, whether it is a general skill or a form skill; {} if unknown.
static func info(id: String) -> Dictionary:
	if SKILLS.has(id):
		return SKILLS[id]
	return form_skills().get(id, {})


## The form skills 小怪 can be offered: his line's, at or below his current form.
static func form_pool(line: int, stage: int) -> Array:
	var out: Array = []
	var all := form_skills()
	for id in all:
		if int(all[id]["line"]) == line and int(all[id]["form"]) <= stage:
			out.append(id)
	return out


## Up to n random special skills you do not have yet.
static func roll_specials(owned: Dictionary, rng: RandomNumberGenerator, n: int = 3) -> Array:
	var pool: Array = []
	for id in SPECIALS:
		if not owned.has(id):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, n)


## Up to n random skills that are not yet at max rank.
static func roll(owned: Dictionary, rng: RandomNumberGenerator, n: int = 3, line: int = -1, stage: int = 0) -> Array:
	var pool: Array = []
	if line >= 0:
		for id in form_pool(line, stage):
			if int(owned.get(id, 0)) < int(form_skills()[id]["max"]):
				pool.append(id)
	for id in SKILLS:
		if SKILLS[id].get("ultimate", false):
			continue
		if int(owned.get(id, 0)) < int(SKILLS[id]["max"]):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, n)

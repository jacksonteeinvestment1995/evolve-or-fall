extends RefCounted
## Run upgrades: every PERK_EVERY levels the game deals three random perk cards and 小怪 keeps one for the rest of the
## run. A perk can be picked up to its "max" times. Their effects use the same modifiers as relics and form skills
## (see Player.form_mod), plus two for the combo chain: "combo_time" (seconds the chain lasts) and "counter_time".

const PERK_EVERY := 4

const PERKS := {
	"sharp_fangs": {"name": "Sharper Fangs", "desc": "+12% bite damage", "mods": {"bite": 0.12}, "max": 5, "color": Color("ff7a5a")},
	"thick_hide": {"name": "Thick Hide", "desc": "+15% max HP", "mods": {"hp": 0.15}, "max": 4, "color": Color("c87850")},
	"quick_paws": {"name": "Quick Paws", "desc": "+8% move speed", "mods": {"speed": 0.08}, "max": 4, "color": Color("60d0ff")},
	"vampire_kiss": {"name": "Vampire Kiss", "desc": "heal 3% of the damage you bite", "mods": {"drain": 0.03}, "max": 3, "color": Color("e04060")},
	"iron_skin": {"name": "Iron Skin", "desc": "take 1 less damage from every hit", "mods": {"cut": 1}, "max": 3, "color": Color("c0c0e0")},
	"regrowth": {"name": "Regrowth", "desc": "regenerate 0.3 HP per second", "mods": {"regen": 0.3}, "max": 4, "color": Color("70e070")},
	"hunters_focus": {"name": "Hunter's Focus", "desc": "bite 8% faster", "mods": {"jaws": 0.08}, "max": 4, "color": Color("ffd84a")},
	"long_reach": {"name": "Long Reach", "desc": "+15% bite reach", "mods": {"reach": 0.15}, "max": 3, "color": Color("a0e0a0")},
	"night_stalker": {"name": "Night Stalker", "desc": "+25% bite damage at night", "mods": {"night_bite": 0.25}, "max": 3, "color": Color("8a9cff")},
	"glass_cannon": {"name": "Glass Cannon", "desc": "+30% bite damage, but -15% max HP", "mods": {"bite": 0.3, "hp": -0.15}, "max": 2, "color": Color("ff4a4a")},
	"combo_master": {"name": "Combo Master", "desc": "your combo lasts 1 second longer", "mods": {"combo_time": 1.0}, "max": 3, "color": Color("ffb030")},
	"counter_strike": {"name": "Counter Strike", "desc": "a perfect dodge sets up a counter for 2 more seconds", "mods": {"counter_time": 2.0}, "max": 2, "color": Color("9fe8ff")},
}


## Up to `n` perks that are not yet at their limit, picked at random.
static func roll(owned: Dictionary, rng: RandomNumberGenerator, n: int) -> Array:
	var pool: Array = []
	for id in PERKS:
		if int(owned.get(id, 0)) < int(PERKS[id]["max"]):
			pool.append(id)
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out

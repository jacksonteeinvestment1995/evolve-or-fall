extends RefCounted
## Skills 小怪 can learn. Every level-up offers 3 to choose from; picking one you
## already have raises its rank (up to max). They are all passive: stat skills work all
## the time, and "auto" skills (with a cooldown) trigger on their own, no keys.

const SKILLS := {
	"hide": {"name": "Tough Hide", "kind": "passive", "max": 5, "desc": "+20% max HP per rank"},
	"fangs": {"name": "Sharp Fangs", "kind": "passive", "max": 5, "desc": "+25% bite damage per rank"},
	"paws": {"name": "Swift Paws", "kind": "passive", "max": 5, "desc": "+8% move speed per rank"},
	"jaws": {"name": "Quick Jaws", "kind": "passive", "max": 5, "desc": "-10% time between bites per rank"},
	"drain": {"name": "Soul Drain", "kind": "passive", "max": 5, "desc": "Heal 1 HP for each villager you defeat, per rank"},
	"greed": {"name": "Bone Collector", "kind": "passive", "max": 5, "desc": "+25% bones from kills per rank"},
	"nova": {"name": "Bone Nova", "kind": "passive", "auto": true, "max": 5, "cd": 8.0, "desc": "Automatic: blasts around you when villagers get close (triple bite damage, short stun)"},
	"bolt": {"name": "Spirit Bolt", "kind": "passive", "auto": true, "max": 5, "cd": 4.0, "desc": "Automatic: fires a piercing bolt at the nearest villager (quadruple bite damage)"},
	"step": {"name": "Shadow Step", "kind": "passive", "auto": true, "max": 5, "cd": 2.0, "desc": "Automatic: 10% chance per rank to dodge a hit and blink away"},
	"roar": {"name": "Roar", "kind": "passive", "auto": true, "max": 5, "cd": 15.0, "desc": "Automatic: when surrounded or low on HP, knocks back and stuns villagers"},
	# Not offered at level-ups: 小怪 gets it by reaching the final form (level 50).
	"doom": {"name": "Final Calamity", "kind": "passive", "auto": true, "ultimate": true, "max": 1, "cd": 25.0, "desc": "The strongest skill, earned by the final form: a huge blast that devastates and stuns everything around you"},
}


## Up to n random skills that are not yet at max rank.
static func roll(owned: Dictionary, rng: RandomNumberGenerator, n: int = 3) -> Array:
	var pool: Array = []
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

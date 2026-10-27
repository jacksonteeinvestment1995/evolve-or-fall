extends RefCounted
## Each monster family has a trait from form 1, and some lines have a signature ability that
## unlocks at form 3 and gets stronger at forms 6 and 9 (rank 1, 2, 3). Abilities run by
## themselves. The first eight are built; the other lines get theirs later (see design-abilities.md).

const UNLOCK_STAGES := [3, 6, 9]

## line index (see lines.gd) -> ability
const ABILITIES := {
	0: {"id": "blood_drain", "name": "Blood Drain", "desc": "Bites heal you (10/15/20% of the damage); rank 3 adds a bleeding red mist"},
	1: {"id": "bone_servants", "name": "Bone Servants", "desc": "Raises 2/3/4 skeleton helpers when 3 or more villagers are near"},
	6: {"id": "molten_trail", "name": "Molten Trail", "desc": "Sprinting leaves burning goo that sets villagers on fire"},
	10: {"id": "fire_breath", "name": "Fire Breath", "desc": "A cone of fire at the nearest villager every 8/6/5 s; rank 3 is twice as wide"},
	14: {"id": "pack_howl", "name": "Pack Howl", "desc": "At night: +40% speed and bleeding bites; rank 3 calls two wolf pups"},
	17: {"id": "rooted", "name": "Rooted", "desc": "Standing still for 2 s roots villagers around you"},
	20: {"id": "stone_skin", "name": "Stone Skin", "desc": "Take 2/3/4 less damage per hit but move 10% slower; rank 3 adds an earthquake"},
	22: {"id": "hellfire_rain", "name": "Hellfire Rain", "desc": "Fireballs fall on 3/4/5 villagers every 10/8/6 s"},
}

const FAMILY_TRAITS := {
	"Undead": "Heal 1 HP per second at night",
	"Slime": "Damage you take splits off a blob that hits the nearest villager",
	"Dragon": "15% of bites also spark onto a second villager",
	"Beast": "+10% speed, +25% at night",
	"Nature": "Regenerate 1 HP every 3 s while standing still",
	"Material": "Every hit you take does 1 less damage",
	"Demon": "Every kill drops 1 extra bone",
}


## 0 before form 3, then 1, 2, 3 at forms 3, 6 and 9.
static func rank_for_stage(stage: int) -> int:
	var rank := 0
	for s in UNLOCK_STAGES:
		if stage >= s:
			rank += 1
	return rank

extends RefCounted
## The 26 monster evolution lines from evolution-lines.md, 10 forms each.
## 小怪 picks one of these at his first evolution (level 3). Names are placeholders.
## Families bias the stats a little: hp, damage and speed multipliers.

const FAMILIES := {
	"Undead": {"hue": 0.28, "hp": 1.0, "dmg": 1.0, "spd": 1.0},
	"Slime": {"hue": 0.58, "hp": 1.25, "dmg": 0.9, "spd": 1.0},
	"Dragon": {"hue": 0.02, "hp": 1.0, "dmg": 1.2, "spd": 1.0},
	"Beast": {"hue": 0.09, "hp": 1.0, "dmg": 1.0, "spd": 1.15},
	"Nature": {"hue": 0.36, "hp": 1.1, "dmg": 1.0, "spd": 1.0},
	"Material": {"hue": 0.12, "hp": 1.3, "dmg": 1.0, "spd": 0.9},
	"Demon": {"hue": 0.95, "hp": 1.0, "dmg": 1.15, "spd": 1.0},
}

const LINES := [
	{"family": "Undead", "forms": ["Zombie", "Rotting Walker", "Ghoul", "Plague Zombie", "Blood Thrall", "Nosferatu", "Vampire", "Elder Vampire", "Count", "Vampire Lord"]},
	{"family": "Undead", "forms": ["Skeleton", "Bone Soldier", "Grave Guard", "Skeleton Knight", "Bone Captain", "Skull Mage", "Bone Sorcerer", "Necromancer", "Dread Mage", "Lich"]},
	{"family": "Undead", "forms": ["Wisp", "Ghost", "Poltergeist", "Phantom", "Specter", "Banshee", "Wailing Queen", "Spirit Lord", "Reaper Shade", "Wraith King"]},
	{"family": "Undead", "forms": ["Scarab Husk", "Mummy", "Dust Mummy", "Tomb Guard", "Mummy Priest", "Cursed Noble", "Cursed Pharaoh", "Sun-Eater", "Sand Wraith", "Sand Tyrant"]},
	{"family": "Undead", "forms": ["Bone Pup", "Grave Hound", "Hellpup", "Hellhound", "Ember Hound", "Twin-Head Hound", "Hell Warden", "Cerberus Cub", "Warden of Hell", "Cerberus"]},
	{"family": "Undead", "forms": ["Rusty Helm", "Haunted Armor", "Living Armor", "Cursed Knight", "Iron Revenant", "Black Knight", "Dread Knight", "Doom Knight", "Death Champion", "Death Lord"]},
	{"family": "Slime", "forms": ["Slime", "Big Slime", "Fire Slime", "Magma Slime", "Molten Slime", "Gold Slime", "Platinum Slime", "Slime Squire", "Slime Cavalier", "Gel Paladin"]},
	{"family": "Slime", "forms": ["Slime", "Mender Slime", "Bubble Slime", "Mist Slime", "Cure Jelly", "Holy Slime", "King Slime", "Crowned Slime", "Slime Monarch", "Slime Emperor"]},
	{"family": "Slime", "forms": ["Slime", "Tiny Quicksilver", "Quicksilver Slime", "Silver Slime", "Mirror Slime", "Steel Slime", "Molten Silver Slime", "Mercury Slime", "Platinum Jelly", "Platinum Sovereign"]},
	{"family": "Slime", "forms": ["Slime", "Cold Slime", "Ice Slime", "Frost Jelly", "Snow Slime", "Hail Jelly", "Blizzard Jelly", "Glacier Slime", "Frozen Regent", "Glacier Sovereign"]},
	{"family": "Dragon", "forms": ["Hatchling", "Dragonling", "Wyvern", "Fire Wyvern", "Drake", "Fire Drake", "Flame Dragon", "Inferno Dragon", "Ancient Dragon", "Elder Dragon"]},
	{"family": "Dragon", "forms": ["Spark Newt", "Static Lizard", "Thunder Lizard", "Bolt Wyrm", "Storm Wyrm", "Storm Drake", "Thunder Drake", "Thunder Dragon", "Tempest Dragon", "Thunder Emperor"]},
	{"family": "Dragon", "forms": ["Frost Whelp", "Snow Wyrm", "Ice Wyrm", "Blizzard Wyrm", "Frost Drake", "Ice Drake", "Blizzard Dragon", "Frost Dragon", "Winter Wyrm", "Glacier Dragon"]},
	{"family": "Dragon", "forms": ["Lizardling", "Lizardman", "Lizard Warrior", "Lizard Captain", "Drake Soldier", "Dragonewt", "Dragon Knight", "Dragon Champion", "Dragon General", "Dragon Lord"]},
	{"family": "Beast", "forms": ["Wolf Pup", "Wolf", "Dire Wolf", "Wild Alpha", "Wolfman", "Werewolf", "Moon Wolf", "Blood Moon Wolf", "Fenrir Spawn", "Fenrir"]},
	{"family": "Beast", "forms": ["Cub", "Wildcat", "Sabertooth", "War Panther", "Lion Beast", "Winged Lion", "Chimera Cub", "Chimera", "Great Chimera", "Manticore"]},
	{"family": "Beast", "forms": ["Bat", "Giant Bat", "Vampire Bat", "Blood Bat", "Dire Bat", "Night Stalker", "Night Wing", "Dusk Lord", "Eclipse Bat", "Moon Lord"]},
	{"family": "Nature", "forms": ["Seed", "Sprout", "Sapling", "Thornling", "Man-Eater", "Great Man-Eater", "Ent", "Treant", "Elder Treant", "World Tree"]},
	{"family": "Nature", "forms": ["Spore", "Mushroom", "Toadstool", "Poison Cap", "Spore Shaman", "Fungal Brute", "Myconid", "Rot Bloom", "Mycelium Elder", "Mycelium King"]},
	{"family": "Nature", "forms": ["Bud", "Flower Sprite", "Petal Dancer", "Alraune", "Rose Maiden", "Vine Witch", "Dryad", "Grove Mother", "Fey Matriarch", "Forest Queen"]},
	{"family": "Material", "forms": ["Clay Lump", "Clay Golem", "Mud Golem", "Stone Golem", "Rock Golem", "Granite Golem", "Iron Golem", "Steel Colossus", "Adamant Golem", "Titan"]},
	{"family": "Material", "forms": ["Wooden Box", "Chest", "Mimic", "Gold Mimic", "Hungry Chest", "Trap Mimic", "Cursed Coffer", "Cursed Vault", "Greed Demon", "Treasure Demon"]},
	{"family": "Demon", "forms": ["Imp", "Fire Imp", "Mischief Imp", "Fiend", "Minor Demon", "Demon", "Greater Demon", "Archdemon", "Demon Prince", "Demon Lord"]},
	{"family": "Demon", "forms": ["Stone Imp", "Gargoyle", "Gargoyle Guard", "Winged Gargoyle", "Stone Fiend", "Demon Gargoyle", "Obsidian Fiend", "Hellstone Fiend", "Gargoyle Lord", "Archfiend"]},
	{"family": "Demon", "forms": ["Apprentice", "Dark Student", "Hex Caster", "Witch", "Coven Witch", "Dark Witch", "Sorceress", "Void Sorceress", "Dark Magister", "Dark Archmage"]},
	{"family": "Demon", "forms": ["Jester", "Prankster", "Mad Jester", "Evil Clown", "Trick Master", "Carnival Fiend", "Harlequin", "Ringmaster", "Chaos Jester", "Pandemonium Jester"]},
]


## Version 1 ships these 9 lines (identified by their first form); the rest show as "coming soon".
const RELEASED := ["Zombie", "Skeleton", "Wisp", "Slime", "Hatchling", "Wolf Pup", "Seed", "Clay Lump", "Imp"]


static func released(i: int) -> bool:
	return RELEASED.has(LINES[i]["forms"][0]) and not (LINES[i]["forms"][0] == "Slime" and i != 6)


## "Zombie to Vampire Lord"
static func title(i: int) -> String:
	var forms: Array = LINES[i]["forms"]
	return "%s to %s" % [forms[0], forms[forms.size() - 1]]


## Each line in a family gets a slightly different hue.
static func hue_of(i: int) -> float:
	var fam: String = LINES[i]["family"]
	var earlier := 0
	for j in i:
		if LINES[j]["family"] == fam:
			earlier += 1
	return fmod(float(FAMILIES[fam]["hue"]) + 0.025 * earlier, 1.0)

# Design draft: minimap, line abilities, enemy attacks

Status: **draft for the owner to edit**. Nothing here is built yet. Every number is a starting point to tune after play-testing.
Design rule from earlier decisions: 小怪's skills are **passive or automatic** (no extra keys), so every new ability below triggers by itself.

---

## 1. Minimap

**Goal:** the map is 180 x 100 tiles; the player needs to find villagers, hidden enemies and their own base without wandering.

- Bottom-left corner (above the build bar on phones), 200 x 112 px, the whole map shrunk to fit. Semi-transparent frame, tinted by day/night.
- Dots: 小怪 = white with a facing tick; villagers = red (size by form, 1 to 3 px); towers = blue; walls = grey; the start meadow = a green square.
- **Hidden enemies** (Parasite Hero, Dark Hero, GOD) = large pulsing dots, colour by type (green / purple / gold), always visible, so the player can hunt or avoid them.
- Fog: the map starts dark; the part you have walked within 400 px of stays revealed. Villagers show only inside the lit part, except hidden enemies. (Option: switch fog off.)
- Click or tap the minimap to ping a spot (a short arrow on the screen edge points there). Does not move the character.
- Cost: draws once per 0.2 s from the existing villager list; no pathing cost.
- **Open question:** fog on or off by default?

---

## 2. Monster line abilities

### 2.1 Framework

- Every line has **one signature ability**, gained at **form 3** (level 15) and upgraded at **form 6** (level 30) and **form 9** (level 45): rank 1, 2, 3.
- The existing skill picks (Tough Hide, Bone Nova, and so on) still happen at every level; this is a free extra tied to the evolution choice.
- Abilities are built from pieces the game already has: zones (blasts), bolts (projectiles), summons, buffs. New piece needed: **status effects** (below).
- Each family also has a small **family trait** active from form 1 (cheap to build, gives the family its feel).

### 2.2 Status effects (new)

| Effect | What it does | Typical duration |
|---|---|---|
| Burn | 1 damage per second | 4 s, refreshes |
| Chill | -35% speed | 3 s |
| Freeze | cannot move or act | 1.2 s, then immune for 4 s |
| Shock | 25% chance to jump to the nearest villager for half damage | on hit |
| Poison | 1 damage per second, stacks up to 3 | 5 s |
| Bleed | 1 damage per second, plus the villager leaves a red trail | 4 s |
| Charm | fights for 小怪 | 8 s |
| Curse | takes +50% damage | 6 s |

### 2.3 Elements and weaknesses

Elements (from the earlier notes): Fire > Ice > Wind > Earth > Thunder > Fire; Light and Dark beat each other.
Villager professions get a weakness and a resistance, so the chosen line matters against what the village sends:

| Profession | Weak to (x1.5) | Resists (x0.5) |
|---|---|---|
| Farmer | Fire | Earth |
| Woodsman | Fire | Wind |
| Hunter | Thunder | Wind |
| Militia | Dark | Earth |
| Knight | Thunder | Fire |
| Priest | Dark | Light |
| Mage | Earth | Thunder |
| Smith | Ice | Fire |
| Thief | Light | Dark |
| Noble | Poison | Light |

Hidden forms: Parasite Hero weak to Light; Dark Hero weak to Light; GOD resists everything but Dark.

### 2.4 Family traits (from form 1)

| Family | Trait |
|---|---|
| Undead | Heal 1 HP per second at night |
| Slime | 20% of damage taken is split off as a bouncing blob that hits villagers |
| Dragon | Bites have a 15% chance to also breathe a small spark (damage = one bite) |
| Beast | +10% speed always; +25% at night |
| Nature | Regenerate 1 HP per 3 s while standing still |
| Material | -1 damage from every hit (minimum 1) |
| Demon | Kills drop +1 bone |

### 2.5 The 26 signature abilities

Ability triggers on its own when the condition is met; rank 1 / 2 / 3 values are given where they change.

**Undead** (Dark, Ice, Earth)
1. **Zombie to Vampire Lord, "Blood Drain":** each bite heals 10% / 15% / 20% of its damage. Final form adds "Crimson Mist": a red cloud around you that bleeds villagers.
2. **Skeleton to Lich, "Bone Servants":** every 12 s, if 3 or more villagers are near, summon 2 / 3 / 4 skeleton helpers for 10 s.
3. **Wisp to Wraith King, "Ghost Step":** after being hit, become untouchable for 0.6 / 0.9 / 1.2 s (cooldown 8 s). Rank 3: you pass through walls and trees while untouchable.
4. **Scarab Husk to Sand Tyrant, "Sandstorm":** a sand zone around you slows villagers and makes ranged attacks miss 40% / 55% / 70% of the time.
5. **Bone Pup to Cerberus, "Triple Bite":** each bite also hits 1 / 2 / 2 extra villagers nearby; rank 3 adds a fire bark cone every 8 s (burn).
6. **Rusty Helm to Death Lord, "Iron Revenant":** -20% / -30% / -40% damage taken and reflect 10% / 15% / 25% back; rank 3: adjacent villagers take 1 damage per second from your death aura.

**Slime** (Water, Fire, Ice, Light, Metal)
7. **Slime to Gel Paladin, "Molten Trail":** while sprinting, leave burning goo that burns villagers walking over it (4 s / 6 s / 8 s).
8. **Slime to Slime Emperor, "Healing Ooze":** regain 1% max HP per second when no villager is within 150 px (2% at night); rank 3: split into 2 jelly allies for 15 s once per minute.
9. **Slime to Platinum Sovereign, "Mirror Coat":** the first ranged attack against you every 8 / 6 / 4 s is reflected back at the shooter; +10% dodge at rank 3.
10. **Slime to Glacier Sovereign, "Frost Aura":** villagers within 100 / 130 / 160 px are chilled; rank 3 freezes one random villager in range every 6 s.

**Dragon** (Fire, Ice, Thunder, Wind)
11. **Hatchling to Elder Dragon, "Fire Breath":** every 8 / 6 / 5 s, breathe fire in a cone at the nearest villager (burn). Rank 3: the cone is double width.
12. **Spark Newt to Thunder Emperor, "Chain Lightning":** bites shock; lightning jumps to 1 / 2 / 3 more villagers.
13. **Frost Whelp to Glacier Dragon, "Ice Breath":** a cone that chills; rank 2 freezes the closest villager; rank 3 leaves an ice patch that slows.
14. **Lizardling to Dragon Lord, "Spear Charge":** your lunge reach is +30% / +60% / +100% and hits through villagers; rank 3: lunge cooldown halves.

**Beast** (Wind, Earth, Dark)
15. **Wolf Pup to Fenrir, "Pack Howl":** at night, +40% speed and bites make villagers bleed; rank 3: the howl summons 2 wolf pups every 20 s.
16. **Cub to Manticore, "Tail Sting":** every 5 s, shoot a poison dart at the nearest villager (stacks up to 3 / 4 / 5).
17. **Bat to Moon Lord, "Night Flight":** immune to mud, +20% speed; "Sonar Screech" every 15 s reveals all hidden enemies on the minimap and stuns villagers within 150 px for 1 s.

**Nature** (Earth, Light, Poison)
18. **Seed to World Tree, "Rooted":** standing still for 2 s makes roots lock villagers within 120 / 150 / 180 px for 2 s; thorns hurt them.
19. **Spore to Mycelium King, "Spore Cloud":** a poison cloud follows you; villagers inside get poisoned and the cloud spreads when one dies.
20. **Bud to Forest Queen, "Charm Petals":** 10% / 15% / 20% chance that a bitten villager is charmed for 8 s (never hidden enemies).

**Material** (Earth, Metal)
21. **Clay Lump to Titan, "Stone Skin":** -2 / -3 / -4 damage per hit taken but -10% speed; rank 3: an earthquake slam every 12 s stuns villagers around you.
22. **Wooden Box to Treasure Demon, "Greed":** +50% / +75% / +100% bones and towers and walls cost 15% / 25% / 35% less; rank 3: kills sometimes drop a golden coin that heals you.

**Demon** (Dark, Fire)
23. **Imp to Demon Lord, "Hellfire Rain":** every 10 / 8 / 6 s, 3 / 4 / 5 fireballs fall on random villagers near you (with a warning ring, so they hit villagers, not you).
24. **Stone Imp to Archfiend, "Stone Form":** when HP drops below 35%, turn to stone for 1.5 / 2 / 3 s: untouchable, then a slam that stuns (cooldown 20 s).
25. **Apprentice to Dark Archmage, "Curse Hex":** every 6 s, curse the strongest villager nearby (+50% damage taken); rank 2: the curse spreads to 2 villagers beside it; rank 3: cursed villagers explode when they die.
26. **Jester to Pandemonium Jester, "Trick":** every 10 s, swap places with a random villager (a dodge) and trigger a random effect (rank 1: confetti stun, rank 2: adds a bomb, rank 3: adds a short heal wave).

### 2.6 Build effort (rough)

1. Status effects plus the minimap: biggest shared piece.
2. One ability per family first (7), then the other 19 reuse the same parts.
3. Every ability gets an automated test, as the existing skills do.

**Open questions for the owner**
- Fix the unlock at form 3, 6, 9, or earlier so the line choice at level 5 matters right away?
- Keep the villager weakness table, or leave elements out and keep the status effects only?

---

## 3. More enemy attacks

They join the existing 17 attack types. Each shows a warning and has a counter.

| Attack | Who | Unlocks | Warning | Counter |
|---|---|---|---|---|
| **Catapult shot** | Smith final form (rolls a catapult) | after 12 min | red target ring, 1.5 s, then a boulder | walls and towers take the damage; roll out of the ring |
| **Mounted charge** | Knight 4th form and up | after 8 min | a line is drawn on the ground | sidestep, or block with a wall |
| **Hidden trap** | Hunter 3rd form and up | after 8 min | faint outline only close up | trigger it with a dash; a Sonar skill reveals it |
| **Dispel** | Priest 3rd form and up | after 10 min | white beam | removes your temporary buffs only |
| **Curse mark** | Priest or Mage final form | after 12 min | purple rune over you | your skills recharge 30% slower for 6 s; kill the caster |
| **Formation squad** | Militia captain | every 4 min | horn sound, banner on the minimap | arrives as 6 villagers in a line with a shield wall; flank them |
| **Poison arrow** | Hunter final form | after 10 min | green arrow trail | poison status on you |

New rules to keep it fair (from the gentle-start decision): nothing new switches on before the listed minute, and each gets a notice on screen when it unlocks.

---

## 4. Suggested build order

1. Minimap (fog optional). Small, helps immediately.
2. Status-effect system plus the 7 family traits.
3. First ability for each family (Blood Drain, Bone Servants, Molten Trail, Fire Breath, Pack Howl, Rooted, Stone Skin, Hellfire Rain), then the rest.
4. The villager element weaknesses.
5. The new enemy attacks, one by one, easiest first (poison arrow, curse mark, mounted charge).
6. Balance pass after you have played each stage.

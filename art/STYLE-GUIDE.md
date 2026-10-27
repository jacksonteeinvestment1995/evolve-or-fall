# 小怪 (Xiao Guai) HD-2D Art Style Guide, batch 1

Sprites are crisp low-res pixel art (nearest-neighbour only). The "HD-2D" look comes from the world around them:
soft coloured lights with bloom, soft cast shadows, tilt-shift blur on the top and bottom screen bands, a vignette,
day/night grading and particles. `preview.html` simulates all of it in canvas code. The sprites never carry blur.

## Camera and light
- Top-down 3/4 view: draw the **front** of every character with a slight look-from-above (visible top of head, ground contact at the feet).
- Zoomed so a 16 px sprite is about 32 px on screen (2x). Every character must read at a glance at 2x.
- Light comes from the **top-left**: highlights top-left, shade bottom-right, cast shadow falls bottom-right (the engine draws it).
- Minimum three tones per material (shadow / base / light). Glowing things (eyes, fire, runes, auras) get a 1 px **rim light** on the lit edge.

## Palette (44 of 48 colours, `palette.js`)
Built as ramps. Shadows lean cooler/purple, highlights lean warmer. No pure black, no pure white. Darkest = `K`, a deep blue-purple.

| Ramp | Keys (dark -> light) | Hex |
|---|---|---|
| Ink / stone | `K J S s t T` | #140f26 #2a2142 #4a4366 #766f95 #a6a1c0 #e6e1ee |
| Hero purple | `U P p q` | #33205c #5a389c #8861cc #b99bf0 |
| Bone / cream (horns, teeth) | `B b C c` | #9e869c #d6c0a0 #f1e2bd #fff1d0 |
| Blood / fire | `R r e o y Y W` | #5f1a40 #b02e4e #e8584c #f08a3c #ffbe45 #ffe479 #fff7c8 |
| Foliage / grass | `L G g h H` | #153a40 #26624a #489a52 #7ac258 #b4e682 |
| Wood / earth | `D d w x` | #35203a #653f3a #976541 #c8915c |
| Skin | `z Z k` | #b8706a #e8a486 #ffd2ae |
| Steel blue / water | `A a l I` | #1c2b68 #3b5fb6 #6a9ee6 #a6d2f8 |
| Spirit cyan | `F f` | #2fa6b0 #8eeee0 |
| Magenta / noble | `M m` | #c8488a #f490b4 |
| Undead flesh | `1 2 3` | #36535a #688a74 #a0b88c |

`T` and `W` are the brightest values (soft white / hot glow). `.` is transparent.

## Outlines
1 px, selective: use a **dark tone of the sprite's own hue**, never one global colour. Purple body -> `U`; flesh -> `1`; wood/leather/skin -> `D`;
foliage -> `L`; red/fire -> `R`; blue cloth/steel -> `A`; stone/bone/neutral -> `J` or `K`. The outline may break (go lighter or vanish) where light hits the top-left edge.

## Identity rules
- **Every hero form keeps the two small cream horns (`b C c`) and the two eyes.** Red eyes from form 5, fangs from form 6, cape from form 9, crown/aura on form 10.
- Head and eyes are big in early forms and the body stretches as the creature grows, so the forms read as one creature evolving.
- Villagers of one profession share a colour and a signature prop; form 5 is visibly an upgrade of form 1 (more armour, bigger weapon, cape, plume, glow).
- Cute first, darker later. Never graphic or gory (audience 13+).
- All art is original folklore-archetype design, no borrowed designs.

## Sizes (px)
| Thing | Size |
|---|---|
| Xiao Guai base | 16x16 |
| Hero stages 1-2 / 3-5 / 6-8 / 9-10 | 16 / 24 / 32 / 40 (the Vampire Lord may use 48) |
| Villagers form 1 (and 2) / forms 3-5 | 16x16 / 20x20 |
| Hidden forms | Parasite Hero and Dark Hero 24-32, GOD 32-48 |
| Tiles | 32x32 (trees 32x48) |
| Structures | 32x32; towers L1 32x32, L2 32x40, L3 32x48, feet aligned at the bottom |
| Effects | 16x16 or 24x24, 3-5 frames |
| Icons | 16x16 or 24x24 |

Every character has an idle pair (2 frames: a 1 px bob or a blink).

## Data format
`palette.js`: `const PALETTE = { "K": "#140f26", ... };` (key char -> hex, `.` is transparent and not listed).

`sprites.js`: `const SPRITES = { "name": { "w": 16, "h": 16, "section": "hero", "label": "Xiao Guai", "frames": [ [row, row, ...], [row, ...] ] } };`
Every row is a string of exactly `w` palette keys or `.`; every frame has exactly `h` rows.

Source of truth is `art/src/*.spr` (plain text, easier to edit by hand):
```
sprite <name> <w> <h> <section> "<label>"
frame
<h rows of exactly w characters>
frame
<h rows>
end
```
Sections: `hero villager hidden structure tile effect icon`.
Tools (Python 3 stdlib only): `python3 art/build.py` merges `src/*.spr` into `sprites.js` and bakes `preview.html` from `preview.src.html`;
`python3 art/validate.py` checks palette, row/frame sizes, palette keys, idle frames, size table and batch coverage;
`python3 art/tools/sheet.py out.png 8 art/src/x.spr` renders a PNG contact sheet.

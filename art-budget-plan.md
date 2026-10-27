# HD-2D pixel art: budget plan for the remaining sprites

Status: proposal. Nothing here has been started or paid for. Prices are from mid-2026 web pages and may have changed.

## Where we are
- Batch 1 and 2 (GitHub PRs #1 and #2, private repo `jacksonteeinvestment1995/xiaoguai-game`): 167 sprites.
  - 10 villager professions x 5 forms
  - 3 hidden forms
  - 3 Undead lines (10 forms each)
  - form 1 and form 10 of 6 more lines
- Missing: about 218 hero forms (17 whole lines = 170, plus the 8 middle forms of 6 lines = 48), effects for the new skills, shore and path edge tiles.
- The art has not been applied to Godot. The user wants to check it first.

## Options, cheapest first
1. **Ship fewer lines in version 1.** Offer 9 lines: the 3 Undead lines (done) plus Slime, Dragon, Beast, Nature, Material and Demon. Show the other 17 as "coming soon". Saves about 150 sprites. The YouTube version has one stage, so few players will see all 26 lines.
2. **Build forms from parts with a script.** About 60 drawn parts:
   - one base body per family, in 3 size tiers
   - overlays for horns, wings, armour, cape and aura
   - one recolour per line (the night palette swap already exists in `art/palette_night.json`)

   The cheaper model runs the script. Fable draws only the parts and the final boss forms.
3. **No walk cycles.** The game is top-down front view. Squash, bob and flip are done in Godot at no art cost.
4. **HD-2D look from Godot, not art.** Lighting, glow, blur, vignette and the night tint are shader and light settings.
5. **Optional paid pixel tool.** PixelLab is about $12 a month. Retro Diffusion is a one-time purchase of about $20 to $65. Aseprite is $19.99 (LibreSprite and Piskel are free). AI output needs cleanup, so a script would snap it to our 44-colour palette. Try one month on one line and compare it with Fable's version.
6. **Free packs for filler only.** Shade's PUNY MYTH-CREATURES is CC0 and 16x16. Its style clashes with our heroes, so use it for props and extra enemies at most. Check each pack's license page first.

## Recommendation
Options 1 to 4: a 9-line version 1, a parts-and-recolour script, Godot animation and Godot lighting.

## Rules to save tokens
- Hard sprite cap per cloud session, and small briefs.
- Fable only for new silhouettes. One polish pass at most.
- The cheaper model does validation, export and preview.
- Work out the price per sprite from batch 2's spend (88 sprites), then set the cap for the next batch.

## Decision (2026-10-27)
User approved the recommendation (options 1 to 4). Still open: the exact line count (9 proposed) and the sprite cap per session. Also in the mind map under Art & Audio.

## Next steps
1. Put the existing 167 sprites into the Godot game, so the user can see how they look in play and what is still missing.
2. User picks the cap and the line count (9 or more).
3. Write the parts-and-recolour script.
4. Draw the parts, with a capped Fable session.

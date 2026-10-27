#!/usr/bin/env python3
"""Validate the art batch. Python 3 stdlib only.
  python3 art/validate.py                    full check of palette.js + sprites.js (+ batch-1 coverage)
  python3 art/validate.py --src a.spr ...    check .spr source files only (format, palette chars, size rules)
Exit code 0 = PASS, 1 = FAIL."""
import sys, os, re, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sprio

HEX = re.compile(r'^#[0-9a-fA-F]{6}$')
# name -> (section, allowed (w,h) list, min frames, max frames)
def S(sec, sizes, lo, hi): return (sec, sizes, lo, hi)
M = {}
M['xiaoguai_base'] = S('hero', [(16, 16)], 2, 2)
for n, sz in [('undead_01_zombie', 16), ('undead_02_rotting_walker', 16), ('undead_03_ghoul', 24), ('undead_04_plague_zombie', 24),
              ('undead_05_blood_thrall', 24), ('undead_06_nosferatu', 32), ('undead_07_vampire', 32), ('undead_08_elder_vampire', 32),
              ('undead_09_count', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
M['undead_10_vampire_lord'] = S('hero', [(40, 40), (48, 48)], 2, 2)
VIL = [('farmer', 'villager', 'harvest_lord'), ('woodsman', 'woodcutter', 'forest_warden'), ('hunter', 'hunter', 'sniper'),
       ('militia', 'militia', 'captain'), ('knight', 'squire', 'templar'), ('priest', 'acolyte', 'saint'),
       ('mage', 'apprentice', 'grand_magus'), ('smith', 'smith', 'titan_smith'), ('thief', 'thief', 'night_master'), ('noble', 'noble', 'emperor')]
for p, a, b in VIL:
    M[f'{p}_1_{a}'] = S('villager', [(16, 16)], 2, 2)
    M[f'{p}_5_{b}'] = S('villager', [(20, 20)], 2, 2)
M['hidden_parasite_hero'] = S('hidden', [(24, 24), (28, 28), (32, 32)], 2, 2)
M['hidden_dark_hero'] = S('hidden', [(24, 24), (28, 28), (32, 32)], 2, 2)
M['hidden_god'] = S('hidden', [(32, 32), (40, 40), (48, 48)], 2, 2)
M['bone_wall'] = S('structure', [(32, 32)], 1, 2)
M['bone_wall_damaged'] = S('structure', [(32, 32)], 1, 2)
M['bone_tower_1'] = S('structure', [(32, 32), (32, 40)], 2, 2)
M['bone_tower_2'] = S('structure', [(32, 40), (32, 48)], 2, 2)
M['bone_tower_3'] = S('structure', [(32, 48)], 2, 2)
for n in ['grass_1', 'grass_2', 'grass_3', 'mud', 'stone_path']: M[n] = S('tile', [(32, 32)], 1, 1)
for n in ['tree_1', 'tree_2']: M[n] = S('tile', [(32, 48)], 1, 2)
FX = [(16, 16), (24, 24), (16, 24), (24, 16)]
for n in ['bite_slash', 'spirit_bolt', 'enemy_arrow', 'fireball_explosion', 'bone_nova', 'roar_wave', 'heal_sparkle', 'level_up_ring']:
    M['fx_' + n] = S('effect', FX, 3, 5)
for n in ['frost', 'bone', 'scream', 'magma', 'gust', 'fire', 'roar', 'thorn', 'roots', 'stomp', 'curse', 'spark']:
    M['fx_skill_' + n] = S('effect', [(48, 48)], 4, 4)
for n in ['burn', 'chill', 'poison', 'bleed', 'curse', 'root', 'stun', 'freeze']:
    M['status_' + n] = S('effect', [(8, 8)], 1, 1)
for n in ['burn', 'poison', 'bleed', 'chill', 'curse']:
    M['fx_proc_' + n] = S('effect', [(16, 16)], 3, 3)
for n in ['tough_hide', 'sharp_fangs', 'swift_paws', 'quick_jaws', 'soul_drain', 'bone_collector', 'bone_nova', 'spirit_bolt', 'shadow_step', 'roar',
          'build_tower', 'build_wall', 'build_remove', 'heart', 'bone', 'exp_orb']:
    M['icon_' + n] = S('icon', [(16, 16), (24, 24)], 1, 2)
for n in ['z_grip', 'z_plague', 'z_chill', 'z_feast', 'z_undying', 'z_crimson', 's_plating', 's_spear', 's_marrow', 's_storm', 's_gaze', 's_pact',
          'w_drift', 'w_touch', 'w_wail', 'w_haunt', 'w_veil', 'w_harvest', 'l_gel', 'l_goo', 'l_splash', 'l_bounce', 'l_absorb', 'l_armor',
          'd_scale', 'd_ember', 'd_gust', 'd_heart', 'd_inferno', 'd_might', 'b_fangs', 'b_rake', 'b_sense', 'b_rush', 'b_roar', 'b_alpha',
          'n_bark', 'n_thorn', 'n_photo', 'n_venom', 'n_tangle', 'n_bloom', 'm_shell', 'm_fists', 'm_quake', 'm_resolve', 'm_core', 'm_titan',
          'e_claws', 'e_brand', 'e_pact', 'e_spark', 'e_curse', 'e_might']:
    M['icon_fs_' + n] = S('icon', [(16, 16)], 1, 1)
    M['skill_' + n] = S('icon', [(16, 16)], 1, 1)   # art/src/skill_icons.spr
for n in ['z_spit', 'z_cloud', 'z_surge', 's_toss', 's_rattle', 's_ossuary', 'w_orbs', 'w_mist', 'w_phase', 'l_glob', 'l_burst', 'l_ooze',
          'd_fireball', 'd_wingstorm', 'd_scales', 'b_claw', 'b_howl', 'b_pack', 'n_seeds', 'n_spores', 'n_grove', 'm_rocks', 'm_slide',
          'm_fortress', 'e_hellbolt', 'e_ruin', 'e_dominion']:
    M['icon_fs_' + n] = S('icon', [(16, 16)], 1, 1)   # art/src/icons_form_skills2.spr
for n in ['overdrive', 'frenzy', 'ironwill', 'secondwind', 'phoenix', 'cleave', 'stormcaller', 'bloodmoon', 'gravity', 'titan', 'mastery', 'bonehoard']:
    M['icon_sp_' + n] = S('icon', [(16, 16)], 1, 1)   # art/src/icons_special.spr

# ---- batch 2 manifest ----
VIL2 = {'farmer': [('farmer', 'Farmer'), ('harvester', 'Harvester'), ('scythe_master', 'Scythe Master')],
        'woodsman': [('lumberjack', 0), ('axeman', 0), ('berserker', 0)], 'hunter': [('archer', 0), ('ranger', 0), ('marksman', 0)],
        'militia': [('footman', 0), ('soldier', 0), ('veteran', 0)], 'knight': [('knight', 0), ('paladin', 0), ('crusader', 0)],
        'priest': [('priest', 0), ('cleric', 0), ('high_priest', 0)], 'mage': [('mage', 0), ('battlemage', 0), ('archmage', 0)],
        'smith': [('armorer', 0), ('forgemaster', 0), ('iron_smith', 0)], 'thief': [('rogue', 0), ('assassin', 0), ('shadow_blade', 0)],
        'noble': [('lord', 0), ('duke', 0), ('king', 0)]}
for p_, forms in VIL2.items():
    for i, (slug, _) in enumerate(forms):
        M[f'{p_}_{i + 2}_{slug}'] = S('villager', [(16, 16)] if i == 0 else [(20, 20)], 2, 2)
HERO_SIZES = [16, 16, 24, 24, 24, 32, 32, 32, 40, 40]
def line(prefix, slugs, boss48=True):
    for i, sl in enumerate(slugs):
        sz = HERO_SIZES[i]
        M[f'{prefix}_{i + 1:02d}_{sl}'] = S('hero', [(sz, sz)] if i < 9 else [(40, 40), (48, 48)], 2, 2)
line('skeleton', ['skeleton', 'bone_soldier', 'grave_guard', 'skeleton_knight', 'bone_captain', 'skull_mage', 'bone_sorcerer', 'necromancer', 'dread_mage', 'lich'])
line('wisp', ['wisp', 'ghost', 'poltergeist', 'phantom', 'specter', 'banshee', 'wailing_queen', 'spirit_lord', 'reaper_shade', 'wraith_king'])
for pre, a, b in [('slime', 'slime', 'gel_paladin'), ('dragon', 'hatchling', 'elder_dragon'), ('beast', 'wolf_pup', 'fenrir'),
                  ('nature', 'seed', 'world_tree'), ('material', 'clay_lump', 'titan'), ('demon', 'imp', 'demon_lord')]:
    M[f'{pre}_01_{a}'] = S('hero', [(16, 16)], 2, 2)
    M[f'{pre}_10_{b}'] = S('hero', [(40, 40), (48, 48)], 2, 2)
for n, sz in [('dragon_02_dragonling', 16), ('dragon_03_wyvern', 24), ('dragon_04_fire_wyvern', 24), ('dragon_05_drake', 24), ('dragon_06_fire_drake', 32),
              ('dragon_07_flame_dragon', 32), ('dragon_08_inferno_dragon', 32), ('dragon_09_ancient_dragon', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
for n, sz in [('beast_02_wolf', 16), ('beast_03_dire_wolf', 24), ('beast_04_wild_alpha', 24), ('beast_05_wolfman', 24),
              ('beast_06_werewolf', 32), ('beast_07_moon_wolf', 32), ('beast_08_blood_moon_wolf', 32), ('beast_09_fenrir_spawn', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
for n, sz in [('nature_02_sprout', 16), ('nature_03_sapling', 24), ('nature_04_thornling', 24), ('nature_05_man_eater', 24),
              ('nature_06_great_man_eater', 32), ('nature_07_ent', 32), ('nature_08_treant', 32), ('nature_09_elder_treant', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
for n, sz in [('slime_02_big_slime', 16), ('slime_03_fire_slime', 24), ('slime_04_magma_slime', 24), ('slime_05_molten_slime', 24),
              ('slime_06_gold_slime', 32), ('slime_07_platinum_slime', 32), ('slime_08_slime_squire', 32), ('slime_09_slime_cavalier', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
for n, sz in [('material_02_clay_golem', 16), ('material_03_mud_golem', 24), ('material_04_stone_golem', 24), ('material_05_rock_golem', 24),
              ('material_06_granite_golem', 32), ('material_07_iron_golem', 32), ('material_08_steel_colossus', 32), ('material_09_adamant_golem', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
for n, sz in [('demon_02_fire_imp', 16), ('demon_03_mischief_imp', 24), ('demon_04_fiend', 24), ('demon_05_minor_demon', 24),
              ('demon_06_demon', 32), ('demon_07_greater_demon', 32), ('demon_08_archdemon', 32), ('demon_09_demon_prince', 40)]:
    M[n] = S('hero', [(sz, sz)], 2, 2)
# walk (4 frames) / attack (3 frames): same size as the idle sprite
WA = {'xiaoguai_base': (16, 'hero'), 'undead_01_zombie': (16, 'hero'), 'undead_10_vampire_lord': (48, 'hero')}
for p_, a, b in VIL:
    WA[f'{p_}_1_{a}'] = (16, 'villager')
for n, (sz, sec) in WA.items():
    M[n + '_walk'] = S(sec, [(sz, sz)], 4, 4)
    M[n + '_attack'] = S(sec, [(sz, sz)], 3, 3)
# props
PROP_SIZES = [(16, 16), (32, 32), (32, 48), (48, 32)]
M['tile_water'] = S('tile', [(32, 32)], 2, 3)
for d_ in ['edge_n', 'edge_e', 'edge_s', 'edge_w', 'corner_ne', 'corner_se', 'corner_sw', 'corner_nw', 'inner_ne', 'inner_se', 'inner_sw', 'inner_nw']:
    M['shore_' + d_] = S('tile', [(32, 32)], 1, 3)      # frames follow tile_water
    M['pathedge_' + d_] = S('tile', [(32, 32)], 1, 1)
for n in ['prop_fence', 'prop_fence_corner', 'prop_rocks_1', 'prop_rocks_2', 'prop_bush', 'prop_flowers_1', 'prop_flowers_2', 'prop_gravestone']:
    M[n] = S('tile', PROP_SIZES, 1, 2)

def check_palette(pal, errs, notes):
    if not pal: errs.append('palette is empty'); return
    if len(pal) > 48: errs.append(f'palette has {len(pal)} colours (max 48)')
    for k, v in pal.items():
        if len(k) != 1: errs.append(f'palette key {k!r} is not a single character')
        if k == '.': errs.append("palette must not define '.' (transparent)")
        if not HEX.match(v): errs.append(f'palette {k!r}: bad hex {v!r}')
        elif v.lower() in ('#000000', '#ffffff'): errs.append(f'palette {k!r}: pure black/white {v}')
    vals = [v.lower() for v in pal.values()]
    dup = {v for v in vals if vals.count(v) > 1}
    if dup: errs.append(f'duplicate colours in palette: {sorted(dup)}')
    notes.append(f'palette: {len(pal)} colours')
    try:
        nj = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'palette_night.json'), encoding='utf-8'))
        bad = [k for k in pal if k not in nj['map']] + [f'{k}->{v}' for k, v in nj['map'].items() if k not in pal or v not in pal]
        if bad: errs.append(f'palette_night.json does not cover/target palette keys: {bad}')
    except Exception as e: errs.append(f'palette_night.json: {e}')

def check_sprites(sprites, pal, errs, warns, require_all):
    used = set()
    for name, s in sprites.items():
        tag = f'[{name}]'
        for key in ('w', 'h', 'frames'):
            if key not in s: errs.append(f'{tag} missing {key}'); break
        else:
            w, h, fr = s['w'], s['h'], s['frames']
            if not fr: errs.append(f'{tag} no frames'); continue
            for fi, f in enumerate(fr):
                if len(f) != h: errs.append(f'{tag} frame {fi}: {len(f)} rows, expected h={h}')
                for ri, row in enumerate(f):
                    if len(row) != w: errs.append(f'{tag} frame {fi} row {ri}: {len(row)} chars, expected w={w}: {row}')
                    for ch in row:
                        if ch == '.': continue
                        if ch not in pal: errs.append(f'{tag} frame {fi} row {ri}: unknown palette key {ch!r}'); break
                        used.add(ch)
            ok_rows = all(len(f) == h and all(len(r) == w for r in f) for f in fr)
            if ok_rows:
                if all(c == '.' for c in ''.join(fr[0])): errs.append(f'{tag} first frame is empty')
                if s.get('section') in ('hero', 'villager', 'hidden') and len(fr) >= 2 and fr[0] == fr[1]:
                    errs.append(f'{tag} idle frames are identical')
                cols = {c for f in fr for r in f for c in r if c != '.'}
                if len(cols) > 28: warns.append(f'{tag} uses {len(cols)} colours (busy)')
        if name in M:
            sec, sizes, lo, hi = M[name]
            if (s.get('w'), s.get('h')) not in sizes: errs.append(f'{tag} size {s.get("w")}x{s.get("h")} not allowed, expected one of {sizes}')
            if not lo <= len(s.get('frames', [])) <= hi: errs.append(f'{tag} {len(s.get("frames", []))} frames, expected {lo}-{hi}')
            if s.get('section', sec) != sec: errs.append(f'{tag} section {s.get("section")!r}, expected {sec!r}')
        else:
            warns.append(f'{tag} not in the batch-1 manifest (extra sprite)')
    if require_all:
        missing = [n for n in M if n not in sprites]
        if missing: errs.append(f'missing {len(missing)} sprites: {missing}')
    return used

def main():
    args = sys.argv[1:]
    errs, warns, notes = [], [], []
    pal = sprio.load_palette()
    check_palette(pal, errs, notes)
    if args and args[0] == '--src':
        sprites = {}
        for f in args[1:]:
            d, pe = sprio.parse_spr(f); errs += pe
            for n in d:
                if n in sprites: errs.append(f'duplicate sprite {n}')
            sprites.update(d)
        used = check_sprites(sprites, pal, errs, warns, False)
        mode = 'src'
    else:
        base = os.path.dirname(os.path.abspath(__file__))
        try: sprites = sprio.load_js(os.path.join(base, 'sprites.js'), 'SPRITES')
        except Exception as e: print('FAIL: cannot read sprites.js:', e); sys.exit(1)
        used = check_sprites(sprites, pal, errs, warns, True)
        mode = 'full'
    notes.append(f'sprites: {len(sprites)}; frames: {sum(len(s.get("frames", [])) for s in sprites.values())}')
    unused = sorted(set(pal) - used)
    if mode == 'full' and unused: warns.append(f'palette keys never used: {unused}')
    for n in notes: print('  ' + n)
    for w in warns: print('  warn:', w)
    for e in errs: print('  ERROR:', e)
    print(('PASS' if not errs else f'FAIL ({len(errs)} errors)') + f'  [{mode}]')
    sys.exit(1 if errs else 0)
if __name__ == "__main__":
    main()

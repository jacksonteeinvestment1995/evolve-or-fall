#!/usr/bin/env python3
"""Export every sprite of art/sprites.js as a PNG strip for Godot (stdlib only).
  python3 art/tools/export_png.py [out_dir]       default out_dir = art/export
Writes <out_dir>/<sprite_name>.png : all frames side by side (frame i starts at x = i * frame_w), 1x scale, RGBA, transparent
background, no padding. Night variants of the tiles listed in palette_night.json are written as <name>_night.png.
Also writes <out_dir>/atlas.json: {"sprites": [{name, label, section, file, frame_w, frame_h, frames, fps, loop, kind}, ...]}
and runs tools/check_png.py on the result."""
import sys, os, zlib, struct, json
HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, '..')
sys.path.insert(0, ART)
import sprio

def write_png(path, w, h, rgba):
    raw = b''.join(b'\x00' + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    def ch(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))

def kind_fps(name, s):
    """(kind, suggested frames-per-second, loop)"""
    n = len(s['frames'])
    if name.endswith('_walk'): return 'walk', 8, True
    if name.endswith('_attack'): return 'attack', 12, False
    sec = s['section']
    if n == 1: return 'static', 0, False
    if sec == 'effect': return 'effect', 12, False
    if name == 'tile_water': return 'tile_anim', 3, True
    return 'idle', 2, True          # heroes, villagers, hidden, icons, towers: 2-frame bob/blink

def main():
    out = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(ART, 'export')
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith('.png'): os.remove(os.path.join(out, f))
    pal = sprio.load_palette()
    rgb = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in pal.items()}
    nj = json.load(open(os.path.join(ART, 'palette_night.json')))
    sprites = sprio.load_js(os.path.join(ART, 'sprites.js'), 'SPRITES')
    jobs = [(n, s, None) for n, s in sprites.items()] + [(n + '_night', sprites[n], nj['map']) for n in nj['night_sprites'] if n in sprites]
    atlas = []
    for name, s, swap in jobs:
        w, h, nf = s['w'], s['h'], len(s['frames'])
        px = bytearray(w * nf * h * 4)
        for fi, fr in enumerate(s['frames']):
            for y, row in enumerate(fr):
                for x, c in enumerate(row):
                    if c == '.': continue
                    r, g, b = rgb[swap[c] if swap else c]
                    o = (y * w * nf + fi * w + x) * 4
                    px[o:o + 4] = bytes((r, g, b, 255))
        write_png(os.path.join(out, name + '.png'), w * nf, h, px)
        kind, fps, loop = kind_fps(name, s)
        e = {'name': name, 'label': s['label'] + (' (night)' if swap else ''), 'section': s['section'], 'file': name + '.png',
             'frame_w': w, 'frame_h': h, 'frames': nf, 'fps': fps, 'loop': loop, 'kind': kind}
        if swap: e['derived_from'] = name[:-6]
        atlas.append(e)
    json.dump({'_doc': 'Each PNG is a horizontal strip: frame i occupies x = i*frame_w .. (i+1)*frame_w. fps is a suggested animation speed (0 = static). Pixel art: use nearest filtering.',
               'palette_colours': len(pal), 'sprites': atlas}, open(os.path.join(out, 'atlas.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print(f'exported {len(atlas)} PNG strips + atlas.json to {out}')
    import subprocess
    sys.exit(subprocess.call([sys.executable, os.path.join(HERE, 'check_png.py'), out]))
if __name__ == '__main__': main()

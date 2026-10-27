#!/usr/bin/env python3
"""Re-read the PNGs written by export_png.py and verify them (stdlib only).
Checks per file: signature, chunk CRCs, IHDR (8-bit RGBA, no interlace), IDAT decompresses to exactly h*(1+4w) bytes,
filter bytes are 0, dimensions equal atlas frame_w*frames x frame_h, and (with sprites.js available) the pixels equal the sprite data.
usage: python3 art/tools/check_png.py [export_dir]      exit code 0 = all valid"""
import sys, os, zlib, struct, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))

def read_png(path):
    d = open(path, 'rb').read()
    if d[:8] != b'\x89PNG\r\n\x1a\n': raise ValueError('bad signature')
    pos, chunks = 8, []
    while pos < len(d):
        n, = struct.unpack('>I', d[pos:pos + 4]); t = d[pos + 4:pos + 8]; body = d[pos + 8:pos + 8 + n]
        crc, = struct.unpack('>I', d[pos + 8 + n:pos + 12 + n])
        if zlib.crc32(t + body) & 0xffffffff != crc: raise ValueError(f'bad CRC in {t!r}')
        chunks.append((t, body)); pos += 12 + n
    if not chunks or chunks[0][0] != b'IHDR' or chunks[-1][0] != b'IEND': raise ValueError('missing IHDR/IEND')
    w, h, bd, ct, cm, fm, il = struct.unpack('>IIBBBBB', chunks[0][1])
    if (bd, ct, il) != (8, 6, 0): raise ValueError(f'expected 8-bit RGBA non-interlaced, got depth={bd} type={ct} interlace={il}')
    raw = zlib.decompress(b''.join(b for t, b in chunks if t == b'IDAT'))
    if len(raw) != h * (1 + 4 * w): raise ValueError(f'data length {len(raw)} != {h * (1 + 4 * w)}')
    rows = []
    for y in range(h):
        row = raw[y * (1 + 4 * w):(y + 1) * (1 + 4 * w)]
        if row[0] != 0: raise ValueError('unexpected filter type')
        rows.append(row[1:])
    return w, h, rows

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'export')
    atlas = json.load(open(os.path.join(out, 'atlas.json'), encoding='utf-8'))
    import sprio
    pal = sprio.load_palette()
    rgb = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in pal.items()}
    night = json.load(open(os.path.join(HERE, '..', 'palette_night.json')))['map']
    sprites = sprio.load_js(os.path.join(HERE, '..', 'sprites.js'), 'SPRITES')
    bad = 0
    for e in atlas['sprites']:
        p = os.path.join(out, e['file'])
        try:
            w, h, rows = read_png(p)
            if (w, h) != (e['frame_w'] * e['frames'], e['frame_h']): raise ValueError(f'size {w}x{h} != atlas {e["frame_w"] * e["frames"]}x{e["frame_h"]}')
            src = sprites[e.get('derived_from', e['name'])]
            for fi, fr in enumerate(src['frames']):
                for y, row in enumerate(fr):
                    for x, ch in enumerate(row):
                        if e.get('derived_from') and ch != '.': ch = night[ch]
                        o = (fi * e['frame_w'] + x) * 4
                        got = tuple(rows[y][o:o + 4]); want = (0, 0, 0, 0) if ch == '.' else rgb[ch] + (255,)
                        if got != want: raise ValueError(f'pixel mismatch frame {fi} ({x},{y}): {got} != {want}')
        except Exception as ex:
            bad += 1; print('BAD ', e['file'], ex)
    print(f'checked {len(atlas["sprites"])} PNGs: ' + ('PASS' if not bad else f'FAIL ({bad} bad)'))
    sys.exit(1 if bad else 0)
if __name__ == '__main__': main()

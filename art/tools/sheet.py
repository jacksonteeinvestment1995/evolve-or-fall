#!/usr/bin/env python3
"""Render .spr source files to a PNG contact sheet (stdlib only) so the art can be eyeballed.
usage: sheet.py out.png scale file.spr [file.spr ...]   (also prints the sprite order)"""
import sys, zlib, struct, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import sprio

def png(path, W, H, px):
    raw = b''.join(b'\x00' + bytes(px[y*W*3:(y+1)*W*3]) for y in range(H))
    def ch(t, d): c = struct.pack('>I', len(d)) + t + d; return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 6)) + ch(b'IEND', b''))

def main():
    out, scale, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    pal = sprio.load_palette()
    rgb = {k: tuple(int(v[i:i+2], 16) for i in (1, 3, 5)) for k, v in pal.items()}
    sprites = {}
    for f in files: sprites.update(sprio.parse_spr(f)[0])
    maxw, pad = 1500, 10
    items = []
    for n, s in sprites.items():
        items.append((n, s, (s['w'] * len(s['frames'])) * scale + pad * len(s['frames']), s['h'] * scale))
    # layout
    x = y = pad; rowh = 0; place = []
    for n, s, w, h in items:
        if x + w > maxw and x > pad: x = pad; y += rowh + pad; rowh = 0
        place.append((n, s, x, y)); x += w + pad; rowh = max(rowh, h)
    W, H = maxw, y + rowh + pad
    bg = [(38, 34, 54), (46, 41, 64)]
    px = bytearray(W * H * 3)
    for j in range(H):
        for i in range(W):
            c = bg[((i // 16) + (j // 16)) & 1]; o = (j * W + i) * 3; px[o:o+3] = bytes(c)
    for idx, (n, s, ox, oy) in enumerate(place):
        print(idx, n, f"{s['w']}x{s['h']}", f"{len(s['frames'])}f")
        for fi, fr in enumerate(s['frames']):
            fx = ox + fi * (s['w'] * scale + pad)
            for yy, row in enumerate(fr):
                for xx, chh in enumerate(row):
                    if chh == '.' or chh not in rgb: continue
                    c = bytes(rgb[chh])
                    for dy in range(scale):
                        base = ((oy + yy * scale + dy) * W + fx + xx * scale) * 3
                        px[base:base + 3 * scale] = c * scale
    png(out, W, H, px)
main()

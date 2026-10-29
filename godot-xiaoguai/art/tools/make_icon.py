"""Draws the game icon for "Evolve or Fall" from the game's own sprites: Xiao Guai, small and bright, standing on a
crumbling ledge, with the huge shadow of his final form (the Elder Dragon) rising behind him. One glance says it:
a tiny monster, a giant future, and a drop below. Pixel art at 128 px, scaled up with no smoothing.
Run from the project folder: python art/tools/make_icon.py"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = os.path.dirname(__file__)
EXPORT = os.path.join(HERE, "..", "export")
OUT = os.path.join(HERE, "..", "..")
S = 128


def frame(name, size):
    img = Image.open(os.path.join(EXPORT, name + ".png")).convert("RGBA")
    return img.crop((0, 0, size, size))


def silhouette(img, col):
    a = img.split()[3].point(lambda v: 255 if v > 20 else 0)
    out = Image.new("RGBA", img.size, col + (255,))
    out.putalpha(a)
    return out


def outline(img, col, grow=1):
    a = img.split()[3].point(lambda v: 255 if v > 20 else 0)
    big = a.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    ring = ImageChops.subtract(big, a)
    out = Image.new("RGBA", img.size, col + (255,))
    out.putalpha(ring)
    return out


def main():
    random.seed(4)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    d = ImageDraw.Draw(canvas)
    # night sky: deep blue at the top, violet low down
    for y in range(S):
        t = y / (S - 1)
        d.line([(0, y), (S, y)], fill=(int(14 + 52 * t), int(10 + 14 * t), int(36 + 46 * t), 255))
    # a hot glow behind the little monster
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in [(58, 28), (46, 40), (34, 56), (22, 78)]:
        gd.ellipse([64 - r, 92 - r, 64 + r, 92 + r], fill=(255, 140, 40, a))
    canvas.alpha_composite(glow)
    # stars
    for _ in range(26):
        x, y = random.randint(2, S - 3), random.randint(2, 60)
        d.point((x, y), fill=(255, 255, 255, 255) if random.random() < 0.5 else (170, 190, 255, 255))
    # the dragon of the future: a huge dark silhouette with a violet rim and burning eyes
    dragon = frame("dragon_10_elder_dragon", 48).resize((108, 108), Image.NEAREST)
    shadow = silhouette(dragon, (58, 30, 92))
    rim = outline(dragon, (150, 80, 190), 1)
    canvas.alpha_composite(shadow, (10, 2))
    canvas.alpha_composite(rim, (10, 2))
    # the ledge he stands on, cracked and crumbling, with pebbles falling away
    ledge = [(0, 104), (30, 101), (52, 104), (76, 101), (100, 104), (128, 100), (128, 128), (0, 128)]
    d.polygon(ledge, fill=(34, 24, 44, 255))
    d.line([(0, 104), (30, 101), (52, 104), (76, 101), (100, 104), (128, 100)], fill=(120, 84, 110, 255), width=2)
    d.line([(60, 104), (57, 112), (62, 118), (58, 128)], fill=(10, 6, 16, 255), width=1)
    d.line([(88, 102), (92, 110), (87, 116)], fill=(10, 6, 16, 255), width=1)
    for x, y, r in [(54, 112, 2), (96, 118, 1), (30, 114, 1), (70, 124, 1)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=(90, 66, 90, 255))
    # Xiao Guai: small, bright and outlined, so he reads even at 32 px
    hero = frame("xiaoguai_base", 16).resize((80, 80), Image.NEAREST)
    canvas.alpha_composite(outline(hero, (255, 244, 220), 2), (24, 26))
    canvas.alpha_composite(hero, (24, 26))
    # a golden "level up" chevron and sparks over his head: the evolve part
    for i, (y, w, a) in enumerate([(14, 7, 255), (8, 7, 190), (2, 7, 110)]):
        d.line([(64 - w, y + 7), (64, y), (64 + w, y + 7)], fill=(255, 216, 74, a), width=2)
    for x, y in [(44, 22), (84, 20), (36, 48), (94, 52), (52, 8), (78, 10)]:
        d.line([(x - 2, y), (x + 2, y)], fill=(255, 235, 160, 255))
        d.line([(x, y - 2), (x, y + 2)], fill=(255, 235, 160, 255))
    # a thin golden frame
    d.rectangle([0, 0, S - 1, S - 1], outline=(255, 190, 70, 255))
    d.rectangle([1, 1, S - 2, S - 2], outline=(120, 70, 30, 255))
    rgb = canvas.convert("RGB")
    sizes = {512: "icon.png", 256: "art/icon_256.png", 128: "art/icon_128.png", 64: "art/icon_64.png", 32: "art/icon_32.png"}
    for px, name in sizes.items():
        rgb.resize((px, px), Image.NEAREST if px >= 128 else Image.LANCZOS).save(os.path.join(OUT, name))
    print("icons written")


if __name__ == "__main__":
    main()

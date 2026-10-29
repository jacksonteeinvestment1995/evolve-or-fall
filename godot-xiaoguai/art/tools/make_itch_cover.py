"""The itch.io cover image (630 x 500) for "Evolve or Fall": Xiao Guai on one side, the rival hero on the other, the
title in between. Uses the game's own sprites. Run from the project folder: python art/tools/make_itch_cover.py"""
import os
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

HERE = os.path.dirname(__file__)
EXPORT = os.path.join(HERE, "..", "export")
OUT = os.path.join(HERE, "..", "..", "itch")
W, H = 630, 500


def frame(name, size, idx=0):
    img = Image.open(os.path.join(EXPORT, name + ".png")).convert("RGBA")
    return img.crop((idx * size, 0, idx * size + size, size))


def outline(img, col, grow):
    a = img.split()[3].point(lambda v: 255 if v > 20 else 0)
    big = a.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    ring = ImageChops.subtract(big, a)
    out = Image.new("RGBA", img.size, col + (255,))
    out.putalpha(ring)
    return out


def tint(img, col, amount):
    solid = Image.new("RGBA", img.size, col + (255,))
    solid.putalpha(img.split()[3])
    return Image.blend(img, solid, amount)


def text(d, xy, s, font, fill, stroke, width=4, anchor="mm"):
    d.text(xy, s, font=font, fill=fill, anchor=anchor, stroke_width=width, stroke_fill=stroke)


def main():
    random.seed(11)
    os.makedirs(OUT, exist_ok=True)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=(int(12 + 60 * t), int(8 + 16 * t), int(34 + 50 * t), 255))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, a in [(250, 18), (200, 26), (150, 36), (100, 50)]:
        gd.ellipse([W // 2 - r, 330 - r // 2, W // 2 + r, 330 + r // 2], fill=(255, 120, 40, a))
    img.alpha_composite(glow)
    for _ in range(70):
        x, y = random.randint(4, W - 5), random.randint(4, 230)
        d.rectangle([x, y, x + 1, y + 1], fill=(255, 255, 255, 255) if random.random() < 0.5 else (170, 190, 255, 255))
    # the ground
    d.polygon([(0, 420), (120, 412), (260, 420), (400, 410), (520, 418), (630, 408), (630, 500), (0, 500)], fill=(30, 22, 40, 255))
    d.line([(0, 420), (120, 412), (260, 420), (400, 410), (520, 418), (630, 408)], fill=(120, 84, 110, 255), width=3)
    # Xiao Guai on the left, small and bright
    hero = frame("xiaoguai_base", 16).resize((176, 176), Image.NEAREST)
    img.alpha_composite(outline(hero, (255, 244, 220), 4), (50, 262))
    img.alpha_composite(hero, (50, 262))
    # the rival on the right: a big evolved form in menacing red, with a crown
    rival = frame("demon_10_demon_lord", 48).resize((288, 288), Image.NEAREST)
    rival = tint(rival, (255, 40, 40), 0.18)
    img.alpha_composite(outline(rival, (255, 60, 50), 3), (310, 150))
    img.alpha_composite(rival, (310, 150))
    d.polygon([(444, 160), (444, 130), (460, 146), (476, 120), (492, 146), (508, 130), (508, 160)], fill=(232, 176, 32, 255))
    # a lightning "VS" between them
    vs = ImageFont.truetype("C:/Windows/Fonts/impact.ttf", 70)
    text(d, (292, 330), "VS", vs, (255, 216, 74, 255), (60, 20, 10, 255), 5)
    # the title
    big = ImageFont.truetype("C:/Windows/Fonts/impact.ttf", 78)
    text(d, (W // 2, 70), "EVOLVE OR FALL", big, (255, 226, 120, 255), (70, 20, 10, 255), 6)
    small = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 22)
    text(d, (W // 2, 132), "Grow from a tiny monster. Outlive a rival who grows too.", small, (240, 235, 255, 255), (20, 10, 40, 255), 4)
    tag = ImageFont.truetype("C:/Windows/Fonts/impact.ttf", 30)
    text(d, (W // 2, 462), "20 MINUTES  -  1 RIVAL  -  100 LEVELS", tag, (255, 255, 255, 255), (30, 20, 60, 255), 4)
    d.rectangle([0, 0, W - 1, H - 1], outline=(255, 190, 70, 255), width=3)
    img.convert("RGB").save(os.path.join(OUT, "cover_630x500.png"))
    print("cover written")


if __name__ == "__main__":
    main()

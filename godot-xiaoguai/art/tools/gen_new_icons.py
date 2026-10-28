"""Draws the pixel-art icons of the long-range skills and the perk cards (24 x 24, the same size as the other skill
icons) into art/export. Run from the project folder: python art/tools/gen_new_icons.py, then re-import in Godot.
Each icon is a dark rounded plate with a coloured rim and a hand-built glyph; there is no anti-aliasing, so they stay crisp."""
import math
import os
from PIL import Image, ImageDraw

S = 24
OUT = os.path.join(os.path.dirname(__file__), "..", "export")


def plate(rim):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=4, fill=(22, 26, 40, 255), outline=rim + (255,))
    d.rounded_rectangle([1, 1, S - 2, S - 2], radius=3, outline=(255, 255, 255, 28))
    return img, d


def px(d, pts, col):
    for x, y in pts:
        d.point((x, y), fill=col)


def line(d, a, b, col, w=1):
    d.line([a, b], fill=col, width=w)


def poly(d, pts, col, outline=None):
    d.polygon(pts, fill=col, outline=outline)


# ----------------------------------------------------------------- the five long-range skills
def frost_shards():
    img, d = plate((120, 200, 255))
    ice, ice2, ice3 = (140, 220, 255), (210, 245, 255), (70, 150, 220)
    for ang, ln in [(-32, 9), (0, 11), (32, 9)]:
        a = math.radians(ang - 90)
        tip = (12 + math.cos(a) * ln, 19 + math.sin(a) * ln * 1.25)
        n = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
        base = (12 + math.cos(a) * 3, 19 + math.sin(a) * 3)
        poly(d, [tip, (base[0] + n[0] * 2.2, base[1] + n[1] * 2.2), (12, 19), (base[0] - n[0] * 2.2, base[1] - n[1] * 2.2)], ice, ice3)
        line(d, (12, 19), tip, ice2)
    px(d, [(4, 5), (19, 4), (20, 8)], (255, 255, 255, 255))
    return img


def meteor_call():
    img, d = plate((255, 140, 60))
    for i, (r, col) in enumerate([(6, (230, 80, 30)), (4, (255, 150, 40)), (2, (255, 235, 140))]):
        d.ellipse([14 - r, 10 - r, 14 + r, 10 + r], fill=col)
    for k in range(5):
        x, y = 12 - k * 2.4, 8 - k * 2.4
        r = 3.5 - k * 0.6
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 140 - k * 20, 40, 255 - k * 40))
    px(d, [(20, 18), (6, 18), (18, 20), (4, 14)], (255, 200, 90, 255))
    line(d, (3, 22), (9, 22), (110, 60, 30))
    return img


def chain_zap():
    img, d = plate((255, 230, 90))
    bolt = (255, 240, 120)
    pts = [(14, 2), (7, 12), (12, 12), (8, 21)]
    line(d, pts[0], pts[1], bolt, 3)
    line(d, pts[1], pts[2], bolt, 3)
    line(d, pts[2], pts[3], bolt, 3)
    line(d, (14, 2), (7, 12), (255, 255, 230))
    for c in [(14, 3), (9, 12), (9, 20)]:
        d.ellipse([c[0] - 2, c[1] - 2, c[0] + 2, c[1] + 2], fill=(140, 220, 255), outline=(255, 255, 255))
    px(d, [(18, 8), (19, 14), (4, 6), (18, 18)], (190, 235, 255, 255))
    return img


def thorn_ring():
    img, d = plate((110, 210, 90))
    leaf = (110, 210, 90)
    for i in range(8):
        a = i / 8 * math.tau
        tip = (12 + math.cos(a) * 10, 12 + math.sin(a) * 10)
        n = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
        b = (12 + math.cos(a) * 5, 12 + math.sin(a) * 5)
        poly(d, [tip, (b[0] + n[0] * 1.8, b[1] + n[1] * 1.8), (b[0] - n[0] * 1.8, b[1] - n[1] * 1.8)], leaf, (40, 110, 40))
    d.ellipse([8, 8, 15, 15], fill=(60, 150, 60), outline=(150, 235, 120))
    d.ellipse([10, 10, 13, 13], fill=(220, 255, 180))
    return img


def spirit_lance():
    img, d = plate((255, 215, 90))
    for r, a in [(5, 40), (3, 70)]:
        line(d, (4, 20), (20, 4), (255, 230, 120, a), r)
    line(d, (4, 20), (18, 6), (150, 110, 50), 2)
    poly(d, [(21, 3), (15, 6), (18, 9)], (255, 248, 200), (255, 200, 80))
    poly(d, [(4, 17), (7, 20), (3, 21)], (255, 210, 90))
    px(d, [(8, 4), (20, 16), (5, 8), (19, 20)], (255, 255, 255, 255))
    return img


# ----------------------------------------------------------------- the perk cards
def sharp_fangs():
    img, d = plate((255, 122, 90))
    for cx in (8, 16):
        poly(d, [(cx - 4, 5), (cx + 4, 5), (cx, 19)], (245, 240, 225), (160, 150, 130))
        line(d, (cx - 2, 6), (cx, 14), (255, 255, 255))
    line(d, (3, 4), (21, 4), (180, 40, 40), 2)
    px(d, [(11, 21), (12, 21), (13, 21)], (255, 90, 70, 255))
    return img


def thick_hide():
    img, d = plate((200, 130, 80))
    poly(d, [(12, 2), (21, 5), (20, 14), (12, 22), (4, 14), (3, 5)], (150, 95, 55), (230, 170, 110))
    poly(d, [(12, 5), (18, 7), (17, 13), (12, 18), (7, 13), (6, 7)], (180, 120, 70))
    line(d, (12, 5), (12, 18), (110, 70, 40))
    px(d, [(8, 8), (16, 8), (8, 12), (16, 12)], (235, 190, 130, 255))
    return img


def quick_paws():
    img, d = plate((96, 208, 255))
    paw = (110, 215, 255)
    d.ellipse([8, 12, 17, 20], fill=paw, outline=(40, 120, 190))
    for x, y in [(5, 10), (9, 6), (14, 6), (18, 10)]:
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=paw, outline=(40, 120, 190))
    for y in (8, 13, 18):
        line(d, (1, y), (4, y), (190, 235, 255))
    return img


def vampire_kiss():
    img, d = plate((224, 64, 96))
    poly(d, [(12, 2), (19, 13), (17, 19), (12, 22), (7, 19), (5, 13)], (215, 40, 70), (255, 120, 140))
    d.ellipse([8, 9, 11, 13], fill=(255, 170, 185))
    # two small fangs
    poly(d, [(9, 18), (11, 18), (10, 22)], (250, 245, 235))
    poly(d, [(13, 18), (15, 18), (14, 22)], (250, 245, 235))
    px(d, [(18, 5), (20, 7)], (255, 120, 140, 255))
    return img


def iron_skin():
    img, d = plate((190, 195, 230))
    poly(d, [(4, 4), (20, 4), (20, 15), (12, 22), (4, 15)], (130, 138, 165), (215, 220, 245))
    poly(d, [(7, 7), (17, 7), (17, 14), (12, 18), (7, 14)], (165, 172, 198))
    line(d, (12, 4), (12, 22), (95, 100, 125))
    line(d, (4, 11), (20, 11), (95, 100, 125))
    px(d, [(6, 6), (18, 6), (6, 13), (18, 13)], (240, 240, 250, 255))
    return img


def regrowth():
    img, d = plate((112, 224, 112))
    poly(d, [(5, 19), (6, 8), (14, 3), (20, 4), (19, 13), (11, 20)], (90, 200, 90), (170, 245, 150))
    line(d, (5, 20), (17, 7), (40, 120, 50), 1)
    for a, b in [((9, 15), (9, 10)), ((13, 12), (13, 8))]:
        line(d, a, b, (40, 120, 50))
    line(d, (18, 15), (18, 21), (255, 255, 255), 2)
    line(d, (15, 18), (21, 18), (255, 255, 255), 2)
    return img


def hunters_focus():
    img, d = plate((255, 216, 74))
    d.ellipse([4, 4, 19, 19], outline=(255, 216, 74), width=2)
    d.ellipse([9, 9, 14, 14], outline=(255, 120, 60), width=1)
    for a, b in [((11, 1), (11, 7)), ((11, 16), (11, 22)), ((1, 11), (7, 11)), ((16, 11), (22, 11))]:
        line(d, a, b, (255, 240, 150), 2)
    px(d, [(11, 11), (12, 11), (11, 12), (12, 12)], (255, 70, 50, 255))
    return img


def long_reach():
    img, d = plate((160, 224, 160))
    d.arc([3, 6, 15, 18], 20, 340, fill=(130, 210, 130), width=2)
    line(d, (8, 12), (20, 12), (190, 245, 190), 2)
    poly(d, [(22, 12), (16, 7), (16, 17)], (220, 255, 210), (130, 210, 130))
    px(d, [(5, 4), (19, 20), (3, 19)], (200, 255, 200, 255))
    return img


def night_stalker():
    img, d = plate((138, 156, 255))
    d.ellipse([4, 3, 19, 18], fill=(210, 220, 255))
    d.ellipse([9, 1, 24, 16], fill=(22, 26, 40))
    d.ellipse([8, 14, 19, 21], fill=(40, 50, 100), outline=(138, 156, 255))
    px(d, [(12, 17), (13, 17), (15, 17), (16, 17)], (255, 230, 90, 255))
    px(d, [(4, 3), (21, 6), (20, 21)], (255, 255, 255, 255))
    return img


def glass_cannon():
    img, d = plate((255, 74, 74))
    poly(d, [(12, 2), (21, 12), (12, 22), (3, 12)], (255, 100, 100), (255, 190, 190))
    poly(d, [(12, 5), (18, 12), (12, 19), (6, 12)], (255, 60, 60))
    for a, b in [((12, 2), (10, 10)), ((10, 10), (14, 14)), ((14, 14), (11, 22))]:
        line(d, a, b, (255, 245, 245))
    px(d, [(19, 4), (4, 4), (20, 20)], (255, 220, 120, 255))
    return img


def combo_master():
    img, d = plate((255, 176, 48))
    poly(d, [(12, 2), (19, 11), (17, 19), (12, 22), (7, 19), (5, 11), (9, 8)], (255, 140, 40), (255, 210, 110))
    poly(d, [(12, 9), (16, 15), (14, 20), (10, 20), (8, 15)], (255, 230, 120))
    line(d, (16, 3), (20, 7), (255, 255, 255), 1)
    line(d, (20, 3), (16, 7), (255, 255, 255), 1)
    return img


def counter_strike():
    img, d = plate((159, 232, 255))
    poly(d, [(12, 2), (20, 12), (12, 22), (4, 12)], (60, 130, 190), (159, 232, 255))
    poly(d, [(9, 5), (15, 5), (12, 17)], (240, 250, 255), (159, 232, 255))
    line(d, (12, 17), (12, 21), (255, 220, 90), 2)
    px(d, [(19, 3), (20, 4), (3, 3)], (255, 255, 255, 255))
    return img


ICONS = {
    "icon_frost_shards": frost_shards, "icon_meteor_call": meteor_call, "icon_chain_zap": chain_zap,
    "icon_thorn_ring": thorn_ring, "icon_spirit_lance": spirit_lance,
    "icon_perk_sharp_fangs": sharp_fangs, "icon_perk_thick_hide": thick_hide, "icon_perk_quick_paws": quick_paws,
    "icon_perk_vampire_kiss": vampire_kiss, "icon_perk_iron_skin": iron_skin, "icon_perk_regrowth": regrowth,
    "icon_perk_hunters_focus": hunters_focus, "icon_perk_long_reach": long_reach, "icon_perk_night_stalker": night_stalker,
    "icon_perk_glass_cannon": glass_cannon, "icon_perk_combo_master": combo_master, "icon_perk_counter_strike": counter_strike,
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (S * 6 + 14, S * 3 + 8), (30, 30, 30, 255))
    for i, (name, fn) in enumerate(ICONS.items()):
        img = fn()
        img.save(os.path.join(OUT, name + ".png"))
        sheet.paste(img, (2 + (i % 6) * (S + 2), 2 + (i // 6) * (S + 2)), img)
    sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(os.path.join(os.path.dirname(__file__), "..", "..", "..", "icons_preview.png") if False else os.path.join(OUT, "..", "new_icons_preview.png"))
    print(len(ICONS), "icons written")

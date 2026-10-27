"""Redraw Xiao Guai (xiaoguai_base) as a red imp: big curved tan horns, dark slit eyes, blocky body with
stubby arms, a tail with a flame tip. Left halves are mirrored; the tail is added on one side.
Run from godot-xiaoguai/art: python tools/redesign_hero.py, then build.py + export_png.py."""
import re

LEFT = [
    ".bb.....",
    ".xb.....",
    ".wxb....",
    "..wxreee",
    "...Rrrre",
    "...RrKKr",
    "...RrKKr",
    "...RrKKr",
    "....Rrrr",
    ".....Rrr",
    "...RRrrr",
    "...RRrrr",
    ".....Rrr",
    ".....RR.",
    ".....KK.",
    "........",
]


def frame_a():
    rows = []
    for l in LEFT:
        right = l[::-1]
        # mirror, but keep the shading: the right edge is the darker side
        rows.append(list(l + right))
    g = [r[:] for r in rows]
    # a bright glint in the top-left corner of each eye makes them glossy
    g[5][5] = "W"
    g[5][9] = "W"
    # light from the top left: the right cheek and arm are in shade
    for y in (4, 5, 6, 7, 8):
        g[y][11] = "R"
    g[10][12] = "R"
    g[11][12] = "R"
    # tail with a flame tip, down on the left
    g[12][4] = "R"
    g[13][3] = "R"
    g[13][2] = "R"
    g[14][1] = "R"
    g[14][0] = "o"
    g[15][0] = "y"
    g[15][1] = "Y"
    return g


def frame_b(a):
    g = [r[:] for r in a]
    # breathe: head and body drop one pixel, legs stay; flame flickers the other way
    out = [["."] * 16 for _ in range(16)]
    for y in range(0, 13):
        out[y + 1] = a[y][:]
    for y in (13, 14):
        out[y] = a[y][:]
    # restore the legs over the body's last row
    out[13] = a[13][:]
    # tail follows the body
    for x in range(0, 5):
        out[13][x] = "."
        out[14][x] = "."
        out[15][x] = "."
    out[13][4] = "R"
    out[14][3] = "R"
    out[14][2] = "R"
    out[15][1] = "R"
    out[15][0] = "o"
    out[14][0] = "y"
    return out


a = frame_a()
b = frame_b(a)
block = ["sprite xiaoguai_base 16 16 hero \"Xiao Guai\""]
for g in (a, b):
    block.append("frame")
    block.extend("".join(r) for r in g)
new = "\n".join(block) + "\n"

p = "src/hero_undead.spr"
s = open(p, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in s else "\n"
s = s.replace("\r\n", "\n")
i = s.index('sprite xiaoguai_base 16 16 hero "Xiao Guai"')
j = s.index("\nsprite ", i + 10) + 1
s = s[:i] + new + s[j:]
open(p, "w", encoding="utf-8", newline="").write(s.replace("\n", nl))
print("redrew xiaoguai_base")

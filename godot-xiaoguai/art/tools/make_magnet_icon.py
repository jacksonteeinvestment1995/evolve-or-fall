"""Draw icon_magnet (24x24 on the same dark rounded badge as the other skill icons) into art/src/icon_magnet.spr.
A red horseshoe magnet with silver tips, and little stars being pulled toward it."""
W = H = 24
g = [["." for _ in range(W)] for _ in range(H)]

# badge: rounded square, light top-left edge, dark bottom-right edge, like icon_tough_hide
for y in range(H):
    for x in range(W):
        corner = (x in (0, W - 1) and y in (0, H - 1)) or (x in (0, W - 1) and y in (1, H - 2) and False)
        if corner:
            continue
        if x == 0 or y == 0:
            g[y][x] = "J"
        elif x == W - 1 or y == H - 1:
            g[y][x] = "K"
        elif x == 1 or y == 1:
            g[y][x] = "s"
        elif x == W - 2 or y == H - 2:
            g[y][x] = "J"
        else:
            g[y][x] = "S"
g[1][1] = "t"

# horseshoe: an arch of thickness 4 opening downward, centred at (12, 12)
import math
cx, cy = 11.5, 12.5
for y in range(3, 21):
    for x in range(3, 21):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy)
        in_ring = 4.2 <= r <= 8.6
        arm = (abs(abs(dx) - 6.4) <= 2.2) and dy >= 0 and y <= 18
        if (in_ring and dy <= 0.8) or arm:
            shade = "e" if (dx + dy) < 0 else "r"
            if r > 7.8 or abs(abs(dx) - 6.4) > 1.6 and arm:
                shade = "R"
            g[y][x] = shade
# silver tips at the two open ends
for x in range(3, 21):
    for y in range(16, 20):
        dx = x - cx
        if abs(abs(dx) - 6.4) <= 2.2:
            g[y][x] = "T" if y < 19 else "t"
# stars being pulled in
for (x, y) in [(5, 4), (17, 3), (20, 8), (3, 9)]:
    g[y][x] = "Y"
    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + d[0], y + d[1]
        if g[yy][xx] == "S":
            g[yy][xx] = "y"

rows = ["".join(r) for r in g]
open("src/icon_magnet.spr", "w", encoding="utf-8").write('# EXP Magnet icon (24x24 badge)\nsprite icon_magnet 24 24 icon "EXP Magnet"\nframe\n' + "\n".join(rows) + "\n")
print("wrote src/icon_magnet.spr")

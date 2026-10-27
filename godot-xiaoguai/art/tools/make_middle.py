"""Fill forms 02 to 09 of the six partly drawn lines from form 01 and form 10, with no new drawing.
Forms 2 to 5 are form 01 scaled up; forms 6 to 9 are form 10 scaled down. Frame sizes follow the
Undead lines (16, 16, 24, 24, 24, 32, 32, 32, 40, 48), and every pixel keeps its palette colour
because scaling is nearest-neighbour.
Run from godot-xiaoguai/: python art/tools/make_middle.py, then godot --headless --import."""
import glob
from PIL import Image

D = "art/export/"
LINES = ["slime", "dragon", "beast", "nature", "material", "demon"]
SIZE = {2: 16, 3: 24, 4: 24, 5: 24, 6: 32, 7: 32, 8: 32, 9: 40}


def find(prefix):
    for f in sorted(glob.glob(D + prefix + "*.png")):
        if not f.endswith(("_attack.png", "_walk.png", "_night.png")):
            return f


def frames(im):
    h = im.height
    return [im.crop((i * h, 0, (i + 1) * h, h)) for i in range(im.width // h)]


for line in LINES:
    a, b = frames(Image.open(find(line + "_01_")).convert("RGBA")), frames(Image.open(find(line + "_10_")).convert("RGBA")[:0] if False else Image.open(find(line + "_10_")).convert("RGBA"))
    for f, s in SIZE.items():
        src = a if f <= 5 else b
        if f == 2:
            out = [fr.copy() for fr in src]
        else:
            out = [fr.resize((s, s), Image.NEAREST) for fr in src]
        sheet = Image.new("RGBA", (s * len(out), s))
        for i, fr in enumerate(out):
            sheet.paste(fr, (i * s, 0))
        sheet.save(D + "%s_%02d_morph.png" % (line, f))

"""Special-encounter map mockup: concept emblems composited into a real revision-4 section map capture.

python3 mock_special_map.py <emblem dir> <out dir>
The base is the ux-01 Hollow Gale capture (section I, 1920x1080). Three standard-combat nodes become a Warband, an
Umbral Snare and an Ember Hoarder; the legend is rebuilt to list only this section's room types.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

EMB, OUT = sys.argv[1], sys.argv[2]
ROOT = "/Users/borgerding/workspace/Labyrinth/"
BASE = ROOT + "output/peer-benchmark-2026-10-12/proof/ux-01/02_auto_map.png"
FONT = "/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/fonts/LabyrinthCrumble-Text.ttf"
TYPES = ["warband", "umbral_snare", "ember_hoarder", "last_light"]
NAMES = {"warband": "Warband", "umbral_snare": "Umbral Snare", "ember_hoarder": "Ember Hoarder", "last_light": "Last Light"}
# Hollow Gale nodes: step 6 lane 1, step 3 lane 2, step 7 lane 3 (none beside a Guardian; the Snare has 2+ exits).
NODES = {"warband": (1115, 437), "umbral_snare": (621, 651), "ember_hoarder": (1266, 852)}

emblem = {t: Image.open(f"{EMB}/{t}_emblem.png").convert("RGB") for t in TYPES}


def interior(im, x, y, win, dark=26):
    """Centre and radius of the dark disc inside a medallion near (x, y); win stays inside the brass rim."""
    px = im.load()
    pts = [(i, j) for j in range(max(0, y - win), min(im.height, y + win)) for i in range(max(0, x - win), min(im.width, x + win))
           if (i - x) ** 2 + (j - y) ** 2 < win * win and sum(px[i, j]) / 3 < dark]
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    r = max(((p[0] - cx) ** 2 + (p[1] - cy) ** 2) ** 0.5 for p in pts)
    return cx, cy, r


def disc(src, r, gain):
    """The emblem scaled to fill a disc of radius r, antialiased, with the room's opacity gain."""
    s = 4
    d = int(round(r * 2))
    art = src.resize((d, d), Image.LANCZOS).point(lambda v: int(v * gain))
    mask = Image.new("L", (d * s, d * s), 0)
    ImageDraw.Draw(mask).ellipse((s, s, d * s - s, d * s - s), fill=255)
    return art, mask.resize((d, d), Image.LANCZOS)


def place(im, t, x, y, gain, win, zoom=1.24):
    cx, cy, r = interior(im, x, y, win)
    r = r - 1.0
    src = emblem[t]
    w = src.width
    pad = int(w * (zoom - 1) / 2)
    src = src.crop((pad, pad, w - pad, w - pad))  # the emblems have a wider margin than the room art
    art, mask = disc(src, r, gain)
    im.paste(art, (int(round(cx - r)), int(round(cy - r))), mask)


def build_map():
    im = Image.open(BASE).convert("RGB")
    for t, (x, y) in NODES.items():
        place(im, t, x, y, 0.85, 31)
    # Legend: only the types this section contains, specials after Standard combat.
    entries = [("crop", 71, 247), ("new", "warband"), ("new", "umbral_snare"), ("new", "ember_hoarder"),
               ("crop", 261, 437), ("crop", 564, 694), ("crop", 865, 958), ("crop", 972, 1127),
               ("crop", 1141, 1231), ("crop", 1249, 1410)]
    top, bot = 976, 1030
    strip = im.crop((1420, top, 1610, bot))
    sprites = []
    std_icon = im.crop((70, top, 122, bot))
    font = ImageFont.truetype(FONT, 15)
    label = (224, 213, 189)
    for e in entries:
        if e[0] == "crop":
            sp = im.crop((e[1], top, e[2], bot))
            lum = sp.convert("L").load()
            cols = [i for i in range(sp.width) if max(lum[i, j] for j in range(sp.height)) > 70]
            sprites.append(sp.crop((cols[0], 0, cols[-1] + 2, sp.height)))
        else:
            t = e[1]
            tw = int(font.getlength(NAMES[t]))
            sp = Image.new("RGB", (52 + 8 + tw + 4, bot - top))
            for ox in range(0, sp.width, strip.width):
                sp.paste(strip, (ox, 0))
            icon = std_icon.copy()
            place(icon, t, 26, 27, 1.0, 19)
            sp.paste(icon, (0, 0))
            ImageDraw.Draw(sp).text((58, 18), NAMES[t], font=font, fill=label)
            sprites.append(sp)
    gap = 12
    total = sum(s.width for s in sprites) + gap * (len(sprites) - 1)
    assert 70 + total < 1615, total
    for ox in range(64, 1612, strip.width):
        im.paste(strip.crop((0, 0, min(strip.width, 1612 - ox), strip.height)), (ox, top))
    x = 70
    for s in sprites:
        im.paste(s, (x, top))
        x += s.width + gap
    # Hover tooltip on the Warband node, in the shared tooltip vocabulary (dark plate, brass rule).
    d = ImageDraw.Draw(im, "RGBA")
    bx, by, bw, bh = 1160, 470, 330, 92
    d.rounded_rectangle((bx, by, bx + bw, by + bh), 6, fill=(16, 13, 11, 240), outline=(176, 138, 74, 255), width=2)
    title = ImageFont.truetype(FONT, 20)
    d.text((bx + 16, by + 12), "Warband · The Stormcaller", font=title, fill=(244, 214, 138))
    d.text((bx + 16, by + 42), "Kill the captain and the rest flee.", font=font, fill=(224, 213, 189))
    d.text((bx + 16, by + 63), "Not yet visited", font=font, fill=(168, 152, 128))
    im.save(f"{OUT}/mock_special_map.png")
    im.save(f"{OUT}/mock_special_map.jpg", quality=90)


def build_strip():
    """Each emblem in an available-size, future-size and legend-size medallion, from real node crops."""
    base = Image.open(BASE).convert("RGB")
    avail = base.crop((290 - 62, 250 - 62, 290 + 62, 250 + 62))
    future = base.crop((1115 - 40, 437 - 40, 1115 + 40, 437 + 40))
    legend = base.crop((70, 976, 122, 1030))
    font = ImageFont.truetype(FONT, 20)
    W, H = 4 * 300, 250
    out = Image.new("RGB", (W, H), (20, 17, 14))
    d = ImageDraw.Draw(out)
    for i, t in enumerate(TYPES):
        a = avail.copy(); place(a, t, 62, 62, 1.0, 42)
        f = future.copy(); place(f, t, 40, 40, 0.85, 31)
        g = legend.copy(); place(g, t, 26, 27, 1.0, 19)
        x0 = i * 300 + 14
        out.paste(a, (x0, 20)); out.paste(f, (x0 + 136, 42)); out.paste(g, (x0 + 226, 56))
        d.text((x0 + 4, 170), NAMES[t], font=font, fill=(244, 214, 138))
        d.text((x0 + 4, 200), "available · future · legend", font=ImageFont.truetype(FONT, 15), fill=(168, 152, 128))
    out.save(f"{OUT}/mock_special_emblems.png")
    out.save(f"{OUT}/mock_special_emblems.jpg", quality=92)


build_map()
build_strip()

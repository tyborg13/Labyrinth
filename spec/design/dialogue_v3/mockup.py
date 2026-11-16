"""Dialogue box v3 director mockup: ink-wash band, unframed bust portrait, brush nameplate kept.

Owner (2026-11-16, dlg-redesign NEEDS CHANGES): "I like the brush stroke for the name, I don't like the medallion for
the portrait. Also, the box itself could look a bit better."
Usage: python3 mockup.py <base_capture.png> <portrait_rest.png> <out.png> [line|choice]
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

R = "/Users/borgerding/workspace/Labyrinth.worktrees/release/"
INK_DIR = R + "assets/art/ui/turn_order_ink/"
UI = R + "fonts/LabyrinthCrumble-UI.ttf"
TX = R + "fonts/LabyrinthCrumble-Text.ttf"


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK0, INK_BAND, INK_WARM = hexc("0b0908"), hexc("1e1611"), hexc("6a4428")
GOLD_B, EMBER, TEXT, TEXT2 = hexc("f0cf8a"), hexc("e8893a"), hexc("efe3c8"), hexc("b5a58a")
NAME_INK = hexc("6b5232")


def mask(name, size, alpha=1.0):
    m = Image.open(INK_DIR + name).convert("RGBA").resize(size, Image.LANCZOS).split()[3]
    return m.point(lambda v: int(v * alpha))


def tinted(m, colour):
    layer = Image.new("RGBA", m.size, colour[:3] + (255,))
    layer.putalpha(m)
    return layer


base, portrait_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
variant = sys.argv[4] if len(sys.argv) > 4 else "line"
bg = Image.open(base).convert("RGBA")
W, H = bg.size
# Hide the old box in the base capture.
bg.paste(bg.crop((425, 840, 1495, 905)).resize((1070, 230)), (425, 845))

# 1. Seat scrim (kept from v2): the bottom darkens so the band sits in shadow.
scr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(scr)
for y in range(600, H):
    t = (y - 600) / (H - 600)
    d.line([(0, y), (W, y)], fill=INK0[:3] + (int(255 * 0.62 * (t ** 1.6)),))
img = Image.alpha_composite(bg, scr)

# Band geometry
BX, BW = 250, 1440
BH = 196 if variant == "line" else 262
BY = H - 26 - BH

# 3. Bust portrait, unframed: the speaker stands at the left and the band crosses his chest.
art = Image.open(portrait_path).convert("RGBA")
bb = art.split()[3].getbbox()
# head-and-shoulders column: 1.6 head widths either side of the face, from the hood top down 75% of the figure
head_cx = (bb[0] + bb[2]) // 2 - 6
crop = art.crop((head_cx - 52, bb[1] - 4, head_cx + 52, bb[1] + int((bb[3] - bb[1]) * 0.75)))
SC = 3
bust = crop.resize((crop.width * SC, crop.height * SC), Image.NEAREST)
PXp = BX + 70
PYp = BY + 141 - bust.height  # the band top crosses the bust at chest height for every band height
# soft dark halo behind the bust so it separates from the room
halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(halo).ellipse([PXp - 30, PYp + 10, PXp + bust.width + 30, PYp + bust.height + 60], fill=(0, 0, 0, 150))
img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(28)))
# the bust's lower edge fades into the band over 40 px
fade = Image.new("L", bust.size, 255)
fd = ImageDraw.Draw(fade)
for i in range(40):
    y = bust.height - 40 + i
    fd.line([(0, y), (bust.width, y)], fill=int(255 * (1 - i / 40)))
bust.putalpha(ImageChops.multiply(bust.split()[3], fade))
img.alpha_composite(bust, (PXp, PYp))
# 2. The band: one wide dry-brush ink stroke instead of a gilded rectangle.
# 2a. warm under-stroke, offset down-right, so the ragged edges catch a little ember light
under = mask("brush_b.png", (BW + 40, BH + 26), 0.70)
img.alpha_composite(tinted(under, INK_WARM), (BX - 4, BY + 4))
# 2b. main stroke
main = mask("brush_c.png", (BW, BH), 0.97)
# 2c. solid core so dry-brush gaps never sit under text; the ragged silhouette stays at the ends and edges
core = Image.new("L", (BW, BH), 0)
ImageDraw.Draw(core).rounded_rectangle([int(BW * 0.07), int(BH * 0.16), int(BW * 0.93), int(BH * 0.84)], 40, fill=242)
core = core.filter(ImageFilter.GaussianBlur(18))
band = ImageChops.lighter(main, core)
img.alpha_composite(tinted(band, INK_BAND), (BX, BY))
# 2d. faint warm light across the band's upper third, as if from the scene above
glow = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([int(BW * 0.22), -int(BH * 0.9), int(BW * 0.86), int(BH * 0.5)], fill=EMBER[:3] + (22,))
glow = glow.filter(ImageFilter.GaussianBlur(46))
glow.putalpha(ImageChops.multiply(glow.split()[3], band))
img.alpha_composite(glow, (BX, BY))

# 4. Nameplate (kept from v2: the owner liked it): bronze dry-brush stroke above the text column.
TXX = PXp + bust.width + 36
d = ImageDraw.Draw(img)
br = mask("brush_a.png", (300, 58), 0.91)
img.alpha_composite(tinted(br, NAME_INK), (TXX - 24, BY + 12))
d = ImageDraw.Draw(img)
fname = ImageFont.truetype(UI, 20)
x = TXX
for ch in "EMACIATED MAN":
    d.text((x, BY + 49), ch, font=fname, fill=GOLD_B, stroke_width=3, stroke_fill=hexc("0a0706"), anchor="ls")
    x += fname.getlength(ch) + 3.5

# 5. Text and continue cue.
fb = ImageFont.truetype(TX, 25)
lines = (["A dragon has fallen. I felt it... and so did the Moltshard you carried away."] if variant == "line"
         else ["The Moltshard hums with what it took. Give it to me, and I can wake", "what sleeps in you."])
y = BY + 74
for ln in lines:
    d.text((TXX, y), ln, font=fb, fill=TEXT, anchor="la")
    y += 35
fc = ImageFont.truetype(UI, 14)
if variant == "line":
    hx, hy = BX + BW - 120, BY + BH - 52
    h2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(h2).ellipse([hx - 14, hy - 14, hx + 14, hy + 14], fill=EMBER[:3] + (90,))
    img = Image.alpha_composite(img, h2.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(img)
    d.polygon([(hx, hy - 7), (hx + 7, hy), (hx, hy + 7), (hx - 7, hy)], fill=EMBER)
    hint = "CLICK TO CONTINUE"
    w = sum(fc.getlength(c) + 3 for c in hint) - 3
    x = hx - 20 - w
    for ch in hint:
        d.text((x, hy), ch, font=fc, fill=TEXT2, anchor="lm")
        x += fc.getlength(ch) + 3
else:
    # choices as two smaller brush strokes: quiet ink and the primary ember-lit stroke
    def choice(x0, y0, w, h, label, primary):
        global img
        m = mask("brush_b.png" if primary else "brush_d.png", (w, h), 0.95)
        img.alpha_composite(tinted(m, hexc("7a3d16") if primary else hexc("3a2a1e")), (x0, y0))
        dd = ImageDraw.Draw(img)
        f = ImageFont.truetype(UI, 18)
        lw = sum(f.getlength(c) + 2 for c in label) - 2
        xx = x0 + (w - lw) / 2
        for ch in label:
            dd.text((xx, y0 + h / 2), ch, font=f, fill=GOLD_B if primary else TEXT, anchor="lm", stroke_width=2,
                    stroke_fill=hexc("0a0706"))
            xx += f.getlength(ch) + 2
    choice(BX + BW - 120 - 300, BY + BH - 92, 300, 62, "Awaken · 1 Moltshard", True)
    choice(BX + BW - 120 - 300 - 24 - 210, BY + BH - 92, 210, 62, "Not yet", False)
img.convert("RGB").save(out)
print("ok", BX, BY, BW, BH, "bust", PXp, PYp, bust.size)

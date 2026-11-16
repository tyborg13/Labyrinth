"""Dialogue box v4 director mockup: the portrait has its own frame, rising above the ink band; the bust breaks out of
the frame's top edge. Ink band, brush nameplate and brush choices kept from v3.

Owner (2026-11-16, dlg-redesign-2 NEEDS CHANGES): "His portrait doesn't quite work, it's slightly overhanging on the
left. It's hard cropped on the right... I really like the portrait popping out of its own frame which is also not
strictly bounded by the dialogue box itself kind of look."
Usage: python3 mock4.py <base_capture.png> <portrait_rest.png> <out.png> [line|choice] [frame_style]
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
FRAME_FILL, FRAME_GLOW, FRAME_RIM = hexc("16100c"), hexc("5a3a22"), hexc("9a7444")


def mask(name, size, alpha=1.0, rotate=0):
    m = Image.open(INK_DIR + name).convert("RGBA")
    if rotate: m = m.rotate(rotate, expand=True)
    m = m.resize(size, Image.LANCZOS).split()[3]
    return m.point(lambda v: int(v * alpha))


def tinted(m, colour):
    layer = Image.new("RGBA", m.size, colour[:3] + (255,))
    layer.putalpha(m)
    return layer


base, portrait_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
variant = sys.argv[4] if len(sys.argv) > 4 else "line"
style = sys.argv[5] if len(sys.argv) > 5 else "rim"
bg = Image.open(base).convert("RGBA")
W, H = bg.size
bg.paste(bg.crop((425, 840, 1495, 905)).resize((1070, 230)), (425, 845))

# Seat scrim (kept).
scr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(scr)
for y in range(560, H):
    t = (y - 560) / (H - 560)
    d.line([(0, y), (W, y)], fill=INK0[:3] + (int(255 * 0.66 * (t ** 1.5)),))
img = Image.alpha_composite(bg, scr)

# Band geometry (v3 heights). The band now starts behind the portrait frame.
BX, BW = 190, 1500
BH = (int(sys.argv[15]) if len(sys.argv) > 15 else 196) if variant == "line" else 262
BY = H - 26 - BH

SC = int(sys.argv[6]) if len(sys.argv) > 6 else 4
CUT = int(sys.argv[7]) if len(sys.argv) > 7 else 152     # sprite row where the bust ends
POP = int(sys.argv[8]) if len(sys.argv) > 8 else 78      # hood top above the frame top
HOOD_TOP, LEFT, RIGHT = int(sys.argv[9]), int(sys.argv[10]), int(sys.argv[11])                      # sprite rows/cols of the bust (rows 60..155)

# Band first: the portrait frame stands in front of its left end.
under = mask("brush_b.png", (BW + 40, BH + 26), 0.70)
img.alpha_composite(tinted(under, INK_WARM), (BX - 4, BY + 4))
main = mask("brush_c.png", (BW, BH), 0.97)
core = Image.new("L", (BW, BH), 0)
ImageDraw.Draw(core).rounded_rectangle([int(BW * 0.07), int(BH * 0.16), int(BW * 0.93), int(BH * 0.84)], 40, fill=242)
core = core.filter(ImageFilter.GaussianBlur(18))
band = ImageChops.lighter(main, core)
img.alpha_composite(tinted(band, INK_BAND), (BX, BY))
glow = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([int(BW * 0.22), -int(BH * 0.9), int(BW * 0.86), int(BH * 0.5)], fill=EMBER[:3] + (22,))
glow = glow.filter(ImageFilter.GaussianBlur(46))
glow.putalpha(ImageChops.multiply(glow.split()[3], band))
img.alpha_composite(glow, (BX, BY))

bust_w, bust_h = (RIGHT - LEFT) * SC, (CUT - HOOD_TOP) * SC
FW, FH = int(sys.argv[13]), int(sys.argv[14])
POP = bust_h - FH
FX = 250
FB = BY + BH - 24
FY = FB - FH
win = Image.new("L", (W, H), 0)
ImageDraw.Draw(win).rectangle([FX, FY, FX + FW, FB], fill=255)
sh = Image.new("L", (W, H), 0)
ImageDraw.Draw(sh).rectangle([FX + 8, FY + 12, FX + FW + 8, FB + 10], fill=190)
img.alpha_composite(tinted(sh.filter(ImageFilter.GaussianBlur(16)), INK0))
img.alpha_composite(tinted(win, FRAME_FILL))
wash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(wash).ellipse([FX + 20, FY - 80, FX + FW - 20, FY + int(FH * 0.75)], fill=FRAME_GLOW[:3] + (180,))
wash = wash.filter(ImageFilter.GaussianBlur(50))
wash.putalpha(ImageChops.multiply(wash.split()[3], win))
img.alpha_composite(wash)
tex = mask("brush_c.png", (FH + 40, FW + 20), 0.30).rotate(90, expand=True).resize((FW, FH))
texl = Image.new("L", (W, H), 0)
texl.paste(tex, (FX, FY))
img.alpha_composite(tinted(ImageChops.multiply(texl, win), hexc("2c2016")))

art = Image.open(portrait_path).convert("RGBA")
HEAD_CX = int(sys.argv[16])
# full sprite width: no source-side crop; the frame window clips the sides below its top edge
bust = art.crop((0, HOOD_TOP, art.width, CUT)).resize((art.width * SC, (CUT - HOOD_TOP) * SC), Image.NEAREST)
bust_h = bust.height
PX = FX + FW // 2 - HEAD_CX * SC
PY = FB - bust_h
POP = FY - PY
fade = Image.new("L", bust.size, 255)
fd = ImageDraw.Draw(fade)
for i in range(40):
    fd.line([(0, bust_h - 40 + i), (bust.width, bust_h - 40 + i)], fill=int(255 * (1 - i / 40) ** 1.3))
bust.putalpha(ImageChops.multiply(bust.split()[3], fade))
layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
layer.alpha_composite(bust, (PX, PY))
clip = Image.new("L", (W, H), 0)
cd = ImageDraw.Draw(clip)
cd.rectangle([FX + 3, FY, FX + FW - 3, FB], fill=255)       # inside the rim
cd.rectangle([0, 0, W, FY + 1], fill=255)                     # above the frame top: unclipped
layer.putalpha(ImageChops.multiply(layer.split()[3], clip))
halo = layer.split()[3].filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * 0.6))
top_only = Image.new("L", (W, H), 0)
ImageDraw.Draw(top_only).rectangle([0, 0, W, FY + 20], fill=255)
img.alpha_composite(tinted(ImageChops.multiply(halo, top_only), INK0))
rim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(rim)
if style == "rim":
    rd.rectangle([FX, FY, FX + FW, FB], outline=FRAME_RIM[:3] + (220,), width=3)
    rd.rectangle([FX + 9, FY + 9, FX + FW - 9, FB - 9], outline=FRAME_RIM[:3] + (60,), width=1)
elif style == "brush":
    top = mask("brush_a.png", (FW + 70, 30), 0.95)
    rim.alpha_composite(tinted(top, NAME_INK), (FX - 35, FY - 15))
    side = mask("brush_d.png", (FH, 20), 0.80).rotate(90, expand=True)
    rim.alpha_composite(tinted(side, NAME_INK), (FX - 10, FY))
    rim.alpha_composite(tinted(side, NAME_INK), (FX + FW - 10, FY))
    bot = mask("brush_d.png", (FW + 40, 22), 0.80)
    rim.alpha_composite(tinted(bot, NAME_INK), (FX - 20, FB - 11))
img.alpha_composite(rim)
img.alpha_composite(layer)
FW_TEXT = FX + FW + 56

# Nameplate and text column right of the frame.
TXX = FW_TEXT
d = ImageDraw.Draw(img)
br = mask("brush_a.png", (300, 58), 0.91)
img.alpha_composite(tinted(br, NAME_INK), (TXX - 24, BY + 12))
d = ImageDraw.Draw(img)
fname = ImageFont.truetype(UI, 20)
x = TXX
for ch in sys.argv[12]:
    d.text((x, BY + 49), ch, font=fname, fill=GOLD_B, stroke_width=3, stroke_fill=hexc("0a0706"), anchor="ls")
    x += fname.getlength(ch) + 3.5
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
print("ok band", BX, BY, BW, BH, "frame", FX, FY, FW, FH, "pop", POP)

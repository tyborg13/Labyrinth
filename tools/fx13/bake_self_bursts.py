"""Bakes the one-shot effects that play on a unit: Block, Stoneskin, heal, buff, Mantle, Illusion, summon, Expose
(director-owned art; numpy + PIL only). Same raster, sheet and player format as tools/fx12/bake_tile_bursts.py: one byte
per cell (palette index, 0 empty), a rear and a front row per effect so the unit stands inside it, every tile width in
SIZES rasterised from authored units (85 = one tile width), so a cell is never scaled.
Usage: python3 tools/fx13/bake_self_bursts.py [out_dir]
"""
import hashlib, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fx12"))
import bake_tile_bursts as B

N, FPS = 16, 30
GUARD = [(0x10, 0x18, 0x26), (0x26, 0x3c, 0x54), (0x46, 0x6c, 0x8e), (0x84, 0xba, 0xde), (0xee, 0xfa, 0xff)]
STONE = [(0x1e, 0x1a, 0x16), (0x3c, 0x36, 0x2c), (0x62, 0x5a, 0x48), (0x8e, 0x86, 0x68), (0xbe, 0xb8, 0x92)]
MOSS = (0x89, 0xa1, 0x5b)
VERDE = [(0x10, 0x2a, 0x1a), (0x24, 0x5c, 0x34), (0x4c, 0x9c, 0x50), (0x9e, 0xe2, 0x7e), (0xf0, 0xff, 0xd8)]
AMBER = [(0x4a, 0x1e, 0x08), (0x94, 0x44, 0x10), (0xe0, 0x8a, 0x2a), (0xff, 0xcc, 0x6a), (0xff, 0xf6, 0xd8)]
GEM = [(0x1c, 0x24, 0x56), (0x38, 0x50, 0x9a), (0x6c, 0x98, 0xde), (0xb0, 0xdc, 0xff), (0xfa, 0xfe, 0xff)]
GLASS = [(0x12, 0x34, 0x38), (0x24, 0x64, 0x66), (0x52, 0xa4, 0x9e), (0xa2, 0xe6, 0xd8), (0xf4, 0xff, 0xfc)]
SHADE = [(0x0c, 0x08, 0x14), (0x1a, 0x11, 0x28), (0x2e, 0x1e, 0x46), (0x58, 0x3c, 0x7e), (0xb0, 0x8a, 0xdc)]
LIGHT = B.LIGHT
put, dith, ease, blank, poly, glint = B.put, B.dith, B.ease, B.blank, B.poly, B.glint


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def edge(mask):
    """Cells of a mask that touch its outside."""
    m = np.pad(mask, 1)
    inner = m[1:-1, :-2] & m[1:-1, 2:] & m[:-2, 1:-1] & m[2:, 1:-1]
    return mask & ~inner


def lit_edge(mask):
    """The upper-left edge cells of a mask."""
    m = np.pad(mask, 1)
    return mask & ~(m[1:-1, :-2] & m[:-2, 1:-1])


def out(img, mask, colour):
    """A one-cell dark line round a mask, only over empty cells."""
    m = np.pad(mask, 1)
    ring = (m[1:-1, :-2] | m[1:-1, 2:] | m[:-2, 1:-1] | m[2:, 1:-1]) & ~mask & (img[..., 3] == 0)
    put(img, ring, colour)


# ---- Block: plates slam together into a shield in front of the body, flash, and clear to a bright rim ------------------
def block():
    rng = np.random.default_rng(700)
    cx, cy = 0, -27
    shield = [(-23, -27), (0, -33), (23, -27), (22, -2), (14, 16), (0, 28), (-14, 16), (-22, -2)]
    plates = [([(-23, -27), (0, -33), (0, 28), (-14, 16), (-22, -2)], (-20, -5)),
              ([(0, -33), (23, -27), (22, -2), (14, 16), (0, 28)], (20, -5))]
    boss = [(0, -20), (9, -8), (0, 14), (-9, -8)]
    sparks = [B.Chip(rng.uniform(-3, 3), cy + rng.uniform(-30, 26), rng.choice([-1, 1]) * rng.uniform(1.6, 4.8), rng.uniform(-2.8, .6), 3, rng.integers(4, 8), [GUARD[2], GUARD[3], GUARD[4]], 1, .25) for _ in range(16)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        slide = 1 - ease(clamp(k / 3.0)) if k < 3 else 0.0
        fade = clamp((k - 4) / 6.0)
        rim_fade = clamp((k - 10) / 5.0)
        whole = np.zeros((B.FH, B.FW), bool)
        for i, (pts, (ox, oy)) in enumerate(plates):
            m = poly([(x + cx + ox * slide, y + cy + oy * slide) for x, y in pts])
            whole |= m
            body = m & dith(np.full_like(B.X, 1.0 if k < 5 else (1 - fade) * .92))
            dent = B.BAYER[((np.arange(B.FH) + 1) // 1)[:, None] % 4, np.arange(B.FW)[None, :] % 4]
            lobe = np.sin((B.X - ox * slide) * .33 + (B.Y - oy * slide) * .21) * np.sin((B.Y - oy * slide) * .27 - (B.X - ox * slide) * .11)
            shade = (.64 if i == 0 else .40) - (B.X - cx) * (.012 if i == 0 else -.004) - (B.Y - cy) * .010 + lobe * .10
            idx = np.clip((shade * 4 + (dent - .5) * .55).astype(int), 0, 3)
            for c in range(4):
                put(f, body & (idx == c), GUARD[c])
            # Hammered lines, one per plate.
            for off in (6, 13):
                line = poly([(cx + ox * slide + (-1 if i == 0 else 1) * (off - .9), cy - 34), (cx + ox * slide + (-1 if i == 0 else 1) * (off + .9), cy - 34),
                             (cx + ox * slide + (-1 if i == 0 else 1) * (off + .9), cy + 30), (cx + ox * slide + (-1 if i == 0 else 1) * (off - .9), cy + 30)])
                put(f, body & line & (B.Y > cy - 24 + off) & (B.Y < cy + 14 - off), GUARD[max(0, 1 - i)])
        b = poly([(x * (1.0 if k >= 3 else .4) + cx, y * (1.0 if k >= 3 else .4) + cy) for x, y in boss]) if k >= 2 else np.zeros_like(whole)
        bb = b & dith(np.full_like(B.X, 1.0 if k < 6 else 1 - clamp((k - 6) / 5)))
        put(f, bb, GUARD[2])
        put(f, bb & (B.X < cx), GUARD[3])
        put(f, edge(b) & bb, GUARD[4])
        keep = dith(np.full_like(B.X, 1 - rim_fade))
        rim = edge(whole)
        rim2 = whole & ~poly([(x * .9 + cx, y * .9 + cy) for x, y in shield]) if k >= 3 else rim
        put(f, rim2 & keep, GUARD[2])
        put(f, rim & keep, GUARD[3 if 3 <= k <= 9 else 2])
        if 3 <= k <= 5:
            hot = np.abs((B.X - cx) * .5 + (B.Y - cy) + 24 - (k - 3) * 26) < 5.5
            put(f, whole & hot, GUARD[4])
        if k == 3:
            put(f, rim2, GUARD[4])
            put(f, np.abs(B.X - cx) < max(.9, B.CELL * .6) * 1.4 * (np.abs(B.Y - cy) < 33), GUARD[4])
        out(f, whole & (f[..., 3] > 0), GUARD[0])
        for x, y, s in ((-22, -27, 3), (22, -27, 4), (0, 27, 4)):
            glint(f, k, s, cx + x, cy + y, GUARD, 10)
        for c in sparks:
            c.draw(f, k)
        B.flash_pool(r, k - 2, 5, 34, GUARD) if k >= 2 else None
        rear.append(r); front.append(f)
    return rear, front


# ---- Stoneskin: slabs shoulder up out of the floor round the body, stand, then crumble into it ---------------------------
class Slab:
    def __init__(self, rng, x, y, w, h, start, lean):
        self.x, self.y, self.w, self.h, self.start, self.lean = x, y, w, h, start, lean
        self.nick, self.seed = rng.uniform(.25, .75), int(rng.integers(1 << 30))

    def draw(self, img, k):
        t = k - self.start
        if t < 0 or k >= 14:
            return
        rise = [.35, .78, 1.06, 1.0][min(t, 3)]
        sink = clamp((k - 9) / 4.5)
        h = self.h * rise * (1 - sink * .9)
        if h < 3:
            return
        x, y, w = self.x, self.y, self.w
        lx = self.lean * h
        left = poly([(x - w, y - 1.5), (x - w + lx, y - h * .86), (x + lx, y - h + 1), (x, y + w * .42)])
        right = poly([(x, y + w * .42), (x + lx, y - h + 1), (x + w + lx, y - h * .8), (x + w, y - 1.5)])
        top = poly([(x - w + lx, y - h * .86), (x + lx - w * .1, y - h - w * .42), (x + w + lx, y - h * .8), (x + lx, y - h + w * .2)])
        rng = np.random.default_rng(self.seed)
        grain = np.random.default_rng(self.seed + 1).random((B.FH, B.FW))
        grain = (grain + np.roll(grain, 1, 1) + np.roll(grain, 1, 0)) / 3     # short clumps, not a grid
        put(img, left, STONE[2]); put(img, right, STONE[1])
        put(img, left & (grain > .66), STONE[3]); put(img, left & (grain < .30), STONE[1]); put(img, right & (grain < .33), STONE[0]); put(img, right & (grain > .72), STONE[2])
        put(img, top, STONE[3]); put(img, lit_edge(top), STONE[4])
        put(img, top & (grain > .58), MOSS)
        seam = np.abs((B.X - x - lx * .5) + (B.Y - y + h * self.nick) * .6) < .9 * max(1, B.CELL)
        put(img, (left | right) & seam, STONE[0])
        if k >= 8:                                           # it cracks before it goes
            for j in range(2):
                off = rng.uniform(-.6, .6) * w
                crack = np.abs((B.X - x - off) - np.sin((B.Y - y) * .5 + j) * 1.6) < .7 * max(1, B.CELL)
                put(img, (left | right) & crack, STONE[0])
        out(img, left | right | top, STONE[0])


def stoneskin():
    rng = np.random.default_rng(720)
    back = [Slab(rng, -27, -3, 10, 34, 1, -.10), Slab(rng, -11, -11, 11, 50, 0, -.03), Slab(rng, 10, -11, 11, 46, 1, .04), Slab(rng, 27, -3, 10, 32, 2, .12)]
    fore = [Slab(rng, -21, 10, 9, 20, 1, -.12), Slab(rng, 0, 16, 10, 16, 2, 0), Slab(rng, 21, 10, 9, 22, 1, .14)]
    dust = [(B.Puff(rng, math.cos(a) * 26, math.sin(a) * 12, rng.uniform(7, 10), i % 3, rng.uniform(6, 9), math.cos(a) * 12, math.sin(a) * 5 - 4, B.DUST)) for i, a in enumerate(np.linspace(.2, 6.0, 8))]
    late = [(B.Puff(rng, math.cos(a) * 24, math.sin(a) * 11 - 2, rng.uniform(7, 10), 9 + i % 2, rng.uniform(5, 6), math.cos(a) * 8, math.sin(a) * 4 - 3, B.DUST)) for i, a in enumerate(np.linspace(.5, 5.8, 6))]
    chips = [B.Chip(rng.uniform(-26, 26), rng.uniform(-30, 0), rng.uniform(-1.6, 1.6), rng.uniform(-2.2, .2), 9, rng.integers(4, 7), [STONE[1], STONE[3]], int(rng.integers(2, 4)), .7) for _ in range(14)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        for s in back:
            s.draw(r, k)
        for s in fore:
            s.draw(f, k)
        for p in dust + late:
            p.draw(r if p.y <= 0 else f, k)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


# ---- Heal: green motes wind up round the body out of a pool of light -----------------------------------------------------
def heal():
    rng = np.random.default_rng(740)
    motes = []
    for i in range(34):
        motes.append(dict(a=rng.uniform(0, 6.28), start=rng.integers(0, 7), life=rng.uniform(8, 11), rad=rng.uniform(15, 27), top=rng.uniform(42, 72), spin=rng.uniform(1.6, 2.8) * (1 if i % 3 else -1), plus=i % 4 == 0, big=i % 2))
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        B.flash_pool(r, k * .8, 8, 37, VERDE)
        # A soft column behind the body.
        t = k / (N - 1)
        col = np.clip(1 - np.abs(B.X) / 20, 0, 1) * np.clip((B.Y + 66 * ease(clamp(k / 6))) / 24, 0, 1) * (B.Y < 4)
        col = col * clamp(1.5 - t * 1.5) * .8
        put(r, dith(col), VERDE[1]); put(r, dith(np.clip(col * 1.5 - .42, 0, 1)), VERDE[2])
        for m in motes:
            age = (k - m["start"]) / m["life"]
            if not 0 <= age < 1:
                continue
            for back in (3, 2, 1, 0):
                g = age - back * .045
                if g < 0:
                    continue
                a = m["a"] + m["spin"] * g * 2.2
                x, y = math.cos(a) * m["rad"] * (1 - .35 * g), math.sin(a) * m["rad"] * .4 - ease(g) * m["top"] + 4
                img = r if math.sin(a) < 0 else f
                px, py = int(round(x * B.Q)) + B.CX, int(round(y * B.Q)) + B.CY
                s = 1 if back > 1 or age > .75 else 2
                if not (2 <= px < B.FW - 3 and 2 <= py < B.FH - 3):
                    continue
                if back:
                    img[py:py + s, px:px + s] = VERDE[3 - min(2, back - 1)] + (255,)
                elif m["plus"] and age < .8:
                    img[py - 2:py + 3, px] = VERDE[3] + (255,); img[py, px - 2:px + 3] = VERDE[3] + (255,)
                    img[py - 1:py + 2, px] = VERDE[4] + (255,); img[py, px - 1:px + 2] = VERDE[4] + (255,)
                else:
                    n = 2 + m["big"] if age < .7 else 1
                    img[py:py + n, px:px + n] = VERDE[3] + (255,)
                    if n > 1:
                        img[py:py + n - 1, px:px + n - 1] = VERDE[4] + (255,)
        rear.append(r); front.append(f)
    return rear, front


# ---- Buff: strokes of ember light race up round the body from the feet ----------------------------------------------------
def empower():
    rng = np.random.default_rng(760)
    strokes = []
    for i, a in enumerate(np.linspace(0, 2 * math.pi, 15, endpoint=False)):
        strokes.append((math.cos(a) * rng.uniform(19, 30), math.sin(a) * 12, rng.integers(0, 4), rng.uniform(48, 78), rng.uniform(2.8, 4.8), rng.uniform(-.10, .10)))
    chips = [B.Chip(rng.uniform(-24, 24), rng.uniform(-8, 8), rng.uniform(-.7, .7), rng.uniform(-6.2, -3.2), rng.integers(1, 6), rng.integers(6, 10), [AMBER[1], AMBER[3], AMBER[4]], 1 + i % 2, .05) for i in range(16)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        B.flash_pool(r, k, 7, 40, AMBER)
        for x, y, st, h, w, lean in strokes:
            t = (k - st) / 11.0
            if not 0 <= t < 1:
                continue
            img = r if y < 0 else f
            head, tail = h * ease(clamp(t / .55)), h * ease(clamp((t - .25) / .75)) * .98
            u = (y - B.Y - tail) / max(1e-6, head - tail)      # 0 at the tail, 1 at the head
            cx = x * (1 - .18 * (y - B.Y) / h) + lean * (y - B.Y)
            ww = w * np.clip(1 - np.abs(u - .62) / .62, 0, 1) * (1 - .4 * t)
            m = (u > 0) & (u < 1) & (np.abs(B.X - cx) < np.maximum(ww, .0)) & (ww > .4)
            core = m & (np.abs(B.X - cx) < ww * .45)
            put(img, m & dith(np.clip(1.5 - t * 1.1, 0, 1) * np.ones_like(B.X)), AMBER[1 if t > .65 else 2])
            put(img, core, AMBER[3 if t < .6 else 2])
            put(img, core & (u > .55) & (t < .5), AMBER[4])
        for c in chips:
            c.draw(f if c.y > 0 else r, k)
        rear.append(r); front.append(f)
    return rear, front


# ---- Mantle: a crown of crystals snaps out round the shoulders ------------------------------------------------------------
def crystal(img, x, y, ang, length, w, hot):
    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx
    tip = (x + dx * length, y + dy * length)
    mid = (x + dx * length * .34, y + dy * length * .34)
    a = poly([(x, y), (mid[0] + px * w, mid[1] + py * w), tip])
    b = poly([(x, y), tip, (mid[0] - px * w, mid[1] - py * w)])
    lit, dark = (b, a) if px * -.5 + py * -.8 < 0 else (a, b)
    put(img, dark, GEM[1]); put(img, lit, GEM[3] if not hot else GEM[4])
    ridge, _ = B.seg_mask((x, y), tip, .6)
    put(img, (a | b) & ridge, GEM[4] if hot else GEM[2])
    put(img, edge(a | b) & dark, GEM[2])
    out(img, a | b, GEM[0])


def mantle():
    rng = np.random.default_rng(780)
    cx, cy = 0, -30
    specs = []
    for i, a in enumerate(np.linspace(math.pi * 1.04, math.pi * 1.96, 9)):
        specs.append((cx + math.cos(a) * 11, cy + 4 + math.sin(a) * 22, a, rng.uniform(23, 28) * (1.2 if i % 2 == 0 else .86), 5.6 if i % 2 == 0 else 4.4, abs(i - 4) // 2))
    low = [(x, y, math.pi * 1.5 + lean, l, w, st) for x, y, lean, l, w, st in ((-19, 8, -.62, 24, 4.6, 1), (-10, 12, -.22, 17, 4.0, 2), (19, 8, .62, 24, 4.6, 1), (10, 12, .22, 17, 4.0, 2), (0, 15, .02, 13, 3.6, 3))]
    chips = [B.Chip(cx + math.cos(a) * 26, cy + math.sin(a) * 26, math.cos(a) * 2.6, math.sin(a) * 2.6 - .6, 10, rng.integers(4, 6), [GEM[2], GEM[3], GEM[4]], int(rng.integers(1, 3)), .3) for a in np.linspace(math.pi, 2 * math.pi, 14)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        B.flash_pool(r, k, 6, 36, GEM)
        for x, y, a, l, w, st in specs + low:
            t = k - st
            if t < 0 or k >= 12:
                continue
            g = [.3, .74, 1.12, 1.0][min(t, 3)] * (1 - clamp((k - 9) / 3.0) * .7)
            crystal(r if y < 0 and (x, y, a, l, w, st) in specs else f, x, y, a, l * g, w * (.6 + .4 * g), k in (4, 5))
        for i, (x, y, a, l, w, st) in enumerate(specs):
            if i % 2 == 0:
                glint(r, k, 4 + i // 2 % 3, x + math.cos(a) * l * .8, y + math.sin(a) * l * .8, GEM, 9)
        for c in chips:
            c.draw(r, k)
        rear.append(r); front.append(f)
    return rear, front


# ---- Illusion: panes of glass slide together on the tile, catch the light, and break -----------------------------------------
def illusion():
    rng = np.random.default_rng(800)
    panes = []
    xs = np.linspace(-20, 20, 7)
    for i, x in enumerate(xs):
        panes.append((x, rng.uniform(52, 66) - abs(x) * .7, 3.6 + (i % 2) * .8, (-1 if i % 2 else 1) * rng.uniform(16, 30), rng.uniform(-10, 10), rng.integers(0, 2)))
    chips = [B.Chip(rng.uniform(-22, 22), rng.uniform(-58, 2), rng.uniform(-2.8, 2.8), rng.uniform(-2.4, .4), 7 + i % 3, rng.integers(4, 7), [GLASS[1], GLASS[3], GLASS[4]], int(rng.integers(1, 4)), .5) for i in range(24)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        B.flash_pool(r, k - 3, 6, 34, GLASS) if k >= 3 else None
        for j, (x, h, w, ox, oy, st) in enumerate(panes):
            t = clamp((k - st) / 4.0)
            if k < st or k > 10:
                continue
            e = 1 - ease(t)
            gone = clamp((k - 6) / 4.0)
            px, py = x + ox * e, 4 + oy * e * .4
            lean = .10 * (-1 if j % 2 else 1) * (1 - t * .6)
            m = poly([(px - w, py), (px - w + lean * h, py - h + 3), (px + w + lean * h, py - h - 2), (px + w, py + 2)])
            img = f
            inner = m & dith(np.full_like(B.X, (.30 + .5 * t) * (1 - gone)))
            put(img, inner, GLASS[1])
            streak = np.abs((B.X - px) * 1.2 + (B.Y - py + h * .5) * .35 - (k - 4) * 4) < 2.6
            put(img, m & streak & dith(np.full_like(B.X, 1 - gone)), GLASS[3])
            ed = edge(m) & dith(np.full_like(B.X, 1 - gone))
            put(img, ed, GLASS[2]); put(img, lit_edge(m) & ed, GLASS[4 if 3 <= k <= 6 else 3])
        if k in (4, 5):
            for j, (x, h, w, ox, oy, st) in enumerate(panes):
                m = poly([(x - w + .6, 4), (x - w + .6, 4 - h + 3), (x + w - .6, 4 - h - 2), (x + w - .6, 6)])
                cover = np.clip((1.0 if k == 4 else .5) - np.clip((B.Y - 4 + h) / h - .45, 0, 1) * .9, 0, 1)
                put(f, m & dith(cover), GLASS[3])
                put(f, m & dith(cover * .9) & (B.X < x - w * .1 + (j % 2) * w * .5), GLASS[4])
                out(f, m, GLASS[0])
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


# ---- Summon: the dark wells up, hides the tile, and opens on whatever came through -------------------------------------------
def summon():
    rng = np.random.default_rng(820)
    cover = [B.Puff(rng, rng.uniform(-17, 17), 9 - 10 * (i % 7), rng.uniform(18, 25), (i % 7) * .4, rng.uniform(8.5, 10.5), rng.uniform(-5, 5), -rng.uniform(8, 16), SHADE) for i in range(26)]
    spill = [B.Puff(rng, math.cos(a) * 24, math.sin(a) * 11 + 3, rng.uniform(9, 13), i % 3, rng.uniform(9, 12), math.cos(a) * 19, math.sin(a) * 8 - 2, SHADE) for i, a in enumerate(np.linspace(0, 6.0, 10))]
    part = [B.Puff(rng, math.cos(a) * 16, -28 + math.sin(a) * 24, rng.uniform(9, 13), 6, rng.uniform(7, 9), math.cos(a) * 26, math.sin(a) * 18 - 8, SHADE) for a in np.linspace(0, 6.0, 10)]
    motes = [B.Chip(rng.uniform(-26, 26), rng.uniform(-6, 8), rng.uniform(-.6, .6), rng.uniform(-5.4, -2.2), rng.integers(0, 7), rng.integers(6, 9), [SHADE[2], SHADE[3], SHADE[4]], 1 + i % 2, .04) for i in range(20)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        # The floor opens: a black diamond with a violet lip, closing as the smoke leaves.
        t = ease(clamp(k / 3)) * (1 - clamp((k - 9) / 5))
        if t > 0:
            d = np.abs(B.X) / (38 * t) + np.abs(B.Y) / (19 * t)
            put(r, d < 1, SHADE[0])
            put(r, (d < 1) & (d > 1 - .20) & dith(np.full_like(B.X, .9)), SHADE[3])
            put(r, (d < .86) & (d > .60) & dith(np.clip(.9 - (d - .6) * 0, 0, 1) * .4 * np.ones_like(B.X)), SHADE[2])
        for p in spill:
            p.draw(r if p.y <= 2 else f, k)
        for p in cover + part:
            p.draw(f, k)
        for c in motes:
            c.draw(f if c.y > 2 else r, k)
        rear.append(r); front.append(f)
    return rear, front


# ---- Expose: a shaft of light finds the unit and its guard splits open ---------------------------------------------------------
def expose():
    rng = np.random.default_rng(840)
    cy = -32
    cracks = [(math.cos(a) * 1.0, math.sin(a), l, b) for a, l, b in ((-1.0, 19, .5), (.5, 16, -.6), (1.75, 21, .5), (2.75, 15, -.5), (4.05, 18, .6))]
    chips = [B.Chip(rng.uniform(-9, 9), cy + rng.uniform(-14, 14), math.cos(a) * rng.uniform(2.4, 4.8), math.sin(a) * rng.uniform(1.6, 3.2) - 1.2, 3, rng.integers(5, 9), [LIGHT[1], LIGHT[3], LIGHT[4]], int(rng.integers(1, 4)), .35) for a in np.linspace(0, 6.2, 18)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        s = clamp(k / 2.0) * clamp((9 - k) / 5.0)
        if s > 0:
            half = 15 + (B.Y + 77) * .16
            beam = np.clip(1 - np.abs(B.X) / half, 0, 1) ** .8 * (B.Y < 4 + 10 * (1 - (np.abs(B.X) / 30) ** 2))
            put(f, dith(np.clip(beam * .55 - .2, 0, 1) * s * (k < 6)), LIGHT[3])
            put(r, dith(beam * s * .95), LIGHT[1]); put(r, dith(np.clip(beam * 1.4 - .4, 0, 1) * s), LIGHT[2])
            put(r, dith(np.clip(beam * 1.6 - .95, 0, 1) * s), LIGHT[3])
        B.flash_pool(r, k, 7, 33, LIGHT)
        if 2 <= k < 12:
            grow, die = ease(clamp((k - 2) / 2.0)), clamp((k - 5) / 4.0)
            for dx, dy, l, bend in cracks:
                a0, a1 = l * die * .9, l * grow
                if a1 - a0 < 2:
                    continue
                m1 = (dx * l * .5 - dy * bend * 12, cy + dy * l * .5 + dx * bend * 12)
                pts = [(0, cy), m1, (dx * l, cy + dy * l)]
                for (p, q, lo, hi) in ((pts[0], pts[1], 0, .5), (pts[1], pts[2], .5, 1)):
                    u0, u1 = clamp((a0 / l - lo) / .5), clamp((a1 / l - lo) / .5)
                    if u1 <= u0:
                        continue
                    P = (p[0] + (q[0] - p[0]) * u0, p[1] + (q[1] - p[1]) * u0)
                    Q = (p[0] + (q[0] - p[0]) * u1, p[1] + (q[1] - p[1]) * u1)
                    w = 1.9 * (1 - lo * .7) * (1 - die * .5)
                    wide, _ = B.seg_mask(P, Q, w)
                    core, _ = B.seg_mask(P, Q, w * .42)
                    put(f, wide, LIGHT[2]); put(f, core, LIGHT[4])
        glint(f, k, 2, 0, cy, LIGHT, 24)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


EFFECTS = {"block": block, "stoneskin": stoneskin, "heal": heal, "empower": empower, "mantle": mantle, "illusion": illusion, "summon": summon, "expose": expose}


def main(out_dir, sizes=B.SIZES):
    out_dir.mkdir(parents=True, exist_ok=True)
    meta = {"frames": N, "fps": FPS, "palette": [], "rows": {}, "sizes": []}
    palette = {}
    for size in sizes:
        B.use(size)
        rows = []
        for name, fn in EFFECTS.items():
            r, f = fn()
            rows += [("%s_rear" % name, r), ("%s_front" % name, f)]
        sheet = np.zeros((B.FH * len(rows), B.FW * N), np.uint8)
        for y, (name, frames) in enumerate(rows):
            meta["rows"][name] = y
            for i, px in enumerate(frames):
                cell = sheet[y * B.FH:(y + 1) * B.FH, i * B.FW:(i + 1) * B.FW]
                for c in sorted({tuple(int(q) for q in v) for v in np.unique(px[px[..., 3] > 0], axis=0)}):
                    cell[(px == c).all(axis=2)] = palette.setdefault(c, len(palette) + 1)
        name = "self_burst_%02d.png" % size
        Image.fromarray(sheet).save(out_dir / name, optimize=True)
        meta["sizes"].append({"tile_cells": [size, size / 2], "frame_cells": [B.FW, B.FH], "tile_centre_cell": [B.CX, B.CY], "atlas": name,
                              "sha256_pixels": hashlib.sha256(sheet.tobytes()).hexdigest()})
        print(name, sheet.shape[::-1], (out_dir / name).stat().st_size // 1024, "KB", len(rows), "rows", len(palette), "colours")
    meta["palette"] = ["00000000"] + ["%02x%02x%02x%02x" % c for c in palette]
    (out_dir / "self_burst_atlas.json").write_text(json.dumps(meta, indent=1) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "tools/fx13/out"), [int(a) for a in sys.argv[2:]] or B.SIZES)

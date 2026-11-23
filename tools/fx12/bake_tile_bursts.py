"""Bakes the one-shot tile bursts that land on each tile an area attack hits (director-owned art; numpy + PIL only).

One cell is one pixel-FX cell (2 framebuffer pixels at 1080p). Shapes are authored for an 85-cell tile and rasterised at
each tile width in SIZES, so a cell is never scaled; the player picks the nearest size. Each burst has a rear and a front
row so a unit can stand inside it, and two strengths: hit (a unit took it) and floor (the empty tiles of the area). The
player mirrors every other tile. Frame 0 is the contact frame. One byte per cell: palette index, 0 empty.
Usage: python3 tools/fx12/bake_tile_bursts.py [out_dir]
"""
import hashlib, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image

N, FPS = 13, 30
SIZES = [44, 52, 60, 68, 76, 84, 92]   # tile widths in cells
HW, HH = 42.5, 21.25                   # authored half extents
STEEL = [(0x4a, 0x1c, 0x0e), (0x96, 0x3c, 0x14), (0xe0, 0x86, 0x3a), (0xff, 0xc8, 0x84), (0xff, 0xf4, 0xdc)]
AIM = [(0x3a, 0x34, 0x30), (0x6e, 0x66, 0x60), (0xa8, 0x9e, 0x94), (0xdc, 0xd4, 0xc8), (0xff, 0xfb, 0xf0)]
DUST = [(0x2e, 0x26, 0x20), (0x54, 0x46, 0x39), (0x82, 0x70, 0x5a), (0xac, 0x98, 0x7c), (0xd2, 0xc2, 0xa4)]
FIRE = [(0x3a, 0x12, 0x08), (0x8a, 0x2a, 0x10), (0xd0, 0x58, 0x1c), (0xf2, 0x9a, 0x3a), (0xff, 0xe6, 0xa8)]
SMOKE = [(0x1c, 0x14, 0x12), (0x34, 0x26, 0x20), (0x4c, 0x3a, 0x30), (0x66, 0x50, 0x42), (0x80, 0x68, 0x58)]
ICE = [(0x14, 0x2c, 0x4c), (0x2a, 0x5c, 0x8e), (0x58, 0x9c, 0xce), (0x9c, 0xd8, 0xf4), (0xf2, 0xfd, 0xff)]
EARTH = [(0x20, 0x18, 0x12), (0x42, 0x32, 0x24), (0x6c, 0x54, 0x3a), (0x9c, 0x7e, 0x58), (0xca, 0xae, 0x82)]
AIR = [(0x1c, 0x4a, 0x42), (0x3a, 0x84, 0x74), (0x78, 0xc2, 0xac), (0xb8, 0xec, 0xd8), (0xf4, 0xff, 0xfa)]
BOLT = [(0x2a, 0x1a, 0x4a), (0x5a, 0x3a, 0x9a), (0x9a, 0x7a, 0xe0), (0xd0, 0xc0, 0xff), (0xff, 0xff, 0xff)]
LIGHT = [(0x5a, 0x34, 0x0c), (0xa8, 0x6c, 0x1c), (0xe6, 0xae, 0x44), (0xff, 0xde, 0x8c), (0xff, 0xfb, 0xe4)]
SHADOW = [(0x0e, 0x08, 0x16), (0x26, 0x14, 0x3a), (0x4a, 0x2a, 0x72), (0x8a, 0x5c, 0xc4), (0xe0, 0xcc, 0xff)]
SHADOW_SEED = 211
SHADOW_STILL_FRAME = 4
SHADOW_SPREAD_CELLS = 5
SHADOW_FOOT_CELLS = 9
SHADOW_TIP_CELLS = 2
SHADOW_HOOK_FRACTION = .2
SHADOW_TENDRIL_RADIUS = .55
SHADOW_POOL_RADII = (.28, .42)
SHADOW_POOL_SHRINK_START = 10
SHADOW_POOL_COVERAGE = .6
SHADOW_POOL_NOISE = (.22, .12)
SHADOW_POOL_PHASES = np.random.default_rng(SHADOW_SEED).uniform(0, math.tau, 2)
SHADOW_BLOT_WIDTH = SHADOW_FOOT_CELLS * .7
SHADOW_BLOT_AMPLITUDE = .25
SHADOW_BLOT_NOISE = tuple(weight * SHADOW_BLOT_AMPLITUDE / sum(SHADOW_POOL_NOISE) for weight in SHADOW_POOL_NOISE)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


def use(size):
    """Set the raster for one tile width. X and Y are authored units at each cell centre."""
    global Q, CELL, FW, FH, CX, CY, X, Y, DITHER
    Q, CELL = size / 85.0, 85.0 / size
    CX, CY = int(math.ceil(51 * Q)) + 1, int(math.ceil(77 * Q)) + 1
    FW, FH = CX * 2, CY + int(math.ceil(25 * Q)) + 1
    yy, xx = np.mgrid[0:FH, 0:FW]
    X, Y = (xx - CX + .5) * CELL, (yy - CY + .5) * CELL
    DITHER = BAYER[yy % 4, xx % 4]


use(84)


def blank():
    return np.zeros((FH, FW, 4), np.uint8)


def put(img, mask, colour):
    img[mask] = colour + (255,)


def dith(value):
    """Ordered-dither coverage of a 0..1 field."""
    return value > DITHER


def ease(t):
    return 1 - (1 - t) ** 3


def seg_mask(p, q, width):
    """Cells within width of a segment (cell units)."""
    d = np.array(q, float) - np.array(p, float)
    L = max(1e-6, d @ d)
    t = np.clip(((X - p[0]) * d[0] + (Y - p[1]) * d[1]) / L, 0, 1)
    return np.hypot(X - (p[0] + d[0] * t), Y - (p[1] + d[1] * t)) <= max(width, .52 * CELL), t


def poly(points):
    m = np.ones((FH, FW), bool)
    n = len(points)
    area = sum(points[i][0] * points[(i + 1) % n][1] - points[(i + 1) % n][0] * points[i][1] for i in range(n))
    for i in range(n):
        (x0, y0), (x1, y1) = points[i], points[(i + 1) % n]
        c = (x1 - x0) * (Y - y0) - (y1 - y0) * (X - x0)
        m &= (c >= -.01) if area > 0 else (c <= .01)
    return m


def split(full, is_front):
    """rear/front pair from one image and a mask of the cells that draw in front of a unit."""
    r, f = full.copy(), full.copy()
    r[is_front] = 0
    f[~is_front] = 0
    return r, f


class Puff:
    """A dithered dust ball that swells, rises and thins from its top-left."""
    def __init__(self, rng, x, y, size, start, life, vx, vy, ramp):
        self.x, self.y, self.size, self.start, self.life, self.vx, self.vy, self.ramp = x, y, size, start, life, vx, vy, ramp
        self.seed = int(rng.integers(1 << 30))

    def draw(self, img, frame):
        age = (frame - self.start) / self.life
        if age < 0 or age >= 1:
            return
        e = ease(age)
        x, y = self.x + self.vx * e, self.y + self.vy * e
        r = self.size * (.45 + .55 * e)
        dx, dy = X - x, (Y - y) / .78
        rng = np.random.default_rng(self.seed)
        lump = np.zeros_like(X)
        for _ in range(4):
            a, rr = rng.uniform(0, 6.28), rng.uniform(.25, .55)
            lump = np.maximum(lump, 1 - np.hypot(dx - math.cos(a) * r * rr, dy - math.sin(a) * r * rr) / (r * rng.uniform(.5, .72)))
        dens = np.clip(lump * 2.2, 0, 1) * (1 - age) ** .7 * 1.05
        on = dith(dens)
        shade = np.clip((-dx * .35 - dy * .6) / r + .5, 0, 1) * (1 - age * .5)
        idx = np.clip((shade * 4).astype(int), 0, 3)
        for i in range(4):
            put(img, on & (idx == i), self.ramp[i + (1 if age < .25 and i < 3 else 0)])


class Chip:
    """A ballistic fragment with a one-cell trail."""
    def __init__(self, x, y, vx, vy, start, life, colours, size=1, gravity=.55):
        self.__dict__.update(x=x, y=y, vx=vx, vy=vy, start=start, life=life, colours=colours, size=size, gravity=gravity)

    def draw(self, img, frame):
        t = frame - self.start
        if t < 0 or t >= self.life:
            return
        for back, col in ((1, self.colours[0]), (0, self.colours[-1] if t < self.life * .6 else self.colours[len(self.colours) // 2])):
            u = max(0, t - back * .6)
            px, py = int(round((self.x + self.vx * u) * Q)) + CX, int(round((self.y + self.vy * u + self.gravity * u * u) * Q)) + CY
            s = max(1, int(round(self.size * Q ** .6)))
            s = s if t < self.life * .7 else max(1, s - 1)
            y0, x0 = max(0, py), max(0, px)
            if 0 <= px < FW - s and 0 <= py < FH - s:
                img[y0:y0 + s, x0:x0 + s] = col + (255,)


def crescent(img, frame, start, life, cx, cy, rx, ry, a0, a1, width, ramp, tilt=0.0):
    """A blade smear: a hot head racing from a0 to a1 with a tapering, breaking tail."""
    t = (frame - start) / life
    if t < 0 or t >= 1:
        return None
    dx, dy = X - cx, Y - cy
    ct, st = math.cos(tilt), math.sin(tilt)
    u, v = (dx * ct + dy * st) / rx, (-dx * st + dy * ct) / ry
    r = np.hypot(u, v)
    span = a1 - a0
    ang = np.arctan2(v, u)
    s = ((ang - a0) * np.sign(span)) % (2 * math.pi) / abs(span)
    head = ease(min(1, t / .38))
    tail = 0 if t < .28 else ease((t - .28) / .72) * 1.02
    inside = (s <= head) & (s >= tail) & (s <= 1)
    w = width / ((rx + ry) / 2) * np.clip(1 - np.abs(s - head * .78) / .8, .12, 1) * (1 - .55 * max(0, t - .3))
    band = inside & (r <= 1) & (r >= 1 - w)
    depth = np.clip((1 - r) / np.maximum(w, 1e-6), 0, 1)
    hot = np.clip(1 - (head - s) / .8, 0, 1)
    heat = np.clip((1 - depth) * .55 + hot * .55 - t * .55, 0, 1)
    if t > .45:
        band &= dith(np.clip(1.25 - (t - .45) * 1.9, 0, 1) * np.ones_like(X))
    idx = np.clip((heat * 5).astype(int), 0, 4)
    for i in range(5):
        put(img, band & (idx == i), ramp[i])
    return band


def glint(img, frame, start, cx, cy, ramp, size=11):
    k = frame - start
    if not 0 <= k <= 2:
        return
    s = [size * .55, size, size * .5][k]
    for dx, dy, l in ((1, 0, 1), (0, 1, .72), (.7, .42, .5), (.7, -.42, .5)):
        along = np.abs((X - cx) * dx + (Y - cy) * dy) / math.hypot(dx, dy)
        off = np.abs((X - cx) * dy - (Y - cy) * dx) / math.hypot(dx, dy)
        w = np.clip(1.9 * (1 - along / (s * l)), 0, 2) * max(1, CELL * .8)
        put(img, (off < w) & (along < s * l), ramp[3])
        put(img, (off < w * .55) & (along < s * l * .7), ramp[4])


def flash_pool(img, frame, life, radius, ramp):
    """A filled pool of light on the tile: brightest on contact, then it breaks up from the middle outward."""
    t = frame / life
    if t >= 1:
        return
    r = np.hypot(X, Y * 2) / radius
    f = np.clip((1.06 - r) * 2.2, 0, 1) * (1 - t) ** .8
    f *= np.clip(1.1 - t * 1.6 * (1.1 - r), 0, 1)
    put(img, dith(f * .95), ramp[1])
    put(img, dith(np.clip(f * 1.25 - .42, 0, 1)), ramp[2])
    if frame <= 1:
        put(img, dith(np.clip((.62 - r) * 2.4 - frame * .5, 0, 1)), ramp[3])


# ---- bursts ---------------------------------------------------------------------------------------------------------
def steel(low):
    rng = np.random.default_rng(500)
    puffs = [Puff(rng, math.cos(a) * 15, math.sin(a) * 7 + 1, rng.uniform(9, 13) * (.75 if low else 1), i % 2, rng.uniform(8.5, 11.5), math.cos(a) * 17, math.sin(a) * 7 - rng.uniform(2, 7), DUST)
             for i, a in enumerate(np.linspace(.3, 6.1, 4 if low else 7))]
    chips = [Chip(rng.uniform(-4, 8), rng.uniform(-12, -4), rng.uniform(-1, 4.2), rng.uniform(-4.2, -1.2), 1, rng.integers(5, 9), [STEEL[1], STEEL[3], STEEL[4]], 1) for _ in range(0 if low else 10)]
    chips += [Chip(rng.uniform(-14, 14), rng.uniform(-2, 8), rng.uniform(-2.4, 2.4), rng.uniform(-3.4, -1.4), 1, rng.integers(6, 10), [DUST[1], DUST[3]], 2) for _ in range(3 if low else 5)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        for p in puffs:
            p.draw(f if p.y > 2 else r, k)
        crescent(f, k, -1, 8, 0, -2 if low else -12, 38, 20 if low else 25, math.pi * 1.02, -math.pi * .06, 7 if low else 13, STEEL, .18 if low else .32)
        if not low:
            glint(f, k, 0, 5, -12, STEEL, 14)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


def fire(low):
    rng = np.random.default_rng(40)
    out_r, out_f = [], []

    def column(seed, base, tongues, height, hold):
        rg = np.random.default_rng(seed)
        w, h = int(round(46 * Q)) * 2, int(round(74 * Q))
        height, tongues = height * (1.75 if low else 1) / Q, [(cx * Q, max(2.4, ww * Q * (.8 if low else 1)), a) for cx, ww, a in tongues]
        x = np.arange(w) - w // 2 + .5
        cool = rg.random((N * 5 + h, w))
        for _ in range(2):
            cool = (cool + np.roll(cool, 1, 0) + np.roll(cool, -1, 0) + np.roll(cool, 1, 1) + np.roll(cool, -1, 1)) / 5
        cool = ((cool - cool.min()) / (cool.max() - cool.min())) ** 1.2
        b = np.zeros((h + 2, w))
        frames = []
        SUB = 5
        for step in range(N * SUB):
            t = step / SUB
            gain = min(1, (t + .8) / 1.1) * (1 if t < hold else max(0, 1 - (t - hold) / 3.0))
            src = np.zeros(w)
            for n, (cx, ww, a) in enumerate(tongues):
                sway = math.sin(step * .55 + n * 2.1) * 2.2 * Q
                flick = .86 + .14 * math.sin(step * 1.3 + n * 1.7)
                src = np.maximum(src, a * flick * np.exp(-((x - cx - sway) / (ww * .92)) ** 2))
            b[h] = np.clip(src * gain * 1.14 - cool[step % cool.shape[0]] * .12, 0, 1)
            b[h + 1] = b[h]
            up1, up2, up3 = b[1:h + 1].copy(), b[2:h + 2].copy(), np.vstack([b[3:h + 2], b[h + 1:h + 2]])
            new = (up1 * .8 + np.roll(up1, 1, 1) * .5 + np.roll(up1, -1, 1) * .5 + up2 * 1.4 + up3 * .9) / 4.1 - cool[(np.arange(h) + step * 2) % cool.shape[0]] * height
            b[:h] = np.clip(new, 0, 1)
            if step % SUB == SUB - 1:
                g = np.zeros((FH, FW))
                for i in range(w):
                    col = int(round(x[i] - .5)) + CX
                    yb = int(round(CY + base(x[i] * CELL) * Q))
                    if 0 <= col < FW:
                        for j in range(h):
                            yy = yb - (h - 1 - j)
                            if 0 <= yy < FH:
                                g[yy, col] = b[j, i]
                frames.append(g)
        return frames

    vee = lambda fy, gx: (lambda x: HH * fy * max(0.0, 1 - abs(x) / (HW * gx)))
    rear = [column(7, vee(-.62, .8), [(-20, 7, .95), (-2, 8, 1), (18, 8, 1)], .062, 4.4),
            column(9, vee(-.2, .85), [(-30, 5, .9), (-10, 7, .95), (11, 7, 1), (31, 5, .9)], .07, 4.0)]
    front = [column(11, vee(.2, .85), [(-31, 5, .9), (-14, 5, .8), (27, 5, .95)], .078, 3.8),
             column(13, vee(.7, .85), [(-19, 6, .95), (2, 5, .8), (18, 6, .95)], .095, 3.4)]
    embers = [Chip(rng.uniform(-30, 30), rng.uniform(-14, 10), rng.uniform(-1.2, 1.2), rng.uniform(-5.2, -2.2), rng.integers(1, 5), rng.integers(5, 9), [FIRE[1], FIRE[3], FIRE[4]], 1, .18) for _ in range(6 if low else 16)]
    smoke = [] if low else [Puff(rng, x, y, rng.uniform(8, 11), st, rng.uniform(6, 8), rng.uniform(-3, 5), -rng.uniform(14, 22), SMOKE) for x, y, st in ((-18, -26, 4), (4, -34, 5), (20, -24, 4), (-6, -18, 6), (14, 2, 5))]
    TH = [.14, .30, .52, .80]
    for k in range(N):
        pair = []
        for layers in (rear, front):
            o = blank()
            for layer in layers:
                g = layer[k]
                on = g > TH[0]
                a = np.pad(on.astype(int), 1)
                nb = sum(a[1 + dy:FH + 1 + dy, 1 + dx:FW + 1 + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
                on &= nb >= 2
                idx = np.digitize(g, TH[1:])
                for i in range(4):
                    put(o, on & (idx == i), FIRE[i + 1])
            pair.append(o)
        under = blank()
        flash_pool(under, k, 6, 41, FIRE)
        for p in smoke:
            p.draw(pair[0] if p.y <= 0 else pair[1], k)
        bare = pair[0][..., 3] == 0
        pair[0][bare] = under[bare]
        for e in embers:
            e.draw(pair[1], k)
        out_r.append(pair[0]); out_f.append(pair[1])
    return out_r, out_f


def spikes(low, ramp, count, hmin, hmax, wide, seed, shatter, gap=.9, pull=1.0):
    """Faceted shards thrust out of the tile: rear and front groups."""
    rng = np.random.default_rng(seed + low)
    if low:
        count, hmin, hmax, wide, pull = int(count * .7), hmin * .5, hmax * .46, wide * .78, 1.05
    items = []
    tries = 0
    while len(items) < count and tries < 400:
        tries += 1
        a, rr = rng.uniform(0, 6.28), rng.uniform(.18, .8) ** .7
        x, y = math.cos(a) * HW * rr * .86 * pull, math.sin(a) * HH * rr * .86 * pull
        if any(abs(x - i['x']) < wide * gap and abs(y - i['y']) < 5 for i in items):
            continue
        # In front of a unit the shards stay below the waist.
        h = rng.uniform(hmin, hmax) * (1.0 - .25 * abs(x) / HW) * (1.0 if y <= 2 else .72)
        items.append(dict(x=x, y=y, h=h, w=rng.uniform(wide * .7, wide * 1.15), lean=x / HW * rng.uniform(.28, .5) + rng.uniform(-.1, .1), start=rng.choice([0, 0, 1]), facet=rng.uniform(-.15, .35)))
    items.sort(key=lambda i: i['y'])
    frag = []
    for it in items:
        for _ in range((2 if low else 5) if shatter else 2):
            u = rng.uniform(.15, .95)
            frag.append((it['y'], Chip(it['x'] + it['lean'] * it['h'] * u, it['y'] - it['h'] * u, it['x'] / HW * rng.uniform(.6, 2.6) + rng.uniform(-.8, .8), rng.uniform(-2.6, -.2), 7, rng.integers(4, 7), [ramp[1], ramp[3], ramp[4]], int(rng.integers(1, 4)), .5)))
    return items, frag, rng


def draw_spike(img, it, k, ramp, sink):
    t = k - it['start']
    if t < 0:
        return
    grow = [.45, .92, 1.06, 1.0][min(t, 3)]
    gone = 0.0
    if k >= 7:
        if not sink:
            return
        gone = min(1, (k - 7) / 4.0)
    h = it['h'] * grow * (1 - gone)
    if h < 2:
        return
    x, y, w, lean = it['x'], it['y'], it['w'] * (1 - .25 * gone), it['lean']
    tip = (x + lean * h, y - h)
    l, r = (x - w / 2, y + w * .10), (x + w / 2, y + w * .06)
    base = (x + w * it['facet'], y + w * .26)
    put(img, poly([l, base, tip]), ramp[2])
    put(img, poly([base, r, tip]), ramp[1])
    # shaded foot, lit left edge, bright ridge.
    inside = poly([l, base, tip]) | poly([base, r, tip])
    foot = inside & (Y > y - h * .16)
    put(img, foot & dith(np.full_like(X, .55)), ramp[0])
    e, t1 = seg_mask(l, tip, .62); put(img, e & inside, ramp[3])
    e, t1 = seg_mask(base, tip, .55); put(img, e & inside & (t1 > .12), ramp[3])
    e, t1 = seg_mask(l, tip, .75); put(img, e & inside & (t1 > .55), ramp[4])
    # Crack band: an inner darker stripe reads as a facet break.
    e, t1 = seg_mask((x + w * .12, y - h * .08), (x + lean * h * .6 + w * .10, y - h * .55), .5); put(img, e & inside, ramp[0])


def ice(low):
    items, frag, rng = spikes(low, ICE, 9, 20, 38, 13, 81, True)
    puffs = [Puff(rng, math.cos(a) * 18, math.sin(a) * 8, rng.uniform(6, 9), 6 + i % 2, 6, math.cos(a) * 9, math.sin(a) * 4 - 3, ICE) for i, a in enumerate(np.linspace(0, 5.2, 3 if low else 5))]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        flash_pool(r, k, 5, 41, ICE)
        for it in items:
            draw_spike(f if it['y'] > 2 else r, it, k, ICE, False)
        for y, c in frag:
            c.draw(f if y > 0 else r, k)
        for p in puffs:
            p.draw(r if p.y < 2 else f, k)
        if k in (1, 2) and not low:
            glint(f, k, 1, -9, -26, ICE, 8)
        rear.append(r); front.append(f)
    return rear, front


def shadow_tendrils(low, rng):
    count, hmin, hmax = (4, 12, 20) if low else (5, 24, 38)
    items = []
    # Keep the seeded footprint and staggering when changing the drawn width.
    opening_radius = SHADOW_TENDRIL_RADIUS - SHADOW_SPREAD_CELLS / (2 * HW)
    while len(items) < count:
        angle, radius = rng.uniform(0, 6.28), rng.uniform(.18, .8) ** .7 * .86
        if radius > opening_radius:
            continue
        x, y = math.cos(angle) * HW * radius, math.sin(angle) * HH * radius
        if any(abs(x - item['x']) < SHADOW_SPREAD_CELLS * .9 and abs(y - item['y']) < 5 for item in items):
            continue
        # Use the ice front-group height reduction within the directed range.
        height = rng.uniform(hmin, hmax)
        if y > 2:
            height = hmin + (height - hmin) * .72
        items.append(dict(x=x, y=y, h=height, start=rng.choice([0, 0, 1])))
    return sorted(items, key=lambda item: item['y'])


def shadow_edge_scale(angle, noise=SHADOW_POOL_NOISE):
    return 1 + noise[0] * np.sin(3 * angle + SHADOW_POOL_PHASES[0]) + noise[1] * np.sin(5 * angle + SHADOW_POOL_PHASES[1])


def shadow_stain(x, y, radius, noise=SHADOW_POOL_NOISE):
    # Measure in board space so both the radius and its distortion follow the 2:1 projection.
    y = y * 2
    return np.hypot(x, y) <= radius * shadow_edge_scale(np.arctan2(y, x), noise)


def shadow_pool_shape(x, y, frame, items):
    opening, full = SHADOW_POOL_RADII
    radius = opening + (full - opening) * min(frame, 2) / 2
    if frame > SHADOW_POOL_SHRINK_START:
        radius *= (N - 1 - frame) / (N - 1 - SHADOW_POOL_SHRINK_START)
    stain = shadow_stain(x, y, HW * radius)
    for item in items:
        if item['start'] <= frame < 10:
            stain |= shadow_stain(x - item['x'], y - item['y'], SHADOW_BLOT_WIDTH * CELL / 2, SHADOW_BLOT_NOISE)
    return stain


def draw_shadow_pool(img, frame, items):
    if frame == N - 1:
        return

    # Erode the union by one cell before dithering to keep the rim on its outer edge.
    stain = shadow_pool_shape(X, Y, frame, items)
    padded = np.pad(stain, 1)
    interior = padded[1:-1, :-2] & padded[1:-1, 2:] & padded[:-2, 1:-1] & padded[2:, 1:-1]
    coverage = min(SHADOW_POOL_COVERAGE, (N - frame) / (N - 8))
    put(img, stain & dith(coverage), SHADOW[0])
    put(img, stain & ~interior & dith(coverage / 2), SHADOW[1])


def draw_shadow_tendril(img, item, frame):
    local = frame - item['start']
    if local < 0 or frame >= 10:
        return
    rise = [.45, .92, 1.06][local] if frame <= 2 else 1.0
    sink = max(0, frame - 6) / 4
    x, y = item['x'], item['y']
    risen_height = item['h'] * rise
    height = risen_height * (1 - sink)
    # Sample both ends of the taper at occupied cell centres.
    base_y = (math.floor(y / CELL - .5) + .5) * CELL
    tip_y = (math.ceil((y - height) / CELL - .5) + .5) * CELL
    span = (Y >= tip_y) & (Y <= base_y)
    t = np.clip((base_y - Y) / max(CELL, base_y - tip_y), 0, 1)
    toward = -1 if x > 0 else 1
    angle = math.radians(35 * np.clip((frame - 2) / 4, 0, 1))
    hook_start = 1 - SHADOW_HOOK_FRACTION
    hook = np.clip((t - hook_start) / SHADOW_HOOK_FRACTION, 0, 1)
    # The top fifth bends to the directed tip tangent and sinks without changing its x coordinates.
    centre_x = x + toward * risen_height * SHADOW_HOOK_FRACTION * math.tan(angle) / 2 * hook ** 2
    foot = SHADOW_FOOT_CELLS * (1 - .25 * sink)
    taper = 1 - np.minimum(t / hook_start, 1)
    width = np.rint(SHADOW_TIP_CELLS + (foot - SHADOW_TIP_CELLS) * taper)
    first = np.floor((centre_x - X) / CELL - (width - 1) / 2 + .5)
    edge_cell = -first if toward < 0 else first + width - 1
    inside = span & (edge_cell >= 0) & (edge_cell < width)
    inner_edge = inside & (edge_cell < 2)
    core = inside & (edge_cell >= width - np.rint(width / 3))
    put(img, inside, SHADOW[2])
    put(img, core, SHADOW[0])
    put(img, inner_edge, SHADOW[3])
    put(img, inner_edge & (t >= .75) & (edge_cell == 0), SHADOW[4])
    put(img, inside & (t < .16) & dith(.55), SHADOW[0])


def shadow(low):
    items = shadow_tendrils(low, np.random.default_rng(SHADOW_SEED + low))
    chips = []
    if not low:
        colours = [SHADOW[0], SHADOW[2], SHADOW[3]]
        gravity = .55  # Chip's usual gravity; return to the pool on frame 6.
        opening = SHADOW_TENDRIL_RADIUS
        for x in np.linspace(-.75, .75, 4) * opening * HW:
            chips.append(Chip(x, opening * HH / 2, 0, -5 * gravity, 1, 6, colours, gravity=gravity))
    rear, front = [], []
    for frame in range(N):
        r, f = blank(), blank()
        draw_shadow_pool(r, frame, items)
        for item in items:
            draw_shadow_tendril(f if item['y'] > 2 else r, item, frame)
        for chip in chips:
            chip.draw(f, frame)
        rear.append(r); front.append(f)
    return rear, front


def earth(low):
    items, frag, rng = spikes(low, EARTH, 8, 18, 40, 24, 171, False, .5, .78)
    puffs = [Puff(rng, math.cos(a) * 20, math.sin(a) * 9 + 2, rng.uniform(10, 15) * (.7 if low else 1), i % 3, rng.uniform(8, 11), math.cos(a) * 18, math.sin(a) * 8 - rng.uniform(3, 9), DUST) for i, a in enumerate(np.linspace(.2, 6.0, 6 if low else 9))]
    chips = [Chip(rng.uniform(-18, 18), rng.uniform(-8, 6), rng.uniform(-2.8, 2.8), rng.uniform(-5.4, -2.4), 0, rng.integers(6, 11), [EARTH[1], EARTH[3]], int(rng.integers(1, 4)), .55) for _ in range(5 if low else 12)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        for p in puffs:
            if p.y <= 2:
                p.draw(r, k)
        for it in items:
            draw_spike(f if it['y'] > 2 else r, it, k, EARTH, True)
        for p in puffs:
            if p.y > 2:
                p.draw(f, k)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


def air(low):
    rng = np.random.default_rng(300)
    arcs = [(0, 7, 2, 34, 15, 0.1, 1.55, 7.5), (1, 8, -11, 28, 13, 2.2, 1.5, 6.5), (2, 8, -23, 23, 10.5, 4.2, 1.45, 6), (3, 8, -34, 18, 8, .9, 1.4, 5)][:2 if low else 4]
    chips = [Chip(rng.uniform(-26, 26), rng.uniform(-10, 10), rng.uniform(1, 3) * rng.choice([-1, 1]), rng.uniform(-4, -1.2), rng.integers(0, 4), rng.integers(5, 9), [DUST[2], AIR[2]], 1, .12) for _ in range(6 if low else 12)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        flash_pool(r, k, 4, 36, AIR)
        for s, life, y, rx, ry, a, span, w in arcs:
            for turn in (0, math.pi):
                full = blank()
                crescent(full, k, s, life, 0, y, rx, ry, a + turn, a + turn + span * math.pi * .62, w * (.7 if low else 1), AIR)
                fr = Y > y
                m = full[..., 3] > 0
                f[m & fr] = full[m & fr]
                r[m & ~fr] = full[m & ~fr]
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


def line(p, q):
    x0, y0, x1, y1 = [int(round(v)) for v in (*p, *q)]
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return [(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n))) for i in range(n + 1)]


def tree(rng, p, heading, length, iso, depth=0, wander=.8, goal=None, bounded=True):
    segs, cells, left, p, side = [], [], length, np.array(p, float), rng.choice([-1, 1])
    while left > 0:
        st = min(left, rng.uniform(2.8, 5.6))
        if goal is not None:
            g = np.array(goal, float) - p
            heading = math.atan2(g[1] / iso, g[0])
        side = -side if rng.random() < .8 else side
        a = heading + side * rng.uniform(.25, wander)
        q = p + np.array([math.cos(a) * st, math.sin(a) * st * iso])
        if bounded and abs(q[0]) / (HW * Q) + abs(q[1]) / (HH * Q) > .95:
            break
        cells += line(p, q)
        if depth < 2 and rng.random() < (.4 if depth == 0 else .18):
            segs += tree(rng, q, heading - side * rng.uniform(.6, 1.1), left * rng.uniform(.25, .5) + 2, iso, depth + 1, wander, None, bounded)
        p, left = q, left - st
        if goal is not None and np.linalg.norm((np.array(goal) - p) * [1, 1 / iso]) < 5:
            cells += line(p, goal)
            break
    return [(cells, depth)] + segs


def bolt(buf, paths, age, thick=False):
    def at(x, y, pr):
        xx, yy = x + CX, y + CY
        if 0 <= xx < FW and 0 <= yy < FH and pr > buf[yy, xx]:
            buf[yy, xx] = pr
    for cells, d in paths:
        for i, (x, y) in enumerate(cells):
            if age == 0:
                at(x, y, 5 if d < 2 else 4)
                if d == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        at(x + dx, y + dy, 5 if thick and dy == 0 else 3)
                    for dx, dy in ((1, 1), (-1, -1), (2, 0), (-2, 0)):
                        if thick or i % 2 == 0:
                            at(x + dx, y + dy, 2)
                else:
                    for dx, dy in ((1, 0), (0, 1)):
                        at(x + dx, y + dy, 2)
            elif age == 1:
                at(x, y, 5 if d == 0 else 4)
                if d == 0:
                    at(x + 1, y, 3); at(x, y + 1, 2)
            elif age == 2:
                if d == 0:
                    at(x, y, 4 if (i // 5) % 3 else 3)
                elif (i // 3) % 2:
                    at(x, y, 3)
            elif age == 3 and d == 0 and (i // 3) % 3 == 0:
                at(x, y, 3 if i % 2 else 2)


def lightning(low):
    rng0 = 900
    sky = [tree(np.random.default_rng(rng0 + j), (6 * Q, -76 * Q), math.pi / 2, 90 * Q, 1, 0, .75, (0, -2 * Q), False) for j in range(2)]
    rays = []
    for j, a in enumerate(np.linspace(.3, 6.0, 4 if low else 6)):
        rays.append((j % 3, tree(np.random.default_rng(rng0 + 10 + j), (math.cos(a) * 4 * Q, math.sin(a) * 2 * Q), math.atan2(math.sin(a), math.cos(a)), 40 * Q, .5), math.sin(a) > 0))
    climbs = [] if low else [(2 + j * 2, tree(np.random.default_rng(rng0 + 30 + j), (x * Q, y * Q), -math.pi / 2, 24 * Q, 1, 0, .7, None, False)) for j, (x, y) in enumerate(((16, 7), (-18, 5), (4, 12)))]
    rg = np.random.default_rng(rng0 + 77)
    sparks = [Chip(rg.uniform(-10, 10), rg.uniform(-6, 4), rg.uniform(-4, 4), rg.uniform(-4.6, -1), 1, rg.integers(4, 8), [BOLT[1], BOLT[3], BOLT[4]], 1, .5) for _ in range(4 if low else 12)]
    rear, front = [], []
    for k in range(N):
        rb, fb = np.zeros((FH, FW), int), np.zeros((FH, FW), int)
        if k <= 3 and not low:
            bolt(rb, sky[0 if k < 2 else 1], k, True)
        for s, paths, fr in rays:
            age = k - s
            if 0 <= age <= 3:
                bolt(fb if fr else rb, paths, age)
            if 4 <= age <= 7:
                bolt(fb if fr else rb, paths, age - 4 if age > 4 else 1)
        for s, paths in climbs:
            if 0 <= k - s <= 3:
                bolt(fb, paths, k - s)
        pair = []
        for buf in (rb, fb):
            o = blank()
            for pr, c in ((2, 1), (3, 2), (4, 3), (5, 4)):
                put(o, buf == pr, BOLT[c])
            pair.append(o)
        under = blank()
        flash_pool(under, k, 5, 41, BOLT)
        bare = pair[0][..., 3] == 0
        pair[0][bare] = under[bare]
        if not low:
            glint(pair[1], k, 0, 0, -2, BOLT, 14)
        for c in sparks:
            c.draw(pair[1], k)
        rear.append(pair[0]); front.append(pair[1])
    return rear, front


def light(low):
    rng = np.random.default_rng(700)
    motes = [Chip(rng.uniform(-28, 28), rng.uniform(-10, 12), rng.uniform(-.5, .5), rng.uniform(-4.4, -2), rng.integers(0, 6), rng.integers(5, 9), [LIGHT[2], LIGHT[3], LIGHT[4]], int(rng.integers(1, 3)), .06) for _ in range(9 if low else 20)]
    shafts = [(x, rng.uniform(40, 70), rng.uniform(6, 9.5), int(rng.integers(0, 2)), y) for x, y in ((-26, 0), (-9, -9), (13, -8), (27, 2), (4, 9))]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        flash_pool(r, k, 7, 31, LIGHT)   # smaller than a tile: neighbouring pools stay apart (director, native review 11-22)
        for x, h, w, s, y in ([] if low else shafts):
            t = (k - s) / 8.0
            if not 0 <= t < 1:
                continue
            up = ease(min(1, (t + .12) / .3))
            fade = 1 if t < .35 else 1 - (t - .35) / .65
            hh = h * up
            vert = np.clip((y - Y) / hh, 0, 1)
            edge = np.clip(1 - np.abs(X - x) / (w * (.35 + .65 * (1 - vert)) * (.4 + .6 * fade)), 0, 1)
            body = (Y <= y) & (Y >= y - hh) & (edge > 0)
            val = np.clip(edge * 1.35, 0, 1) * (1.1 - vert) ** 1.1 * fade * 1.35
            tgt = f if y > 2 else r
            put(tgt, body & dith(np.clip(val, 0, 1)), LIGHT[2])
            put(tgt, body & dith(np.clip(val - .4, 0, 1)), LIGHT[3])
            put(tgt, body & (edge > .6) & dith(np.clip(val - .6, 0, 1)), LIGHT[4])
        for c in motes:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


def streak(img, frame, start, p, q, width, ramp, life=4):
    """A falling missile: it lands on its first frame and its trail burns off from the top."""
    k = frame - start
    if not 0 <= k < life:
        return
    d = np.array(q, float) - np.array(p, float)
    on, t = seg_mask(p, q, width)
    on &= t >= [0, .3, .62, .85][k]
    heat = np.clip(t * 1.1 - k * .18, 0, 1)
    idx = np.clip((heat * 5).astype(int), 0, 4)
    on &= dith(np.clip(t * 1.5 - k * .12 + .1, 0, 1))
    for i in range(5):
        put(img, on & (idx == i), ramp[i])


def volley(low):
    rng = np.random.default_rng(610)
    marks = [(-22, -4, 0), (6, -10, 0), (24, 2, 1), (-6, 7, 1), (14, 11, 2), (-28, 5, 2)][:3 if low else 6]
    puffs = [Puff(rng, x, y, rng.uniform(6, 9), st, rng.uniform(7, 10), rng.uniform(-6, 6), -rng.uniform(3, 8), DUST) for x, y, st in marks]
    chips = [Chip(x + rng.uniform(-2, 2), y - 2, rng.uniform(-2.6, 2.6), rng.uniform(-3.6, -1), st, rng.integers(4, 8), [STEEL[2], STEEL[3], STEEL[4]], 1) for x, y, st in marks for _ in range(2 if low else 4)]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        for p in puffs:
            p.draw(f if p.y > 2 else r, k)
        for x, y, st in marks:
            streak(f if y > 2 else r, k, st, (x - 26, y - 58), (x, y), 1.1, AIM)
            if k == st and not low:
                glint(f if y > 2 else r, k, st - 1, x, y - 1, STEEL, 8)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


def shrapnel(low):
    rng = np.random.default_rng(620)
    n = 5 if low else 9
    balls = [Puff(rng, math.cos(a) * 11, math.sin(a) * 5 - 9, rng.uniform(13, 18) * (.6 if low else 1), 0, rng.uniform(4.5, 6), math.cos(a) * 13, math.sin(a) * 5 - rng.uniform(4, 12), FIRE) for a in np.linspace(.2, 6.0, n)]
    smoke = [Puff(rng, math.cos(a) * 13, math.sin(a) * 6 - 10, rng.uniform(9, 13) * (.7 if low else 1), 3 + i % 2, rng.uniform(7, 9), math.cos(a) * 12, -rng.uniform(9, 20), SMOKE) for i, a in enumerate(np.linspace(.4, 6.2, 3 if low else 7))]
    chips = []
    for a in np.linspace(0, 6.28, 7 if low else 16):
        v = rng.uniform(3.2, 6.6)
        chips.append(Chip(math.cos(a) * 5, math.sin(a) * 2 - 8, math.cos(a) * v, math.sin(a) * v * .5 - rng.uniform(.6, 2.6), 0, rng.integers(4, 8), [FIRE[2], FIRE[3], STEEL[4]], int(rng.integers(1, 3)), .4))
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        flash_pool(r, k, 3 if low else 4, 26 if low else 41, FIRE)
        for p in smoke + balls:
            p.draw(r if p.y < -8 else f, k)
        if k == 0 and not low:
            glint(f, k, 0, 0, -10, FIRE, 16)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


def impact(low):
    """A heavy blow on the floor: cracked flags, dust driven outward, chips thrown up."""
    rng = np.random.default_rng(630)
    n = 6 if low else 11
    puffs = [Puff(rng, math.cos(a) * 14, math.sin(a) * 7, rng.uniform(9, 14) * (.75 if low else 1), i % 2, rng.uniform(8, 11), math.cos(a) * 24, math.sin(a) * 11 - rng.uniform(2, 6), DUST) for i, a in enumerate(np.linspace(.1, 6.0, n))]
    chips = [Chip(rng.uniform(-20, 20), rng.uniform(-9, 8), rng.uniform(-2.4, 2.4), rng.uniform(-6.2, -2.8), 0, rng.integers(7, 11), [EARTH[1], EARTH[3]], int(rng.integers(2, 4)), .6) for _ in range(4 if low else 13)]
    cracks = [tree(np.random.default_rng(631 + j), (0, 0), a, (16 if low else 34) * Q, .5, 0, .7) for j, a in enumerate(np.linspace(.5, 6.1, 4 if low else 6))]
    rear, front = [], []
    for k in range(N):
        r, f = blank(), blank()
        if k < 10:
            for paths in cracks:
                for cells, d in paths:
                    for i, (x, y) in enumerate(cells):
                        if d == 0 and i % 5 and (k < 6 or (i + k) % 3):
                            xx, yy = x + CX, y + CY
                            if 0 <= xx < FW and 1 <= yy < FH:
                                r[yy, xx] = EARTH[0] + (255,)
                                r[yy - 1, xx] = (EARTH[1] if k > 1 else EARTH[2]) + (255,)
        for p in puffs:
            p.draw(r if p.y <= 2 else f, k)
        for c in chips:
            c.draw(f, k)
        rear.append(r); front.append(f)
    return rear, front


BURSTS = {"steel": steel, "volley": volley, "shrapnel": shrapnel, "impact": impact, "fire": fire, "ice": ice, "earth": earth, "air": air, "lightning": lightning, "light": light, "shadow": shadow}


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    meta = {"frames": N, "fps": FPS, "reduced_motion_frame_by_burst": {"shadow": SHADOW_STILL_FRAME},
            "palette": [], "rows": {}, "sizes": []}
    palette = {}                              # RGBA -> index; 0 is empty
    for size in SIZES:
        use(size)
        rows = []
        for name, fn in BURSTS.items():
            for part, low in (("hit", 0), ("floor", 1)):
                r, f = fn(low)
                rows += [("%s_%s_rear" % (name, part), r), ("%s_%s_front" % (name, part), f)]
        sheet = np.zeros((FH * len(rows), FW * N), np.uint8)
        for y, (name, frames) in enumerate(rows):
            meta["rows"][name] = y
            for i, px in enumerate(frames):
                cell = sheet[y * FH:(y + 1) * FH, i * FW:(i + 1) * FW]
                for c in sorted({tuple(int(q) for q in v) for v in np.unique(px[px[..., 3] > 0], axis=0)}):
                    cell[(px == c).all(axis=2)] = palette.setdefault(c, len(palette) + 1)
        name = "tile_burst_%02d.png" % size
        Image.fromarray(sheet).save(out / name, optimize=True)
        meta["sizes"].append({"tile_cells": [size, size / 2], "frame_cells": [FW, FH], "tile_centre_cell": [CX, CY], "atlas": name,
                              "sha256_pixels": hashlib.sha256(sheet.tobytes()).hexdigest()})
        print(name, sheet.shape[::-1], (out / name).stat().st_size // 1024, "KB", len(rows), "rows", len(palette), "colours")
    meta["palette"] = ["00000000"] + ["%02x%02x%02x%02x" % c for c in palette]
    (out / "tile_burst_atlas.json").write_text(json.dumps(meta, indent=1) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "tools/fx12/out"))

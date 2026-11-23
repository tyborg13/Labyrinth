"""Bakes the projectiles a ranged attack throws (director-owned art; numpy + PIL only).

One cell is one pixel-FX cell. Shapes are authored for an 85-cell tile and rasterised at each tile width in SIZES, so a
cell is never scaled. Directional shots have 32 headings (column = round(angle / 11.25 deg), screen angle, y down) and
FLICKER rows; spinning ones have 8 columns; the net has 8 columns of travel progress. One byte per cell: palette index,
0 empty. Physical objects carry a dark outline and light from the upper left; magic does not.
Usage: python3 tools/fx14/bake_shots.py [out_dir]
"""
import hashlib, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

SIZES = [44, 52, 60, 68, 76, 84, 92]
SS = 8
INK = (0x14, 0x0f, 0x0c)
STEEL = [(0x3a, 0x38, 0x3c), (0x6c, 0x6a, 0x70), (0xa6, 0xa6, 0xac), (0xe6, 0xe8, 0xec)]
WOOD = [(0x3a, 0x22, 0x14), (0x68, 0x40, 0x24), (0x96, 0x64, 0x3a), (0xc4, 0x94, 0x5e)]
FEATHER = [(0x5c, 0x1c, 0x18), (0x98, 0x32, 0x2a), (0xd0, 0x62, 0x4c)]
GOLD = [(0x5a, 0x36, 0x0c), (0x9c, 0x68, 0x1c), (0xdc, 0xa6, 0x3c), (0xff, 0xe6, 0x9c)]
BONE = [(0x5c, 0x52, 0x46), (0x9a, 0x8e, 0x7c), (0xd2, 0xc8, 0xb4), (0xfa, 0xf4, 0xe6)]
ROPE = [(0x4a, 0x38, 0x24), (0x84, 0x68, 0x44), (0xb8, 0x98, 0x68)]
ROCK = [(0x30, 0x26, 0x1e), (0x58, 0x46, 0x36), (0x86, 0x6c, 0x52), (0xb8, 0x9a, 0x78)]
ICE = [(0x1a, 0x3a, 0x58), (0x2f, 0x6f, 0x8f), (0x5f, 0xb0, 0xd0), (0xa8, 0xe0, 0xf0), (0xee, 0xfa, 0xff)]
FIRE = [(0x3a, 0x12, 0x08), (0x8a, 0x2a, 0x10), (0xd0, 0x58, 0x1c), (0xf2, 0x9a, 0x3a), (0xff, 0xe6, 0xa8)]
BOLT = [(0x2a, 0x1a, 0x4a), (0x5a, 0x3a, 0x9a), (0x9a, 0x7a, 0xe0), (0xd0, 0xc0, 0xff), (0xff, 0xff, 0xff)]
AIR = [(0x1e, 0x3a, 0x36), (0x3f, 0x7a, 0x6e), (0x79, 0xb8, 0xa6), (0xbf, 0xe6, 0xd6), (0xf2, 0xff, 0xf8)]
PALE = [(0x3a, 0x38, 0x40), (0x6a, 0x6a, 0x76), (0xa2, 0xa4, 0xb0), (0xda, 0xde, 0xe6), (0xff, 0xff, 0xff)]
LIGHT = [(0x6a, 0x36, 0x0c), (0xb8, 0x70, 0x1c), (0xee, 0xb0, 0x44), (0xff, 0xe0, 0x92), (0xff, 0xfc, 0xec)]
SHADE = [(0x12, 0x0a, 0x1c), (0x2c, 0x16, 0x46), (0x52, 0x2c, 0x7c), (0x86, 0x54, 0xb4), (0xc6, 0x9c, 0xec)]
DUST = [(0x3a, 0x30, 0x26), (0x5e, 0x50, 0x40), (0x8a, 0x78, 0x60), (0xb6, 0xa2, 0x86), (0xde, 0xd0, 0xb4)]
SHADOW = (0x08, 0x06, 0x06)
PALETTE = [(0, 0, 0, 0)]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


def ci(rgb):
    q = tuple(rgb) + (255,)
    if q not in PALETTE:
        PALETTE.append(q)
    return PALETTE.index(q)


class Grid:
    """A frame being painted: coordinates in authored cells (85 per tile), origin at the shot's point."""
    def __init__(self, half, q):
        self.q, self.n = q, int(math.ceil(half * q)) * 2 + 2
        self.hi = np.zeros((self.n * SS, self.n * SS), np.uint8)
        self.lo = np.zeros((self.n, self.n), np.uint8)
        yy, xx = np.mgrid[0:self.n, 0:self.n]
        self.x, self.y = (xx + .5 - self.n / 2) / q, (yy + .5 - self.n / 2) / q
        self.b = np.tile(BAYER, (self.n // 4 + 1, self.n // 4 + 1))[:self.n, :self.n]

    def mask(self, pts):
        im = Image.new('1', (self.n * SS, self.n * SS))
        ImageDraw.Draw(im).polygon([((x * self.q + self.n / 2) * SS, (y * self.q + self.n / 2) * SS) for x, y in pts], fill=1)
        return np.asarray(im)

    def fill(self, m, ramp, lit=None):
        """Paints a mask with upper-left light; lit is the rim width in cells."""
        base = ramp[len(ramp) // 2] if lit is None else ramp[-2]
        self.hi[m] = ci(base)
        if lit:
            d = max(1, int(lit * SS))
            sh = lambda dx, dy: np.roll(np.roll(m, dy, 0), dx, 1)
            self.hi[m & ~sh(-d, -d)] = ci(ramp[-3] if len(ramp) > 3 else ramp[0])
            self.hi[m & ~sh(d, d)] = ci(ramp[-1])

    def resolve(self, outline=True, keep=.42):
        blocks = self.hi.reshape(self.n, SS, self.n, SS).transpose(0, 2, 1, 3).reshape(self.n, self.n, -1)
        out = np.zeros((self.n, self.n), np.uint8)
        on = (blocks > 0).mean(2) >= keep
        for j, i in zip(*np.nonzero(on)):
            v = blocks[j, i]; v = v[v > 0]
            out[j, i] = np.bincount(v).argmax()
        if outline:
            solid = out > 0
            ring = np.zeros_like(solid)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ring |= np.roll(np.roll(solid, dy, 0), dx, 1)
            out[ring & ~solid] = ci(INK)
        out[(out == 0)] = self.lo[out == 0]
        return out


def rot(pts, a):
    c, s = math.cos(a), math.sin(a)
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


def ngon(cx, cy, r, n, a0=0.0, sq=1.0):
    return [(cx + math.cos(a0 + i * 2 * math.pi / n) * r, cy + math.sin(a0 + i * 2 * math.pi / n) * r * sq) for i in range(n)]


def wake(g, a, length, width, ramp, rng_k, strength=.9, start=0.0):
    """A dithered tail behind a heading: bright at the head, narrowing and thinning toward the end."""
    c, s = math.cos(a), math.sin(a)
    u, v = g.x * c + g.y * s, -g.x * s + g.y * c
    t = (start - u) / length
    wob = np.sin(t * 9 + rng_k * 2.1) * width * .16 * t
    w = width * (1 - t * .8)
    on = (t >= 0) & (t <= 1) & (np.abs(v - wob) <= w)
    heat = (1 - t) * strength * (1 - .45 * np.abs(v - wob) / np.maximum(w, .01))
    on &= heat > g.b * .62
    idx = np.clip((heat * len(ramp)).astype(int), 0, len(ramp) - 1)
    for i, col in enumerate(ramp):
        g.lo[on & (idx == i)] = ci(col)


def orb(g, cx, cy, r, ramp, k=0, sq=1.0):
    d = np.hypot(g.x - cx, (g.y - cy) / sq) / r
    heat = 1.25 - d
    on = d <= 1
    idx = np.clip((heat * len(ramp) + (g.b - .5) * .9).astype(int), 0, len(ramp) - 1)
    for i, col in enumerate(ramp):
        g.lo[on & (idx == i)] = ci(col)


def arrow(g, a, k):
    wake(g, a, 26, 1.1, STEEL[1:], k, .75, -12)
    g.fill(g.mask(rot([(-17, -.9), (12, -.9), (12, .9), (-17, .9)], a)), WOOD, .5)
    for s in (1, -1):
        g.fill(g.mask(rot([(-18, 0), (-21, s * 3.6), (-14, s * 3.4), (-9, 0)], a)), FEATHER, .7)
    g.fill(g.mask(rot([(19, 0), (11, -3.1), (12.5, 0), (11, 3.1)], a)), STEEL, .8)


def spear(g, a, k):
    # 47 units, about the length of the Frostglass Lancer's held spear (director, native review 11-22: 70 read 1.5x too long)
    wake(g, a, 20, 1.4, STEEL[1:], k, .7, -16)
    g.fill(g.mask(rot([(-21, -1.0), (13, -1.0), (13, 1.0), (-21, 1.0)], a)), WOOD, .6)
    g.fill(g.mask(rot([(11, -2.0), (14.5, -2.0), (14.5, 2.0), (11, 2.0)], a)), GOLD, .6)
    g.fill(g.mask(rot([(26, 0), (18.5, -3.6), (14, -1.4), (14, 1.4), (18.5, 3.6)], a)), STEEL, 1.2)


def hook(g, a, k):
    g.fill(g.mask(rot([(-9, -1.4), (3, -1.4), (3, 1.4), (-9, 1.4)], a)), STEEL, .6)
    out = [(3, -2), (8, -5.5), (12, -3.5), (12.5, 1), (9, 5.5), (4.5, 6.5), (6.5, 3.6), (8.6, .4), (7.6, -2), (3, 2)]
    g.fill(g.mask(rot(out, a)), STEEL, .9)


def link(g, a, k):
    flat = k % 2 == 0
    h = 2.6 if flat else 1.1
    g.fill(g.mask(rot([(-4.4, -h * .6), (-3, -h), (3, -h), (4.4, -h * .6), (4.4, h * .6), (3, h), (-3, h), (-4.4, h * .6)], a)), STEEL, .7)
    if flat:
        g.hi[g.mask(rot([(-2.4, -.8), (2.4, -.8), (2.4, .8), (-2.4, .8)], a))] = ci(INK)


def comet_bits(g, a, k, length, width, colours):
    rng = np.random.default_rng(int(a * 100) * 7 + k)
    c, s = math.cos(a), math.sin(a)
    for bit in range(5):
        t, v = rng.uniform(.25, 1.0), rng.uniform(-1, 1) * width * 1.5
        u = -t * length
        px, py = u * c - v * s, u * s + v * c
        g.lo[(np.abs(g.x - px) < .6 / g.q) & (np.abs(g.y - py) < .6 / g.q)] = ci(colours[(k + bit) % 2])


def comet(ramp, r, length, width, sq=1.0):
    def f(g, a, k):
        wake(g, a, length, width, ramp, k, 1.0, r * .4)
        orb(g, 0, 0, r * (1 + .06 * math.sin(k * 2.1)), ramp, k, sq)
        comet_bits(g, a, k, length, width, ramp[2:4])
    return f


def ember(g, a, k):
    wake(g, a, 36, 6.4, FIRE[:4], k, .9, 2)
    upper, lower = (1, 0, .5), (0, 1, .5)
    for side, flicker in ((-1, upper[k]), (1, lower[k])):
        tongue = [(2, side * 4.2), (-14 - 4 * flicker, side * 6.5), (-4, side * .8)]
        g.fill(g.mask(rot(tongue, a)), FIRE[1:4], .8)
    # Resolve the supersampled tongues before painting the cell-based head.
    g.lo = g.resolve(False)
    g.hi.fill(0)
    orb(g, 0, 0, 6.2 * (1 + .05 * math.sin(k * 2.1)), FIRE[1:], k)
    comet_bits(g, a, k, 36, 6.4, FIRE[3:5])


def mitered_fill(g, points, a, tail_width, head_width, colour, pointed=True):
    points = np.asarray(points, dtype=float)
    segments = np.diff(points, axis=0)
    lengths = np.hypot(segments[:, 0], segments[:, 1])
    normals = segments[:, (1, 0)] / lengths[:, None] * (-1, 1)
    distance = np.concatenate(([0], np.cumsum(lengths)))
    widths = tail_width + (head_width - tail_width) * distance / distance[-1]
    offsets = np.zeros_like(points)
    if not pointed:
        offsets[0] = normals[0] * widths[0]
        offsets[-1] = normals[-1] * widths[-1]
    for index, width in enumerate(widths[1:-1], 1):
        bisector = normals[index - 1] + normals[index]
        bisector /= np.linalg.norm(bisector)
        length = min(width / np.dot(bisector, normals[index]), 2 * width)
        offsets[index] = bisector * length
    outline = np.concatenate((points + offsets, (points - offsets)[::-1]))
    g.fill(g.mask(rot(outline, a)), [colour])


def spark(g, a, k):
    wake(g, a, 30, 5.0, BOLT[:3], k, .7, 0)
    paths = (
        ((-30, 0), (-21, 5), (-14, -1), (-5, 6), (3, -2), (16, 0)),
        ((-30, 0), (-22, -5), (-13, 2), (-6, -6), (4, 3), (16, 0)),
        ((-30, 0), (-20, 4), (-12, -4), (-3, 4), (5, -3), (16, 0)),
    )
    points = paths[k]
    mitered_fill(g, points, a, 1.0, 3.6, BOLT[1])
    mitered_fill(g, points, a, .6, 2.4, BOLT[3])
    mitered_fill(g, points[1:], a, .3, 1.0, BOLT[4])
    u, v = points[(2, 3, 1)[k]]
    angle = math.copysign(math.radians(45), -v)
    bend = math.copysign(math.radians(30), v)
    elbow = (u + 6 * math.cos(angle), v + 6 * math.sin(angle))
    tip = (elbow[0] + 5 * math.cos(angle + bend), elbow[1] + 5 * math.sin(angle + bend))
    fork = [(u, v), elbow, tip]
    mitered_fill(g, fork, a, 1.4, .3, BOLT[3])
    mitered_fill(g, fork[:2], a, .5, .5, BOLT[4], pointed=False)
    g.lo = g.resolve(False)
    g.hi.fill(0)
    tip_x, tip_y = rot([(16, 0)], a)[0]
    orb(g, tip_x, tip_y, 4.0, BOLT[2:], k)


def pale(g, a, k):
    wake(g, a, 40, 4.2, PALE, k, .95, 2)
    g.fill(g.mask(rot([(15, 0), (-2, -4.6), (2, 0), (-2, 4.6)], a)), PALE)
    g.fill(g.mask(rot([(15, 0), (0, -2.4), (3, 0), (0, 2.4)], a)), [PALE[4]] * 3)


def sunlance(g, a, k):
    wake(g, a, 44, 6.4, LIGHT, k, .9, -6)
    g.fill(g.mask(rot([(34, 0), (6, -4.4 - .3 * k), (-30, 0), (6, 4.4 + .3 * k)], a)), [LIGHT[2]] * 3)
    g.fill(g.mask(rot([(34, 0), (8, -2.6), (-22, 0), (8, 2.6)], a)), [LIGHT[3]] * 3)
    g.fill(g.mask(rot([(30, 0), (9, -1.2), (-12, 0), (9, 1.2)], a)), [LIGHT[4]] * 3)


def lance(g, a, k):
    wake(g, a, 34, 5.0, ICE, k, .85, -10)
    g.fill(g.mask(rot([(26, 0), (8, -5.2), (-16, -2.6), (-12, 0), (-16, 2.6), (8, 5.2)], a)), ICE[:4], 1.2)
    g.fill(g.mask(rot([(26, 0), (8, -1.6), (-8, 0), (8, 1.2)], a)), [ICE[4]] * 3)
    g.fill(g.mask(rot([(-4, -3.2), (-18, -9), (-10, -1.5)], a)), ICE[1:4], .7)
    g.fill(g.mask(rot([(-4, 3.2), (-18, 9), (-10, 1.5)], a)), ICE[:3], .7)


def needle(g, a, k):
    wake(g, a, 24, 2.2, ICE, k, .85, -6)
    g.fill(g.mask(rot([(14, 0), (2, -2.4), (-10, 0), (2, 2.4)], a)), ICE[1:], .7)


def blade(g, a, k):
    wake(g, a, 26, 11, AIR[:4], k, .5, -2)
    out = [(math.cos(t) * 15 - 6, math.sin(t) * 15) for t in np.linspace(-1.35, 1.35, 15)]
    inn = [(math.cos(t) * 13 - 10.5, math.sin(t) * 13.6) for t in np.linspace(1.3, -1.3, 15)]
    g.fill(g.mask(rot(out + inn, a)), [AIR[3]] * 3)
    out2 = [(math.cos(t) * 15 - 6, math.sin(t) * 15) for t in np.linspace(-1.0, 1.0, 15)]
    inn2 = [(math.cos(t) * 14 - 7.0, math.sin(t) * 14.2) for t in np.linspace(.95, -.95, 15)]
    g.fill(g.mask(rot(out2 + inn2, a)), [AIR[4]] * 3)


def shade(g, a, k):
    """A torn scrap of the Umbra: black body, ragged violet hem streaming back."""
    wake(g, a, 44, 9.0, SHADE[:4], k, .9, 4)
    c, s = math.cos(a), math.sin(a)
    u, v = g.x * c + g.y * s, -g.x * s + g.y * c
    edge = 7.4 + 1.1 * np.sin(u * .5 + k * 2.1) * np.sign(v)
    body = (u <= 11) & (u >= -18) & (np.abs(v) <= np.where(u > 0, edge * np.sqrt(np.clip(1 - (u / 11) ** 2, 0, 1)), edge * (1 + u / 22)))
    rim = body & ~((u <= 9.4) & (np.abs(v) <= np.where(u > 0, (edge - 1.7) * np.sqrt(np.clip(1 - (u / 9.6) ** 2, 0, 1)), (edge - 1.7) * (1 + u / 22))))
    g.lo[body] = ci(SHADE[0])
    g.lo[body & (np.abs(v + 1.4) < 2.0) & (u > -13) & (u < 3) & (g.b > .5)] = ci(SHADE[1])
    g.lo[rim & (u > -11)] = ci(SHADE[3])
    g.lo[rim & (u > 2)] = ci(SHADE[4])


def dust(g, a, k):
    wake(g, a, 38, 8.5, DUST[:4], k, .72, 6)
    rng = np.random.default_rng(90)
    c, s = math.cos(a), math.sin(a)
    for j in range(7):
        u, v, r = rng.uniform(-11, 7), rng.uniform(-5, 5), rng.uniform(3.0, 5.0) * (1 + .08 * math.sin(k * 2.1 + j))
        cx, cy = u * c - v * s, u * s + v * c
        d = np.hypot(g.x - cx, g.y - cy) / r
        lit = -((g.x - cx) * .55 + (g.y - cy) * .83) / r
        on = (d <= .72) | ((d <= 1) & (g.b > .5))
        idx = np.clip((1.9 + lit * 1.5 + (g.b - .5) * .7).astype(int), 0, 4)
        for i, col in enumerate(DUST):
            g.lo[on & (idx == i)] = ci(col)


def knife(g, f):
    a = f * math.pi / 4
    g.fill(g.mask(rot([(-11, -1.4), (-3, -1.4), (-3, 1.4), (-11, 1.4)], a)), WOOD, .6)
    g.fill(g.mask(rot([(-3.4, -3), (-1.8, -3), (-1.8, 3), (-3.4, 3)], a)), GOLD, .5)
    g.fill(g.mask(rot([(13, 0), (7, -2.6), (-2, -2.4), (-2, 1.6), (8, 1.4)], a)), STEEL, .8)


def axe_or_coin(g, f):
    w = abs(math.cos(f * math.pi / 8)) * 8 + 1.6
    edge = [(x + 1.2, y + .6) for x, y in [(math.cos(t) * w, math.sin(t) * 8.4) for t in np.linspace(0, 2 * math.pi, 22)[:-1]]]
    g.fill(g.mask(edge), GOLD[:3], .5)
    face = [(math.cos(t) * w, math.sin(t) * 8.4) for t in np.linspace(0, 2 * math.pi, 22)[:-1]]
    g.fill(g.mask(face), GOLD, 1.0)
    if w > 4:
        g.fill(g.mask([(x * .55, y * .55) for x, y in face]), [GOLD[1]] * 3)
        g.fill(g.mask([(x * .36, y * .36) for x, y in face]), [GOLD[3]] * 3)


def die(g, f):
    a = f * math.pi / 4 * 1.0 + .4
    yaw = f * math.pi / 8
    r = 6.2
    top = rot([(-r, -r), (r, -r), (r, r), (-r, r)], a)
    top = [(x, y * .62 - 4.4) for x, y in top]
    low = [(x, y + 8.6) for x, y in top]
    ys = sorted(range(4), key=lambda i: top[i][1])
    order = sorted(range(4), key=lambda i: top[i][0])
    g.fill(g.mask(top), [BONE[3]] * 3)
    front = [i for i in range(4) if i != ys[0]]
    l, rr = min(front, key=lambda i: top[i][0]), max(front, key=lambda i: top[i][0])
    b = ys[3]
    if b != l:
        g.fill(g.mask([top[l], top[b], low[b], low[l]]), [BONE[2]] * 3)
    if b != rr:
        g.fill(g.mask([top[b], top[rr], low[rr], low[b]]), [BONE[1]] * 3)
    g.fill(g.mask(top), [BONE[3]] * 3)
    for px, py in ([(0, 0)], [(-2.6, -2.6), (2.6, 2.6)], [(-2.6, -2.6), (0, 0), (2.6, 2.6)], [(-2.6, -2.6), (2.6, 2.6), (-2.6, 2.6), (2.6, -2.6)])[f % 4]:
        x, y = rot([(px, py)], a)[0]
        g.hi[g.mask(ngon(x, y * .62 - 4.4, 1.15, 8, 0, .8))] = ci(FEATHER[0])


def net(g, f):
    t = f / 7
    r = 7 + 13 * math.sin(min(1, t * 1.15) * math.pi / 2)
    spin, sq = t * 2.4, .55 + .25 * t
    pt = lambda rr, a: (math.cos(a + spin) * rr, math.sin(a + spin) * rr * sq)
    n = 8
    def line(p, q, w, col):
        d = np.array(q) - np.array(p); L = np.hypot(*d) + 1e-6
        nx, ny = -d[1] / L * w, d[0] / L * w
        g.hi[g.mask([(p[0] + nx, p[1] + ny), (q[0] + nx, q[1] + ny), (q[0] - nx, q[1] - ny), (p[0] - nx, p[1] - ny)])] = ci(col)
    for i in range(n):
        a = i * 2 * math.pi / n
        line((0, 0), pt(r, a), .55, ROPE[1])
        for frac in (.36, .68, 1.0):
            line(pt(r * frac, a), pt(r * frac, a + 2 * math.pi / n), .55, ROPE[2] if frac == 1 else ROPE[1])
    for i in range(n):
        x, y = pt(r + .6, i * 2 * math.pi / n)
        g.fill(g.mask(ngon(x, y, 2.1, 8)), STEEL, .6)


def trap(g, f):
    tilt = .42 + .5 * abs(math.sin(f * math.pi / 8))
    a0 = f * math.pi / 16
    ring = lambda r: [(math.cos(t) * r, math.sin(t) * r * tilt) for t in np.linspace(0, 2 * math.pi, 26)[:-1]]
    for i in range(10):
        a = a0 + i * 2 * math.pi / 10
        p = (math.cos(a) * 10.5, math.sin(a) * 10.5 * tilt)
        g.fill(g.mask([(p[0] - 1.6, p[1]), (p[0] + 1.6, p[1]), (p[0] * .92, p[1] - 6.2)]), STEEL, .6)
    outer, inner = g.mask(ring(12)), g.mask(ring(8.6))
    g.fill(outer & ~inner, STEEL, .8)
    g.fill(g.mask([(x * .34, y * .34) for x, y in ring(12)]), STEEL[:3], .6)


def boulder(r, seed, ramp):
    """A lump with a few flat faces; the faces turn, the light stays upper left."""
    rng = np.random.default_rng(seed)
    n = 10
    base = [(math.cos(t) * r * k, math.sin(t) * r * k) for t, k in zip(np.linspace(0, 2 * math.pi, n + 1)[:-1] + rng.uniform(-.14, .14, n), rng.uniform(.72, 1.1, n))]
    faces = [(rng.uniform(-.55, .55) * r, rng.uniform(-.55, .55) * r, rng.uniform(0, 6.28), rng.uniform(-.25, .5)) for _ in range(5)]
    def f(g, fr):
        a = fr * math.pi / 4
        m = g.mask(rot(base, a))
        yy, xx = np.mgrid[0:g.n * SS, 0:g.n * SS]
        X, Y = ((xx / SS) - g.n / 2) / g.q, ((yy / SS) - g.n / 2) / g.q
        best, lit = np.full(X.shape, 1e9), np.zeros(X.shape)
        for fx, fy, ang, up in faces:
            px, py = rot([(fx, fy)], a)[0]
            d = (X - px) ** 2 + (Y - py) ** 2
            nx, ny = math.cos(ang + a) * (1 - up) * .5 + px / r * 1.2, math.sin(ang + a) * (1 - up) * .5 + py / r * 1.2
            near = d < best
            best[near], lit[near] = d[near], -nx * .55 - ny * .83
        for lo, hi, col in ((-9, -.55, ramp[0]), (-.55, .05, ramp[1]), (.05, .7, ramp[2]), (.7, 9, ramp[3])):
            g.hi[m & (lit >= lo) & (lit < hi)] = ci(col)
        d = int(SS * 1.1)
        g.hi[m & ~np.roll(np.roll(m, -d, 0), -d, 1)] = ci(ramp[0])
    return f


def dropshadow(g, f):
    on = (np.hypot(g.x / 9, g.y / 4.5) <= 1) & (g.b < .6)
    g.lo[on] = ci(SHADOW)


def star(g, r, ramp, sq=1.0):
    if r <= 0:
        return
    d = (np.sqrt(np.abs(g.x)) + np.sqrt(np.abs(g.y) / sq)) / math.sqrt(r)
    for i, lim in ((1, 1.0), (3, .86), (4, .7)):
        g.lo[d <= lim] = ci(ramp[min(i, len(ramp) - 1)])


def bits(g, t, seed, n, v, size, cols, grav=.5, life=8, up=0.0):
    rng = np.random.default_rng(seed)
    for j in range(n):
        a, sp, st = rng.uniform(0, 6.28), rng.uniform(.5, 1) * v, rng.integers(0, 2)
        lf = rng.uniform(.6, 1) * life
        k = t - st
        if k < 0 or k > lf:
            continue
        drag = (1 - .82 ** (k + 1)) / .18
        px, py = math.cos(a) * sp * drag, math.sin(a) * sp * .7 * drag - up * drag + grav * k * k * .5
        r = size * (1 - .45 * k / lf) * rng.uniform(.6, 1.1)
        lean = rng.uniform(.6, 1.6)
        on = (np.abs(g.x - px) <= max(r, .5 / g.q)) & (np.abs(g.y - py) <= max(r * lean, .5 / g.q))
        g.lo[on] = ci(cols[min(len(cols) - 1, int(k / lf * len(cols)))])


def cloud(g, t, seed, n, v, r0, ramp, life=7, rise=.8):
    rng = np.random.default_rng(seed)
    for j in range(n):
        a, sp = 6.28 * j / n + rng.uniform(-.4, .4), rng.uniform(.6, 1) * v
        k = t / life
        if k > 1:
            continue
        drag = (1 - .75 ** (t + 1)) / .25
        px, py = math.cos(a) * sp * drag, math.sin(a) * sp * .7 * drag - rise * t
        r = r0 * rng.uniform(.8, 1.2) * (.7 + .5 * k)
        d = np.hypot(g.x - px, g.y - py) / r
        on = (d <= 1) & (g.b > np.maximum(0, k * 1.25 - .28 + d * .25 * k))
        lit = -((g.x - px) * .55 + (g.y - py) * .83) / r
        idx = np.clip(((1 - k) * (len(ramp) - 1.6) + lit * 1.1 + (g.b - .5) * .6).astype(int), 0, len(ramp) - 1)
        for i, col in enumerate(ramp):
            g.lo[on & (idx == i)] = ci(col)


def hit_spark(g, t):
    star(g, [15, 19, 12, 6, 0, 0, 0, 0][t], [GOLD[0], GOLD[1], GOLD[2], GOLD[3], STEEL[3]])
    bits(g, t, 11, 11, 6.2, 1.3, [GOLD[3], GOLD[2], GOLD[1]], .7, 7)


def hit_glass(g, t):
    star(g, [13, 16, 9, 0, 0, 0, 0, 0][t], ICE)
    cloud(g, t, 21, 6, 2.6, 5.2, ICE[:4], 6, .2)
    bits(g, t, 22, 14, 6.0, 1.9, [ICE[4], ICE[3], ICE[2], ICE[1]], .75, 8)


def hit_flash(g, t):
    r = [12, 17, 19, 20, 20, 0, 0, 0][t]
    if r:
        d = np.hypot(g.x, g.y) / r
        g.lo[(d <= 1) & (g.b > d * (.5 + t * .16) + t * .12 - .2)] = ci(LIGHT[2])
        g.lo[(d <= .62) & (g.b > d * .4 + t * .2 - .25)] = ci(LIGHT[3])
        g.lo[d <= .34 - t * .06] = ci(LIGHT[4])
    star(g, [18, 22, 12, 0, 0, 0, 0, 0][t], LIGHT)
    bits(g, t, 31, 9, 4.4, 1.1, [LIGHT[4], LIGHT[3], LIGHT[2], LIGHT[1]], -.12, 8, .6)


def hit_pale(g, t):
    star(g, [14, 18, 10, 4, 0, 0, 0, 0][t], PALE)
    cloud(g, t, 41, 5, 2.4, 4.6, PALE[:4], 5, .2)
    bits(g, t, 42, 8, 5.0, 1.1, [PALE[4], PALE[3], PALE[2]], .3, 6)


def hit_gloom(g, t):
    cloud(g, t, 51, 8, 3.2, 7.2, SHADE[:4], 8, .9)
    star(g, [11, 14, 8, 0, 0, 0, 0, 0][t], [SHADE[1], SHADE[2], SHADE[3], SHADE[4], SHADE[4]])
    bits(g, t, 52, 9, 5.0, 1.5, [SHADE[4], SHADE[3], SHADE[1]], -.2, 8, .4)


def hit_chips(g, t):
    cloud(g, t, 61, 8, 3.4, 6.6, DUST[:4], 8, .4)
    bits(g, t, 62, 15, 6.4, 1.6, [ROCK[3], ROCK[2], ROCK[1]], .9, 8, 1.2)


def hit_puff(g, t):
    cloud(g, t, 71, 9, 3.0, 6.8, DUST, 8, .7)


def hit_gust(g, t):
    """Three crossing cuts of wind, each drawn through the target and thinning behind its tip."""
    for j, (a, bend, st) in enumerate(((.35, .022, 0), (2.5, -.02, 1), (-1.15, .016, 2))):
        k = t - st
        if not 0 <= k < 5:
            continue
        c, s = math.cos(a), math.sin(a)
        u, v = g.x * c + g.y * s, -g.x * s + g.y * c
        v = v - bend * u * u + 2
        tip, tail = -14 + (k + 1) * 11, -24 + k * 11 + max(0, k - 2) * 3
        pos = np.clip((u - tail) / max(tip - tail, 1), 0, 1)
        w = 2.4 * np.sin(pos * math.pi) ** .6 * (1 - k * .14)
        on = (u >= max(tail, -24)) & (u <= min(tip, 26)) & (np.abs(v) <= w)
        g.lo[on] = ci(AIR[2 if k > 2 else 3])
        g.lo[on & (np.abs(v) <= w * .5) & (pos > .3)] = ci(AIR[4 if k < 3 else 3])
    bits(g, t, 81, 8, 5.2, 1.0, [AIR[4], AIR[3], AIR[2]], -.05, 7)


HIT = {"hit_spark": hit_spark, "hit_glass": hit_glass, "hit_flash": hit_flash, "hit_pale": hit_pale, "hit_gloom": hit_gloom,
       "hit_chips": hit_chips, "hit_puff": hit_puff, "hit_gust": hit_gust}
DIR = {"arrow": (arrow, 46, 1, True), "spear": (spear, 40, 1, True), "hook": (hook, 14, 1, True), "link": (link, 7, 2, True),
       "pale": (pale, 44, 3, False), "light": (comet(LIGHT, 7.0, 40, 6.0), 46, 3, False), "sunlance": (sunlance, 52, 3, False),
       "lance": (lance, 46, 3, False), "needle": (needle, 32, 3, False), "blade": (blade, 30, 3, False),
       "shade": (shade, 46, 3, False), "dust": (dust, 42, 3, False),
       "ember": (ember, 40, 3, False), "spark": (spark, 40, 3, False)}
SPIN = {"knife": (knife, 16, True), "coin": (axe_or_coin, 12, True), "die": (die, 12, True), "net": (net, 25, True), "trap": (trap, 17, True),
        "stone": (boulder(5.6, 4, ROCK), 9, True), "rock": (boulder(11.5, 9, ROCK), 15, True), "shadow": (dropshadow, 11, False)}
APPENDED_HEADINGS = ("ember", "spark")


def heading_block(fn, half, rows, line, q):
    side = Grid(half, q).n
    image = np.zeros((side * rows, side * 32), np.uint8)
    for k in range(rows):
        for column in range(32):
            grid = Grid(half, q)
            fn(grid, column * math.pi / 16, k)
            image[k * side:(k + 1) * side, column * side:(column + 1) * side] = grid.resolve(line)
    return image, side


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/art/effects/shots"); out.mkdir(parents=True, exist_ok=True)
    meta = {"headings": 32, "flicker_fps": 12, "spin_fps": 18, "hit_fps": 30, "sizes": []}
    for size in SIZES:
        q = size / 85.0
        blocks, y, width, shots = [], 0, 0, {}
        for name, (fn, half, rows, line) in DIR.items():
            if name in APPENDED_HEADINGS:
                continue
            img, probe = heading_block(fn, half, rows, line, q)
            shots[name] = {"kind": "heading", "frame_cells": probe, "y": y, "rows": rows}
            blocks.append(img); y += img.shape[0]; width = max(width, img.shape[1])
        for name, (fn, half, line) in SPIN.items():
            probe = Grid(half, q).n
            img = np.zeros((probe, probe * 8), np.uint8)
            for c in range(8):
                g = Grid(half, q); fn(g, c); img[:, c * probe:(c + 1) * probe] = g.resolve(line, .36 if name == "net" else .42)
            shots[name] = {"kind": "progress" if name == "net" else "still" if name == "shadow" else "spin", "frame_cells": probe, "y": y, "rows": 1}
            blocks.append(img); y += img.shape[0]; width = max(width, img.shape[1])
        for name, fn in HIT.items():
            probe = Grid(30, q).n
            img = np.zeros((probe, probe * 8), np.uint8)
            for c in range(8):
                g = Grid(30, q); fn(g, c); img[:, c * probe:(c + 1) * probe] = g.resolve(False)
            shots[name] = {"kind": "hit", "frame_cells": probe, "y": y, "rows": 1}
            blocks.append(img); y += img.shape[0]; width = max(width, img.shape[1])
        # Append new regions to keep existing frame coordinates and palette indices.
        for name in APPENDED_HEADINGS:
            fn, half, rows, line = DIR[name]
            img, probe = heading_block(fn, half, rows, line, q)
            shots[name] = {"kind": "heading", "frame_cells": probe, "y": y, "rows": rows}
            blocks.append(img); y += img.shape[0]; width = max(width, img.shape[1])
        sheet = np.zeros((y, width), np.uint8)
        yy = 0
        for b in blocks:
            sheet[yy:yy + b.shape[0], :b.shape[1]] = b; yy += b.shape[0]
        Image.fromarray(sheet).save(out / f"shot_{size}.png", optimize=True)
        meta["sizes"].append({"tile_cells": size, "atlas": f"shot_{size}.png", "shots": shots, "sha256_pixels": hashlib.sha256(sheet.tobytes()).hexdigest()})
        print(f"shot_{size}.png", sheet.shape, (out / f"shot_{size}.png").stat().st_size // 1024, "KB")
    meta["palette"] = ["%02x%02x%02x%02x" % p for p in PALETTE]
    (out / "shot_atlas.json").write_text(json.dumps(meta, indent=1) + "\n")
    print(len(PALETTE), "colours")


if __name__ == "__main__":
    main()

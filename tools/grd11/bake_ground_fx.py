"""Bakes the Fire and Electrified ground sheets (director-owned art; deterministic, numpy + PIL only).

Fire is a periodic cooling-map flame simulation on several depth curtains of the tile diamond. Electrified is a set of
branching discharges. One cell is one pixel-FX cell (2 framebuffer pixels at 1080p). Rooms draw their tiles at many widths, so the
same rows are baked for each tile width in SIZES; the player picks the nearest one and never scales a cell.
Usage: python3 tools/grd11/bake_ground_fx.py [out_dir]
"""
import json, math, sys, hashlib
from pathlib import Path
import numpy as np
from PIL import Image

N, SUB = 16, 3
P = N * SUB
SIZES = [44, 52, 60, 68, 76, 84, 92]   # tile widths in cells


def use(size):
    """Set the frame geometry for one tile width."""
    global Q, FW, FH, CX, CY, HW, HH
    Q = size / 85.0
    HW, HH = size / 2, size / 4             # tile diamond half extents
    FW, FH = size + 12, int(round(76 * Q / 2)) * 2 + 4   # frame size in cells
    CX, CY = FW // 2, int(round(54 * Q)) + 2              # tile centre inside a frame


use(84)
FIRE = [(0x3a, 0x12, 0x08), (0x8a, 0x2a, 0x10), (0xd0, 0x58, 0x1c), (0xf2, 0x9a, 0x3a), (0xff, 0xd9, 0x8a)]
BOLT = [(0x2a, 0x1a, 0x4a), (0x5a, 0x3a, 0x9a), (0x9a, 0x7a, 0xe0), (0xd0, 0xc0, 0xff), (0xff, 0xff, 0xff)]
THRESHOLDS = [0.16, 0.30, 0.48, 0.72]


# ---- fire -----------------------------------------------------------------------------------------------------------
def smooth(a, k):
    for _ in range(k):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5
    return a


def norm(a):
    return (a - a.min()) / (a.max() - a.min())


def simulate(seed, w, h, source, cool, contrast=1.6):
    rng = np.random.default_rng(seed)
    c, c2 = norm(smooth(rng.random((P, w)), 4)), norm(smooth(rng.random((P, w)), 1))
    cm = np.clip((c * 0.75 + c2 * 0.25 - 0.5) * contrast + 0.5, 0, 1) * cool
    b = np.zeros((h + 2, w))
    frames = []
    for step in range(P * 4):
        s = step % P
        b[h] = source(s / P)
        b[h + 1] = b[h]
        up1, up2 = b[1:h + 1].copy(), b[2:h + 2].copy()
        new = (up1 * 1.35 + np.roll(up1, 1, 1) * 0.75 + np.roll(up1, -1, 1) * 0.75 + up2 * 1.15) / 4.0 - cm[(np.arange(h) + s) % P]
        b[:h] = np.clip(new, 0, 1)
        if step >= P * 3 and s % SUB == 0:
            frames.append(b[:h].copy())
    return frames


def curtain(seed, base, x0, x1, cool, tongues):
    x0, x1, cool = int(round(x0 * Q)), int(round(x1 * Q)), cool / Q
    tongues = [(cx * Q, max(2.6, ww * Q), a) for cx, ww, a in tongues]
    w, h = x1 - x0 + 12, int(round(56 * Q))
    x = np.arange(w) - 6 + x0 + 0.5
    rng = np.random.default_rng(seed + 999)
    amp = [(cx, ww, a, int(rng.integers(1, 3)), rng.random()) for cx, ww, a in tongues]

    def source(t):
        s = np.zeros(w)
        for cx, ww, a, n, ph in amp:
            s = np.maximum(s, a * (0.86 + 0.14 * math.sin(2 * math.pi * (n * t + ph))) * np.exp(-((x - cx) / ww) ** 2))
        return np.clip(s, 0, 1)

    out = []
    for f in simulate(seed, w, h, source, cool):
        g = np.zeros((FH, FW))
        for i in range(w):
            col = int(round(x[i] - 0.5)) + CX
            yb = int(round(CY + base(x[i])))
            if 0 <= col < FW:
                for j in range(h):
                    yy = yb - (h - 1 - j)
                    if 0 <= yy < FH:
                        g[yy, col] = f[j, i]
        out.append(g)
    return out


def paint(layers):
    out = []
    for k in range(N):
        o = np.zeros((FH, FW, 4), np.uint8)
        for layer in layers:
            g = layer[k]
            on = g > THRESHOLDS[0]
            a = np.pad(on.astype(int), 1)
            nb = sum(a[1 + dy:FH + 1 + dy, 1 + dx:FW + 1 + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
            on &= nb >= 2
            idx = np.digitize(g, THRESHOLDS[1:])
            for i in range(4):
                o[on & (idx == i)] = FIRE[i + 1] + (255,)
        out.append(o)
    return out


def vee(f, g):
    return lambda x: HH * f * max(0.0, 1 - abs(x) / (HW * g))


def fire(seed, mirror, low):
    k, a = (2.0, 0.90) if low else (1.0, 1.0)
    m = lambda ts: [((-cx if mirror else cx), w, amp * a) for cx, w, amp in ts]
    rear = [curtain(seed + 3, vee(-.72, .74), -31, 31, .078 * k, m([(-22, 6, .95), (-8, 6, .9), (11, 8, 1), (25, 5, .85)])),
            curtain(seed + 4, vee(-.28, .8), -35, 35, .100 * k, m([(-32, 4, .9), (-18, 6, 1), (3, 5, .75), (21, 6, .95), (33, 3.5, .85)]))]
    front = [curtain(seed + 6, vee(.12, .8), -35, 35, .090 * k, m([(-31, 4, .85), (-15, 4.5, 1), (30, 4.5, .95)])),
             curtain(seed + 7, vee(.46, .8), -34, 34, .100 * k, m([(-24, 5, .9), (-5, 5, 1), (19, 5.5, 1)])),
             curtain(seed + 8, vee(.80, .80), -32, 32, .130 * k, m([(-18, 6, .95), (0, 4.5, .9), (12, 5, 1)]))]
    return paint(rear), paint(front)


# ---- lightning ------------------------------------------------------------------------------------------------------
def line(p, q):
    x0, y0, x1, y1 = [int(round(v)) for v in (*p, *q)]
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return [(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n))) for i in range(n + 1)]


def inside(x, y, k=.93):
    return abs(x) / HW + abs(y) / HH <= k


def tree(rng, p, heading, length, iso, depth=0, wander=.85, bounded=True, goal=None):
    segs, cells, left, p, side = [], [], length, np.array(p, float), rng.choice([-1, 1])
    while left > 0:
        st = min(left, rng.uniform(2.6, 5.2))
        if goal is not None:
            g = np.array(goal, float) - p
            heading = math.atan2(g[1] / iso, g[0])
        side = -side if rng.random() < .8 else side
        for s in (side, -side):
            a = heading + s * rng.uniform(.25, wander)
            q = p + np.array([math.cos(a) * st, math.sin(a) * st * iso])
            if not bounded or inside(*q):
                break
        else:
            break
        cells += line(p, q)
        if depth < 2 and rng.random() < (.36 if depth == 0 else .16):
            segs += tree(rng, q, heading - side * rng.uniform(.6, 1.15), left * rng.uniform(.25, .5) + 2, iso, depth + 1, wander, bounded)
        p, left = q, left - st
        if goal is not None and np.linalg.norm((np.array(goal) - p) * [1, 1 / iso]) < 4:
            cells += line(p, goal)
            break
    return [(cells, depth)] + segs


class Discharge:
    def __init__(self, seed, start, p, goal=None, heading=0.0, length=40, iso=.5, bounded=True, wander=.85):
        self.start = start
        p, goal, length = (p[0] * Q, p[1] * Q), goal and (goal[0] * Q, goal[1] * Q), length * Q
        self.paths = [tree(np.random.default_rng(seed + k), p, heading, length, iso, 0, wander, bounded, goal) for k in (0, 100)]

    def draw(self, buf, frame):
        age = (frame - self.start) % N
        if age > 3:
            return

        def put(x, y, pr):
            X, Y = x + CX, y + CY
            if 0 <= X < FW and 0 <= Y < FH and pr > buf[Y, X]:
                buf[Y, X] = pr

        for cells, d in self.paths[0 if age < 1 else 1]:
            for i, (x, y) in enumerate(cells):
                if age == 0:
                    put(x, y, 5 if d < 2 else 4)
                    if d == 0:
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            put(x + dx, y + dy, 3)
                        if i % 2 == 0:
                            for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
                                put(x + dx, y + dy, 2)
                    else:
                        for dx, dy in ((1, 0), (0, 1)):
                            put(x + dx, y + dy, 2)
                elif age == 1:
                    put(x, y, 5 if d == 0 else 4)
                    if d == 0 and i % 2:
                        put(x, y + 1, 2)
                        put(x + 1, y, 2)
                elif age == 2:
                    if d == 0:
                        put(x, y, 4 if (i // 5) % 3 else 3)
                    elif (i // 3) % 2:
                        put(x, y, 3)
                elif d == 0 and (i // 3) % 3 == 0:
                    put(x, y, 3 if i % 2 else 2)


def bolts(events):
    out = []
    for f in range(N):
        buf = np.zeros((FH, FW), int)
        for e in events:
            e.draw(buf, f)
        o = np.zeros((FH, FW, 4), np.uint8)
        for pr, c in ((2, 1), (3, 2), (4, 3), (5, 4)):
            o[buf == pr] = BOLT[c] + (255,)
        out.append(o)
    return out


def electric(s, m):
    x = lambda v: -v if m else v
    D = Discharge
    rear = [D(s + 1, 0, (x(-33), -1), (x(4), -17)), D(s + 2, 5, (x(33), -1), (x(-8), -14)),
            D(s + 3, 9, (x(-10), -13), (x(30), -3)), D(s + 4, 13, (x(-30), 1), (x(-6), -12))]
    ground = [D(s + 11, 2, (x(-34), 2), (x(6), 16)), D(s + 12, 7, (x(34), 2), (x(-9), 14)), D(s + 13, 11, (x(-16), 10), (x(30), 5))]
    climb = [D(s + 14, 4, (x(8), 13), None, -math.pi / 2, 24, 1, False, .7), D(s + 15, 14, (x(-14), 9), None, -math.pi / 2 + .2, 19, 1, False, .7)]
    storm_rear = [D(s + 21, 3, (x(-30), -2), (x(8), -15)), D(s + 23, 12, (x(31), -2), (x(2), -15))]
    storm_front = [D(s + 22, 8, (x(-28), 5), (x(20), 11)), D(s + 24, 0, (x(10), 13), None, -math.pi / 2, 22, 1, False, .7)]
    return {"rear": bolts(rear), "front": bolts(ground + climb), "front_quiet": bolts(ground),
            "storm_rear": bolts(storm_rear), "storm_front": bolts(storm_front)}


def rows():
    out = []
    for v, (seed, mirror) in enumerate(((0, False), (400, True))):
        for low in (False, True):
            r, f = fire(seed, mirror, low)
            out += [("fire_%s_rear_%d" % ("low" if low else "full", v), r), ("fire_%s_front_%d" % ("low" if low else "full", v), f)]
        for name, fr in electric(40 + v * 900, mirror).items():
            out.append(("electrified_%s_%d" % (name, v), fr))
    return out


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    meta = {"frames": N, "fps": 12, "palette": [], "rows": {}, "sizes": []}
    palette = {}                              # RGBA -> index; 0 is empty
    for size in SIZES:
        use(size)
        table = rows()
        atlas = Image.new("RGBA", (FW * N, FH * len(table)))
        for y, (name, frames) in enumerate(table):
            meta["rows"][name] = y
            for i, fr in enumerate(frames):
                atlas.paste(Image.fromarray(fr), (i * FW, y * FH))
        # One byte per cell: palette index, 0 empty.
        px = np.asarray(atlas)
        index = np.zeros(px.shape[:2], np.uint8)
        for colour in sorted(c for _, c in atlas.getcolors(1 << 16) if c[3]):
            index[(px == colour).all(axis=2)] = palette.setdefault(colour, len(palette) + 1)
        atlas = Image.fromarray(index)
        name = "ground_fx_%02d.png" % size
        atlas.save(out / name, optimize=True)
        meta["sizes"].append({"tile_cells": [size, size / 2], "frame_cells": [FW, FH], "tile_centre_cell": [CX, CY], "atlas": name,
                              "sha256_pixels": hashlib.sha256(atlas.tobytes()).hexdigest()})
        print(name, atlas.size, (out / name).stat().st_size // 1024, "KB", len(table), "rows")
    meta["palette"] = ["00000000"] + ["%02x%02x%02x%02x" % c for c in palette]
    (out / "ground_fx_atlas.json").write_text(json.dumps(meta, indent=1) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "tools/grd11/out"))

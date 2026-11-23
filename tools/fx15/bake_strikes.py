"""Bakes the vertical strikes that fall onto a tile from above (director-owned art; numpy + PIL only).

Same raster model as tools/fx12/bake_tile_bursts.py (whose helpers it reuses): one cell is one pixel-FX cell, shapes
are authored for an 85-unit tile and rasterised at each tile width in SIZES, one byte per cell (palette index, 0 empty).
Frames are tall: the strike starts well above the tile and lands on its centre. One row per strike, drawn on the
target tile's front layer. Each strike's contact frame is where the tile burst (fx-12) takes over the impact.
Usage: python3 tools/fx15/bake_strikes.py [out_dir] [data_json]   (defaults: assets/art/effects/strikes, data/strikes.json)
"""
import hashlib, importlib.util, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image

_spec = importlib.util.spec_from_file_location("fx12bake", Path(__file__).resolve().parents[1] / "fx12" / "bake_tile_bursts.py")
B = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(B)

FPS = 30
SIZES = B.SIZES
TOP, SIDE, BOTTOM = 268.0, 56.0, 26.0          # authored extents above, beside and below the tile centre
FIRE, SMOKE, EARTH, ICE, BOLT = B.FIRE, B.SMOKE, B.EARTH, B.ICE, B.BOLT
ROCK = [(0x1a, 0x12, 0x10), (0x33, 0x25, 0x1e), (0x52, 0x3c, 0x2e), (0x74, 0x58, 0x42)]


def use(size):
    """Tall raster for one tile width; sets the fx-12 module's globals so its helpers draw into it."""
    B.Q, B.CELL = size / 85.0, 85.0 / size
    B.CX, B.CY = int(math.ceil(SIDE * B.Q)) + 1, int(math.ceil(TOP * B.Q)) + 1
    B.FW, B.FH = B.CX * 2, B.CY + int(math.ceil(BOTTOM * B.Q)) + 1
    yy, xx = np.mgrid[0:B.FH, 0:B.FW]
    B.X, B.Y = (xx - B.CX + .5) * B.CELL, (yy - B.CY + .5) * B.CELL
    B.DITHER = B.BAYER[yy % 4, xx % 4]


def paint(buf):
    o = B.blank()
    for pr, c in ((2, 1), (3, 2), (4, 3), (5, 4)):
        B.put(o, buf == pr, BOLT[c])
    return o


# ---- lightning: a stepped leader, the return stroke on contact, one re-strike, then broken afterglow ---------------
def strike_tree(rng, p, heading, length, depth=0, goal=None):
    """A jagged downward path in cells with a few sparse forks; forks stay inside the frame and point down."""
    segs, cells, left, p = [], [], length, np.array(p, float)
    side, lim = rng.choice([-1, 1]), B.CX - 3
    while left > 0:
        st = min(left, rng.uniform(3.0, 6.5))
        h = heading
        if goal is not None:
            g = np.array(goal, float) - p
            h = math.atan2(g[1], g[0])
        side = -side if rng.random() < .75 else side
        a = h + side * rng.uniform(.2, .75)
        q = p + np.array([math.cos(a) * st, math.sin(a) * st])
        if abs(q[0]) > lim or q[1] > B.FH - B.CY - 2:
            break
        cells += B.line(p, q)
        fork = (.075 if depth == 0 else .05) if p[1] < -30 * B.Q else 0
        if depth < 2 and rng.random() < fork:
            down = math.pi / 2 + rng.choice([-1, 1]) * rng.uniform(.55, .95)
            segs += strike_tree(rng, q, down, left * rng.uniform(.18, .34) + 3, depth + 1)
        p, left = q, left - st
        if goal is not None and np.linalg.norm(np.array(goal) - p) < 4:
            cells += B.line(p, goal)
            break
    return [(cells, depth)] + segs


def lightning():
    Q = B.Q
    trunk = strike_tree(np.random.default_rng(1503), (6 * Q, -TOP * Q + 2), math.pi / 2, 400 * Q, 0, (0, -2 * Q))
    main = trunk[0]
    frames = []
    for k in range(9):
        buf = np.zeros((B.FH, B.FW), int)
        if k in (0, 1):                                   # leader: thin, faint, reaching down
            cells = main[0][: int(len(main[0]) * (.5 if k == 0 else .92))]
            for x, y in cells[:: 2 if k else 3]:
                xx, yy = x + B.CX, y + B.CY
                if 0 <= xx < B.FW and 0 <= yy < B.FH:
                    buf[yy, xx] = max(buf[yy, xx], 3 if k else 2)
        elif k in (2, 4):                                 # return stroke and re-strike
            B.bolt(buf, trunk, 0, True)
        elif k == 3:
            B.bolt(buf, trunk, 1)
        elif k == 5:
            B.bolt(buf, trunk, 2)
        elif k == 6:
            B.bolt(buf, trunk, 3)
        img = paint(buf)
        if k >= 6:                                        # a few cooling glints along the lower trunk
            rng = np.random.default_rng(1600 + k)
            lower = [c for c in main[0] if c[1] > -90 * Q]
            for i in rng.choice(len(lower), max(0, min(len(lower), 7 - (k - 6) * 3)), replace=False):
                x, y = lower[i]
                xx, yy = x + B.CX, y + B.CY
                if 0 <= xx < B.FW and 0 <= yy < B.FH:
                    img[yy, xx] = BOLT[3 if k < 8 else 2] + (255,)
        frames.append(img)
    return frames, 2


# ---- meteor: a burning rock falling in from the upper left with a flame trail ---------------------------------------
def blob(cx, cy, radius, seed):
    rng = np.random.default_rng(seed)
    a = np.arctan2(B.Y - cy, B.X - cx)
    r = np.hypot(B.X - cx, B.Y - cy)
    edge = np.full_like(a, radius)
    for f, amp in ((3, .13), (5, .08), (7, .05)):
        edge = edge * (1 + amp * np.cos(f * a + rng.uniform(0, 6.28)))
    return r <= edge, r / edge


def meteor():
    N, contact = 10, 6
    start, end = np.array([-40.0, -205.0]), np.array([0.0, -11.0])
    d = (end - start) / np.linalg.norm(end - start)
    n = np.array([-d[1], d[0]])
    R = 13.5
    pos = [start + (end - start) * (k / contact) ** 1.2 for k in range(contact + 1)]
    frames = []
    for k in range(N):
        img = B.blank()
        head = pos[min(k, contact)]
        # trail: a tapered dithered flame band behind the rock, cooling to smoke at its tail
        length = 46 + 18 * min(k, contact) if k <= contact else 46 + 18 * contact
        fade = 1.0 if k < contact else max(0.0, 1 - (k - contact + 1) / (N - contact))
        rel = np.stack([B.X - head[0], B.Y - head[1]])
        along = -(rel[0] * d[0] + rel[1] * d[1])          # distance behind the head
        off = np.abs(rel[0] * n[0] + rel[1] * n[1])
        s = np.clip(along / length, 0, 1)
        width = R * (1.0 - .82 * s) * (1.05 + .1 * np.sin(along * .45 + k * 1.7))
        band = (along > -R * .4) & (along < length) & (off < width)
        heat = np.clip((1 - s) * 1.15 - off / np.maximum(width, 1e-6) * .45, 0, 1) * fade
        dens = np.clip(1.25 - s * 1.1, 0, 1) * (fade if k >= contact else 1)
        on = band & B.dith(dens)
        idx = np.clip((heat * 6).astype(int), 0, 5)
        cols = [SMOKE[1], SMOKE[3], FIRE[1], FIRE[2], FIRE[3], FIRE[4]]
        if k >= contact:
            cols = [SMOKE[1], SMOKE[2], SMOKE[3], FIRE[1], FIRE[2], FIRE[3]]
        for i in range(6):
            B.put(img, on & (idx == i), cols[i])
        if k < contact:
            body, rr = blob(head[0], head[1], R, 1700)
            light = ((B.X - head[0]) * -.55 + (B.Y - head[1]) * -.75) / R      # lit from the upper left
            front = ((B.X - head[0]) * d[0] + (B.Y - head[1]) * d[1]) / R       # leading face, toward the ground
            tone = np.clip((light * .5 + .5) * 4, 0, 3.99).astype(int)
            for i in range(4):
                B.put(img, body & (tone == i), ROCK[i])
            B.put(img, body & (front > .25) & (rr > .55), FIRE[2])
            B.put(img, body & (front > .45) & (rr > .7), FIRE[3])
            B.put(img, body & (front > .62) & (rr > .82), FIRE[4])
            for j, (ox, oy, ang, l) in enumerate(((.25, .2, -.5, .55), (-.15, .5, .35, .4))):   # molten seams on the leading face
                for t in np.linspace(0, l, 22):
                    x = head[0] + (ox + math.cos(ang) * t) * R + math.sin(t * 19 + j * 2) * .9
                    y = head[1] + (oy + math.sin(ang) * t) * R
                    xx, yy = int(round(x * B.Q)) + B.CX, int(round(y * B.Q)) + B.CY
                    if 0 <= xx < B.FW and 0 <= yy < B.FH and img[yy, xx, 3]:
                        img[yy, xx] = FIRE[3 if t < l * .6 else 2] + (255,)
            B.put(img, body & (rr > .93) & (light < -.2), ROCK[0])
        frames.append(img)
    return frames, contact


# ---- ice spear: a faceted crystal dropped straight down, standing a beat, then shattering -----------------------------
def spear_mask(tip, L, W, jag_seed):
    """Spear body for a tip at (0, tip): a long point, a straight shaft and a broken, jagged butt; plus the facet coordinate."""
    y = B.Y
    t = (tip - y) / L                                         # 0 at the tip, 1 at the butt
    half = W * np.clip(np.where(t < .34, t / .34, 1.0 - (t - .34) * .25), 0, 1)
    rng = np.random.default_rng(jag_seed)
    teeth = rng.uniform(.0, .09, 7)
    butt = 1.0 - np.interp(B.X / max(W, 1e-6), np.linspace(-1, 1, 7), teeth)
    body = (t >= 0) & (t <= butt) & (np.abs(B.X) <= half)
    return body, B.X / np.maximum(half, 1e-6), t


def shade_spear(img, body, u, t):
    B.put(img, body, ICE[1])                                  # right face
    B.put(img, body & (u < .1), ICE[3])                        # left face, lit from the upper left
    B.put(img, body & (np.abs(u - .1) < .14), ICE[4])          # ridge
    B.put(img, body & (u > .78), ICE[0])                       # shadow edge
    B.put(img, body & (u < -.8), ICE[2])                       # rim
    B.put(img, body & (t > .9) & (u > .1), ICE[2])             # broken end catches light


def ice_spear():
    N, contact = 10, 4
    L, W = 100.0, 8.5
    tips = [-150.0, -122.0, -84.0, -36.0, 3.0, 3.0, 3.0, 3.0]
    frames = []
    rng = np.random.default_rng(1800)
    chips = [B.Chip(rng.uniform(-7, 7), -rng.uniform(25, 95), rng.uniform(-3.2, 3.2), rng.uniform(-3.0, -.5), 7, int(rng.integers(3, 5)),
                    [ICE[1], ICE[3], ICE[4]], int(rng.integers(1, 3)), .8) for _ in range(12)]
    for k in range(N):
        img = B.blank()
        if k < len(tips):
            tip = tips[k]
            if k >= 1 and k <= contact:                       # motion smear: the spear's own shape, dithered, behind it
                prev = tips[k - 1]
                for back in np.linspace(.15, 1.0, 6):
                    ghost, gu, gt = spear_mask(tip - (tip - prev) * back, L, W * (1 - .45 * back), 1800)
                    B.put(img, ghost & ~img[..., 3].astype(bool) & B.dith(np.full_like(B.X, .55 * (1 - back))), ICE[2])
            body, u, t = spear_mask(tip, L, W, 1800)
            if k == 0:                                        # forming: frost gathers into the spear
                body &= B.dith(np.full_like(B.X, .55))
            if k == 7:                                        # breaking: only the planted half is left
                body &= t < .45
            shade_spear(img, body, u, t)
            if k == 6:                                        # cracks run up the shaft before it breaks
                for j, (x0, y0) in enumerate(((-2.0, -30.0), (2.5, -55.0), (-1.0, -78.0))):
                    for i in range(9):
                        x, y = x0 + (i % 3 - 1) * .8 + j * .3, y0 + i * 1.4
                        xx, yy = int(round(x * B.Q)) + B.CX, int(round(y * B.Q)) + B.CY
                        if 0 <= xx < B.FW and 0 <= yy < B.FH and img[yy, xx, 3]:
                            img[yy, xx] = ICE[4] + (255,)
        for c in chips:
            c.draw(img, k)
        frames.append(img)
    return frames, contact


STRIKES = {"lightning": lightning, "meteor": meteor, "ice_spear": ice_spear}


FRAMES = 10
STRIKE_FOR_ELEMENT = {"lightning": "lightning", "fire": "meteor", "ice": "ice_spear"}


def main(out, data_path):
    """Writes strike_NN.png into out and the strike catalogue (data/strikes.json format) to data_path."""
    out.mkdir(parents=True, exist_ok=True)
    meta = {"frames": FRAMES, "fps": FPS, "contact_frame": {}, "strike_for_element": STRIKE_FOR_ELEMENT,
            "reduced_motion_seconds": 0.18, "palette": [], "rows": {}, "sizes": []}
    palette = {}
    for size in SIZES:
        use(size)
        rows = []
        for name, fn in STRIKES.items():
            frames, contact = fn()
            frames = (frames + [B.blank()] * FRAMES)[:FRAMES]
            meta["contact_frame"][name] = contact
            meta["rows"][name + "_front"] = len(rows)
            rows.append(frames)
        sheet = np.zeros((B.FH * len(rows), B.FW * FRAMES), np.uint8)
        for y, frames in enumerate(rows):
            for i, px in enumerate(frames):
                cell = sheet[y * B.FH:(y + 1) * B.FH, i * B.FW:(i + 1) * B.FW]
                for c in sorted({tuple(int(q) for q in v) for v in np.unique(px[px[..., 3] > 0], axis=0)}):
                    cell[(px == c).all(axis=2)] = palette.setdefault(c, len(palette) + 1)
        name = "strike_%02d.png" % size
        Image.fromarray(sheet).save(out / name, optimize=True)
        meta["sizes"].append({"tile_cells": [size, size / 2], "frame_cells": [B.FW, B.FH], "tile_centre_cell": [B.CX, B.CY],
                              "atlas": "res://assets/art/effects/strikes/" + name, "sha256_pixels": hashlib.sha256(sheet.tobytes()).hexdigest()})
        print(name, sheet.shape[::-1], (out / name).stat().st_size // 1024, "KB", len(palette), "colours")
    meta["palette"] = ["00000000"] + ["%02x%02x%02x%02x" % c for c in palette]
    Path(data_path).write_text(json.dumps(meta, indent=1) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "assets/art/effects/strikes"), sys.argv[2] if len(sys.argv) > 2 else "data/strikes.json")

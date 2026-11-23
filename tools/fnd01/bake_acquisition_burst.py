"""Bakes the light burst behind a found item, piece of gear or card (director-owned art; numpy + PIL only).

One cell is one pixel-FX cell. Every radius in RADII is rasterised from the same authored shape (R = 100), so a cell is
never scaled; the player picks the sheet nearest to the radius it needs. One byte per cell: 0 empty, 1..5 = deep, dark,
mid, light, hot, coloured at draw time from the rarity accent. Frame 0 is the pickup.
Usage: python3 tools/fnd01/bake_acquisition_burst.py [out_dir]
"""
import hashlib, json, math, sys
from pathlib import Path
import numpy as np
from PIL import Image

N, FPS = 16, 30
RADII = [48, 60, 72, 88, 104, 124, 148, 176, 208]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32
DEEP, DARK, MID, LIGHT, HOT = 1, 2, 3, 4, 5


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def ease(t):
    return 1 - (1 - clamp(t)) ** 3


def rays(seed=41):
    """Angle, length share, half width (radians), start frame: long and short rays alternate, none evenly spaced."""
    rng = np.random.default_rng(seed)
    out = []
    n = 16
    for i in range(n):
        long = i % 2 == 0
        a = 2 * math.pi * (i + rng.uniform(-.22, .22)) / n + .1
        out.append((a, rng.uniform(.86, 1.0) if long else rng.uniform(.52, .68), rng.uniform(.085, .115) if long else rng.uniform(.055, .08),
                    0 if long else 1, rng.uniform(-.2, .2)))
    return out


RAYS = rays()


def sparks(seed=77):
    rng = np.random.default_rng(seed)
    out = []
    n = 13
    for i in range(n):
        a = 2 * math.pi * (i + rng.uniform(-.3, .3)) / n
        out.append((a, rng.uniform(.5, .74), rng.uniform(.12, .22), int(rng.integers(3, 9)), int(rng.integers(6, 8)), int(rng.integers(3, 6)), rng.uniform(-.12, .12)))
    return out


SPARKS = sparks()


def frame(k, radius):
    R = radius
    size = radius * 2
    yy, xx = np.mgrid[0:size, 0:size]
    X, Y = xx - R + .5, yy - R + .5
    D = BAYER[yy % 4, xx % 4]
    r = np.hypot(X, Y) / R                       # 0..1
    th = np.arctan2(Y, X)
    img = np.zeros((size, size), np.uint8)
    cell = 1.0 / R                               # one cell in authored units

    # Glow: a dithered disc that swells with the pop and is gone by frame 6. It reads as light, not as a shape.
    if k <= 6:
        g = [.34, .56, .60, .56, .50, .42, .34][k]
        s = [1.15, 1.1, .85, .62, .45, .30, .16][k]
        dens = np.clip((1 - r / g) * 1.5, 0, 1) * s
        img[dens > D] = DARK
        img[dens * .62 > D] = MID
        if k <= 3:
            img[dens * .36 > D] = LIGHT

    # Rays.
    for a, length, half, start, sway in RAYS:
        t = k - start
        if t < 0:
            continue
        grow = ease(t / 4.0)
        out = clamp((t - 4) / 7.0)               # the ray leaves the middle and thins
        if out >= 1:
            continue
        rot = a + .018 * k + sway * out * .25
        d = (th - rot + math.pi) % (2 * math.pi) - math.pi
        tip = length * (.28 + .72 * grow) * (1 + .06 * out)
        base = .06 + out ** .8 * (tip - .06) * .88
        along = (r - base) / max(1e-6, tip - base)
        inside = (along >= 0) & (along <= 1)
        # Widest a third of the way along, pointed at both ends.
        taper = np.where(along < .3, along / .3, (1 - along) / .7)
        width = half * (1 - .72 * out) * np.clip(taper, 0, 1)
        across = np.abs(d) * r                   # arc distance in authored units
        wmax = np.maximum(width * .62, 0)
        body = inside & (across <= np.maximum(wmax, cell * .5)) & (np.clip(taper, 0, 1) > .02)
        rim = inside & (across <= wmax + cell * 1.05) & ~body & (np.clip(taper, 0, 1) > .05)
        keep = (1.0 if out < .8 else .55) > D
        img[rim & keep & (img < MID)] = DARK
        img[body & keep] = np.maximum(img[body & keep], MID)
        core = body & (across <= np.maximum(wmax * .55, cell * .5))
        img[core & keep] = np.maximum(img[core & keep], LIGHT)
        if t <= 5:
            hot = body & (across <= np.maximum(wmax * .30, cell * .5)) & (along < .72 - .10 * t)
            img[hot & keep] = HOT

    # Pop: a hard white-hot star with a bright rim, two frames and a fading third.
    if k <= 2:
        pr = [.24, .34, .26][k]
        star = r * (1 + .42 * np.abs(np.cos(th * 2 + .4)) ** 3)
        img[(star < pr * 1.25) & (img < LIGHT)] = LIGHT
        img[star < pr] = HOT if k < 2 else LIGHT
        if k == 2:
            img[star < pr * .6] = HOT

    # Four-point sparkles drift out after the rays.
    for a, r0, dr, start, life, big, sway in SPARKS:
        t = k - start
        if t < 0 or t >= life:
            continue
        p = t / max(1, life - 1)
        rr = (r0 + dr * ease(p)) * R
        aa = a + .018 * k + sway * p
        cx, cy = int(round(R + math.cos(aa) * rr)), int(round(R + math.sin(aa) * rr))
        arm = int(round(big * max(1.0, R / 72.0) * math.sin(math.pi * clamp(.15 + .85 * p))))
        for q in range(-arm, arm + 1):
            c = HOT if abs(q) <= arm * .4 else LIGHT if abs(q) <= arm * .75 else MID
            for x, y in ((cx + q, cy), (cx, cy + q)):
                if 0 <= x < size and 0 <= y < size:
                    img[y, x] = max(img[y, x], c)
        if arm >= 2:
            for x, y in ((cx + 1, cy + 1), (cx - 1, cy - 1), (cx + 1, cy - 1), (cx - 1, cy + 1)):
                if 0 <= x < size and 0 <= y < size:
                    img[y, x] = max(img[y, x], MID)

    # Deep outline around everything that is light or brighter, over empty cells only: keeps it readable on pale floors.
    m = np.pad(img >= LIGHT, 1)
    ring = (m[1:-1, :-2] | m[1:-1, 2:] | m[:-2, 1:-1] | m[2:, 1:-1]) & (img == 0)
    img[ring] = DEEP
    return img


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    meta = {"frames": N, "fps": FPS, "reduced_motion_frame": 4, "reduced_motion_seconds": 0.18, "sizes": []}
    for R in RADII:
        sheet = np.concatenate([frame(k, R) for k in range(N)], axis=1)
        name = "acquisition_burst_%03d.png" % R
        Image.fromarray(sheet).save(out / name, optimize=True)
        meta["sizes"].append({"radius_cells": R, "frame_cells": [R * 2, R * 2], "atlas": "res://assets/art/effects/bursts/" + name,
                              "sha256_pixels": hashlib.sha256(sheet.tobytes()).hexdigest()})
        print(name, sheet.shape[::-1], (out / name).stat().st_size // 1024, "KB")
    (out / "acquisition_bursts.json").write_text(json.dumps(meta, indent=1) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "tools/fnd01/out"))

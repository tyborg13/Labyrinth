"""Third prototype: additive light trails; sweep smear for cuts, axial streak for thrusts."""
import json, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
D = json.load(open('out/paths.json'))
SS = 4
FONT = ImageFont.load_default()
WINDOW = {'sword': (0.33, 0.56), 'heavy': (0.25, 0.56), 'stab': (0.33, 0.54), 'thrust': (0.30, 0.54), 'lash': (0.30, 0.54)}
KIND = {'sword': 'sweep', 'heavy': 'sweep', 'lash': 'sweep', 'stab': 'streak', 'thrust': 'streak'}
REACH = {'sword': 0.55, 'heavy': 0.5, 'lash': 0.09}
STREAK = {'stab': 48, 'thrust': 74}   # source px behind the tip
CONTACT, TAIL = 0.42, 0.10
STYLES = {
    'A_ember': dict(edge=(255, 244, 220), core=(255, 178, 92), rim=(150, 60, 20), embers=(255, 160, 70), strands=False),
    'B_steel': dict(edge=(236, 244, 255), core=(150, 176, 210), rim=(40, 50, 70), embers=None, strands=False),
    'C_brush': dict(edge=(255, 240, 210), core=(250, 160, 80), rim=(130, 50, 20), embers=(255, 150, 60), strands=True),
}
def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(round(lerp(a, b, t))) for a, b in zip(c1, c2))
def visible(key, motion, now):
    t0, t1 = WINDOW[motion]
    return [s for s in D[key]['samples'] if t0 <= s['t'] <= min(now, t1) and s['t'] >= now - TAIL]
def life(motion, now):
    t1 = WINDOW[motion][1]
    return 1.0 if now <= t1 else max(0.0, 1 - (now - t1) / 0.06)

def draw(light, key, motion, now, sty, to_px, scale):
    """Draws into an RGB 'light' layer (black = nothing), later added onto the scene."""
    s = STYLES[sty]; pts = visible(key, motion, now); L = life(motion, now)
    d = ImageDraw.Draw(light)
    rng = random.Random(11)
    if len(pts) >= 2 and L > 0:
        n = len(pts); kind = KIND[motion]
        if kind == 'sweep':
            bands = 16
            for i in range(n - 1):
                a, b = pts[i], pts[i + 1]
                age = 1 - (i + 1) / (n - 1); k = (1 - age) ** 1.3 * L
                for band in range(bands):
                    f0, f1 = band / bands, (band + 1) / bands
                    if s['strands'] and age > 0.3 and (band // 2 + i // 4) % 3 == 0:
                        continue
                    ra = REACH[motion] * (1 - (age + 1 / (n - 1))) ** 0.85; rb = REACH[motion] * (1 - age) ** 0.85
                    def at(p, f, r): return to_px((lerp(p['tip'][0], p['hand'][0], f * r), lerp(p['tip'][1], p['hand'][1], f * r)))
                    col = mix(mix(s['edge'] if f0 < 0.12 else s['core'], s['rim'], f0), (0, 0, 0), 1 - k * (1 - f0) ** 1.4)
                    d.polygon([at(a, f0, max(ra, 0.0)), at(b, f0, rb), at(b, f1, rb), at(a, f1, max(ra, 0.0))], fill=col)
        if kind == 'streak':
            tip = pts[-1]; tp = to_px(tip['tip']); hp = to_px(tip['hand'])
            ax = (tp[0] - hp[0], tp[1] - hp[1]); m = math.hypot(*ax) or 1; ax = (ax[0] / m, ax[1] / m); nx = (-ax[1], ax[0])
            length = STREAK[motion] * scale * SS
            drive = min(1.0, max(0.0, (now - 0.30) / 0.10)) * L
            for lane, off, w in ((0, 0, 4.4), (1, 4.0, 1.6), (2, -4.0, 1.6)):
                segs = 18
                for j in range(segs):
                    f0, f1 = j / segs, (j + 1) / segs
                    k = (1 - f0) ** 1.2 * drive * (1 if lane == 0 else 0.6)
                    p0 = (tp[0] - ax[0] * length * f0 * (1 if lane == 0 else 0.7) + nx[0] * off * scale * SS, tp[1] - ax[1] * length * f0 * (1 if lane == 0 else 0.7) + nx[1] * off * scale * SS)
                    p1 = (tp[0] - ax[0] * length * f1 * (1 if lane == 0 else 0.7) + nx[0] * off * scale * SS, tp[1] - ax[1] * length * f1 * (1 if lane == 0 else 0.7) + nx[1] * off * scale * SS)
                    col = mix(mix(s['edge'], s['core'], f0), (0, 0, 0), 1 - k)
                    d.line([p0, p1], fill=col, width=max(1, int(w * (1 - f0 * 0.6) * scale * SS)))
        # bright leading ribbon along the tip path (all kinds; the main line for the whip)
        edge = [to_px(p['tip']) for p in pts]
        width = 2.6 if kind == 'whip' else 1.6
        for i in range(len(edge) - 1):
            age = 1 - (i + 1) / (len(edge) - 1); k = (1 - age) ** 1.8 * L
            col = mix(mix(s['edge'], s['core'], age), (0, 0, 0), 1 - k)
            d.line([edge[i], edge[i + 1]], fill=col, width=max(1, int(scale * SS * (width * (1 - age) + 0.5))))
        if s['embers']:
            for i, p in enumerate(pts[:-1]):
                if rng.random() < 0.22:
                    age = 1 - (i + 1) / (n - 1); drift = (now - p['t']) * 90
                    x, y = to_px(p['tip']); x += scale * SS * (rng.uniform(-4, 4) + drift * rng.uniform(-1, 1)); y += scale * SS * (rng.uniform(-4, 4) + drift * 0.6)
                    r = scale * SS * rng.uniform(0.7, 1.3)
                    d.ellipse((x - r, y - r, x + r, y + r), fill=mix(s['embers'], (0, 0, 0), age))
    if CONTACT <= now <= CONTACT + 0.10:
        c = min(D[key]['samples'], key=lambda q: abs(q['t'] - CONTACT)); x, y = to_px(c['tip']); k = 1 - (now - CONTACT) / 0.10
        for ang, Ln in ((0, 11), (90, 11), (45, 6), (135, 6)):
            for sg in (1, -1):
                dx, dy = math.cos(math.radians(ang)) * sg, math.sin(math.radians(ang)) * sg; w = scale * SS * 1.2; Lp = scale * SS * Ln * (0.6 + 0.6 * k)
                d.polygon([(x + dy * w, y - dx * w), (x + dx * Lp, y + dy * Lp), (x - dy * w, y + dx * w)], fill=mix(s['edge'], (0, 0, 0), 1 - k))

def compose(base_rgba, light):
    soft = light.filter(ImageFilter.GaussianBlur(SS * 2.5))
    glow = ImageChops.add(light, ImageChops.multiply(soft, Image.new('RGB', soft.size, (150, 150, 150))))
    return ImageChops.add(base_rgba.convert('RGB'), glow)

def board_view(motion, view, now, f, sty, floor):
    s = 0.5857; rig = Image.open(f'out/{motion}_{view}_{f:02d}.png').convert('RGBA')
    W, H = floor.size
    big = floor.resize((W * SS, H * SS), Image.NEAREST).convert('RGBA')
    ox, oy = W * 0.5 - (128 + 127.5) * s, H * 0.62 - (128 + 202.7) * s
    big.alpha_composite(rig.resize((int(512 * s * SS), int(512 * s * SS)), Image.BILINEAR), (int(ox * SS), int(oy * SS)))
    light = Image.new('RGB', big.size, (0, 0, 0))
    draw(light, f'{motion}_{view}', motion, now, sty, lambda p: ((ox + (p[0] + 128) * s) * SS, (oy + (p[1] + 128) * s) * SS), s)
    out = compose(big, light).resize((W, H), Image.LANCZOS)
    return out.resize((W * 3, H * 3), Image.NEAREST)

if __name__ == '__main__':
    floor = Image.open('BOARD_CAPTURE.png').convert('RGB').crop((850, 300, 1050, 480))
    shots = [('sword', 'front', 0.40, 24), ('sword', 'front', 0.42, 25), ('heavy', 'front', 0.42, 25), ('stab', 'front', 0.42, 25), ('thrust', 'front', 0.42, 25), ('lash', 'front', 0.42, 25)]
    for sty in STYLES:
        cells = [board_view(m, v, t, f, sty, floor) for m, v, t, f in shots]
        bw, bh = cells[0].size
        bs = Image.new('RGB', (bw * 3, bh * 2 + 40), (22, 20, 18)); dd = ImageDraw.Draw(bs)
        for i, (c, sh) in enumerate(zip(cells, shots)):
            x, y = (i % 3) * bw, (i // 3) * (bh + 20) + 20
            bs.paste(c, (x, y)); dd.text((x + 6, y - 16), f'{sty} board-scale x3  {sh[0]} t={sh[2]}', fill=(230, 220, 200), font=FONT)
        bs.save(f'v3_{sty}_board.png'); print(sty, bs.size)

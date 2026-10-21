"""Director prototype: a branching section-map generator (revision 7 candidate) and an inked-trail renderer.

Not product code. It measures choice density and renders mockups on the real Cinder Crown map panel.
"""
import json, math, random, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

REPO = Path('/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark')
CAPTURE = Path('/Users/borgerding/workspace/Labyrinth/output/spx-05-2026-10-21/r1/07_fullest_legend.png')
ICONS = REPO / 'assets/art/icons/map'
LANES = 7

P = dict(out_weights={1: 32, 2: 58, 3: 10}, merge_bias=0.45, min_width=2, max_width=6, max_run=2, min_choices=3)


def generate(seed, count=11, params=P):
    rng = random.Random(seed)
    mid = math.ceil(count / 2)
    for _ in range(6000):
        rows = {1: sorted(rng.sample([0, 1, 2, 3, 4, 5, 6], 3))}
        # Openings spread out: at least 2 lanes apart.
        if min(b - a for a, b in zip(rows[1], rows[1][1:])) < 2:
            continue
        children = {}
        ok = True
        for step in range(1, count - 1):
            forced = step + 1 in (mid, count - 1)
            nxt = set()
            prev_max = -1
            for lane in rows[step]:
                lo = max(lane - 1, prev_max if prev_max >= 0 else 0)
                hi = min(lane + 1, LANES - 1)
                opts = list(range(lo, hi + 1))
                if forced:
                    d = 1
                else:
                    w = dict(params['out_weights'])
                    if lane in (0, LANES - 1):
                        w.pop(3, None)
                    d = rng.choices(list(w), weights=list(w.values()))[0]
                d = min(d, len(opts))
                if prev_max >= lo and rng.random() < params['merge_bias']:
                    start = 0  # share the previous node's last child (a merge)
                else:
                    start = rng.randint(0, len(opts) - d)
                    if prev_max >= lo and start == 0 and len(opts) > d:
                        start = 1
                kids = opts[start:start + d]
                children[(step, lane)] = [(step + 1, k) for k in kids]
                prev_max = kids[-1]
                nxt.update(kids)
            rows[step + 1] = sorted(nxt)
            w = len(rows[step + 1])
            if w < params['min_width'] or w > params['max_width']:
                ok = False
                break
            if forced and w > 4:
                ok = False
                break
        if not ok:
            continue
        same = 1
        for s in range(2, count):
            same = same + 1 if rows[s] == rows[s - 1] else 1
            if same > 2:
                ok = False
        if ok:
            m = metrics(rows, children, count)
            if m['longest_run_max'] <= params.get('max_run', 99) and m['choices_min'] >= params.get('min_choices', 0):
                return rows, children
    raise RuntimeError('no layout')


def metrics(rows, children, count):
    interior = [c for s in rows for c in [(s, l) for l in rows[s]] if s < count - 1]
    deg = [len(children.get(c, [])) for c in interior]
    routes = []

    def walk(c, path):
        if c[0] >= count - 1 or c not in children:
            routes.append(path)
            return
        for t in children[c]:
            walk(t, path + [t])
    for l in rows[1]:
        walk((1, l), [(1, l)])
    choice, run_max = [], []
    mid = math.ceil(count / 2)
    for r in routes:
        c = run = longest = 0
        for cell in r[:-1]:
            if len(children.get(cell, [])) >= 2:
                c += 1; run = 0
            elif cell[0] + 1 in (mid, count - 1):
                run = 0  # forced convergence rows are not counted as missed choices
            else:
                run += 1; longest = max(longest, run)
        choice.append(c); run_max.append(longest)
    edges = [(a, b) for a in children for b in children[a]]
    return dict(nodes=len(interior), fork_share=sum(d >= 2 for d in deg) / len(deg), mean_out=sum(deg) / len(deg),
                lane_change_share=sum(a[1] != b[1] for a, b in edges) / len(edges), routes=len(routes),
                choices_median=sorted(choice)[len(choice) // 2], choices_min=min(choice),
                longest_run_median=sorted(run_max)[len(run_max) // 2], longest_run_max=max(run_max))


def assign_types(rows, children, count, seed):
    rng = random.Random(seed * 31 + 7)
    mid = math.ceil(count / 2)
    weights = {'fight': 46, 'mystery': 22, 'guardian': 10, 'scavenger': 10, 'graftwright': 6, 'event': 6}
    types = {}
    for s in sorted(rows):
        for l in rows[s]:
            if s == 1: types[(s, l)] = 'fight'
            elif s == mid: types[(s, l)] = 'relic'
            elif s == count - 1: types[(s, l)] = 'campfire'
            else: types[(s, l)] = rng.choices(list(weights), weights=list(weights.values()))[0]
    # Forks show different types where possible (mirrors the existing fork rule).
    for c, kids in children.items():
        seen = set()
        for k in kids:
            if k[0] in (mid, count - 1):
                continue
            while types[k] in seen and types[k] != 'fight':
                types[k] = rng.choices(list(weights), weights=list(weights.values()))[0]
            seen.add(types[k])
    specials = [c for c in types if types[c] == 'fight' and 3 <= c[0] <= count - 3]
    rng.shuffle(specials)
    for c, t in zip(specials[:2], ['warband', 'umbral_snare']):
        types[c] = t
    return types


def bezier(a, b, wobble):
    (x0, y0), (x3, y3) = a, b
    dx, dy = x3 - x0, y3 - y0
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    c1 = (x0 + dx * 0.33 + nx * wobble, y0 + dy * 0.33 + ny * wobble)
    c2 = (x0 + dx * 0.67 - nx * wobble * 0.8, y0 + dy * 0.67 - ny * wobble * 0.8)
    pts = []
    for i in range(201):
        t = i / 200
        u = 1 - t
        pts.append((u ** 3 * x0 + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * x3,
                    u ** 3 * y0 + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * y3))
    return pts


def resample(pts, spacing):
    out, acc = [pts[0]], 0.0
    for p, q in zip(pts, pts[1:]):
        seg = math.dist(p, q)
        while acc + seg >= spacing:
            t = (spacing - acc) / seg
            p = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
            out.append(p)
            seg = math.dist(p, q)
            acc = 0.0
        acc += seg
    return out


def trim(pts, ra, rb):
    a, b = pts[0], pts[-1]
    return [p for p in pts if math.dist(p, a) > ra + 6 and math.dist(p, b) > rb + 6]


def icon(name, r, tint=1.0):
    path = ICONS / f'{name}.png'
    im = Image.open(path).convert('RGB').resize((2 * r, 2 * r), Image.LANCZOS)
    if tint != 1.0:
        im = im.point(lambda v: int(v * tint))
    mask = Image.new('L', (2 * r, 2 * r), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, 2 * r - 2, 2 * r - 2), fill=255)
    return im, mask


def render(rows, children, types, count, out, style='ink', seed=0, progress=0):
    base = Image.open(CAPTURE).convert('RGB')
    field = (32, 134, 1888, 913)
    paint = Image.open(REPO / 'assets/art/backgrounds/sections/vyraketh.png').convert('RGB')
    fw, fh = field[2] - field[0], field[3] - field[1]
    scale = max(fw / paint.width, fh / paint.height)
    paint = paint.resize((int(paint.width * scale), int(paint.height * scale)), Image.LANCZOS)
    paint = paint.crop(((paint.width - fw) // 2, (paint.height - fh) // 2, (paint.width - fw) // 2 + fw, (paint.height - fh) // 2 + fh))
    paint = paint.point(lambda v: int(v * 0.56))
    base.paste(paint, field[:2])
    img = base.convert('RGBA')
    rng = random.Random(seed * 13 + 5)
    x0, x1 = 247, 1590
    pos = {}
    for s in rows:
        for l in rows[s]:
            x = x0 + (x1 - x0) * (s - 1) / (count - 2) + (rng.uniform(-18, 18) if s > 1 else 0)
            y = 205 + l * 103 + rng.uniform(-24, 24)
            pos[(s, l)] = (x, y)
    start, boss = (107, 522), (1765, 522)
    current = None
    visited = []
    avail = [(1, l) for l in rows[1]]
    if progress:
        prng = random.Random(seed * 97 + 1)
        cell = (1, rows[1][1])
        visited.append(cell)
        for _ in range(progress - 1):
            cell = prng.choice(children[cell]); visited.append(cell)
        current = cell
        avail = list(children[current])
    reach = set()
    if current is not None:
        stack = [current]
        while stack:
            c = stack.pop()
            for k in children.get(c, []):
                if k not in reach: reach.add(k); stack.append(k)
    def bypassed(c):
        return current is not None and c not in reach and c not in visited
    radius = {c: (52 if c in avail else (42 if c == current else 31)) for c in pos}
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    links = [(start, pos[(1, l)], 55, radius[(1, l)], 'immediate' if current is None else ('walked' if (1, l) in visited else 'bypassed'), l - 3) for l in rows[1]]
    for a, kids in children.items():
        for b in kids:
            kind = 'walked' if (a in visited and b in visited) else ('immediate' if a == current else ('bypassed' if (bypassed(a) or bypassed(b)) else 'ahead'))
            links.append((pos[a], pos[b], radius[a], radius[b], kind, ((a[1] * 7 + b[0] * 3 + seed) % 9) - 4))
    for l in rows[count - 1]:
        c = (count - 1, l)
        links.append((pos[c], boss, radius[c], 82, 'bypassed' if bypassed(c) else 'ahead', 3))
    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    for a, b, ra, rb, kind, k in links:
        wob = k * 5.0
        pts = trim(bezier(a, b, wob), ra, rb)
        if not pts:
            continue
        if style != 'ink':
            d.line(pts, fill=(12, 10, 14, 130), width=5); d.line(pts, fill=(89, 86, 97, 255), width=2); continue
        if kind == 'walked':
            d.line(pts, fill=(10, 8, 12, 170), width=8)
            d.line(pts, fill=(196, 150, 84, 255), width=4)
            continue
        spacing, rr, col, halo = {'immediate': (10, 3.6, (246, 216, 150, 255), 160), 'ahead': (12, 2.6, (201, 181, 138, 225), 150),
                                  'bypassed': (14, 1.9, (120, 112, 128, 110), 70)}[kind]
        dots = resample(pts, spacing)
        if kind == 'immediate':
            g.line(pts, fill=(255, 190, 90, 120), width=14)
        for p in dots:
            d.ellipse((p[0] - rr - 1.6, p[1] - rr - 1.6, p[0] + rr + 1.6, p[1] + rr + 1.6), fill=(10, 8, 12, halo))
        for p in dots:
            d.ellipse((p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr), fill=col)
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(7)))
    img = Image.alpha_composite(img, layer)
    # Ground shadow under nodes seats them on the painting.
    shadow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for c, (x, y) in pos.items():
        r = radius[c]
        sd.ellipse((x - r * 1.15, y + r * 0.35, x + r * 1.15, y + r * 1.05), fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    img = Image.alpha_composite(img, shadow)
    med = Image.open(REPO / 'assets/art/ui/section_map/medallion.png').convert('RGBA')
    for c, (x, y) in pos.items():
        r = radius[c]
        t = types[c]
        name = {'fight': 'fight', 'mystery': None, 'guardian': None, 'scavenger': 'scavenger', 'graftwright': 'graftwright',
                'event': 'event', 'relic': 'relic', 'campfire': 'campfire', 'warband': 'warband', 'umbral_snare': 'umbral_snare'}[t]
        if t == 'guardian':
            name = 'boss_vyraketh'  # stand-in for the Guardian emblem in this mockup
            name = 'fight'
        if name is None:
            dd = ImageDraw.Draw(img)
            for k in range(0, 360, 30):
                a0 = math.radians(k)
                dd.arc((x - r, y - r, x + r, y + r), k, k + 17, fill=(170, 162, 175, 255), width=2)
            dd.text((x - 5, y - 9), '?', fill=(200, 192, 205, 255))
            continue
        m = med.resize((int(r * 2.25), int(r * 2.25)), Image.LANCZOS)
        img.alpha_composite(m, (int(x - r * 1.125), int(y - r * 1.125)))
        ic, mask = icon(name, int(r * 0.80), 1.0 if c in avail else (0.38 if bypassed(c) else (0.55 if c in visited else 0.80)))
        img.paste(ic, (int(x - r * 0.80), int(y - r * 0.80)), mask)
        dd = ImageDraw.Draw(img)
        if c in avail:
            dd.ellipse((x - r - 4, y - r - 4, x + r + 4, y + r + 4), outline=(255, 218, 141, 255), width=4)
        if c in visited and c != current:
            dd.ellipse((x - r - 2, y - r - 2, x + r + 2, y + r + 2), outline=(183, 193, 173, 255), width=4)
        if bypassed(c):
            veil = Image.new('RGBA', (int(2 * r + 8), int(2 * r + 8)), (0, 0, 0, 0))
            ImageDraw.Draw(veil).ellipse((0, 0, 2 * r + 7, 2 * r + 7), fill=(14, 12, 18, 120))
            img.alpha_composite(veil, (int(x - r - 4), int(y - r - 4)))
    # Keep the capture's start lantern and boss medallion.
    cap = Image.open(CAPTURE).convert('RGBA')
    spots = [(107, 522, 64), (1765, 522, 92)]
    for (cx, cy, rr) in spots:
        patch = cap.crop((cx - rr, cy - rr - 40, cx + rr, cy + rr))
        img.alpha_composite(patch, (cx - rr, cy - rr - 40))
    if current is not None:
        dd = ImageDraw.Draw(img)
        dd.polygon([(107, 470), (89, 448), (125, 448)], fill=(30, 26, 34))
        veil = Image.new('RGBA', (100, 100), (0, 0, 0, 0)); ImageDraw.Draw(veil).ellipse((0, 0, 99, 99), fill=(14, 12, 18, 110))
        img.alpha_composite(veil, (57, 472))
        dd.ellipse((107 - 50, 522 - 50, 107 + 50, 522 + 50), outline=(183, 193, 173, 255), width=4)
        lantern = cap.crop((107 - 50, 522 - 50, 107 + 50, 522 + 50))
        mask = Image.new('L', lantern.size, 0); ImageDraw.Draw(mask).ellipse((2, 2, 97, 97), fill=255)
        x, y = pos[current]
        img.paste(lantern, (int(x - 50), int(y - 50)), mask)
        dd = ImageDraw.Draw(img)
        dd.polygon([(x, y - 56), (x - 18, y - 82), (x + 18, y - 82)], fill=(255, 240, 192))
    img.convert('RGB').save(out)


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'measure':
        agg = {}
        for seed in range(1, 201):
            for count in [10, 11, 11, 11, 11, 12]:
                rows, children = generate(seed * 10 + count, count)
                for k, v in metrics(rows, children, count).items():
                    agg.setdefault(k, []).append(v)
        for k, v in agg.items():
            v.sort()
            print(k.ljust(20), f"median {v[len(v)//2]:.2f}  p10 {v[len(v)//10]:.2f}  p90 {v[len(v)*9//10]:.2f}")
    else:
        seed = int(sys.argv[2])
        progress = int(sys.argv[4]) if len(sys.argv) > 4 else 0
        rows, children = generate(seed, 11)
        types = assign_types(rows, children, 11, seed)
        print(metrics(rows, children, 11))
        render(rows, children, types, 11, sys.argv[3], mode, seed, progress)

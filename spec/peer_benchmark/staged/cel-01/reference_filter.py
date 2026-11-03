"""Director's reference cel filter (cel-01). The look is decided; the tool must reproduce this output.

Per image, automatically:
- light edge-preserving smoothing (Kuwahara);
- materials by k-means on hue/chroma first and value second (colour weight), so dark coloured cloth and pale ice stay
  their own material;
- each material gets one lit tone and one shadow tone at a fixed shadow step (the same for every character), scaled so
  the material keeps its average brightness;
- lit/shadow is decided on a blurred value (shapes, not speckle), biased by one shared upper-left key light on a
  height built from the silhouette;
- a highlight tone only where the painting has a real highlight (metal sheen);
- glows (bright and saturated) keep the original pixels; the painting's own dark outline stays as ink;
- strong small details (eyes, rivets) take their own material's nearest tone;
- touch-ups: ellipses (image px) where the original pixels are kept.
Alpha is never changed.

Usage: python3 reference_filter.py settings.json in.png out.png [touch ellipses as JSON list]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W = np.array([0.299, 0.587, 0.114])
INK = np.array([0.06, 0.045, 0.04])
SHADOW_TINT = np.array([0.94, 0.97, 1.05])


def box_mean(a, r):
    k = 2 * r + 1
    pad = [(r + 1, r), (r + 1, r)] + [(0, 0)] * (a.ndim - 2)
    c = np.pad(a, pad, mode='edge').cumsum(0).cumsum(1)
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s / (k * k)


def kuwahara(rgb, r):
    h, w, _ = rgb.shape
    lum = rgb @ W
    m = box_mean(rgb, r // 2)
    v = box_mean(lum ** 2, r // 2) - box_mean(lum, r // 2) ** 2
    q = r // 2 + 1
    best = np.full((h, w), np.inf)
    out = rgb.copy()
    for dy in (-q, q):
        for dx in (-q, q):
            vs = np.roll(np.roll(v, dy, 0), dx, 1)
            ms = np.roll(np.roll(m, dy, 0), dx, 1)
            pick = vs < best
            best[pick] = vs[pick]
            out[pick] = ms[pick]
    return out


def kmeans(x, k, iters=12, seed=3):
    rng = np.random.default_rng(seed)
    c = x[rng.choice(len(x), k, replace=False)]
    for _ in range(iters):
        lab = ((x[:, None, :] - c[None]) ** 2).sum(-1).argmin(1)
        for i in range(k):
            sel = x[lab == i]
            if len(sel):
                c[i] = sel.mean(0)
    return c, lab


def blur(x, r):
    k = np.arange(-int(3 * r), int(3 * r) + 1)
    g = np.exp(-(k ** 2) / (2 * r * r)); g /= g.sum()
    p = len(k) // 2
    y = np.pad(x, ((p, p), (0, 0)), mode='edge')
    y = sum(g[i] * y[i:i + x.shape[0]] for i in range(len(k)))
    y = np.pad(y, ((0, 0), (p, p)), mode='edge')
    return sum(g[i] * y[:, i:i + x.shape[1]] for i in range(len(k)))


def grow(mask, n=1):
    im = Image.fromarray((mask * 255).astype(np.uint8))
    for _ in range(n):
        im = im.filter(ImageFilter.MaxFilter(3))
    return np.asarray(im) > 127


def touch_mask(shape, ellipses):
    im = Image.new('L', (shape[1], shape[0]), 0)
    d = ImageDraw.Draw(im)
    for cx, cy, rx, ry in ellipses:
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    return np.asarray(im) > 127


def treat(path, out, S, touch=()):
    a = np.asarray(Image.open(path).convert('RGBA')).astype(float) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    body = alpha > 0.5
    olum = rgb @ W
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    g = S['glow']
    glow = grow(body & (mx > g['core_value']) & (sat > g['core_saturation'])) & body \
        & (mx > g['halo_value']) & (sat > g['halo_saturation'])
    ink = body & (olum < S['ink_value'])

    sm = kuwahara(rgb, S['kuwahara_radius'])
    slum = sm @ W
    wsum = blur(body.astype(float), S['value_blur'])
    vlum = blur(np.where(body, slum, 0), S['value_blur']) / np.maximum(wsum, 1e-3)

    if S['key_light']:
        h = np.zeros(body.shape); m = body.copy()
        for _ in range(30):
            h += m
            m = ~grow(~m)
            if not m.any():
                break
        h = blur(np.sqrt(h / max(h.max(), 1)), 2.5)
        gy, gx = np.gradient(h)
        n = np.dstack([-gx * 9, -gy * 9, np.ones_like(h)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
        L = np.array(S['key_light_direction'], float); L /= np.linalg.norm(L)
        ndl = n @ L
        vv = vlum[body]
        vlum = (vlum - vv.mean()) / max(vv.std(), 1e-3) \
            + S['key_light'] * (ndl - ndl[body].mean()) / max(ndl[body].std(), 1e-3)

    idx = np.flatnonzero((body & ~ink & ~glow).ravel())
    x = sm.reshape(-1, 3)[idx]
    xl = x @ W
    feat = np.concatenate([x / np.maximum(xl[:, None], 0.04) * S['colour_weight'], xl[:, None] * 1.0], 1)
    _, lab = kmeans(feat, S['materials'])
    cent = np.array([x[lab == i].mean(0) if (lab == i).any() else np.zeros(3) for i in range(S['materials'])])
    res = rgb.copy()
    flat = res.reshape(-1, 3)
    v = vlum.ravel()[idx]
    ol = olum.ravel()[idx]
    s = S['shadow_step']
    tone = {}
    for i in range(len(cent)):
        sel = lab == i
        if sel.sum() < 4:
            continue
        cols = x[sel]
        vi = v[sel]
        lit_mask = vi >= np.median(vi)
        f = lit_mask.mean()
        lit = np.clip(cols.mean(0) / (f + s * (1 - f)), 0, 1)
        sh = lit * s * SHADOW_TINT
        out_c = np.where(lit_mask[:, None], lit, sh)
        hl = S['highlight']
        hi_t = np.percentile(ol[sel], hl['percentile'])
        if hi_t > hl['min_value'] and hi_t - np.median(ol[sel]) > hl['min_rise']:
            hi = cols[ol[sel] >= hi_t].mean(0)
            hi = hi + (1 - hi) * hl['lift']
            out_c = np.where((ol[sel] >= hi_t)[:, None], hi, out_c)
        flat[idx[sel]] = out_c
        tone[i] = (lit, sh)

    detail = body & ~ink & ~glow & (np.abs(olum - slum) > S['detail_contrast'])
    if detail.any():
        d = rgb[detail]
        near = ((d[:, None, :] - cent[None]) ** 2).sum(-1).argmin(1)
        out_d = d.copy()
        for j in range(len(d)):
            lit, sh = tone.get(near[j], (d[j], d[j]))
            out_d[j] = lit if d[j] @ W >= ((lit + sh) / 2) @ W else sh
        res[detail] = out_d

    res[ink] = INK
    res[glow] = rgb[glow]
    if touch:
        keep = touch_mask(body.shape, touch) & body
        res[keep] = rgb[keep]
    o = np.dstack([np.clip(res, 0, 1), alpha])
    Image.fromarray((o * 255).round().astype(np.uint8)).save(out)


if __name__ == '__main__':
    settings = json.loads(Path(sys.argv[1]).read_text())['look']
    touch = json.loads(sys.argv[4]) if len(sys.argv) > 4 else ()
    treat(sys.argv[2], sys.argv[3], settings, touch)

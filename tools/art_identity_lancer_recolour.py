"""Opt-in replay of the protected rr-43 director recipe; no other job uses it."""
import colorsys

import numpy as np
from PIL import Image

DIRECTOR_RECIPE_SHA256 = 'acc62d607d59b2a76c017e6a55e78ce0db20d2f7ea79ea6b047e748b1ff5a4cd'


def hsv(img):
    rgb = img[..., :3].astype(float) / 255
    mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn
    h = np.zeros_like(mx); m = d > 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    i = m & (mx == r); h[i] = ((g - b)[i] / d[i]) % 6
    i = m & (mx == g); h[i] = ((b - r)[i] / d[i]) + 2
    i = m & (mx == b); h[i] = ((r - g)[i] / d[i]) + 4
    return h / 6, np.where(mx > 0, d / np.maximum(mx, 1e-6), 0), mx


def recolour(raw_image, front_image):
    raw = np.array(raw_image.convert('RGB')).astype(np.int32)
    blocks = raw[2:1022, 2:1022].reshape(255, 4, 255, 4, 3).transpose(0, 2, 1, 3, 4).reshape(255, 255, 16, 3)
    med = np.median(blocks, axis=2).astype(np.int32)
    key = (med[..., 1] > 180) & (med[..., 0] < 120) & (med[..., 2] < 120)
    rear = np.zeros((255, 255, 4), np.uint8); rear[..., :3] = med.clip(0, 255); rear[..., 3] = (~key) * 255
    front = np.array(front_image.convert('RGBA'))
    fh, fs, fv = hsv(front); rh, rs, rv = hsv(rear)
    fa = front[..., 3] > 0; ra = rear[..., 3] > 0
    fw = fa & ((fh < 0.15) | (fh > 0.9)) & (fv > 0.05); rw = ra & ((rh < 0.15) | (rh > 0.9)) & (rv > 0.05)
    thr_f = 0.45
    thr_r = np.quantile(rs[rw], 1 - (fs[fw] > thr_f).mean())
    new = rear[..., :3].astype(float) / 255
    for cf, cr in [(fs > thr_f, rs > thr_r), (fs <= thr_f, rs <= thr_r)]:
        F = fw & cf; R = rw & cr
        rank = np.argsort(np.argsort(rv[R])) / (R.sum() - 1 + 1e-9)
        tv = np.quantile(fv[F], rank)
        order = np.argsort(fv[F]); fvs = fv[F][order]; fhs = fh[F][order]; fss = fs[F][order]
        idx = np.clip(np.searchsorted(fvs, tv), 0, len(fvs) - 1)
        th = np.array([np.median(fhs[max(0, i - 7):i + 8]) for i in idx])
        ts = np.array([np.median(fss[max(0, i - 7):i + 8]) for i in idx])
        new[R] = np.array([colorsys.hsv_to_rgb(a, b, c) for a, b, c in zip(th, ts, tv)])
    res = rear.copy(); res[..., :3] = (new * 255).round().clip(0, 255).astype(np.uint8)
    pal = np.unique(front[fa][:, :3], axis=0).astype(np.int32)
    flat = res[..., :3].reshape(-1, 3).astype(np.int32); out = np.empty(len(flat), np.int64)
    for s in range(0, len(flat), 4096):
        out[s:s + 4096] = ((flat[s:s + 4096, None, :] - pal[None]) ** 2).sum(-1).argmin(1)
    res[..., :3] = pal[out].reshape(255, 255, 3).astype(np.uint8); res[..., 3] = np.where(ra, 255, 0)
    # Director step 4: this is the complete supplied house-outline recipe,
    # not a second gate-tool post-process or an outline on individual cuts.
    a = res[..., 3] > 0
    n = np.zeros(a.shape, int); n[1:] += a[:-1]; n[:-1] += a[1:]; n[:, 1:] += a[:, :-1]; n[:, :-1] += a[:, 1:]
    a &= n > 0
    inner = a.copy(); inner[1:] &= a[:-1]; inner[:-1] &= a[1:]; inner[:, 1:] &= a[:, :-1]; inner[:, :-1] &= a[:, 1:]
    res[..., 3] = np.where(a, 255, 0); res[a & ~inner, :3] = (20, 16, 21)
    return Image.fromarray(res)



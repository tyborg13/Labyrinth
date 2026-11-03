"""Audited numerical replay of the protected rr-44 arm recipe; never executes job code."""
DIRECTOR_RECIPE_SHA256 = '8025cd27b0bf1193bc7dae546c6b4a08396309757cef186ff895dfc3f09d1942'
import sys

import numpy as np
from PIL import Image

MIN_COMPONENT = 40
DILATE = 2
OUTLINE = (20, 16, 21)


def reduce(image):
    raw = np.array(image.convert('RGB')).astype(np.int32)
    blocks = raw[2:1022, 2:1022].reshape(255, 4, 255, 4, 3).transpose(0, 2, 1, 3, 4).reshape(255, 255, 16, 3)
    med = np.median(blocks, axis=2).astype(np.int32)
    key = (med[..., 1] > 180) & (med[..., 0] < 120) & (med[..., 2] < 120)
    return med, ~key


def components(mask):
    labels = np.zeros(mask.shape, np.int32); sizes = [0]
    for y, x in zip(*np.nonzero(mask)):
        if labels[y, x]: continue
        n = len(sizes); stack = [(y, x)]; labels[y, x] = n; count = 0
        while stack:
            cy, cx = stack.pop(); count += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < 255 and 0 <= nx < 255 and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = n; stack.append((ny, nx))
        sizes.append(count)
    return labels, np.array(sizes)


def dilate(mask, r):
    out = mask.copy()
    for _ in range(r):
        grown = out.copy()
        grown[1:] |= out[:-1]; grown[:-1] |= out[1:]; grown[:, 1:] |= out[:, :-1]; grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def compose(edit, approved_image, mask, side):
    med, edit_alpha = reduce(edit)
    approved = np.array(approved_image.convert('RGBA')).astype(np.int32)
    app_alpha = approved[..., 3] > 0
    diff = np.abs(med - approved[..., :3]).sum(-1)
    changed = (app_alpha != edit_alpha) | (app_alpha & edit_alpha & (diff > 60))
    labels, sizes = components(changed)
    region = np.isin(labels, np.nonzero(sizes >= MIN_COMPONENT)[0]) & (labels > 0)
    if mask is not None:
        region |= np.array(mask.convert('L')) > 0
    region = dilate(region, DILATE)
    xs = np.nonzero(app_alpha.any(0))[0]; mid = (xs.min() + xs.max()) // 2
    half = np.zeros_like(region); half[:, :mid] = side == 'left'; half[:, mid:] = side == 'right'
    region &= half
    pal = np.unique(approved[app_alpha][:, :3], axis=0)
    res = approved.copy()
    flat = med[region]
    idx = ((flat[:, None, :] - pal[None]) ** 2).sum(-1).argmin(1)
    res[region, :3] = pal[idx]
    res[region, 3] = np.where(edit_alpha[region], 255, 0)
    a = res[..., 3] > 0
    n = np.zeros(a.shape, int); n[1:] += a[:-1]; n[:-1] += a[1:]; n[:, 1:] += a[:, :-1]; n[:, :-1] += a[:, 1:]
    drop = region & a & (n == 0); res[drop, 3] = 0; a &= ~drop
    edge = np.zeros_like(a)
    edge[1:] |= ~a[:-1]; edge[:-1] |= ~a[1:]; edge[:, 1:] |= ~a[:, :-1]; edge[:, :-1] |= ~a[:, 1:]
    edge[0] = edge[-1] = True; edge[:, 0] = edge[:, -1] = True
    outline = region & a & edge
    res[outline, :3] = OUTLINE
    res[~(res[..., 3] > 0)] = 0
    return Image.fromarray(res.astype(np.uint8), 'RGBA')

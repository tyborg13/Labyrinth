"""Director composite for the Gaoler's lowered chain arm (rr-44).

Reproduces a 255 px painting from an approved painting and the image edit that lowers its chain arm:
1. 4x4 block median of the edit's [2:1022] crop -> 255 px, chroma-green key.
2. Region = the large connected changes between the edit and the approved painting (components of at least
   MIN_COMPONENT px, so 1 px outline jitter elsewhere stays approved) plus the old arm's footprint mask, dilated by
   DILATE px, inside the side's half of the figure.
3. Inside the region the edit's pixels, each mapped to the nearest colour of the approved palette; outside it the
   approved pixels, unchanged.
4. The house outline on the region's silhouette edge: isolated pixels dropped, every edge pixel set to the approved
   outline tone.
Usage: python3 compose_arm.py <edit_1024.png> <approved_255.png> <old_arm_mask_255.png|-> <side:left|right> <out_255.png> [<region_out.png>]
"""
import sys

import numpy as np
from PIL import Image

MIN_COMPONENT = 40
DILATE = 2
OUTLINE = (20, 16, 21)


def reduce(path):
    raw = np.array(Image.open(path).convert('RGB')).astype(np.int32)
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


def main(edit_path, approved_path, mask_path, side, out_path, region_path=None):
    med, edit_alpha = reduce(edit_path)
    approved = np.array(Image.open(approved_path).convert('RGBA')).astype(np.int32)
    app_alpha = approved[..., 3] > 0
    diff = np.abs(med - approved[..., :3]).sum(-1)
    changed = (app_alpha != edit_alpha) | (app_alpha & edit_alpha & (diff > 60))
    labels, sizes = components(changed)
    region = np.isin(labels, np.nonzero(sizes >= MIN_COMPONENT)[0]) & (labels > 0)
    if mask_path != '-':
        region |= np.array(Image.open(mask_path).convert('L')) > 0
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
    Image.fromarray(res.astype(np.uint8), 'RGBA').save(out_path)
    if region_path:
        Image.fromarray((region * 255).astype(np.uint8), 'L').save(region_path)
    print('region px', int(region.sum()), 'changed outside region', int((changed & ~region).sum()))


if __name__ == '__main__':
    main(*sys.argv[1:])

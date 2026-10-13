"""Prototype: restore a one-block dark outline. Silhouette-edge pixels brighter than `max_lum` (0-1) take the
outline tone; isolated opaque pixels with no opaque 4-neighbour are removed. Alpha otherwise untouched."""
import sys, numpy as np
from PIL import Image
def clean(src, out, tone=(20, 16, 21), max_lum=0.2):
    a = np.asarray(Image.open(src).convert('RGBA')).copy()
    m = a[..., 3] > 0
    n = np.zeros_like(m, dtype=int)
    n[1:] += m[:-1]; n[:-1] += m[1:]; n[:, 1:] += m[:, :-1]; n[:, :-1] += m[:, 1:]
    a[m & (n == 0), 3] = 0
    m = a[..., 3] > 0
    inner = m.copy(); inner[1:] &= m[:-1]; inner[:-1] &= m[1:]; inner[:, 1:] &= m[:, :-1]; inner[:, :-1] &= m[:, 1:]
    edge = m & ~inner
    lum = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255.0
    fix = edge & (lum > max_lum)
    a[fix, :3] = tone
    Image.fromarray(a).save(out)
    return int(fix.sum())
if __name__ == '__main__':
    print(clean(sys.argv[1], sys.argv[2]))

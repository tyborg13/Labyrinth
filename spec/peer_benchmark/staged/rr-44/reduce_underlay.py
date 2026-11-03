"""Director reduction for the rr-44 body underlays (the rr-42 processing).

The edit is resized to 1024 px if the tool returned another size (LANCZOS), then: crop [2:1022], 4x4 block median down
to 255 px, chroma-green key, each pixel mapped to the nearest colour of the painting's palette, registration (0,0).
The underlay is only ever used inside the re-cut pieces' vacated footprints (the density partition hook), so changes
the edit made outside those footprints never show.
Usage: python3 reduce_underlay.py <edit.png> <painting_255.png> <out_255.png>
"""
import sys

import numpy as np
from PIL import Image


def main(edit_path, painting_path, out_path):
    im = Image.open(edit_path).convert('RGB')
    if im.size != (1024, 1024):
        im = im.resize((1024, 1024), Image.LANCZOS)
    raw = np.array(im).astype(np.int32)
    blocks = raw[2:1022, 2:1022].reshape(255, 4, 255, 4, 3).transpose(0, 2, 1, 3, 4).reshape(255, 255, 16, 3)
    med = np.median(blocks, axis=2).astype(np.int32)
    alpha = ~((med[..., 1] > 170) & (med[..., 0] < 130) & (med[..., 2] < 130))
    painting = np.array(Image.open(painting_path).convert('RGBA')).astype(np.int32)
    pal = np.unique(painting[painting[..., 3] > 0][:, :3], axis=0)
    out = np.zeros((255, 255, 4), np.uint8)
    idx = ((med[alpha][:, None, :] - pal[None]) ** 2).sum(-1).argmin(1)
    out[alpha, :3] = pal[idx]
    out[alpha, 3] = 255
    Image.fromarray(out).save(out_path)


if __name__ == '__main__':
    main(*sys.argv[1:])

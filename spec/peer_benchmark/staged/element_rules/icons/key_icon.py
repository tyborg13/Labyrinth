#!/usr/bin/env python3
"""Key a #00FF00 icon render (16x-enlarged 64 px pixel art) down to a transparent 64x64 PNG.
usage: key_icon.py in.png out.png"""
import sys
import numpy as np
from PIL import Image
src = Image.open(sys.argv[1]).convert("RGB").resize((1024, 1024), Image.LANCZOS)
a = np.asarray(src).astype(np.int32)
# Each 16x16 block becomes one icon pixel: the block's median colour, transparent when it is mostly key green.
blocks = a.reshape(64, 16, 64, 16, 3).transpose(0, 2, 1, 3, 4).reshape(64, 64, 256, 3)
green = (blocks[..., 1] > 180) & (blocks[..., 0] < 120) & (blocks[..., 2] < 120)
out = np.zeros((64, 64, 4), np.uint8)
for y in range(64):
    for x in range(64):
        keep = ~green[y, x]
        if keep.sum() >= 128:
            out[y, x, :3] = np.median(blocks[y, x][keep], axis=0)
            out[y, x, 3] = 255
# Despill: pull any green-dominant edge pixel toward its red/blue average.
rgb = out[..., :3].astype(np.int32)
spill = (out[..., 3] > 0) & (rgb[..., 1] > np.maximum(rgb[..., 0], rgb[..., 2]) + 20)
rgb[spill, 1] = np.maximum(rgb[spill, 0], rgb[spill, 2])
out[..., :3] = rgb.astype(np.uint8)
Image.fromarray(out, "RGBA").save(sys.argv[2])

"""Derive a palette-match reference with front-only parts removed (director step).

`--match-front` fits a rear's Lab mean/spread to the whole front; a saturated part that only exists on the front (the
gaoler's oxblood tabard) then pushes every rear part toward its colour. This writes a copy of the front with those
regions made transparent, to be used as the `--match-front` reference for the rear.
Usage: python3 mask_reference.py FRONT_PROCESSED OUT CONFIG.json   (CONFIG: tone_region.py regions; lab_scale ignored)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from tone_region import region_mask  # noqa: E402


def mask(src: Path, out: Path, regions: list) -> None:
    pixels = np.asarray(Image.open(src).convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(float)
    for region in regions:
        hit = region_mask(rgb, region) & (pixels[..., 3] > 0)
        pixels[hit, 3] = 0
        print(f"{region['name']}: {int(hit.sum())} pixels excluded")
    Image.fromarray(pixels).save(out)


if __name__ == "__main__":
    mask(Path(sys.argv[1]), Path(sys.argv[2]), json.loads(Path(sys.argv[3]).read_text()))

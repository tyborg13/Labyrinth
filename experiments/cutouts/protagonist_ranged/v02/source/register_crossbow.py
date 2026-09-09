"""Deterministic registration only; authored RGB/alpha comes from imagegen.

Use the alpha>=16 bounds to measure the painted object without near-transparent
margin noise. Preserve all cropped RGBA and sample nearest at 126 source pixels
wide. The selected front/rear layouts retain grip, muzzle, and crop landmarks.
Run from any cwd; output is the case-owned art, not production.
"""
from pathlib import Path
from PIL import Image

case = Path(__file__).resolve().parents[1]
for facing in ("front", "rear"):
    source = Image.open(case / "source" / f"{facing}_crossbow_generated.png").convert("RGBA")
    bounds = source.getchannel("A").point(lambda a: 255 if a >= 16 else 0).getbbox()
    crop = source.crop(bounds)
    size = (126, 3 * round(crop.height * 42 / crop.width))
    crop.resize(size, Image.Resampling.NEAREST).save(case / "assets" / facing / "crossbow.png")

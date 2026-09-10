"""Register untouched generation; record explicit background/creature ownership.

This only selects/copies generated pixels. No paint, recolor, interpolation,
outline synthesis or hidden anatomy is supplied by the recipe.
"""
from collections import deque
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parent
source = ROOT / "front_generated_02_checkerboard.png"
image = Image.open(source).convert("RGBA").resize((255, 255), Image.Resampling.NEAREST)
registered = ROOT / "front_registered_with_background.png"
image.save(registered)

# Generated pale neutral checkerboard is disjoint from the dark silhouette.
# Flood only neutral bright pixels connected to explicit exterior/gap seeds;
# enclosed ice highlights and armor highlights remain creature-owned.
seeds = [(0, 0), (254, 254), (77, 110), (78, 149), (119, 232), (185, 224),
         (85, 210)]  # Inspected enclosed background between lance shaft and shin.
background = set()
queue = deque(seeds)
while queue:
    x, y = queue.popleft()
    if not (0 <= x < 255 and 0 <= y < 255) or (x, y) in background:
        continue
    r, g, b, _ = image.getpixel((x, y))
    if min(r, g, b) < 150 or max(r, g, b) - min(r, g, b) > 30:
        continue
    background.add((x, y))
    queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

recipe = {
    "purpose": "Whole-paint background ownership only, before anatomical segmentation",
    "priority_polygons": [["creature", [[0, 0], [254, 0], [254, 254], [0, 254]]],
                          ["background", [[0, 0], [254, 0], [254, 254], [0, 254]]]],
    "pixel_overrides": [{"point": [x, y], "name": "background"} for x, y in sorted(background)],
    "selection_recipe": {"seeds": seeds, "neutral_min_channel": 150, "max_chroma": 30,
                         "connectivity": 4, "background_owner_is_discarded": True},
}
(ROOT / "front_background_ownership.json").write_text(json.dumps(recipe, indent=2) + "\n")
mask = Image.new("L", image.size, 255)
for xy in background:
    mask.putpixel(xy, 0)
mask.save(ROOT / "front_creature_mask.png")
record = {
    "input": source.name, "input_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "input_size": list(Image.open(source).size), "crop": [0, 0, 1254, 1254],
    "resize": [255, 255], "resampling": "nearest; one uniform full-canvas registration",
    "offset": [0, 0], "registered": registered.name,
    "registered_sha256": hashlib.sha256(registered.read_bytes()).hexdigest(),
    "source_alpha": "RGB generation has no alpha; explicit background owner excluded from assembly",
    "background_pixels": len(background), "preserved_creature_pixels": 255 * 255 - len(background),
    "ownership_recipe": "front_background_ownership.json", "no_new_rgb_pixels": True,
}
(ROOT / "front_registration.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))

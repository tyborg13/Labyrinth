"""Case-local registration and explicit background ownership for new paint."""
from collections import deque
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[4]
RECIPES = {
    "rear": {"input": "rear_generated.png", "offset": [0, 4], "seeds": [[0, 0], [254, 254], [126, 232], [177, 146], [168, 211]], "revision": "v02"},
    "front_underbody": {"input": "front_underbody_generated.png", "offset": [0, -4], "seeds": [[0, 0], [254, 254], [80, 150], [122, 230], [151, 114]], "revision": "v02"},
    "rear_underbody": {"input": "rear_underbody_generated.png", "offset": [0, 4], "seeds": [[0, 0], [254, 254], [126, 232], [109, 111], [177, 145]]},
}

for key in sys.argv[1:] or list(RECIPES):
    recipe = RECIPES[key]
    original = ROOT / recipe["input"]
    image = Image.open(original).convert("RGBA").resize((255, 255), Image.Resampling.NEAREST)
    registered = ROOT / (key + "_with_background.png")
    image.save(registered)
    background = set()
    queue = deque(tuple(p) for p in recipe["seeds"])
    while queue:
        x, y = queue.popleft()
        if not (0 <= x < 255 and 0 <= y < 255) or (x, y) in background:
            continue
        r, g, b, _ = image.getpixel((x, y))
        if min(r, g, b) < 150 or max(r, g, b) - min(r, g, b) > 30:
            continue
        background.add((x, y))
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    ownership = ROOT / (key + "_background_ownership.json")
    ownership.write_text(json.dumps({
        "purpose": "Explicit generated background exclusion; no repaint",
        "priority_polygons": [["creature", [[0, 0], [254, 0], [254, 254], [0, 254]]],
                              ["background", [[0, 0], [254, 0], [254, 254], [0, 254]]]],
        "pixel_overrides": [{"point": [x, y], "name": "background"} for x, y in sorted(background)],
        "selection": {"seeds": recipe["seeds"], "min_neutral_channel": 150, "max_chroma": 30, "connectivity": 4},
    }, separators=(",", ":")) + "\n")
    output = ROOT / (key + "_background_split" + ("_" + recipe["revision"] if "revision" in recipe else ""))
    subprocess.run([sys.executable, str(PROJECT / "tools/cutout_workflow.py"), "segment", "--source", str(registered), "--ownership", str(ownership), "--output", str(output)], check=True)
    parts = json.loads((output / "segmentation.json").read_text())["parts"]
    part = next(p for p in parts if p["name"] == "creature")
    destination = Image.new("RGBA", (255, 255))
    placement = [part["offset"][i] + recipe["offset"][i] for i in range(2)]
    destination.alpha_composite(Image.open(output / "creature.png"), tuple(placement))
    target = ROOT / (key + "_registered.png")
    destination.save(target)
    destination.getchannel("A").save(ROOT / (key + "_creature_mask.png"))
    record = {**recipe, "resize": [255, 255], "resampling": "nearest; whole canvas, uniform",
              "input_sha256": hashlib.sha256(original.read_bytes()).hexdigest(),
              "output": target.name, "output_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
              "bbox": destination.getbbox(), "alpha_range": destination.getchannel("A").getextrema(),
              "background_owner_discarded": True, "no_new_rgb_pixels": True}
    (ROOT / (key + "_registration.json")).write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record))

sheet = Image.new("RGB", (4 * 510, 550), (42, 40, 38))
draw = ImageDraw.Draw(sheet)
for index, key in enumerate(["front", "rear", "front_underbody", "rear_underbody"]):
    path = ROOT / (key + "_registered.png")
    if not path.exists():
        continue
    image = Image.open(path).resize((510, 510), Image.Resampling.NEAREST)
    sheet.paste(image, (index * 510, 30), image.getchannel("A"))
    draw.text((index * 510 + 8, 8), key + " (uniform 2x)", fill=(240, 230, 214))
    for value in range(0, 255, 20):
        draw.line((index * 510 + value * 2, 30, index * 510 + value * 2, 540), fill=(75, 64, 55))
        draw.text((index * 510 + value * 2 + 1, 20), str(value), fill=(200, 190, 170))
        draw.line((index * 510, 30 + value * 2, (index + 1) * 510 - 1, 30 + value * 2), fill=(75, 64, 55))
        draw.text((index * 510, 30 + value * 2), str(value), fill=(200, 190, 170))
sheet.save(ROOT / "landmark_grid.png")

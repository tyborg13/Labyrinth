"""Lay out every native asset sample for full-cycle inspection; no new poses."""
from pathlib import Path
import argparse
import hashlib
import json
import math
from PIL import Image, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("assets", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()
comparison = json.loads((args.assets / "comparison.json").read_text())
assert comparison["ok"]
args.output.mkdir(parents=True, exist_ok=False)
records = comparison["records"]
# One union crop and scale for the entire case preserve relative body size and
# translation across all views, clips and phases. Original PNGs stay untouched.
left = max(0, min(r["bounds"][0] for r in records) - 8)
top = max(0, min(r["bounds"][1] for r in records) - 8)
right = min(512, max(r["bounds"][0] + r["bounds"][2] for r in records) + 8)
bottom = min(512, max(r["bounds"][1] + r["bounds"][3] for r in records) + 8)
crop = (left, top, right, bottom)
scale = min(220 / (right - left), 220 / (bottom - top))
size = (round((right - left) * scale), round((bottom - top) * scale))
outputs = []
for facing in ["front", "rear"]:
    for mirrored in [False, True]:
        for clip in ["idle", "walk", "dive", "gale", "pull", "guard"]:
            samples = [r for r in records if r["facing"] == facing and r["mirrored"] == mirrored and r["clip"] == clip]
            name = f"{facing}_{'mirror' if mirrored else 'direct'}_{clip}"
            sheet = Image.new("RGB", (6 * 228, math.ceil(len(samples) / 6) * 244 + 32), "#18212a")
            draw = ImageDraw.Draw(sheet)
            draw.text((12, 10), name + " — every native sample in chronological order", fill="white")
            inputs = {}
            for index, sample in enumerate(samples):
                path = args.assets / (sample["label"] + ".png")
                inputs[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
                image = Image.open(path).convert("RGBA").crop(crop).resize(size, Image.Resampling.LANCZOS)
                x, y = (index % 6) * 228, (index // 6) * 244 + 32
                sheet.paste(image, (x + (228 - size[0]) // 2, y + (220 - size[1]) // 2), image)
                draw.text((x + 6, y + 224), f"{index:02d}  phase {sample['phase']:.3f}", fill="#c5d9d7")
            sheet.save(args.output / (name + ".png"))
            outputs.append({"sheet": name + ".png", "input_sha256": inputs})
(args.output / "composition.json").write_text(json.dumps({"source": str(args.assets), "union_crop": crop, "scale": scale, "method": "Uniformly sized thumbnails of every native PNG; original images unchanged; no synthesized frames or poses.", "sheets": outputs}, indent=2) + "\n")
print("Created", len(outputs), "full-cycle contact sheets")

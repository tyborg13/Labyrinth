"""Inspected front back/wing and neck/thorax ownership correction.

Copies accepted registered pixels through the maintained segment/skin toolkit.
No source repaint, texture stretching, or new cover layer supplies the repair.
"""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw

CASE = Path(__file__).resolve().parent
sys.path.insert(0, str(CASE.parents[3] / "tools"))
from cutout_pipeline.assets import segment
from cutout_pipeline.cases import write_json

source = Image.open(CASE / "source/front_registered.png")
recipe = json.loads((CASE / "source/front_ownership.json").read_text())
owners = {}
for name, polygon in recipe["priority_polygons"]:
    mask = Image.new("1", (255, 255))
    ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=1)
    for y in range(255):
        for x in range(255):
            if source.getpixel((x, y))[3] and mask.getpixel((x, y)):
                owners.setdefault((x, y), name)
for override in recipe["pixel_overrides"]:
    owners[tuple(override["point"])] = override["name"]

transfers = [
    {"name": "thorax", "to": "torso", "from": ["neck", "wing_near"],
     "polygon": [[94, 125], [107, 117], [120, 121], [132, 119], [151, 111], [173, 117],
                 [171, 124], [166, 131], [153, 140], [134, 144], [112, 148], [93, 143]]},
    {"name": "back_fins", "to": "torso", "from": ["wing_near"],
     "polygon": [[142, 107], [174, 101], [177, 105], [157, 117], [145, 118]]},
    {"name": "tail_root", "to": "tail", "from": ["wing_near"],
     "polygon": [[179, 127], [194, 127], [211, 145], [214, 170], [194, 179], [190, 151], [182, 141], [175, 135]]},
]
for transfer in transfers:
    mask = Image.new("1", (255, 255))
    ImageDraw.Draw(mask).polygon([tuple(p) for p in transfer["polygon"]], fill=1)
    moved = []
    for point, owner in list(owners.items()):
        if owner in transfer["from"] and mask.getpixel(point):
            owners[point] = transfer["to"]
            moved.append(list(point))
            recipe["pixel_overrides"].append({"point": list(point), "name": transfer["to"]})
    transfer["pixels"] = moved
    transfer["count"] = len(moved)
write_json(CASE / "recipes/front_semantic_repair.json", {
    "reason": "Native release exposed back and tail paint attached to near wing; neck ownership extended into the thorax.",
    "transfers": transfers,
})
path = CASE / "source/front_ownership_v03.json"
write_json(path, recipe)
report = segment(CASE / "source/front_registered.png", path, CASE / "segmented/front_v03")
assert report["ok"]
layout = json.loads((CASE / "layouts/front.json").read_text())
old = {p["name"]: p for p in layout["parts"]}
paint = []
for part in report["parts"]:
    name = part["name"]
    part.update(file=f"segmented/front_v03/{name}.png", bone=old[name]["bone"], z_index=old[name]["z_index"], equipment_slot=old[name]["equipment_slot"])
    (CASE / (part["file"] + ".import")).write_text('[remap]\n\nimporter="keep"\n')
    paint.append(part)
paint.extend(p for p in layout["parts"] if p["name"] not in {p["name"] for p in report["parts"]})
layout["parts"] = paint
write_json(CASE / "layouts/front_repaired.json", layout)
skin = json.loads((CASE / "recipes/front_skin.json").read_text())
skin.update(input_layout="layouts/front_repaired.json", output_layout="layouts/front_repaired_skinned.json")
write_json(CASE / "recipes/front_repaired_skin.json", skin)
print({t["name"]: t["count"] for t in transfers})

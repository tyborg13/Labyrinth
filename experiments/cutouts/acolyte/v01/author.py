"""Dust Acolyte v01 ownership/registration recipe; no character paint is synthesized.

Run from the repository root after `cutout_workflow init`. The original front
is preserved byte-for-byte. Generated rear background exclusion is an explicit
source selection, followed by ONE whole-body registration. Semantic cuts use
the maintained segment command. Hidden socket pixels come from imagegen.
"""
from collections import deque
from pathlib import Path
import hashlib
import json
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
sys.path.insert(0, str(REPO / "tools"))
from cutout_pipeline.assets import skin_mesh


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def register():
    original = ROOT / "source/front_original.png"
    (ROOT / "source/front_registered.png").write_bytes(original.read_bytes())
    image = Image.open(ROOT / "source/rear_alpha_attempt.png").convert("RGBA")
    width, height = image.size
    pixels = image.load()
    background = set()
    queue = deque([(0, 0)])
    while queue:
        x, y = queue.popleft()
        if (x, y) in background or not (0 <= x < width and 0 <= y < height):
            continue
        r, g, b, _ = pixels[x, y]
        if min(r, g, b) < 65 or max(r, g, b) - min(r, g, b) > 26:
            continue
        background.add((x, y))
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    for point in background:
        pixels[point] = (0, 0, 0, 0)
    image.save(ROOT / "source/rear_selected_alpha.png")
    bbox = image.getbbox()
    crop = image.crop(bbox)
    scale = 215 / crop.height
    size = (round(crop.width * scale), 215)
    registered = Image.new("RGBA", (255, 255))
    registered.alpha_composite(crop.resize(size, Image.Resampling.NEAREST), (82, 20))
    registered.save(ROOT / "source/rear_registered.png")
    write(ROOT / "recipes/registration.json", {
        "front": {"source": "source/front_original.png", "operation": "byte-identical copy", "sha256": sha(original)},
        "rear": {"source": "source/rear_alpha_attempt.png", "sha256": sha(ROOT / "source/rear_alpha_attempt.png"),
                 "background_selection": "4-connected flood from (0,0), min RGB >=65 and RGB spread <=26; two generator outputs supplied opaque RGB checkerboard",
                 "excluded_pixels": len(background), "crop": list(bbox), "uniform_scale": scale,
                 "rounded_size": size, "resample": "nearest", "offset": [82, 20],
                 "landmarks": "hood top y20; hem bottom y234; grounded robe center x140, matching accepted front"}})


FRONT = [
    ["orb", [[50, 59], [96, 59], [96, 93], [50, 93]]],
    ["cast_hand", [[50, 93], [85, 93], [85, 103], [86, 107], [85, 119], [68, 119], [50, 111]]],
    ["rest_hand", [[120, 112], [136, 112], [145, 119], [144, 130], [139, 136], [121, 133], [117, 126]]],
    ["cast_sleeve", [[99, 90], [108, 99], [107, 119], [103, 141], [98, 153], [91, 157], [83, 162], [73, 153], [69, 124], [73, 113], [80, 104], [90, 104], [94, 95]]],
    ["rest_sleeve", [[158, 85], [168, 86], [184, 105], [184, 124], [175, 140], [163, 159], [156, 173], [144, 172], [141, 140], [141, 129], [143, 118], [137, 112], [149, 106]]],
    ["hood", [[97, 15], [163, 15], [167, 69], [157, 78], [146, 77], [126, 83], [111, 80], [97, 77]]],
    ["robe_l", [[55, 134], [139, 134], [139, 240], [55, 240]]],
    ["robe_r", [[140, 134], [205, 134], [210, 240], [140, 240]]],
    ["torso", [[92, 70], [181, 70], [185, 95], [180, 134], [80, 134], [85, 103]]],
]
# Rear is separately authored; coordinates are not mirrored front anatomy.
REAR = [
    ["orb", [[188, 62], [222, 62], [222, 92], [188, 92]]],
    ["cast_hand", [[192, 94], [222, 88], [224, 113], [194, 116]]],
    ["cast_sleeve", [[161, 84], [174, 89], [180, 100], [194, 101], [201, 101], [201, 132], [190, 164], [180, 159], [165, 145], [158, 116]]],
    ["rest_sleeve", [[110, 90], [118, 99], [118, 123], [116, 150], [106, 143], [97, 130], [98, 105]]],
    ["hood", [[108, 17], [175, 17], [177, 73], [164, 76], [141, 78], [111, 74], [105, 67]]],
    ["robe_l", [[75, 130], [139, 130], [139, 240], [75, 240]]],
    ["robe_r", [[140, 130], [205, 130], [211, 240], [140, 240]]],
    ["torso", [[100, 70], [179, 70], [182, 99], [176, 132], [101, 132], [99, 92]]],
]


def build(facing, polygons):
    ownership = ROOT / f"source/{facing}_ownership.json"
    write(ownership, {"priority_polygons": polygons, "pixel_overrides": []})
    output = ROOT / f"segmented/{facing}"
    if output.exists():
        raise SystemExit(f"Refusing to overwrite semantic segmentation: {output}")
    subprocess.run([sys.executable, str(REPO / "tools/cutout_workflow.py"), "segment", "--source", str(ROOT / f"source/{facing}_registered.png"), "--ownership", str(ownership), "--output", str(output)], check=True, stdout=subprocess.DEVNULL)
    front = facing == "front"
    joints = {
        "root": {"position": [140, 230], "parent": None},
        "torso": {"position": [130, 134] if front else [141, 130], "parent": "root"},
        "hood": {"position": [130, 76] if front else [143, 74], "parent": "torso"},
        "cast_hand": {"position": [82, 113] if front else [196, 109], "parent": "torso"},
        "orb": {"position": [74, 78] if front else [204, 78], "parent": "cast_hand"},
        "rest_hand": {"position": [135, 123] if front else [109, 127], "parent": "torso"},
        "hem_l": {"position": [125, 233] if front else [132, 234], "parent": "root"},
        "hem_r": {"position": [160, 233] if front else [151, 234], "parent": "root"},
    }
    layers = {"robe_l": 0, "robe_r": 1, "cast_sleeve": 3 if front else 5, "rest_sleeve": 5 if front else 1, "torso": 4, "hood": 6, "cast_hand": 7, "rest_hand": 7, "orb": 8}
    owners = {"robe_l": "torso", "robe_r": "torso", "cast_sleeve": "cast_hand", "rest_sleeve": "torso", "hood": "hood", "torso": "torso", "cast_hand": "cast_hand", "rest_hand": "rest_hand", "orb": "orb"}
    parts = []
    for part in json.loads((output / "segmentation.json").read_text())["parts"]:
        part.update(file=f"segmented/{facing}/{part['file']}", bone=owners[part["name"]], z_index=layers[part["name"]], equipment_slot="robe" if part["name"].startswith("robe") else "")
        parts.append(part)
    # A tiny shoulder socket beneath the real seam. Only interior generated
    # cloth is selected; no transparent exterior or painted checker survives.
    fill = Image.open(ROOT / "source/hidden_sleeve_generated.png").convert("RGBA")
    fill_box = [520, 490, 680, 690]
    socket = fill.crop(fill_box).resize((16, 20), Image.Resampling.NEAREST)
    socket_offset = [94, 100] if front else [157, 97]
    # Limit to fully opaque existing interior: rest source reconstruction stays exact.
    source = Image.open(ROOT / f"source/{facing}_registered.png")
    for y in range(20):
        for x in range(16):
            px, py = socket_offset[0] + x, socket_offset[1] + y
            if source.getpixel((px, py))[3] != 255:
                socket.putpixel((x, y), (0, 0, 0, 0))
    destination = ROOT / f"assets/{facing}/shoulder_socket.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    socket.save(destination)
    parts.append({"name": "shoulder_socket", "file": f"assets/{facing}/shoulder_socket.png", "offset": socket_offset, "bone": "torso", "z_index": 2 if front else 3})
    layout = {"canvas_size": [255, 255], "facing": facing, "joints": joints, "parts": parts,
              "landmarks": {"sole_l": joints["hem_l"]["position"], "sole_r": joints["hem_r"]["position"], "cast_socket": joints["orb"]["position"],
                            "support_note": "Boots/legs are fully concealed in accepted paint. Support points are robe hem contacts, not invented visible feet."}}
    write(ROOT / f"layouts/{facing}.json", layout)
    fields = [{"name": f"{facing}_cast_sleeve", "parts": ["cast_sleeve"], "bones": ["torso", "cast_hand"], "grid": [2, 2],
               "bands": [{"center": [98, 110] if front else [173, 110], "axis": [-1, 0] if front else [1, 0], "width": 18}]}]
    write(ROOT / f"recipes/{facing}_sleeve.json", {"facing": facing, "input_layout": f"layouts/{facing}.json", "output_layout": f"layouts/{facing}_sleeved.json", "fields": fields})
    subprocess.run([sys.executable, str(REPO / "tools/cutout_workflow.py"), "skin", str(ROOT), "--recipe", str(ROOT / f"recipes/{facing}_sleeve.json")], check=True, stdout=subprocess.DEVNULL)
    # Each skirt panel has the same vertical blend but one support owner.
    # This preserves each painted row's width when the lower panels cross.
    layout = json.loads((ROOT / f"layouts/{facing}_sleeved.json").read_text())
    for side in ("l", "r"):
        robe = next(p for p in parts if p["name"] == "robe_" + side)
        layout["joint_meshes"].append(skin_mesh(robe, Image.open(ROOT / robe["file"]).size,
            {"name": f"{facing}_robe_{side}", "bones": ["torso", "hem_" + side],
             "bands": [{"center": [140, 181], "axis": [0,1], "width": 70}], "grid": [2,2]}))
    under = fill.crop((480, 430, 730, 930)).resize((45, 90), Image.Resampling.NEAREST)
    offset = [118, 139]
    for y in range(90):
        for x in range(45):
            px, py = offset[0]+x, offset[1]+y
            if source.getpixel((px,py))[3] != 255 or py >= 227:
                under.putpixel((x,y), (0,0,0,0))
    under.save(ROOT / f"assets/{facing}/underrobe.png")
    layout["parts"].append({"name":"underrobe", "file":f"assets/{facing}/underrobe.png", "offset":offset, "bone":"torso", "z_index":-1, "equipment_slot":"robe"})
    write(ROOT / f"layouts/{facing}_skinned.json", layout)
    write(ROOT / f"recipes/{facing}_robe.json", {"source_layout": f"layouts/{facing}_sleeved.json", "grid": [2, 2],
        "panels": {"robe_l":"torso to hem_l", "robe_r":"torso to hem_r"},
        "weights":"smoothstep over y146..216; constant at each horizontal source row to preserve panel width",
        "underrobe":{"source":"source/hidden_sleeve_generated.png", "crop":[480,430,730,930], "size":[45,90], "uniform_scale":0.18, "offset":offset, "mask":"existing source fully opaque pixels; bottom y226", "owner":"torso", "purpose":"concealed cloth behind separating panels, below both source-painted skirts"},
        "shoulder_socket": {"generated_source": "source/hidden_sleeve_generated.png", "crop": fill_box, "size": [16,20], "offset": socket_offset, "mask": "existing source fully opaque pixels only", "owner": "torso"}})



if __name__ == "__main__":
    register()
    build("front", FRONT)
    build("rear", REAR)
    config_path = ROOT / "cutout.json"
    config = json.loads(config_path.read_text())
    config["layouts"] = {f: f"layouts/{f}_skinned.json" for f in ("front", "rear")}
    config["clips"] = {
        "idle": {"frames": 24, "duration": 1.8, "loop": True, "preview_cycles": 2},
        "walk": {"frames": 36, "duration": 0.72, "loop": True, "preview_cycles": 2, "travel": "motion"},
        "dust_bolt": {"frames": 40, "duration": 1.2, "loop": False},
        "siphon": {"frames": 40, "duration": 1.2, "loop": False},
    }
    config["rigid_bones"] = ["hood", "cast_hand", "rest_hand", "hem_l", "hem_r"]
    config["contact_feet"] = ["hem_l", "hem_r"]
    config["source_baseline"] = {"kind": "new_character", "accepted_front_sha256": sha(ROOT / "source/front_original.png"), "art_status": "registered and segmented; native review pending"}
    config["sources"] = sorted(str(p.relative_to(ROOT)) for group in ("source", "recipes") for p in (ROOT / group).rglob("*") if p.is_file() and not p.name.endswith(".import")) + ["author.py", "layouts/front.json", "layouts/rear.json", "layouts/front_sleeved.json", "layouts/rear_sleeved.json"]
    write(config_path, config)
    for path in ROOT.rglob("*.png"):
        Path(str(path) + ".import").write_text('[remap]\n\nimporter="keep"\n')

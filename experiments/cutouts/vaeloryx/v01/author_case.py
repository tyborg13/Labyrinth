"""Vaeloryx v01's explicit source-space ownership and registration recipe.

This case starts with cutout_workflow init. This recipe only copies existing
paint and describes topology; it never generates or paints anatomy. Run from
the repository root. Native proof is always produced by cutout_workflow render.
"""
from pathlib import Path
import json
import sys

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT / "tools"))
from cutout_pipeline.assets import segment
from cutout_pipeline.cases import write_json

CASE = Path(__file__).resolve().parent

OWNERSHIP = {
    "front": [
        ["claw_near", [[116, 164], [139, 165], [145, 186], [124, 197], [107, 184]]],
        ["claw_far", [[48, 160], [69, 160], [78, 176], [74, 189], [46, 190], [39, 174]]],
        ["claw_hind", [[153, 159], [177, 156], [182, 172], [163, 181], [147, 174]]],
        ["arm_near", [[138, 126], [155, 134], [149, 147], [136, 168], [122, 176], [113, 166], [123, 149]]],
        ["arm_far", [[93, 135], [111, 142], [102, 151], [79, 170], [63, 173], [56, 164], [75, 150]]],
        ["hind_limb", [[157, 135], [177, 143], [183, 157], [177, 169], [160, 174], [148, 154]]],
        ["head", [[58, 129], [62, 140], [68, 148], [77, 130], [89, 118], [104, 109], [115, 94], [121, 80], [114, 69], [105, 76], [98, 98], [80, 111], [73, 123]]],
        ["wing_near", [[157, 12], [255, 12], [255, 187], [216, 183], [200, 158], [185, 137], [164, 125], [147, 142], [129, 132], [127, 108], [142, 86], [155, 55]]],
        ["wing_far", [[0, 0], [117, 0], [114, 39], [108, 59], [108, 78], [108, 96], [100, 105], [86, 116], [78, 132], [73, 152], [45, 181], [0, 175]]],
        ["neck", [[104, 39], [159, 35], [157, 93], [138, 112], [143, 135], [119, 149], [95, 143], [94, 115], [103, 88]]],
        ["tail", [[170, 128], [207, 142], [223, 176], [225, 243], [50, 243], [50, 186], [74, 165], [107, 162], [114, 185], [142, 192], [169, 185], [184, 172], [178, 153]]],
        ["torso", [[92, 103], [153, 96], [179, 116], [185, 147], [161, 173], [109, 159], [83, 147], [82, 126]]],
    ],
    "rear": [
        ["claw_near", [[130, 157], [150, 158], [160, 175], [149, 185], [129, 180], [126, 167]]],
        ["claw_far", [[166, 149], [181, 149], [188, 165], [177, 173], [162, 165]]],
        ["claw_hind", [[82, 156], [101, 151], [106, 169], [95, 179], [80, 173]]],
        ["arm_near", [[116, 137], [132, 137], [138, 150], [148, 163], [135, 172], [122, 158], [112, 146]]],
        ["arm_far", [[148, 134], [160, 132], [169, 142], [181, 151], [176, 163], [163, 155], [148, 149]]],
        ["hind_limb", [[96, 139], [112, 148], [107, 160], [96, 168], [84, 165], [84, 149]]],
        ["head", [[115, 48], [153, 42], [173, 61], [174, 100], [153, 117], [133, 111], [139, 96], [122, 89], [110, 79]]],
        ["wing_near", [[154, 20], [255, 20], [255, 209], [202, 215], [191, 185], [189, 156], [164, 146], [159, 124], [164, 94], [158, 63]]],
        ["wing_far", [[0, 0], [139, 0], [130, 64], [122, 88], [131, 111], [118, 128], [100, 140], [77, 142], [61, 154], [0, 177]]],
        ["neck", [[126, 87], [158, 100], [165, 143], [145, 155], [126, 133], [116, 123]]],
        ["tail", [[90, 119], [122, 123], [118, 144], [112, 160], [117, 177], [158, 171], [195, 179], [203, 243], [35, 243], [37, 156], [57, 130]]],
        ["torso", [[86, 115], [137, 109], [155, 123], [166, 147], [146, 160], [110, 153], [81, 143]]],
    ],
}

POSITIONS = {
    "front": {
        "root": [128, 165], "body": [134, 135], "neck": [115, 115], "head": [109, 91],
        "wing_far": [109, 102], "wing_near": [141, 128],
        "arm_far": [99, 142], "claw_far": [64, 165],
        "arm_near": [141, 140], "claw_near": [126, 170],
        "hind_limb": [164, 147], "claw_hind": [165, 166],
        "tail_base": [177, 143], "tail_mid": [191, 183], "tail_tip": [122, 209],
    },
    "rear": {
        "root": [128, 165], "body": [126, 134], "neck": [144, 122], "head": [141, 95],
        "wing_far": [124, 118], "wing_near": [157, 119],
        "arm_far": [154, 141], "claw_far": [173, 156],
        "arm_near": [121, 145], "claw_near": [139, 167],
        "hind_limb": [103, 147], "claw_hind": [93, 161],
        "tail_base": [105, 141], "tail_mid": [74, 180], "tail_tip": [122, 206],
    },
}

PARENTS = {"root": None, "body": "root", "neck": "body", "head": "neck",
           "wing_far": "body", "wing_near": "body", "arm_far": "body",
           "claw_far": "arm_far", "arm_near": "body", "claw_near": "arm_near",
           "hind_limb": "body", "claw_hind": "hind_limb", "tail_base": "body",
           "tail_mid": "tail_base", "tail_tip": "tail_mid"}

LAYERS = {"wing_far": 0, "claw_hind": 1, "hind_limb": 1, "tail": 2,
          "arm_far": 3, "claw_far": 3, "torso": 5, "neck": 6, "head": 7,
          "wing_near": 8, "arm_near": 9, "claw_near": 10}

# These are inspected contour transfers from the first explicit split. They
# assign wing hooks, trailing claws and tail fins, never leftover torso paint.
CONTOUR_RULES = {
    "front": [([130, 10, 165, 40], "wing_near"), ([75, 120, 84, 153], "head"),
              ([85, 152, 107, 165], "tail"), ([108, 157, 119, 176], "claw_near"),
              ([138, 164, 149, 183], "claw_near"), ([149, 160, 215, 195], "tail"),
              ([137, 185, 150, 195], "tail")],
    "rear": [([140, 20, 160, 48], "wing_near"), ([120, 88, 127, 94], "head"),
             ([110, 152, 128, 163], "arm_near"), ([110, 164, 128, 183], "claw_near"),
             ([149, 151, 163, 166], "arm_far"), ([163, 149, 184, 180], "claw_far"),
             ([184, 149, 196, 184], "wing_near"), ([10, 180, 35, 200], "tail")],
}


def hidden_caps(facing, layout):
    """Register generated interior scales only below opaque source pixels."""
    source = Image.open(CASE / "source/front_underbody_generated.png").convert("RGBA")
    original = Image.open(CASE / ("source/" + facing + "_registered.png")).convert("RGBA")
    # Anatomically neutral concealed scales, sampled from continuous chest,
    # shoulder and elbow surfaces. No checkerboard or new visible source paint.
    definitions = [
        ("wing_socket_far", "body", "wing_far", (500, 565, 596, 661), (26, 26)),
        ("wing_socket_near", "body", "wing_near", (597, 543, 693, 639), (26, 26)),
        ("arm_cap_far", "arm_far", "arm_far", (439, 677, 507, 745), (14, 14)),
        ("arm_cap_near", "arm_near", "arm_near", (657, 633, 737, 713), (18, 18)),
        ("hind_cap", "hind_limb", "hind_limb", (776, 676, 856, 756), (18, 18)),
    ]
    records = []
    for name, bone, anchor, crop, size in definitions:
        point = POSITIONS[facing][anchor]
        offset = [round(point[0] - size[0] / 2), round(point[1] - size[1] / 2)]
        patch = source.crop(crop).resize(size, Image.Resampling.LANCZOS)
        # Crop lies wholly within generated scales. Alpha comes from explicit
        # concealed coverage, constrained to full opacity in the accepted rest.
        coverage = Image.new("L", size, 0)
        ImageDraw.Draw(coverage).ellipse((0, 0, size[0] - 1, size[1] - 1), fill=255)
        for y in range(size[1]):
            for x in range(size[0]):
                alpha = original.getpixel((x + offset[0], y + offset[1]))[3]
                if (alpha != 255 if facing == "front" else alpha < 240):
                    coverage.putpixel((x, y), 0)
        patch.putalpha(coverage)
        path = CASE / f"assets/{facing}/{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        patch.save(path)
        Path(str(path) + ".import").write_text('[remap]\n\nimporter="keep"\n')
        layout["parts"].append({"name": name, "file": str(path.relative_to(CASE)), "offset": offset,
                                "bone": bone, "z_index": -2, "equipment_slot": "hidden_joint"})
        records.append({"name": name, "source": "source/front_underbody_generated.png", "crop": list(crop),
                        "target_size": list(size), "offset": offset, "bone": bone,
                        "alpha_recipe": "ellipse intersect front alpha==255 (exactly occluded) or rear alpha>=240 (generated near-opaque interior)",
                        "opaque_pixels": sum(a == 255 for a in coverage.getdata())})
    return records


def main():
    for facing, polygons in OWNERSHIP.items():
        path = CASE / "source" / (facing + "_ownership.json")
        first = json.loads((CASE / "segmented" / facing / "segmentation.json").read_text())
        overrides = []
        for x, y in first["unassigned_coordinates"]:
            match = next((name for (x0, y0, x1, y1), name in CONTOUR_RULES[facing] if x0 <= x <= x1 and y0 <= y <= y1), None)
            if match is None:
                raise ValueError((facing, "Unreviewed contour pixel", x, y))
            overrides.append({"point": [x, y], "name": match})
        write_json(path, {"priority_polygons": polygons, "pixel_overrides": overrides,
                         "registration": "255px whole-source coordinates, first owner wins"})
        folder = facing + "_v02"
        report = segment(CASE / "source" / (facing + "_registered.png"), path, CASE / "segmented" / folder)
        print(facing, "unassigned", report["unassigned_pixels"], report["unassigned_coordinates"][:40])
        layout = {"version": 1, "facing": facing, "canvas_size": [255, 255],
                  "joints": {name: {"parent": PARENTS[name], "position": point}
                             for name, point in POSITIONS[facing].items()}, "parts": [], "joint_meshes": []}
        for part in report["parts"]:
            name = part["name"]
            part.update(file=f"segmented/{folder}/{name}.png", bone={"torso": "body", "tail": "tail_base"}.get(name, name),
                        z_index=LAYERS[name], equipment_slot="wing" if name.startswith("wing_") else "body")
            layout["parts"].append(part)
            (CASE / (part["file"] + ".import")).write_text('[remap]\n\nimporter="keep"\n')
        hidden = hidden_caps(facing, layout)
        write_json(CASE / "recipes" / (facing + "_hidden.json"), hidden)
        write_json(CASE / "layouts" / (facing + ".json"), layout)
    write_json(CASE / "recipes" / "anatomy.json", {
        "kind": "15-joint serpentine winged dragon; coherent airborne contact model",
        "projection": "2:1; front travels down-left, rear travels up-right; reflections supply other two lanes",
        "landmarks": POSITIONS,
        "uncertainty": "Front cranial surface is largely occluded by the far wing; rear head is occluded by the near wing. Hidden shoulder/neck material is used only beneath source-owned pixels.",
        "ownership": "The wings, cranial surface, neck, torso, each forelimb and its rigid claws, tucked hindlimb and claws, and curled tail have separate semantic owners. No unassigned-pixel sweep is permitted.",
    })


if __name__ == "__main__":
    main()

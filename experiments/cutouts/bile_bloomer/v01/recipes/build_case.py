"""Shale Bloomer v01 registration/ownership; copies paint, never synthesizes it.

Run only for this fresh case. Native rendering remains cutout_workflow.py's job.
The maintained segment and skin commands own extraction and mesh construction.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
from PIL import Image, ImageDraw

CASE = Path(__file__).resolve().parents[1]
REPO = CASE.parents[3]
if len(sys.argv) != 2:
    raise SystemExit("Usage: build_case.py <new integer revision>; existing revisions are retained")
REVISION = "r%02d" % int(sys.argv[1])


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cli(*arguments):
    result = subprocess.run([sys.executable, str(REPO / "tools/cutout_workflow.py"), *map(str, arguments)], cwd=REPO, capture_output=True, text=True)
    if result.returncode:
        try:
            report = json.loads(result.stdout)
            print({"ok": report.get("ok"), "unassigned_pixels": report.get("unassigned_pixels"), "first_unassigned": report.get("unassigned_coordinates", [])[:20]})
        except ValueError:
            print(result.stdout[-2000:])
        raise RuntimeError(result.stderr or "cutout command failed")
    print(arguments[0], arguments[-1], "PASS")


def build():
    config = json.loads((CASE / "cutout.json").read_text())
    ownership = {
        "front": [
            ["core", [[93, 39], [99, 40], [101, 33], [105, 32], [109, 35], [113, 32], [118, 30], [121, 34], [125, 35], [129, 32], [133, 30], [136, 35], [137, 37], [142, 34], [146, 36], [150, 41], [151, 49], [147, 52], [140, 54], [133, 54], [129, 57], [126, 60], [121, 64], [115, 64], [109, 61], [105, 60], [103, 58], [97, 57], [94, 52], [94, 48], [91, 44]]],
            ["petal_near_l", [[69, 49], [87, 47], [105, 56], [123, 64], [123, 76], [113, 86], [91, 75], [80, 66]]],
            ["petal_near_r", [[122, 63], [144, 53], [166, 46], [177, 49], [161, 67], [145, 79], [124, 86], [118, 79]]],
            ["petal_near_r", [[123, 62], [128, 56], [133, 54], [141, 53], [143, 58], [131, 65]]],
            ["petal_far_l", [[50, 0], [127, 0], [125, 38], [107, 43], [97, 54], [76, 56], [51, 45]]],
            ["petal_far_r", [[125, 0], [193, 0], [196, 44], [171, 55], [147, 57], [124, 39]]],
            ["petal_near_l", [[55, 42], [92, 45], [107, 53], [117, 79], [106, 87], [72, 75]]],
            ["petal_near_r", [[142, 45], [191, 43], [174, 82], [146, 91], [123, 85]]],
            ["tendril_high_l", [[51, 59], [74, 65], [80, 90], [74, 111], [58, 114], [49, 97], [49, 78]]],
            ["tendril_high_r", [[171, 49], [210, 52], [209, 83], [201, 109], [185, 106], [183, 87], [170, 77]]],
            ["trunk", [[59, 135], [67, 132], [68, 153], [59, 151]]],
            ["tendril_mid_l", [[20, 96], [52, 94], [50, 118], [66, 132], [63, 152], [44, 148], [20, 129]]],
            ["tendril_low_l", [[18, 146], [54, 142], [43, 161], [40, 174], [51, 181], [66, 174], [74, 181], [63, 195], [35, 204], [17, 188]]],
            ["tendril_low_r", [[200, 116], [239, 105], [243, 196], [219, 205], [196, 194], [190, 182], [208, 176], [216, 159], [204, 140]]],
            ["root_tip_l", [[19, 226], [119, 226], [122, 255], [18, 255]]],
            ["root_tip_r", [[147, 225], [242, 225], [245, 255], [144, 255]]],
            ["root_tip_c", [[113, 215], [139, 215], [146, 246], [117, 247]]],
            ["root_stem_l", [[21, 199], [74, 193], [97, 182], [114, 176], [109, 193], [109, 207], [119, 223], [120, 228], [20, 229]]],
            ["root_stem_r", [[139, 194], [148, 180], [162, 175], [169, 191], [181, 199], [204, 200], [243, 206], [243, 227], [148, 228], [136, 210]]],
            ["root_stem_c", [[111, 194], [140, 192], [152, 213], [142, 225], [115, 225]]],
            ["trunk", [[46, 72], [103, 76], [129, 78], [158, 75], [199, 89], [222, 160], [210, 202], [178, 224], [148, 241], [115, 239], [52, 219], [35, 187], [40, 119]]],
        ],
        "rear": [
            ["core", [[110, 37], [114, 39], [117, 35], [121, 35], [124, 32], [128, 33], [131, 33], [132, 30], [136, 28], [139, 29], [142, 34], [141, 37], [138, 38], [135, 38], [132, 40], [128, 42], [126, 43], [123, 46], [122, 49], [118, 47], [115, 45], [113, 43], [114, 41], [110, 40]]],
            ["petal_near_l", [[71, 34], [95, 35], [117, 45], [128, 51], [120, 70], [110, 88], [92, 76], [82, 58]]],
            ["petal_near_r", [[120, 44], [137, 31], [147, 42], [169, 42], [178, 52], [159, 67], [144, 82], [128, 82], [117, 67]]],
            ["petal_far_l", [[49, 0], [127, 0], [127, 33], [111, 41], [94, 45], [70, 42], [49, 32]]],
            ["petal_far_r", [[124, 0], [201, 0], [203, 44], [175, 55], [149, 48], [126, 35]]],
            ["petal_near_l", [[51, 26], [76, 30], [91, 53], [104, 74], [85, 75], [64, 54]]],
            ["petal_near_r", [[142, 39], [205, 37], [195, 57], [171, 69], [149, 79]]],
            ["trunk", [[75, 74], [87, 72], [86, 98], [74, 103]]],
            ["tendril_high_l", [[44, 48], [72, 48], [77, 64], [83, 86], [72, 102], [59, 102], [49, 84]]],
            ["tendril_high_r", [[169, 57], [206, 56], [211, 89], [201, 121], [184, 125], [173, 108], [183, 86], [173, 78]]],
            ["tendril_mid_r", [[204, 93], [239, 92], [244, 132], [225, 156], [203, 165], [193, 149], [209, 131], [210, 113]]],
            ["tendril_mid_r", [[203, 100], [216, 99], [216, 137], [202, 144]]],
            ["tendril_low_l", [[15, 102], [49, 103], [54, 123], [44, 145], [47, 162], [63, 170], [65, 184], [39, 194], [15, 181]]],
            ["tendril_low_r", [[202, 141], [240, 141], [242, 195], [217, 203], [194, 193], [185, 176], [192, 171], [214, 178], [214, 161]]],
            ["tendril_low_r", [[198, 150], [219, 157], [218, 182], [216, 204], [192, 198]]],
            ["root_tip_l", [[16, 225], [109, 225], [111, 255], [14, 255]]],
            ["root_tip_r", [[127, 226], [241, 226], [244, 255], [124, 255]]],
            ["root_tip_c", [[106, 210], [133, 210], [133, 232], [104, 232]]],
            ["root_stem_l", [[65, 148], [84, 139], [92, 143], [78, 163], [77, 187], [100, 211], [110, 227], [18, 228], [19, 196], [61, 187]]],
            ["root_stem_r", [[151, 167], [161, 160], [174, 177], [183, 196], [234, 207], [241, 228], [126, 229], [137, 215], [149, 203], [146, 186]]],
            ["root_stem_c", [[103, 181], [132, 183], [143, 201], [135, 217], [105, 218]]],
            ["trunk", [[56, 67], [104, 72], [138, 68], [172, 70], [201, 115], [214, 172], [192, 203], [172, 222], [136, 236], [101, 234], [39, 211], [35, 172], [42, 107]]],
        ],
    }
    for facing in ["front", "rear"]:
        source = CASE / "source" / (facing + "_registered.png")
        path = CASE / "source" / (facing + "_ownership_" + REVISION + ".json")
        overrides = [{"point": point, "name": "petal_near_l"} for point in ([[60, 61], [61, 61], [63, 62]] if facing == "front" else [[54, 35], [55, 36], [55, 37], [56, 38], [57, 40]])]
        if facing == "rear":
            overrides += [{"point": point, "name": "core"} for point in [[112, 41], [113, 41], [111, 42], [112, 42], [113, 42]]]
        write(path, {"priority_polygons": ownership[facing], "pixel_overrides": overrides, "policy": "First explicit semantic owner wins. No catch-all sweep; unassigned visible pixels fail."})
        out = CASE / "segmented" / (facing + "_" + REVISION)
        cli("segment", "--source", source, "--ownership", path, "--output", out)
        report = json.loads((out / "segmentation.json").read_text())
        joints = {"root": {"parent": None, "position": [127, 223]}, "trunk": {"parent": "root", "position": [127, 176]}, "bloom": {"parent": "trunk", "position": [126, 76]}, "core": {"parent": "bloom", "position": [124, 48 if facing == "front" else 37]}}
        joints["hidden_calyx"] = {"parent": "bloom", "position": [126, 76]}
        joints["hidden_roots"] = {"parent": "trunk", "position": [127, 176]}
        positions = {"front": {"petal_near_l": [111, 64], "petal_near_r": [134, 64], "petal_far_l": [107, 48], "petal_far_r": [143, 47], "tendril_high_l": [72, 107], "tendril_high_r": [187, 95], "tendril_mid_l": [59, 139], "tendril_low_l": [62, 184], "tendril_low_r": [199, 184], "root_l": [98, 237], "root_r": [190, 237], "root_c": [128, 223]},
                     "rear": {"petal_near_l": [113, 64], "petal_near_r": [134, 62], "petal_far_l": [108, 41], "petal_far_r": [146, 43], "tendril_high_l": [74, 93], "tendril_high_r": [186, 109], "tendril_mid_r": [204, 149], "tendril_low_l": [60, 179], "tendril_low_r": [197, 186], "root_l": [86, 237], "root_r": [158, 239], "root_c": [119, 219]}}[facing]
        for name, point in positions.items():
            joints[name] = {"parent": "bloom" if name.startswith("petal") else "trunk", "position": point}
        parts = []
        for part in report["parts"]:
            name = part["name"]
            bone = name
            if name.startswith("root_tip_"):
                bone = "root_" + name[-1]
            elif name.startswith("root_stem_"):
                bone = "trunk"
            z = 10 if name == "trunk" else 23 if name == "core" else 24 if name.startswith("petal_near") else 21 if name.startswith("petal_far") else 4 if name.startswith("tendril_high") or name.startswith("tendril_mid") else 8 if name.startswith("tendril_low") else 12
            parts.append({**part, "file": str(out.relative_to(CASE)) + "/" + part["file"], "bone": bone, "z_index": z})
        # Select only concealed crown pixels; the accepted front is mostly alpha
        # 252..253, so this donor is hidden by the sampler outside opened attacks.
        donor = Image.open(CASE / "source/hidden_calyx_owned.png").convert("RGBA")
        insert = Image.new("RGBA", (255, 255))
        # Uniform source transform. Original hidden source landmarks: core=(600,245), collar=(600,380).
        scale = 0.15
        dx, dy = 34, 10 if facing == "front" else -2
        resized = donor.resize((round(donor.width * scale), round(donor.height * scale)), Image.Resampling.NEAREST)
        insert.paste(resized, (dx, dy))
        mask = Image.new("1", (255, 255))
        polygon = [[101, 34], [142, 31], [153, 46], [143, 68], [133, 81], [113, 81], [101, 59]] if facing == "front" else [[103, 25], [142, 25], [153, 42], [142, 67], [132, 79], [114, 78], [102, 48]]
        ImageDraw.Draw(mask).polygon(polygon, fill=1)
        original = Image.open(source)
        owned = Image.new("RGBA", original.size)
        for y in range(255):
            for x in range(255):
                if mask.getpixel((x, y)) and original.getpixel((x, y))[3] >= 250:
                    owned.putpixel((x, y), insert.getpixel((x, y)))
        bounds = owned.getbbox()
        target = CASE / "assets" / facing / "hidden_calyx.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        owned.crop(bounds).save(target)
        parts.append({"name": "hidden_calyx", "file": "assets/" + facing + "/hidden_calyx.png", "offset": list(bounds[:2]), "bone": "hidden_calyx", "z_index": 19})
        write(CASE / "recipes" / (facing + "_hidden_registration.json"), {"source": "source/hidden_calyx_generated.png", "source_sha256": sha(CASE / "source/hidden_calyx_generated.png"), "uniform_scale": scale, "offset": [dx, dy], "source_landmarks": {"core": [600, 245], "collar": [600, 380]}, "ownership_polygon": polygon, "additional_mask": "Only pixels behind alpha>=250 accepted source paint; visible only during opened attack, original paint above this fill", "result_bbox": bounds, "resampler": "nearest"})
        root_donor = Image.open(CASE / "source/hidden_roots_owned.png").convert("RGBA")
        root_registered = root_donor.resize((255, 255), Image.Resampling.NEAREST)
        root_mask = Image.new("1", (255, 255))
        root_polygon = [[87, 181], [105, 173], [117, 192], [139, 182], [160, 170], [170, 183], [167, 215], [147, 220], [130, 220], [108, 217], [90, 211]]
        ImageDraw.Draw(root_mask).polygon(root_polygon, fill=1)
        root_insert = Image.new("RGBA", (255, 255))
        for y in range(255):
            for x in range(255):
                if root_mask.getpixel((x, y)) and original.getpixel((x, y))[3] >= 250:
                    root_insert.putpixel((x, y), root_registered.getpixel((x, y)))
        root_bounds = root_insert.getbbox()
        root_insert.crop(root_bounds).save(target.parent / "hidden_roots.png")
        parts.append({"name": "hidden_roots", "file": "assets/" + facing + "/hidden_roots.png", "offset": list(root_bounds[:2]), "bone": "hidden_roots", "z_index": 9})
        write(CASE / "recipes" / (facing + "_hidden_roots_registration.json"), {"source": "source/hidden_roots_generated.png", "source_sha256": sha(CASE / "source/hidden_roots_generated.png"), "uniform_scale": 255 / root_donor.width, "offset": [0, 0], "ownership_polygon": root_polygon, "additional_mask": "Original alpha>=250; donor stays behind the trunk/root owners and appears only in moving-root gaps", "result_bbox": root_bounds, "resampler": "nearest"})
        layout = {"canvas_size": [255, 255], "facing": facing, "joints": joints, "parts": parts, "landmarks": {"sole_l": [positions["root_l"][0], 249], "sole_r": [positions["root_r"][0], 249], "sole_c": [positions["root_c"][0], 227], "bloom_muzzle": joints["core"]["position"]}}
        layout_stem = facing + "_" + REVISION
        write(CASE / "layouts" / (layout_stem + ".json"), layout)
        fields = []
        for side in ["l", "c", "r"]:
            # The lateral stem silhouettes meet the rigid trunk through y=210.
            # Keep that whole attachment fixed, then blend to the rigid toes
            # before their first owned row. Blending across the attachment
            # pulls a rectangular seam open during the root's return stroke.
            center = 218 if side != "c" else 205 if facing == "front" else 200
            width = 14 if side != "c" else 20
            fields.append({"name": "root_" + side, "parts": ["root_stem_" + side], "bones": ["trunk", "root_" + side], "grid": [2, 1], "bands": [{"center": [positions["root_" + side][0], center], "axis": [0, 1], "width": width}]})
        recipe = {"facing": facing, "input_layout": "layouts/" + layout_stem + ".json", "output_layout": "layouts/" + layout_stem + "_skinned.json", "fields": fields}
        write(CASE / "recipes" / (layout_stem + "_skin_input.json"), recipe)
        cli("skin", CASE, "--recipe", CASE / "recipes" / (layout_stem + "_skin_input.json"))
    config = json.loads((CASE / "cutout.json").read_text())
    config["clips"] = {"idle": {"frames": 24, "duration": 1.8, "loop": True, "preview_cycles": 2}, "walk": {"frames": 36, "duration": 0.9, "loop": True, "preview_cycles": 2, "travel": "motion"}, "burst": {"frames": 42, "duration": 1.0, "loop": False}, "mark": {"frames": 42, "duration": 0.984, "loop": False}}
    config["rigid_bones"] = ["trunk", "core", "root_l", "root_c", "root_r"]
    config["contact_feet"] = ["root_l", "root_c", "root_r"]
    config["sources"] = sorted({*config["sources"], *[str(p.relative_to(CASE)) for folder in ["source", "recipes"] for p in (CASE / folder).rglob("*") if p.is_file()]})
    config["source_baseline"] = {"kind": "new_character", "front_original_sha256": sha(CASE / "source/front_original.png"), "registration": "255px whole-source registration; 2:1 board lanes; original front unchanged"}
    write(CASE / "cutout.json", config)
    for png in CASE.rglob("*.png"):
        Path(str(png) + ".import").write_text('[remap]\n\nimporter="keep"\n')


if __name__ == "__main__":
    build()

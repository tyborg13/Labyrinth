"""Reweight existing dragon paint at semantic attachment boundaries.

No pixel, joint, sampler, stride or timing changes. Run inside the forked case;
the pre-repair layout remains its immutable source. Production promotion is a
separate operation after native whole-cycle inspection.
"""
from pathlib import Path
import json
import math
import sys

from PIL import Image

CASE = Path(__file__).resolve().parent
PROJECT = CASE.parents[3]
sys.path.insert(0, str(PROJECT / "tools"))
from cutout_pipeline.assets import skin_mesh


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def visible_pixels(part):
    image = Image.open(CASE / part["file"]).convert("RGBA")
    ox, oy = part["offset"]
    return {(x + ox, y + oy) for y in range(image.height)
            for x in range(image.width) if image.getpixel((x, y))[3] > 16}


def distance(point, anchors):
    x, y = point
    return math.sqrt(min((x - a) ** 2 + (y - b) ** 2 for a, b in anchors))


def border(first, second):
    return {p for p in first if any((p[0] + dx, p[1] + dy) in second
            for dx in (-1, 0, 1) for dy in (-1, 0, 1))}


def constant_mesh(part, bone, family, grid=(32, 32)):
    return skin_mesh(part, Image.open(CASE / part["file"]).size,
                     {"name": family, "bones": [bone], "bands": [], "grid": list(grid)})


def main():
    config_path = CASE / "cutout.json"
    config = json.loads(config_path.read_text())
    character = config["character_id"]
    assert character in ("vyraketh", "tharokh")
    report = {"character": character, "paint_changed": False,
              "motion_changed": False, "facings": {}}
    for facing in ("front", "rear"):
        source = ("layouts/" + facing + "_skinned_v2.json" if character == "vyraketh"
                  else "layouts/" + facing + "_skinned.json")
        layout = json.loads((CASE / source).read_text())
        parts = {p["name"]: p for p in layout["parts"]}
        meshes = layout["joint_meshes"]
        detail = {"source_layout": source, "limbs": {}}
        for limb in ("fore_far", "fore_near", "hind_far", "hind_near"):
            claw = "claw_" + limb
            anchors = visible_pixels(parts[claw])
            changed = 0
            # The claw remains rigid. Its proximal paint edge, rather than the
            # foot's pivot, determines where the neighboring limb must share
            # that rigid transform. An eight-pixel collar retains bend above it.
            for mesh in meshes:
                if mesh["replaces_part"] not in (limb, "cap_" + limb):
                    continue
                weights = mesh["weights"]
                for i, point in enumerate(mesh["vertices"]):
                    old = weights[claw][i]
                    value = max(old, 1 - smooth((distance(point, anchors) - 2.5) / 8))
                    if value > old:
                        changed += 1
                        scale = (1 - value) / (1 - old) if old < 1 else 0
                        for bone in weights:
                            weights[bone][i] = value if bone == claw else weights[bone][i] * scale
            # Preserve the rigid terminal drawing on the same skinning path as
            # its neighboring deforming paint. This is still 100% one bone.
            meshes.append(constant_mesh(parts[claw], claw, facing + "_rigid_" + claw))
            detail["limbs"][limb] = {"claw_paint_pixels": len(anchors),
                                     "reweighted_vertices": changed}
        if character == "tharokh":
            neck_pixels = visible_pixels(parts["neck"])
            body_border = border(neck_pixels, visible_pixels(parts["torso"]))
            head_border = border(neck_pixels, visible_pixels(parts["head"]))
            assert body_border and head_border
            neck = constant_mesh(parts["neck"], "neck", facing + "_neck_attachment", (2, 1))
            neck["weights"] = {bone: [] for bone in ("torso", "neck", "head")}
            for point in neck["vertices"]:
                body_distance = distance(point, body_border)
                head_distance = distance(point, head_border)
                # The irregular rock-plate ownership cut is not a horizontal
                # anatomical joint. Blend across the actual two paint edges.
                body_distance = max(0, body_distance - 1.5)
                head_distance = max(0, head_distance - 1.5)
                u = body_distance / max(0.00001, body_distance + head_distance)
                a, b = smooth(u * 2), smooth((u - 0.5) * 2)
                neck["weights"]["torso"].append(1 - a)
                neck["weights"]["neck"].append(a - b)
                neck["weights"]["head"].append(b)
            meshes.append(neck)
            meshes.append(constant_mesh(parts["head"], "head", facing + "_rigid_head"))
            detail["neck"] = {"body_border_pixels": len(body_border),
                               "head_border_pixels": len(head_border),
                               "vertices": len(neck["vertices"])}
        target = "layouts/" + facing + "_attachments_v3.json"
        (CASE / target).write_text(json.dumps(layout, indent=2) + "\n")
        config["layouts"][facing] = target
        config["sources"] = sorted(set(config.get("sources", []) +
                                      [source, "repair_attachments.py", "attachment_repair.json"]))
        report["facings"][facing] = detail
    (CASE / "attachment_repair.json").write_text(json.dumps(report, indent=2) + "\n")
    config_path.write_text(json.dumps(config, indent=2) + "\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()

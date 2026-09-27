"""Repair the current feedback case's attachment weights without repainting it.

The v1 final capture exposed a moving front neck cut and a rear shoulder/tail
cut. Keep the motion sampler and all paint intact: body-contact vertices share
the body's transform, and a curved tail's later bands cannot steal influence
from its proximal attachment. The torso uses the same skinned geometry path as
its neighbours, avoiding separately rounded Sprite2D contact edges.
"""
import json
import math
from pathlib import Path

CASE = Path(__file__).resolve().parent
PROJECT = CASE.parents[3]


def band(point, center, axis, width):
    length = math.hypot(*axis)
    distance = sum((point[i] - center[i]) * axis[i] / length for i in range(2))
    t = max(0.0, min(1.0, 0.5 + distance / width))
    return t * t * (3.0 - 2.0 * t)


def torso_mesh(layout):
    part = next(p for p in layout["parts"] if p["name"] == "torso")
    # Obtain the authored crop extent from its existing texture, not a new bake.
    from PIL import Image
    with Image.open(CASE / part["file"]) as image:
        width, height = image.size
    x, y = part["offset"]
    return {
        "name": "Skin_torso", "replaces_part": "torso", "file": part["file"],
        "offset": [x, y], "bbox": [x, y, x + width, y + height],
        "z_index": part["z_index"], "equipment_slot": part.get("equipment_slot", ""),
        "family": layout["facing"] + "_body_attachment",
        "coordinate_space": "registered source pixels; crop-local UV pixels",
        "vertices": [[x, y], [x + width, y], [x + width, y + height], [x, y + height]],
        "uvs": [[0, 0], [width, 0], [width, height], [0, height]],
        "triangles": [[0, 1, 2], [0, 2, 3]], "weights": {"body": [1.0] * 4},
    }


for facing in ("front", "rear"):
    path = CASE / "layouts" / (facing + ".json")
    layout = json.loads(path.read_text())
    meshes = layout["joint_meshes"]
    if facing == "front":
        neck = next(m for m in meshes if m["replaces_part"] == "neck")
        # The painted neck/torso cut is at y116–121, not the old y125 band
        # centre. Leave a body-owned collar, then bend smoothly up the neck.
        influence = [band(p, (117, 104), (0, -1), 18) for p in neck["vertices"]]
        neck["weights"] = {
            "body": [round(1.0 - w, 8) for w in influence],
            "neck": [round(w, 8) for w in influence],
        }
    else:
        tail = next(m for m in meshes if m["replaces_part"] == "tail")
        weights = {name: [] for name in ("body", "tail_base", "tail_mid", "tail_tip")}
        for point in tail["vertices"]:
            base = band(point, (102, 145), (-1, 1), 24)
            middle = band(point, (76, 169), (0, 1), 34)
            tip = band(point, (115, 206), (1, 0), 50)
            values = (1.0 - base, base * (1.0 - middle),
                      base * middle * (1.0 - tip), base * middle * tip)
            for name, value in zip(weights, values):
                weights[name].append(round(value, 8))
        tail["weights"] = weights
    body_mesh = torso_mesh(layout)
    layout["joint_meshes"] = [m for m in meshes if m["replaces_part"] not in ("torso", "body_attachment_fill")] + [body_mesh]
    if facing == "rear":
        # Complementary pixel-ownership textures can sample opposite sides of
        # a texel at fractional root translations even with identical weights.
        # A hidden collar reuses the torso's own paint behind those internal
        # cuts. Only its geometry expands two source pixels; exposed parts and
        # their animation retain their authored dimensions and transforms.
        source_part = next(p for p in layout["parts"] if p["name"] == "torso")
        layout["parts"] = [p for p in layout["parts"] if p["name"] != "body_attachment_fill"]
        fill_part = dict(source_part, name="body_attachment_fill", z_index=-1,
                         equipment_slot="hidden_joint")
        layout["parts"].append(fill_part)
        fill = dict(body_mesh, name="Skin_body_attachment_fill",
                    replaces_part="body_attachment_fill", z_index=-1,
                    equipment_slot="hidden_joint")
        x0, y0, x1, y1 = body_mesh["bbox"]
        fill["vertices"] = [[x0-2, y0-2], [x1+2, y0-2],
                            [x1+2, y1+2], [x0-2, y1+2]]
        layout["joint_meshes"].append(fill)
    path.write_text(json.dumps(layout, indent=2) + "\n")

    # Promote only the repaired mesh definitions; retain production asset paths,
    # rest provenance and the current independent renderer/action implementation.
    target = PROJECT / "assets/units/vaeloryx_cutout" / (facing + ".json")
    production = json.loads(target.read_text())
    replacements = {m["replaces_part"]: m for m in layout["joint_meshes"]
                    if m["replaces_part"] in ({"neck", "torso"} if facing == "front" else {"tail", "torso", "body_attachment_fill"})}
    if facing == "rear":
        production["parts"] = [p for p in production["parts"] if p["name"] != "body_attachment_fill"]
        production_fill = dict(fill_part)
        production_fill["file"] = next(p["file"] for p in production["parts"] if p["name"] == "torso")
        production["parts"].append(production_fill)
    production["joint_meshes"] = [m for m in production["joint_meshes"] if m["replaces_part"] not in replacements]
    for part_name, mesh in replacements.items():
        mesh = dict(mesh)
        mesh["file"] = next(p["file"] for p in production["parts"] if p["name"] == part_name)
        production["joint_meshes"].append(mesh)
    target.write_text(json.dumps(production, indent=2) + "\n")
    print(facing, "repaired", ", ".join(replacements))

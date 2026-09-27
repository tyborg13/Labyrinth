"""Reweight existing dragon paint at semantic attachment boundaries.

No pixel, joint, sampler, stride or timing changes. Run inside the forked case;
the pre-repair layout remains its immutable source. Production promotion is a
separate operation after native whole-cycle inspection.
"""
from pathlib import Path
from bisect import bisect_right
from copy import deepcopy
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


def components(pixels):
    remaining = set(pixels)
    result = []
    while remaining:
        first = remaining.pop()
        island, queue = {first}, [first]
        while queue:
            x, y = queue.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    neighbor = (x + dx, y + dy)
                    if neighbor in remaining:
                        remaining.remove(neighbor)
                        island.add(neighbor)
                        queue.append(neighbor)
        result.append(island)
    return result


def constant_mesh(part, bone, family, grid=(32, 32)):
    return skin_mesh(part, Image.open(CASE / part["file"]).size,
                     {"name": family, "bones": [bone], "bands": [], "grid": list(grid)})


def weight_sampler(mesh, rigid_bone):
    if mesh is None:
        return lambda _point: {rigid_bone: 1.0}
    xs = sorted({v[0] for v in mesh["vertices"]})
    ys = sorted({v[1] for v in mesh["vertices"]})
    lookup = {tuple(p): i for i, p in enumerate(mesh["vertices"])}

    def sample(point):
        x, y = min(xs[-1], max(xs[0], point[0])), min(ys[-1], max(ys[0], point[1]))
        xi, yi = min(len(xs) - 2, bisect_right(xs, x) - 1), min(len(ys) - 2, bisect_right(ys, y) - 1)
        x0, x1, y0, y1 = xs[xi], xs[xi + 1], ys[yi], ys[yi + 1]
        u, v = (x - x0) / (x1 - x0), (y - y0) / (y1 - y0)
        # Same diagonal as skin_mesh; added local vertices preserve its
        # existing deformation field outside the corrected ownership islands.
        corners = [((x0, y0), 1 - u), ((x1, y0), u - v), ((x1, y1), v)] if u >= v else [((x0, y0), 1 - v), ((x1, y1), u), ((x0, y1), v - u)]
        return {bone: sum(values[lookup[p]] * w for p, w in corners)
                for bone, values in mesh["weights"].items()}
    return sample


def repair_ownership(layout, parts, assignments):
    """Reassign observed disconnected texture islands without changing pixels.

    Bounds/counts identify reviewed original segmentation remnants, not an
    automatic nearest-limb policy. Each island borrows its actual owner's
    deformation field. Fine vertices are confined to the island's x/y bands.
    """
    bases = {m["replaces_part"]: deepcopy(m) for m in layout["joint_meshes"]}
    report = []
    for source_name, repairs in assignments.items():
        part = parts[source_name]
        pixels = visible_pixels(part)
        islands = components(pixels)
        selections = []
        for bounds, count, target in repairs:
            selected = [c for c in islands if [min(x for x, y in c), min(y for x, y in c),
                        max(x for x, y in c), max(y for x, y in c)] == bounds]
            assert len(selected) == 1 and len(selected[0]) == count, (source_name, bounds)
            selections.append((selected[0], target))
            report.append({"source_part": source_name, "bounds": bounds, "pixels": count, "owner": target})
        remainder = pixels - set().union(*(c for c, _ in selections))
        base = bases.get(source_name)
        mesh = deepcopy(base) if base else constant_mesh(part, part["bone"], "ownership_" + source_name, (8, 8))
        xs, ys = {v[0] for v in mesh["vertices"]}, {v[1] for v in mesh["vertices"]}
        minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
        for island, _ in selections:
            xs.update(range(max(minx, min(x for x, y in island) - 2), min(maxx, max(x for x, y in island) + 3) + 1))
            ys.update(range(max(miny, min(y for x, y in island) - 2), min(maxy, max(y for x, y in island) + 3) + 1))
        xs, ys = sorted(xs), sorted(ys)
        mesh["vertices"] = [[x, y] for y in ys for x in xs]
        mesh["uvs"] = [[x - part["offset"][0], y - part["offset"][1]] for x, y in mesh["vertices"]]
        mesh["triangles"] = []
        for row in range(len(ys) - 1):
            for col in range(len(xs) - 1):
                i = row * len(xs) + col
                mesh["triangles"].extend([[i, i + 1, i + len(xs) + 1], [i, i + len(xs) + 1, i + len(xs)]])
        samplers = {name: weight_sampler(bases.get(name), parts[name]["bone"])
                    for name in {source_name, *(name for _, name in selections)}}
        vertices = []
        for point in mesh["vertices"]:
            owner, nearest = source_name, distance(point, remainder)
            for island, target in selections:
                candidate = distance(point, island)
                if candidate < nearest:
                    owner, nearest = target, candidate
            vertices.append(samplers[owner](point))
        bones = sorted(set().union(*(weights.keys() for weights in vertices)))
        mesh["weights"] = {bone: [weights.get(bone, 0.0) for weights in vertices] for bone in bones}
        layout["joint_meshes"] = [m for m in layout["joint_meshes"] if m["replaces_part"] != source_name] + [mesh]
    return report


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
            # These bounds are the exact original islands traced from native
            # front Breath15, front Walk29 and rear Walk0/10 witnesses.
            ownership = {
                "wing_far": [([100, 32, 100, 36], 5, "head"),
                             ([102, 37, 111, 44], 23, "head"),
                             ([112, 45, 119, 53], 48, "head")],
                "claw_fore_far": [([84, 192, 94, 199], 32, "tail")],
                "claw_hind_far": [([94, 193, 97, 193], 4, "tail")],
                "tail": [([53, 198, 57, 202], 15, "claw_fore_far")],
            } if facing == "front" else {
                "fore_near": [([162, 158, 168, 169], 36, "hind_near")],
                "torso": [([111, 175, 119, 188], 85, "claw_fore_far"),
                          ([115, 166, 122, 173], 24, "fore_far"),
                          ([127, 184, 131, 187], 10, "hind_near")],
            }
            detail["ownership_islands"] = repair_ownership(layout, parts, ownership)
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

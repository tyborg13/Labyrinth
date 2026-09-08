"""Verify registered-art segmentation, editable assets and actual rendered poses.

Connectivity and transform bounds are mechanical checks. They supplement the
separate native-scale art and board review; they do not score artistic quality.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageChops
from joint_mesh_contract_probe import check_poses, _cross
from articulated_contract_probe import component_sizes

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
COUNTS = {"walk": 24, "attack": 32}
SLOTS = {"head", "neck", "chest", "legs", "gloves", "boots", "cloak", "weapon"}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def expanded(part):
    canvas = Image.new("RGBA", (255, 255))
    canvas.alpha_composite(Image.open(HERE / part["file"]).convert("RGBA"), part["offset"])
    return canvas


def overlap(a, b):
    mask = ImageChops.multiply(a.getchannel("A"), b.getchannel("A"))
    points = [(x, y) for y in range(255) for x in range(255) if mask.getpixel((x, y))]
    return points, sum(a.getpixel(p) != b.getpixel(p) for p in points)


def check_layout(path, pose_dump=None):
    data = json.loads(path.read_text())
    facing = data["facing"]
    failures, attachment_proof = [], []
    version = data.get("version")
    if version not in (6, 7) or not data.get("new_registered_anatomy"):
        failures.append("Expected a registered-art layout (pass six or its garment refinement)")
    if len(data["joints"]) != 21 or data["joints"]["weapon_r"]["parent"] != "hand_r":
        failures.append("Missing body bones or independent weapon grip")
    if set(data.get("equipment_slots", {})) != SLOTS:
        failures.append("Missing independently composable equipment slots")
    parts = {p["name"]: p for p in data["parts"]}
    meshes = {m["replaces_part"]: m for m in data["joint_meshes"]}
    if len(parts) != len(data["parts"]) or set(meshes) != {"arm_r", "arm_l", "mantle_near", "mantle_far"}:
        failures.append("Duplicate parts or missing sleeve/shoulder skins")
    entries = data["parts"] + [data["cape_mesh"]]
    names = [p.get("replaces_part", p.get("name")) for p in entries]
    listed = [name for group in data["equipment_slots"].values() for name in group]
    if sorted(listed) != sorted(names):
        failures.append("Equipment bundles omit or duplicate a painted attachment")
    for part in entries:
        allowed_roots = (f"assets/pass6/{facing}/",) if version == 6 else (f"assets/pass6/{facing}/", f"assets/pass7/{facing}/")
        if not part["file"].startswith(allowed_roots):
            failures.append("Runtime part reuses prior-revision character art: " + part["file"])
        if part.get("equipment_slot") not in SLOTS:
            failures.append("Attachment lacks its equipment slot: " + part["file"])
        image = Image.open(HERE / part["file"]).convert("RGBA")
        if not image.getbbox():
            failures.append("Empty painted attachment: " + part["file"])
        if any(a > 127 and r > g + 35 and b > g + 35 for r, g, b, a in image.getdata()):
            failures.append("Magenta matte remains: " + part["file"])
    # Recompose all manually traced source pieces at their saved coordinates.
    # This is a different check from the intentionally modified assembled rest.
    source_report = json.loads((HERE / f"assets/pass6/{facing}/source/segmentation.json").read_text())
    source = Image.open(HERE / source_report["source"]).convert("RGBA")
    reconstructed = Image.new("RGBA", source.size)
    pixel_count = 0
    for part in source_report["parts"]:
        image = Image.open(HERE / part["file"]).convert("RGBA")
        bbox = part["bbox"]
        if image.size != (bbox[2] - bbox[0], bbox[3] - bbox[1]) or part["offset"] != bbox[:2]:
            failures.append("Traced part changed its native registration: " + part["name"])
        reconstructed.alpha_composite(image, part["offset"])
        pixel_count += sum(a > 0 for a in image.getchannel("A").getdata())
    visible = sum(a > 0 for a in source.getchannel("A").getdata())
    source_difference = sum(a != b for a, b in zip(source.getdata(), reconstructed.getdata()) if a[3] or b[3])
    if source_report["unassigned_pixels"] or pixel_count != visible or source_difference:
        failures.append("Manual source split loses, duplicates or changes painted pixels")
    if sha(HERE / source_report["source"]) != source_report["source_sha256"]:
        failures.append("Source segmentation report is stale")
    for mesh in [*meshes.values(), data["cape_mesh"]]:
        name = mesh["replaces_part"]
        if name in parts and any(mesh[k] != parts[name][k] for k in ("file", "offset", "z_index", "equipment_slot")):
            failures.append("Skin differs from its editable attachment: " + name)
        vertices, uvs, weights = mesh["vertices"], mesh["uvs"], mesh["weights"]
        if not vertices or len(vertices) != len(uvs):
            failures.append("Missing geometry/UVs: " + name)
        if any(bone not in data["joints"] or len(w) != len(vertices) for bone, w in weights.items()):
            failures.append("Invalid skin bone or weight count: " + name)
            continue
        for i, vertex in enumerate(vertices):
            values = [w[i] for w in weights.values()]
            if not all(math.isfinite(v) for v in vertex + uvs[i] + values) or any(v < 0 or v > 1 for v in values) or abs(sum(values) - 1) > 1e-6:
                failures.append("Invalid normalized vertex: " + name)
                break
            if uvs[i] != [vertex[j] - mesh["offset"][j] for j in range(2)]:
                failures.append("Skin changes the texture's neutral registration: " + name)
                break
        for tri in mesh["triangles"]:
            if len(tri) != 3 or any(type(i) is not int or not 0 <= i < len(vertices) for i in tri) or _cross(*(vertices[i] for i in tri)) <= 0:
                failures.append("Invalid rest triangle: " + name)
                break
    for side in ("r", "l"):
        # A glove's complete overlapping cuff follows exactly its own bone.
        arm, hand = "arm_" + side, "hand_" + side
        points, differences = overlap(expanded(parts[arm]), expanded(parts[hand]))
        rows = {y for _, y in points}
        skin = meshes[arm]
        relevant = [i for i, (_, y) in enumerate(skin["vertices"]) if y in rows or y - 1 in rows]
        error = max((1 - skin["weights"][hand][i] for i in relevant), default=1)
        if len(points) < 8 or differences or error > 1e-7:
            failures.append("Glove cuff has inconsistent paint or binding: " + side)
        attachment_proof.append({"joint": hand, "shared_pixels": len(points), "different_shared_pixels": differences, "maximum_nonhand_weight": error})
        # Knee parts have complete overlapping source material. Actual posed
        # connection is checked in every clothed and unclothed renderer frame.
        upper, lower = "thigh_" + side, "shin_" + side
        points, differences = overlap(expanded(parts[upper]), expanded(parts[lower]))
        if len(points) < 48 or differences or parts[upper]["bone"] != upper or parts[lower]["bone"] != lower:
            failures.append("Knee symbols lack their authored paint overlap: " + side)
        attachment_proof.append({"joint": "knee_" + side, "shared_pixels": len(points), "different_shared_pixels": differences, "method": "overlapping painted segments; no knee mesh interpolation"})
    cape = data["cape_mesh"]
    if cape["equipment_slot"] != "cloak" or any(parts[n]["equipment_slot"] != "cloak" for n in ["mantle_near", "mantle_far"]):
        failures.append("Shoulder coverings and hanging cloak cannot be removed together")
    if facing == "front" and cape["z_index"] >= parts["torso"]["z_index"]:
        failures.append("Front hanging cloak no longer sits behind the body")
    if facing == "rear":
        valid_order = (parts["torso"]["z_index"] < cape["z_index"] < parts["arm_r"]["z_index"] < parts["mantle_near"]["z_index"]) if version == 6 else (parts["torso"]["z_index"] < parts["arm_r"]["z_index"] < parts["mantle_near"]["z_index"] < cape["z_index"] < parts["scarf"]["z_index"])
        if not valid_order:
            failures.append("Rear cloak/arm/shoulder layers are inconsistent")
    posed = None
    if pose_dump is not None:
        samples = [s for s in pose_dump["samples"] if s["facing"] == facing]
        if {clip: sum(s["clip"] == clip for s in samples) for clip in COUNTS} != COUNTS or len(samples) != sum(COUNTS.values()):
            failures.append("Missing actual authored pose matrices")
        posed_data = dict(data, joint_meshes=[*data["joint_meshes"], cape])
        posed = check_poses(posed_data, samples)
        failures.extend(posed["failures"])
        for name, report in posed["meshes"].items():
            if report["minimum_signed_area_ratio"] <= 0:
                failures.append("Sleeve or cloak skin folds/collapses: " + name)
        for sample in samples:
            for bone in ["thigh_r", "shin_r", "foot_r", "thigh_l", "shin_l", "foot_l"]:
                xx, xy, yx, yy, _, _ = sample["bones"][bone]
                if xx * yy - xy * yx <= 0:
                    failures.append("Painted leg symbol flips/collapses: " + bone)
    return {"facing": facing, "layout_sha256": sha(path), "bone_count": len(data["joints"]),
            "source_segmentation": {"source_sha256": sha(HERE / source_report["source"]), "visible_pixels": visible,
                                    "part_pixels": pixel_count, "changed_or_missing_pixels": source_difference,
                                    "unassigned_pixels": source_report["unassigned_pixels"]},
            "equipment_slots": data["equipment_slots"], "attachments": attachment_proof,
            "posed_area": posed, "failures": failures, "passed": not failures}


def check_renders(folder):
    failures, cases = [], []
    for facing in ("front", "rear"):
        for action, count in COUNTS.items():
            for cloak in (True, False):
                name = f"{facing}_{action}" + ("" if cloak else "_without_cloak")
                paths = sorted((folder / name).glob("*.png"))
                if len(paths) != count:
                    failures.append("Missing full rendered clip: " + name)
                for path in paths:
                    image = Image.open(path).convert("RGBA")
                    sizes = component_sizes(image)
                    major = sum(n >= 8 for n in sizes)
                    if image.size != (512, 512) or major != 1:
                        failures.append("Incorrect canvas, empty pose or detached painted part: " + str(path.relative_to(folder)))
                    cases.append({"file": str(path.relative_to(folder)), "sha256": sha(path),
                                  "major_components": major, "largest_minor_component": sizes[1] if len(sizes) > 1 else 0})
    manifest = json.loads((folder / "render_manifest.json").read_text())
    for resource, expected in manifest["input_sha256"].items():
        if sha(PROJECT / resource.removeprefix("res://")) != expected:
            failures.append("Rendered frames are stale for " + resource)
    return {"scope": "Every actual 512px authored pose, with and without the cloak; 8-connected opaque components of at least eight pixels",
            "input_sha256": manifest["input_sha256"], "cases": cases, "failures": failures, "passed": not failures}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pose-matrices", type=Path, required=True)
    parser.add_argument("--renders", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()
    version = json.loads((HERE / "cutout_layout.json").read_text())["version"]
    if args.output is None:
        args.output = HERE / f"renders/pass{version}/registered_art_validation.json"
    poses = json.loads(args.pose_matrices.read_text())
    stale = []
    if poses.get("matrix_order") != ["xx", "xy", "yx", "yy", "ox", "oy"]:
        stale.append("Unexpected Godot matrix convention")
    for resource, expected in poses["input_sha256"].items():
        if sha(PROJECT / resource.removeprefix("res://")) != expected:
            stale.append("Pose matrices are stale for " + resource)
    layouts = [check_layout(HERE / name, poses) for name in ("cutout_layout.json", "cutout_layout_rear.json")]
    renders = check_renders(args.renders)
    failures = stale + [f for layout in layouts for f in layout["failures"]] + renders["failures"]
    report = {"pass": version, "pose_input_sha256": poses["input_sha256"], "layouts": layouts,
              "rendered_attachments": renders, "failures": failures, "passed": not failures}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"passed": not failures, "rendered_poses": len(renders["cases"]), "failures": failures, "output": str(args.output)}, indent=2))
    raise SystemExit(0 if not failures else 1)


if __name__ == "__main__":
    main()

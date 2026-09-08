from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

from .cases import CutoutError, ID, case_hashes, digest, image_records, load_case, local_path, read_json


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise CutoutError(message)


def _number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _point(value) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(_number(v) for v in value)


def _image(root: Path, value: str) -> tuple[int, int]:
    path = local_path(root, value)
    with Image.open(path) as image:
        _require(image.mode == "RGBA", f"{value}: use RGBA, not a painted transparency background")
        low, high = image.getchannel("A").getextrema()
        _require(high > 0, f"{value}: empty image")
        return image.size


def validate_layout(root: Path, layout: dict, facing: str, rigid: list[str], feet: list[str]) -> dict:
    _require(layout.get("canvas_size") == [255, 255], "Layout registration must be 255x255")
    _require(layout.get("facing") == facing, "Layout facing differs from its case key")
    joints = layout.get("joints")
    _require(isinstance(joints, dict) and bool(joints), "Define the creature's joint graph")
    for name, joint in joints.items():
        _require(bool(ID.fullmatch(name)) and isinstance(joint, dict) and _point(joint.get("position")), f"Invalid joint: {name}")
        seen = set()
        current = name
        while current is not None:
            _require(current in joints, f"{name}: unknown parent {current}")
            _require(current not in seen, f"{name}: cyclic bone parents")
            seen.add(current)
            current = joints[current].get("parent")
    for name in rigid + feet:
        _require(name in joints, f"Declared motion-check bone is missing: {name}")
    parts = layout.get("parts", [])
    _require(isinstance(parts, list) and bool(parts), "No painted parts yet; segment/register this creature before rendering")
    names = set()
    sizes: dict[str, tuple[int, int]] = {}
    for part in parts:
        name = part.get("name", "")
        _require(bool(ID.fullmatch(name)) and name not in names, f"Invalid or duplicate part: {name}")
        names.add(name)
        _require(part.get("bone") in joints and _point(part.get("offset")), f"{name}: missing bone or source registration")
        _require(isinstance(part.get("z_index", 0), int), f"{name}: invalid layer")
        sizes[part["file"]] = _image(root, part["file"])
    meshes = list(layout.get("joint_meshes", []))
    if layout.get("cape_mesh"):
        meshes.append(layout["cape_mesh"])
    replaced = set()
    mesh_names = set()
    families: dict[str, dict[tuple, dict]] = {}
    for mesh in meshes:
        name = mesh.get("name", "PaintedCape" if mesh is layout.get("cape_mesh") else "")
        _require(name and name not in mesh_names, f"Duplicate or unnamed mesh: {name}")
        mesh_names.add(name)
        if mesh.get("replaces_part") and mesh is not layout.get("cape_mesh"):
            replacement = mesh["replaces_part"]
            _require(replacement in names and replacement not in replaced, f"{name}: missing or multiply replaced part")
            replaced.add(replacement)
        width, height = _image(root, mesh["file"])
        points, uvs, triangles, weights = (mesh.get(key) for key in ["vertices", "uvs", "triangles", "weights"])
        _require(isinstance(points, list) and 3 <= len(points) <= 100000 and all(_point(p) for p in points), f"{name}: invalid vertices")
        _require(isinstance(uvs, list) and len(uvs) == len(points) and all(_point(p) for p in uvs), f"{name}: vertex/UV mismatch")
        _require(all(-0.001 <= u <= width + 0.001 and -0.001 <= v <= height + 0.001 for u, v in uvs), f"{name}: UV outside the registered crop")
        _require(isinstance(triangles, list) and bool(triangles), f"{name}: no triangles")
        for triangle in triangles:
            _require(isinstance(triangle, list) and len(triangle) == 3 and all(isinstance(i, int) and 0 <= i < len(points) for i in triangle), f"{name}: invalid triangle indices")
            a, b, c = [points[i] for i in triangle]
            area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            _require(abs(area) > 1e-8, f"{name}: collapsed rest triangle")
        _require(isinstance(weights, dict) and bool(weights), f"{name}: missing weights")
        for bone, values in weights.items():
            _require(bone in joints and isinstance(values, list) and len(values) == len(points), f"{name}: invalid weight array for {bone}")
            _require(all(_number(v) and 0 <= v <= 1 for v in values), f"{name}: nonfinite or negative weights")
        for index, point in enumerate(points):
            row = {bone: values[index] for bone, values in weights.items() if values[index] > 0}
            _require(abs(sum(row.values()) - 1.0) <= 0.001, f"{name}: weights do not sum to one")
            if mesh.get("family"):
                shared = families.setdefault(mesh["family"], {})
                key = tuple(point)
                if key in shared:
                    previous = shared[key]
                    _require(all(abs(row.get(b, 0) - previous.get(b, 0)) < 0.001 for b in row.keys() | previous.keys()), f"{name}: overlapping family vertices have different weights")
                shared[key] = row
    if layout.get("rest_source"):
        _require(_image(root, layout["rest_source"]) == (255, 255), "Assembled rest must retain 255x255 registration")
        if layout.get("rest_source_sha256"):
            _require(digest(local_path(root, layout["rest_source"])) == layout["rest_source_sha256"], "Assembled rest digest is stale")
    return {"joints": len(joints), "parts": len(parts), "meshes": len(meshes), "vertices": sum(len(m["vertices"]) for m in meshes)}


def validate(case: Path, protect: str | None = None) -> dict:
    path, config = load_case(case)
    root = path.parent
    errors = []
    metrics = {}
    try:
        _require(bool(ID.fullmatch(config.get("character_id", ""))), "character_id uses lowercase snake_case")
        _require(config.get("source_size") == [255, 255] and config.get("canvas_size") == [512, 512] and config.get("source_offset") == [128, 128], "Use the current 255px body registration and 512px padded action canvas")
        _require(isinstance(config.get("layouts"), dict) and bool(config["layouts"]), "Case needs explicit facing layouts")
        _require(config.get("default_facing") in config["layouts"], "Default facing is not supplied")
        _require(local_path(root, config["motion"]).is_file(), "Case motion script is missing")
        _require(isinstance(config.get("clips"), dict) and bool(config["clips"]), "Case needs clip playback timing")
        for name, clip in config["clips"].items():
            _require(bool(ID.fullmatch(name)), "Clip ids use lowercase snake_case")
            _require(isinstance(clip.get("frames"), int) and 2 <= clip["frames"] <= 240, f"{name}: frames must be 2..240")
            _require(_number(clip.get("duration")) and 0.03 <= clip["duration"] <= 60, f"{name}: invalid duration")
            _require(isinstance(clip.get("loop"), bool), f"{name}: declare loop explicitly")
            cycles = clip.get("preview_cycles", 1)
            _require(isinstance(cycles, int) and 1 <= cycles <= 8 and (clip["loop"] or cycles == 1), f"{name}: preview cycles must be 1..8; nonloops use one")
            _require(clip.get("travel", "none") in ["none", "motion"], f"{name}: unknown travel policy")
            if "phase_curve" in clip:
                curve = clip["phase_curve"]
                _require(isinstance(curve, list) and len(curve) >= 2 and all(_point(p) and all(0 <= v <= 1 for v in p) for p in curve), f"{name}: invalid phase curve")
                _require(curve[0][0] == 0 and curve[-1][0] == 1 and all(a[0] < b[0] for a, b in zip(curve, curve[1:])), f"{name}: phase-curve input must strictly advance from zero to one")
        for facing, relative in config["layouts"].items():
            try:
                _require(bool(ID.fullmatch(facing)), "Facing ids use lowercase snake_case")
                metrics[facing] = validate_layout(root, read_json(local_path(root, relative)), facing, config.get("rigid_bones", []), config.get("contact_feet", []))
            except (CutoutError, KeyError, TypeError, OSError, ValueError) as error:
                errors.append(f"{facing}: {error}")
        if not errors:
            hashes = case_hashes(path)
            if protect:
                expected = read_json(root / "baseline.sha256.json")
                for relative, sha in expected.items():
                    if protect == "all" or relative.endswith((".png", ".json")) and relative != path.name:
                        _require(hashes.get(relative) == sha, f"Protected baseline changed or was removed: {relative}")
                if protect == "art":
                    new_art = set(p for p in hashes if p.endswith((".png", ".json")) and p != path.name) - set(expected)
                    _require(not new_art, f"New art/layout inputs added under art protection: {sorted(new_art)}")
    except (CutoutError, KeyError, TypeError, OSError, ValueError) as error:
        errors.append(str(error))
    return {"ok": not errors, "character_id": config.get("character_id"), "layouts": metrics, "errors": errors}

#!/usr/bin/env python3
"""Shrike-owned gates. CPU diagnostics never stand in for native proof.

Generic rigid raster/capture transport below is retained from rr-02. Its
humanoid material predicates are deliberately replaced by bird owner masks.
"""
from __future__ import annotations
import argparse
import math
from functools import lru_cache
from pathlib import Path
import sys
import numpy as np
from PIL import Image
sys.path.insert(0, str(Path.cwd() / "tools"))
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_cutout import MAGENTA, components8, rest_identity, to_lab
CANVAS_SIZE = 512
POSE_OFFSET = 128
NATIVE_CAPTURE_TIMEOUT_SECONDS = 900.0
ANGLE_TOLERANCE_DEG = 1.0  # Sampling-only tolerances, never animation tuning.
PIXEL_TOLERANCE = 0.5
SCALE_TOLERANCE = 0.002


def bound_inputs(root, inputs):
    if not inputs:
        raise CutoutError("Missing input hashes")
    for path, expected in inputs.items():
        if not (root / path).is_file() or digest(root / path) != expected:
            raise CutoutError("Stale proof input: " + path)


def frame_counts(pixels):
    if pixels.shape != (CANVAS_SIZE, CANVAS_SIZE, 4):
        raise CutoutError("Motion frame must be native 512x512 RGBA")
    opaque = pixels[..., 3] > 128
    specks = [c for c in components8(opaque)[1:] if c.sum() < 12]
    return {"magenta_pixels": int((opaque & np.all(pixels[..., :3] == MAGENTA[:3], axis=-1)).sum()),
        "detached_specks": len(specks), "detached_speck_pixels": sum(int(c.sum()) for c in specks),
        "clipped_pixels": int(opaque[0].sum() + opaque[-1].sum() + opaque[:, 0].sum() + opaque[:, -1].sum()),
        "empty_frame": not bool(opaque.any())}


def source_gates(root):
    config = read_json(root / "cutout.json")
    errors = []
    if config.get("design_placeholders"): errors += list(config["design_placeholders"])
    if not rest_identity(root)["ok"]: errors.append("Rest identity differs from approved RGBA")
    policy = read_json(root / "recipes/gates.json")
    for view in config["layouts"]:
        owners = np.load(root / f"registered/{view}_owners.npy", allow_pickle=False)
        expected_classes = np.zeros(owners.shape, dtype=np.uint8)
        for index, names in enumerate(policy["semantic_classes"].values(), 1):
            expected_classes[np.isin(owners, [PART_NAMES.index(name) for name in names])] = index
        for field in ["semantic_masks", "occlusion_masks"]:
            path = policy[field].get(view)
            if not path:
                if field == "occlusion_masks" and policy.get("occlusion_not_applicable", {}).get(view): continue
                errors.append("TODO_DESIGN_" + field + "_" + view)
                continue
            mask = np.array(Image.open(root / path).convert("L"))
            expected = expected_classes if field == "semantic_masks" else owners + 1
            if mask.shape != (255, 255) or not np.array_equal(mask, expected):
                errors.append(field + " ownership mismatch: " + view)
    fill = read_json(root / "hidden_fills/index.json")
    if not fill["complete"] or fill.get("pending_design"): errors.append("Hidden fill incomplete")
    bound_inputs(root, fill["protected_inputs"])
    if fill["implementation_sha256"] != digest(root / "repair_fills.py"):
        errors.append("Hidden fill implementation changed; regenerate fills")
    sys.path.insert(0, str(root))
    from repair_ownership import verify_ownership
    errors += verify_ownership(root)
    values = []
    active_value_references = 0
    for view, layout_path in config["layouts"].items():
        layout = read_json(root / layout_path)
        if layout.get("joint_meshes") or layout.get("cape_mesh"): errors.append("Shrike must use rigid parts")
        hidden_colors = {}
        for name in PART_NAMES:
            hidden = np.load(root / f"registered/{view}_hidden_{name}.npy", allow_pickle=False)
            preview = rgba(str(root / f"hidden_fills/{view}_{name}.png"))
            assembled = np.zeros_like(preview)
            coverage = np.zeros(hidden.shape, dtype=int)
            for part in layout["parts"]:
                if not part.get("hidden_material") or part.get("logical_part", part["name"]) != name: continue
                pixels = rgba(str(root / part["file"]))
                x, y = part["offset"]
                h, w = pixels.shape[:2]
                mask = pixels[..., 3] > 128
                assembled[y:y+h, x:x+w][mask] = pixels[mask]
                coverage[y:y+h, x:x+w] += mask
            if np.any(coverage != hidden.astype(int)) or np.any(assembled[hidden] != preview[hidden]):
                errors.append("Runtime hidden fill differs from reviewed fill: " + view + "/" + name)
            if np.any((assembled[..., 3] > 128) & np.all(assembled[..., :3] == MAGENTA[:3], axis=-1)):
                errors.append("Magenta hidden fill: " + view + "/" + name)
            hidden_colors[name] = assembled[hidden, :3]
        paint = rgba(str(root / f"source/{view}/processed.png"))
        owners = np.load(root / f"registered/{view}_owners.npy", allow_pickle=False)
        # Different head materials have different visible/hidden proportions.
        # Compare every paint label with its own distribution (or the explicit
        # same-view sparse rule), rather than pooling beak/mask with feathers.
        sys.path.insert(0, str(root))
        from repair_fills import value_reference
        material_policy = read_json(root / "recipes/value_reference.json")
        materials = read_json(root / "recipes/rig.json")["materials"]
        for name in PART_NAMES:
            colors = hidden_colors[name]
            if not len(colors): continue
            active_value_references += 1
            try:
                reference, reference_rule = value_reference(paint, owners, PART_NAMES, name, materials, material_policy, view)
            except CutoutError as error:
                errors.append(str(error))
                continue
            own = paint[reference, :3]
            reference_l, hidden_l = to_lab(own)[:, 0], to_lab(colors)[:, 0]
            low, high = np.percentile(reference_l, [25, 75])
            difference = float(abs(np.median(hidden_l) - np.median(reference_l)))
            midtones = int(((hidden_l >= low) & (hidden_l <= high)).sum())
            passed = difference <= policy["hidden_value_max_median_l_difference"] and midtones > 0
            semantic = next(k for k, labels in policy["semantic_classes"].items() if name in labels)
            values.append({"view": view, "class": semantic, "part": name, "hidden_pixels": len(colors),
                "reference": reference_rule, "visible_median_l": float(np.median(reference_l)),
                "hidden_median_l": float(np.median(hidden_l)), "median_l_difference": difference,
                "reference_iqr_l": [float(low), float(high)], "hidden_midtones_pixels": midtones, "ok": passed})
            if not passed: errors.append("Hidden fill value: " + view + "/" + name)
    write_json(root / "proof/hidden_value_gates.json", {"ok": len(values) == active_value_references and all(v["ok"] for v in values),
        "basis": "rr-02 L* median difference <=8 and reference-IQR midtones; each painted material uses its own same-view visible reference or the director sparse rule; all six semantic groups retained", "values": values})
    return errors


PART_NAMES = ["body", "head", "beak", "mask", "wing_near", "wing_far", "tail", "legs"]


def expected_frames(config, rest=False):
    result = {(view, clip, frame) for view in config["layouts"] for clip, definition in config["clips"].items()
              for frame in range(definition["frames"])}
    if rest: result |= {(view, "rest", 0) for view in config["layouts"]}
    return result


def sample_errors(config, samples):
    errors = []
    if not samples.get("ok") or not samples.get("design_complete"):
        errors.append("Sampler/design incomplete")
    actual = [(s["view"], s["clip"], s["frame"]) for s in samples["samples"]]
    if set(actual) != expected_frames(config) or len(actual) != len(set(actual)):
        errors.append("Incomplete/duplicated motion sampling")
    return errors


def motion_contracts(samples, layouts):
    """Reject a finite but motionless rig; check the brief's numeric excursions."""
    errors = []
    def require(condition, label):
        if not condition: errors.append(label)
    def angle(matrix): return math.degrees(math.atan2(matrix[1], matrix[0]))
    for view, layout in layouts.items():
        for clip in ["idle", "move", "dive", "talon_rake", "hover", "hit", "death"]:
            frames = [s for s in samples if s["view"] == view and s["clip"] == clip]
            if not frames:
                errors.append("Missing motion contract: " + view + "/" + clip)
                continue
            bones = [s["bones"] for s in frames]
            pixel_scale = float(frames[0]["screen_pixel_scale"])
            dy = np.array([b["body"][5] - layout["joints"]["body"]["position"][1] for b in bones]) * pixel_scale
            body_angle = np.array([angle(b["body"]) for b in bones])
            relative_angles = {name: np.array([angle(b[name]) for b in bones]) - body_angle
                               for name in ["head", "wing_near", "wing_far", "tail", "legs"]}
            label = view + "/" + clip + ": "
            if clip == "idle":
                require(np.max(np.abs(dy)) < .02 and np.max(np.abs(body_angle)) < .02, label + "no body bob/tilt")
                require(all(np.allclose(b["legs"], bones[0]["legs"], atol=.02) for b in bones), label + "planted feet")
                scale = [math.hypot(b["body"][2], b["body"][3]) for b in bones]
                require(abs(max(scale) - 1.02) <= SCALE_TOLERANCE and min(scale) >= 1 - SCALE_TOLERANCE, label + "2% breathing")
                require(np.ptp(relative_angles["head"]) > ANGLE_TOLERANCE_DEG and np.max(np.abs(relative_angles["head"])) <= 6 + ANGLE_TOLERANCE_DEG, label + "independent head looks")
                require(abs(np.max(np.abs(relative_angles["tail"])) - 4) <= ANGLE_TOLERANCE_DEG, label + "4deg tail flick")
                for wing in ["wing_near", "wing_far"]:
                    require(1 <= np.max(np.abs(relative_angles[wing])) <= 2 + ANGLE_TOLERANCE_DEG, label + "2deg " + wing + " settle")
                require(not np.allclose(relative_angles["wing_near"], relative_angles["wing_far"]), label + "wings out of phase")
            elif clip == "move":
                require(abs(min(dy) + 24) <= PIXEL_TOLERANCE, label + "24px apex")
                middle = min(frames, key=lambda s: abs(s["phase"] - .5))
                require(abs((middle["bones"]["body"][5] - layout["joints"]["body"]["position"][1]) * pixel_scale + 24) <= PIXEL_TOLERANCE, label + "apex at mid-step")
                require(abs(max(dy) - 3) <= PIXEL_TOLERANCE, label + "3px crouch")
                require(abs(dy[-1]) <= PIXEL_TOLERANCE, label + "recovered landing")
            elif clip == "dive":
                require(abs(np.max(np.abs(body_angle)) - 20) <= ANGLE_TOLERANCE_DEG, label + "20deg forward pitch")
                for wing in ["wing_near", "wing_far"]:
                    span = [math.hypot(b[wing][0], b[wing][1]) for b in bones]
                    require(abs(min(span) - .7) <= SCALE_TOLERANCE, label + "70% " + wing + " span")
            elif clip == "talon_rake":
                # At the first wing downbeat, the director's forward offset is
                # still zero. Later forward travel also changes projected Y.
                downbeat = min(range(len(frames)), key=lambda i: abs(frames[i]["phase"] - .25))
                require(abs(dy[downbeat] + 6) <= PIXEL_TOLERANCE, label + "6px lift")
                require(abs(np.max(np.abs(relative_angles["legs"])) - 25) <= ANGLE_TOLERANCE_DEG, label + "25deg talons lead")
            elif clip == "hover":
                require(abs(min(dy) + 4) <= PIXEL_TOLERANCE and np.max(np.abs(body_angle)) < .02, label + "level 4px hover")
                for wing in ["wing_near", "wing_far"]:
                    values = relative_angles[wing]
                    require(abs(max(values) - 30) <= ANGLE_TOLERANCE_DEG and abs(min(values) + 30) <= ANGLE_TOLERANCE_DEG, label + "30deg " + wing + " beats")
            elif clip == "hit":
                require(abs(np.max(np.abs(relative_angles["head"])) - 8) <= ANGLE_TOLERANCE_DEG, label + "8deg head jerk")
                for wing in ["wing_near", "wing_far"]:
                    require(abs(np.max(np.abs(relative_angles[wing])) - 10) <= ANGLE_TOLERANCE_DEG, label + "10deg wing jolt")
            elif clip == "death":
                require(abs(abs(body_angle[-1]) - 25) <= ANGLE_TOLERANCE_DEG, label + "terminal 25deg tilt")
                for wing in ["wing_near", "wing_far"]:
                    require(abs(abs(relative_angles[wing][-1]) - 30) <= ANGLE_TOLERANCE_DEG, label + "terminal 30deg wing droop")
    return errors


def finish(root, records, errors, output, basis):
    for entry in records:
        if any(entry[key] for key in ["magenta_pixels", "detached_specks", "clipped_pixels", "empty_frame"]):
            errors.append("Motion pixels failed: %s/%s/%s" % (entry["view"], entry["clip"], entry["frame"]))
    report = {"ok": not errors, "basis": basis, "frames": records, "errors": errors}
    write_json(output, report)
    return report


def cpu_gates(root, output):
    config = read_json(root / "cutout.json")
    samples = read_json(root / "proof/motion_samples.json")
    bound_inputs(root, samples["inputs"])
    errors = source_gates(root) + sample_errors(config, samples)
    layouts = {v: read_json(root / p) for v, p in config["layouts"].items()}
    errors += motion_contracts(samples["samples"], layouts)
    records = [{k: s[k] for k in ["view", "clip", "frame"]} | frame_counts(rasterize(root, layouts[s["view"]], s)[0])
               for s in samples["samples"]]
    return finish(root, records, errors, output, "CPU nearest-raster diagnostic; NOT native proof")


def native_gates(root, output):
    from cutout_pipeline.proof import verify_render
    verified = verify_render(root, output)
    if not verified["ok"]: raise CutoutError(str(verified))
    config = read_json(root / "cutout.json")
    samples = read_json(root / "proof/motion_samples.json")
    bound_inputs(root, samples["inputs"])
    errors = source_gates(root) + sample_errors(config, samples)
    errors += motion_contracts(samples["samples"], {v: read_json(root / p) for v, p in config["layouts"].items()})
    capture = output / "motion_gate_capture"
    bound_inputs(capture, read_json(capture / "sha256.json"))
    manifest = read_json(capture / "native_motion_manifest.json")
    if not manifest["ok"]: raise CutoutError("Native masks failed")
    bound_inputs(root, manifest["inputs"])
    actual = [(s["view"], s["clip"], s["frame"]) for s in manifest["frames"]]
    if set(actual) != expected_frames(config, rest=True) or len(actual) != len(set(actual)):
        raise CutoutError("Native mask frame coverage is incomplete/duplicated")
    records = []
    for frame in manifest["frames"]:
        view, clip, number = frame["view"], frame["clip"], frame["frame"]
        pixels = rgba(str(capture / frame["files"]["rgba"]))
        encoded = rgba(str(capture / frame["files"]["owners"]))
        if encoded.shape != (512, 512, 4): raise CutoutError("Native ownership dimensions")
        ids = encoded[..., 0].astype(int) + 256 * encoded[..., 1].astype(int)
        lookup = manifest["views"][view]
        if not np.array_equal(encoded[..., 3], pixels[..., 3]) or any(str(i) not in lookup for i in np.unique(ids[encoded[..., 3] > 0])):
            raise CutoutError("Native owner IDs/alpha differ: " + view + "/" + clip)
        layout = read_json(root / config["layouts"][view])
        expected_nodes = {p["name"]: (p.get("logical_part", p["name"]), p["bone"], p.get("hidden_material", False)) for p in layout["parts"]}
        actual_nodes = {p["node"]: (p["logical_part"], p["bone"], p["hidden"]) for p in lookup.values()}
        if actual_nodes != expected_nodes: raise CutoutError("Native node provenance differs")
        if clip == "rest":
            if not np.array_equal(pixels[128:383, 128:383], rgba(str(root / f"source/{view}/processed.png"))):
                raise CutoutError("Native rest differs: " + view)
            owners = np.full(ids.shape, -1)
            for key, part in lookup.items():
                owners[(ids == int(key)) & (pixels[..., 3] > 128)] = layout["logical_parts"].index(part["logical_part"])
            if not np.array_equal(owners[128:383, 128:383], np.load(root / f"registered/{view}_owners.npy", allow_pickle=False)):
                raise CutoutError("Native ownership calibration differs: " + view)
        elif not np.array_equal(pixels, rgba(str(output / f"{view}_{clip}/pose_{number:04d}.png"))):
            raise CutoutError("Native masks and primary reel differ")
        records.append({"view": view, "clip": clip, "frame": number} | frame_counts(pixels))
    report = finish(root, records, errors, output / "motion_gates.json", "Native RGBA and calibrated ownership; seven clips, both views")
    write_json(root / "proof/native_motion_gates.json", report)
    return report


@lru_cache(maxsize=512)
def rgba(path: str):
    return np.array(Image.open(path).convert("RGBA"))


def tree_order(layout):
    """Match the rig's bone-first construction and Sprite2D child traversal."""
    children = {None: []}
    remaining = list(layout["joints"])
    while remaining:
        for name in remaining[:]:
            parent = layout["joints"][name]["parent"]
            if parent in children:
                children[parent].append(name)
                children[name] = []
                remaining.remove(name)
    result = []
    def visit(name):
        for child in children[name]:
            visit(child)
        result.extend(p["name"] for p in layout["parts"] if p["bone"] == name)
    visit(None)
    return result


def affine(part, layout, bones):
    xx, xy, yx, yy, x, y = bones[part["bone"]]
    basis = np.array([[xx, yx], [xy, yy]])
    origin = np.array([x, y]) + basis @ (np.array(part["offset"]) - layout["joints"][part["bone"]]["position"]) + POSE_OFFSET
    inverse = np.linalg.inv(basis)
    shift = -inverse @ origin
    return tuple(np.column_stack([inverse, shift]).ravel())


def transformed(values, part, layout, bones):
    return np.asarray(Image.fromarray(values).transform((CANVAS_SIZE, CANVAS_SIZE), Image.Transform.AFFINE,
                      affine(part, layout, bones), Image.Resampling.NEAREST))


def rasterize(root, layout, sample, include_sources=False):
    output = np.zeros((CANVAS_SIZE, CANVAS_SIZE, 4), dtype=np.uint8)
    owners = np.full((CANVAS_SIZE, CANVAS_SIZE), -1, dtype=np.int16)
    sources = np.zeros((CANVAS_SIZE, CANVAS_SIZE), dtype=np.int32)
    arm, body = np.zeros(owners.shape, dtype=bool), np.zeros(owners.shape, dtype=bool)
    order = sample.get("paint_tree_order", tree_order(layout))
    parts = layout["parts"]
    for number in sorted(range(len(parts)), key=lambda i: (sample["draw_order"][parts[i]["name"]], order.index(parts[i]["name"]))):
        part = parts[number]
        pixels = rgba(str(root / part["file"]))
        projected = transformed(pixels, part, layout, sample["bones"])
        mask = projected[..., 3] > 128
        output[mask] = projected[mask]
        owners[mask] = number
        if part["bone"] in ["wing_near", "wing_far"]:
            arm |= mask
        if part.get("logical_part", part["name"]) in ["head", "body", "beak", "mask"]:
            body |= mask
        if include_sources:
            yy, xx = np.indices(pixels.shape[:2])
            source_ids = ((yy + part["offset"][1]) * 255 + xx + part["offset"][0] + 1).astype(np.int32)
            source_ids[pixels[..., 3] == 0] = 0
            mapping = transformed(source_ids, part, layout, sample["bones"])
            sources[mask] = mapping[mask]
    return output, owners, sources, arm, body


def native_screenshot_count(config):
    # Each facing has one rest RGBA/overview, then every clip frame and three
    # unique overview checkpoints (first, middle, last) for each clip.
    return len(config["layouts"]) * (2 + sum(c["frames"] + len({0, c["frames"] // 2, c["frames"] - 1})
        for c in config["clips"].values()))


def capture_native(root, output, task_id, timeout=NATIVE_CAPTURE_TIMEOUT_SECONDS):
    """Explicit windowed director entry point; never invoked by headless gates."""
    import subprocess
    import tempfile
    from cutout_pipeline.proof import verify_render
    if not math.isfinite(timeout) or timeout <= 0:
        raise CutoutError("Native capture timeout must be positive and finite")
    verified = verify_render(root, output)
    if not verified["ok"]:
        raise CutoutError("Capture the fresh primary reel first: " + str(verified))
    destination = output / "motion_gate_capture"
    if destination.exists():
        raise CutoutError("Refusing to replace a motion capture: " + str(destination))
    result_path = output / "native_motion_result.json"
    screenshot_count = native_screenshot_count(read_json(root / "cutout.json"))
    # The visual runner recursively scans user:// PNGs. Mask data must live
    # outside that tree; a user://data subfolder would still be screenshots.
    with tempfile.TemporaryDirectory(prefix=".motion-gate-data-", dir=output) as temporary:
        data_root = Path(temporary).resolve()
        command = [sys.executable, "tools/visual_probe_runner.py", str(root / "probes/native_motion.gd"),
            "--task-id", task_id, "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--expect-size", "1920x1080", "--expect-size", "512x512", "--min-images", str(screenshot_count),
            "--timeout", str(timeout),
            "--result-manifest", str(result_path), "--", "--case", str(root / "cutout.json"),
            "--data-output", str(data_root)]
        completed = subprocess.run(command, check=False)
        if completed.returncode:
            raise CutoutError("Native ownership probe failed; inspect " + str(result_path))
        result = read_json(result_path)
        candidates = set()
        for entry in result["images"]:
            for parent in Path(entry["path"]).parents:
                if (parent / "native_motion_manifest.json").is_file():
                    candidates.add(parent)
                    break
        if not result["ok"] or len(candidates) != 1:
            raise CutoutError("No unique accepted native motion capture")
        collect_native_output(candidates.pop(), data_root, destination)
    return native_gates(root, output)


def collect_native_output(screenshots, data_root, destination):
    """Collect only the accepted attempt's data beside its validated screenshots."""
    import shutil
    manifest = read_json(screenshots / "native_motion_manifest.json")
    data = Path(read_json(screenshots / "native_motion_transport.json")["data_directory"]).resolve()
    if not data.is_relative_to(data_root.resolve()) or not data.is_dir():
        raise CutoutError("Native mask data is missing or outside this capture")
    for frame in manifest["frames"]:
        for kind in ["rgba", "owners", "arm", "body", "rest_dark"]:
            relative = Path(frame["files"][kind])
            expected = (Path("data") if kind != "rgba" else Path()) / f"{frame['view']}_{frame['clip']}" / f"{kind}_{frame['frame']:04d}.png"
            if relative != expected:
                raise CutoutError("Unexpected native capture path: " + str(relative))
            source = screenshots / relative if kind == "rgba" else data / relative.relative_to("data")
            if not source.is_file():
                raise CutoutError("Missing native capture data: " + str(source))
    shutil.copytree(screenshots, destination, ignore=shutil.ignore_patterns("native_motion_transport.json"))
    shutil.copytree(data, destination / "data")
    write_json(destination / "sha256.json", {str(p.relative_to(destination)): digest(p)
        for p in sorted(destination.rglob("*")) if p.is_file()})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, required=True)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--cpu', action='store_true')
    modes.add_argument('--native', type=Path)
    modes.add_argument('--capture-native', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--task-id', default='rr-03')
    args = parser.parse_args()
    try:
        if args.cpu:
            result = cpu_gates(args.case, args.output or args.case / 'proof/cpu_motion_gates.json')
        elif args.native:
            result = native_gates(args.case, args.native)
        else:
            result = capture_native(args.case, args.capture_native, args.task_id)
        print('SHRIKE MOTION GATES: ' + ('PASS' if result['ok'] else 'FAIL'))
        return 0 if result['ok'] else 1
    except (CutoutError, OSError, ValueError, KeyError) as error:
        print('SHRIKE MOTION GATES: FAIL: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())

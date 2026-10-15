#!/usr/bin/env python3
"""Motion-frame pixel gates; native captures and CPU diagnostics stay distinct."""
from __future__ import annotations

import argparse
from functools import lru_cache
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path.cwd() / "tools"))
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_cutout import MAGENTA, bbox, components8, to_lab, label_core

CANVAS_SIZE = 512
POSE_OFFSET = 128
NATIVE_CAPTURE_TIMEOUT_SECONDS = 900.0  # 460 five-surface poses under render-host load.
TABARD_GATE_PARTS = {
    "front": ["pelvis", "thigh_far", "thigh_near", "shin_far", "shin_near", "coat_far", "coat_near"],
    "rear": ["pelvis", "thigh_far", "thigh_near"],
}
LEG_PARTS = ["thigh_far", "thigh_near", "shin_far", "shin_near"]


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
        if part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]:
            arm |= mask
        if part.get("logical_part", part["name"]) in ["head", "torso", "coat_near", "coat_far"]:
            body |= mask
        if include_sources:
            yy, xx = np.indices(pixels.shape[:2])
            source_ids = ((yy + part["offset"][1]) * 255 + xx + part["offset"][0] + 1).astype(np.int32)
            source_ids[pixels[..., 3] == 0] = 0
            mapping = transformed(source_ids, part, layout, sample["bones"])
            sources[mask] = mapping[mask]
    return output, owners, sources, arm, body


@lru_cache(maxsize=32)
def visible_rest_dark(root_path, view, name):
    root = Path(root_path)
    names = list(read_json(root / "source/spec.json")["labels"])
    paint = rgba(str(root / f"source/{view}/processed.png"))
    owners = np.load(root / f"registered/{view}_owners.npy", allow_pickle=False)
    mask = (owners == names.index(name)) & (to_lab(paint[..., :3])[..., 0] < 15)
    if not np.array_equal(mask, rgba(str(root / f"registered/{view}_visible_dark_{name}.png"))[..., 3] > 128):
        raise CutoutError("Visible-rest dark provenance differs from source ownership: " + view + "/" + name)
    return mask


def rasterize_rest_dark(root, layout, sample):
    """CPU diagnostic counterpart of the native fifth provenance-ID surface."""
    owners = np.full((CANVAS_SIZE, CANVAS_SIZE), -1, dtype=np.int16)
    order = sample.get("paint_tree_order", tree_order(layout))
    parts = layout["parts"]
    for number in sorted(range(len(parts)), key=lambda i: (sample["draw_order"][parts[i]["name"]], order.index(parts[i]["name"]))):
        part = parts[number]
        name = part.get("logical_part", part["name"])
        if name not in LEG_PARTS:
            continue
        pixels = rgba(str(root / part["file"]))
        x, y = part["offset"]
        baseline = visible_rest_dark(str(root), sample["view"], name)[y:y+pixels.shape[0], x:x+pixels.shape[1]]
        mask = baseline & (pixels[..., 3] > 128)
        if mask.any():
            projected = transformed(mask.astype(np.uint8) * 255, part, layout, sample["bones"]) > 128
            owners[projected] = number
    return owners


def small_components(pixels, limit=12):
    return [component for component in components8(pixels[..., 3] > 128)[1:] if component.sum() < limit]


def trace_native(root, capture, output):
    """Use actual v04 alpha for defects, labelled CPU maps only for attribution."""
    config = read_json(root / "cutout.json")
    layouts = {v: read_json(root / p) for v, p in config["layouts"].items()}
    samples = read_json(root / "proof/motion_samples.json")["samples"]
    records, source_pixels = [], {}
    for sample in samples:
        v, clip, frame = sample["view"], sample["clip"], sample["frame"]
        native_path = capture / f"{v}_{clip}/pose_{frame:04d}.png"
        native = rgba(str(native_path))
        components = components8(native[..., 3] > 128)[1:]
        if not components:
            continue
        projected, owners, sources, _, _ = rasterize(root, layouts[v], sample, include_sources=True)
        for component in components:
            matched = component & np.all(native == projected, axis=-1) & (owners >= 0)
            attribution = []
            for i in np.unique(owners[matched]):
                part = layouts[v]["parts"][i]
                pixels = set(int(x) for x in sources[matched & (owners == i)] if x)
                source_pixels.setdefault((v, part["name"]), set()).update(pixels)
                attribution.append({"part": part["name"], "logical_part": part.get("logical_part", part["name"]),
                    "hidden": part.get("hidden_material", False), "matched_pixels": int((matched & (owners == i)).sum()),
                    "source_points": [[(x - 1) % 255, (x - 1) // 255] for x in sorted(pixels)]})
            records.append({"view": v, "clip": clip, "frame": frame, "native_pixels": int(component.sum()),
                "bbox": bbox(component), "unmatched_pixels": int((component & ~matched).sum()), "attribution": attribution})
    report = {"basis": "Native alpha/RGBA from verified v04 captures; ownership attribution from matching CPU pixels, not a native ownership capture",
        "native_capture": str(capture), "components": records,
        "source_pixels": [{"view": v, "part": part, "points": [[(x - 1) % 255, (x - 1) // 255] for x in sorted(pixels)]}
                          for (v, part), pixels in sorted(source_pixels.items())]}
    write_json(output, report)
    return report


def bake_rear_arm(root):
    """Project the whole rigid arm into the body with the shortest translation.

    A one-native-pixel interior margin accounts for different nearest raster edge
    decisions. This moves the shoulder attachment inside the concealed body; it
    neither deletes paint nor changes arm lengths, pelvis drive or front motion.
    """
    samples = read_json(root / "proof/motion_samples.json")
    for path, expected in samples["inputs"].items():
        if digest(root / path) != expected:
            raise CutoutError("Stale constraint source sample: " + path)
    layout_path = root / read_json(root / "cutout.json")["layouts"]["rear"]
    layout = read_json(layout_path)
    if layout.get("rear_fist_constraint"):
        raise CutoutError("Bake from fresh unconstrained layouts, not an already projected arm")
    records, curves = [], {"strike": [], "manacle_pin": []}
    for sample in samples["samples"]:
        if sample["view"] != "rear" or sample["clip"] not in curves:
            continue
        _, _, _, arm, body = rasterize(root, layout, sample)
        inside = label_core(body, 2)  # One pixel inside the rasterized boundary.
        extent = (CANVAS_SIZE * 2, CANVAS_SIZE * 2)
        correlation = np.fft.irfft2(np.fft.rfft2(inside, s=extent) * np.conj(np.fft.rfft2(arm, s=extent)), s=extent)
        yy, xx = np.nonzero(np.rint(correlation).astype(np.int32) == int(arm.sum()))
        yy = np.where(yy > CANVAS_SIZE, yy - extent[0], yy)
        xx = np.where(xx > CANVAS_SIZE, xx - extent[1], xx)
        valid = (abs(yy) < CANVAS_SIZE) & (abs(xx) < CANVAS_SIZE)
        yy, xx = yy[valid], xx[valid]
        if not len(xx):
            raise CutoutError("No rigid inward arm translation fits the body: " + sample["clip"] + "/" + str(sample["frame"]))
        index = np.lexsort((xx, yy, xx * xx + yy * yy))[0]
        shift = [int(xx[index]), int(yy[index])]
        shifted = np.asarray(Image.fromarray(arm).transform((CANVAS_SIZE, CANVAS_SIZE), Image.Transform.AFFINE,
            (1, 0, -shift[0], 0, 1, -shift[1]), Image.Resampling.NEAREST))
        if np.any(shifted & ~inside) or int(shifted.sum()) != int(arm.sum()):
            raise CutoutError("Arm projection clipped or escaped the body")
        curves[sample["clip"]].append({"phase": sample["phase"], "offset": shift})
        records.append({"clip": sample["clip"], "frame": sample["frame"], "phase": sample["phase"],
            "arm_pixels": int(arm.sum()), "before_outside": int((arm & ~body).sum()),
            "after_outside": int((shifted & ~body).sum()), "offset": shift})
    write_json(root / "proof/motion_samples_unconstrained.json", samples)
    layout["rear_fist_constraint"] = {"basis": "Shortest integer source-canvas translation into torso/head/coat union, preserving limb shape; one-pixel interior margin; ties y then x",
        "raster_margin_px": 1, "clips": curves}
    write_json(layout_path, layout)
    report = {"ok": True, "basis": "CPU geometric constraint; native pixel gate remains required", "samples": records,
              "unconstrained_samples_sha256": digest(root / "proof/motion_samples_unconstrained.json")}
    write_json(root / "proof/rear_fist_constraints.json", report)
    return report


def frame_counts(pixels, owners, parts, arm, body, view, clip, tabard_lab, rest_dark_owners=None):
    """Count strict DeltaE76<12 on the director's complete logical owner list."""
    opaque = pixels[..., 3] > 128
    distances = np.full(opaque.shape, np.inf)
    distances[opaque] = np.linalg.norm(to_lab(pixels[opaque, :3]) - tabard_lab, axis=-1)
    red = opaque & (distances < 12)
    by_part = dict.fromkeys(TABARD_GATE_PARTS[view], 0)
    for i in np.unique(owners[red]):
        if i < 0 or i >= len(parts):
            raise CutoutError("Opaque material pixel has no valid owner")
        name = parts[i].get("logical_part", parts[i]["name"])
        if name in by_part:
            by_part[name] += int((red & (owners == i)).sum())
    fragments = small_components(pixels)
    near_black = np.zeros(opaque.shape, dtype=bool)
    near_black[opaque] = to_lab(pixels[opaque, :3])[:, 0] < 15
    dark_regions = {}
    for name in LEG_PARTS:
        part_ids = [i for i, part in enumerate(parts) if part.get("logical_part", part["name"]) == name]
        known = np.isin(rest_dark_owners, part_ids) if rest_dark_owners is not None else np.zeros_like(opaque)
        introduced = near_black & np.isin(owners, part_ids) & ~known
        dark_regions[name] = [{"pixels": int(c.sum()), "bbox": bbox(c)} for c in components8(introduced) if c.sum() > 12]
    arm_ids = [i for i, part in enumerate(parts) if part.get("bone") in ["upper_fist", "fore_fist", "hand_fist"]]
    return {"tabard_non_tabard_pixels": sum(by_part.values()), "tabard_collisions_by_part": by_part,
        "detached_small_components": [{"pixels": int(c.sum()), "bbox": bbox(c)} for c in fragments],
        "detached_small_pixels": sum(int(c.sum()) for c in fragments),
        "new_leg_dark_pixels": sum(c["pixels"] for regions in dark_regions.values() for c in regions),
        "new_leg_dark_regions_by_part": dark_regions,
        "rear_arm_outside_pixels": int((arm & ~body).sum()) if view == "rear" and clip in ["strike", "manacle_pin"] else 0,
        "rear_visible_arm_pixels": int((opaque & np.isin(owners, arm_ids)).sum()) if view == "rear" and clip in ["strike", "manacle_pin"] else 0,
        "magenta_pixels": int((opaque & np.all(pixels[..., :3] == MAGENTA[:3], axis=-1)).sum())}


def value_counts(root):
    """Independently inspect filled PNGs against current visible source owners."""
    config = read_json(root / "recipes/rig.json")
    names = list(read_json(root / "source/spec.json")["labels"])
    records = []
    for view in ["front", "rear"]:
        paint = rgba(str(root / f"source/{view}/processed.png"))
        owners = np.load(root / f"registered/{view}_owners.npy", allow_pickle=False)
        for part in config["hidden_value_distribution"]["parts"]:
            hidden = np.load(root / f"registered/{view}_hidden_{part}.npy", allow_pickle=False)
            filled = rgba(str(root / f"hidden_fills/{view}_{part}.png"))
            own_l = to_lab(paint[owners == names.index(part), :3])[:, 0]
            reference_l = own_l
            substitution = None
            material_substitution = part in config.get("occlusion_shadow", {}).get("replacement_trousers_reference_parts", [])
            if len(own_l) < 40 or material_substitution:
                near_l = to_lab(paint[owners == names.index("thigh_near"), :3])[:, 0]
                shift = -6 if len(own_l) < 40 else 0
                reference_l = np.clip(near_l + shift, 0, 100)
                substitution = {"view": view, "part": "thigh_near", "visible_pixels": len(near_l),
                    "source_median_l": float(np.median(near_l)), "l_shift": shift,
                    "rule": "sparse" if len(own_l) < 40 else "trousers_material"}
            fill_l = to_lab(filled[hidden, :3])[:, 0]
            q25, q75 = np.percentile(reference_l, [25, 75])
            effective_q25, effective_q75 = q25, q75
            midtone_substitution = None
            minimum_l = config.get("occlusion_shadow", {}).get("minimum_hidden_l") if part in LEG_PARTS else None
            if minimum_l is not None and q75 < minimum_l:
                eligible_l = reference_l[reference_l >= minimum_l]
                if not len(eligible_l):
                    raise CutoutError("No non-shadow reference midtones: " + view + "/" + part)
                effective_q25, effective_q75 = np.percentile(eligible_l, [25, 75])
                midtone_substitution = "Original reference IQR lies below round7 shadow cutoff; non-shadow reference tail IQR replaces it, nominal median unchanged"
            delta = float(abs(np.median(fill_l) - np.median(reference_l)))
            midtones = int(((fill_l >= effective_q25) & (fill_l <= effective_q75)).sum())
            records.append({"view": view, "part": part, "visible_pixels": len(own_l),
                "visible_median_l": float(np.median(own_l)) if len(own_l) else None, "hidden_median_l": float(np.median(fill_l)),
                "reference_median_l": float(np.median(reference_l)), "substitution": substitution,
                "difference_l": delta, "midtones_range_l": [float(q25), float(q75)],
                "effective_midtones_range_l": [float(effective_q25), float(effective_q75)],
                "midtones_substitution": midtone_substitution,
                "hidden_original_midtones_pixels": int(((fill_l >= q25) & (fill_l <= q75)).sum()),
                "hidden_midtones_pixels": midtones, "ok": delta <= 8 and midtones > 0})
    return records


def finish_report(root, records, basis, output):
    values = value_counts(root)
    gate = read_json(root / "recipes/rig.json")["ownership_cleanup"]["tabard_gate"]
    if gate["parts"] != TABARD_GATE_PARTS or gate["delta_e"] != 12 or gate["comparison"] != "strict_less":
        raise CutoutError("Motion gate scope differs from the director's round6 contract")
    by_clip_part = []
    for view, clip in sorted({(r["view"], r["clip"]) for r in records}):
        frames = [r for r in records if (r["view"], r["clip"]) == (view, clip)]
        for part in TABARD_GATE_PARTS[view]:
            counts = [r["tabard_collisions_by_part"][part] for r in frames]
            by_clip_part.append({"view": view, "clip": clip, "part": part,
                "frames": len(frames), "total_pixels": sum(counts), "max_frame_pixels": max(counts)})
    totals = {name: sum(r[name] for r in records) for name in
              ["tabard_non_tabard_pixels", "detached_small_pixels", "new_leg_dark_pixels", "rear_arm_outside_pixels", "rear_visible_arm_pixels", "magenta_pixels"]}
    report = {"ok": not any(totals.values()) and all(r["ok"] for r in values), "basis": basis,
        "frames": len(records), "totals": totals, "value_distribution": values,
        "colour_gate": gate, "colour_counts_per_part_and_clip": by_clip_part,
        "value_failures": sum(not r["ok"] for r in values), "records": records,
        "design_placeholders": read_json(root / "recipes/rig.json").get("design_placeholders", {})}
    write_json(output, report)
    print("MOTION GATES: " + ("PASS" if report["ok"] else "FAIL") + f" ({len(records)} frames; {totals}; value failures={report['value_failures']}; {basis})")
    return report


def cpu_gates(root, output):
    samples = read_json(root / "proof/motion_samples.json")
    for path, expected in samples["inputs"].items():
        if digest(root / path) != expected:
            raise CutoutError("Stale CPU motion sample: " + path)
    config = read_json(root / "cutout.json")
    expected = {(v, c, f) for v in config["layouts"] for c, d in config["clips"].items() for f in range(d["frames"])}
    actual = [(s["view"], s["clip"], s["frame"]) for s in samples["samples"]]
    if len(actual) != len(expected) or set(actual) != expected:
        raise CutoutError("Motion sample frame coverage is incomplete or duplicated")
    layouts = {v: read_json(root / p) for v, p in config["layouts"].items()}
    tabard_lab = read_json(root / "proof/front_ownership_cleanup.json")["materials"]["tabard_cloth"]["median_lab"]
    records = []
    for sample in samples["samples"]:
        layout = layouts[sample["view"]]
        pixels, owners, _, arm, body = rasterize(root, layout, sample)
        rest_dark = rasterize_rest_dark(root, layout, sample)
        records.append({k: sample[k] for k in ["view", "clip", "frame"]} | frame_counts(pixels, owners, layout["parts"], arm, body, sample["view"], sample["clip"], tabard_lab, rest_dark))
    return finish_report(root, records, "CPU nearest raster diagnostic; NOT native proof", output)


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


def native_gates(root, output):
    from cutout_pipeline.proof import verify_render
    verified = verify_render(root, output)
    if not verified["ok"]:
        raise CutoutError(str(verified))
    capture = output / "motion_gate_capture"
    if not (capture / "sha256.json").is_file():
        raise CutoutError("Native motion capture is incomplete; run --capture-native successfully before collecting proof")
    for path, expected in read_json(capture / "sha256.json").items():
        if digest(capture / path) != expected:
            raise CutoutError("Changed native output: " + path)
    manifest = read_json(capture / "native_motion_manifest.json")
    if not manifest["ok"] or not manifest["inputs"]:
        raise CutoutError("Native ownership probe failed or has no input binding")
    for path, expected in manifest["inputs"].items():
        if digest(root / path) != expected:
            raise CutoutError("Stale native motion input: " + path)
    config = read_json(root / "cutout.json")
    expected = {(v, c, f) for v in config["layouts"] for c, d in config["clips"].items() for f in range(d["frames"])}
    expected |= {(v, "rest", 0) for v in config["layouts"]}
    actual = [(s["view"], s["clip"], s["frame"]) for s in manifest["frames"]]
    if len(actual) != len(expected) or set(actual) != expected:
        raise CutoutError("Native frame coverage is incomplete or duplicated")
    tabard_lab = read_json(root / "proof/front_ownership_cleanup.json")["materials"]["tabard_cloth"]["median_lab"]
    records = []
    for sample in manifest["frames"]:
        view, clip, frame = sample["view"], sample["clip"], sample["frame"]
        pixels, encoded, arm, body, dark_encoded = [rgba(str(capture / sample["files"][key])) for key in ["rgba", "owners", "arm", "body", "rest_dark"]]
        ids = encoded[..., 0].astype(np.int32) + 256 * encoded[..., 1].astype(np.int32)
        ids[encoded[..., 3] <= 128] = 0
        lookup = manifest["views"][view]
        names = read_json(root / config["layouts"][view])["logical_parts"]
        if not np.array_equal(encoded[..., 3], pixels[..., 3]) or any(str(i) not in lookup for i in np.unique(ids) if i):
            raise CutoutError("Native owner IDs/alpha failed validation")
        parts = [{"name": lookup[str(i)]["node"], "logical_part": lookup[str(i)]["logical_part"], "bone": lookup[str(i)]["bone"]} for i in range(1, len(lookup) + 1)]
        dark_ids = dark_encoded[..., 0].astype(np.int32) + 256 * dark_encoded[..., 1].astype(np.int32)
        dark_ids[dark_encoded[..., 3] <= 128] = 0
        if any(str(i) not in lookup or lookup[str(i)]["logical_part"] not in LEG_PARTS for i in np.unique(dark_ids) if i):
            raise CutoutError("Native visible-rest dark provenance IDs failed validation")
        if clip == "rest":
            expected_paint = rgba(str(root / f"source/{view}/processed.png"))
            actual_paint = pixels[POSE_OFFSET:POSE_OFFSET+255, POSE_OFFSET:POSE_OFFSET+255]
            if not np.array_equal(actual_paint, expected_paint):
                raise CutoutError("Native motion probe rest RGBA differs: " + view)
            logical = np.full(ids.shape, -1, dtype=np.int16)
            for i, part in enumerate(parts, 1):
                logical[ids == i] = names.index(part["logical_part"])
            if not np.array_equal(logical[POSE_OFFSET:POSE_OFFSET+255, POSE_OFFSET:POSE_OFFSET+255], np.load(root / f"registered/{view}_owners.npy")):
                raise CutoutError("Native owner ID calibration differs from exact rest partition: " + view)
            expected_dark = np.full((255, 255), -1, dtype=np.int16)
            actual_dark = np.full(ids.shape, -1, dtype=np.int16)
            for name in LEG_PARTS:
                expected_dark[visible_rest_dark(str(root), view, name)] = names.index(name)
            for i, part in enumerate(parts, 1):
                actual_dark[dark_ids == i] = names.index(part["logical_part"])
            if not np.array_equal(actual_dark[POSE_OFFSET:POSE_OFFSET+255, POSE_OFFSET:POSE_OFFSET+255], expected_dark):
                raise CutoutError("Native visible-rest dark provenance calibration differs: " + view)
            continue
        if not np.array_equal(pixels, rgba(str(output / f"{view}_{clip}/pose_{frame:04d}.png"))):
            raise CutoutError(f"Ownership probe RGBA differs from primary reel: {view}/{clip}/{frame}")
        records.append({"view": view, "clip": clip, "frame": frame} | frame_counts(pixels, ids - 1, parts, arm[..., 3] > 128, body[..., 3] > 128, view, clip, tabard_lab, dark_ids - 1))
    report = finish_report(root, records, "Native renderer pixels, calibrated native IDs, complete seven-clip frame set", output / "motion_gates.json")
    write_json(root / "proof/native_motion_gates.json", report)
    return report


def positive_seconds(value):
    seconds = float(value)
    if not math.isfinite(seconds) or seconds <= 0:
        raise argparse.ArgumentTypeError("timeout must be positive and finite")
    return seconds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", type=Path, required=True)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--trace-native", type=Path)
    action.add_argument("--bake-rear-arm", action="store_true")
    action.add_argument("--cpu", action="store_true")
    action.add_argument("--capture-native", type=Path)
    action.add_argument("--native", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--task-id", default="rr-02")
    parser.add_argument("--native-timeout", type=positive_seconds, default=NATIVE_CAPTURE_TIMEOUT_SECONDS,
        help="Seconds allowed for the 460-pose native capture (default: %(default)s); startup watchdog unchanged.")
    args = parser.parse_args()
    root = args.case.resolve()
    try:
        if args.bake_rear_arm:
            report = bake_rear_arm(root)
            print(f"REAR ARM CONSTRAINT: {len(report['samples'])} projected poses")
        elif args.trace_native:
            report = trace_native(root, args.trace_native, args.output)
            print(f"NATIVE MOTION TRACE: {len(report['components'])} detached components")
            return 0
        elif args.cpu:
            report = cpu_gates(root, args.output or root / "proof/cpu_motion_gates.json")
        elif args.capture_native:
            report = capture_native(root, args.capture_native, args.task_id, args.native_timeout)
        else:
            report = native_gates(root, args.native)
        return 0 if report["ok"] else 1
    except (CutoutError, OSError, ValueError, KeyError) as error:
        print("MOTION GATES: FAIL: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

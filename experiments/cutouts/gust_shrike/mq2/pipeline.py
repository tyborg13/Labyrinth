#!/usr/bin/env python3
"""rr-03 input check/build/promotion. Never runs Blender or a windowed engine."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from unittest.mock import patch
import numpy as np
from PIL import Image

CASE = Path(__file__).resolve().parent
PROJECT = CASE.parents[3]
sys.path.insert(0, str(PROJECT / "tools"))
sys.path.insert(0, str(CASE))
from humanoid_cutout.native_frames import load_frame
import maquette_cutout as maquette
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from cutout_pipeline.validation import validate
from compile_motion import compile_data, source_path

JOBS = PROJECT / "spec/art_identity/jobs/gust_shrike"
RENDER_SIZE = 1024
PARTS = ["body", "head", "beak", "mask", "wing_near", "wing_far", "tail", "legs"]
ORIGINAL_REGISTRATION = maquette.registration


def copy_native_rest(source, destination):
    image = load_frame(source)
    if source.is_file() and load_frame(source, cropped=True).size == image.size:
        shutil.copyfile(source, destination)
    else:
        image.save(destination)


def render_registration(raw: Path, record: dict) -> maquette.Registration:
    """The front raw is 1254px; Blender maps/joints are in 1024px coordinates.

    rr-02 registration is in raw pixel coordinates. Normalize the common affine
    map once for every map, solo and joint; never fit parts independently. This
    case-local adapter preserves the shared rr-02 builder and its source checks.
    """
    transform = ORIGINAL_REGISTRATION(raw, record)
    ratio = transform.trace["raw_size"][0] / RENDER_SIZE
    return maquette.Registration([s * ratio for s in transform.scale], transform.offset,
        dict(transform.trace, render_size=RENDER_SIZE, render_to_raw_scale=ratio))


def input_report(renders: Path, front_raw: Path, rear_raw: Path) -> dict:
    errors = []
    for view, raw in [("front", front_raw), ("rear", rear_raw)]:
        if not raw.is_file():
            errors.append(f"TODO_DESIGN_approved_raw_{view}: {raw}")
        else:
            try:
                render_registration(raw, read_json(JOBS / f"mq2_{view}/processed.json"))
            except (CutoutError, OSError, ValueError) as error:
                errors.append(str(error))
    for name in ["spec.json", "view_transforms.json", "joints_px.json"] + [
        f"{view}_{kind}.png" for view in ["front", "rear"]
        for kind in ["parts", "clay", *["solo_" + part for part in PARTS]]
    ]:
        if not (renders / name).is_file(): errors.append("Missing Blender export: " + name)
    if (renders / "spec.json").is_file():
        try:
            spec = read_json(renders / "spec.json")
            if list(spec["labels"]) != PARTS: errors.append("Unexpected maquette labels")
            maquette.render_manifest(renders, spec)
            for view in ["front", "rear"]: maquette.camera_view(spec, view)
        except (CutoutError, KeyError, ValueError, OSError) as error:
            errors.append(str(error))
    return {"ok": not errors, "errors": errors, "renders": str(renders), "raw_front": str(front_raw), "raw_rear": str(rear_raw)}


def build_case(args) -> dict:
    report = input_report(args.renders, args.front_raw, args.rear_raw)
    if not report["ok"]: raise CutoutError("\n".join(report["errors"]))
    prepare_motion()
    build_args = argparse.Namespace(spec=args.renders / "spec.json", front_job=JOBS / "mq2_front",
        rear_job=JOBS / "mq2_rear", front_raw=args.front_raw, rear_raw=args.rear_raw,
        renders=args.renders, case=CASE, rig_recipe=CASE / "recipes/rig.json",
        view_transforms=args.renders / "view_transforms.json", palette=None, color_config=None,
        blender=maquette.BLENDER, task_id="rr-03", resume_scaffold=True, allow_incomplete_renders=False)
    with patch.object(maquette, "registration", render_registration):
        report = maquette.build(build_args)
    create_semantic_masks()
    return report


def prepare_motion() -> dict:
    interpretation = read_json(CASE / "recipes/motion_interpretation.json")
    generated = PROJECT / "scripts/gust_shrike_cutout/motion_data.gd"
    compile_data(CASE, generated, interpretation)
    metadata_path = CASE / "proof/motion_metadata.json"
    process = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", "rr-03", "--stream", "--",
        "godot", "--headless", "--path", ".", "--script", str(CASE / "probes/motion_metadata.gd"), "--",
        "--output", str(metadata_path)], cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (CASE / "proof/motion_metadata.log").write_text(process.stdout)
    if process.returncode: raise CutoutError("Motion metadata failed; see proof/motion_metadata.log")
    metadata = read_json(metadata_path)
    compiled = compile_data(CASE, generated, interpretation, metadata["screen_pixel_scale"])
    write_json(CASE / "proof/motion_compilation.json", compiled)
    for name in ["motion.gd", "motion_data.gd"]:
        shutil.copyfile(PROJECT / "scripts/gust_shrike_cutout" / name, CASE / name)
    recipe = read_json(CASE / "recipes/rig.json")
    for clip, timing in metadata["clips"].items(): recipe["clips"][clip].update(timing)
    recipe["design_placeholders"] = {} if compiled["design_complete"] else {
        "TODO_DESIGN_head_snap_clock": "Specify step2 FPS and start/finish placement in motion_interpretation.json"}
    config = read_json(CASE / "cutout.json")
    # A completed fill binds the build recipe as pixel provenance. Refreshing
    # motion changes runtime config and sampler data, never that paint record.
    if config["source_baseline"].get("art_status") == "unbuilt":
        write_json(CASE / "recipes/rig.json", recipe)
    config["clips"] = recipe["clips"]
    config["design_placeholders"] = recipe["design_placeholders"]
    config["sources"] = sorted(set(config["sources"]) | {"compile_motion.py", "pipeline.py", "director_motion.json", "recipes/motion_interpretation.json", "probes/director_contract.py", "probes/production_coverage.py"})
    write_json(CASE / "cutout.json", config)
    return {"ok": True, "design_complete": compiled["design_complete"], "screen_pixel_scale": metadata["screen_pixel_scale"]}


def create_semantic_masks() -> None:
    """Six director classes, calibrated against the registered maquette labels."""
    policy = read_json(CASE / "recipes/gates.json")
    for view in ["front", "rear"]:
        owners = np.load(CASE / f"registered/{view}_owners.npy", allow_pickle=False)
        classes = np.zeros(owners.shape, dtype=np.uint8)
        for number, labels in enumerate(policy["semantic_classes"].values(), 1):
            classes[np.isin(owners, [PARTS.index(name) for name in labels])] = number
        Image.fromarray(classes).save(CASE / policy["semantic_masks"][view])
    config = read_json(CASE / "cutout.json")
    config["sources"] = sorted(set(config["sources"]) | {"compile_motion.py", "pipeline.py", "director_motion.json", "recipes/motion_interpretation.json"}
                               | set(policy["semantic_masks"].values()))
    write_json(CASE / "cutout.json", config)


def promote(native_output: Path) -> dict:
    # Copy only a complete verified case. No publication, Git, or asset painting.
    sys.path.insert(0, str(CASE / "probes"))
    from motion_gates import native_gates
    gates = native_gates(CASE, native_output)
    if not gates["ok"]: raise CutoutError("Native gates failed; promotion refused")
    config = read_json(CASE / "cutout.json")
    if config.get("design_placeholders"): raise CutoutError("Resolve case design placeholders before promotion")
    for name in ["motion.gd", "motion_data.gd"]:
        if digest(CASE / name) != digest(PROJECT / "scripts/gust_shrike_cutout" / name):
            raise CutoutError("Case/runtime motion differ: " + name)
    destination = PROJECT / "assets/units/gust_shrike_cutout"
    if destination.exists(): raise CutoutError("Refusing to overwrite existing production rig")
    destination.mkdir(parents=True)
    for view, relative in config["layouts"].items():
        layout = read_json(CASE / relative)
        for part in layout["parts"]:
            source = CASE / part["file"]
            target = destination / part["file"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            Path(str(target) + ".import").write_text('[remap]\n\nimporter="keep"\n')
        rest = destination / view / "rest.png"
        rest.parent.mkdir(parents=True, exist_ok=True)
        copy_native_rest(native_output / f"{view}_rest.png", rest)
        Path(str(rest) + ".import").write_text('[remap]\n\nimporter="keep"\n')
        layout["rest_source"] = f"{view}/rest.png"
        write_json(destination / f"{view}.json", layout)
    files = {str(path.relative_to(destination)): digest(path) for path in destination.rglob("*") if path.is_file()}
    write_json(destination / "integration.json", {"ready": True, "files": files,
        "native_proof_sha256": digest(native_output / "proof_sha256.json"), "case": str(CASE.relative_to(PROJECT))})
    return {"ok": True, "production": str(destination), "files": len(files)}


def seal_density() -> dict:
    """Refresh promotion hashes only after prescribed native-rest recording."""
    import process_board_density as density
    entry = next(e for e in density.load_registry()["entries"] if e["id"] == "gust_shrike_cutout")
    outputs = read_json(density.MANIFEST)
    errors = density.paint_errors([entry], outputs) + density.rest_errors([entry], outputs)
    if errors: raise CutoutError("Complete native density rebake and --record-rests first:\n" + "\n".join(errors))
    destination = PROJECT / entry["dir"]
    path = destination / "integration.json"
    integration = read_json(path)
    # The approved editable paint remains the immutable density source.
    config = read_json(CASE / "cutout.json")
    for view, layout_path in config["layouts"].items():
        for part in read_json(CASE / layout_path)["parts"]:
            source = density.SOURCES / entry["dir"] / part["file"]
            if not np.array_equal(np.array(Image.open(source).convert("RGBA")), np.array(Image.open(CASE / part["file"]).convert("RGBA"))):
                raise CutoutError("Density source differs from approved case: " + part["file"])
    integration["files"] = {str(p.relative_to(destination)): digest(p) for p in destination.rglob("*") if p.is_file() and p != path}
    integration["density"] = {"entry": entry["id"], "parts_pixel_sha256": density.parts_digest(entry),
        "native_rests": {p: outputs[p] for p in density.rest_paths(entry)}}
    write_json(path, integration)
    return {"ok": True, "production": str(destination), "density_entry": entry["id"]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check-inputs", "build", "prepare-motion", "validate", "promote", "seal-density"])
    parser.add_argument("--renders", type=Path, default=CASE.parent / "maquette")
    parser.add_argument("--front-raw", type=Path, default=CASE.parent / "inputs/front_raw.png")
    parser.add_argument("--rear-raw", type=Path, default=CASE.parent / "inputs/rear_raw.png")
    parser.add_argument("--native-output", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "check-inputs": result = input_report(args.renders, args.front_raw, args.rear_raw)
        elif args.command == "build": result = build_case(args)
        elif args.command == "prepare-motion": result = prepare_motion()
        elif args.command == "validate": result = validate(CASE)
        elif args.command == "seal-density": result = seal_density()
        else:
            if args.native_output is None: raise CutoutError("promote requires --native-output")
            result = promote(args.native_output)
        print(json.dumps(result, indent=2))
        return 0 if result["ok"] else 1
    except (CutoutError, OSError, ValueError, KeyError) as error:
        print("SHRIKE PIPELINE: FAIL: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

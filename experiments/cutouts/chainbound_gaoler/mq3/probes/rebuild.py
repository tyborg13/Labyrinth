#!/usr/bin/env python3
"""Rebuild the complete gaoler case from immutable inputs and compare all outputs."""
import argparse
from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path.cwd() / "tools"))
from cutout_pipeline.cases import digest, read_json, write_json
from maquette_cutout import build, fill_hidden

# Execution transcripts contain runner IDs, paths and timings. They are evidence
# of an invocation, not reproducible artifacts. No image/JSON/recipe is excluded.
TRANSCRIPTS = {"proof/motion_samples.log", "proof/exposure.log", "proof/motion_constraints.log"}
INVENTORY = "proof/derived_files.json"
DERIVED_DIRECTORIES = ["registered", "segmented", "hidden", "layouts", "hidden_requests", "hidden_fills"]


def artifact_hashes(root):
    return {str(p.relative_to(root)): digest(p) for p in sorted(root.rglob("*"))
            if p.is_file() and "__pycache__" not in p.parts
            and str(p.relative_to(root)) not in TRANSCRIPTS | {INVENTORY}}


def rebuild(source, output, task_id="rr-02"):
    transforms = source / "source/view_transforms.json"
    args = argparse.Namespace(case=output, spec=source / "source/spec.json", rig_recipe=source / "recipes/rig.json",
        renders=source / "source/maquette", palette=source / "source/label_palette.json",
        front_job=source / "source/front", rear_job=source / "source/rear",
        front_raw=source / "source/front/raw.png", rear_raw=source / "source/rear/raw.png",
        view_transforms=transforms if transforms.exists() else None,
        allow_incomplete_renders=False, resume_scaffold=False, task_id=task_id)
    built = build(args)
    if not built["complete"]:
        raise RuntimeError("Incomplete clean build: " + str(built))
    # The recorded fill method is an input: do not silently select a new method
    # because a different workstation happens to have OpenCV installed.
    write_json(output / "recipes/hidden_fill.json", read_json(source / "recipes/hidden_fill.json"))
    filled = fill_hidden(argparse.Namespace(case=output, task_id=task_id, cross_view_fallback=True))
    if not filled["ok"] or not filled["complete"]:
        raise RuntimeError("Incomplete clean fill: " + str(filled))
    hashes = artifact_hashes(output)
    write_json(output / INVENTORY, hashes)
    return hashes


def compare(source, fresh):
    expected = read_json(fresh / INVENTORY)
    recorded = read_json(source / INVENTORY)
    paths = set(expected) | set(recorded) | {INVENTORY}
    # Also catch orphaned generated files omitted from an old inventory.
    for folder in DERIVED_DIRECTORIES:
        paths.update(str(p.relative_to(source)) for p in (source / folder).rglob("*") if p.is_file())
    differences = [p for p in sorted(paths) if not (source / p).is_file() or not (fresh / p).is_file()
                   or digest(source / p) != digest(fresh / p)]
    return {"ok": not differences, "compared_files": len(paths), "different_files": differences,
            "excluded_execution_transcripts": sorted(TRANSCRIPTS), "sha256": expected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", type=Path, required=True)
    parser.add_argument("--output", type=Path, help="Keep a new clean build here; otherwise use a temporary directory")
    parser.add_argument("--report", type=Path)
    parser.add_argument("--task-id", default="rr-02")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="rr02-rebuild-") as temporary:
        output = args.output.resolve() if args.output else Path(temporary).resolve() / "case"
        rebuild(args.case.resolve(), output, args.task_id)
        report = compare(args.case.resolve(), output)
        if args.report:
            write_json(args.report, report)
        print("GAOLER REBUILD: " + ("PASS" if report["ok"] else "FAIL") + " (" + str(report["compared_files"]) + " files)")
        if report["different_files"]:
            print("\n".join(report["different_files"]))
        return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

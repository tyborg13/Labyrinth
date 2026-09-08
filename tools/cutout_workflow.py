#!/usr/bin/env python3
"""Prepare, refine and inspect reusable Escape the Umbra character cutouts."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

from cutout_pipeline.cases import CutoutError, fork_case, init_case, seed_protagonist


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    sub.add_parser("doctor", help="Check local authoring dependencies")
    for name in ["init", "seed-protagonist", "fork"]:
        command = sub.add_parser(name, help={"init": "Start a new creature with its own anatomy", "seed-protagonist": "Copy approved current production art/motion/timing", "fork": "Create a fresh case variant without copying old proof"}[name])
        command.add_argument("--output", type=Path, required=True)
        command.add_argument("--character", required=True)
        if name == "init":
            command.add_argument("--facings", default="front,rear")
        if name == "fork":
            command.add_argument("case", type=Path)
    command = sub.add_parser("validate", help="Check case, image, rig, skin and playback contracts")
    command.add_argument("case", type=Path)
    command.add_argument("--protect", choices=["art", "all"])
    command = sub.add_parser("segment", help="Split registered paint with explicit pixel ownership")
    command.add_argument("--source", type=Path, required=True)
    command.add_argument("--ownership", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command = sub.add_parser("skin", help="Build registered joint meshes from a shared weight recipe")
    command.add_argument("case", type=Path)
    command.add_argument("--recipe", type=Path, required=True)
    command = sub.add_parser("replace-part", help="Replace registered rigid equipment paint in this case")
    command.add_argument("case", type=Path)
    command.add_argument("--facing", required=True)
    command.add_argument("--part", required=True)
    command.add_argument("--image", type=Path, required=True)
    command.add_argument("--offset", required=True, help="Native source x:y; no automatic fitting")
    for name in ["render", "inspect", "verify-render"]:
        command = sub.add_parser(name)
        command.add_argument("case", type=Path)
        if name != "inspect":
            command.add_argument("--output", type=Path, required=True)
        if name != "verify-render":
            command.add_argument("--task-id")
            command.add_argument("--godot", default="godot")
        if name == "render":
            command.add_argument("--backend", help="Explicit native backend, e.g. metal on macOS; default is the repo runner's selection")
            command.add_argument("--ffmpeg", default="ffmpeg")
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.command == "doctor":
            import importlib.util
            report = {"python": sys.version.split()[0], "pillow": importlib.util.find_spec("PIL") is not None, "godot": shutil.which("godot"), "ffmpeg": shutil.which("ffmpeg"), "ffprobe": shutil.which("ffprobe")}
            report["ok"] = sys.version_info >= (3, 9) and report["pillow"] and bool(report["godot"]) and bool(report["ffmpeg"]) and bool(report["ffprobe"])
        elif args.command == "init":
            path = init_case(args.output, args.character, args.facings.split(","))
            report = {"ok": True, "case": str(path), "art_status": "unbuilt; define anatomy and paint before validation/render"}
        elif args.command == "seed-protagonist":
            report = {"ok": True, "case": str(seed_protagonist(args.output, args.character))}
        elif args.command == "fork":
            report = {"ok": True, "case": str(fork_case(args.case, args.output, args.character))}
        elif args.command == "validate":
            from cutout_pipeline.validation import validate
            report = validate(args.case, args.protect)
        elif args.command == "segment":
            from cutout_pipeline.assets import segment
            report = segment(args.source, args.ownership, args.output)
        elif args.command == "skin":
            from cutout_pipeline.assets import apply_skin
            report = {"ok": True, "layout": str(apply_skin(args.case, args.recipe))}
        elif args.command == "replace-part":
            from cutout_pipeline.assets import replace_part
            offset = tuple(int(x) for x in args.offset.split(":"))
            if len(offset) != 2:
                raise CutoutError("Offset must be native x:y")
            report = {"ok": True, "asset": str(replace_part(args.case, args.facing, args.part, args.image, offset))}
        elif args.command == "render":
            from cutout_pipeline.proof import render
            report = render(args.case, args.output, args.task_id, args.godot, args.backend, args.ffmpeg)
        elif args.command == "verify-render":
            from cutout_pipeline.proof import verify_render
            report = verify_render(args.case, args.output)
        elif args.command == "inspect":
            from cutout_pipeline.proof import inspect
            return inspect(args.case, args.task_id, args.godot)
        print(json.dumps(report, indent=2))
        return 0 if report.get("ok") else 1
    except (CutoutError, OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(json.dumps({"ok": False, "error": str(error)}, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Prepare the untouched perf-11 base strip for the optional equivalence probe."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = "5c099f24b"


def write_profile(directory, run_path, stem):
    parent = directory / f"{stem}_parent_profile.gd"
    parent.write_text((ROOT / "tests/perf/profiled_run_scene.gd").read_text().replace(
        '"res://scripts/run_scene.gd"', json.dumps(str(run_path))))
    profile = directory / f"{stem}_profile.gd"
    wrapper = (ROOT / "tools/perf11/profiled_scene.gd").read_text().replace(
        '"res://tests/perf/profiled_run_scene.gd"', json.dumps(str(parent)))
    if "func _on_card_hover_started(index: int, pointer_hover:" not in run_path.read_text():
        wrapper = wrapper.replace("super._on_card_hover_started(index, pointer_hover)",
                                  "super._on_card_hover_started(index)")
    profile.write_text(wrapper)
    return profile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--reference-rev", default=REFERENCE,
                        help="Read-only oracle revision; perf-13 uses 8593be76e")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    source = subprocess.check_output(
        ["git", "show", f"{args.reference_rev}:scripts/turn_order_landing_strip.gd"],
        cwd=ROOT, text=True)
    reference = args.output_dir.resolve() / "reference_strip.gd"
    reference.write_text(source.replace("class_name TurnOrderLandingStrip\n", ""))
    print(reference)
    # Run the same soak in this worktree with the original strip. No checkout,
    # Git mutation, or edit to a protected reference implementation is needed.
    run = subprocess.check_output(["git", "show", f"{args.reference_rev}:scripts/run_scene.gd"],
                                  cwd=ROOT, text=True)
    reference_run = args.output_dir.resolve() / "reference_run.gd"
    reference_run.write_text(run.replace('"res://scripts/turn_order_landing_strip.gd"',
                                        json.dumps(str(reference))))
    scene_profile = write_profile(args.output_dir.resolve(), reference_run, "reference")
    print(scene_profile)
    # Negative control: change only the reused portrait's clock in a private
    # candidate. The semantic and native oracle must both reject this variant.
    fault = args.output_dir.resolve() / "fault_strip.gd"
    candidate = (ROOT / "scripts/turn_order_landing_strip.gd").read_text()
    fault.write_text(candidate.replace("class_name TurnOrderLandingStrip\n", "").replace(
        'renderer.call("reset_prepared_state")', 'renderer.call("seed_idle_phase", 0.5)'))
    print(fault)
    # Perf-12 negative control: lose the hand-enter request, leaving the old
    # presentation on screen unless a board event happens to flush it.
    hover_source = (ROOT / "scripts/run_scene.gd").read_text()
    start = hover_source.index("func _on_card_hover_started(")
    end = hover_source.index("\nfunc _on_card_hover_ended(", start)
    hover_method = hover_source[start:end]
    if "_queue_hover_presentation()" in hover_method:
        fault_hover = args.output_dir.resolve() / "fault_hover_run.gd"
        fault_hover.write_text(hover_source[:start] + hover_method.replace(
            "_queue_hover_presentation()", "pass # Deliberately omit the flush request") + hover_source[end:])
        print(write_profile(args.output_dir.resolve(), fault_hover, "fault_hover"))


if __name__ == "__main__":
    main()

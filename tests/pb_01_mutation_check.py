#!/usr/bin/env python3
"""Prove the five round-1 survivors fail without mutating production files."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
TARGET = Path("scripts/live_actor_presentation.gd")
RESULT_PATH = Path("/private/tmp/pb-01-r1-mutations.json")


def replace_once(source, needle, replacement):
    if source.count(needle) != 1:
        raise AssertionError(f"Mutation requires one exact site: {needle!r}")
    return source.replace(needle, replacement)


def mutated(source, name):
    if name == "disable_renderer_processing":
        return replace_once(source, "\t\tadd_child(renderer)", "\t\tadd_child(renderer)\n\t\trenderer.set_process(false)")
    if name == "noctyrax_processing_disabled":
        return replace_once(source, "\t\tadd_child(renderer)", '\t\tadd_child(renderer)\n\t\tif actor_type == "noctyrax": renderer.set_process(false)')
    if name == "wrong_noctyrax_renderer":
        return replace_once(source, "static func renderer_script(identity: String) -> Script:\n", 'static func renderer_script(identity: String) -> Script:\n\tif identity == "noctyrax": return preload("res://scripts/crawler_cutout/renderer.gd")\n')
    if name == "remove_phase_seed":
        return replace_once(source, '\t\trenderer.set("_idle_seconds", initial_phase * cycle)', "\t\t# Mutation: seed omitted.")
    if name == "draw_still_for_every_cutout":
        begin = source.index("func _draw() -> void:")
        end = source.index("func snapshot()", begin)
        return source[:begin] + "func _draw() -> void:\n\tdraw_texture_rect(still.texture, Rect2(Vector2.ZERO, size), false)\n\n" + source[end:]
    raise AssertionError(name)


def overlay(source, destination, remaining, replacement):
    destination.mkdir(exist_ok=True)
    for child in source.iterdir():
        if child.name in [".git", ".codex", ".agents"]:
            continue
        path = destination / child.name
        if child.name != remaining.parts[0]:
            path.symlink_to(child, target_is_directory=child.is_dir())
        elif len(remaining.parts) > 1:
            overlay(child, path, Path(*remaining.parts[1:]), replacement)
        else:
            path.write_text(replacement)


def main():
    original = (PROJECT / TARGET).read_text()
    expectations = {
        "disable_renderer_processing": "SceneTree automatically advances idle: crawler",
        "noctyrax_processing_disabled": "SceneTree automatically advances idle: noctyrax",
        "wrong_noctyrax_renderer": "Instantiated renderer Script matches the board identity: noctyrax",
        "remove_phase_seed": "Actual renderer is seeded at slot 1",
        "draw_still_for_every_cutout": "CanvasItem submits the renderer texture, not the source still",
    }
    results = []
    for name, expected in expectations.items():
        with tempfile.TemporaryDirectory(prefix="pb_01_mutation_", dir=PROJECT / "tests") as temporary:
            root = Path(temporary)
            overlay(PROJECT, root, TARGET, mutated(original, name))
            process = subprocess.run([
                sys.executable, "tools/godot_task_runner.py", "--task-id", "pb-01", "--stream", "--",
                "godot", "--headless", "--path", str(root), "--script", "res://tests/pre_battle_living_foes_test.gd",
            ], cwd=PROJECT, capture_output=True, text=True, timeout=330)
            output = process.stdout + process.stderr
            log_path = RESULT_PATH.with_name("pb-01-r1-mutation-" + name + ".log")
            log_path.write_text(output)
            caught = process.returncode == 1 and "SCRIPT ERROR" not in output and expected in output
            results.append({"mutation": name, "caught": caught, "exit": process.returncode, "expected_failure": expected, "log": str(log_path)})
            print("PB-01 MUTATION %s: %s" % (name, "CAUGHT" if caught else "SURVIVED OR INVALID"), flush=True)
    intact = (PROJECT / TARGET).read_text() == original
    RESULT_PATH.write_text(json.dumps({"mutations": results, "production_unchanged": intact}, indent=2) + "\n")
    passed = intact and all(result["caught"] for result in results)
    print("PB-01 MUTATION CHECK: %s (%d/5 caught)" % ("PASS" if passed else "FAIL", sum(result["caught"] for result in results)))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

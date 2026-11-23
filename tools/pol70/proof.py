#!/usr/bin/env python3
"""Run the candidate 4 census and native card-title proof against both revisions."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
OUTPUT_ROOT = Path("/private/tmp/labyrinth_codex/pol-70")
BASELINE = "76aac505bcc3f1f915344a5e7b14e8e20e1e1fae"
POL67 = "7d3ca10b7bff68f6e6447131f569fd760fc6fac0"
SIZE = "1920x1080"
CENSUS_SHOTS = ("combat", "boss", "scavenger", "graftwright_confirm", "reward", "draw_pile")
ROW_PROOF_SHOTS = ("event_transform", "scavenger_receipt")
FIXTURE_SHELF = "scavenger_long_names"
NATIVE_SHOTS = ("long_hand", "scavenger", "graftwright_confirm", *ROW_PROOF_SHOTS, FIXTURE_SHELF)
CATALOG_SHOTS = (*CENSUS_SHOTS, "grimoire_card", "event_card")
MOTION_SHOTS = ("motion_long", "motion_short")
ADDITIONAL_SHOTS = ("grimoire_card", "event_card", *ROW_PROOF_SHOTS, *MOTION_SHOTS, FIXTURE_SHELF)
NATIVE_HAND_SIZE = 5
LONG_MOTION_CARD = "cinderweave_guard"
SHORT_MOTION_CARD = "patch_up"
HEADLESS_WORKERS = 3
HEADLESS_FIXED_FPS = 60


def git(*args, project=PROJECT):
    return subprocess.check_output(["git", "-C", str(project), *args], text=True).strip()


def stage_census(directory):
    directory.mkdir()
    for name in ("census.gd", "census_input.gd", "census_states.gd", "shots.json", "layout_check.gd"):
        folder = "pol67" if name == "layout_check.gd" else "scn01"
        source = git("show", f"{POL67}:tools/{folder}/{name}")
        source = source.replace("res://tools/scn01/", "").replace("res://tools/pol67/", "")
        (directory / name).write_text(source + "\n")
    geometry = git("show", "codex/pol-68:tools/scn01/census_geometry.gd")
    (directory / "census_geometry.gd").write_text(geometry.replace("res://tools/pol67/", "") + "\n")
    probe = directory / "census_probe.gd"
    probe.write_bytes((HERE / "census_probe.gd.in").read_bytes())
    (directory / "title_motion.gd").write_bytes((HERE / "title_motion.gd.in").read_bytes())
    return probe


def headless_baseline(baseline, root):
    # Isolate source revision from workstation import-cache differences.
    # Native captures still open the actual before and after worktrees.
    project = root / "candidate4"
    project.mkdir()
    for entry in baseline.iterdir():
        if not entry.name.startswith("."):
            (project / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
    (project / ".godot").symlink_to(PROJECT / ".godot", target_is_directory=True)
    return project


def shot_plan(probe):
    original = json.loads(probe.with_name("shots.json").read_text())
    plan = {row["shot"]: row for row in original["shots"]}
    for name, base in (("draw_pile", "combat"), ("grimoire_card", "combat_grimoire"),
                       ("scavenger_receipt", "scavenger"), (FIXTURE_SHELF, "scavenger"),
                       ("event_card", "event"), ("event_transform", "event"), ("long_hand", "combat"),
                       ("motion_long", "combat"), ("motion_short", "combat")):
        plan[name] = dict(plan[base], shot=name)
    plan["event_card"].update(flags=["--event-id", "whispering_well", "--embers", "100"], choice_index=1)
    plan["event_transform"].update(flags=["--event-id", "mirror_of_skins"], choice_index=0)
    plan["scavenger_receipt"].update(flags=["--embers", "1000"], card_id="doppelganger")
    plan[FIXTURE_SHELF]["shelf_cards"] = ["shattered_reflection", "cinderweave_guard"]
    plan["grimoire_card"].update(card_id="frost_heave", unlock="magick:frost_heave")
    plan["long_hand"]["motion_strip"] = True
    plan["motion_short"].update(flags=["--hand", "patch_up,quick_stab,brace"], motion_card=SHORT_MOTION_CARD)
    for shot in plan.values():
        shot.setdefault("seed", original["default_seed"])
        shared = original["fixture_sets"].get(shot.get("fixture"), [])
        shot["fixture_args"] = [
            "--scenario", shot["scenario"], "--seed", str(shot["seed"]), *shared, *shot.get("flags", []),
        ]
    return plan


def write_json(path, payload):
    path.write_text(json.dumps(payload, indent=2) + "\n")


def run(command, log_path, *, cel_look="all", windowed=False):
    env = dict(os.environ, LABYRINTH_CEL_LOOK=cel_look)
    if windowed:
        env["POL70_WINDOWED_ENGINE"] = "1"
    with log_path.open("w") as log:
        result = subprocess.run(command, cwd=PROJECT, env=env, stdout=log, stderr=subprocess.STDOUT)
    output = log_path.read_text(errors="replace")
    if result.returncode:
        raise ValueError(f"Exit {result.returncode}. See {log_path}")
    return output


def receipt(output, marker):
    for line in reversed(output.splitlines()):
        if line.startswith(marker + " "):
            return json.loads(line.removeprefix(marker + " "))
    raise ValueError(f"Missing {marker} receipt")


def godot(project, script, *engine_args):
    return [
        sys.executable, "tools/godot_task_runner.py", "--task-id", "pol-70", "--stream",
        "--", "godot", "--headless", *engine_args, "--path", str(project), "--script", str(script),
    ]


def capture(project, target, probe, shot, dry_run):
    name = shot["shot"]
    shot = dict(shot, titles_crop=name in NATIVE_SHOTS, measure_names=dry_run and name in CATALOG_SHOTS)
    fixture = receipt(run(
        [*godot(project, "tools/inspection_fixture.gd"), "--", *shot["fixture_args"]],
        target / f"{name}-fixture.log", cel_look="off",
    ), "INSPECTION_FIXTURE_RESULT")
    profile = Path(fixture["progression_path"])
    settings = profile.with_name("settings.json")
    if shot.get("unlock"):
        data = json.loads(profile.read_text())
        data.setdefault("grimoire_unlocked", []).append(shot["unlock"])
        profile = target / f"{name}-profile.json"
        write_json(profile, data)
    png = target / f"{name}.png"
    crop = target / f"{name}_titles_2x.png"
    strip = target / f"{name}_hover_strip.png"
    arguments = [
        "--save", fixture["save_path"], "--profile", str(profile),
        "--settings", str(settings),
        "--mode", fixture["mode"], "--size", SIZE, "--png", str(png), "--shot", json.dumps(shot),
    ]
    if dry_run:
        command = [*godot(project, probe, "--fixed-fps", str(HEADLESS_FIXED_FPS)), "--", *arguments, "--dry-run"]
    else:
        contract = target / f"{name}-contract.json"
        images = [
            {"pattern": png.name, "width": 1920, "height": 1080}, {"pattern": crop.name},
        ]
        if shot.get("motion_strip"):
            images.append({"pattern": strip.name})
        write_json(contract, {"min_images": len(images), "required_images": images})
        command = [
            sys.executable, "tools/visual_probe_runner.py", str(probe), "--project", str(project),
            "--task-id", "pol-70", "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--godot", str(HERE / "native.sh"), "--proof-contract", str(contract),
            "--result-manifest", str(target / f"{name}-native.json"), "--", *arguments,
        ]
    log = target / f"{name}-probe.log"
    output = run(command, log, windowed=not dry_run)
    result = receipt(output, "CENSUS_RESULT")
    if not result["ok"] or result["capped"]:
        raise ValueError(f"{name} did not settle. See {log}")
    if not dry_run:
        with crop.open("rb") as png_file:
            dimensions = struct.unpack(">II", png_file.read(24)[16:24])
        if list(dimensions) != result["crop_size"]:
            raise ValueError(f"{crop} did not match the 2x crop geometry")
        print(png, flush=True)
        print(crop, flush=True)
        if shot.get("motion_strip"):
            print(strip, flush=True)
    hits = sum(is_title_hit(hit) for hit in result["layout_hits"])
    print(f"{target.name}/{name}: settled; {hits} card-title small_font hits; {len(result['titles'])} titles", flush=True)
    if "step_counts" in result:
        steps = result["step_counts"]
        print(f"{target.name}/{name}: {result['catalog_size']} names; "
              + ", ".join(f"step {step}={steps.get(str(step), 0)}" for step in range(1, 6)), flush=True)
    for sample in result.get("shelf_motion", ()):
        print(f"{target.name}/{name}/{sample['id']}: {sample['frames']} hover frames; "
              f"source px {sample['source_px']}; {sample['refits']} refits; peak lift scale {sample['peak_scale']:.3f}", flush=True)
    return dict(result, shot=name, title_small_font_hits=hits)


def is_title_hit(hit):
    return hit["kind"] == "small_font" and hit["node"].endswith("/Margin/VBox/TopRow/Title")


def collect(project, target, probe, plan, names, dry_run):
    target.mkdir()
    if dry_run:
        with ThreadPoolExecutor(max_workers=HEADLESS_WORKERS) as pool:
            rows = list(pool.map(lambda name: capture(project, target, probe, plan[name], True), names))
    else:
        rows = [capture(project, target, probe, plan[name], False) for name in names]
    return rows


def manifest(target, dry_run, rows):
    write_json(target / "manifest.json", {"size": SIZE, "ui_scale": 1.0, "dry_run": dry_run, "shots": rows})


def write_catalog(path, rows):
    fields = ("context", "id", "name", "step", "effective_px", "spacing_source_px", "fits",
              "width_px", "available_px", "ellipsis")
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle, dialect="excel-tab")
        writer.writerow(fields)
        for row in rows:
            for title in row.get("catalog", ()):
                writer.writerow((row["shot"], title["id"], title["name"], title["step"],
                                 f"{title['px']:.4f}", title["spacing"], "yes" if title["fits"] else "no",
                                 f"{title['width_px']:.4f}", f"{title['available_px']:.4f}",
                                 "yes" if title["ellipsis"] else "no"))


def check_miniature_pixels(before, after):
    old = {row["shot"]: row for row in before}
    for current in after:
        name = current["shot"]
        if name not in ROW_PROOF_SHOTS:
            continue
        if old[name]["crop_pixels_sha256"] != current["crop_pixels_sha256"]:
            raise ValueError(f"{name}: miniature title crop pixels differ")
        print(f"{name}: miniature title crop pixels match")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--baseline", type=Path, default=PROJECT.parent / "mrg-15")
    parser.add_argument("--title-rows", action="store_true", help="Capture and compare the miniature title crops.")
    parser.add_argument("--round1", type=Path, default=OUTPUT_ROOT / "round1-final" / "after" / "manifest.json",
                        help="Round 1 after manifest for the headless title-table comparison.")
    parser.add_argument("--smoke-shot", choices=(*CENSUS_SHOTS, *ADDITIONAL_SHOTS), help=argparse.SUPPRESS)
    args = parser.parse_args()
    baseline = args.baseline.resolve()
    if git("rev-parse", "HEAD", project=baseline) != BASELINE or git("--no-optional-locks", "status", "--porcelain", project=baseline):
        parser.error("The baseline must be a clean candidate 4 worktree at " + BASELINE)
    output = args.out or Path(tempfile.mkdtemp(prefix="headless-" if args.dry_run else "native-", dir=OUTPUT_ROOT))
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    print(f"POL70 OUTPUT: {output}", flush=True)
    try:
        probe = stage_census(output / "harness")
        plan = shot_plan(probe)
        if args.smoke_shot:
            target = output / "after"
            rows = collect(PROJECT, target, probe, plan, (args.smoke_shot,), True)
            manifest(target, True, rows)
            return
        if args.dry_run:
            baseline = headless_baseline(baseline, output)
        if args.title_rows:
            miniature = []
            for side, project in (("before", baseline), ("after", PROJECT)):
                rows = collect(project, output / side, probe, plan, ROW_PROOF_SHOTS, args.dry_run)
                manifest(output / side, args.dry_run, rows)
                miniature.append(rows)
            if not args.dry_run:
                check_miniature_pixels(*miniature)
            return
        if args.dry_run:
            names = (*CENSUS_SHOTS, *(shot for shot in ADDITIONAL_SHOTS if shot != "motion_long"))
            before = collect(baseline, output / "before", probe, plan, names, True)
        else:
            before = []
            ranking = collect(baseline, output / "ranking", probe, plan, ("combat",), True)[0]
        if args.dry_run:
            ranking = before[0]
        ids = [row["id"] for row in ranking["longest_at_floor"][:NATIVE_HAND_SIZE]]
        if len(ids) != NATIVE_HAND_SIZE:
            raise ValueError("Could not rank a full native proof hand")
        plan["long_hand"]["fixture_args"].extend(("--hand", ",".join(ids)))
        plan["long_hand"]["motion_card"] = ids[0]
        plan["motion_long"].update(motion_card=LONG_MOTION_CARD, fixture_args=plan["long_hand"]["fixture_args"].copy())
        if args.dry_run:
            before.append(capture(baseline, output / "before", probe, plan["long_hand"], True))
            before.append(capture(baseline, output / "before", probe, plan["motion_long"], True))
            names = (*names, "long_hand", "motion_long")
        else:
            names = NATIVE_SHOTS
            before = collect(baseline, output / "before", probe, plan, names, False)
        manifest(output / "before", args.dry_run, before)
        after = collect(PROJECT, output / "after", probe, plan, names, args.dry_run)
        manifest(output / "after", args.dry_run, after)
        if args.dry_run:
            from compare_rects import check
            write_catalog(output / "title_fit.tsv", after)
            return check(output, CENSUS_SHOTS, args.round1)
        check_miniature_pixels(before, after)
        return 0
    except (OSError, KeyError, ValueError, subprocess.CalledProcessError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())

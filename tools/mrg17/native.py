#!/usr/bin/env python3
"""Capture the approved MRG-17 fixtures from the caller's working tree."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUTPUT = Path("/private/tmp/labyrinth_codex/mrg-17")
SIZE = "1920x1080"
FPS = "60"
TIMEOUT = "180"
TASK = "mrg-17"

sys.path.insert(0, str(ROOT / "tools"))
from pol70 import proof as titles
from pol71 import proof as playback
from fx38 import stage_project as kindle


def run(command, log, env=None):
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    output = log.read_text(errors="replace")
    if result.returncode:
        print(output[-6000:], file=sys.stderr)
        raise RuntimeError(f"Exit {result.returncode}. See {log}")
    return output


def capture(project, script, contract, folder, dry, args, *, plan=(), engine=(), movie=False, name=None):
    folder.mkdir(parents=True, exist_ok=True)
    if dry:
        command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK, "--stream",
                   "--", "godot", "--headless", *engine, "--path", str(project), "--script", str(script),
                   "--", *args, *plan]
        output = run(command, folder / "probe.log")
        for line in output.splitlines():
            if line.startswith(("FX-38", "POL73", "POL71 gameplay proof:", "ECO-02")):
                print(line, flush=True)
        return
    command = [sys.executable, str(ROOT / "tools/visual_probe_runner.py"), str(script), "--project", str(project),
               "--task-id", TASK, "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
               "--timeout", TIMEOUT, "--expect-size", SIZE, "--proof-contract", str(contract),
               "--result-manifest", str(folder / "manifest.json")]
    env = os.environ.copy()
    clock = folder / "clock.avi"
    if movie:
        env.update(MRG17_MOVIE_CLOCK="1", MRG17_MOVIE_FILE=str(clock))
        command.extend(("--godot", str(HERE / "native.sh")))
    run([*command, "--", *args], folder / "probe.log", env)
    if movie:
        clock.unlink(missing_ok=True)
    if name:
        print(folder / name, flush=True)
    else:
        print(folder, flush=True)


def kindle_probe(folder, dry, scratch):
    project = scratch / "kindle-project"
    project.mkdir()
    kindle.stage(ROOT, project, "plan" if dry else "native", False)
    source = (ROOT / "tools/fx38/native.gd").read_text()
    # Continue and shader prewarm still run under the production root. The
    # initialized combat scene then moves to the exact-size capture viewport.
    source = source.replace("var _board: Control", "var _board: Control\nvar _capture_viewport: SubViewport")
    source = source.replace(
        "\tif _round0_order: return true\n",
        "\tif _round0_order: return true\n"
        "\t_capture_viewport = CaptureViewport.create(root)\n"
        "\tSettings.inherit_edge_smoothing(_capture_viewport, root)\n"
        "\tcurrent_scene = null\n"
        "\t_scene.reparent(_capture_viewport, false)\n",
    )
    source = source.replace("Vector2i(root.get_visible_rect().size)", "Vector2i(_scene.get_viewport_rect().size)")
    source = source.replace("var image: Image = root.get_texture().get_image()",
                            "var image: Image = _capture_viewport.get_texture().get_image()")
    for name in ("pixels", "base_pixels", "loading_cover"):
        source = source.replace(f'preload("{name}.gd")', f'preload("res://tools/fx38/{name}.gd")')
    probe = project / ".godot" / "kindle_capture.gd"
    probe.write_text(source)
    capture(project, probe, ROOT / "tools/fx38/after.json", folder, dry, ("--out", str(folder)),
            plan=("--plan",), engine=("--fixed-fps", FPS), movie=True)


def title_run(command, log, *, cel_look="all", windowed=False):
    command = command.copy()
    task = command.index("--task-id") + 1
    command[task] = TASK
    if windowed:
        command[command.index("--godot") + 1] = str(HERE / "native.sh")
    env = dict(os.environ, LABYRINTH_CEL_LOOK=cel_look, POL70_WINDOWED_ENGINE="1" if windowed else "0")
    return run(command, log, env)


def title_probe(folder, dry, scratch, *, full=False):
    titles.run = title_run
    probe = titles.stage_census(scratch / "title-harness")
    plan = titles.shot_plan(probe)
    # Approved pol-70 round 2 long-hand fixture order.
    hand = ["shattered_reflection", "rite_of_the_mountain", "cinderweave_guard",
            "lodestone_reversal", "bone_ward_charm"]
    plan["long_hand"]["fixture_args"].extend(("--hand", ",".join(hand)))
    plan["long_hand"]["motion_card"] = hand[0]
    plan["motion_long"].update(motion_card=titles.LONG_MOTION_CARD,
                               fixture_args=plan["long_hand"]["fixture_args"].copy())
    names = ("long_hand", titles.FIXTURE_SHELF)
    if full:
        names = (*titles.CATALOG_SHOTS, *titles.ROW_PROOF_SHOTS, *titles.MOTION_SHOTS, *names)
    rows = titles.collect(ROOT, folder, probe, plan, names, dry)
    titles.manifest(folder, dry, rows)
    by_name = {row["shot"]: row for row in rows}
    shelf = by_name[titles.FIXTURE_SHELF]["shelf_motion"]
    assert {sample["id"]: (sample["source_px"], sample["refits"]) for sample in shelf} == {
        "shattered_reflection": (15, 0), "cinderweave_guard": (16, 0),
    }
    if full:
        titles.write_catalog(folder / "title_fit.tsv", rows)
        for name in titles.CATALOG_SHOTS:
            row = by_name[name]
            assert row["catalog_size"] == 305, name
            assert sum(int(value) for value in row["step_counts"].values()) == 305, name
        print("MRG-17 TITLE CENSUS PASS (8 contexts, 2440 names)", flush=True)


def playback_probe(folder, dry, scratch, *, use_single_capture=False):
    shot = "block_confirm_36"
    shots = [shot] if use_single_capture else [
        *(f"block_confirm_{frame:02d}" for frame in range(0, 49, 2)),
        "expose_divergent_00", "expose_divergent_delivery",
    ]
    contract = scratch / "playback.json"
    images = playback.expected_images(shots)
    contract.write_text(json.dumps({"min_images": len(images), "expected_sizes": [SIZE],
                                    "required_images": images}))
    probe = ROOT / "tools/pol71/capture.gd"
    if use_single_capture and not dry:
        source = probe.read_text().replace('preload("capture_geometry.gd")',
                                           'preload("res://tools/pol71/capture_geometry.gd")')
        source = source.replace('\tawait _play("push_ice_disagreement", "crosswind", "", "ice", FOE_TILE)\n', "")
        source = source.replace("if dry_run: return\n\tif not _check(image",
                                f'if dry_run or name != "{shot}": return\n\tif not _check(image')
        probe = scratch / "playback.gd"
        probe.write_text(source)
    capture(ROOT, probe, contract, folder, dry, (str(folder),), plan=("--dry-run",))
    if dry:
        receipt = json.loads((folder / "receipt.json").read_text())
        approved = OUTPUT.parent / "pol-71/headless-y3e3jt71/before/receipt.json"
        if approved.exists():
            playback.verify(json.loads(approved.read_text()), receipt)



def economy_probe(folder, dry, scratch):
    source = (ROOT / "tools/eco02/native.gd").read_text()
    # Sample bounds from the current production layout. The cached draw list
    # can lag the submitted presentation at the frame-post-draw signal.
    source = source.replace("dry or _capture_float_crop()", "_capture_float_crop()")
    source = source.replace("board._floating_text_last_layout",
                            "board._floating_text_screen_layout(board.get_theme_default_font())")
    pixels = "\tvar image: Image = viewport.get_texture().get_image().get_region(clip)"
    assert source.count(pixels) == 1
    source = source.replace(
        pixels, '\tif dry:\n\t\tprint("ECO-02 DUAL FLOAT CROP PLAN: %s" % clip)\n\t\treturn true\n' + pixels,
    )
    if dry:
        # The approved Fire fixture also witnesses the two presentation
        # changes in the same committed card play.
        setup = "\tvar widest_float_set: Dictionary = {}\n"
        sample = '\t\t\tif str(item.get("icon", "")) == "card_play" and str(item.get("text", "")) == "+1":\n'
        finish = "\t_expect(sampled_beats == BEAT_SAMPLES.size(), key + \" samples all death-beat frames.\")\n"
        assert all(source.count(marker) == 1 for marker in (setup, sample, finish))
        source = source.replace(
            setup, setup + "\tvar fire_damage_frame: int = -1\n\tvar death_reward_frame: int = -1\n",
        )
        source = source.replace(
            sample,
            '\t\t\tif fire_damage_frame < 0 and item.get("icon") == "surface_fire" and str(item.get("text", "")).begins_with("−"):\n'
            "\t\t\t\tfire_damage_frame = Engine.get_process_frames()\n" + sample +
            '\t\t\t\tif death_reward_frame < 0 and item.get("trailing_icon") == "time" and item.get("trailing_text") == "−5":\n'
            "\t\t\t\t\tdeath_reward_frame = Engine.get_process_frames()\n",
        )
        source = source.replace(
            finish, finish +
            '\tif key == "push_into_fire":\n'
            "\t\tvar both: bool = fire_damage_frame >= 0 and death_reward_frame >= fire_damage_frame\n"
            '\t\t_expect(both, "Lethal Push shows the Fire damage label and the Card Play and Time popup.")\n'
            '\t\tprint("ECO-02 FIRE AND DEATH LABELS: %s (damage frame=%d, rewards frame=%d)" % ["PASS" if both else "FAIL", fire_damage_frame, death_reward_frame])\n',
        )
    probe = scratch / "economy.gd"
    probe.write_text(source)
    capture(ROOT, probe, ROOT / "tools/eco02/native_round1_contract.json", folder, dry,
            ("--edition", "after", "--output", str(folder)), plan=("--dry-run",))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("edition", choices=("a", "b"))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--full-title-census", action="store_true")
    args = parser.parse_args()
    if Path.cwd() != ROOT:
        parser.error(f"Run from {ROOT}")
    if args.edition == "b" and not (ROOT / "tools/eco02/native.gd").is_file():
        parser.error("Part B requires the integrated eco-02 playtest files.")
    output = Path(tempfile.mkdtemp(prefix=f"{args.edition}-{'headless' if args.dry_run else 'native'}.", dir=OUTPUT))
    print(output, flush=True)
    with tempfile.TemporaryDirectory(prefix="mrg17-native.", dir=ROOT / ".godot") as directory:
        scratch = Path(directory)
        if args.edition == "a":
            tasks = [
                lambda: kindle_probe(output / "kindle", args.dry_run, scratch),
                lambda: title_probe(output / "titles", args.dry_run, scratch, full=args.full_title_census),
                lambda: playback_probe(output / "playback", args.dry_run, scratch),
                lambda: capture(ROOT, ROOT / "tools/pol73/capture.gd", ROOT / "tools/pol73/proof-after.json",
                                output / "intent", args.dry_run, (f"--output={output / 'intent'}",),
                                plan=("--validate-only",)),
            ]
        else:
            tasks = [
                lambda: economy_probe(output / "economy", args.dry_run, scratch),
                lambda: playback_probe(output / "playback", args.dry_run, scratch, use_single_capture=True),
            ]
        with ThreadPoolExecutor(max_workers=len(tasks) if args.dry_run else 1) as workers:
            for result in [workers.submit(task) for task in tasks]:
                result.result()
    print(f"MRG-17 {args.edition.upper()} {'DRY RUN' if args.dry_run else 'NATIVE'} PASS", flush=True)


if __name__ == "__main__":
    main()

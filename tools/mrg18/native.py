#!/usr/bin/env python3
"""Prepare and capture the approved candidate 7 scenes."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUTPUT = Path("/private/tmp/labyrinth_codex/mrg-18")
TASK = "mrg-18"
SIZE = "1920x1080"
TIMEOUT = "180"
FIXED_FPS = "60"
SKILL_IDS = ("quick_wits", "living_shadow", "open_sky")
SKILLS = "combat_character_skills"
PROOF_GROUPS = ("aim", "skills-and-fire", "boss", "objective", "badges", "shop", "kindle")

sys.path.insert(0, str(ROOT / "tools"))
from fx38 import stage_project
from scn01 import census

RUNNER = [sys.executable, "tools/godot_task_runner.py", "--task-id", TASK, "--timeout", TIMEOUT,
          "--stream", "--", "godot", "--headless"]


def read_result(output, marker):
    result = census.payload_line(output, marker)
    if not result.get("ok"):
        raise ValueError(f"{marker}: {result.get('error') or 'missing successful receipt'}")
    return result


def run(command, log, env=None):
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    output = log.read_text(errors="replace")
    for line in output.splitlines():
        if line.startswith(("POL62 after:", "ROTATABLE CARD AIM:", "POL66 after", "POL69 CENSUS",
                            "POL74 SHOP READABILITY", "FX-38", "POL69 gameplay proof:")):
            print(line, flush=True)
    if result.returncode:
        print(output[-6000:], file=sys.stderr)
        raise RuntimeError(f"Exit {result.returncode}. See {log}")
    return output


def contract(folder, names):
    file = folder / "proof.json"
    file.write_text(json.dumps({
        "min_images": len(names), "expected_sizes": [SIZE],
        "required_images": [
            {"pattern": name, "width": 1920, "height": 1080, "regions": [
                {"rect": [240, 72, 1440, 850], "min_luma_range": 12, "min_luma_stdev": 2}
            ]} for name in names
        ],
    }))
    return file


def capture(folder, script, args, proof, dry, *, dry_args=(), env=None, project=ROOT, fixed=False, movie=False):
    folder.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all", **(env or {}))
    if dry:
        clock = ["--fixed-fps", FIXED_FPS] if fixed else []
        command = [*RUNNER, *clock, "--path", str(project), "--script", str(script), "--", *args, *dry_args]
    else:
        command = [sys.executable, "tools/visual_probe_runner.py", str(script), "--project", str(project),
                   "--task-id", TASK, "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
                   "--timeout", TIMEOUT, "--proof-contract", str(proof),
                   "--result-manifest", str(folder / "visual.json")]
        if movie:
            env.update(MRG18_MOVIE_CLOCK="1", MRG18_MOVIE_FILE=str(folder / "capture-clock.avi"))
            command.extend(("--godot", str(HERE / "native.sh")))
        command.extend(("--", *args))
    log = run(command, folder / "probe.log", env)
    if movie:
        (folder / "capture-clock.avi").unlink(missing_ok=True)
    print(folder, flush=True)
    return log


def stage_script(source, target, *, sizes=False):
    # Staged harness scripts still resolve their adjacent source dependencies.
    text = source.read_text()
    if sizes:
        text = text.replace("[Vector2i(1920, 1080), Vector2i(1280, 800)]", "[Vector2i(1920, 1080)]")
    relative = source.parent.relative_to(ROOT).as_posix()
    text = re.sub(r'preload\("(?!res://)([^"]+)"\)', rf'preload("res://{relative}/\1")', text)
    target.write_text(text)
    return target


def aim(folder, dry):
    folder.mkdir()
    env = dict(os.environ, LABYRINTH_POL62_PROOF_ROOT=str(folder / "line"))
    run(["bash", "tools/pol62/native.sh", "--fixtures", "--task-id", TASK], folder / "fixtures.log", env)
    capture(folder / "line", ROOT / "tools/pol62/capture.gd", ("--after",),
            ROOT / "tools/pol62/proof_contract.json", dry, env={"LABYRINTH_POL62_PROOF_ROOT": str(folder / "line")})
    area = folder / "area"
    capture(area, ROOT / "tests/rotatable_card_aim_probe.gd",
            ("--proof-phase=after", f"--proof-output={area}"),
            ROOT / "tests/rotatable_card_aim_probe_contract.json", dry)
    census_shot(folder / "area-pattern", "cinderburst", dry, plan=HERE / "area_shot.json")
    print("MRG-18 AREA AIM: PASS (Cinderburst)", flush=True)


def fixture(folder, flags):
    return read_result(run([*RUNNER, "--path", ".", "--script", "tools/inspection_fixture.gd", "--", *flags],
                           folder / "fixture.log", dict(os.environ, LABYRINTH_CEL_LOOK="off")),
                       "INSPECTION_FIXTURE_RESULT")


def census_shot(folder, name, dry, *, plan=None, script="tools/scn01/census.gd"):
    folder.mkdir()
    shots = census.shot_plan(plan) if plan else census.shot_plan()
    shot = next(shot for shot in shots if shot["shot"] == name)
    state = fixture(folder, shot["flags"])
    profile = Path(state["progression_path"])
    args = ("--save", state["save_path"], "--profile", str(profile), "--settings",
            str(profile.with_name("settings.json")), "--mode", state["mode"], "--size", SIZE,
            "--png", str(folder / f"{name}.png"), "--shot", json.dumps(shot), "--rects")
    result = read_result(capture(folder, ROOT / script, args, contract(folder, [f"{name}.png"]),
                                 dry, dry_args=("--dry-run",)), "CENSUS_RESULT")
    return state, result


def skills(folder, dry, scratch):
    folder.mkdir()
    state, result = census_shot(folder / "headers", SKILLS, dry, script="tools/pol69/census_measure.gd")
    headers = result["headers"]
    if len(headers) != 5 or any(row["source_px"] != 17 or row["gap_px"] < 0 for row in headers.values()):
        raise ValueError(f"Unexpected branch headers: {headers}")
    print("MRG-18 SKILL HEADERS: PASS (5 at 17 px)", flush=True)
    links = folder / "links"
    links.mkdir()
    source = ROOT / "tools/pol66/capture.gd"
    if not dry:
        source = stage_script(source, scratch / "skill_links.gd", sizes=True)
    capture(links, source, ("after", str(links), str(Path(state["save_path"]).parent)),
            contract(links, [f"{SIZE}_{name}.png" for name in SKILL_IDS]), dry)
    return state


def shop(folder, dry, scratch):
    shot = stage_script(ROOT / "tools/pol74/shop_readability.gd.in", scratch / "shop_readability.gd")
    capture(folder, shot, ("--output", str(folder)), ROOT / "tools/pol74/native_contract.json", dry, fixed=True)


def kindle(folder, dry, scratch):
    project = scratch / "kindle-project"
    project.mkdir()
    stage_project.stage(ROOT, project, "plan" if dry else "native", False)
    source = stage_script(ROOT / "tools/fx38/native.gd", project / ".godot" / "kindle_capture.gd")
    text = source.read_text()
    text = text.replace("var _board: Control", "var _board: Control\nvar _capture_viewport: SubViewport")
    text = text.replace(
        "\tif _round0_order: return true\n",
        "\tif _round0_order: return true\n"
        "\t_capture_viewport = CaptureViewport.create(root)\n"
        "\tSettings.inherit_edge_smoothing(_capture_viewport, root)\n"
        "\tcurrent_scene = null\n"
        "\t_scene.reparent(_capture_viewport, false)\n",
    )
    text = text.replace("Vector2i(root.get_visible_rect().size)", "Vector2i(_scene.get_viewport_rect().size)")
    text = text.replace("root.get_texture().get_image()", "_capture_viewport.get_texture().get_image()")
    text = text.replace("\tif not _before:\n\t\tif not _check_sprite_profiles()", "\tif not _before and _plan:\n\t\tif not _check_sprite_profiles()")
    text = text.replace('\tif not _save(image, "%s_full.png" % name): return false',
                        '\tif name == "kindled": return _save(image, "kindled_full.png")\n'
                        '\tif not _save(image, "%s_full.png" % name): return false')
    source.write_text(text)
    folder.mkdir()
    capture(folder, source, ("--out", str(folder)), contract(folder, ["kindled_full.png"]), dry,
            project=project, fixed=True, movie=True, dry_args=("--plan",))


def fire(folder, dry, state):
    path = ROOT / "tools/pol69/capture.gd"
    proof = folder / "proof.json"
    folder.mkdir()
    names = ["enemy_fire_peak", "event_open", "event_closed", "hero_fire_peak", "fresh_run"]
    proof.write_text(json.dumps({
        "min_images": len(names), "expected_sizes": [SIZE, "512x288"],
        "required_images": [{"pattern": name + ".png", "width": 1920, "height": 1080} for name in names],
    }))
    capture(folder, path, (str(folder), state["save_path"], "--expect-enemy-icon"), proof,
            dry, dry_args=("--dry-run",))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Run the same proof fixtures headless.")
    parser.add_argument("--only", choices=PROOF_GROUPS, help="Run one proof group.")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="headless." if args.dry_run else "native.", dir=OUTPUT))
    print(output, flush=True)
    failures = []
    with tempfile.TemporaryDirectory(prefix="mrg18-native.", dir=ROOT / ".godot") as directory:
        scratch = Path(directory)

        def skills_and_fire():
            state = skills(output / "skills", args.dry_run, scratch)
            fire(output / "fire", args.dry_run, state)

        steps = {
            "aim": lambda: aim(output / "aim", args.dry_run),
            "skills-and-fire": skills_and_fire,
            "boss": lambda: census_shot(output / "boss", "boss", args.dry_run),
            "objective": lambda: census_shot(output / "objective", "guardian", args.dry_run),
            "badges": lambda: census_shot(output / "badges", "header_badges", args.dry_run,
                                         plan=ROOT / "tools/pol68/badge_shot.json"),
            "shop": lambda: shop(output / "shop", args.dry_run, scratch),
            "kindle": lambda: kindle(output / "kindle", args.dry_run, scratch),
        }
        if args.only:
            steps = {args.only: steps[args.only]}
        for name, step in steps.items():
            try:
                step()
            except (RuntimeError, ValueError, OSError) as error:
                failures.append(name)
                print(f"{name}: {error}", file=sys.stderr, flush=True)
    mode = "DRY RUN" if args.dry_run else "NATIVE"
    status = "PASS" if not failures else "FAIL"
    print(f"MRG-18 {mode} {status} ({len(steps) - len(failures)}/{len(steps)} proof groups)")
    return bool(failures)


if __name__ == "__main__":
    sys.exit(main())

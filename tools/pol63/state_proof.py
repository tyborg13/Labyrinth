#!/usr/bin/env python3
"""Log exact UI copy, font fit and left-stack geometry through Continue."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scn01"))
from census import PROJECT, capture_log, payload_line, shot_plan

SEED = 7262026
JOBS = 3
SIZES = ("1920x1080", "1280x800")
RUNNER = [sys.executable, "tools/godot_task_runner.py", "--task-id", "pol-63", "--stream",
          "--", "godot", "--headless", "--path", "."]
ENTRY_RECT_TOLERANCE = 0.01
NATIVE_TIMEOUT = 70
OTHER_SCREENS = ("reach_exit", "reward", "campfire", "treasure", "scavenger",
                 "graftwright", "victory", "defeat", "event", "pre_battle")


def plan():
    census = {shot["shot"]: shot for shot in shot_plan()}
    specials = json.loads((PROJECT / "data/special_encounters.json").read_text())
    enemies = json.loads((PROJECT / "data/enemies.json").read_text())
    cases = [
        *({"shot": f"warband_{biome}", "scenario": "warband",
           "flags": ["--warband-biome", biome]} for biome in specials["types"]["warband"]["variants"]),
        *({"shot": f"guardian_{enemy_id}", "scenario": "guardian",
           "flags": ["--guardian-id", enemy_id]} for enemy_id, enemy in enemies.items() if enemy.get("guardian")),
        *(shot for name, shot in census.items() if name.startswith("dragon_")),
        *(census[name] for name in ("ember_hoarder", "last_light", "snare", "combat_idle", *OTHER_SCREENS)),
        {**census["guardian"], "shot": "guardian_layout", "exercise_layout": True},
        {**census["start"], "shot": "waypoint", "reveal_waypoint": True},
    ]
    for source in ("combat_idle", "guardian"):
        for entry in ("continue", "door"):
            cases.append({**census[source], "shot": f"{source}_{entry}", "entry": entry,
                          "exercise_layout": True})
    for case in cases:
        if case["shot"] == "combat_idle":
            case["exercise_layout"] = True
        if "seed" not in case:
            case["seed"] = SEED
            case["flags"] = ["--scenario", case["scenario"], "--seed", str(SEED), *case["flags"]]
    return cases


def verify(case, size, out, native=False):
    name = case["shot"]
    fixture_log = out / f"{name}.fixture.log"
    probe_log = out / f"{name}-{size}.log"
    if not fixture_log.is_file():
        _, output = capture_log([*RUNNER, "--script", "tools/inspection_fixture.gd", "--", *case["flags"]],
                                dict(os.environ, LABYRINTH_CEL_LOOK="off"), fixture_log)
    else:
        output = fixture_log.read_text()
    fixture = payload_line(output, "INSPECTION_FIXTURE_RESULT")
    if not fixture.get("ok"):
        return name, [], f"Fixture failed. See {fixture_log}"
    png = out / f"{name}-{size}.png"
    args = ["--save", fixture["save_path"], "--profile", fixture["progression_path"],
            "--settings", str(Path(fixture["progression_path"]).with_name("settings.json")),
            "--mode", fixture["mode"], "--size", size, "--shot", json.dumps(case),
            "--png", str(png)]
    script = "tools/pol63/entry_probe.gd" if case.get("entry") else "tools/pol63/state_probe.gd"
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all")
    if native:
        contract = out / f"{name}-contract.json"
        width, height = map(int, size.split("x"))
        contract.write_text(json.dumps({"min_images": 1, "expected_sizes": [size],
                                         "required_images": [{"pattern": png.name, "width": width, "height": height}]}))
        env["POL63_WINDOWED_ENGINE"] = "1"
        command = [sys.executable, "tools/visual_probe_runner.py", script, "--task-id", "pol-63",
                   "--no-headless", "--audio-driver", "Dummy", "--godot", str(PROJECT / "tools/pol63/native.sh"),
                   "--timeout", str(NATIVE_TIMEOUT), "--expect-size", size, "--proof-contract", str(contract),
                   "--result-manifest", str(out / f"{name}-manifest.json"), "--", *args]
    else:
        command = [*RUNNER, "--script", script, "--", *args, "--dry-run"]
    status, output = capture_log(command, env, probe_log)
    rows = [dict(kind=kind, **json.loads(payload))
            for line in output.splitlines() if line.startswith(("POL63_STATE ", "POL63_LAYOUT ", "POL63_ENTRY "))
            for kind, payload in [line.split(" ", 1)]]
    result = payload_line(output, "CENSUS_RESULT")
    error = "" if status == 0 and result.get("ok") else result.get("error") or f"See {probe_log}"
    return name, rows, error


def deadline_cases(cases):
    for case in cases:
        if not case.get("entry") or case["scenario"] != "combat":
            continue
        for setup, resolution, scale, unframed in (
            ("desktop", SIZES[0], 1.0, False),
            ("unframed", SIZES[0], 1.0, True),
            ("compact", SIZES[1], 1.0, False),
            ("scaled", SIZES[0], 1.15, False),
        ):
            yield (
                {**case, "shot": f"dock_{setup}_{case['entry']}", "deadline_proof": True,
                 "ui_scale": scale, "force_unframed": unframed, "check_entry": True,
                 "exercise_layout": setup == "desktop"},
                resolution,
            )


def compare_entries(rows):
    idle = {row["case"]: row for row in rows if row["kind"] == "POL63_ENTRY" and row["phase"] == "settled_idle"}
    errors = []
    for name, door in idle.items():
        if not name.endswith("_door") or (continued := idle.get(name.removesuffix("_door") + "_continue")) is None:
            continue
        for field, rect in door["stack"].items():
            other = continued["stack"][field]
            if len(rect) != len(other) or any(abs(a - b) > ENTRY_RECT_TOLERANCE for a, b in zip(rect, other)):
                errors.append(f"{name} {field} differs from Continue. {rect} / {other}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("before", "after"))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--only", help="Comma-separated case names.")
    parser.add_argument("--entry-census", action="store_true", help="Capture idle after door entry and Continue.")
    parser.add_argument("--native", action="store_true", help="Run the entry census with the native renderer.")
    parser.add_argument("--dock-deadline", action="store_true", help="Exercise the render-frame deadline headless.")
    args = parser.parse_args()
    if args.native and not args.entry_census:
        parser.error("--native requires --entry-census")
    if args.dock_deadline and (args.entry_census or args.phase != "after"):
        parser.error("--dock-deadline requires the after phase and a headless run")
    args.out = args.out.resolve()
    args.out.mkdir(parents=True, exist_ok=False)
    cases = plan()
    if args.dock_deadline:
        runs = list(deadline_cases(cases))
        cases = [case for case, _ in runs]
    if args.entry_census:
        cases = [case for case in cases if case.get("entry")]
    if args.only:
        names = set(args.only.split(","))
        if missing := names - {case["shot"] for case in cases}:
            parser.error(f"Unknown cases: {', '.join(sorted(missing))}")
        cases = [case for case in cases if case["shot"] in names]
    if args.dock_deadline:
        selected = {case["shot"] for case in cases}
        batches = [[(case, size) for case, size in runs if case["shot"] in selected]]
    else:
        sizes = SIZES if args.phase == "after" and not args.entry_census else SIZES[:1]
        batches = [
            [({**case, "check_fit": args.phase == "after",
               "check_entry": args.phase == "after" and bool(case.get("entry")),
               "exercise_layout": not args.entry_census and size == SIZES[0] and case.get("exercise_layout", False)},
              size)
             for case in cases
             if size == SIZES[0] or not case.get("entry") and case["scenario"] in (
                 "warband", "guardian", "dragon", "ember_hoarder", "snare", "last_light", "combat")]
            for size in sizes
        ]
    rows, errors = [], []
    with ThreadPoolExecutor(max_workers=1 if args.native else JOBS) as pool:
        for batch in batches:
            pending = [(pool.submit(verify, case, size, args.out, args.native), size) for case, size in batch]
            for task, size in pending:
                name, evidence, error = task.result()
                rows.extend(evidence)
                if error:
                    errors.append((name, size, error))
                print(f"{size} {name}: {error or 'observed'}", flush=True)
    if args.phase == "after":
        for error in compare_entries(rows):
            print(error, flush=True)
            errors.append(error)
    path = args.out / "state.json"
    path.write_text(json.dumps(rows, indent=2) + "\n")
    print(f"POL63 STATE PROOF: {'FAIL' if errors else 'PASS'}; {len(rows)} rows; {len(errors)} failures; {path}")
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())

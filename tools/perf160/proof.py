#!/usr/bin/env python3
"""Measure and verify the enemy-round handoff against its release parent."""
import argparse
from contextlib import ExitStack
import hashlib
import json
import os
from pathlib import Path
import platform
from statistics import median
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS / "perf148"))
import strict  # noqa: E402

BASE = "742158475c8bb50cb8ed180eabf0b1175ab45f07"
CHANGED = {"run_scene.gd", "board_threat_isolation.gd", "choice_refresh.gd",
           "retained_pass_preview.gd", "enemy_round_handoff.gd", "stage_hover_refresh.gd"}
PROBE = ROOT / "tools/perf160/probe.gd"
TASK = "perf-160"
PAIR_ORDER = ("AB", "BA", "AB", "BA", "AB")
PROFILES = ("normal", "background")
READY = "post_draw:run_scene:enemy_round_handoff_ready"
CHECKPOINT = "post_draw:run_scene:enemy_round_checkpoint_submit"
THRESHOLD_USEC = 33_000
SLOW_FRACTION = .60
LOAD_WORKERS = 4
REPROS = ("details", "target", "route", "starvation", "departure")
ENV = {"SteamDeck": "1", "LABYRINTH_CEL_LOOK": "all", "LABYRINTH_HITCH_TRACE": "1"}


def base_project(project):
    """Use pinned source with the shared assets and imported resources."""
    project.mkdir()
    for path in ROOT.iterdir():
        if path.name not in {".git", "scripts", "output"}:
            (project / path.name).symlink_to(path, target_is_directory=path.is_dir())
    scripts = project / "scripts"
    scripts.mkdir()
    for path in (ROOT / "scripts").iterdir():
        target = scripts / path.name
        if path.name == "enemy_round_handoff.gd":
            continue
        if path.name in CHANGED:
            target.write_bytes(subprocess.check_output(
                ["git", "show", f"{BASE}:scripts/{path.name}"], cwd=ROOT,
            ))
        else:
            target.symlink_to(path, target_is_directory=path.is_dir())
    return project


def run(command, log, environment):
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, env={**os.environ, **environment},
                                stdout=stream, stderr=subprocess.STDOUT)
    for line in log.read_text().splitlines():
        if line.startswith(("PERF-", "PTF08", "error:")):
            print(f"{log.parent.name} {line}", flush=True)
    if result.returncode:
        raise RuntimeError(f"Exit {result.returncode}, see {log}")


def take(project, script, output, fixtures, *, profile="normal", native=False,
         detail=False, capture="", args=(), environment=ENV):
    policy = ["taskpolicy", "-c", "background"] if profile == "background" else []
    output.mkdir(parents=True, exist_ok=True)
    script_args = [f"--fixtures={fixtures}", f"--output={output}", *args]
    if detail:
        script_args.append("--detail")
    if native:
        command = [sys.executable, str(TOOLS / "visual_probe_runner.py"), str(script),
                   "--task-id", TASK, "--project", str(project), "--no-headless",
                   "--display-driver", "macos", "--rendering-method", "mobile",
                   "--rendering-driver", "metal", "--audio-driver", "Dummy", "--timeout", "180",
                   "--result-manifest", str(output / "images.json")]
        if capture:
            command.extend(["--godot", str(TOOLS / "perf134/capture_godot.sh"),
                            "--expect-size", "1920x1080", "--proof-contract",
                            str(PROBE.with_name("proof.json"))])
            script_args.append(f"--capture={capture}")
        else:
            command.extend(["--min-images", "0"])
    else:
        command = [sys.executable, str(TOOLS / "godot_task_runner.py"), "--task-id", TASK, "--stream",
                   "--", "godot", "--headless", "--fixed-fps", "60",
                   "--path", str(project), "--script", str(script)]
    run([*policy, *command, "--", *script_args], output / "runner.log", environment)


def read(directory):
    result = json.loads((directory / "pass-rounds.json").read_text())
    if set(result) != {"normal", "normal-accept", "tharokh"}:
        raise ValueError(f"Incomplete route roster in {directory}")
    return result


def ready(route):
    frames = [frame for frame in route["frames"] if READY in frame["spans"]]
    if len(frames) != 1:
        raise ValueError(f"Expected one handoff interval, got {len(frames)}")
    return frames[0]


def percentiles(values):
    ordered = sorted(values)
    offset = .95 * (len(ordered) - 1)
    lower = int(offset)
    p95 = ordered[lower] + (offset - lower) * (ordered[min(lower + 1, len(ordered) - 1)] - ordered[lower])
    return {"median": median(ordered), "p95": p95, "min": ordered[0], "max": ordered[-1]}


def samples(projects, output, options):
    profiles = ("background",) if options.mode == "detail" else PROFILES
    pairs = ("AB",) if options.mode == "detail" else PAIR_ORDER[:options.pair_count]
    results = {}
    with ExitStack() as cleanup:
        for _ in range(options.load_workers):
            worker = subprocess.Popen(["yes"], stdout=subprocess.DEVNULL)
            cleanup.callback(worker.wait)
            cleanup.callback(worker.terminate)
        for profile in profiles:
            for number, order in enumerate(pairs, 1):
                for side in order:
                    directory = output / profile / f"{side}{number}"
                    take(projects[side], PROBE, directory, options.fixtures,
                         native=options.native, profile=profile, detail=options.mode == "detail",
                         args=("--load=1",))
                    results[profile, side, number] = read(directory)
    checks = {}
    for profile in profiles:
        first = results[profile, "A", 1]
        compared = [take for (qos, _, _), take in results.items() if qos == profile]
        equal = all(row[kind]["receipt"] == first[kind]["receipt"]
                    for row in compared for kind in first)
        checks[f"{profile}_receipts"] = equal
        print(f"PERF-160 {profile} RECEIPTS: {'PASS' if equal else 'FAIL'} "
              f"({len(first)} routes, {len(pairs)} paired takes)")
        if options.mode == "detail":
            for side in "AB":
                for kind, route in results[profile, side, 1].items():
                    checkpoint = max(f["spans"].get(CHECKPOINT, 0) for f in route["frames"])
                    frame = ready(route)
                    print(f"{side} {kind}: ready {frame['usec']} µs, callback {frame['spans'][READY]} µs, "
                          f"separate checkpoint {checkpoint} µs")
                    for section, cost in sorted(route["ready_phases_usec"].items(), key=lambda item: -item[1]):
                        if section.startswith(("refresh_ui_", "stage_", "board/", "board_layer/", "enemy_round_")):
                            print(f"  {section} {cost} µs")
                    for section in ("enemy_round_initial_snapshots", "enemy_round_initial_checkpoint_state_total",
                                    "enemy_round_initial_checkpoint_persist_total", "enemy_round_final_checkpoint_total",
                                    "enemy_round_final_commit_and_sync_total", "enemy_round_analytics_write",
                                    "enemy_round_transition_analytics_total"):
                        if section in route["phases"]:
                            print(f"  separate {section} {route['phases'][section]['total_usec']} µs")
            continue
        summaries = {}
        for side in "AB":
            arm = [results[profile, side, number] for number in range(1, len(pairs) + 1)]
            handoffs = [ready(route) for take_result in arm for route in take_result.values()]
            summaries[side] = {
                "ready_usec": percentiles([f["usec"] for f in handoffs]),
                "callback_usec": percentiles([f["spans"][READY] for f in handoffs]),
                "over_33_by_route": {
                    kind: sum(f["usec"] > THRESHOLD_USEC for take_result in arm
                              for f in take_result[kind]["frames"])
                    for kind in first
                },
                "pair_ready_max_usec": [max(ready(route)["usec"] for route in take_result.values())
                                        for take_result in arm],
            }
            print(f"PERF-160 {profile} {side} {json.dumps(summaries[side])}", flush=True)
        a, b = summaries.values()
        if profile == "background":
            for metric in ("max", "p95"):
                checks[f"background_handoff_{metric}"] = b["ready_usec"][metric] <= SLOW_FRACTION * a["ready_usec"][metric]
        else:
            for kind in first:
                checks[f"normal_33ms_{kind}"] = b["over_33_by_route"][kind] <= a["over_33_by_route"][kind]
        (output / profile / "summary.json").write_text(json.dumps(summaries, indent=2) + "\n")
    for name, passed in checks.items():
        print(f"PERF-160 {name}: {'PASS' if passed else 'FAIL'}")
    label = "native acceptance" if options.native else "headless diagnostic"
    if options.mode == "detail":
        label = "attribution receipts"
    print(f"PERF-160 {label}: {'PASS' if all(checks.values()) else 'FAIL'}")
    return all(checks.values())


def identity(projects, output, fixtures):
    for side, project in projects.items():
        take(project, TOOLS / "perf140/probe.gd", output / f"{side}1", fixtures)
    a, b = (json.loads((output / f"{side}1" / "forecast-receipts.json").read_text()) for side in "AB")
    differences = sorted(key for key in a.keys() | b.keys() if a.get(key) != b.get(key))
    forecasts = sum("steps" in row for row in a.values())
    print(f"PERF-140 IDENTITY: {'FAIL' if differences else 'PASS'} "
          f"({forecasts} forecasts, {len(a) - forecasts} badge receipts; {len(differences)} differences)")
    for key in differences:
        print(key)
    return not differences


def strict_states(projects, output, options):
    driver = strict.route.load_fixture_tools()
    # Both arms use the current release board settings. Comparing the older
    # perf148 switch would mix different board implementations into the proof.
    environments = dict.fromkeys("AB", {"LABYRINTH_CEL_LOOK": "all", "SteamDeck": "0"})
    if options.native:
        return strict.native_receipts(driver, projects, output, options.fixtures, environments, TASK) == 0
    driver.headless_receipts(projects, output, options.fixtures, TASK, environments)
    print(f"PERF-160 STRICT RECEIPTS: PASS ({len(driver.CAPTURES)} states)")
    return True


def captures(projects, output, fixtures):
    for side, project in projects.items():
        for kind in ("normal", "tharokh"):
            with TemporaryDirectory(dir=output) as temporary:
                take(project, PROBE, output / f"{side}-{kind}", fixtures, native=True,
                     capture=kind, environment={**ENV, "PERF134_CAPTURE_MOVIE": str(Path(temporary) / "clock.avi")})
    identical = True
    driver = strict.route.load_fixture_tools()
    for kind in ("normal", "tharokh"):
        directories = [output / f"{side}-{kind}" for side in "AB"]
        witnesses = [json.loads((directory / f"{kind}-pass-ready.json").read_text()) for directory in directories]
        if witnesses[0] != witnesses[1]:
            raise ValueError(f"{kind}: different capture witnesses")
        for stem in (f"{kind}-pass-ready", "first-ready"):
            images = [directory / (stem + ".png") for directory in directories]
            differences = driver.pixel_difference(*images)["different_pixels"]
            print(f"PERF-160 {kind} {stem}: {'PASS' if not differences else 'FAIL'} ({differences} differing pixels)")
            identical &= differences == 0
    return identical


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("pairs", "detail", "identity", "strict", "repros", "captures", "auto"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fixtures", type=Path, required=True)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--load-workers", type=int, default=LOAD_WORKERS)
    parser.add_argument("--pair-count", type=int, choices=range(1, len(PAIR_ORDER) + 1), default=len(PAIR_ORDER),
                        help="Use fewer pairs for a headless diagnostic.")
    options = parser.parse_args()
    options.fixtures = options.fixtures.resolve(strict=True)
    if options.load_workers < 0:
        parser.error("--load-workers must be nonnegative")
    if options.native and options.mode == "pairs" and options.pair_count != len(PAIR_ORDER):
        parser.error("native acceptance requires five pairs")
    if options.mode == "captures" and not options.native:
        parser.error("captures requires --native")
    output = options.output.resolve()
    output.mkdir(parents=True)
    (output / "environment.json").write_text(json.dumps({
        "base": BASE, "candidate_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "platform": platform.platform(), "native": options.native,
        "candidate_runtime_sha256": {
            name: hashlib.sha256((ROOT / "scripts" / name).read_bytes()).hexdigest()
            for name in sorted(CHANGED)
        },
        "fixture_sha256": hashlib.sha256(options.fixtures.read_bytes()).hexdigest(),
        "load_workers": options.load_workers, "pair_order": PAIR_ORDER[:options.pair_count] if options.mode == "pairs" else ["AB"],
    }, indent=2) + "\n")
    projects = {"A": base_project(output / "base-project"), "B": ROOT}
    if options.mode in ("pairs", "detail"):
        return samples(projects, output, options)
    if options.mode == "identity":
        return identity(projects, output, options.fixtures)
    if options.mode == "strict":
        return strict_states(projects, output, options)
    if options.mode == "captures":
        return captures(projects, output, options.fixtures)
    if options.mode == "auto":
        receipts = []
        for side, project in projects.items():
            directory = output / side
            take(project, TOOLS / "perf160/auto_pass.gd", directory, options.fixtures, native=options.native)
            receipts.append(json.loads((directory / "auto-pass.json").read_text()))
        identical = receipts[0] == receipts[1]
        print(f"PERF-160 AUTO PASS RECEIPTS: {'PASS' if identical else 'FAIL'}")
        return identical
    for case in REPROS:
        take(ROOT, TOOLS / "perf149/repros.gd", output / case, options.fixtures, args=(f"--case={case}",))
    return True


if __name__ == "__main__":
    raise SystemExit(0 if main() else 1)

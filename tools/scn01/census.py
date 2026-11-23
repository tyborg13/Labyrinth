#!/usr/bin/env python3
"""Capture the current Labyrinth screens from isolated inspection saves."""

from __future__ import annotations

import argparse
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from itertools import count
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT = SCRIPT_DIR.parent.parent
TASK = os.environ.get("SCN01_TASK_ID", "pol-68")
OUT_ROOT = Path("/private/tmp/labyrinth_codex") / TASK
CONTACT_SHEET = Path.home() / ".claude/skills/orchestrate-codex/scripts/contact_sheet.py"
SIZES = ("1920x1080", "1280x800")
NATIVE_BUDGET_SECONDS = 29 * 60
ENGINE_TIMEOUT = int(os.environ.get("SCN01_ENGINE_TIMEOUT", "60"))
DRY_RUN_JOBS = 3
SHEET_SHOTS = 12
SHEET_COLUMNS = 4
SCRIPT_ERRORS = ("SCRIPT ERROR:", "Parse Error:", "ERROR: Failed to load script")
FIXTURE_ERROR = "INSPECTION FIXTURE ERROR: "


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def capture_log(
    command: list[str], env: dict[str, str], log: Path, deadline: float | None = None,
    cwd: Path = PROJECT,
) -> tuple[int, str]:
    remaining = None if deadline is None else deadline - time.monotonic()
    if remaining is not None and remaining <= 0:
        raise ValueError("Native census exceeded its shared 29-minute run budget")
    with log.open("w", encoding="utf-8") as output:
        try:
            result = subprocess.run(
                command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=remaining,
            )
        except subprocess.TimeoutExpired as error:
            raise ValueError(f"Native census exceeded its shared run budget; see {log}") from error
    return result.returncode, log.read_text(encoding="utf-8", errors="replace")


def payload_line(output: str, marker: str) -> dict:
    for line in reversed(output.splitlines()):
        if line.startswith(marker + " "):
            return json.loads(line.removeprefix(marker + " "))
    return {}


def shot_plan(path: Path = SCRIPT_DIR / "shots.json") -> list[dict]:
    plan = json.loads(path.read_text(encoding="utf-8"))
    shots = plan["shots"]
    names = set()
    retired = set(plan.get("retired_shot_numbers", []))
    numbers = (number for number in count(1) if number not in retired)
    for index, shot in zip(numbers, shots):
        name = shot["shot"]
        if not re.fullmatch(r"[a-z0-9]+(?:_[a-z0-9]+)*", name) or name in names:
            raise ValueError(f"Invalid or duplicate shot name {name!r}")
        names.add(name)
        seed = shot.get("seed", plan["default_seed"])
        shared = plan["fixture_sets"][shot["fixture"]] if "fixture" in shot else []
        overrides = [*shared, *shot.get("flags", [])]
        if "--seed" in overrides or "--scenario" in overrides or "--allow-live-user-dir" in overrides:
            raise ValueError(f"{name}: use the shot's seed and scenario fields")
        shot.update(
            image=f"{index:02d}_{name}.png",
            seed=seed,
            flags=["--scenario", shot["scenario"], "--seed", str(seed), *overrides],
        )
    return shots


def prepare_shot(shot: dict, args: argparse.Namespace, out: Path, run_id: str) -> tuple[dict, list[str]]:
    name = shot["shot"]
    png = out / shot["image"]
    logs = out / "logs"
    stem = png.stem
    fixture_log = logs / f"{stem}_fixture.log"
    probe_log = logs / f"{stem}_probe.log"
    row = {
        "shot": name,
        "scenario": shot["scenario"],
        "state": shot.get("state", "default"),
        "flags": shot["flags"],
        "seed": shot["seed"],
        "size": args.size,
        "ui_scale": float(args.ui_scale),
        "cel_look": "all",
        "settle_frames": None,
        "capped": None,
        "script_errors": [],
        "layout_hits": [],
        "planned_png": str(png),
        "capture": None,
        "fixture_log": str(fixture_log),
        "probe_log": None,
        "ok": False,
        "error": "",
    }
    task_runner = [
        sys.executable, "tools/godot_task_runner.py", "--task-id", TASK, "--stream",
        "--timeout", str(ENGINE_TIMEOUT),
    ]
    fixture_command = [
        *task_runner, "--run-id", f"{run_id}-{stem}", "--", "godot", "--headless",
        "--path", str(args.project), "--script", "tools/inspection_fixture.gd", "--", *shot["flags"],
    ]
    print(f"{name}: planned {png}", flush=True)
    try:
        status, output = capture_log(fixture_command, dict(os.environ, LABYRINTH_CEL_LOOK="off"), fixture_log, args.deadline)
        row["script_errors"].extend(line for line in output.splitlines() if any(error in line for error in SCRIPT_ERRORS))
        fixture = payload_line(output, "INSPECTION_FIXTURE_RESULT")
        if status or not fixture.get("ok") or row["script_errors"]:
            reason = next(
                (line.removeprefix(FIXTURE_ERROR) for line in output.splitlines()
                 if line.startswith(FIXTURE_ERROR)),
                f"see {fixture_log}",
            )
            raise ValueError(f"inspection fixture exit {status}; {reason}")

        probe_args = [
            "--save", fixture["save_path"], "--profile", fixture["progression_path"],
            "--settings", str(Path(fixture["progression_path"]).with_name("settings.json")),
            "--mode", fixture["mode"], "--size", args.size, "--png", str(png),
            "--shot", json.dumps(shot, separators=(",", ":")),
            "--ui-scale", args.ui_scale,
        ]
        if args.root_window:
            probe_args.append("--root-window")
        if args.rects:
            probe_args.append("--rects")
        row["probe_log"] = str(probe_log)
        return row, probe_args
    except (OSError, ValueError, KeyError) as error:
        row["error"] = str(error)
        return row, []


def finish_shot(row: dict, status: int, output: str, validated: set[Path] | None = None) -> None:
    row["script_errors"].extend(line for line in output.splitlines() if any(error in line for error in SCRIPT_ERRORS))
    result = payload_line(output, "CENSUS_RESULT")
    for field in ("settle_frames", "observed_frames", "capped", "settle_basis", "run_seed", "mode", "stage_state", "layout_hits", "geometry", "control_rects", "dialogue_paint_rects"):
        if field in result:
            row[field] = result[field]
    if status or not result.get("ok") or row["script_errors"] or "layout_hits" not in result:
        reason = result.get("error") or f'see {row["probe_log"]}'
        row["error"] = f"probe exit {status}; {reason}"
        return
    if validated is not None:
        png = Path(row["planned_png"])
        if png not in validated:
            row["error"] = "Visual runner did not validate the planned PNG."
            return
        row["capture"] = str(png)
    row["ok"] = True


def print_status(row: dict) -> dict:
    if row["ok"]:
        status = "CAPPED" if row["capped"] else "SETTLED"
        detail = f'{row["settle_frames"]} equal frames'
    else:
        status = "FAILED"
        detail = row["error"]
    print(f'{row["shot"]}: {status} ({detail})', flush=True)
    return row


def engine_project_flags(project: Path) -> list[str]:
    return ["--path", str(project), "--script", str(SCRIPT_DIR / "census.gd")]


def run_shot(shot: dict, args: argparse.Namespace, out: Path, run_id: str) -> dict:
    row, probe_args = prepare_shot(shot, args, out, run_id)
    if probe_args:
        project_flags = engine_project_flags(args.project)
        command = [
            sys.executable, "tools/godot_task_runner.py", "--task-id", TASK, "--stream",
            "--timeout", str(ENGINE_TIMEOUT), "--", "godot", "--headless", *project_flags,
            "--", *probe_args, "--dry-run",
        ]
        try:
            status, output = capture_log(command, dict(os.environ, LABYRINTH_CEL_LOOK="all"), Path(row["probe_log"]))
            finish_shot(row, status, output)
        except (OSError, ValueError) as error:
            row["error"] = str(error)
    return print_status(row)


def native_shots(shots: list[dict], args: argparse.Namespace, out: Path, run_id: str) -> Iterator[dict]:
    from native_batch import validate_batch

    with ThreadPoolExecutor(max_workers=DRY_RUN_JOBS) as pool:
        prepared = list(pool.map(lambda shot: prepare_shot(shot, args, out, run_id), shots))
    active = [(row, probe_args) for row, probe_args in prepared if probe_args]
    if active:
        try:
            validated, statuses, proof = validate_batch(active, args.size, out, args.deadline, args.project)
        except (OSError, ValueError, KeyError) as error:
            for row, _ in active:
                row["error"] = str(error)
        else:
            for row, _ in active:
                row["proof"] = str(proof)
                status = statuses.get(row["shot"])
                if status is None:
                    row["error"] = f'Native batch did not run this shot. See {out / "logs" / "visual_batch.log"}'
                    continue
                try:
                    output = Path(row["probe_log"]).read_text(encoding="utf-8", errors="replace")
                    finish_shot(row, status, output, validated)
                except (OSError, ValueError) as error:
                    row["error"] = str(error)
    for row, _ in prepared:
        yield print_status(row)


def contact_sheets(out: Path, captures: list[str], deadline: float | None) -> tuple[list[str], list[str]]:
    sheets, errors = [], []
    for index in range(0, len(captures), SHEET_SHOTS):
        path = out / f"contact_sheet_{1 + index // SHEET_SHOTS:02d}.png"
        command = [
            sys.executable, str(CONTACT_SHEET), "--out", str(path),
            "--cols", str(SHEET_COLUMNS), "--labels", "filename",
            *captures[index:index + SHEET_SHOTS],
        ]
        log = out / "logs" / f"{path.stem}.log"
        try:
            status, _ = capture_log(command, os.environ.copy(), log, deadline)
        except ValueError as error:
            errors.append(str(error))
            break
        if status or not path.is_file():
            errors.append(f"Contact sheet failed; see {log}")
        else:
            sheets.append(str(path))
    return sheets, errors


def collect_shots(shots: list[dict], args: argparse.Namespace, out: Path, run_id: str) -> Iterator[dict]:
    if args.dry_run:
        with ThreadPoolExecutor(max_workers=DRY_RUN_JOBS) as pool:
            yield from pool.map(lambda shot: run_shot(shot, args, out, run_id), shots)
    else:
        yield from native_shots(shots, args, out, run_id)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        epilog="Blacksmith and Arcanist are legacy rooms. New runs generate the Scavenger instead.",
    )
    parser.add_argument("--size", choices=SIZES, default=SIZES[0])
    parser.add_argument("--ui-scale", choices=("1.0", "1.15"), default="1.0")
    parser.add_argument("--root-window", action="store_true", help="Capture the shipping root Window at either size.")
    parser.add_argument("--rects", action="store_true", help="Record the control rectangles in output pixels.")
    parser.add_argument("--project", type=Path, default=PROJECT, help="Use another prepared checkout as the game project.")
    parser.add_argument("--no-contact-sheet", action="store_true", help="Keep the individual native PNGs only.")
    parser.add_argument("--only", help="Comma-separated shot names from shots.json.")
    parser.add_argument("--plan", type=Path, default=SCRIPT_DIR / "shots.json", help="Shot plan JSON.")
    parser.add_argument("--out", type=Path, help="Fresh output directory.")
    parser.add_argument("--dry-run", action="store_true", help="Run the real screens headless without PNGs.")
    parser.add_argument("--both", action="store_true", help="Run both sizes in sequential subfolders.")
    parser.add_argument("--report-from", nargs="+", type=Path, metavar="MANIFEST", help="Write layout reports from existing manifests.")
    parser.add_argument("--report-dir", type=Path, help="Override the layout report output directory.")
    args = parser.parse_args()
    sys.path.insert(0, str(PROJECT / "tools" / "pol67"))
    from layout_report import REPORT_DIR, write_reports

    if args.report_from:
        try:
            write_reports(args.report_from, args.report_dir or REPORT_DIR)
        except (OSError, ValueError, KeyError, TypeError) as error:
            parser.error(str(error))
        return 0

    try:
        shots = shot_plan(args.plan)
        if args.only is not None:
            selected = {name.strip() for name in args.only.split(",")}
            unknown = selected - {entry["shot"] for entry in shots}
            if unknown:
                raise ValueError(f"Unknown shot(s): {', '.join(sorted(unknown))}")
            shots = [entry for entry in shots if entry["shot"] in selected]
        if not shots:
            raise ValueError("No shots selected")
        args.project = args.project.resolve(strict=True)
        if not (args.project / "project.godot").is_file():
            raise ValueError(f"No project.godot in {args.project}")
        if not args.dry_run and not args.no_contact_sheet and not CONTACT_SHEET.is_file():
            raise ValueError(f"Contact sheet tool not found at {CONTACT_SHEET}")
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        output_root = (args.out or OUT_ROOT / stamp).expanduser().resolve()
        sizes = SIZES if args.both else (args.size,)
        outputs = [output_root / size for size in sizes] if args.both else [output_root]
        for out in outputs:
            out.mkdir(parents=True, exist_ok=True)
            (out / "logs").mkdir()
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.error(str(error))

    args.deadline = None if args.dry_run else time.monotonic() + NATIVE_BUDGET_SECONDS
    statuses = []
    for size, out in zip(sizes, outputs):
        args.size = size
        statuses.append(run_size(shots, args, out, stamp))
    for size, out in zip(sizes, outputs):
        print(f"Output {size}: {out}")
    if args.both and not args.dry_run:
        write_reports([out / "manifest.json" for out in outputs], args.report_dir or output_root)
    return int(any(statuses))


def run_size(shots: list[dict], args: argparse.Namespace, out: Path, stamp: str) -> int:
    started = time.monotonic()
    manifest = {"size": args.size, "ui_scale": float(args.ui_scale), "dry_run": args.dry_run, "shots": [], "contact_sheets": []}
    manifest_path = out / "manifest.json"
    log = out / "logs" / "cel_look.log"
    # Same rendering cache bootstrap as inspection_fixture.py --launch.
    cel_action = ["status"] if args.dry_run or args.project != PROJECT else ["build", "--if-stale"]
    try:
        status, _ = capture_log(
            [sys.executable, "tools/cel_look.py", *cel_action], os.environ.copy(), log, args.deadline, cwd=args.project,
        )
        if status:
            manifest["error"] = f"Cel look preparation failed; see {log}"
    except ValueError as error:
        manifest["error"] = str(error)
    if manifest.get("error"):
        manifest["elapsed_seconds"] = round(time.monotonic() - started, 3)
        write_json(manifest_path, manifest)
        print(manifest["error"], file=sys.stderr)
        return 1
    run_id = f"{TASK}-{stamp.lower()}-{os.getpid()}-{args.size}"
    for row in collect_shots(shots, args, out, run_id):
        manifest["shots"].append(row)
        write_json(manifest_path, manifest)
    captures = [row["capture"] for row in manifest["shots"] if row["capture"]]
    sheets, sheet_errors = ([], []) if args.no_contact_sheet else contact_sheets(out, captures, args.deadline)
    elapsed = round(time.monotonic() - started, 3)
    manifest.update(contact_sheets=sheets, contact_sheet_errors=sheet_errors, elapsed_seconds=elapsed)
    write_json(manifest_path, manifest)
    failed = [row for row in manifest["shots"] if not row["ok"]]
    for row in failed:
        print(f"FAIL {row['shot']}: {row['error']}")
    for error in sheet_errors:
        print(error, file=sys.stderr)
    capped = [row["shot"] for row in manifest["shots"] if row["capped"]]
    if capped:
        print(f"Settle cap reached: {', '.join(capped)}")
    passed = len(shots) - len(failed)
    verdict = "FAIL" if failed else "PASS"
    print(f"CENSUS RESULT: {verdict}; {passed}/{len(shots)} shots succeeded; {len(capped)} capped")
    print(f"Elapsed {args.size}: {elapsed:.3f} s")
    print(f"Manifest: {manifest_path}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

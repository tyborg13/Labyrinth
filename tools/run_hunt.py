#!/usr/bin/env python3
"""Bounded, headless RunScene hunt and evidence report (stdlib only).

Never imports/edits gameplay, installs fixtures, or launches windowed Godot.
Each seed gets fresh settings, progression, saves, analytics, and runner HOME.
"""
from __future__ import annotations

import argparse
from collections import Counter, deque
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
import json
import hashlib
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = PROJECT / "spec/peer_benchmark/qa/run_hunt_2026-11/campaign"
MAX_PROCESSES = 3
MAX_MINUTES = 75.0
SEED_TIMEOUT_SECONDS = 4500.0
POLL_SECONDS = 1.0
EVENT_PREFIX = "RUN_HUNT_EVENT "
SEVERITY_ORDER = {name: index for index, name in enumerate(("crash", "softlock", "script error", "warning", "leak"))}
REQUIRED_KINDS = ("start", "combat", "guardian", "boss", "dragon", "warband", "snare", "hoarder", "last_light", "campfire", "treasure", "event", "scavenger", "blacksmith", "arcanist", "graftwright")
ROOM_ALIASES = {"boss": "dragon", "umbral_snare": "snare", "ember_hoarder": "hoarder"}
ERROR_MARKER = re.compile(r"SCRIPT ERROR:|(?:^|\s)(?:USER )?ERROR:|(?:^|\s)WARNING:|(?i:(?:failed|failure).*assert|assert.*(?:failed|failure))|push_error|push_warning")
LOCATION = re.compile(r"(?:res://|[A-Za-z]:[/\\]|/|platform/|core/|scene/|servers/|modules/)[^\s()]+:\d+")


def write_json(path: Path, data: object) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def command_for(seed: int, directory: Path, args: argparse.Namespace) -> list[str]:
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "qa-85" if getattr(args, "demo", False) else "qa-18", "--timeout", str(args.seed_timeout), "--stream", "--", "godot", "--headless", "--path", ".", "--script", args.script, "--", "--seed", str(seed), "--output-dir", str(directory)]
    if args.no_embrace:
        command.extend(("--no-embrace", "true"))
    if args.stop_after:
        command.extend(("--stop-after", str(args.stop_after)))
    if getattr(args, "demo", False): command.extend(("--demo", "true"))
    if getattr(args, "health", 9999) != 9999: command.extend(("--health", str(args.health)))
    if getattr(args, "profile_runs", 2) != 2: command.extend(("--profile-runs", str(args.profile_runs)))
    if getattr(args, "defeat_after_hearth", False): command.extend(("--defeat-after-hearth", "true"))
    return command


def read_evidence(seed: int, directory: Path, returncode: int) -> dict:
    """Associate every log marker with the immediately preceding decision.

    Preserve each occurrence; group only in the report. Engine stack locations
    prefer a res:// caller over the generic push_error C++ implementation.
    """
    context = {"seed": seed, "section": -1, "room_kind": "startup", "decision": 0}
    history: deque = deque(maxlen=20)
    findings: list[dict] = []
    rooms: list[dict] = []
    finish = None
    pending = None

    def flush() -> None:
        nonlocal pending
        if pending is None:
            return
        locations = LOCATION.findall("\n".join(pending["log_lines"]))
        pending["location"] = next((item for item in locations if ".gd:" in item), locations[0] if locations else "unavailable in Godot log")
        findings.append(pending)
        pending = None

    raw_log = (directory / "godot.log").read_text(errors="replace")
    for line_number, line in enumerate(raw_log.splitlines(), 1):
        if line.startswith(EVENT_PREFIX):
            flush()
            try:
                event = json.loads(line[len(EVENT_PREFIX):])
            except json.JSONDecodeError:
                # A killed engine can leave its final trace line incomplete.
                # Keep the raw fragment and the last intact decision context.
                event = {"event": "truncated", "data": {}}
            data = event["data"]
            if event["event"] == "decision":
                context = data["context"]
                history.append(data)
            elif event["event"] == "room":
                context = data
                rooms.append(data)
            elif event["event"] == "finding":
                findings.append({**data, "log_line": line_number})
            elif event["event"] == "finish":
                finish = data
                context = data["context"]
            if event["event"] != "truncated": continue
        if ERROR_MARKER.search(line) and not re.match(r"\s+(?:at:|\[\d+\])", line):
            flush()
            pending = {"severity": "warning" if "WARNING:" in line or "push_warning" in line else "script error", "error": line.strip(), "context": dict(context), "last_20_decisions": list(history), "log_line": line_number, "log_lines": [line]}
        elif pending is not None and (line.startswith(" ") or not line.strip()):
            pending["log_lines"].append(line)
        else:
            flush()
    flush()
    if returncode:
        reason = " (seed watchdog timeout)" if returncode == 124 else " (native Godot exit 0; runner detected script errors)" if "Godot reported script or test failures despite exit code 0." in raw_log else ""
        findings.append({"severity": "crash", "error": f"Godot runner exited {returncode}" + reason, "location": "process exit", "context": context, "last_20_decisions": list(history)})
    elif finish is None:
        findings.append({"severity": "crash", "error": "Process exited without RUN_HUNT finish evidence", "location": "process exit", "context": context, "last_20_decisions": list(history)})
    command = json.loads((directory / "command.json").read_text())["argv"]
    replay_script = command[command.index("--script") + 1]
    for finding in findings: finding["replay_script"] = replay_script
    return {"seed": seed, "returncode": returncode, "finish": finish, "rooms": rooms, "findings": findings, "log": str(directory / "godot.log")}


def run_seed(seed: int, output: Path, args: argparse.Namespace) -> dict:
    directory = output / f"seed-{seed:06d}"
    directory.mkdir()
    command = command_for(seed, directory, args)
    environment = {"LABYRINTH_CEL_LOOK": "off"}
    if getattr(args, "demo", False): environment["LABYRINTH_DEMO"] = "1"
    write_json(directory / "command.json", {"cwd": str(PROJECT), "env": environment, "argv": command})
    started = time.monotonic()
    with (directory / "godot.log").open("w") as log:
        result = subprocess.run(command, cwd=PROJECT, env={**os.environ, **environment}, stdout=log, stderr=subprocess.STDOUT, check=False)
    evidence = read_evidence(seed, directory, result.returncode)
    evidence["wall_seconds"] = time.monotonic() - started
    write_json(directory / "evidence.json", evidence)
    finish = evidence.get("finish") or {}
    print(f"RUN HUNT SEED {seed}: outcome={finish.get('outcome', 'process_failure')} decisions={finish.get('decisions', '?')} findings={len(evidence['findings'])}", flush=True)
    return evidence


def deduplicate(runs: list[dict]) -> list[dict]:
    groups = {}
    for run in sorted(runs, key=lambda item: item["seed"]):
        for finding in run["findings"]:
            key = (finding["error"], finding["location"])
            if key not in groups:
                groups[key] = {**finding, "count": 0, "seeds": [], "occurrences": []}
            group = groups[key]
            group["count"] += 1
            if run["seed"] not in group["seeds"]:
                group["seeds"].append(run["seed"])
            group["occurrences"].append({"seed": run["seed"], "context": finding["context"], "log": run["log"], "log_line": finding.get("log_line")})
    return sorted(groups.values(), key=lambda item: (SEVERITY_ORDER[item["severity"]], -item["count"], item["error"]))


def replay_command(group: dict, args: argparse.Namespace) -> str:
    seed = group["context"]["seed"]
    point = int(group["context"].get("decision", 0)) + 1
    command = ["python3", "tools/run_hunt.py", "--seed", str(seed), "--runs", "1", "--processes", "1", "--stop-after", str(point), "--output-dir", f"/private/tmp/labyrinth_codex/qa-18/replay-{seed}-{point}-{time.time_ns()}"]
    if args.no_embrace: command.append("--no-embrace")
    if getattr(args, "demo", False): command.append("--demo")
    if getattr(args, "health", 9999) != 9999: command.extend(("--health", str(args.health)))
    if getattr(args, "demo", False):
        command[command.index("--output-dir") + 1] = command[command.index("--output-dir") + 1].replace("/qa-18/", "/qa-85/")
    if getattr(args, "profile_runs", 2) != 2: command.extend(("--profile-runs", str(args.profile_runs)))
    if getattr(args, "defeat_after_hearth", False): command.append("--defeat-after-hearth")
    script = group.get("replay_script", args.script)
    if script != "tools/run_hunt.gd": command.extend(("--script", script))
    return f"cd {shlex.quote(str(PROJECT))} && LABYRINTH_CEL_LOOK=off {shlex.join(command)}"


def render_report(runs: list[dict], args: argparse.Namespace, elapsed: float, started: int, extra_runs: list[dict] | None = None) -> tuple[str, list[dict]]:
    groups = deduplicate(runs + (extra_runs or []))
    visits: Counter = Counter()
    sections: Counter = Counter()
    outcomes: Counter = Counter()
    for run in runs:
        seen = set()
        for room in run["rooms"]:
            visits[room["room_kind"]] += 1
            if room["room_kind"] in ROOM_ALIASES: visits[ROOM_ALIASES[room["room_kind"]]] += 1
            seen.add(room["section"])
        sections.update(seen)
        outcomes[(run.get("finish") or {}).get("outcome", "process_failure")] += 1
    completed = sum(outcomes.get(key, 0) for key in ("victory", "defeat", "embrace"))
    text = ["# Run hunt — November 2026", "", f"Runs started: {started}; processes ended: {len(runs)}; completed runs: {completed} (victory {outcomes['victory']}, defeat {outcomes['defeat']}, Embrace {outcomes['embrace']}).", f"Wall clock: {elapsed / 60:.2f} minutes. Seed base {args.seed}; at most {args.processes} concurrent Godot processes; stop launching after {args.minutes:g} minutes. Source art; headless; fastest combat; scene time ×8; starting Health 9,999.", "", "## Findings", "", "| Severity | Count | First seed | Section / room kind | Error and source |", "|---|---:|---:|---|---|"]
    text.insert(4, f"No Embrace / terminal choices: {args.no_embrace}. Browse screens leave after 8 decisions; fight budget 400 decisions; unchanged fight state is reported after 50 consecutive decisions.")
    if extra_runs:
        text[4:4] = ["", f"Findings also include {len(extra_runs)} separately verified replay(s); these do not inflate the campaign run totals or coverage below. Their exact private driver paths are preserved in replay commands."]
    for group in groups:
        ctx = group["context"]
        description = (group["error"] + " — " + group["location"]).replace("|", "\\|")
        text.append(f"| {group['severity']} | {group['count']} | {ctx['seed']} | {ctx.get('section', -1)} / {ctx.get('room_kind', 'startup')} | {description} |")
    if not groups:
        text.append("| — | 0 | — | — | No findings observed |")
    for index, group in enumerate(groups, 1):
        text.extend(("", f"### {index}. {group['severity']}: {group['error']}", "", f"Source: `{group['location']}`. Seeds: {', '.join(map(str, group['seeds']))}.", "", "Replay from a fresh profile to this decision (the full context and trace are retained in findings.json):", "", f"```sh\n{replay_command(group, args)}\n```", "", "Last 20 decisions:", "", "| Decision | Kind | Input |", "|---:|---|---|"))
        for action in group.get("last_20_decisions", []):
            detail = str(action.get("text") or action.get("card_id") or action.get("args") or action.get("tile") or action.get("method") or str(action.get("path", "")).rsplit("/", 1)[-1])
            text.append(f"| {action['decision']} | {action['kind']} | {detail.replace('|', chr(92) + '|')} |")
        if not group.get("last_20_decisions"): text.append("| — | startup | No decisions preceded this marker |")
    text.extend(("", "## Coverage", "", "| Section (zero based) | Runs reaching section |", "|---|---:|"))
    for section in range(6): text.append(f"| {section} | {sections[section]} |")
    text.extend(("", "| Room kind | Entries |", "|---|---:|"))
    for kind in sorted(set(REQUIRED_KINDS) | set(visits)):
        text.append(f"| {kind} | {visits[kind]}{' — NEVER VISITED' if not visits[kind] else ''} |")
    text.extend(("", "Aliases retain both the brief's label and the generator's key: dragon = `boss`, Snare = `umbral_snare`, Hoarder = `ember_hoarder`. These paired rows describe the same entries. Blacksmith and arcanist are legacy shop kinds: current new-run generation uses Scavenger (`scripts/run_engine.gd:59–65`). No fixtures were substituted to manufacture coverage.", "", "Node and orphan censuses are retained at every room entry in each seed's summary and trace. The leak detector compares the first section 0 entry with the first section 5 entry; a zero orphan baseline flags any increase. Runs that do not reach section 5 provide no section-5 leak proof.", "", "Every raw marker is retained, including startup/platform errors and shutdown warnings. A nonzero runner status is reported separately; it can mean the runner detected a script error despite a native exit of zero. Per-seed command.json and godot.log retain that distinction.", ""))
    if getattr(args, "health", 9999) != 9999:
        text = [line.replace("starting Health 9,999", "starting Health " + ("normal" if args.health == 0 else f"{args.health:,}")) for line in text]
    if getattr(args, "demo", False):
        text[0] += " — demo mode"
        text = [line.replace("starting Health 9,999", "starting Health " + ("normal" if args.health == 0 else f"{args.health:,}")) for line in text]
        text = [line.replace("No fixtures were substituted to manufacture coverage.", "No synthetic run fixtures were substituted. Terminal reload checks durable profile/Chronicle receipts, cleared resumable state and a fresh Section I run; later endings exercise Rise Again.") for line in text]
        text.extend(("", "## Demo runs (Section is zero based)", "", "| Seed / profile run | Outcome | Section reached | Rooms | Hearth | Panel shown / expected | Resume checks | Rise Again Section |", "|---|---|---:|---:|---|---|---|---|"))
        for run in runs:
            finish = run.get("finish") or {}
            rows = finish.get("demo_runs", [])
            if not rows:
                text.append(f"| {run['seed']} | {finish.get('outcome', 'process_failure')} | — | {len(run['rooms'])} | — | not reached | not reached | — |")
            for index, row in enumerate(rows, 1):
                text.append(f"| {run['seed']} / {index} | {row['outcome']} | {row['section']} | {row['rooms']} | {row['hearth']} | {row['shown']} / {row['expected']} | {json.dumps(row['resumes'], sort_keys=True)} | {row.get('restart_section', '—')} |")
        text.extend(("", "## Exact commands", ""))
        for run in runs:
            recorded = json.loads((Path(run["log"]).parent / "command.json").read_text())
            environment = " ".join(f"{key}={shlex.quote(value)}" for key, value in recorded.get("env", {}).items())
            text.append(f"```sh\ncd {shlex.quote(str(PROJECT))} && {environment} {shlex.join(recorded['argv'])}\n```")
    return "\n".join(text), groups


def save_report(output: Path, report: str, groups: list[dict]) -> Path:
    destination = output.parent / "report.md" if output == DEFAULT_OUTPUT else output / "report.md"
    destination.write_text(report)
    write_json(output / "findings.json", groups)
    return destination


def extra_evidence(paths: list[str]) -> list[dict]:
    runs = []
    for name in paths:
        recorded = json.loads(Path(name).read_text())
        runs.append(read_evidence(recorded["seed"], Path(recorded["log"]).parent, recorded["returncode"]))
    return runs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--demo", action="store_true", help="exercise demo cutoff, end panels, resume and Rise Again on an editor binary")
    parser.add_argument("--profile-runs", type=int, default=2, help="natural demo runs sharing each seeded profile")
    parser.add_argument("--defeat-after-hearth", action="store_true", help="demo: keep override Health until Hearth, then set Health to 1 in the next fight and pass")
    parser.add_argument("--health", type=int, default=9999, help="starting Health override; 0 keeps normal starting Health")
    parser.add_argument("--no-embrace", action="store_true", help="exclude Embrace, abandonment and other voluntary run-ending choices")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--runs", type=int, default=0, help="0: launch sequential seeds until the wall-clock cutoff")
    parser.add_argument("--minutes", type=float, default=MAX_MINUTES)
    parser.add_argument("--processes", type=int, choices=range(1, MAX_PROCESSES + 1), default=MAX_PROCESSES)
    parser.add_argument("--seed-timeout", type=float, default=SEED_TIMEOUT_SECONDS)
    parser.add_argument("--stop-after", type=int, default=0, help="Replay stop after N decisions; 0 plays to termination")
    parser.add_argument("--script", default="tools/run_hunt.gd", help="Private driver copy for planted-fault proof")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report-only", action="store_true", help="Rebuild a completed campaign's report from its raw logs, without running Godot")
    parser.add_argument("--include-evidence", action="append", default=[], help="Supplement report findings with a separately verified seed evidence.json; excludes its run count and coverage")
    args = parser.parse_args()
    if not 0 < args.minutes <= MAX_MINUTES or args.seed_timeout <= 0 or args.runs < 0 or args.stop_after < 0 or args.health < 0:
        parser.error("minutes must be in (0, 75], seed-timeout positive, runs, stop-after and health nonnegative")
    if args.profile_runs < 1 or (args.defeat_after_hearth and (not args.demo or args.health == 0)):
        parser.error("profile-runs must be positive; defeat-after-hearth requires demo and positive starting Health")
    output = args.output_dir.resolve()
    if args.report_only:
        campaign = json.loads((output / "campaign.json").read_text())
        for key, value in campaign["options"].items():
            if key not in ("output_dir", "report_only", "include_evidence"): setattr(args, key, value)
        runs = [read_evidence(run["seed"], Path(run["log"]).parent, run["returncode"]) for run in campaign["runs"]]
        report, groups = render_report(runs, args, campaign["wall_seconds"], campaign["runs_started"], extra_evidence(args.include_evidence))
        destination = save_report(output, report, groups)
        print(f"RUN HUNT REPORT: {destination}")
        print(f"RUN HUNT REPORT CHECK: seeds={len(runs)} finding_groups={len(groups)}")
        return 0
    output.mkdir(parents=True, exist_ok=True)
    if any(output.iterdir()): parser.error("output directory must be empty (fresh seeded state is required)")
    write_json(output / "provenance.json", {"base_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True).strip(), "sha256": {name: hashlib.sha256((PROJECT / name).read_bytes()).hexdigest() for name in ("tools/run_hunt.gd", "tools/run_hunt_policy.gd", "tools/run_hunt.py")}})
    begin = time.monotonic()
    runs: list[dict] = []
    started = 0
    with ThreadPoolExecutor(max_workers=args.processes) as pool:
        active = set()
        while True:
            while len(active) < args.processes and time.monotonic() - begin < args.minutes * 60 and (not args.runs or started < args.runs):
                active.add(pool.submit(run_seed, args.seed + started, output, args))
                started += 1
            if not active: break
            done, active = wait(active, timeout=POLL_SECONDS, return_when=FIRST_COMPLETED)
            if not done: continue
            for future in done: runs.append(future.result())
            report, groups = render_report(runs, args, time.monotonic() - begin, started, extra_evidence(args.include_evidence))
            save_report(output, report, groups)
            write_json(output / "campaign.json", {"runs_started": started, "runs": runs, "wall_seconds": time.monotonic() - begin, "options": {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()}})
    report, groups = render_report(runs, args, time.monotonic() - begin, started, extra_evidence(args.include_evidence))
    destination = save_report(output, report, groups)
    print(f"RUN HUNT REPORT: {destination}")
    print(f"RUN HUNT RESULT: started={started} finished={len(runs)} finding_groups={len(groups)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

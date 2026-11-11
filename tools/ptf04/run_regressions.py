"""Run only the combined-gate failures against this task worktree."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys

MAX_WORKERS = 2
PROGRAMS = {
    name: ("tests/" + name + ".gd", []) for name in (
        "warband_test", "snare_test", "save_resume_boundary_test",
        "departed_run_cleanup_test", "event_feedback_test",
        "flurry_retirement_test", "glossary_test", "board_tile_tooltip_test",
        "suites/full_scene_choices_program", "suites/full_scene_clock_program",
    )
}
PROGRAMS["main_enemy_intent"] = ("tools/ptf04/suite_regression.gd", ["--enemy-intent"])
PROGRAMS["main_tooltip_consistency"] = ("tools/ptf04/suite_regression.gd", [])

FOCUSED_PROGRAMS = {
    "focused_checks": ("tools/ptf04/checks.gd", []),
    "focused_contextual_tutorial": ("tests/contextual_combat_tutorial_test.gd", []),
    "focused_guided_tutorial": ("tests/guided_combat_tutorial_integration_test.gd", []),
    "focused_run_end": ("tests/run_end_recap_tests.gd", []),
    "focused_event_view": ("tests/event_view_test.gd", []),
    "focused_event_rules": ("tests/event_rules_test.gd", ["--rules-only"]),
    "focused_probe_logic": ("tools/ptf04/probe.gd", ["--logic-only"]),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--program", action="append", choices=list(PROGRAMS) + list(FOCUSED_PROGRAMS))
    parser.add_argument("--focused", action="store_true")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    output = Path("/private/tmp/labyrinth_codex/ptf-04/combined-failures") / args.phase
    output.mkdir(parents=True, exist_ok=True)

    def run(name):
        script, extra = (PROGRAMS | FOCUSED_PROGRAMS)[name]
        command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "ptf-04",
                   "--stream", "--", "godot", "--headless", "--path", ".", "--script", script]
        if extra:
            command += ["--"] + extra
        path = output / (name.replace("/", "_") + ".log")
        with path.open("w") as log:
            result = subprocess.run(command, cwd=project, stdout=log, stderr=subprocess.STDOUT)
        record = dict(program=name, exit_code=result.returncode, log=str(path), command=command)
        print(json.dumps(record), flush=True)
        return record

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        records = list(pool.map(run, args.program or (FOCUSED_PROGRAMS if args.focused else PROGRAMS)))
    (output / "results.json").write_text(json.dumps(records, indent=2) + "\n")
    return int(any(row["exit_code"] != 0 for row in records))


if __name__ == "__main__":
    sys.exit(main())

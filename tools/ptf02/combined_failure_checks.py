"""Run only the combined-trial failing programs, with isolated Godot runners."""
from concurrent.futures import ThreadPoolExecutor
import argparse
import json
from pathlib import Path
import subprocess
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = Path("/private/tmp/labyrinth_codex/ptf-02/combined-feedback")
PROGRAMS = (
    "tests/warband_test.gd", "tests/snare_test.gd",
    "tests/save_resume_boundary_test.gd", "tests/departed_run_cleanup_test.gd",
    "tests/event_feedback_test.gd", "tests/flurry_retirement_test.gd",
    "tests/glossary_test.gd", "tests/board_tile_tooltip_test.gd",
    "tests/suites/full_scene_choices_program.gd",
    "tests/suites/full_scene_clock_program.gd",
    "tools/ptf02/enemy_intent_checks.gd",
)
# Two isolated processes keep simultaneous scene fixtures within a modest
# memory budget. The existing runner owns cancellation and the 300-second cap.
JOBS = 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--program", action="append", choices=PROGRAMS)
    args = parser.parse_args()
    directory = OUTPUT_DIR / args.phase
    directory.mkdir(parents=True, exist_ok=True)

    def run(program):
        log = directory / (Path(program).stem + ".log")
        command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "ptf-02",
                   "--stream", "--", "godot", "--headless", "--path", ".", "--script", program]
        with log.open("w") as stream:
            result = subprocess.run(command, cwd=PROJECT_ROOT, stdout=stream, stderr=subprocess.STDOUT)
        record = dict(program=program, exit_code=result.returncode, log=str(log), command=command)
        print(f'{program}: exit {result.returncode}; {log}', flush=True)
        return record

    with ThreadPoolExecutor(max_workers=JOBS) as pool:
        results = list(pool.map(run, args.program or PROGRAMS))
    (directory / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return int(any(result["exit_code"] for result in results))


if __name__ == "__main__":
    raise SystemExit(main())

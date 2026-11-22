"""Measure main_menu._ready after an ordinary Abandon with a large analytics log.

  python3 tools/gfix25/menu_ready.py <out_dir> <analytics_dir> <label=project> ...

For each project it builds a fixture with that project's own Abandon (the
fourth review's 10 MB analytics copy plus a run abandoned in room play), then
times main_menu._ready on fresh copies of the fixture, interleaving projects
round by round. Headless, one Godot process at a time.
"""
import os
import re
import shutil
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()
OUT = Path(sys.argv[1]).resolve()
ANALYTICS = Path(sys.argv[2]).resolve()
PROJECTS = dict(arg.split("=", 1) for arg in sys.argv[3:])
ROUNDS = int(os.environ.get("GFIX25_MENU_ROUNDS", "5"))
HERE = Path(__file__).resolve().parent


def godot(project: str, script: Path, *args: str) -> str:
	cmd = ["nice", "-n", "10", "python3", str(ROOT / "tools/godot_task_runner.py"), "--task-id", "gfix-25",
		"--timeout", "240", "--stream", "--", "godot", "--headless", "--path", project,
		"--script", str(script), "--", *args]
	return subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout


def main() -> None:
	OUT.mkdir(parents=True, exist_ok=True)
	fixtures = {}
	for label, project in list(PROJECTS.items()):
		fixture = OUT / f"fixture-{label}"
		if "@" in project:
			# label=project@fixture times a prepared save folder instead.
			project, source = project.split("@", 1)
			PROJECTS[label] = project
			if fixture.exists():
				shutil.rmtree(fixture)
			shutil.copytree(source, fixture)
			fixtures[label] = fixture
			continue
		if fixture.exists():
			shutil.rmtree(fixture)
		shutil.copytree(ANALYTICS, fixture / "analytics")
		log = godot(project, HERE / "skew_probe.gd", "setup_profile", str(fixture))
		log += godot(project, HERE / "skew_probe.gd", "end_plain", str(fixture), "abandon")
		(OUT / f"fixture-{label}.log").write_text(log)
		assert "AFTER QUIT" in log and "SCRIPT ERROR" not in log, f"fixture {label} failed"
		print(label, "fixture", next(l for l in log.splitlines() if l.startswith("AFTER QUIT")), flush=True)
		fixtures[label] = fixture
	samples = {label: [] for label in PROJECTS}
	for round_index in range(ROUNDS):
		order = list(PROJECTS) if round_index % 2 == 0 else list(reversed(PROJECTS))
		for label in order:
			copy = OUT / f"run-{label}"
			if copy.exists():
				shutil.rmtree(copy)
			shutil.copytree(fixtures[label], copy)
			log = godot(PROJECTS[label], HERE / "menu_ready_probe.gd", str(copy))
			match = re.search(r"NOTE main menu _ready ms=([\d.]+)", log)
			assert match, f"no timing for {label}: {log[-2000:]}"
			samples[label].append(float(match.group(1)))
	for label, values in samples.items():
		print(f"MENU READY {label}: median={statistics.median(values):.1f} ms samples={values}", flush=True)


if __name__ == "__main__":
	main()

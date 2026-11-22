"""gfix-25 r3 version-skew and cross-machine cases (findings 3 and 4).

  python3 tools/gfix25/skew_cases.py <out_dir> <release_worktree>

Version skew: an heirloom prompt saved by one build and finished (Continue or
New Descent) by the other must record the run once. Cross-machine: a newer
embedded profile must keep the disk's heirloom, descent counter, Depth and bank.
Prints one PASS/FAIL line per case and "GFIX25 R3 SKEW CASES: passed/total".
"""
from concurrent.futures import ThreadPoolExecutor
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()
OUT = Path(sys.argv[1]).resolve()
BUILDS = {"br": str(ROOT), "rel": str(Path(sys.argv[2]).resolve())}
PROBE = Path(__file__).resolve().parent / "skew_probe.gd"


def godot(build: str, label: str, *args: str) -> str:
	cmd = ["nice", "-n", "10", "python3", str(ROOT / "tools/godot_task_runner.py"), "--task-id", "gfix-25",
		"--timeout", "240", "--stream", "--", "godot", "--headless", "--path", BUILDS[build],
		"--script", str(PROBE), "--", *args]
	out = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
	(OUT / "logs").mkdir(parents=True, exist_ok=True)
	(OUT / "logs" / f"{label}.log").write_text(out)
	assert "SCRIPT ERROR" not in out, f"{label}: script error"
	return out


def line(log: str, label: str) -> str:
	return next((l for l in log.splitlines() if l.startswith(label + " |")), "")


def count(summary: str, field: str) -> int:
	match = re.search(field + r"=\[([^\]]*)\]", summary)
	return len([x for x in match.group(1).split(",") if x.strip()]) if match else -1


def event(summary: str, kind: str) -> int:
	match = re.search(r'"%s": (\d+)' % kind, summary)
	return int(match.group(1)) if match else 0


def value(summary: str, field: str) -> str:
	match = re.search(r"\b" + field + r"=(\S*)", summary)
	return match.group(1) if match else ""


def skew(direction: str, finish: str, kind: str) -> tuple:
	first, second = ("rel", "br") if direction == "up" else ("br", "rel")
	name = f"{direction}-{finish}-{kind}"
	folder = OUT / "data" / name
	if folder.exists():
		shutil.rmtree(folder)
	godot(first, f"{name}-setup", "setup_profile", str(folder))
	godot(first, f"{name}-prompt", "end_prompt", str(folder), kind, "quit")
	if finish == "continue":
		final = line(godot(second, f"{name}-finish", "continue_heirloom", str(folder), "duelist_rapier"), "AFTER QUIT")
	else:
		final = line(godot(second, f"{name}-finish", "new_descent", str(folder)), "AFTER NEW")
	notes = []
	if count(final, "ledger") != 1: notes.append(f"ledger={count(final, 'ledger')}")
	if count(final, "chronicle") > 1: notes.append(f"chronicle={count(final, 'chronicle')}")
	for kind_name in ("run_scored", "run_ended"):
		if event(final, kind_name) != 1: notes.append(f"{kind_name}={event(final, kind_name)}")
	if '"runs": 2' in final: notes.append("totals runs=2")
	if kind == "escape" and value(final, "bank") not in ("720", "720.0"): notes.append(f"bank={value(final, 'bank')}")
	if kind == "defeat" and '"amount": 720' not in final: notes.append("marker lost")
	return name, not notes, " ".join(notes) or "recorded once", final


def cloud(finish: str) -> tuple:
	name = f"cloud-{finish}"
	folder = OUT / "data" / name
	if folder.exists():
		shutil.rmtree(folder)
	if finish == "continue":
		log = godot("br", name, "cloud_heirloom", str(folder))
		final = line(log, "AFTER QUIT")
		finals = [line(log, "AFTER CONTINUE"), final]
		expected_counter = "5"
	else:
		godot("br", f"{name}-set", "cloud_heirloom", str(folder), "setup_only")
		final = line(godot("br", f"{name}-finish", "new_descent", str(folder)), "AFTER NEW")
		finals = [final]
		expected_counter = "6"
	notes = []
	for summary in finals:
		if value(summary, "heirloom") != "duelist_rapier": notes.append(f"heirloom={value(summary, 'heirloom') or 'none'}")
		if value(summary, "counter") != expected_counter: notes.append(f"counter={value(summary, 'counter')}")
		if value(summary, "unlock") != "2": notes.append(f"unlock={value(summary, 'unlock')}")
	return name, not notes, " ".join(notes) or "heirloom, counter and Depth kept", final


def main() -> None:
	jobs = [(skew, d, f, k) for d in ("up", "down") for f in ("continue", "new") for k in ("escape", "defeat")]
	jobs += [(cloud, "continue"), (cloud, "new")]
	with ThreadPoolExecutor(max_workers=2) as pool:
		results = list(pool.map(lambda job: job[0](*job[1:]), jobs))
	passed = 0
	for name, ok, detail, final in results:
		passed += int(ok)
		print(f"{name} {'PASS' if ok else 'FAIL'} {detail}", flush=True)
		print(f"  {final}", flush=True)
	print(f"GFIX25 R3 SKEW CASES: {passed}/{len(results)} cases passed", flush=True)
	sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
	main()

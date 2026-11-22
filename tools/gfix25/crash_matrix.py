"""gfix-25 r3 crash matrix: process-kill every profile/checkpoint write of each
ending, relaunch, then compare title Continue against New Descent.

Adapted from the fourth save-stack review harness. Headless only, at most two
Godot processes at once. Usage (from the worktree root):

  python3 tools/gfix25/crash_matrix.py <out_dir> [kind[:variant] ...]
  python3 tools/gfix25/crash_matrix.py <out_dir> --evaluate   # re-judge logs

Kinds: defeat, escape, campfire, abandon, nd, nd-active; variants: quit
(Save & Quit at the heirloom prompt), sync (profile synced before the ending),
demo (LABYRINTH_DEMO=1). Prints one line per case and a final
"GFIX25 R3 CRASH MATRIX: passed/total" line.
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
KINDS = sys.argv[2:] or ["defeat", "escape", "campfire", "abandon", "nd", "nd-active"]
PROBE = "res://tools/gfix25/kill_probe.gd"

CUTS = [
	("static func _write_profile_at(path: String, bytes: PackedByteArray) -> bool:",
		"""static var _cut_hits: Dictionary = {}
static var _cut_seq: int = 0
static func _cut(label: String) -> void:
	if OS.get_environment("GFIX_ARMED") != "1": return
	_cut_hits[label] = int(_cut_hits.get(label, 0)) + 1
	_cut_seq += 1
	var tag := label + ":" + str(_cut_hits[label])
	if OS.get_environment("GFIX_TRACE") == "1": print("CUTPOINT ", _cut_seq, " ", tag)
	if OS.get_environment("GFIX_CUT") != tag: return
	print("CUT AT ", tag)
	OS.kill(OS.get_process_id())
	while true: OS.delay_msec(100)

static func _write_profile_at(path: String, bytes: PackedByteArray) -> bool:"""),
	("\tfile.store_buffer(bytes)\n\tfile.flush()\n\tfile.close()\n\tif _load_profile_dictionary(temp_path).is_empty():",
		"\tfile.store_buffer(bytes)\n\tfile.flush()\n\tfile.close()\n\t_cut(\"p_tmp\")\n\tif _load_profile_dictionary(temp_path).is_empty():"),
	("\t\tbackup_valid = true\n\telse:\n\t\tbackup_valid = not _load_profile_dictionary(backup_path).is_empty()",
		"\t\tbackup_valid = true\n\t\t_cut(\"p_rotated\")\n\telse:\n\t\tbackup_valid = not _load_profile_dictionary(backup_path).is_empty()"),
	("\t_remove_profile_file_if_present(backup_path)\n\treturn true\n",
		"\t_cut(\"p_promoted\")\n\t_remove_profile_file_if_present(backup_path)\n\treturn true\n"),
	('var rotate_live: bool = force_backup_rotation or OS.get_name() == "Windows"',
		'var rotate_live: bool = force_backup_rotation or OS.get_name() == "Windows" or OS.get_environment("GFIX_ROTATE") == "1"'),
	("\t\t_remove_run_file_if_present(temp_path)\n\t\treturn false\n\tif transaction_probe.is_valid() and not transaction_probe.call(\"temporary_validated\"): return false",
		"\t\t_remove_run_file_if_present(temp_path)\n\t\treturn false\n\t_cut(\"r_tmp\")\n\tif transaction_probe.is_valid() and not transaction_probe.call(\"temporary_validated\"): return false"),
	("\tif transaction_probe.is_valid() and not transaction_probe.call(\"recovery_ready\"): return false",
		"\tif rotate_live: _cut(\"r_rotated\")\n\tif transaction_probe.is_valid() and not transaction_probe.call(\"recovery_ready\"): return false"),
	("\tif transaction_probe.is_valid() and not transaction_probe.call(\"promoted\"): return false",
		"\t_cut(\"r_promoted\")\n\tif transaction_probe.is_valid() and not transaction_probe.call(\"promoted\"): return false"),
	("\t# Keep the live checkpoint authoritative until both recovery paths are gone.\n",
		"\t# Keep the live checkpoint authoritative until both recovery paths are gone.\n\t_cut(\"clear\")\n"),
]


def farm(dest: Path) -> Path:
	if dest.exists():
		shutil.rmtree(dest)
	dest.mkdir(parents=True)
	for item in ROOT.iterdir():
		if item.name not in (".git", ".godot", "scripts", "output"):
			(dest / item.name).symlink_to(item)
	for sub in (".godot", "scripts"):
		(dest / sub).mkdir()
		for item in (ROOT / sub).iterdir():
			if sub == "scripts" and item.name == "progression_store.gd":
				continue
			(dest / sub / item.name).symlink_to(item)
	source = (ROOT / "scripts/progression_store.gd").read_text()
	for before, after in CUTS:
		assert source.count(before) == 1, before
		source = source.replace(before, after)
	(dest / "scripts/progression_store.gd").write_text(source)
	return dest


def godot(project: Path, label: str, env_extra: dict, *args: str) -> str:
	env = {**os.environ, "GFIX_ROTATE": "1", **env_extra}
	cmd = ["nice", "-n", "10", "python3", "tools/godot_task_runner.py", "--project", str(project),
		"--task-id", "gfix-25", "--timeout", "240", "--stream", "--",
		"godot", "--headless", "--path", str(project), "--script", PROBE, "--", *args]
	out = subprocess.run(cmd, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True).stdout
	(OUT / "logs").mkdir(parents=True, exist_ok=True)
	(OUT / "logs" / f"{label}.log").write_text(out)
	return out


def fields(line: str) -> dict:
	return dict(re.findall(r"(\w+)=(\{[^}]*\}|\S*)", line.split("|", 1)[1])) if "|" in line else {}


def jsonl(summary: dict, kind: str) -> int:
	match = re.search(r'"%s": (\d+)' % kind, summary.get("jsonl", ""))
	return int(match.group(1)) if match else 0


def spec(token: str):
	kind, _, variant = token.partition(":")
	env = {"GFIX_SYNC_PROFILE": "1"} if variant == "sync" else {}
	if variant == "demo":
		env["LABYRINTH_DEMO"] = "1"
	extra = ["quit_at_prompt"] if variant == "quit" else []
	return kind, variant, env, extra


def crash_args(kind: str, folder: Path, extra: list) -> list:
	if kind.startswith("nd"):
		return ["crash_nd", str(folder), "active" if kind == "nd-active" else "none"]
	return ["crash", str(folder), kind, *extra]


def trace(project: Path, token: str) -> list:
	kind, variant, env, extra = spec(token)
	folder = OUT / "data" / f"trace-{kind}-{variant}"
	if folder.exists():
		shutil.rmtree(folder)
	out = godot(project, f"trace-{kind}-{variant}", {**env, "GFIX_TRACE": "1"}, *crash_args(kind, folder, extra))
	assert "COMPLETED" in out and "SCRIPT ERROR" not in out, f"trace {token} failed"
	return re.findall(r"^CUTPOINT \d+ (\S+)$", out, re.M)


def case(project: Path, token: str, n: int, point: str) -> str:
	kind, variant, env, extra = spec(token)
	tag = f"{kind}{'-' + variant if variant else ''}-{n:02d}-{point.replace(':', '')}"
	base = OUT / "data" / tag
	if base.exists():
		shutil.rmtree(base)
	base.mkdir(parents=True)
	crash_dir = base / "crash"
	out = godot(project, f"{tag}-crash", {**env, "GFIX_CUT": point}, *crash_args(kind, crash_dir, extra))
	if f"CUT AT {point}" in out:
		for action in ("continue", "new"):
			d = base / action
			shutil.copytree(crash_dir, d)
			godot(project, f"{tag}-{action}", env, "relaunch", str(d), action)
	return tag


def evaluate(tag: str) -> tuple:
	logs = OUT / "logs"
	if "CUT AT" not in (logs / f"{tag}-crash.log").read_text():
		return tag, False, "no cut"
	results = {}
	for action in ("continue", "new"):
		if not (logs / f"{tag}-{action}.log").exists():
			return tag, False, f"{action} incomplete"
		log = (logs / f"{tag}-{action}.log").read_text()
		if "SCRIPT ERROR" in log or "Assertion failed" in log:
			return tag, False, f"{action} script error"
		results[action] = {l.split(" |")[0]: fields(l) for l in log.splitlines() if " | status=" in l}
	title = results["continue"].get("TITLE", {})
	after_continue = results["continue"].get("AFTER CONTINUE")
	after_new = results["new"].get("AFTER NEW", {})
	notes = []
	# A terminal checkpoint offered by Continue must settle exactly like New
	# Descent from the same files: bank, Depth, one result, or the marker.
	if title.get("selected") in ("defeat", "victory") and after_continue is not None:
		for key in ("bank", "marker", "unlock", "ledger", "chron"):
			if after_continue.get(key) != after_new.get(key):
				notes.append(f"{key} continue={after_continue.get(key)} new={after_new.get(key)}")
		for event in ("run_scored", "run_ended", "reward_claimed", "combat_ended"):
			if jsonl(after_continue, event) != jsonl(after_new, event):
				notes.append(f"{event} continue={jsonl(after_continue, event)} new={jsonl(after_new, event)}")
	# Exactly once: at most one ending per completed run, one score per
	# recorded result and one claim for the single dragon in these fixtures.
	for action, label in (("continue", "AFTER CONTINUE"), ("new", "AFTER NEW")):
		summary = results[action].get(label)
		if summary is None:
			continue
		limits = {"run_ended": int(summary.get("ids") or 0), "run_scored": int(summary.get("ledger") or 0), "reward_claimed": 1}
		for event, limit in limits.items():
			if jsonl(summary, event) > limit:
				notes.append(f"{action} {event}={jsonl(summary, event)} > {limit}")
	detail = f"title={title.get('selected') or 'none'} " + (" ".join(notes) if notes else "equivalent")
	return tag, not notes, detail


def main() -> None:
	if KINDS == ["--evaluate"]:
		# Re-judge an existing run's logs, in the order its cases were cut.
		tags = sorted(p.name[:-len("-crash.log")] for p in (OUT / "logs").glob("*-crash.log"))
	else:
		project = farm(OUT / "proj-kill")
		jobs = []
		for token in KINDS:
			for n, point in enumerate(trace(project, token), 1):
				jobs.append((token, n, point))
		with ThreadPoolExecutor(max_workers=2) as pool:
			tags = list(pool.map(lambda job: case(project, *job), jobs))
	results = [evaluate(tag) for tag in tags]
	passed = 0
	for tag, ok, detail in results:
		passed += int(ok)
		print(f"{tag} {'PASS' if ok else 'FAIL'} {detail}", flush=True)
	print(f"GFIX25 R3 CRASH MATRIX: {passed}/{len(results)} cases passed", flush=True)
	sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
	main()

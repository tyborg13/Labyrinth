#!/usr/bin/env python3
"""Verify the staged Scavenger data and mount the pack produced by export_game."""
from configparser import ConfigParser
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))

from export_game import PROJECT, export
from export_smoke import STAGING_EXCLUDES

DATA_PATH = "data/scavenger_prices.json"
PROBE = """extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not ProjectSettings.load_resource_pack(args[0]):
		push_error("ECO03 failed to mount the staged pack")
		quit(1)
		return
	var path: String = "res://data/scavenger_prices.json"
	var digest: String = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	if digest != args[1]:
		push_error("ECO03 missing or modified packed Scavenger prices")
		quit(1)
		return
	print("ECO03 PACK PRICE DATA: PASS sha256=" + digest)
	quit()
"""


def main() -> int:
    work = Path(sys.argv[1]).resolve()
    work.mkdir(parents=True, exist_ok=False)
    stage = work / "staged"
    pack = work / "scavenger.pck"

    def ignore(directory, names):
        excluded = STAGING_EXCLUDES if Path(directory) == PROJECT else set()
        return (excluded | {".DS_Store", "__pycache__"}).intersection(names)

    shutil.copytree(PROJECT, stage, ignore=ignore)
    digest = hashlib.sha256((PROJECT / DATA_PATH).read_bytes()).hexdigest()
    assert hashlib.sha256((stage / DATA_PATH).read_bytes()).hexdigest() == digest
    settings = ConfigParser(interpolation=None)
    settings.read(stage / "export_presets.cfg")
    presets = [key for key in settings.sections() if key.count(".") == 1]
    assert len(presets) == 6 and all(DATA_PATH in settings[key]["include_filter"].strip('"').split(",") for key in presets)
    print(f"ECO03 STAGED PRICE DATA: PASS presets={len(presets)} sha256={digest}", flush=True)

    # The brief requires the approved cel assets. Refuse a stale stage before
    # calling the export wrapper, which would otherwise rebuild variants.
    status = subprocess.check_output([sys.executable, str(TOOLS / "cel_look.py"), "status"], cwd=PROJECT, text=True)
    if status.strip() != "CEL_STATUS current":
        raise RuntimeError(status)
    code = export("Steam macOS", pack, "eco-03", pack_only=True, project=stage)
    if code:
        return code

    isolated = work / "mount"
    isolated.mkdir()
    (isolated / "project.godot").write_text("config_version=5\n")
    (isolated / "probe.gd").write_text(PROBE)
    return subprocess.run([sys.executable, str(TOOLS / "godot_task_runner.py"),
                           "--project", str(isolated), "--task-id", "eco-03", "--stream", "--",
                           "godot", "--headless", "--path", str(isolated), "--script", "probe.gd",
                           "--", str(pack), digest], cwd=PROJECT).returncode


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Verify the three approved effect catalogues and their imported sheets in a PCK."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT = Path(__file__).resolve().parents[2]
CATALOGUES = ("data/tile_bursts.json", "data/self_bursts.json", "data/shots.json")
SHEETS_PER_CATALOGUE = 7

PROBE = '''extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not ProjectSettings.load_resource_pack(args[0]):
		push_error("MRG-13 PCK: failed to mount " + args[0])
		quit(1)
		return
	var catalogues := 0
	var sheets := 0
	for relative: String in expected:
		var path := "res://" + relative
		var catalogue: Dictionary = expected[relative]
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == catalogue["sha256"]:
			catalogues += 1
		else:
			push_error("MRG-13 PCK: missing or changed catalogue " + path)
		var found := 0
		for sheet: Dictionary in catalogue["sizes"]:
			var atlas: String = sheet["atlas"]
			var texture: Texture2D = ResourceLoader.load(atlas, "Texture2D") as Texture2D
			if texture == null:
				push_error("MRG-13 PCK: missing imported sheet " + atlas)
				continue
			var image := texture.get_image()
			if image == null or image.is_empty():
				push_error("MRG-13 PCK: empty imported sheet " + atlas)
				continue
			image.convert(Image.FORMAT_L8)
			var hash := HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(image.get_data())
			if hash.finish().hex_encode() != sheet["sha256_pixels"]:
				push_error("MRG-13 PCK: changed sheet pixels " + atlas)
				continue
			found += 1
		sheets += found
		print("MRG-13 PCK %s: %d/%d sheets" % [relative, found, catalogue["sizes"].size()])
	var total: int = expected.values().reduce(func(count: int, row: Dictionary) -> int:
		return count + row["sizes"].size(), 0)
	var passed: bool = catalogues == expected.size() and sheets == total
	print("MRG-13 PCK: %s (%d/%d catalogues, %d/%d sheets)" % [
		"PASS" if passed else "FAIL", catalogues, expected.size(), sheets, total])
	quit(0 if passed else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path, help="Path to the exported .pck")
    args = parser.parse_args()
    pack = args.pack.resolve()
    if not pack.is_file():
        parser.error(f"Pack does not exist: {pack}")

    expected = {}
    for relative in CATALOGUES:
        source = (PROJECT / relative).read_bytes()
        sizes = json.loads(source)["sizes"]
        if len({sheet["atlas"] for sheet in sizes}) != SHEETS_PER_CATALOGUE or len(sizes) != SHEETS_PER_CATALOGUE:
            parser.error(f"Expected {SHEETS_PER_CATALOGUE} distinct sheets in {relative}")
        expected[relative] = {"sha256": hashlib.sha256(source).hexdigest(), "sizes": sizes}

    with tempfile.TemporaryDirectory(prefix="mrg13-pck-") as directory:
        project = Path(directory)
        (project / "project.godot").write_text("config_version=5\n")
        script = project / "probe.gd"
        script.write_text(PROBE)
        manifest = project / "expected.json"
        manifest.write_text(json.dumps(expected))
        return subprocess.run([
            sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", "mrg-13",
            "--stream", "--project", str(project), "--", "godot", "--headless", "--path", str(project),
            "--script", str(script), "--", str(pack), str(manifest),
        ], cwd=PROJECT).returncode


if __name__ == "__main__":
    raise SystemExit(main())

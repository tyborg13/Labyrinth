#!/usr/bin/env python3
"""Mount the production export and check the shipped effect data and textures."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


PROJECT = Path(__file__).resolve().parents[2]
CATALOGUES = {
    "data/tile_bursts.json": 7,
    "data/self_bursts.json": 7,
    "data/shots.json": 7,
    "data/strikes.json": 7,
    "data/acquisition_bursts.json": 9,
    "data/ground_fx_atlas.json": 7,
}
GROUND_STYLE = "data/ground_surface_style.json"
GROUND_DIR = "res://assets/art/effects/ground/"
GROUND_ELEMENTS = ("fire", "electrified", "ice", "rubble")
CONTROLS = "data/controls.json"

PROBE = '''extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not ProjectSettings.load_resource_pack(args[0]):
		push_error("MRG-14 PCK: failed to mount " + args[0])
		quit(1)
		return
	var catalogues: int
	var sheets: int
	var total_sheets: int
	for path: String in expected:
		var entry: Dictionary = expected[path]
		total_sheets += entry["sizes"].size()
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path) == entry["sha256"]:
			catalogues += 1
		else:
			push_error("MRG-14 PCK: missing or changed data " + path)
		var found: int
		for sheet: Dictionary in entry["sizes"]:
			if _check_sheet(sheet):
				found += 1
		sheets += found
		print("MRG-14 PCK %s: %d/%d sheets" % [path, found, entry["sizes"].size()])
	var passed: bool = catalogues == expected.size() and sheets == total_sheets
	print("MRG-14 PCK: %s (%d/%d data files, %d/%d sheets)" % [
		"PASS" if passed else "FAIL", catalogues, expected.size(), sheets, total_sheets])
	quit(0 if passed else 1)

func _check_sheet(sheet: Dictionary) -> bool:
	var atlas: String = sheet["atlas"]
	var texture: Texture2D = ResourceLoader.load(atlas, "Texture2D") as Texture2D
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		push_error("MRG-14 PCK: missing imported sheet " + atlas)
		return false
	if sheet.has("sha256_pixels"):
		image.convert(Image.FORMAT_L8)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(image.get_data())
		if digest.finish().hex_encode() == sheet["sha256_pixels"]:
			return true
	else:
		var source: Image = Image.load_from_file(sheet["source"])
		if source != null and source.get_size() == image.get_size():
			return true
	push_error("MRG-14 PCK: changed sheet " + atlas)
	return false
'''


def inventory():
    expected = {}
    for relative in [*CATALOGUES, GROUND_STYLE, CONTROLS]:
        source = (PROJECT / relative).read_bytes()
        data = json.loads(source)
        if relative == GROUND_STYLE:
            assert data["default_mode"] == "pixel"
            sizes = []
            for element in GROUND_ELEMENTS:
                atlas = data[element]["atlas"]["path"]
                sizes.append({"atlas": atlas, "source": str(PROJECT / atlas.removeprefix("res://"))})
        elif relative in CATALOGUES:
            sizes = data["sizes"]
            if relative == "data/ground_fx_atlas.json":
                sizes = [{**sheet, "atlas": GROUND_DIR + sheet["atlas"]} for sheet in sizes]
            assert len(sizes) == len({sheet["atlas"] for sheet in sizes}) == CATALOGUES[relative]
        else:
            sizes = []
        expected["res://" + relative] = {"sha256": hashlib.sha256(source).hexdigest(), "sizes": sizes}
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path, help="Path to the exported .pck")
    args = parser.parse_args()
    pack = args.pack.resolve()
    if not pack.is_file():
        parser.error(f"Pack does not exist: {pack}")

    with tempfile.TemporaryDirectory(prefix="mrg14-pck-") as directory:
        project = Path(directory)
        (project / "project.godot").write_text("config_version=5\n")
        script = project / "probe.gd"
        script.write_text(PROBE)
        manifest = project / "expected.json"
        manifest.write_text(json.dumps(inventory()))
        return subprocess.run([
            sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", "mrg-14",
            "--stream", "--project", str(project), "--", "godot", "--headless", "--path", str(project),
            "--script", str(script), "--", str(pack), str(manifest),
        ], cwd=PROJECT).returncode


if __name__ == "__main__":
    raise SystemExit(main())

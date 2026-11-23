#!/usr/bin/env python3
"""Exercise the repository export smoke and the three production metadata loaders."""

import argparse
import importlib.util
from pathlib import Path


SMOKE_PATH = Path(__file__).resolve().parents[1] / "export_smoke.py"
SPEC = importlib.util.spec_from_file_location("labyrinth_export_smoke", SMOKE_PATH)
export_smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(export_smoke)


# The smoke runner compiles this addition into its disposable release bootstrap.
# Call the real loaders, then inspect imported atlases through their catalogues.
METADATA_PROBE = """
func _check_fx_metadata() -> void:
	var bursts = load("res://scripts/tile_burst_fx.gd")
	var shots = load("res://scripts/shot_fx.gd")
	if bursts == null or shots == null:
		push_error("EXPORT_SMOKE cannot load FX catalog controllers")
		failures += 1
		return
	var files: Dictionary = {
		"tile_bursts.json": bursts.metadata(),
		"self_bursts.json": bursts.self_metadata(),
		"shots.json": shots.metadata(),
	}
	for name: String in files:
		var sizes: Array = files[name].get("sizes", [])
		if sizes.is_empty() or not FileAccess.file_exists("res://data/" + name):
			push_error("EXPORT_SMOKE missing FX catalogue " + name)
			failures += 1
			continue
		var loaded: int = 0
		for row: Dictionary in sizes:
			if ResourceLoader.load(row["atlas"]) is Texture2D:
				loaded += 1
		if loaded != sizes.size():
			push_error("EXPORT_SMOKE missing atlas for " + name)
			failures += 1
		print("QA131 EXPORT FX %s loaded=%d/%d" % [name, loaded, sizes.size()])
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    export_smoke.TASK_ID = "qa-131"
    export_smoke.PACK_PROBE = export_smoke.PACK_PROBE.replace(
        '\t_collect("res://")', '\t_check_fx_metadata()\n\t_collect("res://")', 1
    ) + METADATA_PROBE
    return export_smoke.main(["--preset", "Steam macOS", "--output-dir", str(args.output_dir)])


if __name__ == "__main__":
    raise SystemExit(main())

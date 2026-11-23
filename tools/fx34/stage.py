"""Stage exact-base and working proof scripts without editing either source tree."""

import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = "584a3c6d3"
AUDIT = 'preload("res://tools/fx34/audit.gd")'
MODIFIED = {
    "scripts/chain_attack_feedback.gd",
    "scripts/combat_board_view.gd",
    "scripts/run_scene.gd",
    "tests/pixel_fx_render_probe.gd",
    "tests/pixel_fx_render_probe_contract.json",
}
REMOVED = {
    "_draw_surface_conduction_floor",
    "_draw_surface_conduction_on",
    "_draw_tile_diamond_fill",
    "_draw_missed_equipment_cinders",
    "_draw_disintegrating_equipment_texture",
}
GEAR = REMOVED | {
    "_draw_missed_equipment_disintegration",
    "_draw_surface_floor_line",
}


def definition(source, name):
    match = re.search(rf"^func {name}\(.*?(?=^func |\Z)", source, re.M | re.S)
    if not match:
        raise ValueError(f"Unable to find {name}")
    return match.group().rstrip()


def instrument_board(source):
    function = ""
    output = []
    missed = definition(source, "_draw_missed_equipment_disintegration")
    tint_line = re.search(r"^\s+var tint: Color = .*", missed, re.M)[0].strip()
    for line in source.splitlines():
        if line.startswith("func "):
            function = line.split("(")[0].removeprefix("func ")
            output.append(line)
            if function in REMOVED:
                output.append(f'\t{AUDIT}.painter("{function}")')
            continue
        if function in GEAR:
            if function == "_draw_missed_equipment_disintegration" and line.strip() == tint_line:
                continue
            indent = line[:len(line) - len(line.lstrip())]
            if re.match(r"\s+var (corrupted_rect|rising_rect):", line):
                output.append(line)
                rect = line.strip().split(":")[0].split()[-1]
                output.append(f"{indent}{tint_line}")
                output.append(f"{indent}{AUDIT}.item(tile, progress, tint, "
                              f"{rect}.position.y - loot_rect.position.y, _tile_height())")
                continue
            primitive = re.search(r"\b(draw_(?:line|polyline|rect|colored_polygon|polygon))\(", line)
            if primitive and primitive[1] != "draw_line":
                label = primitive[1]
                output.append(f'{indent}{AUDIT}.primitive("{label}")')
                output.append(f"{indent}if not {AUDIT}.manual:")
                line = "\t" + line
            elif "if PixelFxLayer.line(" in line:
                output.append(f'{indent}{AUDIT}.primitive("PixelFxLayer.line")')
                line = line.replace("if PixelFxLayer.line", f"if not {AUDIT}.manual and PixelFxLayer.line")
        output.append(line)
    return "\n".join(output) + "\n"


def source_for(path, before):
    if before:
        return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT).decode()
    return (ROOT / path).read_text()


def stage(destination, before, instrument):
    def mirror(source, target):
        relative = source.relative_to(ROOT).as_posix()
        if relative in MODIFIED:
            content = source_for(relative, before)
            if instrument and relative.endswith("/combat_board_view.gd"):
                content = instrument_board(content)
            if instrument and relative.endswith("/chain_attack_feedback.gd"):
                marker = '\t\tawait host.call("_play_timed_animation_frames", frame_count,'
                assert content.count(marker) == 1
                content = content.replace(marker, f"\t\t{AUDIT}.beat(index, frame_count, frame_seconds, contact)\n{marker}")
            target.write_text(content)
        elif any(path.startswith(relative + "/") for path in MODIFIED):
            target.mkdir()
            for child in source.iterdir():
                mirror(child, target / child.name)
        else:
            target.symlink_to(source)

    for source in ROOT.iterdir():
        if not source.name.startswith(".") and source.name != "override.cfg":
            mirror(source, destination / source.name)
    cache = destination / ".godot"
    cache.mkdir()
    for name in ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
        (cache / name).symlink_to(ROOT / ".godot" / name)


def focused(destination):
    """Extract the unmodified focused test and its small harness from run_tests.gd."""
    source = (ROOT / "tests/run_tests.gd").read_text()
    constants = ["AnalyticsStore", "GrimoireLibrary", "ProgressionStore", "CombatEngine", "RunEngine", "RunSceneScript", "ParallelRuntime"]
    members = [
        "extends SceneTree",
        *(re.search(rf"^const {name} = .*", source, re.M)[0] for name in constants),
        "var _failures: Array[String]\nvar _assertion_count: int",
        """func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	for id: String in ["chain_attack", "battlefield_conduction", "item_pickup", "skill_run"]:
		var previous: int = _failures.size()
		await (load("res://tests/suites/%s_suite.gd" % id) as Script).run(_assert)
		print("FX-34 FOCUSED %s %s" % [id, "PASS" if _failures.size() == previous else "FAIL"])
	var previous: int = _failures.size()
	_test_missed_equipment_resolution_and_persistence(ProgressionStore.default_data())
	print("FX-34 FOCUSED missed_equipment_resolution_and_persistence %s" % ["PASS" if _failures.size() == previous else "FAIL"])
	for failure: String in _failures: printerr(failure)
	print("FX-34 FOCUSED %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)""",
        *(definition(source, name) for name in (
            "_test_missed_equipment_resolution_and_persistence", "_analytics_events_by_type",
            "_simple_room_layout", "_simple_grid", "_assert")),
    ]
    destination.write_text("\n\n".join(members) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("destination", type=Path)
    parser.add_argument("--before", action="store_true")
    parser.add_argument("--instrument", action="store_true")
    parser.add_argument("--focused", action="store_true")
    args = parser.parse_args()
    if args.focused:
        focused(args.destination)
    else:
        stage(args.destination.resolve(), args.before, args.instrument)

"""Make isolated, cache-backed projects for the exact base and current sources."""

import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = "0d3ccfd26"
OBSERVER = 'preload("res://tools/fx33/painter_log.gd")'

HOOKS = {
    "scripts/combat_board_view.gd": (
        ('\tDeathBurstView.draw_glows(self, tile)', "death_tile_glow_dispatch"),
        ('\t\t\tvar hop: Callable =', "air_painter_route"),
    ),
    "scripts/enemy_mechanics/burst_fx.gd": (
        ('\tFx._ribbon(canvas,', "death_ribbon"),
        ('\tFx._puff(canvas,', "death_puff"),
    ),
    "scripts/elemental_spell_fx.gd": (
        ('\tif PixelFxLayer.route(c, element, impact,', "impact"),
        ('\tif PixelFxLayer.route(c, element, ground,', "ground"),
        ('\tif PixelFxLayer.route(c, element, travel,', "travel"),
        ('\tif PixelFxLayer.route(c, element, release,', "release"),
        ('\t\t_ribbon(c, points, s * 0.014, _tint(col, e * 0.60))', "setup_ribbon"),
        ('\t\t\t_ribbon(c, points, s * 0.014, _tint(col, e * 0.60))', "setup_ribbon"),
    ),
    "scripts/chain_attack_fx.gd": (
        ('\tvar start: Vector2 = from_floor', "air_line_dispatch"),
    ),
    "scripts/pixel_fx_lines.gd": (
        ('\t\tlines.drawn_frame =', "pixel_stroke"),
    ),
}
EDITABLE = set(HOOKS) | {
    "scripts/chain_attack_feedback.gd",
    "scripts/enemy_mechanics/capacitor_view.gd",
    "scripts/enemy_mechanics/chain_hit_feedback.gd",
    "scripts/enemy_mechanics/death_burst_view.gd",
    "scripts/enemy_mechanics/deferred_death_view.gd",
    "scripts/dragon_spell_presentation.gd",
    "scripts/run_scene.gd",
}


def override(path, before, instrument):
    if before:
        result = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT).decode()
    else:
        result = (ROOT / path).read_text()
    if not instrument:
        return result
    lines = result.splitlines(keepends=True)
    for index in range(len(lines) - 1, -1, -1):
        line = lines[index]
        for prefix, label in HOOKS.get(path, ()):
            if line.startswith(prefix):
                indent = line[:len(line) - len(line.lstrip())]
                lines.insert(index, f'{indent}{OBSERVER}.record("{label}")\n')
                break
        if path == "scripts/combat_board_view.gd":
            if line.startswith("func present_tile_bursts("):
                lines.insert(index + 1, f"\t{OBSERVER}.submit(self, specs)\n")
            if line.startswith("func _draw_surface_floor_line("):
                lines.insert(index + 1, f'\tif not dashed and alpha > 0.0: {OBSERVER}.record("floor_line")\n')
        if path == "scripts/enemy_mechanics/chain_hit_feedback.gd" and line.startswith("static func submit("):
            lines.insert(index + 1, f"\t{OBSERVER}.hop(scene.board_view, losses)\n")
    return "".join(lines)


def stage(dest, before, instrument):
    def mirror(source, target):
        relative = source.relative_to(ROOT).as_posix()
        if relative in EDITABLE:
            target.write_text(override(relative, before, instrument))
        elif any(path.startswith(relative + "/") for path in EDITABLE):
            target.mkdir()
            for child in source.iterdir():
                mirror(child, target / child.name)
        else:
            target.symlink_to(source)

    for source in ROOT.iterdir():
        if not source.name.startswith(".") and source.name != "override.cfg":
            mirror(source, dest / source.name)
    if before:
        for path in ("scripts/chain_attack_fx.gd", "scripts/chain_attack_fx.gd.uid"):
            if not (dest / path).exists():
                (dest / path).write_text(override(path, before, instrument))
    cache = dest / ".godot"
    cache.mkdir()
    for name in ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
        (cache / name).symlink_to(ROOT / ".godot" / name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("destination", type=Path)
    parser.add_argument("--before", action="store_true")
    parser.add_argument("--instrument", action="store_true")
    args = parser.parse_args()
    stage(args.destination.resolve(), args.before, args.instrument)

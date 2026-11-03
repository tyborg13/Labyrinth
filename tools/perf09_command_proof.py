#!/usr/bin/env python3
"""Generate isolated canvas-command sinks and run the perf-09 exact oracle.

Only native CanvasItem draw calls are redirected; production renderer control
flow, geometry, colors, textures and ordering execute unchanged. Both variants
share the sinks. The reference loads the entire board renderer from pinned
commit 8af9feebc, together with the changed outcrop/spire drawing helpers.
"""
from pathlib import Path, PureWindowsPath
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROOF_CLOCK_MSEC = 42000
WINDOWS_PROOF_PATH = PureWindowsPath('C:\\temp\\quote"part\\board.gd')
REFERENCE_COMMIT = "8af9feebcb3605968348cb25891ad25dfa4f58b0"
REFERENCE_FILES = {"res://scripts/combat_board_view.gd", "res://scripts/stone_outcrop_art.gd",
                   "res://scripts/dragon_board_props.gd", "res://scripts/board_surface_presentation.gd",
                   "res://scripts/board_scene_prop_redraws.gd"}
NATIVE = ("arc", "circle", "colored_polygon", "line", "mesh", "multiline", "multimesh",
          "polygon", "polyline", "primitive", "rect", "set_transform", "set_transform_matrix",
          "string", "string_outline", "style_box", "texture", "texture_rect", "texture_rect_region")
NAMES = "|".join("draw_" + name for name in NATIVE)
# Uppercase receivers are static renderer helpers, not CanvasItem methods.
CALL = re.compile(r"(?<![\w.])(?:([a-z_][A-Za-z0-9_]*)\.)?(" + NAMES + r")\(")
REF = re.compile(r'["\'](res://scripts/[^"\']+\.gd)["\']')
SINK = '''
var perf09_commands: Array = []
var perf09_dirty_layers: Dictionary = {}
func _perf09_emit(kind: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null, f: Variant = null, g: Variant = null, h: Variant = null, i: Variant = null) -> void:
	var args: Array = [kind, a, b, c, d, e, f, g, h, i]
	while args.back() == null: args.pop_back()
	perf09_commands.append(args)
'''

def gdscript_string(path):
    # JSON quoting is compatible with GDScript strings; slash normalization
    # prevents Windows drive paths from introducing \t / \U escapes.
    return json.dumps(str(path).replace("\\", "/"), ensure_ascii=False)


def instrument(source):
    defined = set(re.findall(r"func (draw_\w+)\(", source))
    def call(match):
        # Leave static function declarations (e.g. ArtTreatment.draw_rect) alone.
        if source[max(0, match.start()-5):match.start()] == "func ":
            return match.group()
        receiver, name = match.groups()
        if receiver is None and name in defined: return match.group()
        return (f'{receiver}.call("_perf09_emit", "{name}", ' if receiver and receiver != "self"
                else f'_perf09_emit("{name}", ')
    source = CALL.sub(call, source)
    source = re.sub(r'RenderingServer.canvas_item_add_triangle_array\((\w+)\.get_canvas_item\(\),', lambda m: f'{m[1]}.call("_perf09_emit", "canvas_item_add_triangle_array",', source)
    source = "\n".join(re.sub(r"(\w+)\.get_rid\(\)", r"\1", line) if '\"canvas_item_add_triangle_array\"' in line else line for line in source.split("\n"))
    return source


def prepare(output, drop_target_queue=False):
    board = "res://scripts/combat_board_view.gd"
    references = {path: subprocess.check_output(["git", "show", REFERENCE_COMMIT + ":" + path.removeprefix("res://")], cwd=ROOT, text=True) for path in REFERENCE_FILES}
    sources = {}
    def visit(path):
        if path in sources or not (ROOT / path.removeprefix("res://")).is_file(): return
        source = (ROOT / path.removeprefix("res://")).read_text()
        sources[path] = source
        for ref in REF.findall(source): visit(ref)
    visit(board)
    changed = set(REFERENCE_FILES) | {path for path, source in sources.items() if instrument(source) != source}
    while True:
        expanded = changed | {path for path, source in sources.items() if set(REF.findall(source)) & changed}
        if expanded == changed: break
        changed = expanded
    for mode in ("reference", "candidate"):
        paths = {path: output / mode / path.removeprefix("res://") for path in changed}
        for path in sorted(changed):
            source = sources[path]
            if path in references and mode == "reference":
                source = references[path]
            if path == board and mode == "candidate" and drop_target_queue:
                source, count = re.subn(r"(for tile: Vector2i in SceneDirtyTiles\.terrain_targets[^\n]+:\n)\t\t\t_queue_scene_render_layer_for_tile\(tile\)", r"\1\t\t\tpass # injected fault: omit terrain target queue", source)
                if count != 1: raise RuntimeError("Expected one terrain-target queue for fault injection")
            source = instrument(source)
            source = source.replace("Time.get_ticks_msec()", str(PROOF_CLOCK_MSEC))
            source = re.sub(r"^(\s*)class \w+ extends (Control|Node2D|CanvasItem|Panel|TextureRect):\n", lambda m: m[0] + "\n".join(m[1] + "\t" + line if line else "" for line in SINK.splitlines()) + "\n", source, flags=re.M)
            if path == board:
                source = re.sub(r"\b(layer|_effects_telegraph_render_layer|_static_render_cache_layer)\.queue_redraw\(\)", lambda m: f"perf09_dirty_layers[str({m[1]}.name)] = true; {m[0]}", source)
            source = re.sub(r"^class_name .*\n", "", source, flags=re.M)
            for ref in REF.findall(source):
                if ref in paths:
                    source = re.sub(r"([\"'])" + re.escape(ref) + r"\1", lambda _: gdscript_string(paths[ref]), source)
            # Only Node-based sources need the sink for their own _draw methods.
            if re.search(r'^extends (Control|Node2D|CanvasItem|Panel|TextureRect)\b', source, re.M): source += SINK
            if path == board: source += "\nconst PERF09_WINDOWS_PATH_PROOF: String = " + gdscript_string(WINDOWS_PROOF_PATH) + "\n"
            paths[path].parent.mkdir(parents=True, exist_ok=True)
            paths[path].write_text(source)
    return {mode: str(output / mode / "scripts/combat_board_view.gd") for mode in ("reference", "candidate")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--states", type=Path, nargs="+", required=True)
    parser.add_argument("--drop-target-queue", action="store_true", help="Negative control: omit the candidate terrain-target redraw in generated sources")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    paths = prepare(args.output_dir.resolve(), args.drop_target_queue)
    command = ["python3", "tools/godot_task_runner.py", "--task-id", "perf-09", "--stream", "--", "godot", "--headless", "--path", ".", "--script", "tests/perf09/command_equivalence.gd", "--", "--reference", paths["reference"], "--candidate", paths["candidate"], "--output-dir", str(args.output_dir.resolve()), "--states", *[str(p.resolve()) for p in args.states]]
    if args.drop_target_queue: command.insert(command.index("--states"), "--fault-injection")
    with (args.output_dir / "command-proof.log").open("w") as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    lines = (args.output_dir / "command-proof.log").read_text().splitlines()
    print("\n".join(lines[-35:]))
    return result.returncode

if __name__ == "__main__":
    raise SystemExit(main())

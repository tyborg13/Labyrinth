"""Package diagnostic copies of the selected tree without editing that tree."""
import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/fel30"))
from prepare import COUNT, HOOK, MARK, replace


def stage(tree, output):
    branch = (tree / "scripts/action_caption_placement.gd").is_file()
    engine = (tree / "scripts/combat_engine.gd").read_text()
    compact = '\t\tsteps.append(_compact_enemy_action_step(before_state, next_state, enemy_index, action, action_context))\n'
    engine = replace(engine, compact, compact + "".join("\t" + line for line in MARK.splitlines(keepends=True)))
    append = '\t_record_runtime_performance_phase("enemy_turn_action_append", performance_phase_started)\n'
    engine = replace(engine, append, MARK + append) + COUNT

    scene = (tree / "scripts/run_scene.gd").read_text()
    step = "\t\tvar step: Dictionary = (step_var as Dictionary).duplicate(false)\n\t\tif hold_player_activation_order"
    scene = replace(scene, step, step.splitlines(keepends=True)[0] + HOOK + step.splitlines(keepends=True)[1])
    if branch:
        anchor = "\t_layout_action_banner(reposition)\n"
        scene = replace(scene, anchor, anchor + "\t_fel34_observe_caption(reposition)\n")
    else:
        anchor = "\t_layout_action_banner()\n\n# The boss bar"
        scene = replace(scene, anchor, "\t_layout_action_banner()\n\t_fel34_observe_caption()\n\n# The boss bar")
    scene += (ROOT / "tools/fel34/scene_hook.txt").read_text()

    board = (tree / "scripts/combat_board_view.gd").read_text()
    if not branch:
        accessor = (ROOT / "scripts/combat_board_view.gd").read_text()
        start = accessor.index("func action_caption_rects(")
        end = accessor.index("func enemy_intent_visual_global_rect(", start)
        board += "\n" + accessor[start:end]

    descent = (tree / "tools/fel30/descent.gd").read_text()
    descent = replace(descent, "if _native:\n\t\tif not _load_replay()", 'if OS.has_environment("FEL30_REPLAY"):\n\t\tif not _load_replay()')
    descent = replace(descent, '\t\t_tree.root.title =', '\tif _native:\n\t\t_tree.root.title =')
    descent = replace(descent, "if _native and not _transcript.has(seed):", "if not _transcript.is_empty() and not _transcript.has(seed):")
    descent = replace(descent, "if _native and _seed_actions !=", "if not _transcript.is_empty() and _seed_actions !=")
    descent = replace(descent, "if not _native else _replay_input(source)", "if _transcript.is_empty() else _replay_input(source)")
    sources = {
        "scripts/combat_engine.gd": engine,
        "scripts/run_scene.gd": scene,
        "scripts/combat_board_view.gd": board,
        "scripts/action_caption_placement.gd": (ROOT / "scripts/action_caption_placement.gd").read_text(),
        "tools/fel30/descent.gd": descent,
        "tools/fel34/replay.gd": (ROOT / "tools/fel34/replay.gd").read_text(),
        "tools/fel34/geometry.gd": (ROOT / "tools/fel34/geometry.gd").read_text(),
        "project.godot": (tree / "project.godot").read_text(),
    }
    output.mkdir(parents=True, exist_ok=True)
    files = {}
    for name, source in sources.items():
        local = name.replace("/", "__")
        (output / local).write_text(source)
        files[local] = "res://" + name
    (output / "scripts.json").write_text(json.dumps(files))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tree", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    stage(args.tree.resolve(), args.output.resolve())


if __name__ == "__main__":
    main()

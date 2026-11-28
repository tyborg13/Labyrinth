"""Stage diagnostic source copies for the fel-30 resource overlay."""
from pathlib import Path
import argparse
import json

import draw_hooks

ROOT = Path(__file__).resolve().parents[2]
HOOK = '''		if step.get("kind", "") == "fel30_action_boundary":
			var capture: Callable = get_tree().root.get_meta("fel30_enemy_action", Callable())
			if capture.is_valid(): await capture.call(self, step)
			continue
'''
MARK = '''	if turn.accepted.is_valid() and _fel30_enemy_count(before_state) >= 4:
		steps.append({"kind": "fel30_action_boundary", "actor_key": "enemy_%d" % enemy_id,
			"enemy_id": enemy_id, "action": str(action.get("type", "")), "action_index": turn.action_index - 1,
			"enemies_before": _fel30_enemy_count(before_state), "turn": int(before_state.get("turn", 0))})
'''
COUNT = '''

func _fel30_enemy_count(state: Dictionary) -> int:
	var alive: int = 0
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: alive += 1
	return alive
'''


def replace(source, needle, patch):
    if source.count(needle) != 1:
        raise ValueError(f"Expected one instrumentation anchor {needle!r}")
    return source.replace(needle, patch)


def scripts():
    path = ROOT / "scripts"
    engine = (path / "combat_engine.gd").read_text()
    compact = "		steps.append(_compact_enemy_action_step(before_state, next_state, enemy_index, action, action_context))\n"
    engine = replace(engine, compact, compact + "".join("	" + line for line in MARK.splitlines(keepends=True)))
    append = '	_record_runtime_performance_phase("enemy_turn_action_append", performance_phase_started)\n'
    engine = replace(engine, append, MARK + append)
    yield "combat_engine.gd", engine + COUNT
    scene = (path / "run_scene.gd").read_text()
    step = "		var step: Dictionary = (step_var as Dictionary).duplicate(false)\n		_hero_facing.enemy_step = step\n"
    yield "run_scene.gd", replace(scene, step, step.splitlines(keepends=True)[0] + HOOK + step.splitlines(keepends=True)[1])
    yield from draw_hooks.scripts(path, replace)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    out = parser.parse_args().directory.resolve()
    out.mkdir(parents=True, exist_ok=True)
    names = {}
    for name, source in scripts():
        local = name.replace("/", "__")
        (out / local).write_text(source)
        names[local] = name
    (out / "scripts.json").write_text(json.dumps(names))
    print(f"FEL30 OVERLAY SOURCES {out}")


if __name__ == "__main__":
    main()

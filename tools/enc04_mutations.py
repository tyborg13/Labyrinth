#!/usr/bin/env python3
"""Replay the enc-03/04 review survivors; always restore source bytes.

Run in an otherwise idle enc-04 worktree. --renderer adds the windowed scrim
mutation; without it, only the headless production regressions are run.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = Path('/private/tmp/labyrinth_codex/enc-04/mutations')
TIMEOUT_SECONDS = 240
MUTATIONS = (
    ('aiming-second-cross', 'scripts/enemy_mechanics/lob_view.gd',
     'affected = engine._vector2i_values(forecast.get("tiles", []))',
     'affected = engine._vector2i_values(forecast.get("tiles", [])).slice(0, 5)',
     'tests/enc04_forecast_test.gd', 'aiming tiles equal committed tiles'),
    ('production-caption', 'scripts/enemy_mechanics/lob_view.gd',
     'intent_step["turn_caption"] = Icons.lob_text(action)',
     'intent_step["turn_caption"] = "%s: %s" % [str(intent_step.get("actor_name", "Enemy")), str(intent_step.get("intent_name", ""))]',
     'tests/enc03_fixture_test.gd', 'Every playback caption is the approved sentence'),
    ('adjacent-forecast', 'scripts/enemy_mechanics/marked_strike.gd',
     'if index < 0: return {}',
     'if index < 0 or Paths.manhattan(enemy["pos"], state["player"]["pos"]) == 1: return {}',
     'tests/enc04_forecast_test.gd', 'aiming tiles equal committed tiles'),
)


def run_mutation(name: str, path: str, old: str, new: str,
                 command: list[str], marker: str, output: Path) -> bool:
    target = ROOT / path
    original = target.read_bytes()
    source = original.decode()
    if source.count(old) != 1:
        raise RuntimeError(f'{name}: expected one mutation anchor in {path}')
    try:
        target.write_text(source.replace(old, new, 1))
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=TIMEOUT_SECONDS)
        (output / f'{name}.log').write_text(result.stdout)
        caught = result.returncode != 0 and marker in result.stdout
        print(f'ENC04 MUTATION {name}: {"CAUGHT" if caught else "FAIL"} '
              f'(exit={result.returncode}; assertion={marker!r}; log={output / (name + ".log")})', flush=True)
        return caught
    finally:
        target.write_bytes(original)
        if target.read_bytes() != original:
            raise RuntimeError(f'{name}: source restoration failed')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--renderer', action='store_true', help='Also run the windowed empty-_draw mutation.')
    parser.add_argument('--output-dir', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    caught = []
    for name, path, old, new, script, marker in MUTATIONS:
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'enc-04',
                   '--stream', '--', 'godot', '--headless', '--path', '.', '--script', script]
        caught.append(run_mutation(name, path, old, new, command, marker, args.output_dir))
    if args.renderer:
        path = 'scripts/action_caption_scrim.gd'
        source = (ROOT / path).read_text()
        start = source.index('func _draw() -> void:')
        end = source.index('\nfunc _falloff_stops', start)
        command = [sys.executable, 'tools/enc03_proof.py', '--phase', 'after', '--task-id', 'enc-04',
                   '--result-manifest', str(args.output_dir / 'empty-draw-visual-result.json')]
        caught.append(run_mutation('empty-scrim-draw', path, source[start:end],
                                   'func _draw() -> void:\n\tpass\n', command,
                                   'Rendered scrim covers every caption text pixel at >= 0.85 alpha', args.output_dir))
    else:
        print('ENC04 MUTATION empty-scrim-draw: NOT RUN (requires --renderer and window-server access)')
    print(f'ENC04 MUTATIONS: {"PASS" if all(caught) else "FAIL"} ({sum(caught)}/{len(caught)} caught; source restored)')
    return 0 if all(caught) else 1


if __name__ == '__main__':
    raise SystemExit(main())

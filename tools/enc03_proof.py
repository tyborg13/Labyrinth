#!/usr/bin/env python3
"""Run native before/after proof, restoring owned source files after a before capture.

No Git mutation: baseline source is read with git show. Runtime saves and imports
remain isolated by visual_probe_runner. Do not edit these owned files concurrently.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE_HEAD = 'e3034e24fd8193daf717c691ba8939094927ac51'
OWNED = ('scripts/action_icon_library.gd', 'scripts/intent_badges.gd',
         'scripts/enemy_intent_compass.gd', 'scripts/enemy_mechanics/lob_view.gd',
         'scripts/enemy_mechanics/marked_strike.gd',
         'scripts/combat_board_view.gd', 'scripts/run_scene.gd')
PROOF_TIMEOUT_SECONDS = 180  # Bounded policy-v2 search plus native renderer warmup.


def slag_span(text: str) -> tuple[int, int]:
    start = text.index('  "slag_mortar": {')
    return start, text.index('\n  "', start + 4)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase', choices=('before', 'after'), required=True)
    parser.add_argument('--task-id', default='enc-03', help='Task-local runner namespace.')
    parser.add_argument('--check-only', action='store_true')
    parser.add_argument('--result-manifest', help='Fresh result path; preserves manifests from earlier director reviews.')
    parser.add_argument('--headless-test', help='Run an existing regression against baseline source, then restore.')
    args = parser.parse_args()
    original = {path: (ROOT / path).read_bytes() for path in (*OWNED, 'data/enemies.json')}
    try:
        if args.phase == 'before':
            for path in OWNED:
                (ROOT / path).write_bytes(subprocess.check_output(['git', 'show', f'{BASELINE_HEAD}:{path}'], cwd=ROOT))
            # Replace only this unit's enemy entry. All other entries retain their bytes.
            path = ROOT / 'data/enemies.json'
            text = path.read_text()
            start, end = slag_span(text)
            definition = json.loads((ROOT / 'tests/fixtures/enc03_slag_before.json').read_text())
            path.write_text(text[:start] + '  "slag_mortar": ' + json.dumps(definition, indent=2).replace('\n', '\n  ') + ',' + text[end:])
        command = [sys.executable, 'tools/visual_probe_runner.py', '--task-id', args.task_id]
        if args.headless_test:
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', args.task_id, '--stream', '--', 'godot', '--headless', '--path', '.', '--script', args.headless_test]
        elif args.check_only:
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', args.task_id, '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tests/enc03_fixture_test.gd']
        else:
            command += ['--no-headless', '--display-driver', 'macos', '--audio-driver', 'Dummy',
                        '--timeout', str(PROOF_TIMEOUT_SECONDS),
                        '--expect-size', '1920x1080', '--proof-contract', f'tests/proof_contracts/enc03_lob_{args.phase}.json',
                        '--result-manifest', args.result_manifest or f'output/enc-03/{args.phase}-visual-result.json']
        if not args.headless_test:
            command += ['--'] if args.check_only else ['tests/enc03_lob_probe.gd', '--']
            if args.phase == 'before': command += ['--before']
            if args.check_only: command += ['--check-only']
        result = subprocess.run(command, cwd=ROOT)
    finally:
        if args.phase == 'before':
            for path in OWNED: (ROOT / path).write_bytes(original[path])
            # data/enemies.json is shared across units. Restore our entry only;
            # a concurrent change to another entry must survive the capture.
            path = ROOT / 'data/enemies.json'
            text = path.read_text()
            start, end = slag_span(text)
            old_text = original['data/enemies.json'].decode()
            old_start, old_end = slag_span(old_text)
            path.write_text(text[:start] + old_text[old_start:old_end] + text[end:])
            assert all((ROOT / path).read_bytes() == original[path] for path in OWNED)
            assert path.read_text()[slice(*slag_span(path.read_text()))] == old_text[old_start:old_end]
            print('ENC03 BEFORE SOURCE RESTORATION: PASS', flush=True)
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()

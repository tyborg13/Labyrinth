"""Matched reviewer workload; source snapshots never touch another checkout."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = 'tests/suites/board_hud_movement_suite.gd'
ENTRYPOINT = 'tests/status_plates_performance_probe.gd'
# codex/peer-benchmark resolved at task start. Shared refs may advance while
# other units work; keep matched evidence bound to the original source.
BASE = 'f39db885c4c691679f17cf7e4667130480b6fc50'
PROBE_TIMEOUT_SECONDS = 90
DEFAULT_PROOF_DIR = Path('/private/tmp/sb02-proof')
REPEATS = 2
MAX_RATIO = 1.15


def matched(output):
    output.mkdir(parents=True, exist_ok=True)
    reports = {'base_revision': BASE}
    with tempfile.TemporaryDirectory(prefix='_sb02_movement_', dir=ROOT / 'tools') as temporary:
        folder = Path(temporary)
        for label, revision in [('base', BASE), ('candidate', None)]:
            probe = ROOT / ENTRYPOINT
            arguments = ['--movement-only']
            if revision:
                board = folder / 'historical_board.gd'
                source = subprocess.check_output(['git', 'show', revision + ':scripts/combat_board_view.gd'], cwd=ROOT, text=True)
                board.write_text(source.replace('class_name CombatBoardView', ''))
                helper = folder / 'historical_movement.gd'
                helper.write_text((ROOT / PROBE).read_text().replace('res://scripts/combat_board_view.gd', 'res://' + board.relative_to(ROOT).as_posix()))
                probe = folder / 'historical_probe.gd'
                probe.write_text('extends SceneTree\nfunc _initialize() -> void:\n\tpreload("res://scripts/parallel_runtime.gd").apply_from_environment()\n\tcall_deferred("_run")\nfunc _run() -> void:\n\tvar passed: bool = await preload("res://' + helper.relative_to(ROOT).as_posix() + '").run(self)\n\tquit(0 if passed else 1)\n')
                arguments = []
            reports[label] = []
            for repeat in range(REPEATS):
                result = subprocess.run(['python3', 'tools/godot_task_runner.py', '--task-id', 'sb-02', '--timeout', str(PROBE_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', '.', '--script', str(probe.relative_to(ROOT)), '--', *arguments], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                (output / f'{label}-{repeat}.log').write_text(result.stdout)
                if result.returncode:
                    raise AssertionError(result.stdout[-6000:])
                report = json.loads(re.search(r'^MOVE_CPU (.+)$', result.stdout, re.M)[1])
                report['cold_plans'] = json.loads(re.search(r'^COLD_PLAN_CPU (.+)$', result.stdout, re.M)[1])
                reports[label].append(report)
        ratio = sum(r['p50_us'] for r in reports['candidate']) / sum(r['p50_us'] for r in reports['base'])
        reports['p50_ratio'] = ratio
        (output / 'movement-comparison.json').write_text(json.dumps(reports, indent=2) + '\n')
        print('SB02 MATCHED MOVEMENT: base=%s candidate=%s p50_ratio=%.3f limit=%.2f' % ([r['p50_us'] for r in reports['base']], [r['p50_us'] for r in reports['candidate']], ratio, MAX_RATIO), flush=True)
        return reports


class Movement(unittest.TestCase):
    def test_incremental_submission(self):
        # Identity/LRU checks run in the probe; the matched budget is recorded
        # separately to avoid treating concurrent full-suite load as a benchmark.
        result = subprocess.run(['python3', 'tools/godot_task_runner.py', '--task-id', 'sb-02', '--timeout', str(PROBE_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tests/status_plates_performance_probe.gd', '--', '--movement-only'], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.assertEqual(result.returncode, 0, result.stdout[-6000:])
        self.assertIn('STATUS MOVEMENT PROBE RESULT: PASS', result.stdout)

    def test_crowded_live_hand(self):
        result = subprocess.run(['python3', 'tools/godot_task_runner.py', '--task-id', 'sb-02', '--timeout', str(PROBE_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tests/status_capture_probe.gd', '--', '--check-only', '--crowded'], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.assertEqual(result.returncode, 0, result.stdout[-6000:])
        self.assertIn('STATUS CAPTURE PROBE RESULT: PASS', result.stdout)


if __name__ == '__main__':
    reports = matched(Path(os.environ.get('SB02_PROOF_DIR', str(DEFAULT_PROOF_DIR))))
    raise SystemExit(0 if reports['p50_ratio'] <= MAX_RATIO else 1)

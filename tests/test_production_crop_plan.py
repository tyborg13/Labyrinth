"""Real writer replay, fixed-crop lossless IO, and an omitted-frame mutation."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID', 'cap-02')
PROOF_TIMEOUT_SECONDS = 180
EXPECTED_CROP = [269, 156, 1045, 744]


class ProductionCropPlanTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cap02-crop-')
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def capture(self, output, *arguments, script=None):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream', '--',
                   'godot', '--headless', '--path', '.', '--script',
                   'tests/maquette_cutout/production_crop_plan_test.gd', '--', '--output', str(output), *arguments]
        if script is not None:
            command[command.index('--script') + 1] = str(script)
        return subprocess.run(command, cwd=PROJECT, text=True, capture_output=True, timeout=PROOF_TIMEOUT_SECONDS)

    def test_moving_actor_across_scenarios_has_one_covering_crop(self):
        output = self.root / 'complete'
        result = self.capture(output)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PRODUCTION CROP PLAN: PASS (0 failures; 4 frames; 2 scenarios)', result.stdout)
        records = json.loads((output / 'native_storage.json').read_text())['files']
        self.assertEqual(set(records), {f'frame_{frame}.png' for frame in range(4)})
        for row in records.values():
            self.assertEqual(row['crop'], EXPECTED_CROP)
            self.assertEqual(row['size'], [1920, 1080])
            self.assertEqual(row['encoding'], 'webp')

    def test_escape_fails_with_scenario_clip_frame_before_writing(self):
        output = self.root / 'escape'
        result = self.capture(output, '--escape-after-plan')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('Production action canvas escaped the fixed run crop: scenario=rear/copied_action clip=mirror frame=99', result.stdout + result.stderr)
        self.assertIn('PRODUCTION CROP ESCAPE: REJECTED', result.stdout)
        self.assertEqual(list(output.iterdir()), [])

    def test_fixture_only_plan_mutation_is_rejected(self):
        # Disposable copies share one mutated Storage resource. Production
        # sources and their assertions remain untouched by this mutation.
        source = PROJECT / 'tests/maquette_cutout'
        storage = (source / 'capture_storage.gd').read_text()
        start = storage.index('static func record_production_canvas(')
        end = storage.index('\nstatic func finish_production(', start)
        storage = storage[:start] + '''static func record_production_canvas(_board: Control, _unit: Dictionary) -> void:
\tpass
''' + storage[end:]
        mutant_storage = self.root / 'storage.gd'
        mutant_storage.write_text(storage)
        base = (PROJECT / 'tests/rr20/production_capture.gd').read_text().replace(
            'res://tests/maquette_cutout/capture_storage.gd', str(mutant_storage))
        mutant_base = self.root / 'base.gd'
        mutant_base.write_text(base)
        script = (source / 'production_crop_plan_test.gd').read_text().replace(
            'res://tests/rr20/production_capture.gd', str(mutant_base))
        mutant_script = self.root / 'fixture.gd'
        mutant_script.write_text(script)
        result = self.capture(self.root / 'mutant', script=mutant_script)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Production action canvas escaped the fixed run crop', result.stdout + result.stderr)
        self.assertIn('Whole-run union, outward rounding and 16 px margin', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()

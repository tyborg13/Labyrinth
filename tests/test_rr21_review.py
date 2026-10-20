"""Cold review evidence and stale-capture routing; never claim GPU proof."""
import copy
import ast
import inspect
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/briar_weaver')]
from rr21_case import CASE
from rr21_evidence import native_current
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import bindings

REVIEW_TIMEOUT_SECONDS = 180  # Existing rr-21 headless proof timeout.
COMMAND_STUB_TIMEOUT_SECONDS = 10  # Existing owner-proof test convention.
REQUIRED_CLIPS = ('lash', 'thornwall')
INVALID_CAPTURE_SIZE = [1, 1]


class ReviewTests(unittest.TestCase):
    def test_normal_review_refreshes_and_recaptures_only_stale_native_inputs(self):
        # Inert command stubs verify the real shell's windowed routing. Actual
        # Bone2D evidence and direction gates are exercised separately below.
        with tempfile.TemporaryDirectory(prefix='rr21-review-routing-') as folder:
            folder = Path(folder)
            stub = folder / 'python3'
            stub.write_text(f'#!{sys.executable}\n' + '''import json, os, sys
with open(os.environ['RR21_COMMAND_LOG'], 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
if '--native-current' in sys.argv:
    sys.exit(0 if os.environ['RR21_FIXTURE_CURRENT'] == '1' else 1)
''')
            stub.chmod(0o755)
            for current in (False, True):
                with self.subTest(current=current):
                    log = folder / ('current.jsonl' if current else 'stale.jsonl')
                    environment = dict(os.environ, PATH=str(folder) + os.pathsep + os.environ['PATH'],
                        RR21_COMMAND_LOG=str(log), RR21_FIXTURE_CURRENT='1' if current else '0')
                    result = subprocess.run(['sh', 'experiments/cutouts/briar_weaver/rr21_proof.sh', 'review'],
                        cwd=ROOT, env=environment, capture_output=True, text=True, timeout=COMMAND_STUB_TIMEOUT_SECONDS)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    calls = [json.loads(line) for line in log.read_text().splitlines()]
                    refresh = next(i for i, call in enumerate(calls) if '--refresh' in call)
                    provenance = next(i for i, call in enumerate(calls) if '--native-current' in call)
                    gate = next(i for i, call in enumerate(calls) if any(a.endswith('/rr21_gates.py') for a in call))
                    encode = next(i for i, call in enumerate(calls) if 'humanoid_cutout.proof' in call)
                    captures = [i for i, call in enumerate(calls) if 'tools/visual_probe_runner.py' in call]
                    self.assertLess(refresh, provenance)
                    self.assertLess(provenance, gate)
                    self.assertLess(gate, encode)
                    self.assertIn('--native', calls[gate])
                    self.assertEqual(len(captures), 0 if current else 1)
                    if captures:
                        self.assertLess(provenance, captures[0])
                        self.assertLess(captures[0], gate)
                        self.assertIn('tests/rr21/native_capture.gd', calls[captures[0]])

    def test_removing_containment_guard_is_caught_for_both_outside_paths(self):
        import tests.test_rr21_walk as walk_tests
        tree = ast.parse(inspect.getsource(read_report))
        guard = next(node for node in ast.walk(tree) if isinstance(node, ast.If)
                     and 'path.is_relative_to(proof)' in ast.unparse(node.test))
        guard.test.values = guard.test.values[1:]  # Keep existence and hash checks.
        namespace = read_report.__globals__.copy()
        exec(compile(ast.fix_missing_locations(tree), '<removed containment guard>', 'exec'), namespace)
        result = unittest.TestResult()
        with patch.object(walk_tests, 'read_report', namespace['read_report']):
            walk_tests.WalkTests('test_compact_evidence_loads_legacy_and_hash_bound_full_rows').run(result)
        self.assertEqual(result.errors, [])
        self.assertEqual(len(result.failures), 2)
        self.assertTrue(all('ValueError not raised' in details for _, details in result.failures))

    def fixture(self, folder):
        """Checkout case files plus compact index, without ignored diagnostics."""
        case = folder / 'checkout/mq9'
        tracked = subprocess.check_output(['git', 'ls-files', '-z', '--', str(CASE.relative_to(ROOT))], cwd=ROOT)
        for filename in tracked.decode().split('\0'):
            if not filename: continue
            relative = (ROOT / filename).relative_to(CASE)
            if 'proof' in relative.parts: continue
            destination = case / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / filename, destination)
        (case / 'proof').mkdir()
        # Use the committed compact index, never the worker's ignored samples.
        relative = str(CASE.relative_to(ROOT) / 'proof/samples.json')
        revision = 'HEAD'
        present = subprocess.run(['git', 'cat-file', '-e', revision + ':' + relative],
                                 cwd=ROOT, capture_output=True)
        if present.returncode:
            # A no-commit integration merge can introduce this case. Its
            # incoming record is committed even though HEAD predates it.
            revision = 'MERGE_HEAD'
        (case / 'proof/samples.json').write_bytes(subprocess.check_output(
            ['git', 'show', revision + ':' + relative], cwd=ROOT))
        shutil.copyfile(CASE / 'proof/build.json', case / 'proof/build.json')
        self.assertFalse((case / 'proof/logs').exists())
        self.assertNotIn('samples', read_json(case / 'proof/samples.json'))
        # Only provenance is exercised on this synthetic capture manifest.
        # --validate-only must not run native pixel gates or the encoder.
        manifest = {'test_fixture': True, 'ok': True, 'native_pixels': True,
            'size': [1920, 1080], 'ui_scale': 1, 'inputs': bindings(case), 'frames': []}
        write_json(case / 'proof/native/frames.json', manifest)
        return case

    def run_review(self, case):
        result = subprocess.run(['sh', 'experiments/cutouts/briar_weaver/rr21_proof.sh',
            'review', '--validate-only'], cwd=ROOT, env=dict(os.environ, RR21_CASE=str(case)),
            text=True, capture_output=True, timeout=REVIEW_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('RR21 REVIEW PREFLIGHT: PASS', result.stdout)
        print(result.stdout, end='')
        compact = read_json(case / 'proof/samples.json')
        self.assertNotIn('samples', compact)
        full = read_report(case)
        self.assertEqual(full['inputs'], bindings(case))
        self.assertEqual(compact['full_samples']['sha256'], digest(case / 'proof/logs/samples.json'))
        gate = read_json(case / 'proof/gates.json')
        self.assertEqual(gate['errors'], [])
        for view in ('front', 'rear'):
            direction = gate['views'][view]['direction']
            self.assertTrue(direction['ok'])
            for clip in REQUIRED_CLIPS:
                self.assertGreater(direction['clip_positive_checks'][clip], 0)
                rows = [r for r in full['samples'] if r['view'] == view and r['clip'] == clip
                        and r['kind'] == 'presented']
                self.assertTrue(rows)
                self.assertTrue(all(r.get('direction_bones') for r in rows))
        return full

    def test_review_from_clean_proof_state_regenerates_real_direction_evidence(self):
        with tempfile.TemporaryDirectory(prefix='review_clean_', dir=CASE / 'proof/logs') as folder:
            case = self.fixture(Path(folder))
            manifest = case / 'proof/native/frames.json'
            capture_hash = digest(manifest)
            full = self.run_review(case)
            self.assertEqual(digest(manifest), capture_hash)
            # Reproduce e05340c42's stale-contract condition in the headless
            # evidence only. Review must regenerate, not relabel its hashes.
            stale = copy.deepcopy(full)
            key = 'runtime:tests/rr21/production_contract.json'
            stale['inputs'][key] = 'stale-contract-fixture'
            write_json(case / 'proof/logs/samples.json', stale)
            compact = read_json(case / 'proof/samples.json')
            compact['full_samples']['sha256'] = digest(case / 'proof/logs/samples.json')
            write_json(case / 'proof/samples.json', compact)
            self.run_review(case)
            self.assertEqual(digest(manifest), capture_hash)

    def test_native_preflight_requires_current_capture_and_never_rebinds_it(self):
        with tempfile.TemporaryDirectory(prefix='review_stale_', dir=CASE / 'proof/logs') as folder:
            case = self.fixture(Path(folder))
            capture = case / 'proof/native'
            path = capture / 'frames.json'
            fresh = read_json(path)
            self.assertTrue(native_current(case, capture))
            self.assertFalse(native_current(case, case / 'proof/missing_native'))
            for mutant in (dict(fresh, ok=False), dict(fresh, native_pixels=False),
                           dict(fresh, size=INVALID_CAPTURE_SIZE), dict(fresh, inputs={})):
                write_json(path, mutant)
                before = digest(path)
                self.assertFalse(native_current(case, capture))
                self.assertEqual(digest(path), before)
            # Validation-only must fail closed instead of attempting a GUI
            # capture when current provenance is absent.
            result = subprocess.run(['sh', 'experiments/cutouts/briar_weaver/rr21_proof.sh',
                'review', '--validate-only'], cwd=ROOT, env=dict(os.environ, RR21_CASE=str(case)),
                text=True, capture_output=True, timeout=REVIEW_TIMEOUT_SECONDS)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('RECAPTURE REQUIRED', result.stdout)
            self.assertEqual(digest(path), before)


if __name__ == '__main__': unittest.main()

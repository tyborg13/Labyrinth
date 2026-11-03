"""Pinned 2bd5ea39a submissions, whole-submission costs, cache and reload guards."""
import gzip
import json
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from tools.python_suite_groups import perf_test


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a'
MANIFEST_SHA256 = 'de38d3fb2145f0a0b81d249f202bb25305d6218c96a5fe08818d250d932ce7e7'
TIMING_HEADROOM_FACTOR = 2.0
RUNNER_TIMEOUT_SECONDS = 120
CLEAN_TIMING_RUNS = 5
MAX_CACHE_PAYLOAD_BYTES = 4 * 1024 * 1024
PIN_FIXTURE_BONES = (1, 0, 0, 1)
UNAPPROVED_BYTE = b'\n'
REVIEWER_PATCH = ROOT / 'tests/rr49/proof/rr50/reviewer/fast-path-disabled.patch'
REVIEW1 = ROOT / 'tests/rr49/proof/rr50/feedback1/reviewer'
REFERENCE_REVISION = 'c78b9f7f68cc52880a6e74d805983a698999c1b6'
REFERENCE_FIXTURE = ROOT / 'tests/rr49/fixtures/optimized_c78b9f7f6'


def stage_runtime(project):
    """Mutation isolation: production scripts copied, all other inputs read-only."""
    project.mkdir()
    for source in ROOT.iterdir():
        if source.name == 'scripts':
            shutil.copytree(source, project / source.name)
        elif source.name != '.git':
            (project / source.name).symlink_to(source, target_is_directory=source.is_dir())


class SubmissionTests(unittest.TestCase):
    def run_godot(self, script, arguments=(), expected=0, project=ROOT):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-50', '--project', str(project),
                   '--timeout', str(RUNNER_TIMEOUT_SECONDS), '--stream', '--',
                   'godot', '--headless', '--path', '.', '--script', 'tests/rr49/' + script]
        if arguments:
            command += ['--', *map(str, arguments)]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                             timeout=RUNNER_TIMEOUT_SECONDS + 2)
        if expected is None:
            self.assertIn(run.returncode, (0, 1), run.stdout + run.stderr)
            self.assertIn('RR49 SUBMISSION COST:', run.stdout)
        else:
            self.assertEqual(run.returncode, expected, run.stdout + run.stderr)
        return run.stdout




    def test_every_polygon_matches_and_one_changed_vertex_is_caught(self):
        baseline = json.loads(gzip.decompress((ROOT / 'tests/goldens/rr49_submission.json.gz').read_bytes()))
        with tempfile.TemporaryDirectory(prefix='rr49-identity-') as folder:
            output = Path(folder) / 'actual.json'
            self.run_godot('submission_hashes.gd', ['--input', FIXTURE / 'cases.json', '--output', output])
            current = json.loads(output.read_text())
            self.assertEqual(current['paths'], baseline['paths'])
            self.assertEqual(current['poses'], baseline.get('poses', 8364))
            self.assertEqual(current['buffers'], baseline.get('buffers', 304685))
            self.assertEqual(len(current['rows']), len(baseline['rows']))
            self.assertEqual(sum(map(len, current['rows'])), sum(map(len, baseline['rows'])))
            differences = [i for i, (a, b) in enumerate(zip(current['rows'], baseline['rows'])) if a != b]
            self.assertEqual(differences, [])
            cases = json.loads((FIXTURE / 'cases.json').read_text())
            cases['cases'] = cases['cases'][:1]
            selected = Path(folder) / 'first.json'
            selected.write_text(json.dumps(cases))
            self.run_godot('submission_hashes.gd', ['--input', selected, '--output', output, '--mutate-vertex'])
            changed = json.loads(output.read_text())
            bad = [i for i, (a, b) in enumerate(zip(changed['rows'][0], baseline['rows'][0])) if a != b]
            self.assertEqual(bad, [0])
        print('RR49 EXACT IDENTITY: PASS (8364 poses; 304685 polygon buffers; actual one-vertex mutation caught)')

    @perf_test
    def test_all_clip_costs_and_three_interleaved_rigs(self):
        with tempfile.TemporaryDirectory(prefix='rr49-cost-') as folder:
            output = Path(folder) / 'cost.json'
            for index in range(CLEAN_TIMING_RUNS):
                text = self.run_godot('submission_cost.gd', ['--headroom', TIMING_HEADROOM_FACTOR, '--output', output])
                result = json.loads(output.read_text())
                self.assertTrue(result['ok'])
                self.assertEqual(result['headroom_factor'], TIMING_HEADROOM_FACTOR)
                self.assertEqual((result['motion_median_budget_us'], result['motion_max_budget_us'], result['held_budget_us']),
                                 (2000, 3000, 500))
                self.assertEqual(len(result['clips']), 18)
                self.assertEqual(len(result['interleaved']), 2)
                self.assertEqual(len(result['paired']), 2)
                for pair in result['paired']:
                    self.assertEqual(pair['minimum_speedup'], 1.6)
                    self.assertEqual(pair['samples'], 7 * 51 * 3)
                    self.assertGreaterEqual(pair['speedup'], 1.6)
                    self.assertEqual(pair['reference_revision'], REFERENCE_REVISION)
                    self.assertEqual(pair['maximum_reference_factor'], 1.3)
                    self.assertEqual(pair['reference_factor_percentile'], 0.9)
                    self.assertLessEqual(pair['production_reference_factor'], 1.3)
                    self.assertTrue(pair['reference_ok'])
                    print('RR50 PAIRED RUN ' + str(index + 1) + ': ' + json.dumps(pair), flush=True)
                for view in result['interleaved']:
                    self.assertEqual(view['rigs'], 3)
                    for cache in view['caches']:
                        self.assertEqual(cache['repeat_misses'], 0)
                        self.assertGreater(cache['repeat_hits'], 0)
                worst_median = max(row['stable_median_us'] for row in result['clips'])
                worst_max = max(row['stable_max_us'] for row in result['clips'])
                print(f'RR50 ABSOLUTE RUN {index + 1}: median={worst_median} us; max={worst_max} us; headroom={TIMING_HEADROOM_FACTOR}', flush=True)
                print(next(line for line in text.splitlines() if line.startswith('RR49 SUBMISSION COST:')), flush=True)
        print('RR50 CLEAN TIMING: PASS (5/5 paired and absolute guards under task runner)', flush=True)

    @perf_test
    def test_production_fast_path_removal_is_rejected(self):
        mutations = [('disabled-fast-path', REVIEWER_PATCH, 'fallback_ok'),
                     ('slowdown30', REVIEW1 / 'slowdown30.patch', 'reference_ok'),
                     ('partial-fast-path', REVIEW1 / 'partial-fast-path.patch', 'reference_ok')]
        with tempfile.TemporaryDirectory(prefix='rr50-cost-mutations-') as folder:
            for label, patch_path, component in mutations:
                with self.subTest(mutation=label):
                    project = Path(folder) / label
                    stage_runtime(project)
                    patched = subprocess.run(['patch', '--batch', '--forward', '-p1', '-i', str(patch_path)],
                                             cwd=project, capture_output=True, text=True)
                    self.assertEqual(patched.returncode, 0, patched.stdout + patched.stderr)
                    output = Path(folder) / (label + '.json')
                    self.run_godot('submission_cost.gd', ['--headroom', TIMING_HEADROOM_FACTOR, '--output', output],
                                   expected=1, project=project)
                    result = json.loads(output.read_text())
                    self.assertFalse(result['ok'])
                    self.assertEqual(len(result['paired']), 2)
                    for pair in result['paired']:
                        self.assertEqual(pair['reference_revision'], REFERENCE_REVISION)
                        self.assertFalse(pair[component], pair)
                        self.assertFalse(pair['ok'])
                        if component == 'fallback_ok': self.assertLess(pair['speedup'], 1.6)
                        else: self.assertGreater(pair['production_reference_factor'], 1.3)
                    reason = 'Paired fast-path speedup:' if component == 'fallback_ok' else 'Immutable optimized reference cost:'
                    self.assertTrue(any(reason in error for error in result['errors']))
                    print('RR50 TIMING MUTATION ' + label + ': PASS (rejected; ' + json.dumps(result['paired']) + ')', flush=True)

    def test_cache_payload_and_capacity_mutation(self):
        with tempfile.TemporaryDirectory(prefix='rr50-cache-payload-') as folder:
            output = Path(folder) / 'cache.json'
            text = self.run_godot('cache_payload.gd', ['--output', output])
            result = json.loads(output.read_text())
            self.assertTrue(result['ok'])
            self.assertEqual(len(result['views']), 2)
            for row in result['views']:
                self.assertEqual(row['maximum_bytes'], MAX_CACHE_PAYLOAD_BYTES)
                for field in ('motion_full_bytes', 'idle_full_bytes', 'mixed_full_bytes'):
                    self.assertGreater(row[field], 0)
                    self.assertLessEqual(row[field], MAX_CACHE_PAYLOAD_BYTES)
            print(next(line for line in text.splitlines() if line.startswith('RR50 CACHE PAYLOAD:')), flush=True)
            project = Path(folder) / 'project'
            stage_runtime(project)
            path = project / 'scripts/maquette_cutout_runtime/stable_skin.gd'
            original = path.read_text()
            self.assertEqual(original.count('const CACHE_CAPACITY: int = 16'), 1)
            path.write_text(original.replace('const CACHE_CAPACITY: int = 16', 'const CACHE_CAPACITY: int = 128'))
            self.run_godot('cache_payload.gd', ['--output', output], expected=1, project=project)
            result = json.loads(output.read_text())
            self.assertFalse(result['ok'])
            # This must fail the memory assertion itself, independently of the
            # exact-capacity assertion, with actual full retained payloads.
            self.assertTrue(any(error.startswith('Cache payload:') for error in result['errors']))
            for row in result['views']:
                self.assertGreater(row['mixed_full_bytes'], MAX_CACHE_PAYLOAD_BYTES)
            print('RR50 CAPACITY MUTATION: PASS (128 exceeds 4 MiB in both views)', flush=True)

    def test_disabled_cache_and_legacy_inner_loop_are_rejected(self):
        with tempfile.TemporaryDirectory(prefix='rr49-cost-mutations-') as folder:
            output = Path(folder) / 'cost.json'
            for option, reason in [('--disable-cache', 'cache misses')]:
                self.run_godot('submission_cost.gd', ['--headroom', TIMING_HEADROOM_FACTOR, '--output', output, option], expected=1)
                result = json.loads(output.read_text())
                self.assertFalse(result['ok'], option)
                self.assertTrue(any(reason in error for error in result['errors']), (option, result['errors']))
        print('RR49 CACHE MUTATION: PASS (disabled cache loses repeat hits)')

    def test_same_facing_reload_and_real_rebuild(self):
        text = self.run_godot('reload.gd')
        line = next(line for line in text.splitlines() if line.startswith('RR49 RELOAD: '))
        result = json.loads(line.split(': ', 1)[1])
        self.assertEqual(result['errors'], [])
        self.assertEqual(len(result['rows']), 4)
        for row in result['rows']:
            self.assertEqual(row['helpers'], 0 if row['legacy'] else 5)
            self.assertEqual(len(row['changed']), (6 if row['view'] == 'front' else 5) if row['legacy'] else 0)
        print('RR49 RELOAD: PASS (5 helpers; identical front/rear buffers; legacy double-load mutation caught)')

    def test_three_interleaved_rigs_reuse_cache(self):
        with tempfile.TemporaryDirectory(prefix='rr49-cache-behavior-') as folder:
            output = Path(folder) / 'cost.json'
            # A timing miss cannot mask or fail these deterministic counters.
            self.run_godot('submission_cost.gd', ['--headroom', TIMING_HEADROOM_FACTOR, '--output', output], expected=None)
            result = json.loads(output.read_text())
            self.assertEqual(len(result['interleaved']), 2)
            for view in result['interleaved']:
                self.assertEqual(view['rigs'], 3)
                for cache in view['caches']:
                    self.assertEqual(cache['repeat_misses'], 0)
                    self.assertGreater(cache['repeat_hits'], 0)

    @perf_test
    def test_legacy_inner_loop_exceeds_cost_budget(self):
        with tempfile.TemporaryDirectory(prefix='rr49-legacy-cost-') as folder:
            output = Path(folder) / 'cost.json'
            self.run_godot('submission_cost.gd', ['--headroom', TIMING_HEADROOM_FACTOR, '--output', output,
                                               '--legacy-submission'], expected=1)
            result = json.loads(output.read_text())
            self.assertFalse(result['ok'])
            self.assertTrue(any('cost:' in error for error in result['errors']))


if __name__ == '__main__':
    unittest.main()

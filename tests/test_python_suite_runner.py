"""Synthetic serial/parallel parity, fixture lifecycle, failures and audit grouping."""
import ast
from collections import Counter
from contextlib import redirect_stdout
import fnmatch
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import python_suite_audit as audit
import run_python_suite as runner
import sweep_parallel as sweeps
import python_suite_selection as selection

CLI_TIMEOUT_SECONDS = 40
CONCURRENCY_FIXTURE_DEADLINE_SECONDS = 10
CONCURRENCY_FIXTURE_POLL_SECONDS = 0.01


def declare_resources(root, modules):
    path = root / audit.RESOURCE_TABLE
    path.parent.mkdir(parents=True, exist_ok=True)
    resources = {resource: resource for names in modules.values() for resource in names}
    path.write_text(json.dumps(dict(version=1, resources=resources, modules=modules)))
    (root / selection.GROUP_TABLE).write_text(json.dumps(dict(version=1, groups={
        'default': dict(modules=list(modules), triggers=[])})))


class SuiteRunnerTests(unittest.TestCase):
    def test_distinct_modules_execute_concurrently_and_worker_crashes_fail_closed(self):
        with tempfile.TemporaryDirectory(prefix='perf06-concurrency-') as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            subprocess.run(['git', 'init', '-q', root], check=True)
            for name, other in (('a', 'b'), ('b', 'a')):
                source = f'''import time, unittest
from pathlib import Path
class Tests(unittest.TestCase):
    def test_barrier(self):
        root = Path(__file__).resolve().parents[1]
        (root / '{name}.ready').touch()
        deadline = time.monotonic() + {CONCURRENCY_FIXTURE_DEADLINE_SECONDS}
        while not (root / '{other}.ready').exists():
            self.assertLess(time.monotonic(), deadline, 'module workers did not overlap')
            time.sleep({CONCURRENCY_FIXTURE_POLL_SECONDS})
'''
                (root / 'tests' / ('test_' + name + '.py')).write_text(source)
            declare_resources(root, {'test_a': ['a.ready'], 'test_b': ['b.ready']})
            result = self.cli(root, root / 'proof', 2)
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn('Ran 2 tests', result.stdout)
            (root / 'tests/test_a.py').write_text('import os, unittest\nclass Tests(unittest.TestCase):\n'
                                                '    def test_crash(self): os._exit(3)\n')
            result = self.cli(root, root / 'crash', 2)
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn('exited 3', result.stdout)
            self.assertNotIn('OK', result.stdout)
            self.assertFalse((root / 'crash/summary.json').exists())

    def test_imported_fixture_testcases_stay_with_the_discovering_module(self):
        with tempfile.TemporaryDirectory(prefix='perf06-imported-') as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            subprocess.run(['git', 'init', '-q', root], check=True)
            (root / 'tests/fixture.py').write_text('import unittest\nclass Fixture(unittest.TestCase):\n'
                                                '    def test_imported(self): pass\n')
            for name in ('test_a', 'test_b'):
                (root / 'tests' / (name + '.py')).write_text('from fixture import Fixture\n')
            (root / 'tests/test_a.py').write_text(
                'from fixture import Fixture\nfrom pathlib import Path\n'
                'events = Path(__file__).resolve().parents[1] / "module-events.log"\n'
                'with events.open("a") as stream: stream.write("import\\n")\n'
                'def load_tests(loader, suite, pattern):\n'
                '    with events.open("a") as stream: stream.write("hook\\n")\n'
                '    return suite\n')
            (root / 'tests/testing_contract.py').write_text('from fixture import Fixture\n')
            (root / 'tests/test_empty.py').write_text('# Empty discovery module.\n')
            (root / 'tests/package').mkdir()
            (root / 'tests/package/__init__.py').write_text(
                'import unittest\nfrom fixture import Fixture\nfrom pathlib import Path\n'
                'events = Path(__file__).resolve().parents[2] / "package-events.log"\n'
                'with events.open("a") as stream: stream.write("import\\n")\n'
                'def load_tests(loader, suite, pattern):\n'
                '    with events.open("a") as stream: stream.write("hook\\n")\n'
                '    return unittest.TestSuite([Fixture("test_imported")])\n')
            (root / 'tests/package/test_ignored.py').write_text(
                'raise AssertionError("package hook must stop recursive discovery")\n')
            declarations = {name: [] for name in audit.discover_modules(root)}
            declarations['test_a'] = ['module-events.log']
            declarations['package'] = ['package-events.log']
            declare_resources(root, declarations)
            output = root / 'proof'
            result = self.cli(root, output, 3)
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn('Ran 4 tests', result.stdout)
            record = json.loads((output / 'summary.json').read_text())
            self.assertEqual(len([test for shard in record['shards'] for test in shard['ids']]), 4)
            self.assertEqual(set(record['modules']), {'test_a', 'test_b', 'test_empty', 'testing_contract', 'package', 'package.test_ignored'})
            self.assertEqual((root / 'module-events.log').read_text(), 'import\nhook\n')
            self.assertEqual((root / 'package-events.log').read_text(), 'import\nhook\n')
            serial = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests'],
                cwd=root, capture_output=True, text=True, timeout=CLI_TIMEOUT_SECONDS)
            self.assertIn('Ran 4 tests', serial.stderr)
            self.assertEqual(serial.returncode, 0, serial.stderr)

    def fixture(self, folder):
        root = Path(folder) / 'project'
        (root / 'tests').mkdir(parents=True)
        subprocess.run(['git', 'init', '-q', root], check=True)
        sources = {
            'test_pass.py': '''import unittest
class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.ready = True
    def test_pass(self): self.assertTrue(self.ready)
    @unittest.skip('explicit fixture skip')
    def test_skip(self): pass
    @unittest.expectedFailure
    def test_expected(self): self.fail('expected fixture')
''',
            'test_fail.py': '''import unittest
class Tests(unittest.TestCase):
    def test_failure(self): self.fail('fixture traceback marker')
    def test_error(self): raise ValueError('fixture error marker')
    def test_subtests(self):
        for frame in (1,2):
            with self.subTest(frame=frame): self.assertEqual(frame,0)
''',
            'test_import.py': "raise ImportError('fixture import marker')\n",
            'test_setup.py': '''import unittest
class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): raise RuntimeError('fixture setup marker')
    def test_never(self): pass
''',
        }
        for name, source in sources.items():
            (root / 'tests' / name).write_text(source)
        declare_resources(root, {name: [] for name in audit.discover_modules(root)})
        return root

    def cli(self, root, directory, shards, *options):
        return subprocess.run([sys.executable, str(ROOT / 'tools/run_python_suite.py'), '--root', str(root),
            '--shards', str(shards), '--output-dir', str(directory), *options], text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=CLI_TIMEOUT_SECONDS)

    def test_cli_serial_and_parallel_preserve_totals_tracebacks_skips_and_modules(self):
        with tempfile.TemporaryDirectory(prefix='perf06-runner-') as folder:
            root = self.fixture(folder)
            records = []
            for shards in (1, 3):
                output = Path(folder) / str(shards)
                result = self.cli(root, output, shards)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('Ran 7 tests', result.stdout)
                self.assertIn('FAILED (failures=3, errors=3, skipped=1, expected failures=1)', result.stdout)
                for marker in ('fixture traceback marker', 'fixture error marker', 'fixture import marker',
                               'fixture setup marker', 'explicit fixture skip'):
                    self.assertIn(marker, result.stdout)
                record = json.loads((output / 'summary.json').read_text())
                self.assertEqual(set(record['modules']), {'test_pass', 'test_fail', 'test_import', 'test_setup'})
                self.assertTrue((output / 'isolation-audit.md').is_file())
                records.append(record)
            self.assertEqual(records[0]['tests'], records[1]['tests'])
            self.assertEqual(Counter(test for r in records[0]['shards'] for test in r['ids']),
                             Counter(test for r in records[1]['shards'] for test in r['ids']))
            serial = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests'],
                cwd=root, text=True, capture_output=True, timeout=CLI_TIMEOUT_SECONDS)
            self.assertIn('Ran 7 tests', serial.stderr)
            self.assertIn('FAILED (failures=3, errors=3, skipped=1, expected failures=1)', serial.stderr)

        with tempfile.TemporaryDirectory(prefix='python-groups-') as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            subprocess.run(['git', 'init', '-q', root], check=True)
            (root / 'tests/test_groups.py').write_text(
                'import unittest\nfrom python_suite_groups import perf_test\n'
                'class Mixed(unittest.TestCase):\n'
                '    def test_behavior(self): pass\n'
                '    @perf_test\n'
                '    def test_perf_failure(self): self.fail("perf-only marker")\n'
                'class Ordinary(unittest.TestCase):\n'
                '    @classmethod\n'
                '    def setUpClass(cls): raise RuntimeError("ordinary setup marker")\n'
                '    def test_behavior(self): pass\n')
            declare_resources(root, {'test_groups': []})
            default = self.cli(root, root / 'default', 1)
            self.assertEqual(default.returncode, 1, default.stdout)
            self.assertIn('ordinary setup marker', default.stdout)
            self.assertNotIn('perf-only marker', default.stdout)
            perf = self.cli(root, root / 'perf', 1, '--perf')
            self.assertEqual(perf.returncode, 1, perf.stdout)
            self.assertIn('Ran 1 tests', perf.stdout)
            self.assertIn('perf-only marker', perf.stdout)
            self.assertNotIn('ordinary setup marker', perf.stdout)
            record = json.loads((root / 'perf/summary.json').read_text())
            self.assertEqual(record['group'], 'perf')
            self.assertEqual([test for shard in record['shards'] for test in shard['ids']],
                             ['test_groups.Mixed.test_perf_failure'])

    def test_shipped_timings_are_read_only_and_learned_timings_override(self):
        with tempfile.TemporaryDirectory() as folder:
            shipped, learned = Path(folder) / 'shipped.json', Path(folder) / 'learned.json'
            shipped.write_text(json.dumps({'tests': [dict(id='test_a.T.test_a', run_s=2, setup_s=3),
                                                    dict(id='test_a.T.test_b', run_s=4, setup_s=1)]}))
            original = shipped.read_bytes()
            self.assertEqual(runner.load_timings(shipped), {'test_a': 10})
            learned.write_text(json.dumps({'modules': {'test_a': 7, 'test_new': 2}}))
            self.assertEqual(runner.load_timings(shipped, learned), {'test_a': 7, 'test_new': 2})
            runner.write_history(learned, dict(timestamp=1, modules={'test_a': 4}))
            self.assertEqual(runner.load_timings(shipped, learned), {'test_a': 4, 'test_new': 2})
            learned.write_text('[]')
            self.assertEqual(runner.load_timings(shipped, learned), {'test_a': 10})
            learned.write_text(json.dumps({'modules': {'test_a': -1, 'test_bad': 'invalid'}}))
            self.assertEqual(runner.load_timings(shipped, learned), {'test_a': 10})
            self.assertEqual(shipped.read_bytes(), original)

    def test_summary_handles_unexpected_success_and_no_failures(self):
        record = dict(tests=2, failures=[], errors=[], skipped=[], expected_failures=0,
                      unexpected_successes=['test_fixture'])
        stream = io.StringIO()
        self.assertFalse(runner.summary([record], 1, stream))
        self.assertIn('FAILED (unexpected successes=1)', stream.getvalue())
        record['unexpected_successes'] = []
        self.assertTrue(runner.summary([record], 1, io.StringIO()))


class IsolationAuditTests(unittest.TestCase):
    def test_whole_modules_and_shared_paths_remain_together(self):
        modules = ['a', 'b', 'c', 'd']
        rows = [dict(module=m, resources=r) for m, r in
                (('a', ['same']), ('b', ['same', 'transitive']), ('c', ['transitive']), ('d', []))]
        shards, _ = audit.balance(modules, dict(a=5,b=4,c=3,d=10), rows, 3)
        self.assertEqual(Counter(m for shard in shards for m in shard), Counter(modules))
        self.assertTrue(any(set(shard) == {'a','b','c'} for shard in shards))
        with self.assertRaises(ValueError):
            audit.balance(modules, {}, rows, 0)

    def test_real_audit_includes_indirect_proof_writers_and_fixed_scratch_paths(self):
        modules = audit.discover_modules(ROOT)
        rows = audit.audit(ROOT, modules)
        indexed = {r['module']: r for r in rows}
        self.assertIn('capacitor', indexed['test_godot_sidecars']['resources'])
        self.assertEqual(indexed['test_approved_content_manifest']['resources'], [])
        self.assertEqual(indexed['test_demo_clips']['input_group'], 'tools')
        shards, _ = audit.balance(modules, {}, rows, 4)
        owners = {name: i for i, shard in enumerate(shards) for name in shard}
        for resource in {resource for row in rows for resource in row['resources']}:
            self.assertEqual(len({owners[row['module']] for row in rows if resource in row['resources']}), 1)

    def test_discovery_honours_package_boundaries(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'tests/package').mkdir(parents=True)
            (root/'tests/ignored').mkdir()
            for name in ('tests/test_a.py','tests/package/test_b.py','tests/package/__init__.py',
                         'tests/ignored/test_c.py'):
                (root/name).touch()
            self.assertEqual(audit.discover_modules(root), ['package', 'package.test_b', 'test_a'])
            modules = audit.discover_modules(root)
            rows = [dict(module=name, resources=[]) for name in modules]
            shards, _ = audit.balance(modules, {}, rows, 3)
            self.assertTrue(any({'package', 'package.test_b'} <= set(shard) for shard in shards))
            tree = ast.parse('from . import test_b\n')
            self.assertEqual(audit.imported_test_modules(tree, 'package.test_a', 'package',
                {'package', 'package.test_a', 'package.test_b'}, 'tests'), ['package', 'package.test_b'])
            (root / 'tools').mkdir()
            (root / 'tools/helper.py').write_text('from package import test_b\n')
            self.assertEqual(audit.imported_test_modules(ast.parse('import helper\n'),
                'test_a', '', set(modules), 'tests', root), ['package', 'package.test_b'])
            rows[-1]['imports'] = ['package.test_b']
            shards, _ = audit.balance(modules, {}, rows, 3)
            self.assertTrue(any(set(shard) == set(modules) for shard in shards))


class InputGroupTests(unittest.TestCase):
    def groups(self):
        return {'default': dict(modules=['test_default'], triggers=[]),
                'rig': dict(modules=['test_rig'], triggers=['assets/units/**', 'tests/test_rig.py']),
                'tools': dict(modules=['test_tool'], triggers=['tools/**', 'tests/test_tool.py'])}

    def rows(self):
        return [dict(module=module, resources=[], imports=[])
                for entry in self.groups().values() for module in entry['modules']]

    def test_trigger_match_and_first_matching_file(self):
        files = ['assets/units/a/rig.json', 'assets/units/z/paint.png', 'tools/render.py']
        with patch.object(selection, 'changed_files', return_value=files):
            selected = selection.select_groups(ROOT, self.groups(), self.rows(), changed_since='HEAD')
        self.assertEqual(selected['selected_groups'], ['default', 'rig', 'tools'])
        self.assertEqual(selected['reasons']['rig'], 'changed file: assets/units/a/rig.json')
        self.assertEqual(selected['reasons']['tools'], 'changed file: tools/render.py')

    def test_no_matching_path_selects_only_default_and_explicit_all_is_unchanged(self):
        with patch.object(selection, 'changed_files', return_value=['README.md']) as changes:
            selected = selection.select_groups(ROOT, self.groups(), self.rows(), changed_since='HEAD')
            self.assertEqual(selected['selected_groups'], ['default'])
            for options in ({}, {'all_groups': True}, {'perf': True, 'changed_since': 'bad-ref'}):
                self.assertEqual(selection.select_groups(ROOT, self.groups(), self.rows(),
                                 **options)['selected_groups'], ['default', 'rig', 'tools'])
            changes.assert_called_once_with(ROOT, 'HEAD')

    def test_unresolvable_reference_and_change_list_failure_run_everything(self):
        with tempfile.TemporaryDirectory(prefix='suite-selection-ref-') as folder:
            subprocess.run(['git', 'init', '-q', folder], check=True)
            selected = selection.select_groups(folder, self.groups(), self.rows(), changed_since='absent-ref')
        self.assertEqual(selected['selected_groups'], ['default', 'rig', 'tools'])
        self.assertIn('cannot compute changes', selected['fallback'])
        for reason in selected['reasons'].values():
            self.assertIn('fallback:', reason)
        with patch.object(selection, 'changed_files', side_effect=ValueError('diff unavailable')):
            selected = selection.select_groups(ROOT, self.groups(), self.rows(), changed_since='HEAD')
        self.assertEqual(selected['selected_groups'], ['default', 'rig', 'tools'])
        self.assertEqual(selected['fallback'], 'diff unavailable')

    def test_git_changes_include_staged_unstaged_untracked_and_deleted_paths(self):
        # Only this disposable fixture repository is initialized/committed.
        with tempfile.TemporaryDirectory(prefix='suite-selection-git-') as folder:
            root = Path(folder)
            def git(*args):
                return subprocess.run(['git', *args], cwd=root, check=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            git('init', '-q')
            for name in ('staged.txt', 'unstaged.txt', 'deleted.txt'):
                (root / name).write_text('before')
            git('add', '.')
            git('-c', 'user.name=Suite fixture', '-c', 'user.email=suite@example.invalid',
                '-c', 'commit.gpgsign=false', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'fixture')
            (root / 'staged.txt').write_text('after')
            git('add', 'staged.txt')
            (root / 'unstaged.txt').write_text('after')
            (root / 'deleted.txt').unlink()
            (root / 'assets/units/a').mkdir(parents=True)
            untracked = 'assets/units/a/untracked é\npaint.png'
            (root / untracked).write_bytes(b'fixture')
            expected = sorted(['staged.txt', 'unstaged.txt', 'deleted.txt', untracked])
            self.assertEqual(selection.changed_files(root, 'HEAD'), expected)
            selected = selection.select_groups(root, self.groups(), self.rows(), changed_since='HEAD')
            self.assertEqual(selected['selected_groups'], ['default', 'rig'])
            self.assertEqual(selected['reasons']['rig'], 'changed file: ' + untracked)

    def test_group_inventory_must_be_complete_unique_and_have_trigger_paths(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'tools').mkdir()
            path = root / selection.GROUP_TABLE
            for groups, message in (({'default': dict(modules=[], triggers=[])}, 'missing='),
                ({'default': dict(modules=['test_default'], triggers=[]),
                  'rig': dict(modules=['test_default'], triggers=['assets/**'])}, 'belongs to both'),
                ({'default': dict(modules=['test_default'], triggers=[]),
                  'rig': dict(modules=['test_rig'], triggers=[])}, 'invalid modules/trigger')):
                path.write_text(json.dumps(dict(version=1, groups=groups)))
                with self.assertRaisesRegex(ValueError, message):
                    selection.load_groups(root, ['test_default', 'test_rig'])

    def test_import_dependencies_and_package_hooks_promote_the_complete_group(self):
        rows = self.rows()
        rows[0]['imports'] = ['test_rig']
        with patch.object(selection, 'changed_files', return_value=[]):
            selected = selection.select_groups(ROOT, self.groups(), rows, changed_since='HEAD')
        self.assertEqual(selected['selected_groups'], ['default', 'rig'])
        self.assertIn('test_default -> test_rig', selected['reasons']['rig'])
        groups = {'default': dict(modules=['package'], triggers=[]),
                  'rig': dict(modules=['package.test_rig'], triggers=['assets/**'])}
        with patch.object(selection, 'changed_files', return_value=[]):
            selected = selection.select_groups(ROOT, groups, [], changed_since='HEAD')
        self.assertEqual(selected['selected_groups'], ['default', 'rig'])

    def test_filtered_runner_audits_all_modules_and_guards_excluded_imports(self):
        with tempfile.TemporaryDirectory(prefix='suite-selection-worker-') as folder:
            root = Path(folder)
            (root / 'tests').mkdir()
            subprocess.run(['git', 'init', '-q', root], check=True)
            (root / 'tests/test_default.py').write_text(
                'import unittest\nclass Tests(unittest.TestCase):\n    def test_ok(self): pass\n')
            (root / 'tests/test_rig.py').write_text('raise RuntimeError("excluded rig imported")\n')
            declare_resources(root, {'test_default': [], 'test_rig': []})
            groups = self.groups()
            del groups['tools']
            (root / selection.GROUP_TABLE).write_text(json.dumps(dict(version=1, groups=groups)))
            options = ['--root', str(root), '--shards', '2', '--changed-since', 'HEAD',
                       '--output-dir', str(root / 'proof')]
            with patch.object(selection, 'changed_files', return_value=[]), redirect_stdout(io.StringIO()):
                self.assertEqual(runner.main(options), 0)
            record = json.loads((root / 'proof/summary.json').read_text())
            self.assertEqual(record['selection']['selected_groups'], ['default'])
            self.assertEqual(set(record['modules']), {'test_default'})
            audited = json.loads((root / 'proof/isolation-audit.json').read_text())
            self.assertEqual({r['module'] for r in audited}, {'test_default', 'test_rig'})
            # The excluded source remains in the guard inventory even when a
            # caught dynamic import escapes static scheduling declarations.
            (root / 'tests/test_default.py').write_text(
                'import unittest, importlib\nclass Tests(unittest.TestCase):\n'
                '    def test_ok(self):\n'
                '        try: importlib.import_module("".join(["test_", "rig"]))\n'
                '        except ImportError: pass\n')
            with patch.object(selection, 'changed_files', return_value=[]), \
                 redirect_stdout(io.StringIO()), patch('sys.stderr', new=io.StringIO()) as stderr:
                self.assertEqual(runner.main(options), 1)
            self.assertIn('IMPORT OWNERSHIP VIOLATION', stderr.getvalue())
            self.assertFalse((root / 'proof/summary.json').exists())

    def test_real_inventory_and_all_named_group_test_sources_have_triggers(self):
        resources = json.loads((ROOT / audit.RESOURCE_TABLE).read_text())['modules']
        groups, owners = selection.load_groups(ROOT, resources)
        self.assertEqual(set(owners), set(audit.discover_modules(ROOT)))
        for name, entry in groups.items():
            if name == 'default' or entry.get('on_demand'):
                continue
            for module in entry['modules']:
                path = 'tests/' + module.replace('.', '/') + '.py'
                self.assertTrue(any(fnmatch.fnmatchcase(path, p) for p in entry['triggers']), path)
        self.assertEqual(owners['test_art_identity_gate'], 'rig')
        self.assertEqual(owners['test_demo_clips'], 'tools')
        self.assertEqual(owners['test_python_suite_runner'], 'default')
        selected = selection.select_groups(ROOT, groups, [], all_groups=True)
        self.assertEqual(selected['selected_groups'], ['default'])
        demand = selection.select_groups(ROOT, groups, [], on_demand=['tools'])
        self.assertEqual(demand['selected_groups'], ['tools'])


class PoseShardTests(unittest.TestCase):
    def test_worker_default_override_and_disjoint_frame_inventory(self):
        with patch.dict(os.environ, {}, clear=True), patch.object(os, 'cpu_count', return_value=32):
            self.assertEqual(sweeps.worker_count(), 8)
        with patch.dict(os.environ, {'LABYRINTH_SWEEP_WORKERS': '2'}):
            self.assertEqual(sweeps.worker_count(), 2)
        with patch.dict(os.environ, {'LABYRINTH_SWEEP_WORKERS': '32'}):
            self.assertEqual(sweeps.worker_count(), 8)
        rows = list(range(17))
        self.assertEqual(sorted(x for chunk in sweeps.partition(rows, 8) for x in chunk), rows)
        sweeps.checked_frames('synthetic', [(x,) for x in rows], [(x,) for chunk in sweeps.partition(rows,8)
                                                                         for x in chunk], time.monotonic())
        with self.assertRaises(AssertionError):
            sweeps.checked_frames('synthetic', [(1,), (2,)], [(1,), (1,)], 0)

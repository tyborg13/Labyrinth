"""Director regressions: stale results, declared writers, skips and deadlines."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import python_suite_audit as audit
import run_python_suite as runner
from python_suite_selection import GROUP_TABLE
from tests.python_suite_guard_cases import check_import_ownership, check_source_encodings

CLI_TIMEOUT_SECONDS = 40
SLEEPING_SHARD_TIMEOUT_SECONDS = 0.5
TREE_SHARD_TIMEOUT_SECONDS = 2
CHILD_CLEANUP_GRACE_SECONDS = 3.5
HEARTBEAT_INTERVAL_SECONDS = 0.05
HEARTBEAT_OBSERVATION_SECONDS = 0.3
CHILD_EXIT_POLL_SECONDS = 0.01
PASS_SOURCE = 'import unittest\nclass Tests(unittest.TestCase):\n    def test_ok(self): pass\n'


def wait_for_child_exit(pid):
    """Observe cleanup completion instead of always sleeping its grace budget."""
    deadline = time.monotonic() + CHILD_CLEANUP_GRACE_SECONDS
    while True:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        if time.monotonic() >= deadline:
            raise AssertionError(f'Timed-out heartbeat producer {pid} is still alive')
        time.sleep(CHILD_EXIT_POLL_SECONDS)


class RunnerFeedbackTests(unittest.TestCase):
    def project(self, sources, declarations=None):
        temporary = tempfile.TemporaryDirectory(prefix='perf06-feedback-')
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        (root / 'tests').mkdir()
        subprocess.run(['git', 'init', '-q', root], check=True)
        for relative, source in sources.items():
            path = root / 'tests' / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(source) if isinstance(source, bytes) else path.write_text(source)
        modules = ({name: [] for name in audit.discover_modules(root)}
                   if declarations is None else declarations)
        table = root / audit.RESOURCE_TABLE
        table.parent.mkdir(parents=True)
        table.write_text(json.dumps(dict(version=1, modules=modules,
            resources={resource: resource for entry in modules.values()
                       for resource in (entry.get('resources', []) if isinstance(entry, dict) else entry)})))
        (root / GROUP_TABLE).write_text(json.dumps(dict(version=1, groups={
            'default': dict(modules=list(modules), triggers=[])})))
        return root

    def cli(self, root, *options):
        return subprocess.run([sys.executable, str(ROOT / 'tools/run_python_suite.py'),
            '--root', str(root), '--output-dir', str(root / 'proof'), '--shards', '2', *options],
            cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            timeout=CLI_TIMEOUT_SECONDS)

    def test_zero_exit_reusing_output_cannot_accept_stale_results(self):
        root = self.project({'test_a.py': PASS_SOURCE})
        self.assertEqual(self.cli(root).returncode, 0)
        self.assertTrue((root / 'proof/shard-1-result.json').exists())
        (root / 'tests/test_a.py').write_text(PASS_SOURCE.replace('pass', 'os._exit(0)').replace(
            'import unittest', 'import os, unittest'))
        result = self.cli(root)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('missing result', result.stdout)
        self.assertIn('shard-1-output.log', result.stdout)
        self.assertNotIn('OK', result.stdout)
        self.assertFalse((root / 'proof/shard-1-result.json').exists())
        self.assertFalse((root / 'proof/summary.json').exists())

    def test_each_shard_invocation_has_a_fresh_id(self):
        root = self.project({'test_a.py': PASS_SOURCE, 'test_b.py': PASS_SOURCE})
        identifiers = []
        for _ in range(2):
            result = self.cli(root)
            self.assertEqual(result.returncode, 0, result.stdout)
            identifiers.extend(json.loads(path.read_text())['invocation_id']
                               for path in (root / 'proof').glob('shard-*-result.json'))
        self.assertEqual(len(identifiers), 4)
        self.assertEqual(len(set(identifiers)), 4)

    def fake_result(self, contents):
        root = self.project({'test_a.py': PASS_SOURCE})
        output = root / 'proof'
        output.mkdir()
        def launch(command, **kwargs):
            path = command[command.index('--output') + 1]
            program = ('from pathlib import Path\n'
                       f'Path({path!r}).write_text({contents!r})\n'
                       'print("result validation fixture log", flush=True)\n')
            return subprocess.Popen([sys.executable, '-c', program], **kwargs)
        with patch.object(runner, 'spawn_owned_process', side_effect=launch):
            with self.assertRaises(RuntimeError) as raised:
                runner.run_shards(root, [['test_a']], output)
        self.assertIn('result validation fixture log', str(raised.exception))
        self.assertIn('shard-1-output.log', str(raised.exception))
        return str(raised.exception)

    def test_mismatched_invocation_is_rejected_with_its_log(self):
        self.assertIn('mismatched invocation id', self.fake_result('{"invocation_id":"stale"}'))

    def test_malformed_result_is_rejected_with_its_log(self):
        self.assertIn('Expecting', self.fake_result('not JSON'))

    def assert_skip_parity(self, sources, reason):
        root = self.project(sources)
        serial = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-v'],
            cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=CLI_TIMEOUT_SECONDS)
        parallel = self.cli(root)
        for result in (serial, parallel):
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn('Ran 3 tests', result.stdout)
            self.assertIn('OK (skipped=1)', result.stdout)
            self.assertIn(reason, result.stdout)
        record = json.loads((root / 'proof/summary.json').read_text())
        skipped = [item for shard in record['shards'] for item in shard['skipped']]
        self.assertEqual(len(skipped), 1)
        self.assertEqual(skipped[0][1], reason)

    def test_import_time_module_skip_preserves_serial_totals_and_reason(self):
        self.assert_skip_parity({'test_a.py': PASS_SOURCE, 'test_b.py': PASS_SOURCE,
            'test_skip.py': 'import unittest\nraise unittest.SkipTest("module import skip marker")\n'},
            'module import skip marker')

    def test_import_time_package_skip_preserves_serial_totals_and_reason(self):
        self.assert_skip_parity({'test_a.py': PASS_SOURCE, 'test_b.py': PASS_SOURCE,
            'package/__init__.py': 'import unittest\nraise unittest.SkipTest("package import skip marker")\n',
            'package/test_hidden.py': 'raise AssertionError("skipped package must not recurse")\n'},
            'package import skip marker')

    def test_unclassified_shared_writer_is_rejected_before_scheduling(self):
        source = PASS_SOURCE.replace('pass', 'open("shared.lock", "x").close()')
        root = self.project({'test_a.py': source, 'test_b.py': source}, declarations={})
        result = self.cli(root)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('Unclassified test module test_a', result.stdout)
        self.assertIn(audit.RESOURCE_TABLE, result.stdout)
        self.assertFalse((root / 'shared.lock').exists())
        self.assertFalse(list((root / 'proof').glob('shard-*')))

    def test_two_modules_one_exclusive_lock_are_scheduled_together(self):
        source = '''import time, unittest
from pathlib import Path
class Tests(unittest.TestCase):
    def test_exclusive(self):
        with open('shared.lock', 'x'):
            time.sleep(0.05)
        Path('shared.lock').unlink()
'''
        root = self.project({'test_a.py': source, 'test_b.py': source},
                            declarations={'test_a': ['shared.lock'], 'test_b': ['shared.lock']})
        serial = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests'],
            cwd=root, capture_output=True, text=True, timeout=CLI_TIMEOUT_SECONDS)
        self.assertEqual(serial.returncode, 0, serial.stderr)
        result = self.cli(root)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Ran 2 tests', result.stdout)
        plan = json.loads((root / 'proof/plan.json').read_text())
        self.assertTrue(any(shard == ['test_a', 'test_b'] for shard in plan['shards']))
        # Unlike a test-method writer, import-time code must never be reached
        # by another shard at all, even when its result would be filtered out.
        for exclusive in (False, True):
            with self.subTest(import_time_exclusive=exclusive):
                source = ('import os, unittest\nfrom pathlib import Path\n'
                          'root = Path(__file__).resolve().parents[1]\n'
                          'with (root / "imports.log").open("a") as stream:\n'
                          '    stream.write("imported writer\\n")\n')
                if exclusive:
                    source += ('descriptor = os.open(root / "shared.lock", os.O_CREAT | os.O_EXCL | os.O_WRONLY)\n'
                               'os.close(descriptor)\n')
                source += ('class Tests(unittest.TestCase):\n'
                           '    def test_only_one_import(self):\n'
                           '        self.assertEqual((root / "imports.log").read_text(), "imported writer\\n")\n')
                resources = ['imports.log', 'shared.lock'] if exclusive else ['imports.log']
                root = self.project({'test_a.py': source, 'test_b.py': PASS_SOURCE},
                                    declarations={'test_a': resources, 'test_b': []})
                result = self.cli(root)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertIn('Ran 2 tests', result.stdout)
                self.assertEqual((root / 'imports.log').read_text(), 'imported writer\n')
                plan = json.loads((root / 'proof/plan.json').read_text())
                self.assertEqual(sum(bool(shard) for shard in plan['shards']), 2)
        check_import_ownership(self)

    def test_missing_or_invalid_resource_table_fails_closed(self):
        root = self.project({'test_a.py': PASS_SOURCE})
        table = root / audit.RESOURCE_TABLE
        for contents in (None, '{"version":1,"resources":{},"modules":{"test_a":["unknown"]}}'):
            with self.subTest(contents=contents):
                if contents is None:
                    table.unlink()
                else:
                    table.write_text(contents)
                result = self.cli(root)
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('ISOLATION AUDIT FAILED', result.stdout)
                self.assertFalse((root / 'proof/summary.json').exists())
        check_source_encodings(self)

    def test_sleeping_worker_times_out_with_its_log(self):
        source = PASS_SOURCE.replace('import unittest', 'import time, unittest').replace(
            'pass', 'print("sleeping shard marker", flush=True); time.sleep(60)')
        root = self.project({'test_sleep.py': source})
        result = self.cli(root, '--shard-timeout', str(SLEEPING_SHARD_TIMEOUT_SECONDS))
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('timed out after 0.5s', result.stdout)
        self.assertIn('sleeping shard marker', result.stdout)
        self.assertFalse((root / 'proof/summary.json').exists())

    def test_deadline_terminates_children_and_detached_task_runner_children(self):
        for task_runner in (False, True):
            with self.subTest(task_runner=task_runner):
                root = self.project({'test_sleep.py': PASS_SOURCE}, declarations={'test_sleep': ['heartbeat']})
                heartbeat = root / 'heartbeat'
                child_pid = root / 'heartbeat.pid'
                program = ('import os, time\nfrom pathlib import Path\n'
                           f'Path({str(child_pid)!r}).write_text(str(os.getpid()))\nwhile True:\n'
                           f'    Path({str(heartbeat)!r}).write_text(str(time.monotonic()))\n'
                           f'    time.sleep({HEARTBEAT_INTERVAL_SECONDS})\n')
                command = [sys.executable, '-u', '-c', program]
                if task_runner:
                    command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'),
                               '--task-id', 'perf-06-timeout-fixture', '--stream', '--', *command]
                source = ('import subprocess, time, unittest\nclass Tests(unittest.TestCase):\n'
                          '    def test_sleep(self):\n'
                          f'        subprocess.Popen({command!r})\n'
                          '        time.sleep(60)\n')
                (root / 'tests/test_sleep.py').write_text(source)
                result = self.cli(root, '--shard-timeout', str(TREE_SHARD_TIMEOUT_SECONDS))
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn('timed out', result.stdout)
                self.assertTrue(heartbeat.exists(), result.stdout)
                wait_for_child_exit(int(child_pid.read_text()))
                stopped = heartbeat.read_bytes()
                time.sleep(HEARTBEAT_OBSERVATION_SECONDS)
                self.assertEqual(heartbeat.read_bytes(), stopped, 'timed-out child is still running')

    def test_shard_deadline_default_and_invalid_values(self):
        self.assertEqual(runner.DEFAULT_SHARD_TIMEOUT_SECONDS, 2400)
        root = self.project({'test_a.py': PASS_SOURCE})
        for value in ('0', '-1', 'nan', 'inf'):
            with self.subTest(value=value):
                result = self.cli(root, '--shard-timeout', value)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn('--shard-timeout must be finite and positive', result.stdout)
        for configured in (None, SLEEPING_SHARD_TIMEOUT_SECONDS, TREE_SHARD_TIMEOUT_SECONDS):
            with self.subTest(wait_timeout=configured):
                process = Mock()
                process.wait.return_value = 0
                def launch(command, **kwargs):
                    output = Path(command[command.index('--output') + 1])
                    invocation = command[command.index('--invocation-id') + 1]
                    output.write_text(json.dumps(dict(invocation_id=invocation, tests=0,
                        duration=0, modules={})))
                    return process
                options = ['--root', str(root), '--shards', '1', '--output-dir', str(root / 'wait-proof')]
                if configured is not None:
                    options += ['--shard-timeout', str(configured)]
                with patch.object(runner, 'spawn_owned_process', side_effect=launch), \
                     patch.object(runner, 'terminate_process_tree'), \
                     patch.object(runner, 'summary', return_value=True):
                    self.assertEqual(runner.main(options), 0)
                # Independent of both the production constant and its message.
                process.wait.assert_called_once_with(timeout=2400 if configured is None else configured)

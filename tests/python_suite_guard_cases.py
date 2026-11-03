"""CLI guard/encoding fixtures; no extra discovered TestCase identities."""
import json


PASS = 'import unittest\nclass Tests(unittest.TestCase):\n    def test_ok(self): pass\n'
GUARD_MESSAGE = ('test module test_b imports test module test_a, which runs in another shard; '
                 'declare the dependency in tools/python_suite_resources.json')
WRITER = '''import os, unittest
from pathlib import Path
root = Path(__file__).resolve().parents[1]
with (root / 'imports.log').open('a') as stream:
    stream.write(str(os.getpid()) + '\\n')
EXCLUSIVE
class Tests(unittest.TestCase):
    def test_once(self):
        self.assertEqual(len((root / 'imports.log').read_text().splitlines()), 1)
'''
LATIN1_IMPORT = '# coding: latin-1\ncaf\u00e9 = 1\nimport test_a\n'


def run_fixture(case, consumer, *, helper=None, declared=False, exclusive=True, expected=True):
    source = WRITER.replace('EXCLUSIVE',
        "os.close(os.open(root / 'shared.lock', os.O_CREAT | os.O_EXCL | os.O_WRONLY))" if exclusive else '')
    resources = ['imports.log', 'shared.lock'] if exclusive else ['imports.log']
    entry = {'resources': [], 'imports': ['test_a']} if declared else []
    sources = {'test_a.py': source, 'test_b.py': consumer}
    root = case.project(sources, declarations={'test_a': resources, 'test_b': entry})
    if helper:
        relative, content = helper
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content) if isinstance(content, bytes) else path.write_text(content)
    result = case.cli(root)
    events = root / 'imports.log'
    writes = events.read_text().splitlines() if events.exists() else []
    case.assertLessEqual(len(writes), 1, result.stdout)
    if expected:
        case.assertEqual(result.returncode, 0, result.stdout)
        case.assertIn('Ran 2 tests', result.stdout)
        case.assertEqual(len(writes), 1)
        plan = json.loads((root / 'proof/plan.json').read_text())
        case.assertTrue(any(shard == ['test_a', 'test_b'] for shard in plan['shards']), plan)
    else:
        case.assertEqual(result.returncode, 1, result.stdout)
        case.assertIn(GUARD_MESSAGE, result.stdout)
        case.assertIn('IMPORT OWNERSHIP VIOLATION:', result.stdout)
        case.assertIn('output.log', result.stdout)
        case.assertNotIn('FileExistsError', result.stdout)
        case.assertFalse((root / 'proof/summary.json').exists())
    return root, result


def check_import_ownership(case):
    # Production audit -> scheduler -> worker path. Removing the production
    # static dependency call must split this fixture and fail this assertion.
    run_fixture(case, 'import test_a\n' + PASS)
    run_fixture(case, 'import importlib.util\n'
                'assert importlib.util.find_spec("perf06_absent_fixture_dependency") is None\n' + PASS,
                declared=True)
    variants = {
        'literal dynamic': ('import importlib\nimportlib.import_module("test_a")\n' + PASS, None, False),
        'added path': ('from pathlib import Path\nimport sys\n'
            'sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "helpers"))\n'
            'import bridge\n' + PASS, ('helpers/bridge.py', 'import test_a\n'), False),
        'Latin-1': ((LATIN1_IMPORT + PASS).encode('latin-1'), None, True),
    }
    for name, (consumer, helper, found_statically) in variants.items():
        for exclusive in (False, True):
            for declared in (False, True):
                with case.subTest(import_form=name, exclusive=exclusive, declared=declared):
                    run_fixture(case, consumer, helper=helper, declared=declared,
                                exclusive=exclusive, expected=declared or found_statically)
    # Catching an ownership ImportError must still make the shard fail.
    caught = ('import importlib\ntry:\n    importlib.import_module("test_a")\n'
              'except ImportError:\n    pass\n' + PASS)
    run_fixture(case, caught, expected=False)
    caught_in_test = '''import importlib, unittest
class Tests(unittest.TestCase):
    def test_caught(self):
        try:
            importlib.import_module('test_a')
        except ImportError:
            pass
'''
    run_fixture(case, caught_in_test, expected=False)
    # Resolution must inspect a spec from another finder, rather than assuming
    # a module's import name identifies its file or using only PathFinder.
    alias = '''import importlib.util, sys
from pathlib import Path
class AliasFinder:
    def find_spec(self, fullname, path=None, target=None):
        if fullname == 'writer_alias':
            return importlib.util.spec_from_file_location(fullname, Path(__file__).with_name('test_a.py'))
sys.meta_path.insert(1, AliasFinder())
import writer_alias
'''
    run_fixture(case, alias + PASS, expected=False)
    # A missing lookup must not make importlib retry the remaining finders
    # outside the guard. This finder would resolve the alias on a second call.
    stateful = alias.replace('class AliasFinder:\n', 'class AliasFinder:\n    calls = 0\n').replace(
        "if fullname == 'writer_alias':\n", "if fullname == 'writer_alias':\n"
        '            self.calls += 1\n            if self.calls == 1:\n                return None\n')
    root = case.project({'test_a.py': WRITER.replace('EXCLUSIVE', ''), 'test_b.py': stateful + PASS},
                        declarations={'test_a': ['imports.log'], 'test_b': []})
    result = case.cli(root)
    case.assertEqual(result.returncode, 1, result.stdout)
    case.assertIn("No module named 'writer_alias'", result.stdout)
    events = root / 'imports.log'
    case.assertLessEqual(len(events.read_text().splitlines()) if events.exists() else 0, 1, result.stdout)


def check_source_encodings(case):
    # Both the audited module scanner and its recursive helper scanner must
    # preserve legal identifiers and imports in non-UTF-8 Python sources.
    run_fixture(case, (LATIN1_IMPORT + PASS).encode('latin-1'))
    run_fixture(case, 'from pathlib import Path\nimport sys\n'
                'sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))\n'
                'import bridge\n' + PASS,
                helper=('tools/bridge.py', LATIN1_IMPORT.encode('latin-1')))
    # Python 3.9 reports a NUL byte as ValueError rather than SyntaxError.
    for relative in ('tests/test_b.py', 'tools/bridge.py'):
        for source, reason in ((b'invalid Python syntax )\n', 'syntax'), (b'x = 1\x00\n', 'null bytes')):
            with case.subTest(parse_error=relative, reason=reason):
                root = case.project({'test_b.py': 'import bridge\n' + PASS})
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(source)
                result = case.cli(root)
                case.assertEqual(result.returncode, 1, result.stdout)
                case.assertIn('ISOLATION AUDIT FAILED', result.stdout)
                case.assertIn('Cannot parse Python source ' + str(path.resolve()), result.stdout)
                case.assertIn(reason, result.stdout.lower())
                case.assertFalse(list((root / 'proof').glob('shard-*')))
    for imports in ('test_a', ['unknown_test']):
        with case.subTest(invalid_imports=imports):
            root = case.project({'test_a.py': PASS, 'test_b.py': PASS}, declarations={
                'test_a': [], 'test_b': {'resources': [], 'imports': imports}})
            result = case.cli(root)
            case.assertEqual(result.returncode, 1, result.stdout)
            case.assertIn('Invalid import dependency declaration for test_b', result.stdout)

"""Exercise rr-14's actual assertion on disposable committed unit ranges."""
from contextlib import redirect_stdout
from io import StringIO
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import test_rr14_seer_identity as seer

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_FILE = 'assets/units/hoarfrost_seer_cutout/compiled_motion.json'
FIXTURE_BINDING_FILE = 'experiments/cutouts/hoarfrost_seer/rr10/proof/samples.json'
FIXTURE_INVENTORY = 'tests/rr14/seer_identity.json'
FIXTURE_ORIGINAL = b'approved Seer fixture\n'
FIXTURE_MUTATION = b'foreign Seer change inside rr-14\n'
FIXTURE_EVIDENCE = b'{"samples":[{"inputs":{"nested":"protected"}}], "inputs": {"compiler":"before"}, "ok":true}\n'
FIXTURE_REBOUND = FIXTURE_EVIDENCE.replace(b'"before"', b'"after"')
FIXTURE_CURRENT_BINDINGS = {'compiler': 'current fixture'}


class PreservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='int05-preservation-', dir=ROOT / 'tests')
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Preservation fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        self.write(FIXTURE_FILE, FIXTURE_ORIGINAL)
        self.write(FIXTURE_BINDING_FILE, FIXTURE_EVIDENCE)
        self.write(FIXTURE_INVENTORY, json.dumps({
            'files': [FIXTURE_FILE], 'binding_only_files': [FIXTURE_BINDING_FILE]}).encode())
        self.baseline = self.commit_fixture()
        self.write(FIXTURE_BINDING_FILE, FIXTURE_REBOUND)
        self.unit = self.commit_fixture()

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.project).decode().strip()

    def write(self, relative, raw):
        path = self.project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)

    def commit_fixture(self):
        # Only this disposable history; never commit the implementation worktree.
        self.git('add', '.')
        self.git('commit', '-qm', 'preservation fixture')
        return self.git('rev-parse', 'HEAD')

    def assert_range(self, end):
        # A separate TestCase with no active result makes subTest failures raise,
        # rather than being swallowed by this test's expected-failure context.
        case = seer.SeerIdentityTests()
        with patch.object(seer, 'PROJECT', self.project), \
                patch.object(seer, 'INVENTORY', self.project / FIXTURE_INVENTORY), \
                patch.object(seer, 'BASELINE_COMMIT', self.baseline), \
                patch.object(seer, 'UNIT_HEAD', end), redirect_stdout(StringIO()):
            case.test_approved_assets_layouts_compiled_motion_and_samples_are_byte_identical()

    def test_seer_change_inside_rr14_range_is_caught_despite_later_repairs(self):
        self.assert_range(self.unit)
        self.write(FIXTURE_FILE, FIXTURE_MUTATION)
        mutant = self.commit_fixture()
        self.assertEqual(self.git('diff', '--name-only'), '')
        with self.assertRaisesRegex(AssertionError, 'rr-14 changed protected Seer bytes'):
            self.assert_range(mutant)
        self.write(FIXTURE_FILE, FIXTURE_ORIGINAL)
        self.commit_fixture()
        with self.assertRaisesRegex(AssertionError, 'rr-14 changed protected Seer bytes'):
            self.assert_range(mutant)
        self.write(FIXTURE_FILE, FIXTURE_MUTATION)
        self.assert_range(self.unit)
        print('INT05 SEER RANGE MUTATION: PASS (in-range edit caught; later commits and working bytes ignored)')

    def test_listed_deletion_and_rename_are_caught(self):
        (self.project / FIXTURE_FILE).unlink()
        deleted = self.commit_fixture()
        with self.assertRaisesRegex(AssertionError, 'rr-14 changed protected Seer bytes'):
            self.assert_range(deleted)
        self.write(FIXTURE_FILE + '.renamed', FIXTURE_ORIGINAL)
        renamed = self.commit_fixture()
        with self.assertRaisesRegex(AssertionError, 'rr-14 changed protected Seer bytes'):
            self.assert_range(renamed)

    def test_binding_object_alone_may_change(self):
        self.assertNotEqual(FIXTURE_EVIDENCE, FIXTURE_REBOUND)
        self.assertEqual(seer.without_bindings(FIXTURE_EVIDENCE), seer.without_bindings(FIXTURE_REBOUND))
        self.assert_range(self.unit)
        self.write(FIXTURE_BINDING_FILE, FIXTURE_REBOUND.replace(b'"protected"', b'"mutated"'))
        mutant = self.commit_fixture()
        self.write(FIXTURE_BINDING_FILE, FIXTURE_EVIDENCE)
        with self.assertRaises(AssertionError):
            self.assert_range(mutant)
        print('INT05 BINDING MUTATION: PASS (top-level inputs allowed; nested payload change rejected)')

    def test_non_binding_serialization_bytes_remain_protected(self):
        self.write(FIXTURE_BINDING_FILE, FIXTURE_REBOUND.replace(b'"ok":true', b'"ok": true'))
        mutant = self.commit_fixture()
        with self.assertRaises(AssertionError):
            self.assert_range(mutant)

    def test_missing_or_non_object_bindings_are_rejected(self):
        for raw in (b'{"samples":{"inputs":{}}}', b'{"inputs":[]}', b'[]'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                seer.without_bindings(raw)

    def test_rebinding_uses_historical_payload_after_hash_pin_removal(self):
        spec = importlib.util.spec_from_file_location('int05_refresh_bindings', ROOT / 'tests/rr14/refresh_bindings.py')
        refresh = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(refresh)
        with patch.object(refresh, 'PROJECT', self.project), \
                patch.object(refresh, 'INVENTORY', self.project / FIXTURE_INVENTORY), \
                patch.object(refresh, 'BASELINE_COMMIT', self.baseline), \
                patch.object(refresh, 'bindings', return_value=FIXTURE_CURRENT_BINDINGS), \
                redirect_stdout(StringIO()):
            # This helper's lexical replacement expects inputs before payload.
            raw = b'{"inputs":{"compiler":"before"},"samples":[],"ok":true}\n'
            self.write(FIXTURE_BINDING_FILE, raw)
            baseline = self.commit_fixture()
            with patch.object(refresh, 'BASELINE_COMMIT', baseline):
                refresh.main()
                rebound = (self.project / FIXTURE_BINDING_FILE).read_bytes()
                self.assertEqual(json.loads(rebound)['inputs'], FIXTURE_CURRENT_BINDINGS)
                self.assertEqual(seer.without_bindings(raw), seer.without_bindings(rebound))
                damaged = rebound.replace(b'"ok":true', b'"ok":false')
                self.write(FIXTURE_BINDING_FILE, damaged)
                with self.assertRaisesRegex(ValueError, 'Refusing changed evidence payload'):
                    refresh.main()
                self.assertEqual((self.project / FIXTURE_BINDING_FILE).read_bytes(), damaged)


if __name__ == '__main__':
    unittest.main()

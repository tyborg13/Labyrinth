"""Output import exclusions must not hide current or newly added res:// inputs."""
from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import output_gdignore

RESOURCE_PREFIX = "res://" + "output/"


class OutputGdignoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.files = []

    def source(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        self.files.append(name)

    def folder(self, name):
        path = self.root / "output" / name
        path.mkdir(parents=True)
        return path

    def reconcile(self, check=False):
        with patch.object(output_gdignore, "git_files", return_value=self.files), redirect_stdout(io.StringIO()):
            return output_gdignore.reconcile(self.root, check=check)

    def test_preserves_resource_inputs_and_dynamic_relative_dependencies(self):
        for name, reference in (("contextual-animation-polish", "creatures/cases/"), ("rr-01", "before")):
            folder = self.folder(name)
            (folder / "textures").mkdir()
            self.source(f"tests/{name}.gd", f'var source = "{RESOURCE_PREFIX}{name}/{reference}" + character\n')
        self.assertEqual(0, self.reconcile())
        self.assertEqual([], list(self.root.rglob(".gdignore")))

    def test_marks_tracked_and_local_output_folders_idempotently(self):
        for name in ("tracked", "new-local-captures"):
            folder = self.folder(name)
            (folder / "proof.png").write_bytes(b"existing artifact")
        self.files.append("output/tracked/proof.png")
        self.assertEqual(1, self.reconcile(check=True))
        self.assertEqual([], list(self.root.rglob(".gdignore")))
        self.assertEqual(0, self.reconcile())
        self.assertEqual(0, self.reconcile(check=True))
        self.assertEqual(0, self.reconcile())
        for name in ("tracked", "new-local-captures"):
            self.assertTrue((self.root / "output" / name / ".gdignore").is_file())
            self.assertEqual(b"existing artifact", (self.root / "output" / name / "proof.png").read_bytes())

    def test_audited_output_sink_does_not_exempt_a_new_consumer(self):
        folder = self.folder("feel-01")
        self.source("tests/suites/combat_feel_suite.gd", f'const PROOF_DIR = "{RESOURCE_PREFIX}feel-01"\n')
        self.assertEqual({}, output_gdignore.scan_references(self.root, self.files))
        self.source("tools/new_consumer.gd", f'var image = load("{RESOURCE_PREFIX}feel-01/frame.png")\n')
        self.assertEqual(0, self.reconcile())
        self.assertFalse((folder / ".gdignore").exists())

    def test_new_reference_to_ignored_folder_fails_without_deleting_marker(self):
        folder = self.folder("new-input")
        marker = folder / ".gdignore"
        marker.write_text("existing marker\n")
        untouched = self.folder("other-output")
        self.source("tests/new_probe.gd", f'var image = load("{RESOURCE_PREFIX}new-input/image.png")\n')
        self.assertEqual(1, self.reconcile())
        self.assertEqual("existing marker\n", marker.read_text())
        self.assertFalse((untouched / ".gdignore").exists())

    def test_existing_custom_marker_is_preserved(self):
        marker = self.folder("custom") / ".gdignore"
        marker.write_text("authored marker\n")
        self.assertEqual(0, self.reconcile())
        self.assertEqual("authored marker\n", marker.read_text())

    def test_dynamic_top_level_resource_path_requires_review(self):
        for reference in ("", "%s/image.png", "{folder}/image.png"):
            with self.subTest(reference=reference):
                self.source("tools/dynamic.gd", f'var path = "{RESOURCE_PREFIX}{reference}"\n')
                with self.assertRaisesRegex(ValueError, "Dynamic output root needs review"):
                    output_gdignore.scan_references(self.root, self.files)

    def test_output_proposal_is_not_a_live_resource_consumer(self):
        self.source("output/proposals/cards.json", '{"art_path": "' + RESOURCE_PREFIX + 'proposals/card.png"}')
        self.assertEqual(0, self.reconcile())
        self.assertTrue((self.root / "output/proposals/.gdignore").is_file())

    def test_symlinked_output_directory_is_not_written(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.root / "output").mkdir()
        (self.root / "output/link").symlink_to(outside, target_is_directory=True)
        self.assertEqual(1, self.reconcile())
        self.assertFalse((outside / ".gdignore").exists())

    def test_symlinked_output_root_is_rejected_before_scanning(self):
        with tempfile.TemporaryDirectory() as outside:
            targets = (self.root / "inside", Path(outside) / "external", Path(outside) / "missing")
            for target in targets:
                with self.subTest(target=target.name):
                    if target.name != "missing":
                        (target / "captures").mkdir(parents=True)
                    output = self.root / "output"
                    output.symlink_to(target, target_is_directory=True)
                    for check in (False, True):
                        with patch.object(output_gdignore, "git_files", side_effect=AssertionError("Unsafe root must not be scanned")), redirect_stdout(io.StringIO()):
                            self.assertEqual(1, output_gdignore.reconcile(self.root, check=check))
                    self.assertFalse((target / "captures/.gdignore").exists())
                    output.unlink()

    def test_output_resolving_outside_repo_is_rejected_before_scanning(self):
        self.folder("captures")
        original_resolve = Path.resolve
        outside = self.root.parent / "outside-output"

        def resolve(path):
            return outside if path == self.root / "output" else original_resolve(path)

        # Also cover canonical path escapes that are not reported as symlinks,
        # such as Windows junctions, without needing platform-specific fixtures.
        with patch.object(Path, "resolve", resolve), patch.object(output_gdignore, "git_files", side_effect=AssertionError("Unsafe root must not be scanned")), redirect_stdout(io.StringIO()):
            for check in (False, True):
                self.assertEqual(1, output_gdignore.reconcile(self.root, check=check))
        self.assertFalse((self.root / "output/captures/.gdignore").exists())


if __name__ == "__main__":
    unittest.main()

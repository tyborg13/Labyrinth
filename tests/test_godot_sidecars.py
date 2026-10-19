"""Tracked Godot resources keep their import settings and stable UIDs."""
from __future__ import annotations

from contextlib import redirect_stdout
import io
from pathlib import Path, PurePosixPath
import subprocess
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
# Existing tracked import types, plus the standard types named by this guard's
# contract. Keep this seed even if the last sidecar of a type is removed.
IMPORTABLE_SUFFIXES = {
    ".csv", ".glb", ".gltf", ".jpeg", ".jpg", ".mp3", ".ogg", ".otf",
    ".png", ".svg", ".ttf", ".wav", ".webp", ".woff", ".woff2",
}
UID_SUFFIXES = {".gd", ".gdshader", ".gdshaderinc"}
SIDECAR_SUFFIXES = {".import", ".uid"}
REPAIR_HINT = (
    "Run godot --headless --import (through tools/godot_task_runner.py), "
    "commit the .import/.uid sidecars with their sources, and remove stale sidecars."
)


def git_files(root: Path) -> set[str]:
    def inventory(selection):
        result = subprocess.run(
            ["git", "ls-files", selection, "-z"], cwd=root,
            check=True, capture_output=True,
        )
        return set(result.stdout.decode("utf-8", errors="surrogateescape").split("\0")) - {""}

    # Include unstaged deletions in the snapshot being checked, so cleaning up
    # an orphan can pass before staging; deleting only a sidecar still fails.
    return inventory("--cached") - inventory("--deleted")


def git_ignored_paths(root: Path, paths: list[str]) -> set[str]:
    if not paths:
        return set()
    result = subprocess.run(
        ["git", "check-ignore", "-z", "--stdin"], cwd=root,
        input=("\0".join(paths) + "\0").encode("utf-8", errors="surrogateescape"),
        capture_output=True,
    )
    # Exit 1 means none matched; other failures must not silently exempt files.
    if result.returncode not in (0, 1):
        result.check_returncode()
    return set(result.stdout.decode("utf-8", errors="surrogateescape").split("\0")) - {""}


def assert_sidecars_versioned(files: set[str], *, root: Path | None = None) -> None:
    # Only tracked markers exempt tracked resources, so a local scratch marker
    # cannot hide missing sidecars from this guard on a fresh checkout.
    ignored = {PurePosixPath(name).parent for name in files
               if PurePosixPath(name).name == ".gdignore"}
    importable = IMPORTABLE_SUFFIXES | {
        PurePosixPath(name.removesuffix(".import")).suffix.lower()
        for name in files if name.endswith(".import")
    }
    missing: list[str] = []
    stale: list[str] = []
    for name in sorted(files):
        path = PurePosixPath(name)
        if path.suffix in SIDECAR_SUFFIXES:
            if str(path.with_suffix("")) not in files:
                stale.append(name)
            continue
        if any(parent in ignored for parent in path.parents):
            continue
        suffix = path.suffix.lower()
        sidecar = ".uid" if suffix in UID_SUFFIXES else ".import" if suffix in importable else None
        if sidecar and name + sidecar not in files:
            missing.append(name + sidecar)
    if root is not None:
        exempt = git_ignored_paths(root, missing)
        print(f"GODOT SIDECARS: gitignored exemptions = {len(exempt)}")
        missing = [name for name in missing if name not in exempt]
    problems: list[str] = []
    if missing:
        problems.append(f"Missing tracked Godot sidecars ({len(missing)}):\n" + "\n".join(missing))
    if stale:
        problems.append(f"Stale tracked Godot sidecars ({len(stale)}):\n" + "\n".join(stale))
    if problems:
        raise AssertionError("\n\n".join(problems + [REPAIR_HINT]))


class GodotSidecarRepositoryTests(unittest.TestCase):
    def test_tracked_sources_have_sidecars_and_sidecars_have_sources(self):
        assert_sidecars_versioned(git_files(ROOT), root=ROOT)


class GodotSidecarGuardTests(unittest.TestCase):
    def setUp(self):
        self.image = "assets/guard sprite.png"
        self.script = "scripts/guard.gd"
        self.ignored_folder = "experiments/cutouts/guard_fixture/runtime_v1/assets/"
        self.files = {self.image, self.image + ".import", self.script, self.script + ".uid"}

    def rejection(self, files, expected_path):
        with self.assertRaises(AssertionError) as raised:
            assert_sidecars_versioned(files)
        message = str(raised.exception)
        self.assertIn(expected_path, message.splitlines())
        self.assertIn(REPAIR_HINT, message)
        return message

    def test_complete_tracked_fixture_passes(self):
        assert_sidecars_versioned(self.files)

    def test_dropping_tracked_import_fails(self):
        missing = self.image + ".import"
        message = self.rejection(self.files - {missing}, missing)
        self.assertIn("Missing tracked Godot sidecars (1):", message)

    def test_dropping_tracked_uid_fails(self):
        missing = self.script + ".uid"
        message = self.rejection(self.files - {missing}, missing)
        self.assertIn("Missing tracked Godot sidecars (1):", message)

    def test_adding_stale_sidecar_fails(self):
        for stale in ("assets/deleted.png.import", "scripts/deleted.gd.uid"):
            with self.subTest(stale=stale):
                message = self.rejection(self.files | {stale}, stale)
                self.assertIn("Stale tracked Godot sidecars (1):", message)

    def test_missing_sidecar_in_gitignored_folder_is_exempt(self):
        for source in (self.ignored_folder + "front_canvas.png", self.ignored_folder + "motion.gd"):
            with self.subTest(source=source), redirect_stdout(io.StringIO()) as output:
                assert_sidecars_versioned(self.files | {source}, root=ROOT)
                self.assertEqual("GODOT SIDECARS: gitignored exemptions = 1\n", output.getvalue())

    def test_gitignore_exempts_only_matching_sidecar_paths(self):
        files = {self.image, self.script}
        with patch(f"{__name__}.git_ignored_paths", return_value={self.image + ".import"}) as ignored:
            with redirect_stdout(io.StringIO()) as output, self.assertRaises(AssertionError) as raised:
                assert_sidecars_versioned(files, root=ROOT)
        ignored.assert_called_once_with(ROOT, [self.image + ".import", self.script + ".uid"])
        self.assertEqual("GODOT SIDECARS: gitignored exemptions = 1\n", output.getvalue())
        self.assertIn(self.script + ".uid", str(raised.exception).splitlines())
        self.assertNotIn(self.image + ".import", str(raised.exception).splitlines())

    def test_gitignored_folder_does_not_exempt_stale_sidecars(self):
        stale = self.ignored_folder + "deleted.png.import"
        with redirect_stdout(io.StringIO()), self.assertRaises(AssertionError) as raised:
            assert_sidecars_versioned({stale}, root=ROOT)
        self.assertIn(stale, str(raised.exception).splitlines())

    def test_importable_types_require_sidecars_even_without_existing_examples(self):
        for suffix in sorted(IMPORTABLE_SUFFIXES | {".PNG"}):
            with self.subTest(suffix=suffix):
                source = "assets/new" + suffix
                self.rejection({source}, source + ".import")

    def test_additional_importable_type_is_learned_from_tracked_sidecars(self):
        source = "assets/new.custom"
        self.rejection({source, "assets/existing.custom", "assets/existing.custom.import"},
                       source + ".import")

    def test_all_script_and_shader_types_require_uids(self):
        for suffix in sorted(UID_SUFFIXES):
            with self.subTest(suffix=suffix):
                source = "scripts/new" + suffix
                self.rejection({source}, source + ".uid")

    def test_gdignore_exempts_its_folder_and_descendants_only(self):
        files = self.files | {
            "scratch/.gdignore", "scratch/image.png", "scratch/nested/shader.gdshader",
            "scratch/nested/motion.gd", "scratch/nested/lighting.gdshaderinc",
        }
        assert_sidecars_versioned(files)
        self.rejection(files | {"scratch-other/image.png"}, "scratch-other/image.png.import")
        assert_sidecars_versioned({".gdignore", "image.png", "nested/motion.gd"})

    def test_ignored_folder_does_not_exempt_stale_sidecars(self):
        stale = "scratch/deleted.png.import"
        self.rejection({"scratch/.gdignore", stale}, stale)

    def test_reports_all_missing_and_stale_paths(self):
        stale = "scripts/deleted.gd.uid"
        message = self.rejection({self.image, self.script, stale}, stale)
        self.assertIn(self.image + ".import", message.splitlines())
        self.assertIn(self.script + ".uid", message.splitlines())
        self.assertIn("Missing tracked Godot sidecars (2):", message)

    def test_other_source_types_do_not_require_sidecars(self):
        assert_sidecars_versioned({"scenes/main.tscn", "data/cards.json", "README.md"})

    def test_git_inventory_preserves_spaces_and_newlines(self):
        names = {"assets/guard sprite.png", "assets/guard\nsprite.png.import"}
        result = subprocess.CompletedProcess([], 0, "\0".join(sorted(names)).encode() + b"\0")
        deleted = subprocess.CompletedProcess([], 0, b"")
        with patch.object(subprocess, "run", side_effect=[result, deleted]) as run:
            self.assertEqual(names, git_files(ROOT))
        self.assertEqual(2, run.call_count)
        self.assertEqual(["git", "ls-files", "--cached", "-z"], run.call_args_list[0].args[0])
        self.assertEqual(["git", "ls-files", "--deleted", "-z"], run.call_args_list[1].args[0])

    def test_git_inventory_removes_unstaged_deletions(self):
        for deleted_path in (self.image, self.image + ".import"):
            with self.subTest(deleted_path=deleted_path):
                tracked = subprocess.CompletedProcess([], 0, "\0".join(sorted(self.files)).encode() + b"\0")
                deleted = subprocess.CompletedProcess([], 0, deleted_path.encode() + b"\0")
                with patch.object(subprocess, "run", side_effect=[tracked, deleted]):
                    files = git_files(ROOT)
                self.assertEqual(self.files - {deleted_path}, files)
                expected = self.image + ".import"
                self.rejection(files, expected)

    def test_git_check_ignore_preserves_spaces_and_newlines(self):
        paths = ["assets/guard sprite.png.import", "assets/guard\nsprite.png.import"]
        result = subprocess.CompletedProcess([], 0, paths[0].encode() + b"\0")
        with patch.object(subprocess, "run", return_value=result) as run:
            self.assertEqual({paths[0]}, git_ignored_paths(ROOT, paths))
        run.assert_called_once_with(["git", "check-ignore", "-z", "--stdin"], cwd=ROOT,
                                    input=("\0".join(paths) + "\0").encode(), capture_output=True)

    def test_git_check_ignore_accepts_no_matches_and_rejects_errors(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"")):
            self.assertEqual(set(), git_ignored_paths(ROOT, [self.image + ".import"]))
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 128, b"")):
            with self.assertRaises(subprocess.CalledProcessError):
                git_ignored_paths(ROOT, [self.image + ".import"])


if __name__ == "__main__":
    unittest.main()

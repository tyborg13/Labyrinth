from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
FIXTURES = REPO_ROOT / "tests/fixtures/ui_identity"
LINT_PATH = REPO_ROOT / "tools/ui_identity_lint.py"
CLI_TIMEOUT_SECONDS = 60  # Test-only budget; the lint does not launch the game.
SYNTHETIC_FILE = "scripts/ui_identity_added_violation.gd"  # Test-only non-helper path.

spec = importlib.util.spec_from_file_location("ui_identity_lint", LINT_PATH)
assert spec is not None and spec.loader is not None
lint = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = lint
spec.loader.exec_module(lint)


def _fixture(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def _marked_sites(source: str, path: str) -> list[dict]:
    return [{"file": path, "line": line, "rule": match.group(1)}
            for line, text in enumerate(source.splitlines(), 1)
            for match in re.finditer(r"# SITE_(R[1-6])\b", text)]


def _cli(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(LINT_PATH), *args, "--root", str(root)],
                          cwd=REPO_ROOT, text=True, capture_output=True, timeout=CLI_TIMEOUT_SECONDS)


def _copy_policy(root: Path) -> None:
    (root / lint.BASELINE_PATH).parent.mkdir(parents=True, exist_ok=True)
    for relative in (lint.BASELINE_PATH, lint.EXCEPTIONS_PATH):
        shutil.copyfile(REPO_ROOT / relative, root / relative)


class UiIdentityRuleTests(unittest.TestCase):
    def assert_fixture(self, name: str, rule: str, count: int) -> dict:
        path = "scripts/" + name
        source = _fixture(name)
        result = lint.scan_source(path, source)
        expected = _marked_sites(source, path)
        self.assertEqual(len(expected), count)
        self.assertEqual({site["rule"] for site in expected}, {rule})
        self.assertEqual(result["sites"], expected)
        return result

    def test_r1_raw_boxes(self) -> None:
        self.assert_fixture("boxes.gd", "R1", 3)

    def test_r2_colour_literals(self) -> None:
        self.assert_fixture("colours.gd", "R2", 17)

    def test_r3_only_outline_argument_counts(self) -> None:
        self.assert_fixture("outlines.gd", "R3", 3)

    def test_r4_bare_bars(self) -> None:
        self.assert_fixture("bars.gd", "R4", 2)

    def test_r5_font_loading_variation_and_fallback(self) -> None:
        self.assert_fixture("fonts.gd", "R5", 5)

    def test_r6_caption_argument_positions_and_assignments(self) -> None:
        self.assert_fixture("captions.gd", "R6", 12)

    def test_comments_strings_and_neutral_modulates_are_excluded(self) -> None:
        self.assertEqual(lint.scan_source("scripts/exclusions.gd", _fixture("exclusions.gd"))["sites"], [])

    def test_neutral_alpha_can_contain_a_separately_counted_literal(self) -> None:
        source = "var neutral = Color(1, 1, 1, Color(0.1, 0.2, 0.3).a)"
        self.assertEqual(lint.scan_source("scripts/example.gd", source)["sites"],
                         [{"file": "scripts/example.gd", "line": 1, "rule": "R2"}])

    def test_allowlists_are_exact_paths_and_do_not_hide_other_rules(self) -> None:
        fixtures = {"R1": "boxes.gd", "R2": "colours.gd", "R3": "outlines.gd",
                    "R4": "bars.gd", "R5": "fonts.gd"}
        for rule, paths in lint.RULE_ALLOWLISTS.items():
            for path in sorted(paths):
                with self.subTest(rule=rule, path=path):
                    self.assertEqual(lint.scan_source(path, _fixture(fixtures[rule]))["sites"], [])
                    source = "var font_size = 12"
                    self.assertEqual(lint.scan_source(path, source)["sites"][0]["rule"], "R6")
                    nested = "scripts/nested/" + Path(path).name
                    self.assertTrue(lint.scan_source(nested, _fixture(fixtures[rule]))["sites"])

    def test_palette_matches_are_separate_information_not_extra_sites(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "scripts/ui_palette.gd").write_text(_fixture("palette.gd"), encoding="utf-8")
            tokens = lint.palette_tokens(root)
            self.assertEqual(tokens, {"aabbccff": ["SHORT"], "c9a25eff": ["ALSO_GOLD", "GOLD"]})
            result = lint.scan_source("scripts/colours.gd", _fixture("colours.gd"), tokens)
            self.assertEqual(len(result["sites"]), 17)
            self.assertEqual(len(result["palette_matches"]), 6)
            for match in result["palette_matches"]:
                if match["hex"] == "c9a25eff":
                    self.assertEqual(match["tokens"], ["ALSO_GOLD", "GOLD"])

    def test_unfinished_calls_do_not_stop_later_sites(self) -> None:
        result = lint.scan_source("scripts/incomplete.gd", "Color(\nvar box = StyleBoxFlat.new()\n")
        self.assertEqual(result["sites"], [{"file": "scripts/incomplete.gd", "line": 2, "rule": "R1"}])

    def test_two_calls_on_one_line_remain_distinct_sites(self) -> None:
        result = lint.scan_source("scripts/two.gd", "var boxes = [StyleBoxFlat.new(), StyleBoxFlat.new()]")
        self.assertEqual(len(result["sites"]), 2)
        self.assertEqual([site["line"] for site in result["sites"]], [1, 1])

    def test_r1_serialized_resources_count_definitions_only(self) -> None:
        for path, fixture, line in (("scenes/raw_box.tscn", "raw_box.tscn", 4),
                                    ("themes/raw_box.tres", "raw_box.tres", 1)):
            with self.subTest(path=path):
                self.assertEqual(lint.scan_source(path, _fixture(fixture))["sites"],
                                 [{"file": path, "line": line, "rule": "R1"}])
        excluded = '''; [sub_resource type="StyleBoxFlat" id="comment"]
[ext_resource type="StyleBoxFlat" path="res://themes/raw_box.tres" id="reference"]
[sub_resource type="Gradient" id='type="StyleBoxFlat"']
[node name="Label" type="Label"]
text = """
[sub_resource type="StyleBoxFlat" id="inside_string"]
"""
'''
        self.assertEqual(lint.scan_source("scenes/excluded.tscn", excluded)["sites"], [])


class UiIdentityRatchetTests(unittest.TestCase):
    def test_check_passes_on_repository_tree(self) -> None:
        result = _cli(REPO_ROOT, "check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS: UI identity lint", result.stdout)

    def test_check_fails_on_temporary_copy_with_new_raw_box(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("scripts", "scenes", "themes"):
                shutil.copytree(REPO_ROOT / name, root / name)
            _copy_policy(root)
            (root / SYNTHETIC_FILE).write_text("extends Control\nvar box = StyleBoxFlat.new()\n", encoding="utf-8")
            result = _cli(root, "check")
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn(f"{SYNTHETIC_FILE}:2: R1 raw box", result.stdout)
            self.assertIn("use UiSkin / UiComponentSurface.draw_plate", result.stdout)

    def test_check_reports_insertions_before_existing_sites_and_all_rule_helpers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            path = root / "scripts/example.gd"
            original = "\n".join(_fixture(name) for name in
                                 ("boxes.gd", "colours.gd", "outlines.gd", "bars.gd", "fonts.gd", "captions.gd"))
            path.write_text(original, encoding="utf-8")
            baseline = _cli(root, "--write-baseline")
            self.assertEqual(baseline.returncode, 0, baseline.stderr)
            (root / lint.EXCEPTIONS_PATH).write_text("[]\n", encoding="utf-8")
            path.write_text("StyleBoxFlat.new()\n" + original + "\n" + original, encoding="utf-8")
            result = _cli(root, "check")
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("scripts/example.gd:1: R1 raw box", result.stdout)
            for rule, (_, helper) in lint.RULES.items():
                self.assertIn(f": {rule} ", result.stdout)
                self.assertIn("use " + helper, result.stdout)

    def test_write_baseline_refuses_existing_unless_forced(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = _cli(root, "--write-baseline")
            self.assertEqual(first.returncode, 0, first.stderr)
            path = root / lint.BASELINE_PATH
            contents = path.read_bytes()
            refused = _cli(root, "--write-baseline")
            self.assertEqual(refused.returncode, 2)
            self.assertIn("baseline exists", refused.stderr)
            self.assertEqual(path.read_bytes(), contents)
            forced = _cli(root, "--write-baseline", "--force")
            self.assertEqual(forced.returncode, 0, forced.stderr)
            self.assertEqual(path.read_bytes(), contents)

    def test_tighten_lowers_only_and_removes_zero_entries(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "scripts/existing.gd").write_text("StyleBoxFlat.new()\n" * 3, encoding="utf-8")
            (root / "scripts/added.gd").write_text("StyleBoxFlat.new()\n", encoding="utf-8")
            before = {"scripts/existing.gd": {"R1": 2, "R2": 4, "R6": 0},
                      "scripts/removed.gd": {"R1": 1}}
            lint.write_baseline(root / lint.BASELINE_PATH, before)
            result = _cli(root, "--tighten")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(lint.read_baseline(root / lint.BASELINE_PATH),
                             {"scripts/existing.gd": {"R1": 2}})
            (root / "scripts/existing.gd").write_text("StyleBoxFlat.new()\n", encoding="utf-8")
            result = _cli(root, "--tighten")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(lint.read_baseline(root / lint.BASELINE_PATH),
                             {"scripts/existing.gd": {"R1": 1}})

    def test_exception_counts_are_additive_and_require_a_reason(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            path = root / "scripts/example.gd"
            path.write_text("StyleBoxFlat.new()\n", encoding="utf-8")
            self.assertEqual(_cli(root, "--write-baseline").returncode, 0)
            entry = {"file": "scripts/example.gd", "rule": "R1", "count": 1, "reason": "Test-only director exception"}
            (root / lint.EXCEPTIONS_PATH).write_text(json.dumps([entry]), encoding="utf-8")
            path.write_text("StyleBoxFlat.new()\n" * 2, encoding="utf-8")
            self.assertEqual(_cli(root, "check").returncode, 0)
            path.write_text("StyleBoxFlat.new()\n" * 3, encoding="utf-8")
            self.assertEqual(_cli(root, "check").returncode, 1)
            entry["reason"] = ""
            (root / lint.EXCEPTIONS_PATH).write_text(json.dumps([entry]), encoding="utf-8")
            self.assertEqual(_cli(root, "check").returncode, 2)

    def test_lower_counts_pass_and_remind_to_tighten(self) -> None:
        result = {"counts": {}, "sites": []}
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertTrue(lint.check(result, {"scripts/gone.gd": {"R1": 1}}, {}))
        self.assertIn("--tighten", output.getvalue())

    def test_new_file_can_only_use_an_explicit_exception_allowance(self) -> None:
        result = {"counts": {"scripts/new.gd": {"R1": 1}},
                  "sites": [{"file": "scripts/new.gd", "line": 1, "rule": "R1"}]}
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertFalse(lint.check(result, {}, {}))
            self.assertTrue(lint.check(result, {}, {"scripts/new.gd": {"R1": 1}}))

    def test_invalid_policy_counts_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "policy.json"
            for count in (-1, True, "1", 1.5):
                with self.subTest(count=count):
                    path.write_text(json.dumps({"version": 1, "counts": {"scripts/x.gd": {"R1": count}}}),
                                    encoding="utf-8")
                    with self.assertRaises(ValueError):
                        lint.read_baseline(path)
                    path.write_text(json.dumps([{"file": "scripts/x.gd", "rule": "R1", "count": count,
                                                 "reason": "Test-only invalid policy"}]), encoding="utf-8")
                    with self.assertRaises(ValueError):
                        lint.read_exceptions(path)

    def test_scan_json_is_deterministic_with_totals_top_files_and_sites(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts/nested").mkdir(parents=True)
            for index in reversed(range(lint.TOP_FILE_LIMIT + 2)):
                (root / f"scripts/nested/file_{index:02}.gd").write_text("StyleBoxFlat.new()\n", encoding="utf-8")
            (root / "outside.gd").write_text("StyleBoxFlat.new()\n", encoding="utf-8")
            first, second = _cli(root, "scan", "--json"), _cli(root, "scan", "--json")
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(first.stdout, second.stdout)
            result = json.loads(first.stdout)
            self.assertEqual(result["totals"]["R1"], 17)
            self.assertEqual(len(result["sites"]), 17)
            self.assertEqual(len(result["top_files"]["R1"]), 15)
            self.assertEqual(result["top_files"]["R1"][0]["file"], "scripts/nested/file_00.gd")

    def test_scan_includes_scenes_and_themes_for_r1_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scenes/nested").mkdir(parents=True)
            (root / "themes/nested").mkdir(parents=True)
            (root / "scenes/nested/raw_box.tscn").write_text(_fixture("raw_box.tscn"), encoding="utf-8")
            (root / "themes/nested/raw_box.tres").write_text(_fixture("raw_box.tres"), encoding="utf-8")
            result = lint.scan(root)
            self.assertEqual(result["totals"], {"R1": 2, "R2": 0, "R3": 0, "R4": 0, "R5": 0, "R6": 0})
            self.assertEqual(sorted(result["counts"]), ["scenes/nested/raw_box.tscn", "themes/nested/raw_box.tres"])

    def test_policy_is_mandatory_for_ui_work(self) -> None:
        for relative in ("AGENTS.md", ".codex/skills/create-labyrinth-ui/SKILL.md"):
            source = (REPO_ROOT / relative).read_text(encoding="utf-8")
            self.assertIn("spec/ui_identity_gate.md", source, relative)


if __name__ == "__main__":
    unittest.main()

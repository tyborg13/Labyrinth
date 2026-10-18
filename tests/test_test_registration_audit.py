"""Registration guard regressions: references alone cannot hide an orphan."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location("test_registration_audit", Path(__file__).resolve().parents[1] / "tools/test_registration_audit.py")
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class RegistrationAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.write("tests/run_tests.gd", 'extends SceneTree\nfunc _initialize():\n\tquit(0)\n')

    def write(self, path, text):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(text)

    def rows(self):
        return {r["path"]: r["classification"] for r in audit.audit(self.root)[0]}

    def quarantine(self, path="tests/broken_test.gd", **changes):
        entry = {"path": path, "category": "stale-reference", "reason": "Old independent reference",
                 "evidence_log": "output/proof/broken.log", "follow_up": "qa-09"}
        entry.update(changes)
        self.write(audit.QUARANTINE_MANIFEST, json.dumps([entry]))
        return entry

    def test_new_headless_test_fails_guard(self):
        self.write("tests/new_test.gd", 'extends SceneTree\nfunc _initialize():\n\tassert(false)\n')
        self.assertIn("Unregistered headless test: tests/new_test.gd", audit.audit(self.root)[1])

    def test_comment_preload_and_parse_only_load_do_not_register(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
const Unused = preload("res://tests/unused_suite.gd")
func _initialize():
    # preload("res://tests/comment_suite.gd").run()
    load("res://tests/parsed_suite.gd")
    quit(0)
''')
        for name in ("unused", "comment", "parsed"):
            self.write(f"tests/{name}_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(false)\n')
            self.assertEqual(self.rows()[f"tests/{name}_suite.gd"], "orphaned")

    def test_follow_deferred_and_inline_suite_call(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
func _initialize():
    call_deferred("_run")
func _run():
    preload("res://tests/nested_suite.gd").run()
''')
        self.write("tests/nested_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/nested_suite.gd"], "full suite")

    def test_function_local_aliases_do_not_leak_from_uncalled_functions(self):
        for keyword in ("var", "const"):
            with self.subTest(keyword=keyword):
                self.write("tests/run_tests.gd", f'''extends SceneTree
func _initialize():
    {keyword} suite = preload("res://tests/a_suite.gd")
    suite.run()
func _unused():
    {keyword} suite = preload("res://tests/b_suite.gd")
    suite.run()
''')
                for name in ("a", "b"):
                    self.write(f"tests/{name}_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
                self.assertEqual(self.rows()["tests/a_suite.gd"], "full suite")
                self.assertEqual(self.rows()["tests/b_suite.gd"], "orphaned")

    def test_local_alias_does_not_replace_class_constant_in_another_method(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
const Suite = preload("res://tests/a_suite.gd")
func _initialize():
    _run()
func _run():
    Suite.run()
func _unused():
    const Suite = preload("res://tests/b_suite.gd")
''')
        for name in ("a", "b"):
            self.write(f"tests/{name}_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/a_suite.gd"], "full suite")
        self.assertEqual(self.rows()["tests/b_suite.gd"], "orphaned")

    def test_strings_do_not_register_inline_alias_local_or_deferred_calls(self):
        examples = ('preload("res://tests/ghost_suite.gd").run()', 'Ghost.run()',
                    '_uncalled()', 'call_deferred("_uncalled")', 'Callable(self, "_uncalled")')
        for example in examples:
            for literal in (json.dumps(example), repr(example), '"""\n' + example + '\n"""',
                            "'''\n" + example + "\n'''"):
                with self.subTest(literal=literal):
                    self.write("tests/run_tests.gd", f'''extends SceneTree
const Ghost = preload("res://tests/ghost_suite.gd")
func _initialize():
    print({literal}) # Ghost.run()
func _uncalled():
    Ghost.run()
''')
                    self.write("tests/ghost_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(false)\n')
                    self.assertEqual(self.rows()["tests/ghost_suite.gd"], "orphaned")

    def test_untyped_typed_and_inferred_aliases_in_class_and_function_scope(self):
        for keyword, loader in (("var", "load"), ("const", "preload")):
            for assignment in (" = ", ": Variant = ", " := "):
                for class_scope in (True, False):
                    with self.subTest(keyword=keyword, assignment=assignment, class_scope=class_scope):
                        declaration = f'{keyword} Suite{assignment}{loader}("res://tests/active_suite.gd")\n'
                        self.write("tests/run_tests.gd", "extends SceneTree\n" +
                                   (declaration if class_scope else "") + "func _initialize():\n" +
                                   ("" if class_scope else "    " + declaration) + "    Suite.run()\n")
                        self.write("tests/active_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
                        self.assertEqual(self.rows()["tests/active_suite.gd"], "full suite")

    def test_nested_alias_lookup_uses_class_scope_only(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
const Outer = preload("res://tests/outer.gd")
func _initialize():
    Outer.Inner.run()
''')
        self.write("tests/outer.gd", '''extends RefCounted
const Inner = preload("res://tests/a_suite.gd")
static func unused():
    const Inner = preload("res://tests/b_suite.gd")
''')
        for name in ("a", "b"):
            self.write(f"tests/{name}_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/a_suite.gd"], "full suite")
        self.assertEqual(self.rows()["tests/b_suite.gd"], "orphaned")

    def assert_mutation_rejected(self, name, test_name, patcher):
        result = unittest.TestResult()
        with patcher:
            type(self)(test_name).run(result)
        self.assertFalse(result.errors, result.errors)
        self.assertGreater(len(result.failures), 0, name + " survived its regression")
        print("AUDIT MUTATION REJECTED: %s (%d assertion failures)" % (name, len(result.failures)))

    def test_global_alias_collection_fails_scope_regression(self):
        path = Path(audit.__file__)
        source = path.read_text()
        class_aliases = "gd.aliases(parsed.class_tokens)"
        local_aliases = '        aliases.update({a: resource_path(owner, p) for a, p in gd.aliases(body).items()})\n'
        self.assertIn(class_aliases, source)
        self.assertIn(local_aliases, source)
        mutated = {"__file__": str(path), "__name__": "scope_mutation"}
        source = source.replace(class_aliases, "gd.aliases(parsed.class_tokens + [t for body in parsed.methods.values() for t in body])")
        exec(compile(source.replace(local_aliases, ""), str(path), "exec"), mutated)
        self.assert_mutation_rejected("aliases collected across functions",
                                     "test_function_local_aliases_do_not_leak_from_uncalled_functions",
                                     mock.patch.object(audit, "execution_graph", mutated["execution_graph"]))

    def test_scanning_string_contents_fails_call_regression(self):
        original = audit.gd.calls

        def scan_strings(tokens):
            edges = original(tokens)
            for token in tokens:
                if token.kind == "string":
                    extra = original(audit.gd.tokenize(token.value))
                    edges = audit.gd.Calls(*(a + b for a, b in zip(edges, extra)))
            return edges

        self.assert_mutation_rejected("string contents scanned as calls",
                                     "test_strings_do_not_register_inline_alias_local_or_deferred_calls",
                                     mock.patch.object(audit.gd, "calls", side_effect=scan_strings))

    def test_omitting_inferred_aliases_fails_assignment_regression(self):
        original = audit.gd.aliases

        def omit_inferred(tokens):
            result = original(tokens)
            for index, token in enumerate(tokens[:-3]):
                if token.value in ("var", "const") and [t.value for t in tokens[index + 2:index + 4]] == [":", "="]:
                    result.pop(tokens[index + 1].value, None)
            return result

        self.assert_mutation_rejected("inferred aliases omitted",
                                     "test_untyped_typed_and_inferred_aliases_in_class_and_function_scope",
                                     mock.patch.object(audit.gd, "aliases", side_effect=omit_inferred))

    def test_relative_nested_suite_calls_are_followed(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
func _initialize():
    preload("res://tests/nested/outer.gd").run()
''')
        self.write("tests/nested/outer.gd", 'extends RefCounted\nstatic func run():\n\tpreload("inner_suite.gd").run()\n')
        self.write("tests/nested/inner_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/nested/inner_suite.gd"], "full suite")

    def test_map_performance_child_requires_its_executed_regression_call(self):
        self.write("tests/run_tests.gd", 'extends SceneTree\nfunc _initialize():\n\tpreload("res://tests/suites/section_map_performance_suite.gd").run()\n')
        suite = '''extends RefCounted
const Regression = preload("res://tests/suites/section_map_regression_suite.gd")
static func run():
    Regression._run_child("section_map_type_rejection_test.gd", 10)
'''
        self.write("tests/suites/section_map_performance_suite.gd", suite)
        self.write("tests/suites/section_map_regression_suite.gd", 'extends RefCounted\nstatic func _run_child(path, timeout):\n\tpass\n')
        self.write("tests/section_map_type_rejection_test.gd", 'extends SceneTree\nfunc _initialize():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/section_map_type_rejection_test.gd"], "full suite")
        self.write("tests/suites/section_map_performance_suite.gd", suite.replace('    Regression._run_child', '    # Regression._run_child'))
        self.assertEqual(self.rows()["tests/section_map_type_rejection_test.gd"], "orphaned")

    def test_overridden_initializer_follows_inherited_and_nested_aliases(self):
        self.write("tests/run_tests.gd", 'extends SceneTree\nfunc _initialize():\n\tpreload("res://tests/child_suite.gd").run()\n')
        self.write("tests/parent.gd", 'extends RefCounted\nconst Nested = preload("res://tests/outer.gd")\n')
        self.write("tests/child_suite.gd", 'extends "res://tests/parent.gd"\nstatic func run():\n\tNested.Inner.run()\n')
        self.write("tests/outer.gd", 'extends RefCounted\nconst Inner = preload("res://tests/inner_suite.gd")\n')
        self.write("tests/inner_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/inner_suite.gd"], "full suite")

    def test_python_driver_requires_a_reachable_executed_script_command(self):
        self.write("tests/program_suite_runner_test.gd", 'extends SceneTree\n')
        driver = '''import subprocess
class DriverTests:
    def test_parent(self):
        self.fixture()
    def fixture(self):
        command = ["godot", "--script", "tests/program_suite_runner_test.gd"]
        return subprocess.run(command)
'''
        self.write("tests/test_program_suite_runner.py", driver)
        self.assertEqual(self.rows()["tests/program_suite_runner_test.gd"], "full suite")
        for broken in (driver.replace("self.fixture()", "pass"), driver.replace("return subprocess.run(command)", "return 0")):
            self.write("tests/test_program_suite_runner.py", broken)
            self.assertEqual(self.rows()["tests/program_suite_runner_test.gd"], "orphaned")

    def test_program_registration_executes_whole_entrypoint(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
func _initialize():
    preload("res://tools/program_suite_runner.gd").start()
''')
        self.write(audit.PROGRAM_DISPATCHER, 'extends RefCounted\nstatic func start():\n\tpass\n')
        self.write(audit.PROGRAM_MANIFEST, json.dumps([{"path": "tests/isolated_test.gd"}]))
        self.write("tests/isolated_test.gd", 'extends SceneTree\nfunc _initialize():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/isolated_test.gd"], "full suite")
        self.assertFalse(audit.audit(self.root)[1])
        self.write("tests/run_tests.gd", 'extends SceneTree\nfunc _initialize():\n\tquit(0)\n')
        self.assertEqual(self.rows()["tests/isolated_test.gd"], "orphaned")

    def test_wrapper_requires_same_executed_methods_and_no_local_assertions(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
func _initialize():
    preload("res://tests/shared_suite.gd").run()
''')
        self.write("tests/shared_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\nstatic func run_live():\n\tassert(true)\n')
        wrapper = '''extends SceneTree
const Suite = preload("res://tests/shared_suite.gd")
func _initialize():
    Suite.run()
'''
        self.write("tests/shared_test.gd", wrapper)
        self.assertEqual(self.rows()["tests/shared_test.gd"], "full suite")
        self.write("tests/shared_test.gd", wrapper + '    _expect(false, "unique regression")\nfunc _expect(ok, message):\n    assert(ok)\n')
        self.assertEqual(self.rows()["tests/shared_test.gd"], "orphaned")
        self.write("tests/shared_test.gd", wrapper.replace("Suite.run()", "Suite.run_live()"))
        self.assertEqual(self.rows()["tests/shared_test.gd"], "orphaned")

    def test_subclass_entrypoint_does_not_register_overridden_base_test(self):
        self.write("tests/run_tests.gd", '''extends SceneTree
func _initialize():
    preload("res://tools/program_suite_runner.gd").start()
''')
        self.write(audit.PROGRAM_DISPATCHER, 'extends RefCounted\nstatic func start():\n\tpass\n')
        self.write(audit.PROGRAM_MANIFEST, json.dumps([{"path": "tests/child_test.gd"}]))
        self.write("tests/base_test.gd", '''extends SceneTree
func _initialize():
    call_deferred("_run")
func _run():
    assert(false)
''')
        self.write("tests/child_test.gd", 'extends "res://tests/base_test.gd"\nfunc _run():\n\tassert(true)\n')
        self.assertEqual(self.rows()["tests/base_test.gd"], "orphaned")
        self.assertEqual(self.rows()["tests/child_test.gd"], "full suite")

    def test_partition_requires_every_program_before_shared_wrapper_coverage(self):
        original = "tests/section_map_v5_test.gd"
        parts = audit.PARTITIONED_PROGRAMS[original]
        self.write("tests/run_tests.gd", 'extends SceneTree\nfunc _initialize():\n\tpreload("res://tools/program_suite_runner.gd").start()\n')
        self.write(audit.PROGRAM_DISPATCHER, 'extends RefCounted\nstatic func start():\n\tpass\n')
        self.write(original, 'extends SceneTree\nconst Suite = preload("res://tests/shared_suite.gd")\nfunc _initialize():\n\tSuite.run()\n')
        self.write("tests/shared_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(true)\n')
        for part in parts:
            self.write(part, 'extends SceneTree\nconst Suite = preload("res://tests/shared_suite.gd")\nfunc _initialize():\n\tSuite.run()\n')
        self.write(audit.PROGRAM_MANIFEST, json.dumps([{"path": part} for part in parts]))
        self.assertEqual(self.rows()[original], "full suite")
        for missing in parts:
            with self.subTest(missing=missing):
                self.write(audit.PROGRAM_MANIFEST, json.dumps([{"path": part} for part in parts if part != missing]))
                self.assertEqual(self.rows()[original], "orphaned")

    def test_windowed_allowlist_is_exact_and_requires_a_reason(self):
        self.write("tests/pixels_test.gd", 'extends SceneTree\nfunc _initialize():\n\tawait RenderingServer.frame_post_draw\n')
        self.write(audit.WINDOWED_MANIFEST, json.dumps({"tests/pixels_test.gd": "requires frame_post_draw"}))
        self.assertEqual(self.rows()["tests/pixels_test.gd"], "windowed probe")
        self.write("tests/new_pixels_test.gd", 'extends SceneTree\n')
        self.assertEqual(self.rows()["tests/new_pixels_test.gd"], "orphaned")
        self.write(audit.WINDOWED_MANIFEST, json.dumps({"tests/pixels_test.gd": ""}))
        self.assertIn("Invalid renderer exclusion: tests/pixels_test.gd", audit.audit(self.root)[1])

    def test_stale_and_duplicate_program_entries_fail(self):
        self.write(audit.PROGRAM_MANIFEST, json.dumps([{"path": "tests/deleted_test.gd"}] * 2))
        self.assertIn("Invalid or duplicate program registration: tests/deleted_test.gd", audit.audit(self.root)[1])

    def test_complete_owned_quarantine_covers_headless_test(self):
        self.write("tests/broken_test.gd", 'extends SceneTree\nfunc _initialize():\n\tassert(false)\n')
        self.quarantine()
        self.assertEqual(self.rows()["tests/broken_test.gd"], "quarantined")
        self.assertEqual(audit.audit(self.root)[1], [])
        self.write("tests/new_test.gd", 'extends SceneTree\n')
        self.assertIn("Unregistered headless test: tests/new_test.gd", audit.audit(self.root)[1])

    def test_each_quarantine_field_is_required_and_nonempty(self):
        self.write("tests/broken_test.gd", 'extends SceneTree\n')
        for field in audit.QUARANTINE_FIELDS:
            for value in (None, "", "   ", 3):
                with self.subTest(field=field, value=value):
                    entry = self.quarantine()
                    if value is None:
                        del entry[field]
                    else:
                        entry[field] = value
                    self.write(audit.QUARANTINE_MANIFEST, json.dumps([entry]))
                    self.assertTrue(any("Incomplete quarantine" in error for error in audit.audit(self.root)[1]))

    def test_quarantine_category_and_owner_must_match(self):
        self.write("tests/broken_test.gd", 'extends SceneTree\n')
        for changes in ({"category": "other"}, {"follow_up": "qa-99"}, {"follow_up": "qa-10"}):
            with self.subTest(changes=changes):
                self.quarantine(**changes)
                self.assertTrue(any("unknown category or follow-up" in error for error in audit.audit(self.root)[1]))

    def test_quarantine_evidence_path_is_relative_without_requiring_local_artifact(self):
        self.write("tests/broken_test.gd", 'extends SceneTree\n')
        for path in ("/tmp/proof.log", "../proof.log", "output/../proof.log", "C:\\proof.log", "."):
            with self.subTest(path=path):
                self.quarantine(evidence_log=path)
                self.assertTrue(any("evidence_log must" in error for error in audit.audit(self.root)[1]))
        self.quarantine()
        self.assertEqual(audit.audit(self.root)[1], [])

    def test_deleted_duplicate_and_windowed_quarantines_fail(self):
        self.quarantine()
        self.assertTrue(any("missing test" in error for error in audit.audit(self.root)[1]))
        self.write("tests/broken_test.gd", 'extends SceneTree\n')
        entry = self.quarantine()
        self.write(audit.QUARANTINE_MANIFEST, json.dumps([entry, entry]))
        self.assertTrue(any("duplicate path" in error for error in audit.audit(self.root)[1]))
        self.quarantine()
        self.write(audit.WINDOWED_MANIFEST, json.dumps({"tests/broken_test.gd": "native rendering"}))
        self.assertTrue(any("already registered or windowed" in error for error in audit.audit(self.root)[1]))

    def test_registered_test_cannot_stay_quarantined(self):
        self.write("tests/run_tests.gd", 'extends SceneTree\nfunc _initialize():\n\tpreload("res://tests/broken_test.gd").run()\n')
        self.write("tests/broken_test.gd", 'extends RefCounted\nstatic func run():\n\tpass\n')
        self.quarantine()
        self.assertTrue(any("already registered or windowed" in error for error in audit.audit(self.root)[1]))

    def test_quarantined_library_requires_an_executed_entrypoint(self):
        self.write("tests/broken_suite.gd", 'extends RefCounted\nstatic func run():\n\tassert(false)\n')
        self.quarantine("tests/broken_suite.gd")
        self.assertTrue(any("requires an executable entrypoint" in error for error in audit.audit(self.root)[1]))
        self.write("tests/wrapper_test.gd", 'extends SceneTree\nfunc _initialize():\n\tquit(0)\n')
        self.quarantine("tests/broken_suite.gd", entrypoint="tests/wrapper_test.gd")
        self.assertTrue(any("does not execute" in error for error in audit.audit(self.root)[1]))
        self.write("tests/wrapper_test.gd", 'extends SceneTree\nfunc _initialize():\n\tpreload("res://tests/broken_suite.gd").run()\n')
        self.assertEqual(self.rows()["tests/broken_suite.gd"], "quarantined")

    def test_slow_guard_flags_passing_quarantine(self):
        self.write("tests/broken_test.gd", 'extends SceneTree\n')
        self.quarantine()
        for exit_code in (0, 1, 124):
            with self.subTest(exit_code=exit_code):
                def execute(program, root, output):
                    return {"path": program["path"], "exit": exit_code, "seconds": 1, "log": "proof.log"}
                results, errors = audit.check_quarantine(self.root, self.root, execute)
                self.assertEqual(len(results), 1)
                self.assertEqual(bool(errors), exit_code == 0)
                if exit_code == 0:
                    self.assertIn("now passes; register it", errors[0])

    def test_slow_guard_runs_shared_suite_assertions_once(self):
        entry = self.quarantine()
        suite = dict(entry, path="tests/broken_suite.gd", entrypoint=entry["path"])
        self.write(audit.QUARANTINE_MANIFEST, json.dumps([entry, suite]))
        called = []
        def execute(program, root, output):
            called.append(program["path"])
            return {"path": program["path"], "exit": 0, "seconds": 1, "log": "proof.log"}
        results, errors = audit.check_quarantine(self.root, self.root, execute)
        self.assertEqual(called, [entry["path"]])
        self.assertEqual(len(results), 2)
        self.assertEqual(len(errors), 2)

    def test_invalid_quarantine_document_fails(self):
        for value in ({}, [None], ["not an entry"]):
            with self.subTest(value=value):
                self.write(audit.QUARANTINE_MANIFEST, json.dumps(value))
                self.assertTrue(audit.audit(self.root)[1])

    def test_repository_headless_registration_guard(self):
        _, errors = audit.audit()
        self.assertEqual(errors, [], "\n" + "\n".join(errors))


if __name__ == "__main__":
    unittest.main()

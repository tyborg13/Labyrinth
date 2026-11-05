#!/usr/bin/env python3
"""Behavioral checks for concurrency, ordered logs, failure and cancellation."""

from __future__ import annotations

import json
import os
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import threading
from unittest import mock
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools/program_suite_runner.py"
CASE_SLEEP_SECONDS = 0.25
TEST_TIMEOUT_SECONDS = 15
STARTUP_TIMEOUT_SECONDS = 5
# This fixture only boots a tiny Python executable, not a native Godot project.
# Both attempts must still record their PID and be reaped (asserted below).
HUNG_CHILD_TIMEOUT_SECONDS = 1.2
POLL_SECONDS = 0.02
FIXTURE_TEST_TIMEOUT_SECONDS = 30
# Independent of the manifest: recognized but incorrect modes must fail too.
REQUIRED_FIXTURE_MODES = {"demo_capture_settings_test": "capture_settings"}
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests/helpers"))

import program_suite_runner as runner
import program_suite_fixture as fixture
import godot_import_cache as import_cache
import godot_task_runner as task_runner
import pool_width_benchmark as pool_benchmark
import loaded_suite_benchmark as loaded_benchmark

FAKE_GODOT = '''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
name = Path(sys.argv[sys.argv.index('--script') + 1]).stem
case = json.loads(os.environ['RUNNER_TEST_CASES']).get(name, {})
def event(kind):
    row = dict(kind=kind, name=name, pid=os.getpid(), seconds=time.monotonic(),
               home=os.environ['HOME'], task=os.environ['LABYRINTH_TASK_ID'],
               appdata=os.environ['APPDATA'], localappdata=os.environ['LOCALAPPDATA'],
               xdg_data=os.environ['XDG_DATA_HOME'], xdg_config=os.environ['XDG_CONFIG_HOME'],
               xdg_cache=os.environ['XDG_CACHE_HOME'], xdg_state=os.environ['XDG_STATE_HOME'],
               user=os.environ['LABYRINTH_USER_DIR_NAME'], cel=os.environ['LABYRINTH_CEL_LOOK'], args=sys.argv[1:])
    fd = os.open(os.environ['RUNNER_TEST_EVENTS'], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    os.write(fd, (json.dumps(row) + '\\n').encode())
    os.close(fd)
previous = [json.loads(line) for line in Path(os.environ['RUNNER_TEST_EVENTS']).read_text().splitlines()] if Path(os.environ['RUNNER_TEST_EVENTS']).exists() else []
if 'retry' in case and any(row['kind'] == 'start' and row['name'] == name for row in previous):
    case = case['retry']
event('start')
print('CHILD LOG START ' + name, flush=True)
if case.get('barrier', 0):
    deadline = time.monotonic() + case['barrier_timeout']
    while sum(json.loads(line)['kind'] == 'start' for line in Path(os.environ['RUNNER_TEST_EVENTS']).read_text().splitlines()) < case['barrier']:
        if time.monotonic() >= deadline:
            print('TEST RESULT: FAIL concurrency barrier not reached', flush=True)
            sys.exit(1)
        time.sleep(case['poll'])
time.sleep(case.get('sleep', 0))
print(case.get('output', 'child output ' + name), flush=True)
print('CHILD LOG END ' + name, flush=True)
event('end')
sys.exit(case.get('code', 0))
'''


class ProgramSuiteRunnerTests(unittest.TestCase):
    def test_cel_default_and_explicit_modes(self):
        for index, value in enumerate((None, 'all', 'actors', 'off', '')):
            with self.subTest(value=value), mock.patch.dict(os.environ):
                os.environ.pop('LABYRINTH_CEL_LOOK', None)
                if value is not None:
                    os.environ['LABYRINTH_CEL_LOOK'] = value
                result, report = self.run_scheduler({'cel_' + str(index): {}})
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(self.read_events()[-1]['cel'], 'off' if value is None else value)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.godot = self.directory / "godot"
        self.godot.write_text(FAKE_GODOT)
        self.godot.chmod(0o755)
        self.fixture_manifest = self.directory / "programs.json"
        fixture_programs = [
            {"path":"tests/runner_pack_fixture.gd", "mode":"cutout_pack"},
            {"path":"tests/runner_roster_fixture.gd", "mode":"roster_pack"},
            {"path":"tests/demo_capture_settings_test.gd", "mode":"capture_settings"},
        ]
        # Fixture sources live under the test's temp directory. The real stage
        # bootstrap still uses the repository runtime for its root project.
        for row in fixture_programs[:2]:
            script = self.directory / Path(row["path"]).name
            script.write_text('extends SceneTree\nfunc _initialize() -> void:\n'
                              '\tprint("RUNNER PACKAGE FIXTURE: PASS")\n\tquit(0)\n')
            row["source"] = str(script)
        self.fixture_manifest.write_text(json.dumps(fixture_programs))
        self.events = self.directory / "events.jsonl"
        self.report = self.directory / "report.json"

    def environment(self, cases):
        environment = dict(os.environ, RUNNER_TEST_CASES=json.dumps(cases), RUNNER_TEST_EVENTS=str(self.events),
                           LABYRINTH_PROGRAM_MANIFEST=str(self.fixture_manifest))
        environment.pop(runner.TEST_POOL_ENV, None)
        return environment

    def command(self, suites, *extra):
        command = [sys.executable, str(RUNNER), "--project", str(ROOT), "--godot", str(self.godot),
                   "--task-id", "runner-test", "--result-file", str(self.report), *extra]
        for suite in suites:
            command.extend(["--suite", suite])
        return command

    def run_scheduler(self, cases, *extra):
        result = subprocess.run(self.command(cases, *extra), env=self.environment(cases),
                                text=True, capture_output=True, timeout=TEST_TIMEOUT_SECONDS)
        return result, json.loads(self.report.read_text())

    def read_events(self):
        return [json.loads(line) for line in self.events.read_text().splitlines()]

    def test_manifest_has_unique_existing_programs_and_valid_timeouts(self):
        self.assertEqual(len(runner.SUITES), len(set(runner.SUITES)))
        for name in runner.SUITES:
            self.assertTrue((ROOT / "tests" / (name + ".gd")).is_file(), name)
        for program in runner.SUPPLEMENTAL_PROGRAMS:
            self.assertGreater(program.get("timeout_seconds", runner.SUITE_TIMEOUT_SECONDS), 0)
        self.assertEqual(runner.SUITE_TIMEOUT_SECONDS, 300)

    def test_perf_selection_preserves_functional_programs(self):
        programs = {"functional": {}, "mixed": {"perf_checks": True}, "speed": {"group": "perf"}}
        with mock.patch.object(runner, "SUITES", tuple(programs)), mock.patch.object(runner, "SUPPLEMENTAL_BY_NAME", programs):
            self.assertEqual(set(runner.selected_suites()), {"functional", "mixed"})
            self.assertEqual(set(runner.selected_suites(True)), {"mixed", "speed"})

    def test_missing_and_stale_import_artifacts_are_detected(self):
        project = self.directory / "project"
        project.mkdir()
        self.assertIn("missing", import_cache.stale_reason(project))
        (project / ".godot").mkdir()
        (project / ".godot/global_script_class_cache.cfg").touch()
        source = project / "image.png"
        source.write_bytes(b"fixture")
        sidecar = project / "image.png.import"
        sidecar.write_text('[deps]\ndest_files=["res://.godot/imported/image.ctex"]\n')
        self.assertIn("missing artifact", import_cache.stale_reason(project))
        artifact = project / ".godot/imported/image.ctex"
        artifact.parent.mkdir()
        artifact.touch()
        self.assertEqual(import_cache.stale_reason(project), "")
        # Godot writes the sidecar just after the artifact. Its timestamp alone
        # must not turn a successful import into an endless reimport loop.
        newer = artifact.stat().st_mtime_ns + 1_000_000
        os.utime(sidecar, ns=(newer, newer))
        self.assertEqual(import_cache.stale_reason(project), "")
        old = source.stat().st_mtime_ns - 1_000_000
        os.utime(artifact, ns=(old, old))
        self.assertIn("stale artifact", import_cache.stale_reason(project))
        with mock.patch.object(import_cache.subprocess, "call", return_value=0) as launch:
            self.assertEqual(import_cache.ensure_imported(project, "godot", "test-02"), 0)
        command = launch.call_args.args[0]
        self.assertIn("godot_task_runner.py", command[1])
        self.assertEqual(command[-1], "--import")
        artifact.touch()
        with mock.patch.object(import_cache.subprocess, "call") as launch:
            self.assertEqual(import_cache.ensure_imported(project, "godot", "test-02"), 0)
            launch.assert_not_called()

    def test_import_index_reuses_paths_and_detects_new_sidecars(self):
        project = self.directory / "indexed"
        (project / ".godot").mkdir(parents=True)
        (project / ".godot/global_script_class_cache.cfg").touch()
        (project / "first.png").write_bytes(b"fixture")
        (project / "first.png.import").write_text('dest_files=["res://.godot/first.ctex"]\n')
        (project / ".godot/first.ctex").touch()
        self.assertEqual(import_cache.stale_reason(project), "")
        with mock.patch.object(import_cache, "_build_index", side_effect=AssertionError("warm check rebuilt index")):
            self.assertEqual(import_cache.stale_reason(project), "")
        (project / "new.png").write_bytes(b"fixture")
        (project / "new.png.import").write_text('dest_files=["res://.godot/new.ctex"]\n')
        self.assertIn("missing artifact: .godot/new.ctex", import_cache.stale_reason(project))
        (project / import_cache.INDEX_PATH).write_text('{"version":1,"directories":[],"rows":[]}')
        self.assertIn("missing artifact: .godot/new.ctex", import_cache.stale_reason(project))

    def test_perf_flag_enables_only_opt_in_guards_in_the_child(self):
        result, _report = self.run_scheduler({"speed": {}}, "--perf")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("--perf-checks", self.read_events()[0]["args"])

    def test_full_suite_entrypoint_is_detected_before_godot_parses(self):
        for script in ("tests/run_tests.gd", "./tests/run_tests.gd", "tests/../tests/run_tests.gd",
                       "res://tests/run_tests.gd", str(ROOT / "tests/run_tests.gd")):
            self.assertEqual(import_cache.full_suite_project(["godot", "--path", str(ROOT), "--script", script], ROOT), ROOT)
        self.assertIsNone(import_cache.full_suite_project(["godot", "--import"], ROOT))

    def assert_supplemental_modes(self, programs):
        self.assertLessEqual(REQUIRED_FIXTURE_MODES.keys(), programs.keys())
        for name, program in programs.items():
            self.assertEqual(program["path"], "tests/" + name + ".gd")
            self.assertTrue((ROOT / program["path"]).is_file())
            self.assertIn(program.get("mode", "script"), ("script", "cutout_pack", "roster_pack", "capture_settings"))
            self.assertEqual(program.get("mode", "script"), REQUIRED_FIXTURE_MODES.get(name, "script"), name)

    def test_supplemental_modes_and_paths_are_guarded(self):
        self.assert_supplemental_modes(runner.SUPPLEMENTAL_BY_NAME)

    def test_changing_any_supplemental_fixture_mode_fails_guard(self):
        for name, program in runner.SUPPLEMENTAL_BY_NAME.items():
            with self.subTest(name=name), self.assertRaises(AssertionError):
                changed = dict(program, mode="script" if program.get("mode", "script") != "script" else "cutout_pack")
                self.assert_supplemental_modes(dict(runner.SUPPLEMENTAL_BY_NAME, **{name: changed}))
        print("RUNNER MUTATION REJECTED: all %d supplemental mode changes (including Bile Bloomer to script)" % len(runner.SUPPLEMENTAL_BY_NAME))

    def assert_fixture_runtime_paths(self, execute):
        directory = self.directory / "runtime-paths"
        directory.mkdir()
        foreign = self.directory / "foreign-project"
        foreign.mkdir()
        script = "tests/runner_pack_fixture.gd"
        stages = [(ROOT, script, []), (foreign, str(ROOT / script), [])]
        with mock.patch.object(runner, "SUPPLEMENTAL_BY_NAME", {"runner_pack_fixture": {"path":script}}), \
                mock.patch.dict(execute.__globals__, {"fixture_stages": mock.Mock(return_value=stages)}), \
                mock.patch.object(fixture.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)), \
                mock.patch.object(runner, "task_command", return_value=["unused"]):
            result = execute(["--project", str(ROOT), "--suite", "runner_pack_fixture",
                              "--directory", str(directory), "--godot", "unused", "--task-id", "runtime-paths",
                              "--timeout", str(FIXTURE_TEST_TIMEOUT_SECONDS)])
        self.assertEqual(result, 0)
        root_bootstrap = (directory / "runner_pack_fixture.gd").read_text()
        foreign_bootstrap = (directory / "stage-1/runner_pack_fixture.gd").read_text()
        resource = 'preload("res://scripts/parallel_runtime.gd")'
        absolute = 'preload(' + json.dumps(str(ROOT / "scripts/parallel_runtime.gd")) + ')'
        self.assertIn(resource, root_bootstrap)
        self.assertNotIn(absolute, root_bootstrap)
        self.assertIn(absolute, foreign_bootstrap)
        self.assertNotIn(resource, foreign_bootstrap)

    def test_fixture_runtime_uses_resource_path_only_in_repository_project(self):
        self.assert_fixture_runtime_paths(fixture.main)

    def test_absolute_runtime_in_root_fails_bootstrap_path_guard(self):
        path = ROOT / "tools/program_suite_fixture.py"
        source = path.read_text()
        original = 'project.resolve() == root'
        self.assertIn(original, source)
        mutated = {"__file__": str(path), "__name__": "runtime_path_mutation"}
        exec(compile(source.replace(original, "False", 1), str(path), "exec"), mutated)
        with self.assertRaises(AssertionError):
            self.assert_fixture_runtime_paths(mutated["main"])
        print("RUNNER MUTATION REJECTED: absolute runtime preload in repository project")

    def test_map_performance_regression_has_an_exclusive_program_slot(self):
        self.assertIn("suites/section_map_performance_program", runner.SUITES)
        map_source = (ROOT / "tests/suites/section_map_v5_suite.gd").read_text()
        self.assertNotIn("section_map_performance_suite.gd", map_source,
                         "Keep the slow-seed performance regression out of the map aggregate")
        child = (ROOT / "tests/suites/section_map_performance_program.gd").read_text()
        self.assertIn('preload("res://tests/suites/section_map_performance_suite.gd")', child)
        self.assertIn('Suite.run(Callable(self, "_expect"))', child,
                      "The separate child must retain the entire regression")

    def test_full_harness_waits_for_coroutine_tests_before_reporting(self):
        source = (ROOT / "tests/run_tests.gd").read_text()
        methods = dict(re.findall(r"^func (\w+)\([^\n]*\n(.*?)(?=^func |\Z)", source, re.M | re.S))
        initializers = [methods["_initialize"]]
        for path in (ROOT / "tests/suites").glob("full_scene_*_program.gd"):
            initializers.append(path.read_text().split("func _initialize()", 1)[1])
        for initializer in initializers:
            for awaited, name in re.findall(r"^\t(await )?(_test_\w+)\(", initializer, re.M):
                if re.search(r"^\s+await ", methods[name], re.M):
                    self.assertTrue(awaited, name + " must complete before assertion counts and final reporting")

    def test_children_overlap_but_never_exceed_limit_and_keep_namespaces_separate(self):
        cases = {"child_%d" % index: {"sleep": CASE_SLEEP_SECONDS, "barrier": runner.DEFAULT_TEST_POOL,
                 "barrier_timeout": STARTUP_TIMEOUT_SECONDS, "poll": POLL_SECONDS}
                 for index in range(runner.DEFAULT_TEST_POOL + 2)}
        result, report = self.run_scheduler(cases)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        active = peak = 0
        events = self.read_events()
        for event in events:
            active += 1 if event["kind"] == "start" else -1
            peak = max(peak, active)
        self.assertEqual(active, 0)
        self.assertEqual(peak, runner.DEFAULT_TEST_POOL)
        self.assertEqual(report["jobs"], runner.DEFAULT_TEST_POOL)
        starts = [event for event in events if event["kind"] == "start"]
        for field in ("home", "task", "user", "appdata", "localappdata", "xdg_data", "xdg_config", "xdg_cache", "xdg_state"):
            self.assertEqual(len({event[field] for event in starts}), len(cases))
        self.assertEqual([row["name"] for row in report["results"]], list(cases))
        self.assertTrue(all(row["seconds"] > 0 for row in report["results"]))
        self.assertTrue(report["complete"])

    def test_fixture_stages_keep_one_slot_and_preserve_build_verify_arguments(self):
        cases = {"runner_pack_fixture": {}, "demo_capture_settings_test": {}, "runner_roster_fixture": {}}
        result, report = self.run_scheduler(cases)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        starts = [event for event in self.read_events() if event["kind"] == "start"]
        self.assertEqual(len(starts), 4)
        pack = [event for event in starts if event["name"] == "runner_pack_fixture"]
        self.assertEqual([event["args"][-2] for event in pack], ["build", "verify"])
        self.assertEqual(pack[0]["args"][-1], pack[1]["args"][-1])
        self.assertEqual(len({event["home"] for event in starts}), 4)
        self.assertEqual(len({event["appdata"] for event in starts}), 4)
        capture = next(event for event in starts if event["name"] == "demo_capture_settings_test")
        project = Path(capture["args"][capture["args"].index("--path") + 1])
        self.assertIn("mjpeg_quality=1.0", (project / "override.cfg").read_text())
        self.assertEqual(capture["args"][-1], "--verify-movie-guard")
        self.assertEqual(len(report["results"]), len(cases))

    def test_reusing_fixture_report_path_keeps_staging_fresh(self):
        for _iteration in range(2):
            result, _report = self.run_scheduler({"runner_pack_fixture": {}, "demo_capture_settings_test": {}})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        builds = [event["args"][-1] for event in self.read_events()
                  if event["kind"] == "start" and event["name"] == "runner_pack_fixture" and event["args"][-2] == "build"]
        self.assertEqual(len(set(builds)), 2)

    def test_parent_pipe_eof_cancels_active_package_stage(self):
        cases = {"runner_pack_fixture": {"sleep": 60}}
        process = subprocess.Popen(self.command(cases, "--watch-parent-stdin"), env=self.environment(cases),
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
            while not self.events.exists() and time.monotonic() < deadline:
                time.sleep(POLL_SECONDS)
            self.assertTrue(self.events.exists(), "Package stage did not start")
            pid = self.read_events()[0]["pid"]
            process.stdin.close()
            process.stdin = None
            stdout, stderr = process.communicate(timeout=TEST_TIMEOUT_SECONDS)
            self.assertEqual(process.returncode, 1, stdout + stderr)
            self.assertIn("parent interrupted", json.loads(self.report.read_text())["results"][0]["reason"])
            deadline = time.monotonic() + runner.WRAPPER_CLEANUP_SECONDS
            while time.monotonic() < deadline:
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    break
                time.sleep(POLL_SECONDS)
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)
        finally:
            if process.poll() is None:
                process.terminate()
                process.communicate(timeout=TEST_TIMEOUT_SECONDS)

    @unittest.skipUnless(shutil.which("godot"), "Needs native headless Godot for fixture stages")
    def test_real_fixture_stages_initialize_namespaces_and_run_complete_contracts(self):
        command = self.command(["runner_pack_fixture", "demo_capture_settings_test", "runner_roster_fixture"])
        command[command.index("--godot") + 1] = shutil.which("godot")
        result = subprocess.run(command, env=self.environment({}), text=True, capture_output=True, timeout=FIXTURE_TEST_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        paths = []
        logs = ""
        for row in json.loads(self.report.read_text())["results"]:
            log = Path(row["log_path"]).read_text()
            logs += log
            paths.extend(json.loads(value) for value in re.findall(r"^PROGRAM SUITE PATHS: (.+)$", log, re.M))
        self.assertEqual(len(paths), 4)
        for field in ("user_data", "log_file"):
            self.assertEqual(len({value[field] for value in paths}), 4)
        self.assertTrue(all(Path(value["log_file"]).is_file() for value in paths))
        self.assertEqual(logs.count("RUNNER PACKAGE FIXTURE: PASS"), 3)
        self.assertIn("DEMO MOVIE GUARD TEST: PASS", logs)

    def test_nonzero_child_fails_scheduler_and_names_child(self):
        result, report = self.run_scheduler({"deliberate_failure": {"code": 7}, "success": {}})
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertTrue(report["failed"])
        self.assertEqual(report["results"][0]["name"], "deliberate_failure")
        self.assertEqual(report["results"][0]["returncode"], 7)
        self.assertEqual(report["results"][1]["returncode"], 0)

    def test_zero_exit_script_failure_still_fails(self):
        result, report = self.run_scheduler({"marker_failure": {"output": "SCRIPT ERROR: deliberate"}})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["results"][0]["returncode"], 1)

    def test_hung_child_times_out_and_process_is_gone(self):
        result, report = self.run_scheduler({"hung_child": {"sleep": 60}}, "--timeout", str(HUNG_CHILD_TIMEOUT_SECONDS))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        child = report["results"][0]
        self.assertEqual(child["name"], "hung_child")
        self.assertEqual(child["returncode"], 124)
        self.assertTrue(child["timed_out"])
        log = Path(child["log_path"]).read_text()
        self.assertIn("timed out after %s seconds" % HUNG_CHILD_TIMEOUT_SECONDS, log)
        # Unlike the controlled-clock deadline tests below, this fixture needs
        # a real interpreter to start and record its owned PID before timeout.
        starts = self.read_events() if self.events.exists() else []
        self.assertEqual(len(starts), 2, "Each timeout attempt must start:\n" + log)
        self.assertEqual(report["retries"], ["hung_child"])
        for start in starts:
            with self.assertRaises(ProcessLookupError):
                os.kill(start["pid"], 0)

    def test_sequential_children_each_receive_their_whole_timeout(self):
        class Clock:
            now = 100.0
            def advance(self, seconds): self.now += seconds
            def monotonic(self): return self.now
        clock = Clock()
        timeouts = []
        class Process:
            def __init__(self): self.started = clock.now
            def poll(self): return 0 if clock.now - self.started >= 0.2 else None
        def launch(command, **kwargs):
            timeouts.append(float(command[command.index("--timeout") + 1]))
            return Process()
        args = argparse.Namespace(project=self.directory, godot="fixture", task_id="independent",
                                  result_file=self.report, suite=["first", "second"], jobs=1, timeout=0.3)
        with mock.patch.object(runner, "spawn_owned_process", side_effect=launch), \
                mock.patch.object(runner, "stop_wrapper"):
            report = runner.run_suites(args, threading.Event(), clock=clock.monotonic, wait=clock.advance)
        self.assertFalse(report["failed"])
        self.assertGreater(report["seconds"], args.timeout)
        self.assertEqual(timeouts, [0.3, 0.3])

    def test_full_suite_has_no_implicit_outer_cap_but_respects_explicit_timeouts(self):
        for script, flags, expected in (
            ("tests/run_tests.gd", [], None),
            ("tests/run_tests.gd", ["--timeout", "7"], 7),
            ("tests/run_tests.gd", ["--timeout=9"], 9),
            ("tests/individual.gd", [], task_runner.DEFAULT_TIMEOUT_SECONDS),
        ):
            with self.subTest(script=script, flags=flags), \
                    mock.patch.object(import_cache, "ensure_imported", return_value=0), \
                    mock.patch.object(task_runner, "run_task_command", return_value=task_runner.CommandResult(0, "", "")) as run:
                code = task_runner.main(["--project", str(ROOT), "--task-id", "test-02", "--godot-home-root", str(self.directory),
                                         *flags, "--", "godot", "--headless", "--path", str(ROOT), "--script", script])
            self.assertEqual(code, 0)
            self.assertEqual(run.call_args.args[3], expected)

    def test_rejected_editor_scan_cannot_start_an_import(self):
        with mock.patch.object(import_cache, "ensure_imported") as imported:
            with self.assertRaisesRegex(SystemExit, "refusing Godot --editor scan"):
                task_runner.main(["--project", str(ROOT), "--task-id", "test-02", "--godot-home-root", str(self.directory),
                                  "--", "godot", "--editor", "--script", "tests/run_tests.gd"])
        imported.assert_not_called()

    def test_full_entrypoint_import_failure_prevents_suite_launch(self):
        with mock.patch.object(import_cache, "ensure_imported", return_value=7), \
                mock.patch.object(task_runner, "run_task_command") as run:
            code = task_runner.main(["--project", str(ROOT), "--task-id", "test-02", "--godot-home-root", str(self.directory),
                                     "--", "godot", "--headless", "--path", str(ROOT), "--script", "tests/run_tests.gd"])
        self.assertEqual(code, 7)
        run.assert_not_called()

    def test_timeout_retries_once_serially_after_all_other_programs(self):
        cases = {"timeout": {"code": 124, "retry": {}}, "last": {"sleep": CASE_SLEEP_SECONDS}}
        result, report = self.run_scheduler(cases)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(report["retries"], ["timeout"])
        self.assertEqual([row["returncode"] for row in report["results"][0]["attempts"]], [124, 0])
        events = self.read_events()
        starts = [row for row in events if row["kind"] == "start" and row["name"] == "timeout"]
        last_end = next(row for row in events if row["kind"] == "end" and row["name"] == "last")
        self.assertGreater(events.index(starts[1]), events.index(last_end))
        self.assertNotEqual(starts[0]["home"], starts[1]["home"])

    def test_timeout_twice_fails(self):
        result, report = self.run_scheduler({"twice": {"code": 124}})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["retries"], ["twice"])
        self.assertEqual([row["returncode"] for row in report["results"][0]["attempts"]], [124, 124])

    def test_assertion_failure_is_never_retried_even_before_a_timeout(self):
        result, report = self.run_scheduler({"assertion": {"code": 124, "output": "TEST RESULT: FAIL assertion"}})
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["retries"], [])
        self.assertEqual(report["results"][0]["returncode"], 1)
        self.assertEqual(len(report["results"][0]["attempts"]), 1)

    def test_per_program_override_reaches_task_runner(self):
        args = argparse.Namespace(project=ROOT, godot=str(self.godot), task_id="test-02", result_file=self.report,
                                  suite=["slow"], jobs=1, timeout=300)
        original = runner.child_command
        observed = []
        def command(args, suite, timeout, bootstrap, engine_log):
            observed.append(timeout)
            return original(args, suite, timeout, bootstrap, engine_log)
        with mock.patch.dict(os.environ, self.environment({"slow": {}})), \
                mock.patch.dict(runner.SUPPLEMENTAL_BY_NAME, {"slow": {"timeout_seconds": 450}}), \
                mock.patch.object(runner, "child_command", side_effect=command):
            report = runner.run_suites(args, threading.Event())
        self.assertFalse(report["failed"])
        self.assertEqual(observed, [450])

    def test_parent_pipe_eof_cancels_children(self):
        cases = {"orphan_candidate": {"sleep": 60}}
        process = subprocess.Popen(self.command(cases, "--watch-parent-stdin"),
                                   env=self.environment(cases), stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
            while not self.events.exists() and time.monotonic() < deadline:
                time.sleep(POLL_SECONDS)
            self.assertTrue(self.events.exists(), "Child did not start")
            process.stdin.close()
            process.stdin = None
            stdout, stderr = process.communicate(timeout=TEST_TIMEOUT_SECONDS)
            self.assertEqual(process.returncode, 1, stdout + stderr)
            report = json.loads(self.report.read_text())
            self.assertIn("parent interrupted", report["results"][0]["reason"])
            with self.assertRaises(ProcessLookupError):
                os.kill(self.read_events()[0]["pid"], 0)
        finally:
            if process.poll() is None:
                process.terminate()
                process.communicate(timeout=TEST_TIMEOUT_SECONDS)

    def test_onset_arguments_are_preserved(self):
        suites = ["sfx_sync_harness", *["suites/sfx_sync_%d_program" % i for i in range(3)]]
        result, _report = self.run_scheduler({name: {} for name in suites})
        self.assertEqual(result.returncode, 0)
        for event in self.read_events():
            self.assertEqual(event["args"][-2:], ["--", "--assert-onsets"])

    def test_reused_report_path_gets_fresh_placement_transport(self):
        for _iteration in range(2):
            result, _report = self.run_scheduler({"suites/encounter_rules_program": {}})
            self.assertEqual(result.returncode, 0)
        starts = [event for event in self.read_events() if event["kind"] == "start"]
        directories = [Path(next(arg.split("=", 1)[1] for arg in event["args"]
                                 if arg.startswith("--placement-report-directory="))) for event in starts]
        self.assertEqual(len(set(directories)), 2)
        self.assertTrue(all(path.is_dir() and path.parent == self.report.with_suffix(".logs").resolve() for path in directories))

    def test_environment_sets_pool_and_explicit_jobs_takes_precedence(self):
        cases = {"first": {"sleep": CASE_SLEEP_SECONDS}, "second": {"sleep": CASE_SLEEP_SECONDS}}
        for environment_value, extra, expected in (("2", (), 2), ("invalid", ("--jobs", "1"), 1)):
            with self.subTest(environment_value=environment_value, extra=extra):
                self.events.unlink(missing_ok=True)
                result = subprocess.run(self.command(cases, *extra),
                                        env=dict(self.environment(cases), LABYRINTH_TEST_POOL=environment_value),
                                        text=True, capture_output=True, timeout=TEST_TIMEOUT_SECONDS)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                report = json.loads(self.report.read_text())
                self.assertEqual(report["jobs"], expected)
                active = peak = 0
                for event in self.read_events():
                    active += 1 if event["kind"] == "start" else -1
                    peak = max(peak, active)
                self.assertEqual(peak, expected)

    def test_explicit_wide_pools_are_not_capped_by_logical_cpu_formula(self):
        for width in (8, 11):
            with self.subTest(width=width):
                result, report = self.run_scheduler({"wide": {}}, "--jobs", str(width))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(report["jobs"], width)

    def test_invalid_pool_widths_fail_before_launch(self):
        for value in ("", "0", "-1", "invalid", "1.5"):
            with self.subTest(environment_value=value):
                result = subprocess.run(self.command(["unused"]),
                                        env=dict(self.environment({}), LABYRINTH_TEST_POOL=value),
                                        text=True, capture_output=True, timeout=TEST_TIMEOUT_SECONDS)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(self.events.exists())
        for value in ("0", "-1"):
            with self.subTest(jobs=value):
                result = subprocess.run(self.command(["unused"], "--jobs", value),
                                        env=self.environment({}), text=True, capture_output=True,
                                        timeout=TEST_TIMEOUT_SECONDS)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(self.events.exists())

    def test_memory_accounting_retains_orphans_and_rejects_reused_pids(self):
        memory = object.__new__(pool_benchmark.MacSuiteMemory)
        memory.owned = {}
        usage = {pid: SimpleNamespace(start=pid, resident=pid * 100, footprint=pid * 200)
                 for pid in (1, 2, 3, 99)}
        children = {1: [2], 2: [3]}
        memory.usage = usage.get
        memory.children = lambda pid: children.get(pid, [])
        self.assertEqual(memory.sample(1), {"rss_bytes": 600, "footprint_bytes": 1200, "processes": 3})
        children.clear()  # Owned children can briefly outlive their wrappers.
        del usage[3]
        self.assertEqual(memory.sample(1), {"rss_bytes": 300, "footprint_bytes": 600, "processes": 2})
        usage[2] = SimpleNamespace(start=200, resident=5000, footprint=9000)
        self.assertEqual(memory.sample(1), {"rss_bytes": 100, "footprint_bytes": 200, "processes": 1})

    def test_pool_selection_excludes_a_faster_width_with_a_failed_confirmation(self):
        for width, seconds in ((5, 10), (8, 7)):
            for repeat in range(2):
                row = {"requested_width": width, "actual_width": width, "passed": True,
                       "wall_seconds": seconds, "suite_seconds": seconds,
                       "peak_rss_bytes": 1000, "peak_footprint_bytes": 2000}
                (self.directory / ("trial-%d-%d.json" % (width, repeat))).write_text(json.dumps(row))
        failed = dict(row, requested_width=None, actual_width=8, passed=False, peak_footprint_bytes=3000)
        (self.directory / "confirm-default-8.json").write_text(json.dumps(failed))
        result = pool_benchmark.summarize(self.directory)
        self.assertEqual(result["chosen_width"], 5)
        self.assertFalse(result["groups"]["8"]["eligible"])
        self.assertEqual(result["groups"]["8"]["peak_footprint_bytes"], 3000)

    def test_loaded_pool_requires_three_complete_passes_below_memory_bound(self):
        passed = dict(passed=True, complete=True, actual_width=8, guard_reason="",
                      peak_rss_bytes=1000, peak_footprint_bytes=2000)
        self.assertTrue(loaded_benchmark.qualifies([passed] * 3))
        self.assertFalse(loaded_benchmark.qualifies([passed] * 2))
        for change in (dict(passed=False), dict(complete=False), dict(actual_width=5),
                       dict(guard_reason="memory accounting failed"),
                       dict(peak_rss_bytes=loaded_benchmark.MEMORY_BOUND_BYTES),
                       dict(peak_footprint_bytes=loaded_benchmark.MEMORY_BOUND_BYTES)):
            with self.subTest(change=change):
                self.assertFalse(loaded_benchmark.qualifies([passed, passed, dict(passed, **change)]))

    @unittest.skipUnless(sys.platform == "darwin", "macOS suite memory monitor")
    def test_memory_guard_interrupts_owned_command_before_it_can_run_unbounded(self):
        class MemoryAtLimit:
            def __init__(self):
                self.owned = {}

            def sample(self, _pid):
                return {"rss_bytes": 1024, "footprint_bytes": pool_benchmark.ABORT_MEMORY_BYTES,
                        "processes": 1}

        native_popen = subprocess.Popen
        processes = []

        def launch(_command, **kwargs):
            process = native_popen([sys.executable, "-c", "import time; time.sleep(60)"], **kwargs)
            processes.append(process)
            return process

        with mock.patch.object(pool_benchmark, "MacSuiteMemory", MemoryAtLimit), \
                mock.patch.object(pool_benchmark.subprocess, "Popen", side_effect=launch):
            result = pool_benchmark.run_trial(self.directory / "guard", 11, "guard-test")
        self.assertFalse(result["passed"])
        self.assertIn("memory guard", result["guard_reason"])
        self.assertLess(result["wall_seconds"], TEST_TIMEOUT_SECONDS)
        self.assertIsNotNone(processes[0].returncode)
        samples = [json.loads(line) for line in
                   (self.directory / "guard/guard-test-memory.jsonl").read_text().splitlines()]
        self.assertTrue(samples)
        self.assertEqual(samples[0]["footprint_bytes"], pool_benchmark.ABORT_MEMORY_BYTES)
        self.assertIn("seconds", samples[0])
        self.assertIn("load", samples[0])
    @unittest.skipUnless(shutil.which("godot"), "Needs native headless Godot to resolve storage paths")
    def test_children_resolve_distinct_user_storage_and_explicit_engine_logs(self):
        project = self.directory / "project"
        (project / "scripts").mkdir(parents=True)
        (project / "tests").mkdir()
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Runner Isolation Test"\n')
        shutil.copyfile(ROOT / "scripts/parallel_runtime.gd", project / "scripts/parallel_runtime.gd")
        # Intentionally omit namespace initialization, as en02/en04 used to do.
        (project / "tests/early_storage.gd").write_text('''extends SceneTree
func _initialize() -> void:
\tvar requested: String = OS.get_environment("LABYRINTH_USER_DIR_NAME")
\tif requested.is_empty() or preload("res://scripts/parallel_runtime.gd").current_namespace() != requested or ProjectSettings.get_setting("application/config/custom_user_dir_name", "") != requested:
\t\tprint("TEST RESULT: FAIL namespace not initialized before persistence")
\t\tquit(1)
\t\treturn
\tvar path: String = ProjectSettings.globalize_path("user://early-storage.json")
\tFileAccess.open(path, FileAccess.WRITE).store_string("isolated")
\tprint("EARLY STORAGE: " + path)
\tquit(0)
''')
        command = self.command(["early_storage", "early_storage"])
        command[command.index("--project") + 1] = str(project)
        command[command.index("--godot") + 1] = str(Path(shutil.which("godot")).resolve())
        result = subprocess.run(command, text=True, capture_output=True, timeout=TEST_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        resolved = []
        for row in json.loads(self.report.read_text())["results"]:
            log = Path(row["log_path"]).read_text()
            paths = json.loads(re.search(r"^PROGRAM SUITE PATHS: (.+)$", log, re.M)[1])
            storage = Path(re.search(r"^EARLY STORAGE: (.+)$", log, re.M)[1])
            self.assertEqual(storage.read_text(), "isolated")
            self.assertEqual(storage.parent, Path(paths["user_data"]))
            self.assertEqual(Path(paths["user_file"]).parent, storage.parent)
            self.assertEqual(paths["log_file"], row["engine_log_path"])
            # Check the real Godot log, not just the requested environment path.
            self.assertIn(paths["user_data"], Path(paths["log_file"]).read_text())
            resolved.append(paths)
        for field in ("user_data", "user_file", "log_file"):
            self.assertEqual(len({row[field] for row in resolved}), 2, field)

        original = runner.write_child_bootstrap

        def omit_namespace_initialization(path, suite):
            original(path, suite)
            path.write_text(path.read_text().replace(
                '\tpreload("res://scripts/parallel_runtime.gd").apply_from_environment()\n', ""))

        args = argparse.Namespace(project=project, task_id="namespace-mutation", godot=shutil.which("godot"),
                                  result_file=self.directory / "mutation.json", jobs=1, timeout=5,
                                  suite=["early_storage"])
        with mock.patch.object(runner, "write_child_bootstrap", side_effect=omit_namespace_initialization):
            report = runner.run_suites(args, threading.Event())
        self.assertTrue(report["failed"], "Removing bootstrap initialization must fail before persistence")
        self.assertEqual(report["results"][0]["name"], "early_storage")
        log = Path(report["results"][0]["log_path"]).read_text()
        self.assertIn("FAIL namespace not initialized before persistence", log)
        self.assertNotIn("EARLY STORAGE:", log)
        paths = json.loads(re.search(r"^PROGRAM SUITE PATHS: (.+)$", log, re.M)[1])
        self.assertFalse((Path(paths["user_data"]) / "early-storage.json").exists())

    def run_godot_fixture(self, cases, timeout=5):
        command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", "qa-07",
                   "--timeout", str(TEST_TIMEOUT_SECONDS), "--stream", "--", "godot", "--headless",
                   "--path", str(ROOT), "--script", "tests/program_suite_runner_test.gd", "--",
                   "--godot", str(self.godot), "--timeout", str(timeout)]
        for suite in cases:
            command.extend(["--suite", suite])
        return subprocess.run(command, env=self.environment(cases), text=True, capture_output=True,
                              timeout=TEST_TIMEOUT_SECONDS + 5)

    @unittest.skipUnless(shutil.which("godot"), "Needs Godot for the real parent fixture")
    def test_real_parent_prints_whole_logs_in_manifest_order(self):
        cases = {"slow_first": {"sleep": CASE_SLEEP_SECONDS}, "fast_second": {}, "fast_third": {}}
        result = self.run_godot_fixture(cases)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        positions = [result.stdout.index("MAIN BODY SENTINEL")]
        for suite in cases:
            positions.extend([result.stdout.index("CHILD LOG START " + suite),
                              result.stdout.index("CHILD LOG END " + suite),
                              result.stdout.index("PROGRAM SUITE " + suite + ": PASS")])
        self.assertEqual(positions, sorted(positions))
        self.assertIn("TEST RESULT: PASS", result.stdout)
        ends = [event["name"] for event in self.read_events() if event["kind"] == "end"]
        self.assertNotEqual(ends[0], "slow_first")

    @unittest.skipUnless(shutil.which("godot"), "Needs Godot for the real parent fixture")
    def test_real_parent_failure_and_timeout_fail_whole_run_and_name_child(self):
        for name, case, timeout, marker in (
            ("deliberate_failure", {"code": 7}, 5, "exit 7"),
            ("hung_child", {"sleep": 60}, 0.2, "exit 124) (timed out)"),
        ):
            with self.subTest(child=name):
                result = self.run_godot_fixture({name: case}, timeout)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("Program sub-suite failed: " + name, result.stderr)
                self.assertIn(marker, result.stderr)
                self.assertIn("PROGRAM SUITE " + name + ": FAIL", result.stdout)
                self.assertIn("TEST RESULT: FAIL (1 failure(s))", result.stdout)


if __name__ == "__main__":
    unittest.main()

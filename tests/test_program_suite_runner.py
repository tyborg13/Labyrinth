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


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools/program_suite_runner.py"
CASE_SLEEP_SECONDS = 0.25
TEST_TIMEOUT_SECONDS = 15
STARTUP_TIMEOUT_SECONDS = 5
HUNG_CHILD_TIMEOUT_SECONDS = STARTUP_TIMEOUT_SECONDS + 0.2
POLL_SECONDS = 0.02
EXTRACTED_PROGRAMS = [
    "suites/full_scene_presentation_program", "suites/full_scene_cutouts_program",
    "suites/full_scene_creature_cutouts_program", "suites/full_scene_audio_program",
    "suites/full_scene_navigation_program", "suites/full_scene_card_drag_program",
    "suites/full_scene_controls_program",
    "suites/full_scene_clock_program",
    "suites/full_scene_choices_program", "suites/full_scene_interaction_program",
]
MERGED_PROGRAMS = ["opening_boon_recovery_test", "section_map_v5_test", "section_map_v5_layout_test"]
SUPPLEMENTAL_MANIFEST = ROOT / "tests/headless_test_programs.json"
FIXTURE_TEST_TIMEOUT_SECONDS = 30
SPLIT_PROGRAMS = {
    "encounter_tables_test": [
        "suites/encounter_rules_program", "suites/encounter_placement_0_program",
        "suites/encounter_placement_1_program", "suites/encounter_placement_summary_program",
    ],
    "sfx_sync_harness": ["suites/sfx_sync_%d_program" % index for index in range(3)],
}
DEADLINE_BUDGET_SECONDS = 0.3
DEADLINE_CLEANUP_SECONDS = 0.04

sys.path.insert(0, str(ROOT / "tools"))
import program_suite_runner as runner

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
               user=os.environ['LABYRINTH_USER_DIR_NAME'], args=sys.argv[1:])
    fd = os.open(os.environ['RUNNER_TEST_EVENTS'], os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    os.write(fd, (json.dumps(row) + '\\n').encode())
    os.close(fd)
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
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.godot = self.directory / "godot"
        self.godot.write_text(FAKE_GODOT)
        self.godot.chmod(0o755)
        self.events = self.directory / "events.jsonl"
        self.report = self.directory / "report.json"

    def environment(self, cases):
        return dict(os.environ, RUNNER_TEST_CASES=json.dumps(cases), RUNNER_TEST_EVENTS=str(self.events))

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

    def assert_complete_manifest(self, actual):
        # Read the former orchestration manifests, not a second hand-maintained list.
        expected = []
        for path in ("tests/static_facing_program_suites.gd", "tests/helpers/program_sub_suites.gd"):
            source = (ROOT / path).read_text().split("const SUITES:", 1)[1].split("=", 1)[1].split("]", 1)[0]
            expected.extend(re.findall(r'"([a-z0-9_]+)"', source))
        expected = [part for name in expected for part in SPLIT_PROGRAMS.get(name, [name])]
        expected.extend(EXTRACTED_PROGRAMS)
        expected.extend(MERGED_PROGRAMS)
        supplemental = json.loads(SUPPLEMENTAL_MANIFEST.read_text())
        self.assertEqual(len(supplemental), 116, "Preserve the accepted supplemental set")
        expected.extend(program["path"].removeprefix("tests/").removesuffix(".gd") for program in supplemental)
        self.assertEqual(list(actual), expected)
        self.assertEqual(len(set(actual)), len(actual), "No child may be silently overwritten")
        for suite in EXTRACTED_PROGRAMS + [part for parts in SPLIT_PROGRAMS.values() for part in parts]:
            self.assertTrue((ROOT / "tests" / (suite + ".gd")).is_file())

    def test_manifest_preserves_all_existing_children_and_order(self):
        self.assert_complete_manifest(runner.SUITES)

    def test_removing_any_extracted_program_fails_manifest_guard(self):
        parts = EXTRACTED_PROGRAMS + [part for parts in SPLIT_PROGRAMS.values() for part in parts]
        for removed in ([name] for name in parts):
            with self.subTest(removed=removed), self.assertRaises(AssertionError):
                self.assert_complete_manifest([name for name in runner.SUITES if name not in removed])

    def test_removing_any_supplemental_or_merged_program_fails_manifest_guard(self):
        for name in [*MERGED_PROGRAMS, *runner.SUPPLEMENTAL_BY_NAME]:
            with self.subTest(removed=name), self.assertRaises(AssertionError):
                self.assert_complete_manifest([suite for suite in runner.SUITES if suite != name])

    def test_supplemental_modes_and_paths_are_guarded(self):
        for name, program in runner.SUPPLEMENTAL_BY_NAME.items():
            with self.subTest(name=name):
                self.assertEqual(program["path"], "tests/" + name + ".gd")
                self.assertTrue((ROOT / program["path"]).is_file())
                self.assertIn(program.get("mode", "script"), ("script", "cutout_pack", "roster_pack", "capture_settings"))

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
        cases = {"child_%d" % index: {"sleep": CASE_SLEEP_SECONDS, "barrier": runner.MAX_CHILDREN,
                 "barrier_timeout": STARTUP_TIMEOUT_SECONDS, "poll": POLL_SECONDS} for index in range(7)}
        result, report = self.run_scheduler(cases)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        active = peak = 0
        events = self.read_events()
        for event in events:
            active += 1 if event["kind"] == "start" else -1
            peak = max(peak, active)
        self.assertEqual(active, 0)
        self.assertEqual(peak, runner.MAX_CHILDREN)
        starts = [event for event in events if event["kind"] == "start"]
        for field in ("home", "task", "user", "appdata", "localappdata", "xdg_data", "xdg_config", "xdg_cache", "xdg_state"):
            self.assertEqual(len({event[field] for event in starts}), len(cases))
        self.assertEqual([row["name"] for row in report["results"]], list(cases))
        self.assertTrue(all(row["seconds"] > 0 for row in report["results"]))
        self.assertTrue(report["complete"])

    def test_fixture_stages_keep_one_slot_and_preserve_build_verify_arguments(self):
        cases = {"acolyte_cutout_pack_test": {}, "demo_capture_settings_test": {}, "enemy_cutout_roster_pack_test": {}}
        result, report = self.run_scheduler(cases)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        starts = [event for event in self.read_events() if event["kind"] == "start"]
        self.assertEqual(len(starts), 4)
        pack = [event for event in starts if event["name"] == "acolyte_cutout_pack_test"]
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
            result, _report = self.run_scheduler({"acolyte_cutout_pack_test": {}, "demo_capture_settings_test": {}})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        builds = [event["args"][-1] for event in self.read_events()
                  if event["kind"] == "start" and event["name"] == "acolyte_cutout_pack_test" and event["args"][-2] == "build"]
        self.assertEqual(len(set(builds)), 2)

    def test_parent_pipe_eof_cancels_active_package_stage(self):
        cases = {"acolyte_cutout_pack_test": {"sleep": 60}}
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
        command = self.command(["acolyte_cutout_pack_test", "demo_capture_settings_test", "enemy_cutout_roster_pack_test"])
        command[command.index("--godot") + 1] = shutil.which("godot")
        result = subprocess.run(command, text=True, capture_output=True, timeout=FIXTURE_TEST_TIMEOUT_SECONDS)
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
        self.assertIn("ACOLYTE CUTOUT PACK TEST RESULT: PASS (build", logs)
        self.assertIn("ACOLYTE CUTOUT PACK TEST RESULT: PASS (verify", logs)
        self.assertIn("DEMO MOVIE GUARD TEST: PASS", logs)
        self.assertIn("ENEMY CUTOUT ROSTER PACK BUILD TEST RESULT: PASS", logs)

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
        self.assertEqual(len(starts), 1, "Stub did not start within its startup budget:\n" + log)
        with self.assertRaises(ProcessLookupError):
            os.kill(starts[0]["pid"], 0)

    def test_budget_names_active_and_unstarted_children(self):
        cases = {"active": {"sleep": 60}, "pending": {}}
        result, report = self.run_scheduler(cases, "--jobs", "1", "--budget", "0.3")
        self.assertEqual(result.returncode, 1)
        self.assertEqual([row["name"] for row in report["results"]], list(cases))
        self.assertTrue(all(row["timed_out"] for row in report["results"]))
        self.assertIn("budget exhausted", report["results"][1]["reason"])
        self.assertGreater(report["results"][0]["seconds"], 0)
        self.assertEqual(report["results"][1]["seconds"], 0)
        # The total budget includes interpreter startup. On a loaded machine
        # the active wrapper can expire before its fixture writes an event.
        if self.events.exists():
            self.assertEqual([event["name"] for event in self.read_events()], ["active"])

    def assert_controlled_deadline(self, run_suites):
        class Clock:
            now = 1000.0

            def monotonic(self):
                return self.now

            def advance(self, seconds):
                self.now += seconds

        class Process:
            returncode = None

            def poll(self):
                return self.returncode

        for budget in (DEADLINE_BUDGET_SECONDS, DEADLINE_BUDGET_SECONDS * 2):
            clock = Clock()
            cancelled_at = []
            args = argparse.Namespace(project=self.directory, godot="fixture", task_id="deadline",
                                      result_file=self.report, suite=["active", "pending"],
                                      jobs=1, timeout=60, budget=budget)

            def stop(process):
                cancelled_at.append(clock.now - 1000.0)
                clock.advance(DEADLINE_CLEANUP_SECONDS)
                process.returncode = 124

            with mock.patch.object(runner.subprocess, "Popen", side_effect=lambda *a, **kw: Process()), \
                    mock.patch.dict(run_suites.__globals__, stop_wrapper=stop):
                report = run_suites(args, threading.Event(), clock=clock.monotonic, wait=clock.advance)
            self.assertEqual(len(cancelled_at), 1)
            self.assertAlmostEqual(cancelled_at[0], budget, delta=runner.POLL_SECONDS)
            self.assertLessEqual(report["seconds"], budget + DEADLINE_CLEANUP_SECONDS + runner.POLL_SECONDS)
            self.assertTrue(report["complete"] and report["failed"])
            self.assertTrue(all(row["timed_out"] for row in report["results"]))
            self.assertEqual(report["results"][1]["seconds"], 0)

    def test_cancels_at_requested_deadline_with_bounded_cleanup(self):
        self.assert_controlled_deadline(runner.run_suites)

    def test_doubling_budget_fails_controlled_deadline_guard(self):
        source = RUNNER.read_text()
        original = "deadline = started + args.budget"
        self.assertIn(original, source)
        mutated = {"__file__": str(RUNNER), "__name__": "deadline_mutation"}
        exec(compile(source.replace(original, original + " * 2", 1), str(RUNNER), "exec"), mutated)
        with self.assertRaises(AssertionError):
            self.assert_controlled_deadline(mutated["run_suites"])

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
        suites = ["sfx_sync_harness", *SPLIT_PROGRAMS["sfx_sync_harness"]]
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

    def test_worker_limit_follows_requested_logical_cpu_formula(self):
        self.assertEqual(runner.MAX_CHILDREN, min(6, max(1, (os.cpu_count() or 1) // 3)))

    def test_slots_above_worker_limit_are_rejected(self):
        result = subprocess.run(self.command(["unused"], "--jobs", str(runner.MAX_CHILDREN + 1)),
                                text=True, capture_output=True, timeout=TEST_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 2)
        self.assertIn("jobs must be 1..%d" % runner.MAX_CHILDREN, result.stderr)

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
                                  budget=10, suite=["early_storage"])
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

"""Disk bounds, single-take streaming, and failure cleanup without GUI capture."""
import copy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from tools.demo_clips import capture_setup, comparison, encode, media, pipeline, recording, storage
from test_demo_clips import SYNTHETIC_SIZE, write_synthetic_avi

SYNTHETIC_FRAMES = 6
TEST_PROVENANCE = {"synthetic": "test-only"}


def validation(output, ids):
    rows, reports = [], {}
    for clip_id in ids:
        report = {"clip": clip_id, "fps": 60, "start_frame": 0, "end_frame": SYNTHETIC_FRAMES,
                  "events": [{"kind": "action", "frame": 1}], "frames": [], "errors": [],
                  "headless": True, "fixture_valid": True, "director_sha256": "test-only"}
        logs = []
        for take in ("a", "b"):
            path = output / "validation" / take / clip_id / "events.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(report))
            logs.append(str(path))
        rows.append({"clip": clip_id, "deterministic": True, "fixture_valid": True, "errors": [], "logs": logs})
        reports[clip_id] = report
    (output / "validate-report.json").write_text(json.dumps({
        "results": rows, "failures": [], "input_hashes": TEST_PROVENANCE}))
    return reports


SYNTHETIC_SETTINGS = {"engine": "synthetic test", "mjpeg_quality": 1.0,
                      "effective_quality_setting": "editor/movie_writer/video_quality", "effective_quality": 1.0}
SYNTHETIC_LOG = ("Synthetic test capture; no GUI process launched\n"
                 "Metal 3.0 - Forward Mobile - Using Device #0: Synthetic test\n"
                 "DEMO CAPTURE SETTINGS " + json.dumps(SYNTHETIC_SETTINGS) + "\n")


def synthetic_capture(directory, report):
    write_synthetic_avi(directory / "movie.avi", report["end_frame"])
    native = dict(report, headless=False)
    (directory / "events.json").write_text(json.dumps(native))
    (directory / "godot.log").write_text(SYNTHETIC_LOG)


class DemoCaptureSetupTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("godot"), "Godot needed for Movie Maker engine API regression")
    def test_movie_writer_path_activates_real_scene_quality_verification(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            project = capture_setup.prepare_project(directory, pipeline.ROOT)
            # Actual scene guard; injected empty/nonempty engine path and real
            # OS command args without --write-movie. No dummy-frame capture.
            result = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", "demo-01", "--stream", "--",
                                     "godot", "--headless", "--path", str(project), "--fixed-fps", "60",
                                     "--script", "res://tests/demo_capture_settings_test.gd", "--", "--verify-movie-guard"],
                                    cwd=pipeline.ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            settings = [json.loads(line.removeprefix("DEMO CAPTURE SETTINGS ")) for line in result.stdout.splitlines()
                        if line.startswith("DEMO CAPTURE SETTINGS {")]
            self.assertEqual(len(settings), 2, result.stdout)
            self.assertEqual(settings[0]["effective_quality"], 1.0)
            self.assertIn("DEMO MOVIE GUARD TEST: PASS", result.stdout)

    def test_renderer_and_active_quality_are_required_in_log(self):
        proof = capture_setup.log_proof("\x1b[32m" + SYNTHETIC_LOG + "\x1b[0m")
        self.assertIn("Metal 3.0 - Forward Mobile", proof["renderer_log"])
        for bad in (SYNTHETIC_LOG.replace("Metal 3.0 - Forward Mobile", "OpenGL API - Compatibility - ANGLE Metal"),
                    SYNTHETIC_LOG.replace("Forward Mobile", "Forward+"),
                    SYNTHETIC_LOG.replace('"effective_quality": 1.0', '"effective_quality": 0.75'),
                    SYNTHETIC_LOG.split("DEMO CAPTURE SETTINGS")[0]):
            with self.subTest(log=bad), self.assertRaises(ValueError): capture_setup.log_proof(bad)

    def test_project_view_preserves_original_settings_resources_and_size_accounting(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, take = Path(tmp) / "project", Path(tmp) / "take"
            root.mkdir()
            config = b'config_version=5\n[rendering]\nrenderer/rendering_method="mobile"\n'
            (root / "project.godot").write_bytes(config)
            original = '[application]\nconfig/name="test"\n'
            (root / "override.cfg").write_text(original)
            (root / "assets").mkdir()
            (root / "assets/source.bin").write_bytes(b"x" * 1000)
            project = capture_setup.prepare_project(take, root)
            self.assertEqual((project / "project.godot").read_bytes(), config)
            self.assertEqual((root / "override.cfg").read_text(), original)
            self.assertTrue((project / "override.cfg").read_text().startswith(original))
            self.assertTrue((project / "assets").is_symlink())
            self.assertEqual(storage.output_size(take), len(config) + len((original + capture_setup.OVERRIDE).encode()))
            shutil.rmtree(project)
            self.assertTrue((root / "assets/source.bin").is_file())

    @unittest.skipUnless(shutil.which("godot"), "Godot needed for real startup settings proof")
    def test_override_is_loaded_by_godot_before_scene_startup(self):
        original = (pipeline.ROOT / "project.godot").read_bytes()
        root_override = pipeline.ROOT / "override.cfg"
        original_override = root_override.read_bytes() if root_override.exists() else None
        with tempfile.TemporaryDirectory() as tmp:
            project = capture_setup.prepare_project(Path(tmp), pipeline.ROOT)
            result = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", "demo-01", "--stream", "--",
                                     "godot", "--headless", "--path", str(project), "--script",
                                     "res://tests/demo_capture_settings_test.gd"],
                                    cwd=pipeline.ROOT, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("DEMO CAPTURE SETTINGS TEST: PASS", result.stdout)
            line = next(line for line in result.stdout.splitlines() if line.startswith("DEMO CAPTURE SETTINGS "))
            settings = json.loads(line.removeprefix("DEMO CAPTURE SETTINGS "))
            self.assertEqual(settings["mjpeg_quality"], 1.0)
            self.assertEqual(settings["effective_quality"], 1.0)
            self.assertEqual(Path(settings["override_path"]).resolve(), (project / "override.cfg").resolve())
        self.assertEqual((pipeline.ROOT / "project.godot").read_bytes(), original)
        self.assertEqual(root_override.read_bytes() if root_override.exists() else None, original_override)


class DemoAVICleanupTests(unittest.TestCase):
    def test_all_reels_must_be_probed_and_source_hashes_match_before_deletion(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            paths = [output / "raw" / clip_id / "movie.avi" for clip_id in ("first", "second")]
            for path in paths:
                path.parent.mkdir(parents=True)
                path.write_bytes(b"synthetic lifecycle fixture")
            manifest = {"failures": [], "reels": [{"probed": True}, {"probed": True}],
                        "clips": [{"clip": path.parent.name, "input_hashes": {"movie.avi": storage.file_hash(path)}} for path in paths]}
            for mutate in (lambda m: m["failures"].append("clip encode failed"),
                           lambda m: m["reels"].pop(),
                           lambda m: m["reels"][1].update(probed=False)):
                bad = copy.deepcopy(manifest)
                mutate(bad)
                self.assertEqual(encode.release_avis(output, bad, 2)["status"], "retained")
                self.assertTrue(all(path.exists() for path in paths))
            paths[1].write_bytes(b"changed source")
            with self.assertRaisesRegex(ValueError, "AVI changed before cleanup"):
                encode.release_avis(output, manifest, 2)
            self.assertTrue(all(path.exists() for path in paths))
            manifest["clips"][1]["input_hashes"]["movie.avi"] = storage.file_hash(paths[1])
            self.assertEqual(encode.release_avis(output, manifest, 2)["status"], "deleted")
            self.assertFalse(any(path.exists() for path in paths))


class DemoNativeComparisonTests(unittest.TestCase):
    def retained_weaver(self):
        case = json.loads((pipeline.ROOT / "tools/demo_clips/comparison_exemptions.json").read_text())["cases"][0]
        paths = [pipeline.ROOT / case["evidence"][key] for key in ("native_log", "headless_log")]
        if not all(path.exists() for path in paths): self.skipTest("owner's retained native/headless logs unavailable")
        return [json.loads(path.read_text()) for path in paths]

    def test_reviewed_weaver_pairs_report_presentation_exemptions(self):
        native, reference = self.retained_weaver()
        untouched, profile, exemptions = self.compare(native, reference)
        self.assertEqual(untouched, native)
        self.assertEqual(len(exemptions), 96)
        first = next(point for point in exemptions if point["item"] == "events[6]")
        self.assertEqual((first["headless_frame"], first["native_frame"], first["offset"]), (153, 200, 47))
        self.assertIn("finish_enemies()", first["cause"])
        self.assertTrue(first["code_paths"])
        with redirect_stdout(io.StringIO()) as stdout:
            recording.print_exemptions({"clip": "weaver_thornwall", "timing_exemptions": exemptions})
        self.assertIn("events[6]: H153/N200 +47", stdout.getvalue())

    def test_weaver_exemption_does_not_allow_other_frames_clips_or_payloads(self):
        native, reference = self.retained_weaver()
        for change in ("frame", "clip", "payload", "state"):
            a, b = copy.deepcopy(native), copy.deepcopy(reference)
            if change == "frame": a["events"][6]["frame"] += 1
            if change == "clip": a["clip"] = b["clip"] = "other_clip"
            if change == "payload": a["events"][6]["sample_index"] += 1
            if change == "state": a["frames"][42]["actors"]["player"]["hp"] -= 1
            with self.subTest(change=change), self.assertRaises(comparison.ComparisonError): self.compare(a, b)
        # Even matching changed states in both logs are outside this reviewed case.
        native["frames"][42]["actors"]["player"]["hp"] -= 1
        reference["frames"][42]["actors"]["player"]["hp"] -= 1
        with self.assertRaises(comparison.ComparisonError): self.compare(native, reference)

    def test_weaver_exemptions_survive_record_compare_and_encode_reports(self):
        native, reference = self.retained_weaver()
        clip_id = "weaver_thornwall"
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            validation(output, [clip_id])
            for path in (output / "validation").rglob("events.json"): path.write_text(json.dumps(reference))
            def capture(_, directory):
                (directory / "events.json").write_text(json.dumps(native))
                (directory / "godot.log").write_text(SYNTHETIC_LOG)
                (directory / "movie.avi").write_bytes(b"mocked lifecycle media")
            duration = {"intermediate": str(output / f"raw/{clip_id}/movie.avi"), "raw_frame_count": 686,
                        "start_frame": 29, "end_frame": 685, "frame_count": 656, "duration": 656 / 60}
            with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), \
                 patch.object(recording, "capture", side_effect=capture), \
                 patch.object(media, "prepare_avi", return_value={"path": duration["intermediate"], "frame_count": 686, "audio_codec": "pcm_s16le"}), \
                 patch.object(media, "duration_info", return_value=duration), \
                 patch.object(recording.sync, "audit", return_value=([], [])), \
                 patch.object(storage, "require_space", return_value=storage.MIN_FREE_BYTES), redirect_stdout(io.StringIO()):
                self.assertFalse(recording.run([{"id": clip_id}], output))
                self.assertFalse(recording.compare_all([{"id": clip_id}], output))
            recorded = json.loads((output / "record-report.json").read_text())
            compared = json.loads((output / "compare-report.json").read_text())
            audit = json.loads((output / f"raw/{clip_id}/audit.json").read_text())
            exemptions = recorded["results"][0]["timing_exemptions"]
            self.assertEqual(len(exemptions), 96)
            self.assertEqual(audit["timing_exemptions"], exemptions)
            self.assertEqual(compared["results"][0]["timing_exemptions"], exemptions)
            director = output / "director.json"
            clips = [{"id": clip_id}]
            director.write_text(json.dumps({"caption_style": {}, "reels": [{"id": "test", "clips": clips}]}))
            with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), \
                 patch.object(pipeline, "DIRECTOR", director), patch.object(pipeline, "clips", return_value=clips), \
                 patch.object(encode.sys, "argv", ["encode.py", "--output", str(output)]), \
                 patch.object(encode, "encode_clip", return_value={"clip": clip_id}), \
                 patch.object(encode, "encode_reel", return_value={"reel": "test", "probed": True}), redirect_stdout(io.StringIO()):
                self.assertFalse(encode.main())
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertEqual(manifest["clips"][0]["timing_exemptions"], exemptions)

    @staticmethod
    def reports(offset):
        reference = {"clip": "synthetic", "fps": 60, "start_frame": 10, "end_frame": 30,
                     "events": [{"kind": "action", "frame": 12, "action": ["end_turn"]},
                                {"kind": "cue", "frame": 20, "cue": "hit.claw", "sample_index": 2}],
                     "frames": [{"frame": 19, "actors": {"player": {"hp": 10}}},
                                {"frame": 20, "actors": {"player": {"hp": 6}}}],
                     "errors": [], "headless": True, "fixture_valid": True, "director_sha256": "test-only"}
        native = copy.deepcopy(reference)
        native["headless"] = False
        for field in ("start_frame", "end_frame"): native[field] += offset
        for name in ("events", "frames"):
            for row in native[name]: row["frame"] += offset
        return native, reference

    def compare(self, native, reference):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / "native.json", Path(tmp) / "headless.json"
            a.write_text(json.dumps(native)); b.write_text(json.dumps(reference))
            original = a.read_bytes()
            result = comparison.compare_native(a, b)
            self.assertEqual(a.read_bytes(), original)
            return result

    def test_constant_two_frame_lead_or_lag_preserves_native_sync_times(self):
        for offset in (-2, -1, 0, 1, 2):
            with self.subTest(offset=offset):
                native, reference = self.reports(offset)
                untouched, measured, exemptions = self.compare(native, reference)
                self.assertEqual(measured, [{"item": "start_frame", "headless_frame": 10,
                                             "native_frame": 10 + offset, "offset": offset}])
                self.assertEqual(untouched, native)
                self.assertEqual(exemptions, [])
                self.assertEqual(untouched["events"][1]["frame"], 20 + offset)

    def test_native_lead_and_lag_over_two_frames_are_rejected(self):
        for offset in (-3, 3):
            for item in ("start_frame", "end_frame", "events", "frames"):
                native, reference = self.reports(0)
                if item in ("events", "frames"):
                    native[item][0]["frame"] += offset
                else:
                    native[item] += offset
                with self.subTest(offset=offset, item=item), self.assertRaisesRegex(ValueError, "required \\[-2, \\+2\\]"):
                    self.compare(native, reference)

    def test_zero_startup_then_one_frame_lag_from_first_effect_cue_passes(self):
        native, reference = self.reports(0)
        native["end_frame"] += 1
        native["events"][1]["frame"] += 1
        native["frames"][1]["frame"] += 1
        untouched, profile, exemptions = self.compare(native, reference)
        self.assertEqual(untouched, native)
        self.assertEqual(profile, [
            {"item": "start_frame", "headless_frame": 10, "native_frame": 10, "offset": 0},
            {"item": "events[1]", "headless_frame": 20, "native_frame": 21, "offset": 1}])

    def test_lag_can_increase_twice_to_two_frames(self):
        native, reference = self.reports(1)
        native["start_frame"] -= 1
        native["events"][0]["frame"] -= 1
        native["end_frame"] += 1
        _, profile, exemptions = self.compare(native, reference)
        self.assertEqual([(p["headless_frame"], p["native_frame"], p["offset"]) for p in profile],
                         [(10, 10, 0), (19, 20, 1), (30, 32, 2)])

    def test_one_zero_zero_one_board_profile_passes(self):
        native, reference = self.reports(0)
        reference["frames"] = [{"frame": frame, "actors": {"player": {"hp": 10}}}
                               for frame in (13, 15, 16, 17)]
        native["frames"] = copy.deepcopy(reference["frames"])
        for row, offset in zip(native["frames"], (1, 0, 0, 1)): row["frame"] += offset
        native["events"][1]["frame"] += 1
        native["end_frame"] += 1
        untouched, profile, exemptions = self.compare(native, reference)
        self.assertEqual(untouched, native)
        self.assertEqual([(p["headless_frame"], p["native_frame"], p["offset"]) for p in profile],
                         [(10, 10, 0), (13, 14, 1), (15, 15, 0), (17, 18, 1)])

    def test_non_frame_payload_and_sequence_differences_are_rejected(self):
        mutations = [lambda r: r["events"][1].update(sample_index=3),
                     lambda r: r["frames"][1]["actors"]["player"].update(hp=5),
                     lambda r: r["events"].reverse(),
                     lambda r: r["frames"].pop(),
                     lambda r: r.update(fps=30),
                     lambda r: r.update(fixture_valid=False)]
        for index, mutate in enumerate(mutations):
            native, reference = self.reports(1)
            mutate(native)
            with self.subTest(mutation=index), self.assertRaisesRegex(ValueError, "DETERMINISM FAIL"):
                self.compare(native, reference)

    def test_director_float_tolerance_accepts_clock_roundoff_not_state_drift(self):
        for delta in (2e-6, 1e-2):
            native, reference = self.reports(0)
            reference["frames"][0]["progress"] = 0.25
            native["frames"][0]["progress"] = 0.25 + delta
            with self.subTest(delta=delta):
                if delta == 2e-6:
                    untouched, _, exemptions = self.compare(native, reference)
                    self.assertEqual(untouched, native)
                else:
                    with self.assertRaisesRegex(ValueError, "non-frame payload"):
                        self.compare(native, reference)


class DemoDiskGuardTests(unittest.TestCase):
    def test_eight_gb_boundary_and_no_writes_below_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "not-created"
            usage = shutil.disk_usage(tmp)
            with patch.object(storage.shutil, "disk_usage", return_value=usage._replace(free=storage.MIN_FREE_BYTES)):
                self.assertEqual(storage.require_space(output), storage.MIN_FREE_BYTES)
            with patch.object(storage.shutil, "disk_usage", return_value=usage._replace(free=storage.MIN_FREE_BYTES - 1)), \
                 patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), \
                 patch.object(recording, "capture") as capture, redirect_stdout(io.StringIO()) as stdout:
                self.assertTrue(recording.run([{"id": "first"}], output))
            self.assertFalse(output.exists())
            capture.assert_not_called()
            self.assertIn("at least 8 GB required", stdout.getvalue())
            self.assertIn("DEMO DISK START", stdout.getvalue())
            self.assertIn("DEMO DISK END", stdout.getvalue())

    def test_size_result_includes_all_artifacts_and_itself(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            (output / "movie.avi").write_bytes(b"mjpeg")
            report = {"complete": True}
            storage.write_result(output, "result.json", report)
            written = json.loads((output / "result.json").read_text())
            self.assertEqual(written["output_size_bytes"], storage.output_size(output))

    def test_failed_avi_inspection_keeps_source_and_unrelated_images(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            reports = validation(output, ["first"])
            directory = output / "raw/first"
            directory.mkdir(parents=True)
            (directory / "movie-poster.png").write_bytes(b"preserve unrelated image")
            valid = json.loads((output / "validate-report.json").read_text())["results"][0]
            with patch.object(recording, "capture", side_effect=lambda _, path: synthetic_capture(path, reports["first"])), \
                 patch.object(media, "prepare_avi", side_effect=ValueError("AVI inspection failed")):
                row = recording.record_clip("first", directory, valid, {})
            self.assertEqual(row["errors"], ["AVI inspection failed"])
            self.assertEqual(row["deleted_frame_count"], 0)
            self.assertEqual([p.name for p in directory.glob("movie*.png")], ["movie-poster.png"])
            for name in ("movie.avi", "events.json", "godot.log", "audit.json"):
                self.assertTrue((directory / name).exists())

    def test_capture_exit_120_keeps_avi_and_logs_without_extraction(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            reports = validation(output, ["first"])
            directory = output / "raw/first"
            directory.mkdir(parents=True)
            valid = json.loads((output / "validate-report.json").read_text())["results"][0]
            def fail_capture(_, path):
                synthetic_capture(path, reports["first"])
                raise ValueError("Native capture process exit 120")
            with patch.object(recording, "capture", side_effect=fail_capture), \
                 patch.object(media, "prepare_avi") as convert:
                row = recording.record_clip("first", directory, valid, {})
            convert.assert_not_called()
            self.assertEqual(row["errors"], ["Native capture process exit 120"])
            self.assertFalse(list(directory.glob("movie*.png")))
            self.assertTrue((directory / "godot.log").exists())
            self.assertTrue((directory / "movie.avi").exists())
            self.assertFalse((directory / "movie.wav").exists())


@unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "brief requires ffmpeg and ffprobe")
class DemoStreamingTests(unittest.TestCase):
    def exercise(self, output, sync_findings=False, low_before_second=False, mismatch=False, native_offset=0, unshifted_start=False, ids=None, bad_renderer=False):
        ids = ids or ["first", "second"]
        reports = validation(output, ids)
        calls = []
        def capture(clip_id, directory):
            self.assertFalse(list((output / "raw").rglob("movie*.png")))
            if calls:
                self.assertTrue((output / "raw" / calls[-1] / "movie.avi").is_file())
                self.assertTrue((output / "raw" / calls[-1] / "audit.json").is_file())
            calls.append(clip_id)
            report = copy.deepcopy(reports[clip_id])
            for field in ("start_frame", "end_frame"): report[field] += native_offset
            for name in ("events", "frames"):
                for row in report[name]: row["frame"] += native_offset
            if unshifted_start: report["start_frame"] = reports[clip_id]["start_frame"]
            if mismatch and (mismatch is True or clip_id in mismatch): report["events"][0]["frame"] += 3
            synthetic_capture(directory, report)
            if bad_renderer and clip_id == ids[0]:
                (directory / "godot.log").write_text(SYNTHETIC_LOG.replace("Metal 3.0 - Forward Mobile", "OpenGL API - Compatibility - ANGLE Metal"))
        def audit(directory, report, rules):
            self.assertTrue((directory / "movie.avi").is_file())
            self.assertFalse(list(directory.glob("movie*.png")))
            self.assertTrue((directory / "movie.wav").exists())
            self.assertEqual(report["events"][0]["frame"], 1 + native_offset)
            if sync_findings:
                return [{"cue": "hit.claw", "applicable": True, "status": "measured", "offset_status": "measured",
                         "offset_ms": 80, "flags": ["Peak offset 80 ms outside sfx-04"]},
                        {"cue": "status.bleed", "applicable": True, "status": "unmeasured", "offset_status": "unmeasured",
                         "duration_status": "unmeasured", "flags": [], "reason": "low correlation: overlap"}], ["synthetic measured offset flag"]
            return [], []
        guards = [storage.MIN_FREE_BYTES] * (len(ids) + 1)
        if low_before_second: guards[2] = storage.DiskSpaceError("at least 8 GB required")
        with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), \
             patch.object(recording, "capture", side_effect=capture), \
             patch.object(recording, "CAPTURE_SIZE", SYNTHETIC_SIZE), \
             patch.object(recording.sync, "audit", side_effect=audit), \
             patch.object(storage, "require_space", side_effect=guards), redirect_stdout(io.StringIO()) as stdout:
            failed = recording.run([{"id": clip_id} for clip_id in ids], output)
        self.assertFalse(list((output / "raw").rglob("movie*.png")))
        return failed, calls, json.loads((output / "record-report.json").read_text()), stdout.getvalue()

    def test_single_avi_take_is_audited_and_retained_until_delivery(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            failed, calls, result, stdout = self.exercise(output)
            self.assertFalse(failed)
            self.assertEqual(calls, ["first", "second"])
            self.assertTrue(result["complete"])
            self.assertEqual(result["output_size_bytes"], storage.output_size(output))
            self.assertIn("DEMO OUTPUT SIZE:", stdout)
            self.assertIn("DEMO CAPTURE TIMING", stdout)
            for clip_id in calls:
                directory, report, row = recording.checked_take(output, clip_id, result)
                self.assertFalse(report["headless"])
                self.assertEqual(row["frame_count"], SYNTHETIC_FRAMES)
                self.assertEqual(row["deleted_frame_count"], 0)
                self.assertAlmostEqual(row["duration"], 0.1)
                self.assertGreater(row["capture_wall_s"], 0)
                self.assertGreaterEqual(row["clip_wall_s"], row["capture_wall_s"])
                self.assertEqual(row["seconds_per_frame"], row["capture_wall_s"] / SYNTHETIC_FRAMES)
                self.assertIn("Metal 3.0 - Forward Mobile", row["renderer_log"])
                self.assertEqual(row["capture_settings"]["effective_quality"], 1.0)
                for name in ("movie.avi", "movie.wav", "events.json", "godot.log", "audit.json"):
                    self.assertTrue((directory / name).is_file())
            (output / "raw/first/movie.wav").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "changed after audit"):
                recording.checked_take(output, "first", result)

    def test_sync_flags_and_unmeasured_rows_do_not_block_any_take(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            failed, calls, result, stdout = self.exercise(output, sync_findings=True)
            self.assertFalse(failed)
            self.assertEqual(calls, ["first", "second"])
            self.assertTrue(result["complete"])
            self.assertEqual(result["failures"], [])
            self.assertEqual(len(result["sync_summary"]["flags"]), 2)
            self.assertEqual(len(result["sync_summary"]["unmeasured"]), 2)
            self.assertIn("DEMO SYNC SUMMARY", stdout)
            self.assertIn("low correlation: overlap", stdout)
            for clip_id in calls:
                recording.checked_take(output, clip_id, result)
                self.assertTrue((output / "raw" / clip_id / "movie.avi").exists())

    def test_native_offset_is_reported_without_retiming_sync_or_duration(self):
        for unshifted_start in (False, True):
            with self.subTest(unshifted_start=unshifted_start), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp)
                failed, calls, result, stdout = self.exercise(output, native_offset=1, unshifted_start=unshifted_start)
                self.assertFalse(failed)
                expected = [{"item": "start_frame", "headless_frame": 0,
                             "native_frame": 0 if unshifted_start else 1, "offset": 0 if unshifted_start else 1}]
                if unshifted_start:
                    expected.append({"item": "events[0]", "headless_frame": 1, "native_frame": 2, "offset": 1})
                self.assertIn("native lag profile " + comparison.format_profile(expected), stdout)
                for clip_id in calls:
                    _, report, row = recording.checked_take(output, clip_id, result)
                    self.assertEqual(row["native_frame_offset_profile"], expected)
                    self.assertEqual(report["events"][0]["frame"], 2)
                    self.assertEqual(row["start_frame"], 0 if unshifted_start else 1)
                    self.assertEqual(row["frame_count"], SYNTHETIC_FRAMES + int(unshifted_start))
                with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), redirect_stdout(io.StringIO()):
                    self.assertFalse(recording.compare_all([{"id": clip_id} for clip_id in calls], output))
                compared = json.loads((output / "compare-report.json").read_text())
                self.assertEqual(compared["failures"], [])
                self.assertEqual([row["native_frame_offset_profile"] for row in compared["results"]],
                                 [row["native_frame_offset_profile"] for row in result["results"]])

    def test_disk_guard_rechecks_before_second_clip_without_writing_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            failed, calls, result, stdout = self.exercise(output, low_before_second=True)
            self.assertTrue(failed)
            self.assertEqual(calls, ["first"])
            self.assertFalse(result["complete"])
            self.assertFalse((output / "raw/second").exists())
            self.assertIn("at least 8 GB required", stdout)

    def test_native_event_drift_fails_and_cleans_up_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            failed, calls, result, _ = self.exercise(output, mismatch=True)
            self.assertTrue(failed)
            self.assertEqual(calls, ["first", "second"])
            self.assertEqual(len(result["failures"]), 2)
            self.assertIn("DETERMINISM FAIL", result["failures"][0])
            profile = result["results"][0]["native_frame_offset_profile"]
            self.assertEqual([point["offset"] for point in profile], [0, 3, 0])
            with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), redirect_stdout(io.StringIO()):
                self.assertTrue(recording.compare_all([{"id": "first"}], output))
            compared = json.loads((output / "compare-report.json").read_text())
            self.assertEqual(compared["results"][0]["native_frame_offset_profile"], profile)
            self.assertTrue(compared["failures"])

    def test_all_twenty_one_clips_are_attempted_and_all_failures_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            ids = [f"clip_{i}" for i in range(21)]
            failed, calls, result, stdout = self.exercise(output, ids=ids, mismatch={ids[0], ids[12]})
            self.assertTrue(failed)
            self.assertEqual(calls, ids)
            self.assertEqual(len(result["results"]), 21)
            self.assertEqual(len(result["failures"]), 2)
            self.assertEqual(stdout.count("DEMO TAKE FAILURE:"), 2)
            recording.checked_take(output, ids[-1], result)

    def test_wrong_renderer_fails_clip_and_next_clip_is_still_attempted(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            failed, calls, result, stdout = self.exercise(output, bad_renderer=True)
            self.assertTrue(failed)
            self.assertEqual(calls, ["first", "second"])
            self.assertEqual(len(result["failures"]), 1)
            self.assertIn("Capture renderer proof missing", result["failures"][0])
            self.assertIsNone(result["results"][0]["seconds_per_frame"])
            recording.checked_take(output, "second", result)
            self.assertIn("DEMO CAPTURE TIMING", stdout)
            self.assertTrue((output / "raw/first/movie.avi").exists())

    def test_rerecord_replaces_only_its_own_outputs_and_cleans_interrupted_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            self.exercise(output)
            first, second = output / "raw/first", output / "raw/second"
            (first / "cue-9999.wav").write_bytes(b"stale cue")
            (first / "movie.partial.mkv").write_bytes(b"stale conversion")
            (second / "movie00000000.png").write_bytes(b"interrupted frame")
            (first / "owner-notes.txt").write_text("preserve")
            failed, calls, result, _ = self.exercise(output)
            self.assertFalse(failed)
            self.assertEqual(calls, ["first", "second"])
            self.assertFalse((first / "cue-9999.wav").exists())
            self.assertFalse((first / "movie.partial.mkv").exists())
            self.assertEqual((first / "owner-notes.txt").read_text(), "preserve")
            for clip_id in calls: recording.checked_take(output, clip_id, result)

    def test_encode_reports_findings_and_replaces_deliverables_without_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            self.exercise(output, sync_findings=True)
            director = output / "director.json"
            clips = [{"id": "first"}, {"id": "second"}]
            director.write_text(json.dumps({"caption_style": {}, "reels": [{"id": "test", "clips": clips}]}))
            for folder, names in (("clips", ("first", "second")), ("reels", ("test",))):
                (output / folder).mkdir()
                for name in names: (output / folder / f"{name}.mp4").write_bytes(b"old delivery")
            def encode_clip(directory, report, clip, style, destination, work):
                self.assertFalse(destination.exists())
                destination.write_bytes(b"replacement")
                return {"clip": clip["id"], "path": str(destination)}
            with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), \
                 patch.object(pipeline, "DIRECTOR", director), patch.object(pipeline, "clips", return_value=clips), \
                 patch.object(encode.sys, "argv", ["encode.py", "--output", str(output)]), \
                 patch.object(encode, "encode_clip", side_effect=encode_clip) as convert, \
                 patch.object(encode, "encode_reel", return_value={"reel": "test", "probed": True}), redirect_stdout(io.StringIO()) as stdout:
                self.assertFalse(encode.main())
            self.assertEqual(convert.call_count, 2)
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertEqual(manifest["failures"], [])
            self.assertEqual(len(manifest["sync_summary"]["flags"]), 2)
            self.assertEqual(len(manifest["sync_summary"]["unmeasured"]), 2)
            self.assertIn("DEMO SYNC SUMMARY", stdout.getvalue())
            self.assertIn("low correlation: overlap", stdout.getvalue())
            self.assertEqual(manifest["intermediate_cleanup"]["status"], "deleted")
            for clip in clips:
                directory = output / "raw" / clip["id"]
                self.assertFalse((directory / "movie.avi").exists())
                self.assertTrue((directory / "movie.wav").exists())
                self.assertTrue((directory / "godot.log").exists())

    def test_encode_keeps_good_clips_when_another_take_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            _, _, recorded, _ = self.exercise(output)
            recorded.update(complete=False, failures=["first: take missing"], results=recorded["results"][1:])
            (output / "record-report.json").write_text(json.dumps(recorded))
            director = output / "director.json"
            clips = [{"id": "first"}, {"id": "second"}]
            director.write_text(json.dumps({"caption_style": {}, "reels": [{"id": "test", "clips": clips}]}))
            with patch.object(pipeline, "hashes", return_value=TEST_PROVENANCE), \
                 patch.object(pipeline, "DIRECTOR", director), patch.object(pipeline, "clips", return_value=clips), \
                 patch.object(encode.sys, "argv", ["encode.py", "--output", str(output)]), \
                 patch.object(encode, "encode_clip", return_value={"clip": "second"}) as convert, \
                 patch.object(encode, "encode_reel") as reel, redirect_stdout(io.StringIO()):
                self.assertTrue(encode.main())
            self.assertEqual(convert.call_count, 1)
            self.assertEqual(convert.call_args.args[2]["id"], "second")
            reel.assert_not_called()
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertTrue(any("take is missing" in failure for failure in manifest["failures"]))
            self.assertEqual(manifest["intermediate_cleanup"]["status"], "retained")
            self.assertTrue((output / "raw/first/movie.avi").exists())
            self.assertTrue((output / "raw/second/movie.avi").exists())


if __name__ == "__main__":
    unittest.main()

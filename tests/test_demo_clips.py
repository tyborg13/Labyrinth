"""Headless encoder/measurement tests. Synthetic media is test-only."""
from array import array
from contextlib import redirect_stdout
import copy
import io
import json
import math
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import wave

from tools.demo_clips import encode, media, pipeline, sync
from tools import visual_probe_runner

SYNTHETIC_SIZE = (320, 180)
SYNTHETIC_FRAME_COUNT = 180
SYNTHETIC_LONG_STATUS_S = 1.35


def write_wave(path, samples, rate=48000, width=2):
    with wave.open(str(path), "wb") as wav:
        wav.setparams((2, width, rate, 0, "NONE", "not compressed"))
        values = array("h" if width == 2 else "i")
        for sample in samples:
            value = round(sample * (2 ** (width * 8 - 1) - 1))
            values.extend((value, value))
        wav.writeframes(values.tobytes())


def write_synthetic_avi(path, frames, source_wav=None, size=SYNTHETIC_SIZE):
    """Test-only MJPEG/PCM input; never presented as native Godot proof."""
    if source_wav is None:
        source_wav = path.parent / "synthetic-source.wav"
        write_wave(source_wav, [0.0] * (frames * 800))
    media.ffmpeg(["-f", "lavfi", "-i", f"color=c=0x0c1824:s={size[0]}x{size[1]}:r=60",
                  "-i", source_wav, "-map", "0:v:0", "-map", "1:a:0", "-frames:v", frames,
                  "-c:v", "mjpeg", "-q:v", "1", "-pix_fmt", "yuvj444p", "-c:a", "copy",
                  "-threads", "2", path])
    return source_wav


class DemoDirectorTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("godot"), "Godot needed for viewport GUI routing regression")
    def test_probe_tile_centre_reaches_production_gui_input_under_retina_stretch(self):
        import sys
        result = subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", "demo-01", "--stream", "--",
                                 "godot", "--headless", "--path", ".", "--script", "tests/demo_probe_viewport_test.gd"],
                                cwd=pipeline.ROOT, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("DEMO PROBE VIEWPORT TEST: PASS", result.stdout)
        self.assertIn("board tile (4, 4); GUI hover; Retina stretch", result.stdout)

    def test_caption_changes_preserve_take_hashes_but_recording_changes_do_not(self):
        director = json.loads(pipeline.DIRECTOR.read_text())
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            imported, protected = root / "tools/demo_clips/clips.json", root / "spec/clips.json"
            for path in (imported, protected, root / "project.godot", root / "tests/sfx_sync_sources.gd", root / "tests/sfx_sync_pacing.gd"):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture")
            def save(value):
                for path in (imported, protected): path.write_text(json.dumps(value))
            with patch.object(pipeline, "ROOT", root), patch.object(pipeline, "DIRECTOR", imported), patch.object(pipeline, "PROTECTED", protected):
                save(director)
                before = pipeline.hashes()
                command_before = pipeline.command("fire_volley", root / "take", True)
                original_encoding_hash = imported.read_bytes()
                changed = copy.deepcopy(director)
                changed["caption_style"]["position_px"] = [48, 900]
                changed["caption_style"]["subtitle_top_px"] = 944
                changed["reels"][0]["clips"][0].update(title="Changed title", subtitle="Changed subtitle")
                save(changed)
                self.assertEqual(pipeline.hashes(), before)
                self.assertEqual(pipeline.command("fire_volley", root / "take", True), command_before)
                self.assertNotEqual(imported.read_bytes(), original_encoding_hash)
                for field, value in (("enemies", [["crawler", [2, 1]]]), ("traps", [["lightning", [1, 0]]]),
                                     ("forced_intents", {"crawler": "lunge"}), ("actions", [["end_turn"]]),
                                     ("combat_speed", "fastest")):
                    capture_change = copy.deepcopy(changed)
                    capture_change["reels"][0]["clips"][0][field] = value
                    save(capture_change)
                    self.assertNotEqual(pipeline.hashes(), before, field)
                for field, value in (("music_volume", 0.5), ("tail_s", 2.0), ("seed", 123)):
                    capture_change = copy.deepcopy(changed)
                    capture_change["defaults"][field] = value
                    save(capture_change)
                    self.assertNotEqual(pipeline.hashes(), before, field)

    def test_protected_import_and_complete_clip_inventory(self):
        self.assertEqual(pipeline.DIRECTOR.read_bytes(), pipeline.PROTECTED.read_bytes())
        clips = pipeline.clips()
        self.assertEqual(len(clips), 21)
        self.assertEqual(len({c["id"] for c in clips}), 21)

    def test_determinism_compares_actions_cues_and_frames(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / "a.json", Path(tmp) / "b.json"
            report = {"clip": "fixture", "fps": 60, "start_frame": 0, "end_frame": 10,
                      "events": [{"kind": "cue", "frame": 3}], "frames": [], "errors": [], "director_sha256": "hash"}
            a.write_text(json.dumps(report)); b.write_text(json.dumps(report))
            pipeline.compare(a, b)
            report["events"][0]["frame"] = 4
            b.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, "DETERMINISM FAIL"): pipeline.compare(a, b)

    def test_record_command_is_windowed_movie_maker_and_runner_owned(self):
        cmd = pipeline.command("fire_volley", Path("/tmp/demo-test"), True)
        self.assertIn("tools/godot_task_runner.py", cmd)
        self.assertIn("--write-movie", cmd)
        self.assertIn("--windowed", cmd)
        self.assertNotIn("--headless", cmd)
        for flag in ("--rendering-method", "--rendering-driver", "--display-driver"):
            self.assertNotIn(flag, cmd)
        self.assertEqual(cmd[cmd.index("--write-movie") + 1], "/tmp/demo-test/movie.avi")
        self.assertEqual(cmd[cmd.index("--path") + 1], "/tmp/demo-test/capture-project")
        self.assertEqual(cmd[cmd.index("--fixed-fps") + 1], "60")

    def test_missing_caption_style_position_fails_without_a_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "caption_style.subtitle_top_px"):
                encode.caption_image({}, {}, Path(tmp), SYNTHETIC_SIZE)

    def test_visual_probe_uses_project_compatible_renderer_defaults(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(pipeline.subprocess, "run") as run:
            run.return_value.returncode = 0
            self.assertFalse(pipeline.probes([{"id": "fire_volley"}], Path(tmp)))
        command = run.call_args.args[0]
        self.assertNotIn("--rendering-driver", command)
        self.assertNotIn("--rendering-method", command)
        args = visual_probe_runner.build_parser().parse_args(command[2:command.index("--")])
        visual_probe_runner.resolve_probe_rendering_mode(args, pipeline.ROOT, platform="darwin", environment={})
        self.assertEqual(args.rendering_method, "mobile")
        self.assertEqual(args.rendering_driver, "metal")
        self.assertFalse(args.headless)
        self.assertEqual(args.expect_size, [(1920, 1080)])


class DemoMediaWrapperTests(unittest.TestCase):
    def test_ffmpeg_wrappers_keep_two_threads(self):
        def assert_options(command, required):
            # Presence/count assertions must run even if every option vanished.
            for flag, count in required.items():
                self.assertEqual(command.count(flag), count, flag)
            for index, flag in enumerate(command):
                if flag in required: self.assertEqual(command[index + 1], "2")

        with patch.object(media.subprocess, "run") as run:
            run.return_value.returncode = 0
            run.return_value.stdout = ""
            media.ffmpeg(["-i", "source.avi", "delivery.mp4"])
        command = run.call_args.args[0]
        assert_options(command, {"-threads": 1, "-filter_threads": 1, "-filter_complex_threads": 1})
        with patch.object(sync.subprocess, "run") as run:
            run.return_value.stdout = b""
            sync.pcm(Path("source.wav"))
        command = run.call_args.args[0]
        assert_options(command, {"-threads": 2, "-filter_threads": 1})


class DemoSyncTests(unittest.TestCase):
    def test_mixed_repeated_hits_with_unequal_correlations_are_unmeasured(self):
        self.assert_mixed_repeated_hits_unmeasured(2)

    def test_seed_7_repeated_hits_cannot_drop_the_contaminated_occurrence(self):
        self.assert_mixed_repeated_hits_unmeasured(7)

    def test_overlap_seeds_1_through_20_never_produce_a_false_measured_offset(self):
        for seed in range(1, 21):
            with self.subTest(overlap_seed=seed):
                self.assert_mixed_repeated_hits_unmeasured(seed, check_first=False)

    def test_competing_peak_below_identification_threshold_is_still_ambiguous(self):
        self.assert_mixed_repeated_hits_unmeasured(7, overlap_gain=1.25, check_first=False)

    def test_competing_peak_at_exactly_half_correlation_is_ambiguous(self):
        reference = array("f", [1.0] + [0.0] * 95)
        mix = array("f", [0.0]) * 1000
        # The first window's dot product is 1, with powers 1 and 4: r = 0.5.
        # Negative samples add energy without introducing positive cue peaks.
        mix[100:104] = array("f", [1, -1, -1, -1])
        mix[200] = 1.0
        with self.assertRaisesRegex(ValueError, "ambiguous PCM match"):
            sync.locate(mix, reference, 200 / sync.RATE)

    def assert_mixed_repeated_hits_unmeasured(self, seed, overlap_gain=0.75, check_first=True):
        rules = json.loads((pipeline.ROOT / "data/sfx_cues.json").read_text())["rules"]["sync"]
        reference, overlap = self.reference(), self.reference(seed)
        peak = sync.rms_peak(reference, rules)
        mix = array("f", [0.0]) * sync.RATE
        first = round(0.515 * sync.RATE) - peak
        second = round(0.615 * sync.RATE) - peak
        for i, value in enumerate(reference): mix[first + i] += value + overlap_gain * overlap[i]
        if overlap_gain > 1:
            # This competitor is below the 0.65 measurement threshold, but
            # above the conservative 0.5 ambiguity threshold.
            dot = sum(value * mix[first + i] for i, value in enumerate(reference))
            power = sum(value * value for value in reference)
            mixed_power = sum(mix[first + i] ** 2 for i in range(len(reference)))
            confidence = dot / math.sqrt(power * mixed_power)
            self.assertGreaterEqual(confidence, 0.5)
            self.assertLess(confidence, sync.MIN_CORRELATION)
        # The contaminated first occurrence remains identifiable on its own.
        if check_first:
            found, confidence, _ = sync.locate(mix, reference, 0.5)
            self.assertEqual(found, first)
            self.assertGreaterEqual(confidence, sync.MIN_CORRELATION)
            self.assertLess(confidence, 0.9)
        for i, value in enumerate(reference): mix[second + i] += value
        report = {"clip": "mixed_repeated_hits", "fps": 60,
                  "events": [{"cue": "hit.claw", "frame": frame, "result": "played", "pcm": "cue.wav", "pitch": 1} for frame in (30, 36)],
                  "frames": [{"frame": frame, "actors": {"player": {"hp": hp}}, "traps": [], "surfaces": []}
                             for frame, hp in ((0, 12), (30, 10), (36, 8))]}
        with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name == "movie.wav" else reference):
            rows, flags = sync.audit(Path("/synthetic"), report, rules)
        self.assertEqual(flags, [])
        self.assertEqual(len(rows), 2)
        for row in rows:
            self.assertEqual(row["offset_status"], "unmeasured")
            self.assertIn("ambiguous PCM match", row["reason"])
            self.assertNotIn("offset_ms", row)

    def test_distinct_peaks_closer_than_five_ms_are_ambiguous(self):
        reference = self.reference()
        mix = array("f", [0.0]) * 12000
        for offset in (3201, 3345):
            for i, value in enumerate(reference): mix[offset + i] += value
        with self.assertRaisesRegex(ValueError, "ambiguous PCM match"):
            sync.locate(mix, reference, 3201 / sync.RATE)

    def test_separation_uses_the_cues_autocorrelation_peak_width(self):
        broad = array("f", [0, 1, 2, 3, 2, 1, 0])
        impulse = array("f", [0, 0, 1, 0, 0, 0, 0])
        self.assertEqual(sync.correlation_peak_width([broad]), 5)
        self.assertEqual(sync.correlation_peak_width([impulse]), 1)
        self.assertEqual(sync.correlation_peak_width([broad, broad]), 5)

    def test_periodic_side_peaks_are_ambiguous_even_with_one_cue(self):
        reference = array("f", [1, -1] * 48)
        mix = array("f", [0.0]) * 1000
        mix[200:200 + len(reference)] = reference
        with self.assertRaisesRegex(ValueError, "ambiguous PCM match"):
            sync.locate(mix, reference, 200 / sync.RATE)

    def test_identical_repeated_hits_are_unmeasured_without_false_offset_flags(self):
        rules = json.loads((pipeline.ROOT / "data/sfx_cues.json").read_text())["rules"]["sync"]
        reference = self.reference()
        peak = sync.rms_peak(reference, rules)
        mix = array("f", [0.0]) * sync.RATE
        for contact in (0.5, 0.6):
            offset = round((contact + 0.015) * sync.RATE) - peak
            for i, value in enumerate(reference): mix[offset + i] += value
        report = {"clip": "repeated_hits", "fps": 60,
                  "events": [{"cue": "hit.claw", "frame": frame, "result": "played", "pcm": "cue.wav", "pitch": 1} for frame in (30, 36)],
                  "frames": [{"frame": frame, "actors": {"player": {"hp": hp}}, "traps": [], "surfaces": []}
                             for frame, hp in ((0, 12), (30, 10), (36, 8))]}
        with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name == "movie.wav" else reference):
            rows, flags = sync.audit(Path("/synthetic"), report, rules)
        self.assertEqual(flags, [])
        self.assertEqual(len(rows), 2)
        for row in rows:
            self.assertEqual(row["offset_status"], "unmeasured")
            self.assertIn("ambiguous PCM match", row["reason"])
            self.assertNotIn("offset_ms", row)

    @staticmethod
    def reference(seed=1):
        rng = random.Random(seed)
        return array("f", (rng.uniform(-1, 1) * 0.4 * math.exp(-((i - 720) / 240) ** 2) for i in range(2400)))

    def test_locates_individual_cue_despite_louder_overlapping_sound(self):
        reference = self.reference()
        other = self.reference(2)
        mix = array("f", [0.0]) * 12000
        offset = 3201
        for i, value in enumerate(reference): mix[offset+i] += value
        # A separate, much louder peak is outside the identification window.
        for i, value in enumerate(other): mix[offset+1600+i] += value * 4
        found, correlation, gain = sync.locate(mix, reference, (offset+77)/sync.RATE)
        self.assertEqual(found, offset)
        self.assertGreater(correlation, 0.99)
        self.assertAlmostEqual(gain, 1.0, places=4)

    def test_silence_is_failure_not_zero_offset(self):
        with self.assertRaisesRegex(ValueError, "cannot be separated"):
            sync.locate(array("f", [0.0]) * 12000, self.reference(), 0.3)

    def test_stereo_phase_cancellation_does_not_hide_a_cue(self):
        reference = self.reference()
        left, right = array("f", [0.0])*12000, array("f", [0.0])*12000
        for i, value in enumerate(reference): left[3201+i], right[3201+i] = value, -value
        source = sync.Stereo(reference, array("f", (-v for v in reference)))
        found, confidence, gain = sync.locate(sync.Stereo(left, right), source, 3200/sync.RATE)
        self.assertEqual(found, 3201)
        self.assertGreater(confidence, 0.99)
        self.assertAlmostEqual(gain, 1.0)

    def test_peak_uses_sfx04_window_and_earliest_near_maximum(self):
        rules = {"envelope_window_ms": 5, "alignment_peak_within_db": 2}
        signal = array("f", [0.0]) * 4000
        signal[1000], signal[3000] = 0.9, 1.0
        self.assertLess(sync.rms_peak(signal, rules), 1100)

    def test_contact_is_from_visual_state_not_audio_peak(self):
        before = {"frame": 1, "actors": {"enemy_1": {"hp": 10}}, "traps": [], "surfaces": []}
        after = copy.deepcopy(before)
        after.update(frame=8)
        after["actors"]["enemy_1"]["hp"] = 7
        self.assertEqual(sync.contacts({"frames": [before, after]})[0]["frame"], 8)

    def test_audit_flags_only_measured_desync_and_reports_unknown_contact(self):
        rules = json.loads((pipeline.ROOT/"data/sfx_cues.json").read_text())["rules"]["sync"]
        reference = self.reference()
        peak = sync.rms_peak(reference, rules)
        report = {"clip": "synthetic", "fps": 60, "events": [{"cue": "hit.claw", "frame": 30, "result": "played", "pcm": "cue.wav", "pitch": 1}],
                  "frames": [{"frame": 0, "actors": {"player": {"hp": 10}}, "traps": [], "surfaces": []},
                             {"frame": 30, "actors": {"player": {"hp": 6}}, "traps": [], "surfaces": []}]}
        for lag, expected_failure in ((0.015, False), (0.08, True)):
            mix = array("f", [0.0])*round(2.0*sync.RATE)
            offset = round((0.5+lag)*sync.RATE)-peak
            for i, value in enumerate(reference): mix[offset+i] = value
            with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name=="movie.wav" else reference):
                rows, failures = sync.audit(Path("/synthetic"), report, rules)
            self.assertEqual(bool(failures), expected_failure)
            self.assertEqual(rows[0]["status"], "measured")
            self.assertAlmostEqual(rows[0]["offset_ms"], lag*1000, delta=0.1)
        report["frames"] = []
        with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name=="movie.wav" else reference):
            rows, flags = sync.audit(Path("/synthetic"), report, rules)
        self.assertEqual(flags, [])
        self.assertEqual(rows[0]["status"], "unmeasured")
        self.assertIn("ambiguous contact", rows[0]["reason"])
        self.assertNotIn("offset_ms", rows[0])

    def test_status_duration_gate_uses_minus_40_dbfs_tail(self):
        rules = json.loads((pipeline.ROOT/"data/sfx_cues.json").read_text())["rules"]["sync"]
        rng = random.Random(410)
        reference = array("f", (rng.uniform(-1, 1)*0.03 for _ in range(round(SYNTHETIC_LONG_STATUS_S*sync.RATE))))
        # A distinct noise transient identifies this duration fixture. A tonal
        # onset has periodic correlation side peaks and is now ambiguous.
        for i in range(400): reference[i] += 0.3*rng.uniform(-1, 1)*math.exp(-((i-180)/60)**2)
        peak = sync.rms_peak(reference, rules)
        mix = array("f", [0.0])*round(3.0*sync.RATE)
        offset = round(0.515*sync.RATE)-peak
        for i, value in enumerate(reference): mix[offset+i] = value
        report = {"clip": "synthetic", "fps": 60, "events": [{"cue": "status.bleed", "frame": 30, "result": "played", "pcm": "cue.wav", "pitch": 1}],
                  "frames": [{"frame": 0, "actors": {"player": {"bleed": 0}}, "traps": [], "surfaces": []},
                             {"frame": 30, "actors": {"player": {"bleed": 1}}, "traps": [], "surfaces": []}]}
        with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name=="movie.wav" else reference):
            rows, failures = sync.audit(Path("/synthetic"), report, rules)
        self.assertGreater(rows[0]["audible_duration_s"], 1.2)
        self.assertEqual(rows[0]["duration_status"], "measured")
        self.assertTrue(any("> 1.2s" in f for f in failures))

        # Matching the onset does not establish duration when another voice
        # obscures the tail. Keep the measured offset, with no duration flag.
        for i in range(offset + round(0.2 * sync.RATE), len(mix)): mix[i] = 0
        with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name=="movie.wav" else reference):
            rows, flags = sync.audit(Path("/synthetic"), report, rules)
        self.assertEqual(rows[0]["offset_status"], "measured")
        self.assertEqual(rows[0]["duration_status"], "unmeasured")
        self.assertNotIn("audible_duration_s", rows[0])
        self.assertIn("overlap or truncation", rows[0]["duration_reason"])
        self.assertEqual(flags, [])

    def test_lightning_trap_duration_is_independent_of_contact_ambiguity(self):
        rules = json.loads((pipeline.ROOT/"data/sfx_cues.json").read_text())["rules"]["sync"]
        reference = self.reference()
        mix = array("f", [0.0]) * sync.RATE
        for i, value in enumerate(reference): mix[24000+i] = value
        items = []
        for clip_id in ("trap_enemy", "trap_hero"):
            report = {"clip": clip_id, "fps": 60, "frames": [],
                      "events": [{"cue": "trap.trigger", "frame": 30, "result": "played", "pcm": "cue.wav", "pitch": 1}]}
            with patch.object(sync, "pcm", side_effect=lambda path, pitch=1: mix if path.name=="movie.wav" else reference):
                rows, flags = sync.audit(Path("/synthetic"), report, rules)
            self.assertEqual(flags, [])
            self.assertEqual(rows[0]["status"], "measured")
            self.assertEqual(rows[0]["duration_status"], "measured")
            self.assertEqual(rows[0]["offset_status"], "unmeasured")
            self.assertGreater(rows[0]["audible_duration_s"], 0)
            items.append({"clip": clip_id, "sync_table": rows})
        summary = sync.summary(items)
        self.assertEqual([row["status"] for row in summary["trap_durations"]], ["measured", "measured"])
        with redirect_stdout(io.StringIO()) as stdout: sync.print_summary(summary)
        self.assertIn("DEMO LIGHTNING TRAP DURATION trap_enemy: measured", stdout.getvalue())
        self.assertIn("DEMO LIGHTNING TRAP DURATION trap_hero: measured", stdout.getvalue())

    def test_low_correlation_has_a_reason_and_no_invented_measurement_or_flag(self):
        rules = json.loads((pipeline.ROOT/"data/sfx_cues.json").read_text())["rules"]["sync"]
        report = {"clip": "trap_hero", "fps": 60, "frames": [],
                  "events": [{"cue": "trap.trigger", "frame": 30, "result": "played", "pcm": "cue.wav", "pitch": 1}]}
        with patch.object(sync, "pcm", return_value=self.reference()), \
             patch.object(sync, "locate", side_effect=ValueError("low correlation: Cue cannot be separated from recorded mix (correlation 0.487)")):
            rows, flags = sync.audit(Path("/synthetic"), report, rules)
        self.assertEqual(flags, [])
        self.assertEqual(rows[0]["status"], "unmeasured")
        self.assertIn("correlation 0.487", rows[0]["reason"])
        self.assertNotIn("offset_ms", rows[0])
        self.assertNotIn("audible_duration_s", rows[0])
        summary = sync.summary([{"clip": "trap_hero", "sync_table": rows}, {"clip": "trap_enemy", "sync_table": []}])
        self.assertEqual(summary["trap_durations"][0]["status"], "unmeasured")
        self.assertIn("low correlation", summary["trap_durations"][0]["reason"])
        self.assertIn("No played lightning-trap cue", summary["trap_durations"][1]["reason"])
        with redirect_stdout(io.StringIO()) as stdout: sync.print_summary(summary)
        self.assertIn("DEMO LIGHTNING TRAP DURATION trap_hero: unmeasured", stdout.getvalue())
        self.assertIn("correlation 0.487", stdout.getvalue())

    def test_trap_removal_is_a_rendered_contact(self):
        before = {"frame": 1, "actors": {}, "traps": [{"tile": "2,4"}], "surfaces": []}
        after = {"frame": 30, "actors": {}, "traps": [], "surfaces": []}
        contacts = sync.contacts({"frames": [before, after]})
        self.assertTrue(sync.contact_matches("trap.trigger", contacts[-1]))
        self.assertEqual(contacts[-1]["frame"], 30)


@unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "brief requires ffmpeg and ffprobe")
class DemoEncodingTests(unittest.TestCase):
    def test_clip_and_reel_probe_failure_preserve_existing_deliveries_atomically(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            work = root / "work"
            work.mkdir()
            clip = json.loads(pipeline.DIRECTOR.read_text())["reels"][0]["clips"][0]
            style = json.loads(pipeline.DIRECTOR.read_text())["caption_style"]
            def partial_encode(args):
                for index, flag in enumerate(args):
                    if flag == "-threads": self.assertEqual(str(args[index + 1]), "2")
                pending = next(Path(arg) for arg in args if str(arg).endswith(".mp4"))
                self.assertIn(".pending.mp4", pending.name)
                pending.write_bytes(b"partial replacement")
            clip_out, reel_out = root / "clip.mp4", root / "reel.mp4"
            for path in (clip_out, reel_out): path.write_bytes(b"existing verified delivery")
            with patch.object(media, "duration_info", return_value={"raw_frame_count": 60}), \
                 patch.object(encode, "caption_image", return_value=work / "caption.png"), \
                 patch.object(encode, "ffmpeg", side_effect=partial_encode), \
                 patch.object(encode, "probe", side_effect=ValueError("probe failed")):
                with self.assertRaisesRegex(ValueError, "probe failed"):
                    encode.encode_clip(root, {"start_frame": 0, "end_frame": 60}, clip, style, clip_out, work)
                with patch.object(encode, "join_audio"), self.assertRaisesRegex(ValueError, "probe failed"):
                    encode.encode_reel({"id": "test", "clips": [{"id": "a"}]},
                                       {"a": {"lossless_audio": "a.wav", "path": "a.mp4", "duration": 1.0, "frame_count": 60}}, reel_out, work)
            for path in (clip_out, reel_out): self.assertEqual(path.read_bytes(), b"existing verified delivery")
            self.assertFalse(list(root.glob("*.pending.mp4")))

    def test_synthetic_avi_pcm_caption_trim_and_reel(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            raw = root / "raw"
            raw.mkdir()
            size = (1920, 1080)  # Exercise the director's bottom-left coordinates.
            source = raw / "synthetic-source.wav"
            write_wave(source, (0.08*math.sin(i*2*math.pi*440/48000) for i in range(3*48000)))
            write_synthetic_avi(raw / "movie.avi", SYNTHETIC_FRAME_COUNT, source, size)
            director = json.loads(pipeline.DIRECTOR.read_text())
            clip = director["reels"][0]["clips"][0]
            report = {"start_frame": 12, "end_frame": 168}
            intermediate = media.prepare_avi(raw, size)
            self.assertEqual(intermediate["frame_count"], SYNTHETIC_FRAME_COUNT)
            self.assertEqual(intermediate["audio_codec"], "pcm_s16le")
            self.assertEqual(media.read_wave(source), media.read_wave(raw / "movie.wav"))
            self.assertFalse(list(raw.glob("movie*.png")))
            row = encode.encode_clip(raw, report, clip, director["caption_style"],
                                     root / "clip.mp4", root / "work", size)
            caption = json.loads((root / "work/fire_volley-caption.json").read_text())
            title, subtitle = caption["lines"]
            self.assertEqual((title["x"], title["y"], title["size"]), (48, 930, 34))
            self.assertEqual((subtitle["x"], subtitle["y"], subtitle["size"]), (48, 974, 24))
            self.assertEqual(row["frame_count"], 156)
            self.assertAlmostEqual(row["duration"], 2.6)
            def bright_pixels(time):
                result = subprocess.run(["ffmpeg", "-v", "error", "-threads", "2", "-ss", str(time), "-i", str(root/"clip.mp4"), "-frames:v", "1", "-vf", "format=gray", "-f", "rawvideo", "-threads", "2", "pipe:1"], capture_output=True, check=True)
                return sum(v > 90 for v in result.stdout)
            initial, fading, ended = (bright_pixels(t) for t in (0.5, 2.05, 2.4))
            self.assertGreater(initial, fading)
            self.assertGreater(fading, ended)
            self.assertEqual(ended, 0)
            second = dict(row, clip="second")
            reel = {"id": "synthetic", "clips": [clip, {"id": "second"}]}
            joined = encode.encode_reel(reel, {clip["id"]: row, "second": second}, root/"reel.mp4", root/"work")
            self.assertEqual(joined["frame_count"], 312)
            self.assertTrue(joined["probed"])
            with wave.open(str(root/"work/synthetic-reel.wav"), "rb") as wav:
                data = array("i", wav.readframes(wav.getnframes()))
            boundary = round(2.6*48000)*2
            self.assertEqual(list(data[boundary-2:boundary+2]), [0, 0, 0, 0])
            evidence = pipeline.OUTPUT / "synthetic-proof"
            evidence.mkdir(parents=True, exist_ok=True)
            (evidence.parent/".gitignore").write_text("*\n")
            (evidence.parent/".gdignore").touch()
            for source in (root/"clip.mp4", root/"reel.mp4", root/"work/fire_volley-caption.png"):
                shutil.copyfile(source, evidence/source.name)

    def test_wrong_intermediate_codec_and_short_pcm_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_synthetic_avi(root / "movie.avi", 6)
            info = media.probe(root / "movie.avi")
            info["streams"][0]["codec_name"] = "h264"
            with patch.object(media, "probe", return_value=info), self.assertRaisesRegex(ValueError, "MJPEG AVI"):
                media.prepare_avi(root, SYNTHETIC_SIZE)
            media.prepare_avi(root, SYNTHETIC_SIZE)
            write_wave(root / "movie.wav", [0.0] * 800)
            with self.assertRaisesRegex(ValueError, "audio ends before logged video"):
                media.duration_info(root, {"start_frame": 0, "end_frame": 6}, SYNTHETIC_SIZE)


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import re
import sys
import unittest

import mido


REPO_ROOT = Path(__file__).resolve().parents[1]
TRACK_ROOT = REPO_ROOT / "output" / "classical_soundtracks" / "mussorgsky_pictures_old_castle"
BUILDER_PATH = TRACK_ROOT / "scripts" / "build_main_menu_loop.py"
CONFIG_PATH = TRACK_ROOT / "track.v03.json"
V07_BUILDER_PATH = TRACK_ROOT / "scripts" / "build_main_menu_loop_v07.py"
V07_CONFIG_PATH = TRACK_ROOT / "track.v07.json"


def load_builder():
    spec = importlib.util.spec_from_file_location("old_castle_main_menu_arrangement", BUILDER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load builder at {BUILDER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_v07_builder():
    spec = importlib.util.spec_from_file_location("old_castle_main_menu_v07", V07_BUILDER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load builder at {V07_BUILDER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class OldCastleMainMenuArrangementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.builder = load_builder()
        staves, _ = cls.builder.FULL._load_source()
        cls.full_events = cls.builder.FULL._arrangement_events(staves)
        cls.cropped, cls.clipped = cls.builder._crop_base_events(cls.full_events)
        cls.high_events, cls.high_mapping = cls.builder._high_embellishments(cls.full_events)
        cls.percussion = cls.builder._percussion_events()

    def test_selection_is_the_requested_contiguous_measure_span(self) -> None:
        self.assertEqual(7, self.builder.SOURCE_START_MEASURE)
        self.assertEqual(69, self.builder.SOURCE_END_MEASURE_EXCLUSIVE)
        self.assertEqual(62, self.builder.MEASURE_COUNT)
        self.assertEqual(8640, self.builder.SOURCE_START_TICK)
        self.assertEqual(97920, self.builder.SOURCE_END_TICK)
        self.assertAlmostEqual(15.0, self.builder.SOURCE_START_TICK / 480 * 60 / 72)
        self.assertAlmostEqual(170.0, self.builder.SOURCE_END_TICK / 480 * 60 / 72)
        self.assertAlmostEqual(132.85714285714286, self.builder.TOTAL_TICKS / 480 * 60 / 84)
        self.assertTrue(all(value == 0 for value in self.clipped.values()))

    def test_every_base_event_is_an_exact_v02_crop(self) -> None:
        expected_counts = {
            "Veiled Violin / Castle Air": 188,
            "Ashen Violin / Inner Voice": 101,
            "Hollow Viola / Lower Harmony": 262,
            "Grave Cello / Troubadour": 188,
            "Undercrypt Bass / G-sharp Pedal": 262,
        }
        for track_name, count in expected_counts.items():
            with self.subTest(track=track_name):
                source = [
                    event
                    for event in self.full_events[track_name]
                    if self.builder.SOURCE_START_TICK <= event.start < self.builder.SOURCE_END_TICK
                ]
                cropped = self.cropped[track_name]
                self.assertEqual(count, len(cropped))
                self.assertEqual(len(source), len(cropped))
                self.assertEqual(
                    [
                        (event.start - self.builder.SOURCE_START_TICK,
                         event.end - self.builder.SOURCE_START_TICK,
                         event.pitch,
                         event.velocity)
                        for event in source
                    ],
                    [(event.start, event.end, event.pitch, event.velocity) for event in cropped],
                )

    def test_high_strings_are_sparse_exact_octave_doublings(self) -> None:
        self.assertEqual(20, len(self.high_events))
        self.assertEqual(
            list(self.builder.HIGH_EMBELLISHMENT_SOURCE_MEASURES),
            [entry["source_measure"] for entry in self.high_mapping],
        )
        melody_by_start = {event.start: event for event in self.full_events[self.builder.BASE_TRACKS[0]]}
        for event, mapping in zip(self.high_events, self.high_mapping, strict=True):
            source_start = (
                (mapping["source_measure"] - 1) * self.builder.MEASURE_TICKS
                + mapping["source_offset_ticks"]
            )
            source = melody_by_start[source_start]
            self.assertEqual(source.pitch + 12, event.pitch)
            self.assertEqual(source.start - self.builder.SOURCE_START_TICK, event.start)
            self.assertLessEqual(event.end - event.start, source.end - source.start)
            self.assertEqual(source.pitch % 12, event.pitch % 12)

    def test_percussion_is_quiet_regular_six_eight_background(self) -> None:
        self.assertEqual(248, len(self.percussion))
        by_measure: dict[int, list[object]] = {}
        for event in self.percussion:
            by_measure.setdefault(event.start // self.builder.MEASURE_TICKS, []).append(event)
            self.assertIn(event.pitch, (36, 41, 42))
            self.assertLessEqual(event.velocity, 58)
        self.assertEqual(set(range(62)), set(by_measure))
        for measure, events in by_measure.items():
            with self.subTest(measure=measure + 7):
                self.assertEqual([0, 480, 720, 1200], [event.start % 1440 for event in events])
                self.assertEqual([36, 42, 41, 42], [event.pitch for event in events])

    def test_midi_tracks_channels_counts_tempo_and_loop_markers(self) -> None:
        midi = mido.MidiFile(TRACK_ROOT / "versions" / "v03" / "arrangement.mid")
        self.assertEqual(8, len(midi.tracks))
        self.assertEqual(480, midi.ticks_per_beat)
        names = [self.builder.FULL._meta_events(track) for track in midi.tracks]
        track_names = [
            next(message.name for _, message in events if message.type == "track_name")
            for events in names
        ]
        self.assertEqual(
            ["Conductor / Main Menu Loop Map", *self.builder.MUSICAL_TRACKS, self.builder.PERCUSSION_TRACK],
            track_names,
        )
        conductor = [message for _, message in names[0]]
        self.assertTrue(any(message.type == "set_tempo" and message.tempo == mido.bpm2tempo(84) for message in conductor))
        markers = [message.text for message in conductor if message.type == "marker"]
        self.assertEqual(
            ["LOOP_START / source printed m7 / v02 0:15", "LOOP_END / before source printed m69 / v02 2:50"],
            markers,
        )
        for track in midi.tracks[1:7]:
            channels = {message.channel for message in track if hasattr(message, "channel")}
            self.assertNotIn(9, channels)
        percussion_channels = {
            message.channel
            for message in midi.tracks[7]
            if message.type in ("note_on", "note_off")
        }
        self.assertEqual({9}, percussion_channels)

    def test_normalized_score_and_config_are_audition_only(self) -> None:
        xml_path = TRACK_ROOT / "versions" / "v03" / "normalized" / "full_score.musicxml"
        text = xml_path.read_text(encoding="utf-8")
        self.assertEqual(1, text.count("<encoding-date>2026-08-26</encoding-date>"))
        score_part_ids = re.findall(r'<score-part id="([^"]+)">', text)
        part_ids = re.findall(r'<part id="([^"]+)">', text)
        self.assertEqual(["P1", "P2", "P3", "P4", "P5", "P6"], score_part_ids)
        self.assertEqual(score_part_ids, part_ids)
        for part_xml in re.findall(r'<part id="[^"]+">(.*?)</part>', text, flags=re.DOTALL):
            self.assertEqual(62, len(re.findall(r'<measure\b[^>]*\bnumber="', part_xml)))
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        self.assertEqual("audition", config["approval"]["status"])
        self.assertEqual({}, config["expected_outputs"])
        self.assertEqual(84, config["render"]["tempo_qpm"])
        self.assertAlmostEqual(60 / 84, config["render"]["crossfade_seconds"])

    def test_prior_audition_trees_remain_byte_for_byte_unchanged(self) -> None:
        self.assertEqual(
            self.builder.EXPECTED_PREVIOUS_VERSION_HASHES,
            self.builder._verify_previous_versions(),
        )


class OldCastleApprovedIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.builder = load_v07_builder()
        cls.config = json.loads(V07_CONFIG_PATH.read_text(encoding="utf-8"))

    def test_v07_preserves_the_approved_v06_music_byte_for_byte(self) -> None:
        v06_midi = TRACK_ROOT / "versions" / "v06" / "arrangement.mid"
        v07_midi = TRACK_ROOT / "versions" / "v07" / "arrangement.mid"
        self.assertEqual(v06_midi.read_bytes(), v07_midi.read_bytes())
        self.assertEqual(
            "87ee823295e323dd8661361180af30ba5969e3c3dbe9413e0d0032681cb1ac5c",
            self.config["arrangement"]["midi_sha256"],
        )
        self.assertEqual("approved", self.config["approval"]["status"])
        self.assertEqual("v07", self.config["approval"]["version"])

    def test_v07_is_strictly_verified_and_promoted_without_byte_drift(self) -> None:
        report = json.loads(
            (TRACK_ROOT / "versions" / "v07" / "VERIFICATION.json").read_text(encoding="utf-8")
        )
        expected_hash = self.config["expected_outputs"]["ogg_sha256"]
        preview = TRACK_ROOT / "versions" / "v07" / "preview.ogg"
        promoted = REPO_ROOT / "assets" / "audio" / "music" / "mussorgsky_old_castle_main_menu.ogg"
        self.assertTrue(report["ok"])
        self.assertEqual(expected_hash, FileHash.sha256(preview))
        self.assertEqual(preview.read_bytes(), promoted.read_bytes())
        ratios = report["audio"]["decoded_loop_metrics"]["ogg"]["seam_to_p99_9_ratio"]
        self.assertLessEqual(max(ratios), self.config["verification"]["max_loop_seam_to_p99_9_ratio"])

    def test_v07_builder_keeps_every_prior_version_immutable(self) -> None:
        preserved = self.builder._verify_preserved_versions()
        self.assertIn("v06", preserved)
        self.assertEqual(
            "57fabef2f4298b22ef7477e18b261702152483c9cb7aabe43acd99ece952fdc8",
            self.config["expected_outputs"]["ogg_sha256"],
        )


class FileHash:
    @staticmethod
    def sha256(path: Path) -> str:
        import hashlib

        return hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main()

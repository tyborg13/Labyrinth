from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import re
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TRACK_ROOT = REPO_ROOT / "output" / "classical_soundtracks" / "mussorgsky_pictures_old_castle"
BUILDER_PATH = TRACK_ROOT / "scripts" / "build_full_arrangement.py"
CONFIG_PATH = TRACK_ROOT / "track.v02.json"


def load_builder():
    spec = importlib.util.spec_from_file_location("old_castle_full_arrangement", BUILDER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load builder at {BUILDER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class OldCastleFullArrangementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.builder = load_builder()
        cls.staves, cls.source_report = cls.builder._load_source()
        cls.events = cls.builder._arrangement_events(cls.staves)

    def test_complete_movement_boundaries_and_source_counts(self) -> None:
        self.assertEqual(107, self.source_report["measure_count"])
        self.assertEqual(274080, self.source_report["movement_start_tick"])
        self.assertEqual(428160, self.source_report["movement_end_tick"])
        self.assertEqual(430560, self.source_report["next_movement_tick"])
        self.assertEqual(
            {"treble": 575, "bass": 593},
            self.source_report["source_staff_note_counts"],
        )
        self.assertEqual(
            107,
            self.source_report["anchors"]["final_fermata_rest_measure"],
        )

    def test_every_printed_system_and_opening_lament_are_anchored(self) -> None:
        anchors = self.source_report["anchors"]
        self.assertEqual(
            [1, 7, 13, 19, 25, 31, 38, 44, 50, 57, 63, 70, 76, 82, 89, 96, 102],
            [entry["measure"] for entry in anchors["printed_system_anchors"]],
        )
        self.assertEqual(20, len(anchors["opening_melody_anchors"]))
        ornament = [
            entry
            for entry in anchors["opening_melody_anchors"]
            if entry["measure"] == 9 and entry["offset_ticks"] in (767, 815)
        ]
        self.assertEqual(
            [
                {"measure": 9, "offset_ticks": 767, "pitches": ["A#4"]},
                {"measure": 9, "offset_ticks": 815, "pitches": ["G#4"]},
            ],
            ornament,
        )
        self.assertEqual(
            {
                "measure": 106,
                "treble_pitches": ["G#4", "G#5"],
                "bass_pitches": ["G#2", "D#3", "B3"],
            },
            anchors["final_cadence"],
        )

    def test_five_voice_reduction_counts_and_range(self) -> None:
        self.assertEqual(
            {
                "Veiled Violin / Castle Air": 291,
                "Ashen Violin / Inner Voice": 160,
                "Hollow Viola / Lower Harmony": 438,
                "Grave Cello / Troubadour": 291,
                "Undercrypt Bass / G-sharp Pedal": 438,
            },
            {name: len(events) for name, events in self.events.items()},
        )
        movement_ticks = 107 * 1440
        for track_name, events in self.events.items():
            with self.subTest(track=track_name):
                self.assertTrue(events)
                self.assertTrue(all(0 <= event.start < event.end <= movement_ticks for event in events))
                self.assertFalse(any(event.start >= 106 * 1440 for event in events))

    def test_v01_audition_is_byte_for_byte_unchanged(self) -> None:
        self.assertEqual(
            self.builder.EXPECTED_V01_HASHES,
            self.builder._verify_v01_unchanged(),
        )

    def test_generated_musicxml_has_stable_unique_part_ids_and_107_measures(self) -> None:
        path = TRACK_ROOT / "versions" / "v02" / "normalized" / "full_score.musicxml"
        text = path.read_text(encoding="utf-8")
        self.assertEqual(1, text.count("<encoding-date>2026-08-26</encoding-date>"))
        score_part_ids = re.findall(r'<score-part id="([^"]+)">', text)
        part_ids = re.findall(r'<part id="([^"]+)">', text)
        self.assertEqual(["P1", "P2", "P3", "P4", "P5"], score_part_ids)
        self.assertEqual(score_part_ids, part_ids)
        for part_xml in re.findall(r'<part id="[^"]+">(.*?)</part>', text, flags=re.DOTALL):
            self.assertEqual(107, len(re.findall(r'<measure\b[^>]*\bnumber="', part_xml)))

    def test_config_uses_cc0_symbolic_source_and_no_omr_inputs(self) -> None:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        self.assertEqual("cc0", config["source"]["rights_basis"])
        self.assertEqual(self.builder.EXPECTED_SOURCE_MIDI_SHA256, config["source"]["sha256"])
        self.assertIn("PDMX", config["source"]["source_format"])
        self.assertEqual(5, config["reproducibility"]["expected_part_count"])
        self.assertNotIn("omr_raw", BUILDER_PATH.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()

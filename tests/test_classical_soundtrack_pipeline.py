from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = REPO_ROOT / "tools"
CONFIG = REPO_ROOT / "output" / "schubert_d810_movement_ii_retro_poc" / "driving_tactical_loop.track.json"
BANK_DIR = REPO_ROOT / "assets" / "audio" / "instruments" / "classical_dark_fantasy_v1"

EXPECTED_SAMPLE_HASHES = {
    "veiled_violin": "c683d2911eba6adb35e58027b1dd363f5057996a789f06f8a4aa604d9092ffc8",
    "ashen_violin": "61582413be61cd25d182bdb1645c83af6b663070d9be9730525a02bc1ec890a0",
    "hollow_viola": "9cac0ff97b72b9822e4774fdd4d270b8f4b719f5662e27035519715b07f70c74",
    "grave_cello": "17eb59965eabbe0a910585f100296ce56cd868884d440139a3b5c7b13df40f09",
    "undercrypt_bass": "2b1a1a07e74969533c0ef2766602633fcb6180a12ae6fa3dddc6dbdb1264679e",
    "umbra_war_drum": "6286624ce4b2bf0f8f372a524217846a7096bb9f453dea8b60f69d3207f346ea",
    "bone_tom": "3789e4f0aec579f355416bc05cea5758f018b528ae7db37069100b221f0432ec",
    "ash_tick": "1d2eff817f2e52e2b7ffa177914a6c2b33cc534b4f34b53bbefa1b469837aeb7",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def audio_dependencies_available() -> bool:
    if sys.version_info < (3, 12) or not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        return False
    try:
        __import__("mido")
        __import__("numpy")
        __import__("music21")
    except ImportError:
        return False
    return True


class ClassicalSoundtrackPipelineTests(unittest.TestCase):
    def test_checked_in_bank_has_approved_sample_hashes(self) -> None:
        manifest = json.loads((BANK_DIR / "bank_manifest.json").read_text(encoding="utf-8"))
        actual = {sample["bank_id"]: sha256(BANK_DIR / sample["path"]) for sample in manifest["samples"]}
        self.assertEqual(EXPECTED_SAMPLE_HASHES, actual)
        self.assertIn("No recording, sample pack, SoundFont, ROM, model output", manifest["provenance"])

    @unittest.skipUnless(audio_dependencies_available(), "requires pinned Python 3.12 audio environment")
    def test_bank_generator_is_deterministic(self) -> None:
        sys.path.insert(0, str(TOOLS_DIR))
        try:
            from classical_soundtrack_pipeline.bank import generate_bank

            with tempfile.TemporaryDirectory() as temporary:
                destination = Path(temporary)
                manifest = generate_bank(destination)
                actual = {sample["bank_id"]: sha256(destination / sample["path"]) for sample in manifest["samples"]}
                self.assertEqual(EXPECTED_SAMPLE_HASHES, actual)
                first_manifest = (destination / "bank_manifest.json").read_bytes()
                generate_bank(destination)
                self.assertEqual(first_manifest, (destination / "bank_manifest.json").read_bytes())
        finally:
            sys.path.remove(str(TOOLS_DIR))

    @unittest.skipUnless(audio_dependencies_available(), "requires pinned Python 3.12 audio environment")
    def test_scaffold_is_rights_locked_and_non_overwriting(self) -> None:
        sys.path.insert(0, str(TOOLS_DIR))
        try:
            from classical_soundtrack_pipeline.common import PipelineError, read_json, verify_source_clearance
            from classical_soundtrack_pipeline.scaffold import create_scaffold

            with tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                created = create_scaffold(root, "Test Op. 1", "Test Work", "Test Composer", BANK_DIR / "bank_manifest.json")
                config_path = created / "track.json"
                self.assertEqual("source_required", read_json(config_path)["source"]["rights_status"])
                with self.assertRaises(PipelineError):
                    verify_source_clearance(read_json(config_path), config_path)
                with self.assertRaises(PipelineError):
                    create_scaffold(root, "Test Op. 1", "Other", "Other", BANK_DIR / "bank_manifest.json")
        finally:
            sys.path.remove(str(TOOLS_DIR))

    @unittest.skipUnless(audio_dependencies_available(), "requires pinned Python 3.12 audio environment")
    def test_provenance_gate_rejects_mismatches_and_placeholder_licenses(self) -> None:
        sys.path.insert(0, str(TOOLS_DIR))
        try:
            from classical_soundtrack_pipeline.common import PipelineError, read_json, verify_source_clearance

            original = read_json(CONFIG)
            verify_source_clearance(original, CONFIG)
            for key in ("composer", "composition", "source_format", "license_evidence", "composition_public_domain_evidence"):
                mutated = copy.deepcopy(original)
                mutated["source"][key] = "Deliberate evidence mismatch"
                with self.subTest(key=key), self.assertRaises(PipelineError):
                    verify_source_clearance(mutated, CONFIG)
            for license_value in ("TODO", "unknown", "proprietary", "all rights reserved", "not CC0", "not public domain", "CC0 status pending"):
                mutated = copy.deepcopy(original)
                mutated["source"]["transcription_license"] = license_value
                with self.subTest(license=license_value), self.assertRaises(PipelineError):
                    verify_source_clearance(mutated, CONFIG)
            for rights_basis in ("", "copyrighted", "cc_by"):
                mutated = copy.deepcopy(original)
                mutated["source"]["rights_basis"] = rights_basis
                with self.subTest(rights_basis=rights_basis), self.assertRaises(PipelineError):
                    verify_source_clearance(mutated, CONFIG)
        finally:
            sys.path.remove(str(TOOLS_DIR))

    @unittest.skipUnless(audio_dependencies_available(), "requires pinned Python 3.12 audio environment")
    def test_normalizer_writes_full_score_and_separate_parts(self) -> None:
        sys.path.insert(0, str(TOOLS_DIR))
        try:
            from music21 import instrument, note, stream
            from classical_soundtrack_pipeline.normalization import write_normalized_score

            score = stream.Score()
            for name, pitch in (("Violin I", "D5"), ("Cello", "D3")):
                part = stream.Part()
                part.partName = name
                part.insert(0, instrument.fromString(name))
                measure = stream.Measure(number=1)
                measure.append(note.Note(pitch, quarterLength=4.0))
                part.append(measure)
                score.insert(0, part)
            with tempfile.TemporaryDirectory() as temporary:
                report = write_normalized_score(score, Path(temporary), expand_repeats=False)
                self.assertEqual(2, report["part_count"])
                self.assertTrue(Path(report["full_score_musicxml"]).is_file())
                self.assertTrue(Path(report["full_score_midi"]).is_file())
                self.assertEqual(2, len(list((Path(temporary) / "parts").glob("*.musicxml"))))
                self.assertEqual(2, len(list((Path(temporary) / "parts").glob("*.mid"))))
        finally:
            sys.path.remove(str(TOOLS_DIR))

    @unittest.skipUnless(audio_dependencies_available(), "requires pinned Python 3.12 audio environment")
    def test_reference_render_and_verifier_match_approved_outputs(self) -> None:
        encoders = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], check=True, capture_output=True, text=True).stdout
        if " vorbis " not in encoders:
            self.skipTest("approved Ogg requires FFmpeg's native Vorbis encoder")
        sys.path.insert(0, str(TOOLS_DIR))
        try:
            from classical_soundtrack_pipeline.common import PipelineError, assert_publishable, publish_immutable
            from classical_soundtrack_pipeline.promote import promote_track
            from classical_soundtrack_pipeline.render import render_track
            from classical_soundtrack_pipeline.verify import _validate_loop_seam, verify_track

            with tempfile.TemporaryDirectory() as temporary:
                output = Path(temporary)
                report = render_track(CONFIG, output)
                self.assertEqual("bb0a7c9b30883e87f0d2c0be88fd11844056ce40c628860950a02fc51677403b", report["audio"]["ogg_sha256"])
                self.assertEqual("722be73cd85a4c69618ffa3b66c3f0b1f98ab91dd3ace78772c04c0f1ac8c18b", report["audio"]["flac_sha256"])
                verification = verify_track(CONFIG, output)
                self.assertTrue(verification["ok"])
                self.assertEqual(736, verification["midi"]["note_counts"]["Funeral Pulse / Procedural Percussion"])
                self.assertIn("ogg", verification["audio"]["decoded_loop_metrics"])

                promoted = output / "promoted.ogg"
                promotion = promote_track(CONFIG, output, promoted)
                self.assertTrue(promotion["ok"])
                self.assertEqual(report["audio"]["ogg_sha256"], sha256(promoted))

                config = json.loads(CONFIG.read_text(encoding="utf-8"))
                config["approval"]["status"] = "audition"
                rejected_config = output / "unapproved.track.json"
                rejected_config.write_text(json.dumps(config), encoding="utf-8")
                rejected_asset = output / "must_not_promote.ogg"
                with self.assertRaises(PipelineError):
                    promote_track(rejected_config, output, rejected_asset)
                self.assertFalse(rejected_asset.exists())

                candidate = output / "candidate.bin"
                protected = output / "existing_audition.bin"
                candidate.write_bytes(b"new candidate")
                protected.write_bytes(b"approved audition")
                with self.assertRaises(PipelineError):
                    assert_publishable(candidate, protected, "audition artifact")
                self.assertEqual(b"approved audition", protected.read_bytes())

                concurrent = output / "concurrently_created.bin"
                assert_publishable(candidate, concurrent, "audition artifact")
                concurrent.write_bytes(b"different concurrent bytes")
                with self.assertRaises(PipelineError):
                    publish_immutable(candidate, concurrent, "audition artifact")
                self.assertEqual(b"different concurrent bytes", concurrent.read_bytes())

                game_asset = output / "existing_game_asset.ogg"
                game_asset.write_bytes(b"different game asset")
                with self.assertRaises(PipelineError):
                    promote_track(CONFIG, output, game_asset)
                self.assertEqual(b"different game asset", game_asset.read_bytes())

                bad_seam = {
                    "first_last_sample_delta": [0.5, 0.4],
                    "p99_9_adjacent_sample_delta": [0.01, 0.01],
                }
                with self.assertRaises(PipelineError):
                    _validate_loop_seam(bad_seam, 1.0, "deliberately bad fixture")
        finally:
            sys.path.remove(str(TOOLS_DIR))


if __name__ == "__main__":
    unittest.main()

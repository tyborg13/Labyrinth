from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TRACK_ROOT = REPO_ROOT / "output" / "classical_soundtracks" / "chopin_op35_funeral_march"
V05_BUILDER_PATH = TRACK_ROOT / "scripts" / "build_arrangement_v05.py"
V05_CONFIG_PATH = TRACK_ROOT / "track.v05.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_v05_builder():
    spec = importlib.util.spec_from_file_location("chopin_death_music_v05", V05_BUILDER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load builder at {V05_BUILDER_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class ChopinDeathMusicApprovedIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.builder = load_v05_builder()
        cls.config = json.loads(V05_CONFIG_PATH.read_text(encoding="utf-8"))

    def test_v05_preserves_the_owner_approved_v04_music_byte_for_byte(self) -> None:
        v04 = TRACK_ROOT / "versions" / "v04"
        v05 = TRACK_ROOT / "versions" / "v05"
        self.assertEqual((v04 / "arrangement.mid").read_bytes(), (v05 / "arrangement.mid").read_bytes())
        self.assertEqual((v04 / "preview.flac").read_bytes(), (v05 / "preview.flac").read_bytes())
        self.assertEqual((v04 / "preview.ogg").read_bytes(), (v05 / "preview.ogg").read_bytes())
        self.assertEqual("approved", self.config["approval"]["status"])
        self.assertEqual("v05", self.config["approval"]["version"])
        self.assertEqual("native", self.config["render"]["vorbis_encoder"])

    def test_v05_is_strictly_verified_and_promoted_without_byte_drift(self) -> None:
        v05 = TRACK_ROOT / "versions" / "v05"
        verification = json.loads((v05 / "VERIFICATION.json").read_text(encoding="utf-8"))
        preview = v05 / "preview.ogg"
        promoted = REPO_ROOT / "assets" / "audio" / "music" / "chopin_op35_funeral_march_death_loop.ogg"
        expected_hash = self.config["expected_outputs"]["ogg_sha256"]
        self.assertTrue(verification["ok"])
        self.assertEqual("f005bda46c395579b32f0afeb749b5e16775efa2ecee5203e2a4bacd872b2569", expected_hash)
        self.assertEqual(expected_hash, sha256(preview))
        self.assertEqual(preview.read_bytes(), promoted.read_bytes())
        ratios = verification["audio"]["decoded_loop_metrics"]["ogg"]["seam_to_p99_9_ratio"]
        self.assertLessEqual(max(ratios), self.config["verification"]["max_loop_seam_to_p99_9_ratio"])

    def test_v05_builder_proves_v04_remains_immutable(self) -> None:
        preserved = self.builder._verify_v04_is_untouched()
        self.assertEqual(self.builder.EXPECTED_V04_VERSION_HASHES, preserved)
        report = json.loads(
            (TRACK_ROOT / "versions" / "v05" / "BUILD_REPORT.json").read_text(encoding="utf-8")
        )
        self.assertTrue(report["musical_content"]["midi_byte_for_byte_equal_to_v04"])
        self.assertEqual("none", report["musical_content"]["musical_changes_from_v04"])


if __name__ == "__main__":
    unittest.main()

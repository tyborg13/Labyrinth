"""Director-owned inputs must be installed without any content changes."""
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
STAGED = ROOT / "spec/peer_benchmark/staged/spx"
UNSAFE_TYPED_ARRAY = re.compile(r"\b(?:var|const)\s+\w+\s*:\s*Array\[[^\]]+\]\s*=\s*\[")


class SpecialEncounterAssetsTest(unittest.TestCase):
    def test_catalog_is_byte_identical(self):
        self.assertEqual((ROOT / "data/special_encounters.json").read_bytes(),
                         (STAGED / "special_encounters.json").read_bytes())

    def test_emblems_and_provenance_are_byte_identical(self):
        destination = ROOT / "assets/art/icons/map"
        self.assertEqual((destination / "provenance.json").read_bytes(),
                         (STAGED / "emblems/provenance.json").read_bytes())
        provenance = json.loads((destination / "provenance.json").read_text())
        for filename, entry in provenance["files"].items():
            with self.subTest(filename=filename):
                content = (destination / filename).read_bytes()
                self.assertEqual(content, (STAGED / "emblems" / filename).read_bytes())
                self.assertEqual(hashlib.sha256(content).hexdigest(), entry["sha256"])


class SpecialEncounterWindowsArrayTest(unittest.TestCase):
    def test_special_reward_helper_and_new_scripts_use_safe_typed_arrays(self):
        engine = (ROOT / "scripts/run_engine.gd").read_text()
        helper = re.search(r"(?ms)^func _special_rarity_floor\(.*?(?=^func |\Z)", engine)
        self.assertIsNotNone(helper)
        sources = {"run_engine.gd::_special_rarity_floor": helper.group()}
        for path in (
            "scripts/special_encounter_library.gd",
            "tests/helpers/special_placement_regressions.gd",
            "tests/helpers/special_map_proof_fixture.gd",
            "tests/suites/special_encounter_suite.gd",
            "tests/special_encounter_test.gd",
            "tests/special_encounter_legend_test.gd",
            "tests/special_encounter_probe.gd",
        ):
            sources[path] = (ROOT / path).read_text()
        for path, source in sources.items():
            with self.subTest(path=path):
                self.assertIsNone(UNSAFE_TYPED_ARRAY.search(source), path)

    def test_guard_rejects_the_reviewed_windows_regression(self):
        self.assertIsNotNone(UNSAFE_TYPED_ARRAY.search("var weighted: Array[String] = []"))
        self.assertIsNone(UNSAFE_TYPED_ARRAY.search("var weighted: Array[String]"))


if __name__ == "__main__":
    unittest.main()

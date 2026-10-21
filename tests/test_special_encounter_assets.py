"""Director-owned inputs must be installed without any content changes."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
STAGED = ROOT / "spec/peer_benchmark/staged/spx"


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


if __name__ == "__main__":
    unittest.main()

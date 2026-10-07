from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST = REPO_ROOT / "spec/assets/visible_gear_slice/outputs.json"
REGISTRY = REPO_ROOT / "assets/units/protagonist_cutout/gear_visuals.json"


class GearVisualAssetTest(unittest.TestCase):
    def test_sources_match_recorded_digests(self) -> None:
        manifest = json.loads(MANIFEST.read_text())
        self.assertTrue(manifest)
        for output, record in manifest.items():
            source = REPO_ROOT / record["source"]
            self.assertTrue(source.exists(), record["source"])
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), record["source_sha256"], output)

    def test_shipped_textures_are_current_derivations(self) -> None:
        result = subprocess.run([sys.executable, str(REPO_ROOT / "tools/process_gear_visual_assets.py"), "--check"],
                                capture_output=True, text=True, cwd=REPO_ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_every_registered_gear_file_is_a_derived_output(self) -> None:
        manifest = json.loads(MANIFEST.read_text())
        registry = json.loads(REGISTRY.read_text())
        for item_id, entry in registry["items"].items():
            for facing, ops in entry.get("facings", {}).items():
                for op in ops.get("replace", []) + ops.get("attach", []):
                    path = f"assets/units/protagonist_cutout/{op['file']}"
                    self.assertIn(path, manifest, f"{item_id}/{facing}")


if __name__ == "__main__":
    unittest.main()

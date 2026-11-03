"""One approved-asset inventory and production-only resource/rig smoke."""
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tests/approved_asset_pins.json"
MANIFEST_HELPER_TIMEOUT_SECONDS = 30


def check_animated_sheets(test, manifest):
    # B8: shipped elemental torches must contain distinct approved frames.
    for row in manifest["animated_sheets"]:
        with Image.open(ROOT / row["path"]) as sheet:
            width, height = row["frame_size"]
            test.assertEqual(sheet.size, (width * row["columns"], height * row["rows"]))
            frames = {sheet.crop((x*width, y*height, (x+1)*width, (y+1)*height)).tobytes()
                      for y in range(row["rows"]) for x in range(row["columns"])}
            test.assertGreaterEqual(len(frames), row["minimum_unique_frames"], row["path"])


def check_pins(test, manifest, root=ROOT):
    expected = manifest["files"]
    scopes = manifest["approval_source"]["inventory_scopes"]
    actual = {path.relative_to(root).as_posix() for base, suffixes in scopes.items()
              for path in (root / base).rglob("*") if path.is_file() and path.suffix in suffixes}
    test.assertEqual(actual, set(expected), "Approved asset inventory mismatch (owner approval required)")
    for name, digest in expected.items():
        data = (root / name).read_bytes()
        observed = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        test.assertEqual(observed, digest, "Changed approved asset: " + name)
    for name, row in manifest["images"].items():
        with Image.open(root / name) as image:
            test.assertEqual(list(image.size), row["size"], name)
            test.assertEqual(list(image.convert("RGBA").getchannel("A").getbbox() or ()), row["alpha_bounds"], name)
    for row in manifest["roster"]:
        for name in row["layouts"].values():
            test.assertTrue((root / name).is_file(), name)
        if "motion" in row:
            motion = json.loads((root / row["motion"]).read_text())
            test.assertEqual(set(motion["clips"]), set(row["clips"]), row["actor"])
    # B5: independent live two-sole midpoint, plus the approved owner nudge.
    row = manifest["mirror_sole"]
    for view in ("front", "rear"):
        layout = json.loads((root / row["root"] / (view + ".json")).read_text())
        parts = {part["name"]: part for part in layout["parts"]}
        contacts = []
        for name in row["foot_parts"]:
            part = parts[name]
            with Image.open(root / row["root"] / part["file"]) as image:
                rgba = image.convert("RGBA")
            opaque = [(x, y) for y in range(rgba.height) for x in range(rgba.width)
                      if rgba.getpixel((x, y))[3] == row["opaque_alpha"]]
            test.assertTrue(opaque, view + ": opaque sole")
            bottom = max(y for _, y in opaque)
            sole = [(x, y) for x, y in opaque if y > bottom - row["sole_rows"]]
            contacts.append(tuple(part["offset"][axis] + sum(point[axis] + row["pixel_center_offset"]
                                  for point in sole) / len(sole) for axis in (0, 1)))
        midpoint = tuple((contacts[0][axis] + contacts[1][axis]) / 2 + row["owner_nudge"][axis]
                         for axis in (0, 1))
        profile = manifest["registration"][row["actor"]]
        test.assertLessEqual(math.dist(profile[view], midpoint), row["tolerance_px"], view + ": two-sole registration")
        test.assertAlmostEqual(profile[view][1] - profile["height"][1 if view == "rear" else 0],
                               row["painted_rest_top"][view], places=2)


class ApprovedContentManifestTests(unittest.TestCase):
    def test_approved_content(self):
        manifest = json.loads(MANIFEST.read_text())
        check_pins(self, manifest)
        check_animated_sheets(self, manifest)
        with tempfile.TemporaryDirectory(prefix="approved-content-") as temporary:
            command = [sys.executable, str(ROOT / "tools/godot_task_runner.py"),
                       "--task-id", os.environ.get("LABYRINTH_TASK_ID", "approved-content"),
                       "--timeout", str(MANIFEST_HELPER_TIMEOUT_SECONDS), "--stream", "--", "godot",
                       "--headless", "--path", str(ROOT), "--script",
                       "tests/helpers/approved_content_smoke.gd", "--", "--pack", str(Path(temporary) / "approved.pck")]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("APPROVED CONTENT SMOKE: PASS", result.stdout)
            (Path(temporary) / "project.godot").write_text("config_version=5\n")
            runtime = subprocess.run([sys.executable, str(ROOT / "tools/godot_task_runner.py"),
                       "--project", temporary, "--task-id", os.environ.get("LABYRINTH_TASK_ID", "approved-content"),
                       "--timeout", str(MANIFEST_HELPER_TIMEOUT_SECONDS), "--stream", "--", "godot",
                       "--headless", "--path", temporary, "--main-pack", str(Path(temporary) / "approved.pck"),
                       "--script", "res://tests/helpers/approved_content_smoke.gd"],
                       cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(runtime.returncode, 0, runtime.stdout + runtime.stderr)
            self.assertIn("APPROVED CONTENT SMOKE: PASS", runtime.stdout)


if __name__ == "__main__":
    unittest.main()

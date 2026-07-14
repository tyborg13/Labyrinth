from __future__ import annotations

import importlib.util
from pathlib import Path
import argparse
import struct
import tempfile
import unittest
import zlib


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "visual_probe_runner.py"
SPEC = importlib.util.spec_from_file_location("visual_probe_runner", SCRIPT)
assert SPEC and SPEC.loader
VISUAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VISUAL)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_checker_png(path: Path, width: int = 40, height: int = 40) -> None:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            value = 230 if (x + y) % 2 else 20
            rows.extend((value, value, value, 255))
    data = VISUAL.PNG_SIGNATURE
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(rows)))
    data += png_chunk(b"IEND", b"")
    path.write_bytes(data)


def write_solid_png(path: Path, width: int, height: int, value: int = 80) -> None:
    rows = bytearray()
    for _y in range(height):
        rows.append(0)
        for _x in range(width):
            rows.extend((value, value, value, 255))
    data = VISUAL.PNG_SIGNATURE
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(rows)))
    data += png_chunk(b"IEND", b"")
    path.write_bytes(data)


class VisualProbeRunnerTests(unittest.TestCase):
    def test_exact_sizes_and_semantic_regions_are_enforced(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            image = Path(raw) / "proof.png"
            write_checker_png(image)
            contract = {
                "required_images": [
                    {
                        "pattern": "proof.png",
                        "width": 40,
                        "height": 40,
                        "regions": [{"rect": [5, 5, 20, 20], "min_luma_range": 100, "min_luma_stdev": 50}],
                    }
                ]
            }
            stats = VISUAL.validate_pngs([image], 1, [(40, 40)], contract)
            self.assertEqual(stats[0]["width"], 40)

    def test_missing_exact_size_fails(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            image = Path(raw) / "proof.png"
            write_checker_png(image)
            with self.assertRaises(VISUAL.ProbeError):
                VISUAL.validate_pngs([image], 1, [(41, 40)], {})

    def test_generated_metadata_diff_reports_added_and_modified_paths(self) -> None:
        before = {"old.import": "one", "same.uid": "same"}
        after = {"old.import": "two", "same.uid": "same", "new.uid": "new"}
        self.assertEqual(VISUAL.generated_metadata_changes(before, after), ["new.uid", "old.import"])

    def test_semantic_region_skips_smaller_matching_images(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            small = Path(raw) / "proof-small.png"
            large = Path(raw) / "proof-large.png"
            write_checker_png(small, 40, 40)
            write_checker_png(large, 80, 80)
            contract = {
                "required_images": [
                    {
                        "pattern": "proof-*.png",
                        "width": 80,
                        "height": 80,
                        "regions": [{"rect": [50, 50, 20, 20], "min_luma_range": 100}],
                    }
                ]
            }
            VISUAL.validate_pngs([small, large], 2, [(40, 40), (80, 80)], contract)

    def test_semantic_region_cannot_be_supplied_by_wrong_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            small = Path(raw) / "proof-small.png"
            large = Path(raw) / "proof-large.png"
            write_checker_png(small, 40, 40)
            write_solid_png(large, 80, 80)
            contract = {
                "required_images": [
                    {
                        "pattern": "proof-*.png",
                        "width": 80,
                        "height": 80,
                        "regions": [{"rect": [5, 5, 20, 20], "min_luma_range": 100}],
                    }
                ]
            }
            with self.assertRaises(VISUAL.ProbeError):
                VISUAL.validate_pngs([small, large], 2, [(40, 40), (80, 80)], contract)

    def test_result_manifest_requires_fresh_path_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "report.json"
            VISUAL.write_result_manifest(str(path), {"ok": True})
            with self.assertRaises(VISUAL.ProbeError):
                VISUAL.write_result_manifest(str(path), {"ok": False})

    def test_macos_gui_probes_default_to_angle_with_native_fallback(self) -> None:
        args = argparse.Namespace(
            rendering_driver="",
            fallback_rendering_driver=[],
            headless=False,
            display_driver="macos",
        )
        self.assertEqual(VISUAL.rendering_driver_candidates(args), ["opengl3_angle", ""])


if __name__ == "__main__":
    unittest.main()

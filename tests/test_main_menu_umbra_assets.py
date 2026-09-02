from __future__ import annotations

import hashlib
import struct
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
UI_ART = REPO_ROOT / "assets" / "art" / "ui"
BUTTON_IDLE = UI_ART / "main_menu_umbra_button_idle.png"
BUTTON_FOCUSED = UI_ART / "main_menu_umbra_button_focused.png"
MARKER_LEFT = UI_ART / "main_menu_umbra_focus_marker_left.png"
MARKER_RIGHT = UI_ART / "main_menu_umbra_focus_marker_right.png"


def png_ihdr(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError(f"{path} is not a valid PNG with an IHDR header")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


class MainMenuUmbraAssetTests(unittest.TestCase):
    def test_generated_button_states_are_aligned_rgba_sprites(self) -> None:
        self.assertEqual((1024, 224, 6), png_ihdr(BUTTON_IDLE))
        self.assertEqual((1024, 224, 6), png_ihdr(BUTTON_FOCUSED))
        self.assertNotEqual(
            hashlib.sha256(BUTTON_IDLE.read_bytes()).digest(),
            hashlib.sha256(BUTTON_FOCUSED.read_bytes()).digest(),
            "focused molten fractures must be a distinct generated-art state",
        )

    def test_generated_side_widgets_are_separate_mirrored_rgba_sprites(self) -> None:
        self.assertEqual((112, 184, 6), png_ihdr(MARKER_LEFT))
        self.assertEqual((112, 184, 6), png_ihdr(MARKER_RIGHT))
        self.assertNotEqual(MARKER_LEFT.read_bytes(), MARKER_RIGHT.read_bytes())

    def test_umbra_renderer_uses_rasters_not_procedural_fractures(self) -> None:
        source = (REPO_ROOT / "scripts" / "themed_button_ornament.gd").read_text(encoding="utf-8")
        for asset_name in (BUTTON_IDLE.name, BUTTON_FOCUSED.name, MARKER_LEFT.name, MARKER_RIGHT.name):
            self.assertIn(asset_name, source)
        self.assertIn("draw_texture_rect", source)
        self.assertIn("AssetLoader.load_texture_source_first", source)
        self.assertNotIn('preload("res://assets/art/ui/main_menu_umbra_', source)
        for forbidden in (
            "func _draw_umbra_corner",
            "func _draw_umbra_fractures",
            "func _umbra_crack_path",
            "func _draw_umbra_marker(",
        ):
            self.assertNotIn(forbidden, source)

    def test_generated_rasters_are_exported_as_raw_files(self) -> None:
        for asset in (BUTTON_IDLE, BUTTON_FOCUSED, MARKER_LEFT, MARKER_RIGHT):
            metadata = asset.with_suffix(asset.suffix + ".import").read_text(encoding="utf-8")
            self.assertIn('\nimporter="keep"\n', metadata)
            self.assertNotIn(".ctex", metadata)


if __name__ == "__main__":
    unittest.main()

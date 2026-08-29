#!/usr/bin/env python3
"""Keep the production main-menu mark aligned with generated Steam artwork."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_MENU_PATH = ROOT / "scripts" / "main_menu.gd"
STEAM_GENERATOR_PATH = ROOT / "steam" / "scripts" / "generate_store_assets.py"


def _load_steam_generator():
    spec = importlib.util.spec_from_file_location("generate_store_assets", STEAM_GENERATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load the Steam store-asset generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MainMenuSteamBrandingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.menu_source = MAIN_MENU_PATH.read_text(encoding="utf-8")
        cls.steam_source = STEAM_GENERATOR_PATH.read_text(encoding="utf-8")
        cls.steam_generator = _load_steam_generator()

    def test_title_face_colors_match_steam_palette(self) -> None:
        constant_names = (
            "TITLE_FACE_TOP_COLOR",
            "TITLE_FACE_HIGH_COLOR",
            "TITLE_FACE_MID_COLOR",
            "TITLE_FACE_LOW_COLOR",
            "TITLE_FACE_BOTTOM_COLOR",
        )
        for constant_name, (_position, rgb) in zip(constant_names, self.steam_generator.FACE_STOPS):
            color_hex = "".join(f"{channel:02x}" for channel in rgb)
            self.assertIn(
                f'const {constant_name} := Color("{color_hex}")',
                self.menu_source,
                f"{constant_name} should match the Steam title palette",
            )

    def test_title_layers_match_steam_palette(self) -> None:
        for color_hex in ("5b2d74", "c0522f", "ffd98d"):
            self.assertIn(f'Color("{color_hex}")', self.menu_source)
            self.assertIn(f'fill="#{color_hex}"', self.steam_source)

    def test_menu_uses_one_full_logo_gradient(self) -> None:
        self.assertIn("gradient_offset + local_y", self.menu_source)
        self.assertIn(
            'set_shader_parameter("gradient_offset", line_position.y)',
            self.menu_source,
        )
        self.assertIn(
            'set_shader_parameter("gradient_height", shared_gradient_height)',
            self.menu_source,
        )
        for position, _rgb in self.steam_generator.FACE_STOPS[1:-1]:
            self.assertIn(f"position <= {position:.2f}", self.menu_source)


if __name__ == "__main__":
    unittest.main()

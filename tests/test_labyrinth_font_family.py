#!/usr/bin/env python3
"""Contract tests for the generated Labyrinth Crumble font family."""

from __future__ import annotations

import importlib.util
import json
import sys
import unittest
from pathlib import Path

from fontTools.ttLib import TTFont


ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "fonts"
GENERATOR_PATH = ROOT / "tools" / "build_labyrinth_font.py"


def _load_generator():
    spec = importlib.util.spec_from_file_location("build_labyrinth_font", GENERATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load the Labyrinth Crumble generator")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


GENERATOR = _load_generator()


class LabyrinthFontFamilyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads(
            (FONT_DIR / "LabyrinthCrumble-family.json").read_text(encoding="utf-8")
        )

    def test_family_contains_three_optical_cuts_with_complete_project_coverage(self) -> None:
        expected = {
            "display": ("Display Black", 900, 900),
            "ui": ("UI ExtraBold", 800, 800),
            "text": ("Text Semibold", 600, 725),
        }
        cuts = {cut["key"]: cut for cut in self.manifest["cuts"]}
        self.assertEqual(set(cuts), set(expected))
        required_codepoints = {ord(char) for char in GENERATOR.SUPPORTED_CHARS}

        for key, (style_name, weight, digit_weight) in expected.items():
            cut = cuts[key]
            font_path = FONT_DIR / cut["ttf"]
            resource_path = FONT_DIR / cut["tres"]
            import_path = FONT_DIR / f'{cut["ttf"]}.import'
            self.assertTrue(font_path.is_file())
            self.assertTrue(resource_path.is_file())
            self.assertIn(
                f'source_file="res://fonts/{cut["ttf"]}"',
                import_path.read_text(encoding="utf-8"),
            )
            with TTFont(font_path) as font:
                cmap = font.getBestCmap()
                self.assertTrue(required_codepoints.issubset(cmap))
                self.assertEqual(font["OS/2"].usWeightClass, weight)
                self.assertEqual(cut["digit_weight"], digit_weight)
                names = {
                    record.nameID: record.toUnicode()
                    for record in font["name"].names
                    if record.nameID in {0, 1, 2, 5, 13}
                }
                self.assertEqual(names[1], "Labyrinth Crumble")
                self.assertEqual(names[2], style_name)
                self.assertEqual(names[5], "Version 2.0")
                self.assertIn("SIL Open Font License", names[0])
                self.assertIn("SIL Open Font License", names[13])

    def test_distress_is_exterior_only_and_recedes_with_reading_size(self) -> None:
        policy = self.manifest["policy"]
        self.assertEqual(policy["chips"], "exterior silhouette only")
        self.assertFalse(policy["interior_cracks"])
        self.assertTrue(policy["preserve_component_count"])
        self.assertTrue(policy["preserve_counter_count"])

        cuts = {cut["key"]: cut for cut in self.manifest["cuts"]}
        self.assertGreater(cuts["display"]["total_chips"], cuts["ui"]["total_chips"])
        self.assertGreater(cuts["ui"]["total_chips"], cuts["text"]["total_chips"])
        self.assertGreater(
            cuts["display"]["total_removed_pixels"],
            cuts["ui"]["total_removed_pixels"],
        )
        self.assertGreater(
            cuts["ui"]["total_removed_pixels"],
            cuts["text"]["total_removed_pixels"],
        )
        self.assertGreaterEqual(cuts["display"]["total_chips"], 220)
        self.assertGreaterEqual(cuts["ui"]["total_chips"], 150)
        self.assertGreaterEqual(cuts["text"]["total_chips"], 60)

    def test_source_attribution_and_license_are_vendored(self) -> None:
        self.assertEqual(self.manifest["source"], "Bitter[wght].ttf")
        self.assertEqual(self.manifest["source_license"], "SIL Open Font License 1.1")
        self.assertTrue((FONT_DIR / "source" / "Bitter[wght].ttf").is_file())
        license_text = (FONT_DIR / "source" / "Bitter-OFL.txt").read_text(encoding="utf-8")
        self.assertIn("SIL OPEN FONT LICENSE Version 1.1", license_text)

    def test_player_facing_sources_have_no_legacy_font_references(self) -> None:
        roots = ("scripts", "scenes", "themes", "tests", "marketing")
        suffixes = {".gd", ".tscn", ".tres", ".godot", ".py"}
        legacy_markers = (
            "LabyrinthCrumble-Header",
            "LabyrinthCrumble-Regular",
            "PressStart2P",
        )
        offenders: list[str] = []
        for root_name in roots:
            for path in (ROOT / root_name).rglob("*"):
                if path.suffix not in suffixes or path == Path(__file__):
                    continue
                text = path.read_text(encoding="utf-8")
                if any(marker in text for marker in legacy_markers):
                    offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [])

    def test_shared_typography_maps_every_role_to_the_intended_cut(self) -> None:
        source = (ROOT / "scripts" / "ui_typography.gd").read_text(encoding="utf-8")
        self.assertIn('DISPLAY_FONT_PATH: String = "res://fonts/LabyrinthCrumble-Display.tres"', source)
        self.assertIn('UI_FONT_PATH: String = "res://fonts/LabyrinthCrumble-UI.tres"', source)
        self.assertIn('TEXT_FONT_PATH: String = "res://fonts/LabyrinthCrumble-Text.tres"', source)
        self.assertIn("ROLE_HERO, ROLE_BANNER", source)
        self.assertIn("ROLE_SECTION, ROLE_TITLE", source)
        self.assertIn("var font: Font = ui_font()", source)

    def test_interactive_controls_and_card_title_fitting_use_the_ui_cut(self) -> None:
        typography_source = (ROOT / "scripts" / "ui_typography.gd").read_text(encoding="utf-8")
        option_helper = typography_source.split("static func set_option_button_size", 1)[1].split(
            "static func set_rich_text_size", 1
        )[0]
        self.assertIn("var font: Font = ui_font()", option_helper)
        self.assertIn('button.add_theme_font_override("font", font)', option_helper)
        self.assertIn('popup.add_theme_font_override("font", font)', option_helper)

        settings_source = (ROOT / "scripts" / "settings_panel.gd").read_text(encoding="utf-8")
        style_button = settings_source.split("func _style_button", 1)[1].split(
            "func _sync_controls_from_settings", 1
        )[0]
        self.assertIn(
            "UiTypography.apply_button_role(button, UiTypography.ROLE_BODY)",
            style_button,
        )

        card_source = (ROOT / "scripts" / "card_widget.gd").read_text(encoding="utf-8")
        fit_title = card_source.split("func _fit_title_label", 1)[1].split(
            "func _relieved_title_size", 1
        )[0]
        self.assertIn("var font: Font = UiTypography.ui_font()", fit_title)
        self.assertNotIn("UiTypography.default_font(title_label)", fit_title)

    def test_large_identity_text_and_card_scan_values_keep_readable_emphasis(self) -> None:
        typography_source = (ROOT / "scripts" / "ui_typography.gd").read_text(encoding="utf-8")
        self.assertIn("STONE_TEXT_SHADER_CODE", typography_source)
        self.assertIn("static func apply_stone_text", typography_source)

        main_menu_source = (ROOT / "scripts" / "main_menu.gd").read_text(encoding="utf-8")
        self.assertIn("uniform float texture_strength = 0.12", main_menu_source)

        run_source = (ROOT / "scripts" / "run_scene.gd").read_text(encoding="utf-8")
        self.assertIn(
            "UiTypography.apply_stone_text(room_title, 0.13, 3.5)",
            run_source,
        )

        card_source = (ROOT / "scripts" / "card_widget.gd").read_text(encoding="utf-8")
        self.assertIn("const TITLE_FIT_RELIEF: int = 1", card_source)
        self.assertIn("const TITLE_MAX_RENDER_SIZE: int = 17", card_source)
        self.assertIn("var font: Font = UiTypographyScript.ui_font()", card_source)
        self.assertIn("20 if size.x <= 42.0 else 23", card_source)
        self.assertIn("_scaled_card_font_size(13, 8)", card_source)


if __name__ == "__main__":
    unittest.main()

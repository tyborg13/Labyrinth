from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PLAYER_UI_ROOTS = ("scripts", "scenes", "themes")
PLAYER_UI_SUFFIXES = {".gd", ".tscn", ".tres"}
LEGACY_BUTTON_ASSETS = (
    "button_wood_gold_normal.png",
    "button_wood_gold_hover.png",
    "button_wood_gold_pressed.png",
    "progression_command_normal.png",
    "progression_command_hover.png",
    "progression_command_pressed.png",
    "progression_command_disabled.png",
    "progression_stepper_normal.png",
    "progression_stepper_hover.png",
    "progression_stepper_pressed.png",
    "progression_stepper_disabled.png",
)


class ButtonSystemInventoryTests(unittest.TestCase):
    def test_legacy_button_assets_are_removed(self) -> None:
        ui_dir = REPO_ROOT / "assets" / "art" / "ui"
        remaining = [name for name in LEGACY_BUTTON_ASSETS if (ui_dir / name).exists()]
        self.assertEqual([], remaining, f"dead stretched button assets remain: {remaining}")

    def test_no_player_facing_legacy_button_references_remain(self) -> None:
        findings: list[str] = []
        for root_name in PLAYER_UI_ROOTS:
            root = REPO_ROOT / root_name
            for path in root.rglob("*"):
                if not path.is_file() or path.suffix not in PLAYER_UI_SUFFIXES:
                    continue
                text = path.read_text(encoding="utf-8")
                for asset_name in LEGACY_BUTTON_ASSETS:
                    if asset_name in text:
                        findings.append(f"{path.relative_to(REPO_ROOT)} -> {asset_name}")
        self.assertEqual([], findings, "player-facing legacy button references remain:\n" + "\n".join(findings))

    def test_shared_button_builder_is_code_native(self) -> None:
        skin_source = (REPO_ROOT / "scripts" / "ui_skin.gd").read_text(encoding="utf-8")
        button_builder = skin_source.split("func make_button_style", 1)[1].split("func button_native_size", 1)[0]
        self.assertIn("StyleBoxFlat.new()", button_builder)
        self.assertNotIn("StyleBoxTexture", button_builder)
        self.assertNotIn("AssetLoader", button_builder)


if __name__ == "__main__":
    unittest.main()

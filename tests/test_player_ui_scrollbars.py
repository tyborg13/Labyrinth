from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


# Owner preference: no horizontal scrollbars in player-facing UI, and no
# scrolling anywhere on the skill tree (fit-to-view instead).
class PlayerUiScrollbarTests(unittest.TestCase):
    def test_player_ui_does_not_enable_visible_horizontal_scrollbars(self) -> None:
        auto_assignment = re.compile(
            r"horizontal_scroll_mode\s*=[^\n]*SCROLL_MODE_(?:AUTO|ALWAYS)"
        )
        for script_path in (REPO_ROOT / "scripts").rglob("*.gd"):
            self.assertIsNone(auto_assignment.search(script_path.read_text(encoding="utf-8")), script_path)
        for scene_path in (REPO_ROOT / "scenes").rglob("*.tscn"):
            scene = scene_path.read_text(encoding="utf-8")
            self.assertNotIn("horizontal_scroll_mode = 1", scene, scene_path)
            self.assertNotIn("horizontal_scroll_mode = 2", scene, scene_path)

    def test_skill_tree_surface_is_scrollbar_free(self) -> None:
        skill_tree = (REPO_ROOT / "scripts" / "skill_tree_view.gd").read_text(encoding="utf-8")
        self.assertNotIn("ScrollContainer.new()", skill_tree)
        self.assertNotIn("SkillDetailScroll", skill_tree)



if __name__ == "__main__":
    unittest.main()

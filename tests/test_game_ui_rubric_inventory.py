from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
RUBRIC_PATH = "spec/game_ui_rubric.md"
SKILL_NAME = "create-labyrinth-ui"


class GameUiRubricInventoryTests(unittest.TestCase):
    def test_root_instructions_make_ui_rubric_mandatory(self) -> None:
        instructions = (REPO_ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn(f"${SKILL_NAME}", instructions)
        self.assertIn(RUBRIC_PATH, instructions)
        self.assertIn("player-facing UI", instructions)

    def test_ui_skill_routes_to_the_versioned_rubric(self) -> None:
        skill_root = REPO_ROOT / ".codex" / "skills" / SKILL_NAME
        skill = (skill_root / "SKILL.md").read_text(encoding="utf-8")
        metadata = (skill_root / "agents" / "openai.yaml").read_text(encoding="utf-8")
        self.assertIn(RUBRIC_PATH, skill)
        self.assertIn("visual", skill.lower())
        self.assertIn(f"${SKILL_NAME}", metadata)

    def test_rubric_is_anchored_to_live_game_ui_systems(self) -> None:
        rubric = (REPO_ROOT / RUBRIC_PATH).read_text(encoding="utf-8")
        for required_anchor in (
            "UiSkin",
            "UiTypography",
            "UiTooltipPanel",
            "CardWidget",
            "1280x720",
            "1280x800",
            "1920x1080",
            "125%",
            "reduced motion",
            "Preserve every input path",
            "controller or Steam Deck",
            "Automatic rejection tripwires",
            "Horizontal scrollbars are prohibited",
            "semantic icon-led selection objects",
            "any part of a skill tree/dependency graph",
        ):
            self.assertIn(required_anchor, rubric)

    def test_player_ui_does_not_enable_visible_horizontal_scrollbars(self) -> None:
        auto_assignment = re.compile(
            r"horizontal_scroll_mode\s*=\s*ScrollContainer\.SCROLL_MODE_(?:AUTO|ALWAYS)"
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

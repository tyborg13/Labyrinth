from __future__ import annotations

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
            "1920x1080",
            "125%",
            "reduced motion",
            "Automatic rejection tripwires",
        ):
            self.assertIn(required_anchor, rubric)


if __name__ == "__main__":
    unittest.main()

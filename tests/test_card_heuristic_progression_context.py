import json
import subprocess
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOL_PATH = REPO_ROOT / "tools" / "card_heuristic.py"


class CardHeuristicProgressionContextTests(unittest.TestCase):
    def test_assumptions_keep_skills_outside_intrinsic_card_scores(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOL_PATH), "--show-assumptions"],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        assumptions = json.loads(result.stdout)
        self.assertEqual(assumptions["player_flow"]["base_initiative"], 9)
        self.assertEqual(assumptions["player_flow"]["cards_per_turn"], 2)
        self.assertEqual(assumptions["player_flow"]["draw_per_turn"], 2)
        self.assertEqual(assumptions["player_flow"]["max_hand_size"], 7)
        self.assertEqual(
            assumptions["qualitative_progression"]["score_profile"],
            "no_skills",
        )
        self.assertEqual(
            assumptions["qualitative_progression"]["cohort_field"],
            "progression_skills",
        )
        self.assertIn(
            "exclude skill effects",
            assumptions["qualitative_progression"]["coefficient_policy"],
        )


if __name__ == "__main__":
    unittest.main()

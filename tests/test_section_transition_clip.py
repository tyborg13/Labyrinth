"""Proof-tool contracts; actual gameplay/timing is covered by the Godot suite."""
import copy
import json
from pathlib import Path
import unittest

from tools.demo_clips import section_transition as clip


class SectionTransitionClipTests(unittest.TestCase):
    def test_encode_retains_logged_clip_bounds_and_pcm_sample_alignment(self):
        command = clip.encode_arguments(Path("/private/tmp/flow-01-clip-test"), {"start_frame": 29, "end_frame": 595})
        filters = command[command.index("-filter_complex") + 1]
        self.assertIn("trim=start_frame=29:end_frame=595", filters)
        self.assertIn("atrim=start_sample=23200:end_sample=476000", filters)
        self.assertEqual(command[command.index("-r") + 1], "60")
        self.assertEqual(command[command.index("-ar") + 1], "48000")

    def test_native_and_headless_commands_use_task_runner(self):
        directory = Path("/private/tmp/flow-01-clip-command-test")
        for recording in (False, True):
            command = clip.command(directory, recording)
            self.assertIn(str(clip.ROOT / "tools/godot_task_runner.py"), command)
            self.assertEqual(command[command.index("--task-id") + 1], "flow-01")
            self.assertIn(clip.SCENE, command)
            self.assertEqual("--headless" in command, not recording)
            self.assertEqual("--write-movie" in command, recording)
        native = clip.command(directory, True)
        self.assertEqual(native[native.index("--resolution") + 1], "1920x1080")

    def test_receipt_requires_full_transition_and_two_second_tail(self):
        names = ["section_i_dragon_alive", "dragon_defeated_reward_granted", "continue", "arrival", "map_fully_open", "tail_finished"]
        frames = [0, 250, 370, 526, 551, 671]
        report = {"events": [dict(event=name, frame=frame) for name, frame in zip(names, frames)]}
        clip.validate_events(report)
        for index in (2, 4, 5):
            changed = copy.deepcopy(report)
            changed["events"][index]["frame"] -= 30
            with self.assertRaises(ValueError):
                clip.validate_events(changed)
        changed = copy.deepcopy(report)
        changed["events"].pop(1)
        with self.assertRaises(ValueError):
            clip.validate_events(changed)

    def test_extension_uses_director_format_and_proof_has_requested_strip(self):
        root = clip.ROOT
        data = json.loads((root / "tools/demo_clips/section_transition.json").read_text())
        self.assertEqual(data["reels"][0]["clips"][0]["id"], "section_transition")
        self.assertEqual(data["defaults"]["tail_s"], 2.0)
        self.assertEqual(data["defaults"]["reward_hold_s"], 2.0)
        proof = json.loads((root / "tests/proof_contracts/section_transition.json").read_text())
        patterns = [row["pattern"] for row in proof["required_images"]]
        for time in (300, 900, 1500, 2400, 3000):
            self.assertIn(f"*/normal_{time:04d}.png", patterns)
        for motion in ("normal", "reduced"):
            for phase in ("reverse", "reward"):
                self.assertIn(f"*/failure_{motion}_{phase}.png", patterns)
        for name in ("normal_2800", "normal_3000", "reduced_1850", "reduced_2000"):
            self.assertIn(f"*/{name}.png", patterns)
        self.assertEqual(proof["min_images"], 14)
        self.assertEqual(proof["expected_sizes"], ["1920x1080"])


if __name__ == "__main__":
    unittest.main()

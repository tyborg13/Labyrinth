#!/usr/bin/env python3
"""Headless command-contract checks; native capture remains director-owned."""
import json
from pathlib import Path
import unittest

import capture_pace_round as capture


class PaceRoundCaptureTests(unittest.TestCase):
    def test_round_probe_selects_pace_02_and_the_merged_pace_01_baseline(self):
        for before in (False, True):
            args = capture.probe_arguments(Path("/tmp/pace-02-manifest.json"), before=before)
            self.assertEqual(args[args.index("--task-id")+1], "pace-02")
            self.assertEqual(args[args.index("--expect-size")+1], "1920x1080")
            self.assertEqual(args[-2:] if before else args[-1:], ["--round-only", "--baseline"] if before else ["--round-only"])
            self.assertIn("--proof-contract", args)
        source = (Path(__file__).parent / "combat_feel_probe.gd").read_text()
        self.assertIn('const BASELINE_COMMIT: String = "4e874c34f"', source)

    def test_movie_command_keeps_visual_runner_configuration(self):
        args = capture.visual.build_parser().parse_args([
            "tests/combat_feel_probe.gd", "--no-headless", "--display-driver", "macos",
            "--audio-driver", "Dummy", "--task-id", "pace-02"])
        args.probe_args = ["--round-only", "--baseline"]
        command = capture.movie_command(args, "opengl3_angle", Path("/tmp/pace.log"), Path("/tmp/round.avi"))
        self.assertNotIn("--headless", command)
        for flag, value in [("--fixed-fps", "60"), ("--resolution", "1920x1080"),
                            ("--audio-driver", "Dummy"), ("--rendering-driver", "opengl3_angle"),
                            ("--write-movie", "/tmp/round.avi"), ("--log-file", "/tmp/pace.log")]:
            self.assertEqual(command[command.index(flag)+1], value)
        self.assertEqual(command[-3:], ["--", "--round-only", "--baseline"])

    def test_native_audio_and_video_trim_share_boundaries(self):
        command = capture.encode_command(Path("round.avi"), Path("after.mp4"), 120, 420)
        self.assertIn("trim=start_frame=120:end_frame=420", command[command.index("-vf")+1])
        self.assertEqual(command[command.index("-af")+1], "atrim=start_sample=96000:end_sample=336000,asetpts=PTS-STARTPTS")
        self.assertEqual(command[command.index("-r")+1], "60")
        self.assertIn("0:a:0", command)

    def test_capture_boundaries_fail_closed(self):
        log = "PACE ROUND CAPTURE START_FRAME=120\nPACE ROUND CAPTURE END_FRAME=420\n"
        self.assertEqual(capture.capture_boundaries(log), (120, 420))
        for bad in ("", log+log, "PACE ROUND CAPTURE START_FRAME=10\nPACE ROUND CAPTURE END_FRAME=9\n"):
            with self.assertRaises(ValueError):
                capture.capture_boundaries(bad)

    def test_proof_contract_requires_both_full_resolution_board_images(self):
        contract = json.loads((Path(__file__).parent / "pace_round_proof_contract.json").read_text())
        self.assertEqual(contract["expected_sizes"], ["1920x1080"])
        self.assertEqual({x["pattern"] for x in contract["required_images"]}, {"*round_start.png", "*round_end.png"})
        self.assertTrue(all(x["regions"] for x in contract["required_images"]))


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import importlib.util
from pathlib import Path
import argparse
import os
import struct
import sys
import tempfile
import time
import unittest
from unittest import mock
import zlib


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "visual_probe_runner.py"
SPEC = importlib.util.spec_from_file_location("visual_probe_runner", SCRIPT)
assert SPEC and SPEC.loader
VISUAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VISUAL)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_checker_png(path: Path, width: int = 40, height: int = 40) -> None:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            value = 230 if (x + y) % 2 else 20
            rows.extend((value, value, value, 255))
    data = VISUAL.PNG_SIGNATURE
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(rows)))
    data += png_chunk(b"IEND", b"")
    path.write_bytes(data)


def write_solid_png(path: Path, width: int, height: int, value: int = 80) -> None:
    rows = bytearray()
    for _y in range(height):
        rows.append(0)
        for _x in range(width):
            rows.extend((value, value, value, 255))
    data = VISUAL.PNG_SIGNATURE
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(rows)))
    data += png_chunk(b"IEND", b"")
    path.write_bytes(data)


class VisualProbeRunnerTests(unittest.TestCase):
    def test_short_fail_fast_defaults_remain_configurable(self) -> None:
        defaults = VISUAL.build_parser().parse_args(["tests/ui_probe.gd"])
        self.assertEqual(defaults.timeout, 30.0)
        self.assertEqual(defaults.startup_timeout, 8.0)
        self.assertEqual(defaults.gui_lease_timeout, 30.0)
        self.assertEqual(defaults.attempts, 1)
        custom = VISUAL.build_parser().parse_args(
            [
                "tests/ui_probe.gd",
                "--timeout",
                "42",
                "--startup-timeout",
                "12",
                "--gui-lease-timeout",
                "18",
                "--attempts",
                "3",
            ]
        )
        self.assertEqual(custom.timeout, 42.0)
        self.assertEqual(custom.startup_timeout, 12.0)
        self.assertEqual(custom.gui_lease_timeout, 18.0)
        self.assertEqual(custom.attempts, 3)

    def test_startup_watchdog_stops_process_before_total_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            started_at = time.monotonic()
            with self.assertRaisesRegex(VISUAL.ProbeStartupTimeout, "did not initialize"):
                VISUAL.run_process_with_watchdogs(
                    [sys.executable, "-c", "import time; time.sleep(5)"],
                    cwd=root,
                    env=os.environ.copy(),
                    timeout=4.0,
                    startup_log=root / "never-created.log",
                    startup_timeout=0.1,
                )
            self.assertLess(time.monotonic() - started_at, 1.5)

    def test_total_watchdog_stops_an_initialized_hung_process(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            started_at = time.monotonic()
            with self.assertRaisesRegex(VISUAL.ProbeExecutionTimeout, "total timeout"):
                VISUAL.run_process_with_watchdogs(
                    [sys.executable, "-c", "import time; time.sleep(5)"],
                    cwd=root,
                    env=os.environ.copy(),
                    timeout=0.1,
                    startup_log=None,
                    startup_timeout=0.0,
                )
            self.assertLess(time.monotonic() - started_at, 1.5)

    @unittest.skipUnless(os.name == "posix", "POSIX process-group interruption coverage")
    def test_interruption_reaps_the_spawned_process(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            pid_file = root / "child.pid"
            child_code = (
                "import os, pathlib, time; "
                "pathlib.Path(%r).write_text(str(os.getpid())); "
                "time.sleep(5)"
                % str(pid_file)
            )
            real_monotonic = time.monotonic
            monotonic_calls = 0

            def interrupt_after_child_starts() -> float:
                nonlocal monotonic_calls
                monotonic_calls += 1
                if monotonic_calls == 1:
                    return real_monotonic()
                deadline = real_monotonic() + 1.0
                while real_monotonic() < deadline:
                    if pid_file.exists() and pid_file.read_text().strip():
                        break
                raise KeyboardInterrupt()

            with mock.patch.object(VISUAL.time, "monotonic", side_effect=interrupt_after_child_starts):
                with self.assertRaises(KeyboardInterrupt):
                    VISUAL.run_process_with_watchdogs(
                        [sys.executable, "-c", child_code],
                        cwd=root,
                        env=os.environ.copy(),
                        timeout=4.0,
                        startup_log=None,
                        startup_timeout=0.0,
                    )
            self.assertTrue(pid_file.exists())
            child_pid = int(pid_file.read_text())
            with self.assertRaises(ProcessLookupError):
                os.kill(child_pid, 0)

    def test_windows_tree_termination_uses_taskkill(self) -> None:
        process = mock.Mock()
        process.pid = 321
        process.poll.return_value = None
        process.wait.return_value = 0
        with mock.patch.object(VISUAL.os, "name", "nt"):
            with mock.patch.object(VISUAL.subprocess, "run") as run:
                VISUAL.stop_process_tree(process)
        run.assert_called_once_with(
            ["taskkill", "/PID", "321", "/T", "/F"],
            stdout=VISUAL.subprocess.DEVNULL,
            stderr=VISUAL.subprocess.DEVNULL,
            timeout=2.0,
            check=False,
        )
        process.wait.assert_called_once_with(timeout=1.0)

    def test_exact_sizes_and_semantic_regions_are_enforced(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            image = Path(raw) / "proof.png"
            write_checker_png(image)
            contract = {
                "required_images": [
                    {
                        "pattern": "proof.png",
                        "width": 40,
                        "height": 40,
                        "regions": [{"rect": [5, 5, 20, 20], "min_luma_range": 100, "min_luma_stdev": 50}],
                    }
                ]
            }
            stats = VISUAL.validate_pngs([image], 1, [(40, 40)], contract)
            self.assertEqual(stats[0]["width"], 40)

    def test_missing_exact_size_fails(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            image = Path(raw) / "proof.png"
            write_checker_png(image)
            with self.assertRaises(VISUAL.ProbeError):
                VISUAL.validate_pngs([image], 1, [(41, 40)], {})

    def test_generated_metadata_diff_reports_added_and_modified_paths(self) -> None:
        before = {"old.import": "one", "same.uid": "same"}
        after = {"old.import": "two", "same.uid": "same", "new.uid": "new"}
        self.assertEqual(VISUAL.generated_metadata_changes(before, after), ["new.uid", "old.import"])

    def test_semantic_region_skips_smaller_matching_images(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            small = Path(raw) / "proof-small.png"
            large = Path(raw) / "proof-large.png"
            write_checker_png(small, 40, 40)
            write_checker_png(large, 80, 80)
            contract = {
                "required_images": [
                    {
                        "pattern": "proof-*.png",
                        "width": 80,
                        "height": 80,
                        "regions": [{"rect": [50, 50, 20, 20], "min_luma_range": 100}],
                    }
                ]
            }
            VISUAL.validate_pngs([small, large], 2, [(40, 40), (80, 80)], contract)

    def test_semantic_region_cannot_be_supplied_by_wrong_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            small = Path(raw) / "proof-small.png"
            large = Path(raw) / "proof-large.png"
            write_checker_png(small, 40, 40)
            write_solid_png(large, 80, 80)
            contract = {
                "required_images": [
                    {
                        "pattern": "proof-*.png",
                        "width": 80,
                        "height": 80,
                        "regions": [{"rect": [5, 5, 20, 20], "min_luma_range": 100}],
                    }
                ]
            }
            with self.assertRaises(VISUAL.ProbeError):
                VISUAL.validate_pngs([small, large], 2, [(40, 40), (80, 80)], contract)

    def test_result_manifest_requires_fresh_path_by_default(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "report.json"
            VISUAL.write_result_manifest(str(path), {"ok": True})
            with self.assertRaises(VISUAL.ProbeError):
                VISUAL.write_result_manifest(str(path), {"ok": False})

    def test_macos_gui_probes_default_to_angle_with_native_fallback(self) -> None:
        args = argparse.Namespace(
            rendering_driver="",
            fallback_rendering_driver=[],
            headless=False,
            display_driver="macos",
        )
        self.assertEqual(VISUAL.rendering_driver_candidates(args), ["opengl3_angle", ""])

    def test_macos_host_defaults_to_angle_without_display_driver_flag(self) -> None:
        args = argparse.Namespace(
            rendering_driver="",
            fallback_rendering_driver=[],
            headless=False,
            display_driver="",
        )
        with mock.patch.object(VISUAL.sys, "platform", "darwin"):
            self.assertEqual(VISUAL.rendering_driver_candidates(args), ["opengl3_angle", ""])

    def test_project_msaa_automatically_selects_native_macos_gpu(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            project = Path(raw)
            (project / "project.godot").write_text(
                '[rendering]\nanti_aliasing/quality/msaa_2d=2\nrenderer/rendering_method="mobile"\n'
            )
            args = argparse.Namespace(
                headless=None,
                display_driver="",
                rendering_driver="",
                rendering_method="",
            )
            VISUAL.resolve_probe_rendering_mode(args, project, platform="darwin", environment={})
            self.assertFalse(args.headless)
            self.assertEqual(args.display_driver, "macos")
            self.assertEqual(args.rendering_driver, "metal")
            self.assertEqual(args.rendering_method, "mobile")

    def test_explicit_headless_msaa_probe_fails_with_capability_error(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            project = Path(raw)
            (project / "project.godot").write_text(
                "[rendering]\nanti_aliasing/quality/msaa_2d=2\n"
            )
            args = argparse.Namespace(
                headless=True,
                display_driver="",
                rendering_driver="",
                rendering_method="",
            )
            with self.assertRaisesRegex(VISUAL.ProbeError, "dummy headless renderer"):
                VISUAL.resolve_probe_rendering_mode(args, project, platform="darwin", environment={})

    def test_project_without_msaa_retains_headless_default(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            project = Path(raw)
            (project / "project.godot").write_text(
                '[rendering]\nrenderer/rendering_method="mobile"\n'
            )
            args = argparse.Namespace(
                headless=None,
                display_driver="",
                rendering_driver="",
                rendering_method="",
            )
            VISUAL.resolve_probe_rendering_mode(args, project, platform="linux", environment={})
            self.assertTrue(args.headless)


if __name__ == "__main__":
    unittest.main()

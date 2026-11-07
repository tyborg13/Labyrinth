#!/usr/bin/env python3
"""Demo configuration and build routing; all writes are test-owned temporary files."""
import configparser
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
PRESET_NAMES = ("Steam Demo macOS", "Steam Demo Windows", "Steam Demo Linux")
PLATFORMS = ("macos", "windows", "linux")
DEMO_FILENAMES = ("Escape the Umbra Demo.app", "Escape the Umbra Demo.exe", "Escape the Umbra Demo.x86_64")
MISSING_IDS_MESSAGE = (
    "Demo target needs STEAM_DEMO_APP_ID and STEAM_DEMO_DEPOT_{MACOS,WINDOWS,LINUX} "
    "in steam/steam_build_config.env."
)
COMMAND_TIMEOUT_SECONDS = 30
PACK_EXPORT_TIMEOUT_SECONDS = 60
DEMO_IDS_FIXTURE = {"APP_ID": "100", "DEPOT_MACOS": "101", "DEPOT_WINDOWS": "102", "DEPOT_LINUX": "103"}


def read_config(path):
    config = configparser.ConfigParser(interpolation=None)
    config.optionxform = str
    # project.godot has config_version before its first named section.
    config.read_string("[root]\n" + path.read_text())
    return config


class DemoBuildTests(unittest.TestCase):
    def test_demo_presets_copy_full_presets(self):
        presets = read_config(ROOT / "export_presets.cfg")
        self.assertEqual(len(presets.sections()), 13)  # Including the synthetic root.
        for index, (name, platform, filename) in enumerate(zip(PRESET_NAMES, PLATFORMS, DEMO_FILENAMES)):
            with self.subTest(preset=name):
                full = dict(presets[f"preset.{index}"])
                self.assertEqual(full["custom_features"], '""')
                demo = dict(presets[f"preset.{index + 3}"])
                expected = dict(full, name=json.dumps(name), custom_features='"demo"',
                                export_path=json.dumps(f"build/steam_demo/content/{platform}/{filename}"))
                self.assertEqual(demo, expected)
                options = dict(presets[f"preset.{index}.options"])
                if index == 0:
                    options["application/bundle_identifier"] = '"com.borgerding.escapetheumbra.demo"'
                self.assertEqual(dict(presets[f"preset.{index + 3}.options"]), options)

    def test_project_name_does_not_shadow_runtime_user_directory(self):
        application = read_config(ROOT / "project.godot")["application"]
        self.assertEqual(application["config/name.demo"], '"Escape the Umbra Demo"')
        self.assertEqual(application["config/name"], '"Escape the Umbra"')
        for key in application:
            self.assertFalse(key.startswith("config/use_custom_user_dir.") and "demo" in key.split("."))
            self.assertFalse(key.startswith("config/custom_user_dir_name.") and "demo" in key.split("."))

    def test_missing_demo_ids_fail_before_export(self):
        # Even a missing Godot binary must not obscure the actionable ID error.
        for missing in ("all", "APP_ID", "DEPOT_MACOS", "DEPOT_WINDOWS", "DEPOT_LINUX"):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory(prefix="demo-ids-") as directory:
                root = Path(directory)
                marker = root / "godot-ran"
                godot = root / "godot"
                godot.write_text('#!/bin/sh\ntouch "$DEMO_TEST_GODOT_MARKER"\nexit 99\n')
                godot.chmod(0o755)
                config = root / "config.env"
                values = {}
                for index, key in enumerate(("APP_ID", "DEPOT_MACOS", "DEPOT_WINDOWS", "DEPOT_LINUX")):
                    values[key] = "" if missing in ("all", key) else str(100 + index)
                config.write_text("\n".join(f'STEAM_DEMO_{key}="{value}"' for key, value in values.items()))
                env = dict(os.environ, DEMO_TEST_GODOT_MARKER=str(marker))
                result = subprocess.run(
                    ["bash", str(ROOT / "scripts/build_and_upload_steam.sh"), "--targets", "demo", "--preview",
                     "--config", str(config), "--godot-binary", str(godot)],
                    env=env, text=True, capture_output=True, timeout=COMMAND_TIMEOUT_SECONDS,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(MISSING_IDS_MESSAGE, result.stderr)
                self.assertFalse(marker.exists(), "No version query or export may run before ID validation")

    def test_export_help_includes_demo_presets(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/export_game.py"), "--help"],
                                text=True, capture_output=True, timeout=COMMAND_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in PRESET_NAMES:
            self.assertIn(name, result.stdout)

    def test_target_routing_and_preview_scripts(self):
        # Keep production orchestration/export/copy/VDF functions, but replace
        # external setup and the export tool in a self-contained fake project.
        for targets in ("demo", "main,demo", "main,playtest", "playtest"):
            with self.subTest(targets=targets), tempfile.TemporaryDirectory(prefix="demo-routing-") as directory:
                root = Path(directory)
                (root / "scripts").mkdir()
                (root / "tools").mkdir()
                (root / "steam").mkdir()
                (root / "GODOT_SPLASH_LICENSE.txt").write_text("fixture license")
                config = (ROOT / "steam/steam_build_config.env").read_text()
                for key, value in DEMO_IDS_FIXTURE.items():
                    # Fixture IDs replace whatever the shipped config holds (real IDs since 2026-11-06).
                    config = re.sub(rf'^STEAM_DEMO_{key}=.*$', f'STEAM_DEMO_{key}={value}', config, flags=re.M)
                (root / "steam/steam_build_config.env").write_text(config)
                source = (ROOT / "scripts/build_and_upload_steam.sh").read_text()
                source, entrypoint = source.rsplit('\nmain "$@"', 1)
                self.assertEqual(entrypoint.strip(), "")
                harness = root / "scripts/build_and_upload_steam.sh"
                harness.write_text(source + '''
validate_environment() { :; }
ensure_godot_templates() { :; }
prepare_export_project() { mkdir -p "${EXPORT_PROJECT_ROOT}"; }
validate_exported_pck() { :; }
main "$@"
''')
                (root / "tools/cel_look.py").write_text("# no-op fixture\n")
                (root / "tools/export_game.py").write_text('''import json, os, pathlib, sys
args = sys.argv[1:]
output = pathlib.Path(args[args.index('--output') + 1])
preset = args[args.index('--preset') + 1]
with open(os.environ['DEMO_TEST_EXPORT_LOG'], 'a') as log:
    log.write(json.dumps({'preset': preset, 'output': str(output)}) + '\\n')
if output.suffix == '.app':
    output = output / 'Contents/Resources/fixture.pck'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(preset)
''')
                log = root / "exports.jsonl"
                result = subprocess.run(["bash", str(harness), "--targets", targets, "--preview", "--dry-run"],
                                        env=dict(os.environ, DEMO_TEST_EXPORT_LOG=str(log)),
                                        text=True, capture_output=True, timeout=COMMAND_TIMEOUT_SECONDS)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                exports = [json.loads(line) for line in log.read_text().splitlines()]
                full = "main" in targets or "playtest" in targets
                expected_names = (["Steam macOS", "Steam Windows", "Steam Linux"] if full else [])
                if "demo" in targets:
                    expected_names += list(PRESET_NAMES)
                self.assertEqual([entry["preset"] for entry in exports], expected_names)
                for kind in ("full", "demo"):
                    selected = full if kind == "full" else "demo" in targets
                    build = root / "build" / ("steam" if kind == "full" else "steam_demo")
                    self.assertEqual(build.exists(), selected)
                    if not selected:
                        continue
                    filenames = DEMO_FILENAMES if kind == "demo" else tuple(name.replace(" Demo", "") for name in DEMO_FILENAMES)
                    for platform, filename in zip(PLATFORMS, filenames):
                        output = build / "content" / platform / filename
                        self.assertTrue(output.exists(), output)
                        self.assertTrue((output.parent / "GODOT_SPLASH_LICENSE.txt").exists())
                        if platform == "linux":
                            self.assertTrue(output.stat().st_mode & 0o111)
                    for target in ("demo",) if kind == "demo" else tuple(t for t in ("main", "playtest") if t in targets):
                        scripts = build / "steampipe/scripts"
                        app = (scripts / f"app_build_{target}.vdf").read_text()
                        self.assertIn('"Preview" "1"', app)
                        self.assertIn(f'"ContentRoot" "{build / "content"}"', app)
                        if target == "demo":
                            self.assertIn('"AppID" "100"', app)
                        for platform in PLATFORMS:
                            depot = (scripts / f"depot_build_{target}_{platform}.vdf").read_text()
                            self.assertIn(f'"ContentRoot" "{build / "content" / platform}"', depot)

    @unittest.skipUnless(shutil.which("godot"), "Godot is required for exported-name startup proof")
    def test_exported_name_resolves_before_user_folder(self):
        # Export a tiny pack with the real names and presets. No autoload runs:
        # this measures the engine's initial user directory before runtime code.
        with tempfile.TemporaryDirectory(prefix="demo-name-proof-") as directory:
            root = Path(directory)
            project = root / "project"
            project.mkdir()
            application = read_config(ROOT / "project.godot")["application"]
            (project / "project.godot").write_text(
                'config_version=5\n[application]\n' + "\n".join(
                    f'{key}={application[key]}' for key in ("config/name", "config/name.demo")) + "\n"
            )
            shutil.copyfile(ROOT / "export_presets.cfg", project / "export_presets.cfg")
            (project / "startup_proof.gd").write_text('''extends SceneTree
func _initialize() -> void:
    print("DEMO STARTUP PROOF: " + JSON.stringify({
        "demo": OS.has_feature("demo"),
        "name": ProjectSettings.get_setting_with_override("application/config/name"),
        "user_dir": ProjectSettings.globalize_path("user://"),
    }))
    quit()
''')
            runner = [sys.executable, str(ROOT / "tools/godot_task_runner.py"),
                      "--project", str(project), "--task-id", "dmo-01", "--stream", "--", "godot", "--headless"]
            for preset, expected_name, demo in (("Steam Demo Linux", "Escape the Umbra Demo", True),
                                                ("Steam Linux", "Escape the Umbra", False)):
                with self.subTest(preset=preset):
                    pack = root / ("demo.pck" if demo else "full.pck")
                    export = subprocess.run(runner + ["--path", str(project), "--export-pack", preset, str(pack)],
                                            text=True, capture_output=True, timeout=PACK_EXPORT_TIMEOUT_SECONDS)
                    self.assertEqual(export.returncode, 0, export.stdout + export.stderr)
                    launch = subprocess.run(runner + ["--main-pack", str(pack), "--script", "res://startup_proof.gd"],
                                            text=True, capture_output=True, timeout=COMMAND_TIMEOUT_SECONDS)
                    self.assertEqual(launch.returncode, 0, launch.stdout + launch.stderr)
                    marker = "DEMO STARTUP PROOF: "
                    line = next(line for line in launch.stdout.splitlines() if line.startswith(marker))
                    proof = json.loads(line[len(marker):])
                    self.assertEqual(proof["demo"], demo)
                    self.assertEqual(proof["name"], expected_name)
                    self.assertTrue(proof["user_dir"].rstrip("/").endswith("/app_userdata/" + expected_name), proof)
                    print(line)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Guard the approved splash pixels, native settings, and desktop attribution."""

import configparser
import hashlib
from pathlib import Path
import shlex
import struct
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPLASH = ROOT / "assets/art/ui/boot_splash_makers_seal.png"
APPROVED_SHA256 = "a2fea0706c12f6e9e066e5b3f54d2660423d42d733975a110f0ffe45b79f211c"
NOTICE = "GODOT_SPLASH_LICENSE.txt"


class BootSplashTests(unittest.TestCase):
    def test_approved_art_is_unchanged(self):
        data = SPLASH.read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), APPROVED_SHA256)
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", data[16:24]), (1672, 941))

    def test_native_splash_settings(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read_string("[header]\n" + (ROOT / "project.godot").read_text())
        app = config["application"]
        self.assertEqual(app["boot_splash/image"].strip('"'), "res://" + str(SPLASH.relative_to(ROOT)))
        self.assertEqual(app["boot_splash/bg_color"], "Color(0, 0, 0, 1)")
        self.assertEqual(app["boot_splash/stretch_mode"], "1")  # Godot 4.6 KEEP.
        self.assertEqual(app["boot_splash/show_image"], "true")
        self.assertEqual(app["boot_splash/use_filter"], "true")
        self.assertEqual(app["boot_splash/minimum_display_time"], "2000")  # Milliseconds.
        self.assertEqual(app["run/main_scene"], '"res://scenes/main_menu.tscn"')
        self.assertNotIn("boot_splash/fullsize", app)  # Retired in Godot 4.6.

    def test_import_metadata_uses_canonical_asset_path(self):
        # The trailer's game-assets symlink can rewrite shared import sidecars.
        # Shipping metadata must not depend on that marketing-only alias.
        metadata = SPLASH.with_suffix(".png.import").read_text()
        source = "res://" + SPLASH.relative_to(ROOT).as_posix()
        digest = hashlib.md5(source.encode()).hexdigest()  # Godot cache key, not security.
        imported = f"res://.godot/imported/{SPLASH.name}-{digest}.ctex"
        self.assertIn(f'\nsource_file="{source}"\n', metadata)
        self.assertIn(f'\ndest_files=["{imported}"]\n', metadata)
        self.assertIn(f'\npath="{imported}"\n', metadata)

    def test_logo_attribution(self):
        notice = (ROOT / NOTICE).read_text()
        for required in (
            "2017 Andrea Calabró",
            "https://creativecommons.org/licenses/by/4.0/",
            "https://godotengine.org/press/",
            "https://github.com/godotengine/godot/blob/master/misc/logo/LICENSE.txt",
            "Changes:",
            "https://godotengine.org/license/",
        ):
            self.assertIn(required, notice)

    def test_desktop_staging_copies_readable_notice(self):
        # Run the real packaging function against isolated fake export outputs.
        # Do not run main(): it can download templates or upload to Steam.
        script = (ROOT / "scripts/build_and_upload_steam.sh").read_text()
        self.assertTrue(script.endswith('main "$@"\n'))
        definitions = script.rsplit('main "$@"', 1)[0]
        with tempfile.TemporaryDirectory(prefix="labyrinth-splash-package-") as temp:
            root = Path(temp)
            functions = root / "build_functions.sh"
            functions.write_text(definitions)
            for platform, executable in (
                ("macos", "Escape the Umbra.app"),
                ("windows", "Escape the Umbra.exe"),
                ("linux", "Escape the Umbra.x86_64"),
            ):
                with self.subTest(platform=platform):
                    staged = root / "staging" / platform / executable
                    staged.parent.mkdir(parents=True)
                    if platform == "macos":
                        staged.mkdir()
                        (staged / "test-marker").write_bytes(b"exported app")
                    else:
                        staged.write_bytes(b"exported executable")
                    command = "\n".join((
                        "source " + shlex.quote(str(functions)),
                        "PROJECT_ROOT=" + shlex.quote(str(ROOT)),
                        "CONTENT_ROOT=" + shlex.quote(str(root / "content")),
                        "EXPORT_STAGING_ROOT=" + shlex.quote(str(root / "staging")),
                        "sync_staged_platform_output " + platform,
                    ))
                    result = subprocess.run(["bash", "-c", command], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    content = root / "content" / platform
                    self.assertEqual((content / NOTICE).read_bytes(), (ROOT / NOTICE).read_bytes())
                    self.assertTrue((content / executable).exists())
                    if platform == "linux":
                        self.assertTrue((content / executable).stat().st_mode & 0o111)


if __name__ == "__main__":
    unittest.main()

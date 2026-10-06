from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import pixel_density as density
import process_board_density as tool

REGISTRY = ROOT / "spec/assets/board_pixel_density/registry.json"
SOURCES = ROOT / "spec/assets/board_pixel_density/sources"


def function_text(code: str, name: str) -> str:
    return code.split(f"func {name}(", 1)[1].split("\nfunc ", 1)[0]


class BoardPixelDensityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.registry = json.loads(REGISTRY.read_text())
        cls.entries = {e["id"]: e for e in cls.registry["entries"]}
        cls.board = (ROOT / "scripts/combat_board_view.gd").read_text()

    def test_shipped_derivations_and_manifest_are_current(self) -> None:
        result = subprocess.run([sys.executable, str(ROOT / "tools/process_board_density.py"), "--check"],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("CHECK-OK", result.stdout)

    def test_gear_outputs_remain_current(self) -> None:
        result = subprocess.run([sys.executable, str(ROOT / "tools/process_gear_visual_assets.py"), "--check"],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("CHECK-OK", result.stdout)

    def test_every_output_preserves_size_alpha_hidden_rgb_and_frame_edges(self) -> None:
        for entry in self.entries.values():
            for path in entry["paths"]:
                with self.subTest(path=path):
                    with Image.open(SOURCES / path) as original, Image.open(ROOT / path) as current:
                        self.assertEqual(current.mode, "RGBA")
                        self.assertEqual(original.size, current.size)
                        a, b = np.asarray(original.convert("RGBA")), np.asarray(current)
                        np.testing.assert_array_equal(a[..., 3], b[..., 3], err_msg=path)
                        np.testing.assert_array_equal(a[a[..., 3] == 0], b[a[..., 3] == 0], err_msg=path)
                        for x, y, w, h in density.frame_rects(original.size, entry["frames"]):
                            aa, bb = a[y:y+h, x:x+w], b[y:y+h, x:x+w]
                            ring = density.edge_ring(aa[..., 3] > 0)
                            np.testing.assert_array_equal(aa[ring], bb[ring], err_msg=path)

    def test_rig_coverage_names_adoption_command_for_new_art(self) -> None:
        body = function_text(self.board, "_unit_uses_cutout")
        types = re.findall(r'"([a-z_]+)"', body.split(" in [", 1)[1])
        directories = {"assets/units/stone_warden_cutout" if kind == "warden"
                       else f"assets/units/{kind}_cutout" for kind in types}
        directories.update(str(p.relative_to(ROOT)) for p in (ROOT / "assets/units/guardians").iterdir() if p.is_dir())
        registered_dirs = {e["dir"] for e in self.entries.values() if e["kind"] == "rig" and e["id"] != "hero_rear"}
        self.assertEqual(directories, registered_dirs, "New board rig: register by the rule, then --adopt <path>")
        directories.add("assets/units/protagonist_cutout/rear")
        registered = {p for e in self.entries.values() for p in e["paths"]}
        excluded = self.registry["excluded_paths"]
        self.assertFalse(registered & excluded.keys(), "Paths cannot be registered and excluded")
        for directory in sorted(directories):
            for path in sorted((ROOT / directory).rglob("*.png")):
                relative = str(path.relative_to(ROOT))
                self.assertTrue(relative in registered or bool(excluded.get(relative)),
                                f"Uncovered PNG: {relative}; register then --adopt {relative}")
        for path in registered:
            self.assertTrue((ROOT / path).is_file(), path)

    def test_grid_rule_and_measurement_use_untouched_native_sources(self) -> None:
        for entry in self.entries.values():
            with self.subTest(entry=entry["id"]):
                native = tool.sample(SOURCES / entry["measurement_path"], entry["frames"])
                share = density.metrics(native)["orphan_share"]
                self.assertAlmostEqual(share, entry["orphan_share"])
                self.assertEqual(entry["t"], 1.5 if share >= 0.15 else 1.0)
                if entry.get("override"):
                    self.assertTrue(entry["override"].strip())
                else:
                    self.assertEqual(entry["grid"], round(entry["t"] / entry["r"], 2))
                    self.assertEqual(entry["mode"], "regrid" if entry["grid"] >= 1.25 else "clean")

    def test_draw_scales_follow_live_code_including_trimmed_pillar(self) -> None:
        def constant(name: str) -> float:
            expression = re.search(rf"const {name}: float = ([^\n]+)", self.board).group(1)
            self.assertRegex(expression, r"^[0-9. /+*()-]+$")
            return float(eval(expression, {"__builtins__": {}}, {}))

        def component(name: str, axis: int) -> float:
            pair = re.search(r"return Vector2\(tile_width \* ([0-9.]+), tile_width \* ([0-9.]+)\)", function_text(self.board, name))
            return float(pair.group(axis + 1))

        unit_x, unit_y = component("_unit_size", 0), component("_unit_size", 1)
        unit_factor = unit_x / 255
        prop_x, prop_y = component("_prop_size", 0), component("_prop_size", 1)
        with Image.open(SOURCES / self.entries["pillar"]["paths"][0]) as im:
            left, top, right, bottom = im.convert("RGBA").getchannel("A").getbbox()
        pw, ph = right - left, bottom - top
        pillar_factor = min(prop_x / pw, prop_y / ph)
        pillar_width = pillar_factor * pw
        enemies = json.loads((ROOT / "data/enemies.json").read_text())
        npcs = json.loads((ROOT / "data/npcs.json").read_text())
        run_scene = (ROOT / "scripts/run_scene.gd").read_text()
        for entry in self.entries.values():
            name = entry["id"]
            if entry["kind"] == "rig":
                expected = 1.0 if name == "hero_rear" else enemies[name].get("art_scale", 1.0)
            else:
                frame = tool.sample(SOURCES / entry["paths"][0], entry["frames"])
                w, h = frame.size
                if name.startswith("column_torch"):
                    draw = pillar_width * constant("COLUMN_TORCH_WIDTH_SCALE") / w
                elif name.startswith("campfire"):
                    draw = constant("CAMPFIRE_BONFIRE_WIDTH_SCALE") / w
                elif name == "pillar":
                    self.assertIn("trim_texture_to_used_rect", function_text(self.board, "_load_board_prop_assets"))
                    draw = pillar_factor
                elif name == "moss_pillar_overlay":
                    scale = float(re.search(r"draw_rect.size.x \* ([0-9.]+)", function_text(self.board, "_pillar_moss_rect")).group(1))
                    draw = pillar_width * scale / w
                elif name == "door":
                    draw = min(constant("DOOR_FRAME_WIDTH_SCALE") / w, constant("DOOR_FRAME_HEIGHT_SCALE") / h)
                elif name == "door_opening":
                    static = tool.sample(SOURCES / self.entries["door"]["paths"][0], None)
                    bbox = static.getchannel("A").getbbox()
                    opening = frame.getchannel("A").getbbox()
                    draw = min(constant("DOOR_FRAME_WIDTH_SCALE") / static.width,
                               constant("DOOR_FRAME_HEIGHT_SCALE") / static.height) * (bbox[3]-bbox[1]) / (opening[3]-opening[1])
                elif name in ("scavenger_npc", "emaciated_man_idle"):
                    npc = npcs["scavenger" if name == "scavenger_npc" else "emaciated_man"]
                    draw = min(unit_x / w, unit_y / h) * npc.get("art_scale", 1.0)
                elif name in ("scavenger_stall", "watch_brazier"):
                    pattern = r'"kind":\s*"scavenger_stall"[\s\S]*?"width_scale":\s*([0-9.]+)' if name == "scavenger_stall" else r'"kind":"watch_brazier_lit"[^\n]+"width_scale":([0-9.]+)'
                    draw = float(re.search(pattern, run_scene).group(1)) / w
                elif name.startswith("wooden_crate"):
                    draw = constant("TERRAIN_CRATE_DRAW_WIDTH_SCALE") / w
                elif name.startswith("wooden_box") or name == "powder_keg":
                    draw = constant("TERRAIN_BOX_DRAW_WIDTH_SCALE") / w
                elif name == "dropped_embers":
                    draw = constant("LOOT_DRAW_TILE_WIDTH_SCALE") / w
                elif name == "relic_chest":
                    draw = constant("RELIC_CHEST_WIDTH_SCALE") / w
                elif name.startswith("trap_"):
                    draw = constant("TRAP_DRAW_WIDTH_SCALE") / w
                elif "floor" in name:
                    draw = 1.0 / w
                else:
                    self.fail(f"New prop needs a live-code scale assertion: {name}")
                expected = draw / unit_factor
            self.assertAlmostEqual(entry["r"], expected, msg=name)

    def test_door_regions_match_code(self) -> None:
        block = self.board.split("const DOOR_OPENING_FRAME_REGIONS := [", 1)[1].split("]", 1)[0]
        rects = [list(map(int, match)) for match in re.findall(r"Rect2i\((\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)", block)]
        self.assertEqual(self.entries["door_opening"]["frames"], {"rects": rects})


class DensityOperationTest(unittest.TestCase):
    def image(self) -> Image.Image:
        rng = np.random.default_rng(9)
        pixels = rng.integers(0, 256, (12, 16, 4), dtype=np.uint8)
        pixels[..., 3] = 255
        pixels[0, :, 3] = 0
        pixels[5, 4, 3] = 0
        pixels[3, 3, 3] = 11
        return Image.fromarray(pixels)

    def test_frames_are_independent_and_rect_gaps_are_untouched(self) -> None:
        source = self.image()
        frames = {"rects": [[1, 1, 6, 10], [9, 2, 6, 8]]}
        for mode in ("clean", "regrid"):
            expected = source.copy()
            for x, y, w, h in frames["rects"]:
                crop = source.crop((x, y, x+w, y+h))
                expected.paste(density.process(crop, mode, 1.5), (x, y))
            self.assertEqual(density.process(source, mode, 1.5, frames).tobytes(), expected.tobytes())
        tiled = density.process(source, "regrid", 1.5, {"grid": [2, 2]})
        for x, y, w, h in density.frame_rects(source.size, {"grid": [2, 2]}):
            self.assertEqual(tiled.crop((x,y,x+w,y+h)).tobytes(),
                             density.regrid(source.crop((x,y,x+w,y+h)), 1.5).tobytes())

    def test_alpha_hidden_colour_and_edge_restore_with_partial_alpha(self) -> None:
        source = self.image()
        pixels = np.asarray(source)
        for mode in ("clean", "regrid"):
            out = np.asarray(density.process(source, mode, 2.0))
            np.testing.assert_array_equal(out[..., 3], pixels[..., 3])
            np.testing.assert_array_equal(out[pixels[..., 3] == 0], pixels[pixels[..., 3] == 0])
            ring = density.edge_ring(pixels[..., 3] > 0)
            np.testing.assert_array_equal(out[ring], pixels[ring])

    def test_premultiplied_box_does_not_bleed_hidden_rgb(self) -> None:
        source = np.zeros((8, 8, 4), dtype=np.uint8)
        source[..., :3] = (240, 60, 20)
        source[..., 3] = 255
        source[2, 2] = (0, 255, 255, 0)
        output = np.asarray(density.regrid(Image.fromarray(source), 2.0))
        np.testing.assert_array_equal(output[3, 3], (240, 60, 20, 255))
        np.testing.assert_array_equal(output[2, 2], source[2, 2])

    def test_metrics_exclude_isolated_pixels_and_count_runs(self) -> None:
        image = Image.new("RGBA", (6, 2))
        for x, colour in enumerate((10, 10, 50, 50)):
            image.putpixel((x, 0), (colour, colour, colour, 255))
        image.putpixel((5, 1), (240, 30, 9, 255))
        self.assertEqual(density.metrics(image), {"orphan_share": 0.0, "run_length": 5/3})
        image.putpixel((1, 0), (100, 100, 100, 255))
        self.assertEqual(density.metrics(image)["orphan_share"], 0.5)

    def test_reject_invalid_frames_grid_and_mode(self) -> None:
        image = self.image()
        for frames in ({"grid": [3, 2]}, {"rects": [[0,0,20,1]]}, {"rects": [[0,0,3,3], [1,1,3,3]]}):
            with self.assertRaises(ValueError):
                density.process(image, "regrid", 1.5, frames)
        for grid in (0, -1, float("inf")):
            with self.assertRaises(ValueError):
                density.regrid(image, grid)
        with self.assertRaises(ValueError):
            density.process(image, "posterise", 1.5)

    def test_adoption_refuses_existing_sources_before_any_copy(self) -> None:
        with tempfile.TemporaryDirectory(dir=REGISTRY.parent) as directory:
            root = Path(directory)
            (root / "paint").mkdir()
            self.image().save(root / "paint/a.png")
            self.image().save(root / "paint/b.png")
            sources = root / "sources"
            with mock.patch.multiple(tool, ROOT=root, SOURCES=sources):
                tool.adopt(["paint/a.png"], False)
                original = (sources / "paint/a.png").read_bytes()
                (root / "paint/a.png").write_bytes(b"repaint")
                with self.assertRaisesRegex(ValueError, "force-adopt"):
                    tool.adopt(["paint/b.png", "paint/a.png"], False)
                self.assertFalse((sources / "paint/b.png").exists())
                self.assertEqual((sources / "paint/a.png").read_bytes(), original)
                tool.adopt(["paint/a.png"], True)
                self.assertEqual((sources / "paint/a.png").read_bytes(), b"repaint")
                with self.assertRaises(ValueError):
                    tool.repo_path("../outside.png")

    def test_cli_only_restore_and_stale_manifest(self) -> None:
        with tempfile.TemporaryDirectory(dir=REGISTRY.parent) as directory:
            root = Path(directory)
            (root / "paint").mkdir()
            self.image().save(root / "paint/a.png")
            self.image().save(root / "paint/b.png")
            self.image().save(root / "paint/hero.png")
            original_a = (root / "paint/a.png").read_bytes()
            registry = root / "registry.json"
            entries = [{"id": name, "paths": [f"paint/{name}.png"], "measurement_path": f"paint/{name}.png",
                        "mode": "regrid", "grid": 2.0, "frames": None} for name in ("a", "b")]
            registry.write_text(json.dumps({"hero_reference": "paint/hero.png", "entries": entries}))
            manifest = root / "outputs.json"
            with mock.patch.multiple(tool, ROOT=root, REGISTRY=registry, SOURCES=root / "sources", MANIFEST=manifest):
                def run(*args: str) -> int:
                    with mock.patch.object(sys, "argv", ["process_board_density.py", *args]):
                        return tool.main()
                self.assertEqual(run("--adopt-all"), 0)
                self.assertEqual(run(), 0)
                self.assertEqual(run("--check"), 0)
                record_b = json.loads(manifest.read_text())["paint/b.png"]
                output_b = (root / "paint/b.png").read_bytes()
                self.assertEqual(run("--write-originals", "--only", "a"), 0)
                self.assertEqual((root / "paint/a.png").read_bytes(), original_a)
                self.assertEqual((root / "paint/b.png").read_bytes(), output_b)
                self.assertEqual(run("--check", "--only", "a"), 1)
                self.assertEqual(run("--only", "a"), 0)
                self.assertEqual(json.loads(manifest.read_text())["paint/b.png"], record_b)
                self.assertEqual(run("--check"), 0)
                records = json.loads(manifest.read_text())
                records["paint/b.png"]["sha256"] = "stale"
                manifest.write_text(json.dumps(records))
                self.assertEqual(run("--check"), 1)


if __name__ == "__main__":
    unittest.main()

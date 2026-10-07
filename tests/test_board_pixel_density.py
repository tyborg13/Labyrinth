from __future__ import annotations

import json
import contextlib
import io
import re
import shutil
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
import generate_trap_pressure_plate_preview as trap_preview

REGISTRY = ROOT / "spec/assets/board_pixel_density/registry.json"
SOURCES = ROOT / "spec/assets/board_pixel_density/sources"


def function_text(code: str, name: str) -> str:
    return code.split(f"func {name}(", 1)[1].split("\nfunc ", 1)[0]


def mask_bounds(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    y, x = np.nonzero(mask)
    return (int(x.min()), int(y.min()), int(x.max())+1, int(y.max())+1) if len(x) else None


def silhouette_boundary_distance(source: np.ndarray, output: np.ndarray) -> int:
    """Worst Chebyshev distance of changed support from the source edge ring."""
    changed = source ^ output
    if not changed.any():
        return 0
    covered = density.edge_ring(source)
    if not covered.any():
        return max(source.shape)
    distance = 0
    while (changed & ~covered).any():
        padded = np.pad(covered, 1, constant_values=False)
        covered = np.logical_or.reduce([padded[y:y+source.shape[0], x:x+source.shape[1]]
                                        for y in range(3) for x in range(3)])
        distance += 1
    return distance


def board_png_paths(root: Path) -> set[str]:
    paths = set()
    for script in ("combat_board_view", "relic_chest_prop", "stone_outcrop_art", "dragon_board_props"):
        code = (root / f"scripts/{script}.gd").read_text()
        for path in re.findall(r'["\']res://([^"\'\n]+\.png)["\']', code):
            if "%s" in path:
                matches = list(root.glob(path.replace("%s", "*")))
                assert matches, f"Board PNG template has no files: {path}; update registry / --adopt"
                paths.update(str(p.relative_to(root)) for p in matches)
            else:
                paths.add(path)
        # RelicChestProp loads ROOT + part + ".png". Include the whole root so
        # adding another opening paint part cannot evade literal-path coverage.
        if 'ROOT + part + ".png"' in code:
            directory = re.search(r'const ROOT[^\n]*"res://([^"\n]+/)"', code).group(1)
            paths.update(str(p.relative_to(root)) for p in (root / directory).glob("*.png"))
    for npc in json.loads((root / "data/npcs.json").read_text()).values():
        path = npc.get("art_path", "").removeprefix("res://")
        if path.endswith(".png"):
            paths.add(path)
            idle = path[:-4] + "_idle.png"
            if (root / idle).is_file():
                paths.add(idle)
    return paths


def live_paint(layout: dict) -> dict[str, str]:
    meshes = layout.get("joint_meshes", [])
    replaced = {mesh.get("replaces_part") for mesh in meshes}
    pieces = [part for part in layout.get("parts", []) if part["name"] not in replaced
              and not (layout.get("cape_mesh") and part.get("cape_segment"))]
    pieces += meshes
    paths = {piece["name"]: piece["file"] for piece in pieces}
    if layout.get("cape_mesh"):
        paths["PaintedCape"] = layout["cape_mesh"]["file"]
    return paths


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

    def test_painted_derivations_and_manifest_are_current(self) -> None:
        manifest = json.loads(tool.MANIFEST.read_text())
        self.assertEqual(tool.paint_errors(list(self.entries.values()), manifest), [])

    def test_gear_outputs_remain_current(self) -> None:
        result = subprocess.run([sys.executable, str(ROOT / "tools/process_gear_visual_assets.py"), "--check"],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("CHECK-OK", result.stdout)

    def test_every_output_preserves_size_alpha_hidden_rgb_and_frame_edges(self) -> None:
        for entry in self.entries.values():
            for path in entry["paths"]:
                if tool.settings_for_path(entry, path)["mode"] == "resample":
                    continue
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

    def test_board_prop_and_room_png_coverage(self) -> None:
        registered = {p for e in self.entries.values() for p in e["paths"]}
        excluded = self.registry["excluded_paths"]
        for path in sorted(board_png_paths(ROOT)):
            self.assertTrue(path in registered or path in excluded,
                            f"Uncovered board PNG: {path}; add to registry, then --adopt {path}")
        categories = {"vfx", "ui_icon", "never_drawn", "presence_gate", "other"}
        for path, exclusion in excluded.items():
            self.assertIsInstance(exclusion, dict, path)
            self.assertIn(exclusion.get("category"), categories, path)
            self.assertTrue(exclusion.get("reason", "").strip(), path)
            self.assertTrue((ROOT / path).is_file(), path)

    def test_new_board_png_names_registry_and_adopt(self) -> None:
        with tempfile.TemporaryDirectory(dir=REGISTRY.parent) as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            (root / "data").mkdir()
            for name in ("combat_board_view", "relic_chest_prop", "stone_outcrop_art", "dragon_board_props"):
                (root / f"scripts/{name}.gd").write_text('var texture = load("res://new_board.png")' if name == "stone_outcrop_art" else "")
            (root / "data/npcs.json").write_text("{}")
            with self.assertRaisesRegex(AssertionError, r"new_board.png.*registry.*--adopt"):
                for path in board_png_paths(root):
                    self.assertIn(path, self.registry["excluded_paths"],
                                  f"Uncovered board PNG: {path}; add to registry, then --adopt {path}")

    def test_rig_rest_rule_uses_declared_assemblies_only(self) -> None:
        for entry in self.entries.values():
            if entry["kind"] != "rig":
                continue
            rests = set(tool.rest_paths(entry))
            self.assertFalse(rests & set(entry["paths"]), entry["id"])
            for facing in entry["rest_paths"]:
                layout = json.loads((ROOT / entry["dir"] / f"{facing}.json").read_text())
                declared = layout.get("rest_source", "")
                if declared:
                    path = declared.removeprefix("res://") if declared.startswith("res://") else str(Path(entry["dir"]) / declared)
                    self.assertIn(path, rests, entry["id"])
                for path in live_paint(layout).values():
                    relative = path.removeprefix("res://") if path.startswith("res://") else str(Path(entry["dir"]) / path)
                    self.assertNotIn(relative, rests, f"Live paint cannot be a rest output: {relative}")
                    self.assertTrue(relative in entry["paths"] or relative in self.registry["excluded_paths"],
                                    f"Live paint missing from registry: {relative}; --adopt {relative}")
                for path in (ROOT / entry["dir"] / facing).glob("rest*.png"):
                    relative = str(path.relative_to(ROOT))
                    self.assertTrue(relative in rests or relative in entry["paths"],
                                    f"Rest-named paint missing from registry: {relative}; --adopt {relative}")

    def test_silhouette_probe_cases_pin_density_sources(self) -> None:
        probes = ("chainbound_gaoler_cutout", "stone_warden_cutout", "dragon_attachment", "vaeloryx_feedback")
        compared = 0
        for name in probes:
            code = (ROOT / f"tests/{name}_asset_probe.gd").read_text()
            self.assertIn("Silhouette.same_silhouette", code, name)
            configs = re.findall(r'reference.configure\("res://([^"\n]+/cutout.json)"\)', code)
            if name == "dragon_attachment":
                prefix, suffix = re.search(r'reference.configure\("res://([^"\n]+)" \+ character \+ "([^"\n]+)"\)', code).groups()
                profiles = code.split("const PROFILES = [", 1)[1].split("\n]", 1)[0]
                configs += [prefix + character + suffix for character in re.findall(r'"id": "([a-z_]+)"', profiles)]
            self.assertEqual(len(configs), 2 if name == "dragon_attachment" else 1, name)
            for config_path in configs:
                case = ROOT / config_path
                config = json.loads(case.read_text())
                rig_id = "warden" if config["character_id"] == "stone_warden" else config["character_id"]
                entry = self.entries[rig_id]
                for facing, layout_path in config["layouts"].items():
                    reference = live_paint(json.loads((case.parent / layout_path).read_text()))
                    production = live_paint(json.loads((ROOT / entry["dir"] / f"{facing}.json").read_text()))
                    self.assertEqual(reference.keys(), production.keys(), f"{name}/{facing} painted nodes")
                    for node, path in reference.items():
                        expected = ROOT / path.removeprefix("res://") if path.startswith("res://") else case.parent / path
                        relative = production[node]
                        relative = relative.removeprefix("res://") if relative.startswith("res://") else str(Path(entry["dir"]) / relative)
                        self.assertIn(relative, entry["paths"], f"{name}/{facing}/{node}")
                        with Image.open(expected) as paint, Image.open(SOURCES / relative) as source:
                            self.assertEqual(paint.size, source.size, str(expected))
                            self.assertEqual(paint.convert("RGBA").tobytes(), source.convert("RGBA").tobytes(),
                                             f"Case paint differs from density source: {expected} → {relative}")
                        compared += 1
        self.assertGreater(compared, 100)

    def test_grid_rule_and_measurement_use_untouched_native_sources(self) -> None:
        for entry in self.entries.values():
            for facing, settings in entry.get("facings", {"": entry}).items():
                with self.subTest(entry=entry["id"], facing=facing):
                    native = tool.sample(SOURCES / settings["measurement_path"], entry["frames"])
                    share = density.metrics(native)["orphan_share"]
                    self.assertAlmostEqual(share, settings["orphan_share"])
                    self.assertAlmostEqual(settings["t"], density.strength(share))
                    if entry.get("override"):
                        self.assertTrue(entry["override"].strip())
                    elif entry["kind"] != "rig" and entry["r"] > 1.05:
                        self.assertEqual(settings["mode"], "resample")
                        self.assertEqual(density.scale_axes(settings["scale"]),
                                         density.scale_axes(entry.get("r_axes", entry["r"])))
                        self.assertEqual(settings["grid"], 1.5)
                        self.assertTrue(settings["resample_note"])
                    else:
                        self.assertEqual(settings["grid"], round(settings["t"] / entry["r"], 2))
                        self.assertEqual(settings["mode"], "regrid" if settings["grid"] >= 1.2 else "clean")
                    if entry["kind"] == "rig":
                        self.assertNotEqual(settings["mode"], "resample")
                        self.assertIn(settings["measurement_path"], entry["rest_paths"][facing])
                        for path in entry["paths"]:
                            if Path(path).parent.name == facing:
                                self.assertIs(tool.settings_for_path(entry, path), settings)

    def test_approved_per_facing_results_and_overrides(self) -> None:
        expected = {"chainbound_gaoler": (1.23, 1.46), "frostglass_lancer": (1.08, 1.37),
                    "craghide": (1.05, 1.22), "ash_hound": (1.68, 1.84), "bell_tender": (1.48, 1.76),
                    "rime_spitter": (1.43, 1.53), "roc_fledgling": (1.57, 2.0), "crawler": (1.73, 1.73)}
        for name, grids in expected.items():
            self.assertEqual(tuple(self.entries[name]["facings"][f]["grid"] for f in ("front", "rear")), grids, name)
        for settings in self.entries["lightning_wisp"]["facings"].values():
            self.assertEqual((settings["mode"], settings["grid"]), ("regrid", 1.5))
        self.assertEqual(self.entries["hero_rear"]["facings"]["rear"]["mode"], "clean")
        self.assertEqual((self.entries["scavenger_npc"]["mode"], self.entries["scavenger_npc"]["grid"]), ("clean", 1.0))

    def test_resampled_outputs_size_alpha_silhouette_and_fringe(self) -> None:
        manifest = json.loads(tool.MANIFEST.read_text())
        for entry in self.entries.values():
            if entry.get("mode") != "resample":
                continue
            owner = self.entries[entry.get("alpha_class_from", entry["id"])]
            measurement = tool.sample(SOURCES / owner["measurement_path"], owner["frames"])
            measurement_alpha = np.asarray(measurement)[...,3]
            translucent = int(((measurement_alpha >= 64) & (measurement_alpha < 240)).sum())
            fraction = translucent / max(int((measurement_alpha > 0).sum()), 1)
            solid = fraction < 0.10
            for path in entry["paths"]:
                with Image.open(SOURCES / path) as original, Image.open(ROOT / path) as current:
                    source, output = original.convert("RGBA"), current.convert("RGBA")
                old_rects = density.frame_rects(source.size, entry["frames"])
                new_rects = density.frame_rects(output.size, entry["frames"])
                self.assertEqual(len(new_rects), len(old_rects))
                record = manifest[path]
                self.assertEqual(record["alpha_class"], "solid" if solid else "soft")
                self.assertAlmostEqual(record["translucent_alpha_fraction"], fraction)
                self.assertEqual(record["alpha_class_from"], owner["id"])
                self.assertEqual(record["alpha_measurement_path"], owner["measurement_path"])
                self.assertEqual(record["alpha_source_pixel_sha256"], tool.pixel_digest(measurement))
                for index, ((x,y,w,h), (xx,yy,ww,hh)) in enumerate(zip(old_rects, new_rects)):
                    with self.subTest(path=path, frame=index):
                        sx, sy = density.scale_axes(entry["scale"])
                        self.assertEqual((ww, hh), (round(w*sx), round(h*sy)))
                        frame = source.crop((x,y,x+w,y+h))
                        pixels = np.asarray(output.crop((xx,yy,xx+ww,yy+hh)))
                        near = np.asarray(frame.resize((ww,hh), Image.Resampling.NEAREST))
                        a, b = near[..., 3] > 0, pixels[..., 3] > 0
                        source_alpha = np.asarray(frame)[..., 3]
                        bilinear = np.asarray(Image.fromarray(source_alpha.astype(np.float32)).resize(
                            (ww,hh), Image.Resampling.BILINEAR))
                        weight = np.asarray(Image.fromarray((source_alpha > 0).astype(np.float32)).resize(
                            (ww,hh), Image.Resampling.BILINEAR))
                        bilinear = bilinear / np.maximum(weight, 1e-3)
                        expected_alpha = np.where(a, np.rint(bilinear.clip(0,255)), 0)
                        if solid:
                            lanczos = np.asarray(Image.fromarray(source_alpha.astype(np.float32)).resize(
                                (ww,hh), Image.Resampling.LANCZOS))
                            body = (lanczos.clip(0,255) >= 128) & a
                            expected_alpha = np.where(body, near[...,3], expected_alpha)
                            ring = density.edge_ring(body) & (near[..., 3] >= 128)
                            np.testing.assert_array_equal(pixels[..., :3][ring], near[..., :3][ring])
                        np.testing.assert_array_equal(pixels[..., 3], expected_alpha.astype(np.uint8))
                        self.assertFalse((b & ~a).any(), "Resampled alpha support must stay within NEAREST source")
                        hidden = pixels[..., 3] == 0
                        np.testing.assert_array_equal(pixels[..., :3][hidden], near[..., :3][hidden])
                        old_bounds, new_bounds = mask_bounds(a), mask_bounds(b)
                        if old_bounds is None:
                            self.assertIsNone(new_bounds)
                        elif new_bounds is not None:
                            self.assertGreaterEqual(new_bounds[0], old_bounds[0])
                            self.assertGreaterEqual(new_bounds[1], old_bounds[1])
                            self.assertLessEqual(new_bounds[2], old_bounds[2])
                            self.assertLessEqual(new_bounds[3], old_bounds[3])
                        self.assertLessEqual(silhouette_boundary_distance(a, b), 1)

    def test_every_resampled_frame_preserves_mean_source_alpha(self) -> None:
        for entry in self.entries.values():
            if entry.get("mode") != "resample":
                continue
            for path in entry["paths"]:
                with Image.open(SOURCES / path) as im:
                    source = im.convert("RGBA")
                with Image.open(ROOT / path) as im:
                    output = im.convert("RGBA")
                for index, (old, new) in enumerate(zip(density.frame_rects(source.size, entry["frames"]),
                                                       density.frame_rects(output.size, entry["frames"]))):
                    with self.subTest(path=path, frame=index):
                        x,y,w,h = old
                        xx,yy,ww,hh = new
                        near_alpha = np.asarray(source.crop((x,y,x+w,y+h)).resize(
                            (ww,hh), Image.Resampling.NEAREST))[...,3]
                        alpha = np.asarray(output.crop((xx,yy,xx+ww,yy+hh)))[...,3]
                        support = near_alpha > 0
                        if support.any():
                            difference = abs(float(alpha[support].mean()) - float(near_alpha[support].mean())) / 255
                            self.assertLessEqual(difference, 3/255, "Resampling must preserve paint/fade opacity over source support")

    def test_static_sheet_families_and_independent_elemental_overlays(self) -> None:
        families = {f"trap_{element}_sheets": f"trap_{element}"
                    for element in ("air", "earth", "fire", "ice", "lightning")}
        families.update(wooden_box_destroy="wooden_box", wooden_crate_destroy="wooden_crate",
                        campfire_idle="campfire", column_torch_idle="column_torch_static",
                        door_opening="door", relic_chest_opening="relic_chest")
        for child, parent in families.items():
            self.assertEqual(self.entries[child]["alpha_class_from"], parent, child)
            self.assertEqual(tool.alpha_settings(self.entries[child], self.registry),
                             tool.alpha_settings(self.entries[parent], self.registry))
        for element in ("air", "earth", "fire", "ice", "lightning"):
            self.assertEqual(tool.alpha_settings(self.entries[f"trap_{element}"], self.registry)["alpha_class"], "solid")
        overlays = [e for e in self.entries.values()
                    if any("/element_overlays/" in path for path in e["paths"])]
        self.assertEqual(len(overlays), 8)
        for entry in overlays:
            self.assertEqual(entry["paths"], [entry["measurement_path"]])
            self.assertNotIn("alpha_class_from", entry)
        self.assertEqual({e["id"] for e in overlays if tool.alpha_settings(e, self.registry)["alpha_class"] == "soft"},
                         {"fire_floor_overlay_01", "fire_floor_overlay_02", "ice_floor_overlay_01"})

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
        pillar_height = pillar_factor * ph
        enemies = json.loads((ROOT / "data/enemies.json").read_text())
        npcs = json.loads((ROOT / "data/npcs.json").read_text())
        run_scene = (ROOT / "scripts/run_scene.gd").read_text()
        for entry in self.entries.values():
            name = entry["id"]
            draw_y = None
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
                    height_scale = float(re.search(r"draw_rect.size.y \* ([0-9.]+)", function_text(self.board, "_pillar_moss_rect")).group(1))
                    draw_y = pillar_height * height_scale / h
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
                elif name == "relic_chest_opening":
                    chest = (ROOT / "scripts/relic_chest_prop.gd").read_text()
                    logical_width = float(re.search(r"const LOGICAL_SIZE := Vector2\(([0-9.]+),", chest).group(1))
                    self.assertIn("point / LOGICAL_SIZE * rect.size", chest)
                    self.assertIn("Vector2(128.0, 160.0)", chest)
                    draw = constant("RELIC_CHEST_WIDTH_SCALE") / logical_width
                elif name.startswith("trap_"):
                    draw = constant("TRAP_DRAW_WIDTH_SCALE") / w
                elif "floor" in name:
                    draw = 1.0 / w
                    tile_height_scale = float(re.search(r"return _tile_width\(\) \* ([0-9.]+)", function_text(self.board, "_tile_height")).group(1))
                    draw_y = tile_height_scale / h
                else:
                    self.fail(f"New prop needs a live-code scale assertion: {name}")
                expected = draw / unit_factor
            self.assertAlmostEqual(entry["r"], expected, msg=name)
            if draw_y is not None:
                expected_axes = (expected, draw_y / unit_factor)
                np.testing.assert_allclose(entry["r_axes"], expected_axes, err_msg=name)
                np.testing.assert_allclose(entry["scale"], expected_axes, err_msg=name)
                for axis, value in zip(("x", "y"), expected_axes):
                    derivation = entry["scale_derivation"][axis]
                    self.assertAlmostEqual(derivation["screen_pixels_per_source_pixel_per_tile_width"] / unit_factor, value)
                    self.assertTrue(derivation["expression"])
            elif entry.get("mode") == "resample":
                self.assertIsInstance(entry["scale"], (float, int), "Aspect-preserving props keep a uniform scale")

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

    @contextlib.contextmanager
    def temporary_rig(self):
        with tempfile.TemporaryDirectory(dir=REGISTRY.parent) as directory:
            root = Path(directory)
            (root / "paint").mkdir()
            # Exercise rest tracking on temporary copies of shipped paint/rests;
            # no test can alter the worktree's production PNGs or rest records.
            shutil.copyfile(SOURCES / "assets/units/acolyte_cutout/front/torso.png", root / "paint/part.png")
            shutil.copyfile(ROOT / "assets/units/acolyte_cutout/front/rest.png", root / "paint/rest.png")
            self.image().save(root / "paint/hero.png")
            registry = root / "registry.json"
            entry = {"id": "fixture", "kind": "rig", "paths": ["paint/part.png"],
                     "rest_paths": {"front": ["paint/rest.png"]}, "measurement_path": "paint/rest.png",
                     "mode": "regrid", "grid": 2.0, "frames": None}
            registry.write_text(json.dumps({"hero_reference": "paint/hero.png", "entries": [entry]}))
            manifest = root / "outputs.json"
            with mock.patch.multiple(tool, ROOT=root, REGISTRY=registry, SOURCES=root / "sources", MANIFEST=manifest):
                def run(*args: str) -> tuple[int, str]:
                    output = io.StringIO()
                    with mock.patch.object(sys, "argv", ["process_board_density.py", *args]), contextlib.redirect_stdout(output):
                        result = tool.main()
                    return result, output.getvalue()
                self.assertEqual(run("--adopt-all")[0], 0)
                self.assertEqual(run()[0], 0)
                yield root, manifest, run

    def test_check_ignores_png_compression_for_outputs_sources_and_rests(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            self.assertEqual(run("--record-rests")[0], 0)
            records = manifest.read_bytes()
            for path in (root / "paint/part.png", root / "sources/paint/part.png", root / "paint/rest.png"):
                encoded = path.read_bytes()
                with Image.open(path) as image:
                    pixels = image.convert("RGBA")
                pixels.save(path, compress_level=0)
                self.assertNotEqual(encoded, path.read_bytes())
            self.assertEqual(run("--check"), (0, "CHECK-OK\n"))
            self.assertEqual(manifest.read_bytes(), records)

    def test_check_requires_rest_record_after_processing(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            status, output = run("--check")
            self.assertEqual(status, 1)
            self.assertIn("rest rebake needed: paint/rest.png: no rebake record", output)
            self.assertEqual(run("--record-rests"), (0, "RECORDED-RESTS 1 file(s)\n"))
            self.assertEqual(run("--check"), (0, "CHECK-OK\n"))

    def test_changed_rest_pixels_require_rebake(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            self.assertEqual(run("--record-rests")[0], 0)
            with Image.open(root / "paint/rest.png") as image:
                rest = image.convert("RGBA")
            rest.putpixel((4, 4), (0, 0, 0, 255))
            rest.save(root / "paint/rest.png")
            status, output = run("--check")
            self.assertEqual(status, 1)
            self.assertIn("rest rebake needed: paint/rest.png: rest pixels changed since recorded rebake", output)

    def test_changed_parts_require_rebake_even_when_paint_is_current(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            self.assertEqual(run("--record-rests")[0], 0)
            rest_record = json.loads(manifest.read_text())["paint/rest.png"]
            with Image.open(root / "sources/paint/part.png") as image:
                source = np.asarray(image.convert("RGBA")).copy()
            source[..., :3][source[..., 3] > 0] = (210, 180, 150)
            Image.fromarray(source).save(root / "sources/paint/part.png")
            self.assertEqual(run()[0], 0)
            current = json.loads(manifest.read_text())
            self.assertEqual(current["paint/rest.png"], rest_record, "Processing must preserve the last rebake record")
            self.assertEqual(tool.paint_errors(tool.load_registry()["entries"], current), [])
            status, output = run("--check")
            self.assertEqual(status, 1)
            self.assertIn("rest rebake needed: paint/rest.png: rig part pixels changed since recorded rebake", output)

    def test_unpremultiplied_colour_rounds_to_nearest_integer(self) -> None:
        pixels = np.full((8, 8, 4), 10, dtype=np.uint8)
        pixels[..., 3] = 255
        pixels[2:4, 2:4, :3] = 11
        pixels[2, 2, :3] = 10
        output = np.asarray(density.regrid(Image.fromarray(pixels), 2.0))
        np.testing.assert_array_equal(output[2, 2], (11, 11, 11, 255))

    def test_continuous_strength_knots_and_clamps(self) -> None:
        for share, expected in ((0, 1.0), (0.05, 1.0), (0.075, 1.125), (0.10, 1.25), (0.15, 1.5), (1, 1.5)):
            self.assertAlmostEqual(density.strength(share), expected)

    def test_resample_frames_are_independent_and_share_the_first_frame_class(self) -> None:
        source = self.image()
        # Only frame 0 selects the class; sampling/regridding remains frame-local.
        pixels = np.asarray(source).copy()
        pixels[..., 3] = np.where(pixels[..., 3] > 24, 255, 0)
        pixels[:6, :8, 3] = np.where(pixels[:6, :8, 3] > 0, 100, 0)
        source = Image.fromarray(pixels)
        frames = {"grid": [2, 2]}
        first_class = density.classify_alpha(source.crop((0,0,8,6)))["alpha_class"]
        self.assertEqual(first_class, "soft")
        result = density.process(source, "resample", 1.5, frames, 1.7)
        differs_from_per_frame = False
        for old, new in zip(density.frame_rects(source.size, frames), density.frame_rects(result.size, frames)):
            x,y,w,h = old
            xx,yy,ww,hh = new
            frame = source.crop((x,y,x+w,y+h))
            expected = density.resample_frame(frame, 1.7, alpha_class=first_class)
            self.assertEqual(result.crop((xx,yy,xx+ww,yy+hh)).tobytes(), expected.tobytes())
            near = np.asarray(frame.resize((ww,hh), Image.Resampling.NEAREST))
            self.assertFalse(((np.asarray(expected)[...,3] > 0) & (near[...,3] == 0)).any())
            differs_from_per_frame |= expected.tobytes() != density.resample_frame(frame, 1.7).tobytes()
        self.assertTrue(differs_from_per_frame, "Later frames must keep frame 0's class even when their own paint differs")

    def test_per_axis_sheet_resampling_keeps_frame_sizes_and_local_grid(self) -> None:
        source = self.image()
        frames = {"grid": [2, 2]}
        scale = [2.1, 1.6]
        result = density.process(source, "resample", 1.5, frames, scale, "solid")
        self.assertEqual(result.size, (34, 20))
        for old, new in zip(density.frame_rects(source.size, frames), density.frame_rects(result.size, frames)):
            x,y,w,h = old
            xx,yy,ww,hh = new
            self.assertEqual((ww,hh), (17,10))
            expected = density.resample_frame(source.crop((x,y,x+w,y+h)), scale, alpha_class="solid")
            self.assertEqual(result.crop((xx,yy,xx+ww,yy+hh)).tobytes(), expected.tobytes())
        scalar = density.process(source, "resample", 1.5, frames, 1.7)
        pair = density.process(source, "resample", 1.5, frames, [1.7,1.7])
        self.assertEqual(scalar.size, pair.size)
        self.assertEqual(scalar.tobytes(), pair.tobytes())

    def test_alpha_classification_counts_only_nonzero_pixels_and_uses_strict_threshold(self) -> None:
        pixels = np.zeros((10, 20, 4), dtype=np.uint8)
        pixels[:5, :, 3] = 255
        # Faint halos and nearly opaque paint do not count as translucent.
        pixels[1, :, 3] = (1, 63, 240, 254) * 5
        for count, expected in ((0, "solid"), (9, "solid"), (10, "soft"), (11, "soft")):
            frame = pixels.copy()
            frame[0, :count, 3] = np.where(np.arange(count) % 2, 239, 64)
            classification = density.classify_alpha(Image.fromarray(frame))
            self.assertEqual(classification, {"alpha_class": expected, "translucent_alpha_fraction": count/100})
        self.assertEqual(density.classify_alpha(Image.new("RGBA", (8, 8))),
                         {"alpha_class": "solid", "translucent_alpha_fraction": 0.0})

    def test_solid_hybrid_keeps_faint_halo_and_restores_the_body_outline(self) -> None:
        paint = np.full((12, 16, 4), (91, 74, 56, 0), dtype=np.uint8)
        paint[1:11, 1:15] = (126, 99, 65, 12)
        paint[2:10, 2:14] = (18, 12, 8, 245)
        paint[3:9, 3:13] = (195, 163, 118, 245)
        source = Image.fromarray(paint)
        self.assertEqual(density.classify_alpha(source)["alpha_class"], "solid")
        result = density.resample_frame(source, 1.7)
        lanczos = np.asarray(Image.fromarray(paint[...,3].astype(np.float32)).resize(
            result.size, Image.Resampling.LANCZOS))
        bilinear = np.asarray(Image.fromarray(paint[...,3].astype(np.float32)).resize(
            result.size, Image.Resampling.BILINEAR))
        weight = np.asarray(Image.fromarray((paint[...,3] > 0).astype(np.float32)).resize(
            result.size, Image.Resampling.BILINEAR))
        bilinear = bilinear / np.maximum(weight, 1e-3)
        near = np.asarray(source.resize(result.size, Image.Resampling.NEAREST))
        support = near[...,3] > 0
        body = (lanczos.clip(0,255) >= 128) & support
        expected_alpha = np.where(body, near[...,3], np.where(support, np.rint(bilinear.clip(0,255)), 0))
        pixels = np.asarray(result)
        np.testing.assert_array_equal(pixels[...,3], expected_alpha.astype(np.uint8))
        self.assertTrue(((pixels[...,3] > 0) & (pixels[...,3] < 128)).any(), "Keep the faint halo")
        ring = density.edge_ring(body) & (near[...,3] >= 128)
        self.assertTrue((ring & ~density.edge_ring(support)).any(), "Outline belongs to the body, inside the halo")
        np.testing.assert_array_equal(pixels[..., :3][ring], near[..., :3][ring])
        self.assertTrue((near[..., :3][ring] == (18, 12, 8)).all(axis=-1).any(), "Keep the dark body rim")
        hidden = pixels[...,3] == 0
        np.testing.assert_array_equal(pixels[..., :3][hidden], near[..., :3][hidden])

    def test_soft_resample_alpha_is_normalized_bilinear_support_limited_and_fringe_is_nearest(self) -> None:
        pixels = np.asarray(self.image()).copy()
        pixels[2:6, 2:8, 3] = 100
        source = Image.fromarray(pixels)
        self.assertEqual(density.classify_alpha(source)["alpha_class"], "soft")
        result = density.resample_frame(source, 1.7)
        alpha = np.asarray(Image.fromarray(np.asarray(source)[...,3].astype(np.float32)).resize(
            result.size, Image.Resampling.BILINEAR))
        weight = np.asarray(Image.fromarray((np.asarray(source)[...,3] > 0).astype(np.float32)).resize(
            result.size, Image.Resampling.BILINEAR))
        alpha = alpha / np.maximum(weight, 1e-3)
        near = np.asarray(source.resize(result.size, Image.Resampling.NEAREST))
        expected_alpha = np.where(near[...,3] > 0, np.rint(alpha.clip(0,255)), 0).astype(np.uint8)
        np.testing.assert_array_equal(np.asarray(result)[...,3], expected_alpha)
        self.assertFalse(set(result.getchannel("A").getdata()) <= {0, 255})
        pixels = np.asarray(result)
        hidden = pixels[...,3] == 0
        np.testing.assert_array_equal(pixels[..., :3][hidden], near[..., :3][hidden])

    def test_normalized_bilinear_preserves_uniform_paint_on_sparse_support(self) -> None:
        for alpha_class in ("solid", "soft"):
            for alpha in (255, 245, 219, 178, 133, 87, 46, 18, 12):
                with self.subTest(alpha_class=alpha_class, alpha=alpha):
                    paint = np.full((12, 16, 4), (91, 74, 56, 0), dtype=np.uint8)
                    paint[2, 3] = (126, 99, 65, alpha)
                    paint[5:9, 7:13] = (126, 99, 65, alpha)
                    source = Image.fromarray(paint)
                    result = density.resample_frame(source, [2.03, 1.55], alpha_class=alpha_class)
                    near = np.asarray(source.resize(result.size, Image.Resampling.NEAREST))
                    pixels = np.asarray(result)
                    np.testing.assert_array_equal(pixels[...,3], near[...,3])
                    hidden = pixels[...,3] == 0
                    np.testing.assert_array_equal(pixels[..., :3][hidden], near[..., :3][hidden])
                    if alpha_class == "soft":
                        np.testing.assert_array_equal(pixels[..., :3][~hidden], near[..., :3][~hidden])

    def test_boundary_distance_uses_chebyshev_and_catches_interior_changes(self) -> None:
        source = np.zeros((12, 12), dtype=bool)
        source[2:10, 2:10] = True
        for point, expected in (((1, 1), 1), ((0, 0), 2), ((5, 5), 3)):
            changed = source.copy()
            changed[point] = ~changed[point]
            self.assertEqual(silhouette_boundary_distance(source, changed), expected)

    def test_resample_cli_reruns_from_sources_are_idempotent(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            registry = json.loads(tool.REGISTRY.read_text())
            entry = registry["entries"][0]
            entry.update(kind="prop", mode="resample", scale=1.7, grid=1.5)
            entry.pop("rest_paths")
            tool.REGISTRY.write_text(json.dumps(registry))
            self.assertEqual(run()[0], 0)
            pixels = (root / "paint/part.png").read_bytes()
            records = manifest.read_bytes()
            self.assertEqual(run()[0], 0)
            self.assertEqual((root / "paint/part.png").read_bytes(), pixels)
            self.assertEqual(manifest.read_bytes(), records)
            self.assertEqual(run("--check"), (0, "CHECK-OK\n"))

    def test_per_axis_cli_records_scales_and_reports_both_pixel_ratios(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            registry = json.loads(tool.REGISTRY.read_text())
            entry = registry["entries"][0]
            entry.update(kind="prop", mode="resample", scale=[1.7,1.3], r=1.7,
                         r_axes=[1.7,1.3], t=1.5, grid=1.5)
            entry.pop("rest_paths")
            tool.REGISTRY.write_text(json.dumps(registry))
            self.assertEqual(run()[0], 0)
            record = json.loads(manifest.read_text())["paint/part.png"]
            self.assertEqual(record["scale"], [1.7,1.3])
            with Image.open(root / "sources/paint/part.png") as source, Image.open(root / "paint/part.png") as output:
                self.assertEqual(output.size, (round(source.width*1.7), round(source.height*1.3)))
            self.assertEqual(run("--check"), (0, "CHECK-OK\n"))
            with mock.patch.object(tool, "REPORT", root / "report.md"):
                self.assertEqual(run("--report")[0], 0)
            row = next(line for line in (root / "report.md").read_text().splitlines() if line.startswith("| fixture |"))
            self.assertIn("| 1.700 → 1.000 | 1.300 → 1.000 |", row)

    def test_family_class_comes_from_static_measurement_even_with_only(self) -> None:
        with self.temporary_rig() as (root, manifest, run):
            source = self.image()
            source.save(root / "sources/paint/part.png")
            plate = {"id": "plate", "kind": "prop", "paths": ["paint/part.png"],
                     "measurement_path": "paint/part.png", "mode": "resample", "scale": 1.7,
                     "grid": 1.5, "frames": None}
            sheets = {**plate, "id": "sheets", "paths": ["paint/sheet.png"],
                      "measurement_path": "paint/sheet.png", "frames": {"grid": [2, 2]},
                      "alpha_class_from": "plate"}
            registry = {"hero_reference": "paint/hero.png", "entries": [plate, sheets]}
            tool.REGISTRY.write_text(json.dumps(registry))
            translucent = np.asarray(source).copy()
            translucent[1:4, 1:4, 3] = 100
            sheet = Image.fromarray(translucent)
            self.assertEqual(density.classify_alpha(sheet.crop((0,0,8,6)))["alpha_class"], "soft")
            sheet.save(root / "paint/sheet.png")
            self.assertEqual(run("--adopt", "paint/sheet.png")[0], 0)
            self.assertIn("paint/part.png", tool.source_paths(registry, [sheets]))
            self.assertEqual(run()[0], 0)
            record = json.loads(manifest.read_text())["paint/sheet.png"]
            self.assertEqual(record["alpha_class"], "solid")
            self.assertEqual(record["alpha_class_from"], "plate")
            expected = density.process(sheet, "resample", 1.5, sheets["frames"], 1.7, "solid")
            self.assertTrue(tool.same_pixels(root / "paint/sheet.png", expected))
            self.assertTrue(expected.tobytes() != density.process(sheet, "resample", 1.5, sheets["frames"], 1.7).tobytes())
            source.save(root / "sources/paint/part.png", compress_level=0)
            self.assertEqual(run("--check", "--only", "sheets"), (0, "CHECK-OK\n"))
            # Changing the static measurement selects the new path for every
            # child frame, even when only that child is processed or checked.
            measurement = np.asarray(source).copy()
            measurement[...,3] = np.where(measurement[...,3] > 0, 100, 0)
            Image.fromarray(measurement).save(root / "sources/paint/part.png")
            self.assertEqual(run("--check", "--only", "sheets")[0], 1)
            self.assertEqual(run("--only", "sheets")[0], 0)
            record = json.loads(manifest.read_text())["paint/sheet.png"]
            self.assertEqual(record["alpha_class"], "soft")
            self.assertTrue(tool.same_pixels(root / "paint/sheet.png",
                                            density.process(sheet, "resample", 1.5, sheets["frames"], 1.7, "soft")))
            self.assertEqual(run("--check", "--only", "sheets"), (0, "CHECK-OK\n"))

    def test_alpha_family_links_reject_missing_sources_and_cycles(self) -> None:
        source = {"id": "source"}
        child = {"id": "child", "alpha_class_from": "source"}
        registry = {"entries": [source, child]}
        self.assertIs(tool.alpha_source_entry(child, registry), source)
        child["alpha_class_from"] = "missing"
        with self.assertRaisesRegex(ValueError, "unknown alpha_class_from"):
            tool.alpha_source_entry(child, registry)
        child["alpha_class_from"] = "source"
        source["alpha_class_from"] = "child"
        with self.assertRaisesRegex(ValueError, "cyclic alpha_class_from"):
            tool.alpha_source_entry(child, registry)

    def test_trap_preview_uses_current_canvas_and_fits_legacy_floors(self) -> None:
        with tempfile.TemporaryDirectory(dir=REGISTRY.parent) as directory:
            root = Path(directory)
            (root / "traps").mkdir()
            (root / "floors").mkdir()
            for _, element, variant in trap_preview.ELEMENTS:
                Image.new("RGBA", (248, 162), (100, 20, 30, 255)).save(root / "traps" / f"trap_{element}.png")
                Image.new("RGBA", (122, 80), (40, 50, 60, 255)).save(root / "floors" / f"base_floor_tile_{variant:02d}.png")
            with mock.patch.multiple(trap_preview, TRAP_DIR=root / "traps", FLOOR_DIR=root / "floors"):
                sheet = trap_preview.build_sheet()
            self.assertEqual(sheet.size, (3892, 1186))

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
                density.resample_frame(image, grid)
        for scale in ([1], [1,2,3], [0,1], [1,-1], [1,float("nan")]):
            with self.assertRaises(ValueError):
                density.resample_frame(image, scale)
        with self.assertRaises(ValueError):
            density.process(image, "posterise", 1.5)
        with self.assertRaisesRegex(ValueError, "alpha_class must be solid or soft"):
            density.resample_frame(image, 1.7, alpha_class="hard")

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
                records["paint/b.png"]["pixel_sha256"] = "stale"
                manifest.write_text(json.dumps(records))
                self.assertEqual(run("--check"), 1)


if __name__ == "__main__":
    unittest.main()

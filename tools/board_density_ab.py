#!/usr/bin/env python3
"""Build matched board-density sheets; exit nonzero on determinism failures.

Usage: board_density_ab.py BEFORE_DIR AFTER_DIR OUT_DIR
       board_density_ab.py --self-test

Directories contain board_density_probe.gd stills and manifest.json. Rects are
screen-space [x, y, width, height]; floor_polygons describe the allowed floor.
Only the manifest label (if supplied externally) may differ. Every other piece
of metadata, including idle frames, placement, facing and camera, must match.
Pixel comparison is exact across all RGBA channels, outside the union of draw
rects and the floor. The 12px crop padding never widens the comparison mask.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

PADDING = 12
ZOOM = 3
GAP = 16
TITLE_HEIGHT = 32
BACKGROUND = (24, 22, 20)
TEXT = (236, 220, 192)


def _filename(value: object, directory: Path) -> Path:
    if not isinstance(value, str) or not value.endswith(".png") or Path(value).name != value:
        raise ValueError(f"Invalid still filename in {directory / 'manifest.json'}: {value!r}")
    return directory / value


def _load(directory: Path) -> dict:
    with (directory / "manifest.json").open(encoding="utf-8") as source:
        manifest = json.load(source)
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("scenes"), dict) or not manifest["scenes"]:
        raise ValueError(f"Unsupported or empty board density manifest: {directory}")
    size = manifest.get("size")
    if not isinstance(size, list) or len(size) != 2 or any(not isinstance(n, int) or n <= 0 for n in size):
        raise ValueError(f"Invalid frame size: {directory}")
    for name, scene in manifest["scenes"].items():
        if not re.fullmatch(r"[a-zA-Z0-9_-]+", name):
            raise ValueError(f"Invalid scene name: {name!r}")
        _filename(scene.get("image"), directory)
        if not isinstance(scene.get("rects"), list) or not scene["rects"]:
            raise ValueError(f"Missing draw rects: {name}")
        keys = set()
        for entry in scene["rects"]:
            key = entry.get("key")
            if not isinstance(key, str) or not key or key in keys or not isinstance(entry.get("type"), str):
                raise ValueError(f"Invalid or duplicate rect identity: {name}: {entry!r}")
            keys.add(key)
            _box(entry)
        if "player" not in keys:
            raise ValueError(f"Missing hero reference: {name}")
        polygons = scene.get("floor_polygons")
        if not isinstance(polygons, list) or not polygons:
            raise ValueError(f"Missing floor polygons: {name}")
        for polygon in polygons:
            if not isinstance(polygon, list) or len(polygon) < 3:
                raise ValueError(f"Invalid floor polygon: {name}")
            for point in polygon:
                if not isinstance(point, list) or len(point) != 2 or not all(_number(n) for n in point):
                    raise ValueError(f"Invalid floor point: {name}: {point!r}")
    return manifest


def _number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _box(entry: dict, padding: int = 0) -> tuple[int, int, int, int]:
    rect = entry.get("rect")
    if not isinstance(rect, list) or len(rect) != 4 or not all(_number(n) for n in rect) or rect[2] <= 0 or rect[3] <= 0:
        raise ValueError(f"Invalid draw rect: {entry!r}")
    x, y, width, height = rect
    return (math.floor(x) - padding, math.floor(y) - padding,
            math.ceil(x + width) + padding, math.ceil(y + height) + padding)


def _changed_pixels(before: Image.Image, after: Image.Image, scene: dict) -> tuple[int, tuple | None]:
    mask = Image.new("L", before.size, 0)
    draw = ImageDraw.Draw(mask)
    for entry in scene["rects"]:
        left, top, right, bottom = _box(entry)
        # PIL rectangle endpoints are inclusive; manifest ends are exclusive.
        draw.rectangle((left, top, right - 1, bottom - 1), fill=255)
    for polygon in scene["floor_polygons"]:
        draw.polygon([tuple(point) for point in polygon], fill=255)
    channels = ImageChops.difference(before, after).split()
    delta = channels[0]
    for channel in channels[1:]:
        delta = ImageChops.lighter(delta, channel)
    changed = delta.point(lambda n: 255 if n else 0)
    outside = ImageChops.multiply(changed, ImageChops.invert(mask))
    return outside.histogram()[255], outside.getbbox()


def _crop(image: Image.Image, entry: dict) -> Image.Image:
    cropped = image.crop(_box(entry, PADDING)).convert("RGB")
    return cropped.resize((cropped.width * ZOOM, cropped.height * ZOOM), Image.Resampling.NEAREST)


def _text(draw: ImageDraw.ImageDraw, position: tuple[int, int], value: str) -> None:
    draw.text(position, value, font=ImageFont.load_default(), fill=TEXT)


def _full_sheet(before: Image.Image, after: Image.Image, target: Path, scene_name: str) -> None:
    sheet = Image.new("RGB", (before.width * 2 + GAP, before.height + TITLE_HEIGHT), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    _text(draw, (8, 9), f"{scene_name} | before")
    _text(draw, (before.width + GAP + 8, 9), f"{scene_name} | after")
    sheet.paste(before.convert("RGB"), (0, TITLE_HEIGHT))
    sheet.paste(after.convert("RGB"), (before.width + GAP, TITLE_HEIGHT))
    sheet.save(target)


def _crop_sheet(before: Image.Image, after: Image.Image, scene: dict, target: Path) -> None:
    hero = next(entry for entry in scene["rects"] if entry["key"] == "player")
    reference = _crop(before, hero)
    rows = [(entry, _crop(before, entry), _crop(after, entry)) for entry in scene["rects"]]
    subject_width = max(max(left.width, right.width) for _, left, right in rows)
    # Allow long labels without hiding them behind the next column.
    reference_width = max(reference.width, 200)
    subject_width = max(subject_width, 300)
    sheet_width = reference_width + subject_width * 2 + GAP * 2
    row_heights = [TITLE_HEIGHT + max(reference.height, left.height, right.height) + GAP for _, left, right in rows]
    sheet = Image.new("RGB", (sheet_width, sum(row_heights)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    y = 0
    for (entry, left, right), row_height in zip(rows, row_heights):
        xs = (0, reference_width + GAP, reference_width + subject_width + GAP * 2)
        _text(draw, (8, y + 9), f"hero reference (before, {scene['hero_facing']})")
        _text(draw, (xs[1] + 8, y + 9), f"before | {entry['key']} | {entry['type']}")
        _text(draw, (xs[2] + 8, y + 9), f"after | {entry['key']} | {entry['type']}")
        for x, crop in zip(xs, (reference, left, right)):
            sheet.paste(crop, (x, y + TITLE_HEIGHT))
        y += row_height
    sheet.save(target)


def build(before_dir: Path, after_dir: Path, out_dir: Path) -> dict:
    before_dir, after_dir, out_dir = (path.resolve() for path in (before_dir, after_dir, out_dir))
    if before_dir == after_dir or out_dir in (before_dir, after_dir) or any(out_dir in path.parents or path in out_dir.parents for path in (before_dir, after_dir)):
        raise ValueError("Before, after and output directories must be separate; output cannot contain or sit inside an input")
    before_manifest, after_manifest = _load(before_dir), _load(after_dir)
    failures = []
    before_meta = {key: value for key, value in before_manifest.items() if key not in ("label", "scenes")}
    after_meta = {key: value for key, value in after_manifest.items() if key not in ("label", "scenes")}
    if before_meta != after_meta:
        failures.append("Capture metadata differs (resolution, scale, seed, phase or errors)")
    for label, directory, manifest in (("before", before_dir, before_manifest), ("after", after_dir, after_manifest)):
        if manifest.get("errors"):
            failures.append(f"{label} probe reported errors: {manifest['errors']}")
        expected = {scene["image"] for scene in manifest["scenes"].values()}
        actual = {path.name for path in directory.glob("*.png")}
        if expected != actual:
            failures.append(f"{label} still inventory differs from manifest: missing={sorted(expected - actual)}, extra={sorted(actual - expected)}")
    before_scenes, after_scenes = before_manifest["scenes"], after_manifest["scenes"]
    if set(before_scenes) != set(after_scenes):
        failures.append(f"Scene inventory differs: before={sorted(before_scenes)}, after={sorted(after_scenes)}")
    out_dir.mkdir(parents=True, exist_ok=True)
    results = []
    links = []
    for name, scene in before_scenes.items():
        if name not in after_scenes:
            continue
        other = after_scenes[name]
        if scene != other:
            failures.append(f"{name}: scene metadata differs (draw rects, camera, hero facing, idle frames or fixture)")
        with Image.open(_filename(scene["image"], before_dir)) as source:
            before = source.convert("RGBA")
        with Image.open(_filename(other["image"], after_dir)) as source:
            after = source.convert("RGBA")
        if before.size != after.size or list(before.size) != before_manifest["size"] or list(after.size) != after_manifest["size"]:
            failures.append(f"{name}: image dimensions differ from one another or the manifest")
            continue
        count, bounds = _changed_pixels(before, after, scene)
        if count:
            failures.append(f"{name}: {count} changed pixels outside manifest rects/floor; bounds={bounds}")
        full_name, crops_name = f"{name}_full.png", f"{name}_crops.png"
        _full_sheet(before, after, out_dir / full_name, name)
        _crop_sheet(before, after, scene, out_dir / crops_name)
        results.append({"scene": name, "unexpected_pixels": count, "unexpected_bounds": bounds,
                        "full_sheet": full_name, "crop_sheet": crops_name, "crop_rows": len(scene["rects"])})
        links.append(f"- **{name}**: [full frame]({full_name}), [3x crops]({crops_name}) ({len(scene['rects'])} rows)")
    status = "FAIL" if failures else "PASS"
    report = {"status": status, "before_dir": str(before_dir), "after_dir": str(after_dir), "failures": failures, "scenes": results}
    (out_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    index = ["# Board density before / after", "", f"Determinism: **{status}**", "",
             "Full frames are before | after. Every crop row starts with the same scene's before hero reference, then before | after for the named draw rect. Crops have 12px padding and use 3x nearest enlargement.", "", *links]
    if failures:
        index += ["", "## Determinism failures", "", *[f"- {failure}" for failure in failures]]
    (out_dir / "index.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    return report


def self_test() -> None:
    """Exercise the builder on synthetic captures, including failures."""
    with tempfile.TemporaryDirectory(prefix="board-density-ab-") as temp:
        root = Path(temp)
        before_dir, after_dir = root / "before", root / "after"
        before_dir.mkdir()
        after_dir.mkdir()
        scene = {"image": "synthetic.png", "tile_width": 10.0, "hero_facing": "rear", "idle_frames": {"tl": 0, "tr": 3},
                 "fixture": "synthetic", "rects": [
                     {"key": "player", "type": "player", "kind": "actor", "rect": [10, 10, 5, 8]},
                     {"key": "torch", "type": "column_torch_left", "kind": "prop", "rect": [30.2, 10.2, 4.5, 6.5]}],
                 "floor_polygons": [[[5, 30], [40, 30], [40, 40], [5, 40]]]}
        manifest = {"schema_version": 1, "size": [64, 48], "seed": 1, "ui_scale": 1.0, "phase_seconds": 0.0, "errors": [], "scenes": {"synthetic": scene}}
        for directory in (before_dir, after_dir):
            (directory / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        before = Image.new("RGBA", (64, 48), (20, 30, 40, 255))
        before.save(before_dir / "synthetic.png")
        after = before.copy()
        after.putpixel((12, 12), (200, 30, 40, 255))
        after.putpixel((33, 13), (20, 200, 40, 255))
        after.putpixel((15, 35), (20, 30, 200, 255))
        after.save(after_dir / "synthetic.png")
        report = build(before_dir, after_dir, root / "sheets")
        assert report["status"] == "PASS", report
        assert report["scenes"][0]["crop_rows"] == 2
        assert (root / "sheets" / "index.md").is_file()
        with Image.open(root / "sheets" / "synthetic_full.png") as full:
            assert full.size == (64 * 2 + GAP, 48 + TITLE_HEIGHT)
            assert full.getpixel((12, 12 + TITLE_HEIGHT)) == (20, 30, 40)
            assert full.getpixel((64 + GAP + 12, 12 + TITLE_HEIGHT)) == (200, 30, 40)
        crop = _crop(before, scene["rects"][0])
        assert crop.size == ((5 + PADDING * 2) * ZOOM, (8 + PADDING * 2) * ZOOM)
        subject = _crop(after, scene["rects"][0])
        px = (PADDING + 2) * ZOOM
        assert all(subject.getpixel((px + x, px + y)) == (200, 30, 40) for x in range(ZOOM) for y in range(ZOOM))
        with Image.open(root / "sheets" / "synthetic_crops.png") as crops:
            assert crops.size == (200 + 300 * 2 + GAP * 2, (TITLE_HEIGHT + crop.height + GAP) * 2)
            second_row = TITLE_HEIGHT + crop.height + GAP
            assert crops.getpixel((px, TITLE_HEIGHT + px)) == (20, 30, 40)
            assert crops.getpixel((px, second_row + TITLE_HEIGHT + px)) == (20, 30, 40)
            assert crops.getpixel((200 + 300 + GAP * 2 + px, TITLE_HEIGHT + px)) == (200, 30, 40)
        # RGB-only changes must be detected even though the RGBA diff alpha is 0.
        after.putpixel((55, 5), (21, 30, 40, 255))
        # Crop padding is presentation only, never an allowed-change region.
        after.putpixel((9, 10), (21, 30, 40, 255))
        after.save(after_dir / "synthetic.png")
        report = build(before_dir, after_dir, root / "pixel_failure")
        assert report["status"] == "FAIL" and report["scenes"][0]["unexpected_pixels"] == 2, report
        after = before.copy()
        after.putpixel((55, 5), (20, 30, 40, 254))
        after.save(after_dir / "synthetic.png")
        assert build(before_dir, after_dir, root / "alpha_failure")["scenes"][0]["unexpected_pixels"] == 1
        after = before.copy()
        after.save(after_dir / "synthetic.png")
        scene["hero_facing"] = "front"
        (after_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        assert build(before_dir, after_dir, root / "metadata_failure")["status"] == "FAIL"
        scene["hero_facing"] = "rear"
        manifest["scenes"]["extra"] = dict(scene)
        (after_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        assert build(before_dir, after_dir, root / "inventory_failure")["status"] == "FAIL"
        for invalid in ([0, 0, -1, 2], [0, 0, float("nan"), 2]):
            try:
                _box({"rect": invalid})
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid rect accepted")
    print("BOARD DENSITY AB SELF-TEST: PASS")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("before_dir", nargs="?", type=Path)
    parser.add_argument("after_dir", nargs="?", type=Path)
    parser.add_argument("out_dir", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if None in (args.before_dir, args.after_dir, args.out_dir):
        parser.error("before_dir, after_dir and out_dir are required (or use --self-test)")
    try:
        report = build(args.before_dir, args.after_dir, args.out_dir)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"BOARD DENSITY AB: FAIL: {error}\n")
    print(f"BOARD DENSITY AB: {report['status']}")
    for failure in report["failures"]:
        print(f"DETERMINISM FAILURE: {failure}")
    print(args.out_dir.resolve() / "index.md")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())

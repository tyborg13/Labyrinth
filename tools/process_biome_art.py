#!/usr/bin/env python3
"""Fit approved biome repaints to the board templates; never generate paint."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

import process_board_density as density
from pixel_density import metrics, process

ROOT = Path(__file__).resolve().parents[1]
FLOOR_VARIANTS = ("02", "03", "05", "06")
# Director-approved zero-based frames in the sixteen-frame idle cycle.
SPARK_FLASH_FRAMES: tuple[int, ...] = (4, 11)


def key_green(image: Image.Image) -> Image.Image:
    pixels = np.asarray(image.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(np.float32)
    other = np.maximum(rgb[..., 0], rgb[..., 2])
    screen = rgb[..., 1] > other * 1.35 + 16
    pixels[screen] = 0
    # Despill the remaining mixed edge samples, including faint AA fringes.
    pixels[..., 1] = np.minimum(pixels[..., 1], np.maximum(pixels[..., 0], pixels[..., 2]))
    return Image.fromarray(pixels)


def grade(image: Image.Image, gains: list[float]) -> Image.Image:
    pixels = np.asarray(image).copy()
    pixels[..., :3] = np.rint(pixels[..., :3].astype(float) * gains).clip(0, 255).astype(np.uint8)
    return Image.fromarray(pixels)


def fill_nearest(pixels: np.ndarray, wanted: np.ndarray) -> None:
    """Nearest Euclidean painted sample, with stable row-major tie breaking."""
    painted = np.argwhere(pixels[..., 3] > 0)
    if not len(painted):
        raise ValueError("repaint has no painted pixels")
    holes = np.argwhere(wanted & (pixels[..., 3] == 0))
    for start in range(0, len(holes), 64):
        batch = holes[start:start + 64]
        distances = ((batch[:, None, :] - painted[None, :, :]) ** 2).sum(axis=2)
        nearest = painted[np.argmin(distances, axis=1)]
        pixels[batch[:, 0], batch[:, 1], :3] = pixels[nearest[:, 0], nearest[:, 1], :3]


def fit_repaint(repaint: Image.Image, template: Image.Image, reuse_alpha: bool) -> Image.Image:
    bbox = repaint.getchannel("A").getbbox()
    target = template.getchannel("A").getbbox()
    if bbox is None or target is None:
        raise ValueError("empty alpha bounding box")
    fitted = repaint.crop(bbox).resize((target[2] - target[0], target[3] - target[1]), Image.Resampling.BOX)
    result = Image.new("RGBA", template.size)
    result.paste(fitted, target[:2])
    if reuse_alpha:
        pixels = np.asarray(result).copy()
        alpha = np.asarray(template.getchannel("A"))
        fill_nearest(pixels, alpha > 0)
        pixels[..., 3] = alpha
        result = Image.fromarray(pixels)
    return result


def match_floors(floors: list[Image.Image]) -> list[Image.Image]:
    means = np.array([np.asarray(im)[..., :3][np.asarray(im)[..., 3] > 0].mean(axis=0) for im in floors])
    median = np.median(means, axis=0)
    return [grade(im, np.clip(median / np.maximum(mean, 1e-9), 0.85, 1.15).tolist())
            for im, mean in zip(floors, means)]


def density_entry(path: str, registry: dict) -> dict:
    return next(entry for entry in registry["entries"] if path in entry["paths"])


def treat(image: Image.Image, path: str, registry: dict) -> Image.Image:
    entry = density_entry(path, registry)
    settings = density.settings_for_path(entry, path)
    alpha = density.alpha_settings(entry, registry) if settings["mode"] == "resample" else {}
    return process(image, settings["mode"], settings["grid"], entry["frames"],
                   settings.get("scale", 1.0), alpha.get("alpha_class"))


def idle_sheet(light: Image.Image, size: tuple[int, int], kind: str) -> Image.Image:
    # Stone declares sixteen row-major frames in a 4x4 grid (188x344 each).
    frame = light.resize((size[0] // 4, size[1] // 4), Image.Resampling.BOX)
    source = np.asarray(frame)
    glow = (source[..., :3].astype(float) @ np.array([0.2126, 0.7152, 0.0722]) / 255 > 0.55) & (source[..., 3] > 0)
    sheet = Image.new("RGBA", size)
    for index in range(16):
        phase = (1 - np.cos(2 * np.pi * index / 16)) / 2
        gain = {"flame": 0.86 + 0.20 * phase, "glow": 0.92 + 0.13 * phase,
                "spark": 1.25 if index in SPARK_FLASH_FRAMES else 0.9}[kind]
        pixels = source.copy()
        pixels[glow, :3] = np.rint(source[glow, :3].astype(float) * gain).clip(0, 255).astype(np.uint8)
        if kind == "flame" and index % 2:
            # Move only the glow region up one pixel; never wrap the sheet edge.
            pixels[glow] = 0
            ys, xs = np.nonzero(glow)
            valid = ys > 0
            pixels[ys[valid] - 1, xs[valid]] = np.column_stack((
                np.rint(source[ys[valid], xs[valid], :3].astype(float) * gain).clip(0, 255).astype(np.uint8),
                source[ys[valid], xs[valid], 3]))
        sheet.paste(Image.fromarray(pixels), ((index % 4) * frame.width, (index // 4) * frame.height))
    return sheet


def process_biome(raw_dir: Path, biome: str, output_dir: Path, definition: dict) -> dict:
    registry = density.load_registry()
    templates = [f"assets/placeholders/tiles/base_floor_tile_{v}.png" for v in FLOOR_VARIANTS]
    floors = []
    hashes = {}

    def raw(name: str) -> Image.Image:
        path = raw_dir / f"{biome}_{name}.png"
        hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        with Image.open(path) as image:
            return key_green(image)

    def source(path: str) -> Image.Image:
        with Image.open(density.SOURCES / path) as image:
            return image.convert("RGBA")

    gains = definition.get("raw_grade", {})
    for variant, path in zip(FLOOR_VARIANTS, templates):
        repaint = grade(raw(f"floor_{variant}"), gains.get("floor", [1, 1, 1]))
        floors.append(fit_repaint(repaint, source(path), True))
    outputs = {f"floor_{v}.png": treat(im, path, registry)
               for v, im, path in zip(FLOOR_VARIANTS, match_floors(floors), templates)}
    pillar_path = "assets/placeholders/tiles/pillar.png"
    outputs["pillar.png"] = treat(fit_repaint(grade(raw("pillar"), gains.get("pillar", [1, 1, 1])),
                                            source(pillar_path), True), pillar_path, registry)
    light_path = "assets/art/tiles/column_torch_left.png"
    fitted_light = fit_repaint(raw("light"), source(light_path), False)
    outputs["light_left.png"] = treat(fitted_light, light_path, registry)
    outputs["light_right.png"] = ImageOps.mirror(outputs["light_left.png"])
    idle_path = "assets/art/tiles/column_torch_left_idle.png"
    sheet = idle_sheet(fitted_light, source(idle_path).size, definition["light_flicker"])
    outputs["light_left_idle.png"] = treat(sheet, idle_path, registry)
    # Mirror each frame independently; whole-sheet flips reverse frame order.
    right = Image.new("RGBA", sheet.size)
    for x, y, w, h in density.frame_rects(sheet.size, {"grid": [4, 4]}):
        right.paste(ImageOps.mirror(outputs["light_left_idle.png"].crop((x, y, x+w, y+h))), (x, y))
    outputs["light_right_idle.png"] = right
    references = dict(zip(outputs, templates + [pillar_path, light_path,
                          "assets/art/tiles/column_torch_right.png", idle_path,
                          "assets/art/tiles/column_torch_right_idle.png"]))
    report = {}
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, image in outputs.items():
        template = Image.open(ROOT / references[name]).convert("RGBA")
        if name.startswith("floor_") or name == "pillar.png":
            if image.getchannel("A").tobytes() != template.getchannel("A").tobytes():
                raise ValueError(f"template alpha changed: {biome}/{name}")
        (output_dir / name).write_bytes(density.png_bytes(image))
        report[name] = {"orphan_share": metrics(image)["orphan_share"],
                        "template_orphan_share": metrics(template)["orphan_share"]}
    return {"outputs": report, "raw_sha256": hashes}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-dir", type=Path, required=True)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--biome")
    selection.add_argument("--all", action="store_true")
    args = parser.parse_args()
    data = json.loads((ROOT / "data/biomes.json").read_text())
    ids = [key for key in data["biomes"] if key != data["default_biome"]] if args.all else [args.biome]
    if any(key not in data["biomes"] or key == data["default_biome"] for key in ids):
        parser.error("select a non-stone biome from data/biomes.json")
    provenance = ROOT / "spec/assets/biomes"
    provenance.mkdir(parents=True, exist_ok=True)
    hashes = {}
    hash_path = provenance / "raw_sha256.txt"
    if hash_path.exists():
        hashes.update({line.split("  ", 1)[1]: line.split("  ", 1)[0] for line in hash_path.read_text().splitlines()})
    for biome in ids:
        result = process_biome(args.raw_dir, biome, ROOT / "assets/art/biomes" / biome, data["biomes"][biome])
        hashes.update(result.pop("raw_sha256"))
        print(f"BIOME ART {biome}: " + json.dumps(result, sort_keys=True))
    hash_path.write_text("".join(f"{digest}  {name}\n" for name, digest in sorted(hashes.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Register the two director-approved E1 paintings; never generate artwork.

Uses the repository green-key and density processors. Only en-02 assets and
their additive registry records are written. Raw director files stay untouched.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

from process_biome_art import key_green
from pixel_density import metrics, strength

ROOT = Path(__file__).resolve().parents[1]
RAW = Path("/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art")
ENEMIES = ("hoarfrost_seer", "gale_herald")
ICONS = ("icefall", "wind")
# Both are standard-band enemies. Fit nearest to the Gaoler baseline while
# staying inside the director's 85–95% Lancer-height band.
STANDARD_HEIGHT_BAND = (0.85, 0.95)
SPRITE_CANVAS = (255, 255)
PORTRAIT_CANVAS = (128, 128)
PORTRAIT_TOP_PADDING = 8
# Head/front regions measured from the approved paintings, not new paint.
HEAD_REGIONS = {
    "hoarfrost_seer": (530, 208, 790, 570),
    "gale_herald": (345, 248, 520, 455),
}


def fit(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    out = source.copy()
    out.thumbnail(size, Image.Resampling.LANCZOS)
    return out


def write_portrait(enemy_id: str, sprite: Image.Image, keyed: Image.Image) -> None:
    raw_bounds = keyed.getbbox()
    bounds = sprite.getbbox()
    scale = (bounds[3] - bounds[1]) / (raw_bounds[3] - raw_bounds[1])
    head = HEAD_REGIONS[enemy_id]
    translated = tuple(round((head[i] - raw_bounds[i % 2]) * scale + bounds[i % 2]) for i in range(4))
    head_bounds = sprite.crop(translated).getbbox()
    center_x = round((translated[0] + translated[2]) / 2)
    top_y = translated[1] + head_bounds[1]
    # Native 1:1 crop, matching the existing turn-clock pipeline. Do not fit
    # the small head alone into a padded canvas: retain its shoulders/body.
    portrait = Image.new("RGBA", PORTRAIT_CANVAS)
    crop = sprite.crop((center_x - 64, top_y, center_x + 64, top_y + 128 - PORTRAIT_TOP_PADDING))
    portrait.alpha_composite(crop, (0, PORTRAIT_TOP_PADDING))
    portrait.save(ROOT / f"assets/art/portraits/{enemy_id}.png", optimize=True)


def main() -> None:
    expected = {line.split()[1]: line.split()[0] for line in (ROOT / "spec/peer_benchmark/staged/enemies/raw_sha256.txt").read_text().splitlines() if line.strip()}
    for relative in [f"enemies/{enemy_id}.png" for enemy_id in ENEMIES] + [f"icons/{name}.png" for name in ICONS]:
        if hashlib.sha256((RAW / relative).read_bytes()).hexdigest() != expected[relative]:
            raise ValueError(f"Director-approved source hash mismatch: {relative}")
    if sys.argv[1:] == ["--portraits-only"]:
        for enemy_id in ENEMIES:
            write_portrait(enemy_id, Image.open(ROOT / f"assets/art/enemies/{enemy_id}.png").convert("RGBA"), key_green(Image.open(RAW / "enemies" / f"{enemy_id}.png")))
        print("EN02 PORTRAIT CROP: PASS (2 native 128x128 crops)")
        return
    raw_hashes = []
    gaoler_bounds = Image.open(ROOT / "assets/art/enemies/chainbound_gaoler.png").getbbox()
    lancer_bounds = Image.open(ROOT / "assets/art/enemies/frostglass_lancer.png").getbbox()
    gaoler_height = gaoler_bounds[3] - gaoler_bounds[1]
    lancer_height = lancer_bounds[3] - lancer_bounds[1]
    height = round(min(max(gaoler_height, lancer_height * STANDARD_HEIGHT_BAND[0]), lancer_height * STANDARD_HEIGHT_BAND[1]))
    registry_path = ROOT / "spec/assets/board_pixel_density/registry.json"
    registry = json.loads(registry_path.read_text())
    for enemy_id in ENEMIES:
        source_path = RAW / "enemies" / f"{enemy_id}.png"
        raw_hashes.append(f"{hashlib.sha256(source_path.read_bytes()).hexdigest()}  {source_path}\n")
        keyed = key_green(Image.open(source_path))
        body = keyed.crop(keyed.getbbox())
        body = fit(body, (SPRITE_CANVAS[0], height))
        sprite = Image.new("RGBA", SPRITE_CANVAS)
        sprite.alpha_composite(body, ((SPRITE_CANVAS[0] - body.width) // 2, gaoler_bounds[3] - body.height))
        path = f"assets/art/enemies/{enemy_id}.png"
        (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
        sprite.save(ROOT / path, optimize=True)
        write_portrait(enemy_id, sprite, keyed)
        measured = metrics(sprite)
        r = 1.0
        t = strength(measured["orphan_share"])
        grid = round(t / r, 2)
        entry = {"id": enemy_id, "kind": "prop", "paths": [path], "r": r,
                 "r_derivation": {"path": "data/enemies.json", "key": f"{enemy_id}.art_scale", "expression": "_unit_size width 1.03 * default art_scale 1.0 / 255 / hero reference (1.03/255)"},
                 "measurement_path": path, "frames": None, "orphan_share": measured["orphan_share"], "t": t, "grid": grid,
                 "mode": "regrid" if grid >= 1.2 else "clean"}
        previous = next((i for i, old in enumerate(registry["entries"]) if old["id"] == enemy_id), None)
        if previous is None: registry["entries"].append(entry)
        else: registry["entries"][previous] = entry
        print(f"REGISTERED {enemy_id}: {sprite.size}, baseline {gaoler_bounds[3]}, silhouette height {body.height}; portrait {PORTRAIT_CANVAS}")
    for name in ICONS:
        source = key_green(Image.open(RAW / "icons" / f"{name}.png"))
        source = fit(source.crop(source.getbbox()), (56, 56))
        icon = Image.new("RGBA", (64, 64))
        icon.alpha_composite(source, ((64 - source.width) // 2, (64 - source.height) // 2))
        icon.save(ROOT / f"assets/art/icons/{name}.png", optimize=True)
        print(f"REGISTERED {name}: 64x64, same 4px fit padding as blink")
    registry_path.write_text(json.dumps(registry, indent=2) + "\n")
    record = ROOT / "spec/assets/enemies/raw_sha256.txt"
    record.parent.mkdir(parents=True, exist_ok=True)
    old_lines = record.read_text().splitlines(True) if record.exists() else []
    old_lines = [line for line in old_lines if not any(f"/{enemy}.png" in line for enemy in ENEMIES)]
    record.write_text("".join(old_lines + raw_hashes))


if __name__ == "__main__":
    main()

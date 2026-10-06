#!/usr/bin/env python3
"""Derive the protagonist's visible-gear textures from approved painted sources.

Sources are the image run's untouched outputs in
spec/assets/visible_gear_slice/sources/ (flat #00FF00 backgrounds). Each is keyed,
trimmed to its alpha bounds and reduced to the exact native size its registry slot
expects, then written to assets/units/protagonist_cutout/gear/. Mesh-replacement
sizes come from the bare rig's own textures, so a sleeve always matches its mesh.

    python3 tools/process_gear_visual_assets.py            # write all outputs
    python3 tools/process_gear_visual_assets.py --check    # verify outputs are current
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "spec/assets/visible_gear_slice/sources"
RIG = ROOT / "assets/units/protagonist_cutout"
MANIFEST = ROOT / "spec/assets/visible_gear_slice/outputs.json"

# Attachment and weapon sizes are design decisions (spec/design/visible_gear_slice).
FIXED_SIZES = {
    ("war_maul", "front"): (95, 76), ("war_maul", "rear"): (95, 76),
    ("sawtooth_knife", "front"): (45, 32), ("sawtooth_knife", "rear"): (44, 33),
    ("splintered_shield", "front"): (30, 38), ("splintered_shield", "rear"): (28, 36),
    ("ward_kite", "front"): (28, 50), ("ward_kite", "rear"): (26, 46),
    ("parrying_dagger", "front"): (21, 48), ("parrying_dagger", "rear"): (21, 48),
    ("cracked_lantern", "front"): (15, 27), ("cracked_lantern", "rear"): (15, 27),
    ("crown_of_thorns", "front"): (56, 16), ("crown_of_thorns", "rear"): (58, 16),
    ("war_dancer_sash", "front"): (59, 36), ("war_dancer_sash", "rear"): (61, 38),
}
WHOLE = {"war_maul": "weapon_r", "sawtooth_knife": "weapon_r", "splintered_shield": "offhand",
         "ward_kite": "offhand", "parrying_dagger": "offhand", "cracked_lantern": "trinket",
         "crown_of_thorns": "trinket", "war_dancer_sash": "trinket"}
PIECES = {"undertaker_plate": ("torso", "arm_r", "arm_l", "hips"), "cinderweave_mail": ("torso", "arm_r", "arm_l", "hips"),
          "ironshod_sabatons": ("foot_r", "foot_l"), "emberstriders": ("foot_r", "foot_l")}


def base_part_size(facing: str, part: str) -> tuple[int, int]:
    layout = json.loads((RIG / f"{facing}.json").read_text())
    for entry in layout["parts"]:
        if entry["name"] == part:
            path = str(entry["file"]).replace("res://assets/units/protagonist_cutout/", "")
            with Image.open(RIG / path) as im:
                return im.size
    raise KeyError(f"{facing}:{part}")


def key_green(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            spill = g - max(r, b)
            if a == 0 or (g > 140 and spill > 70):
                px[x, y] = (0, 0, 0, 0)
            elif spill > 18:
                # Edge despill: pull residual chroma green back to the neighbouring hue.
                px[x, y] = (r, max(r, b), b, a)
    return im


def reduce(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    box = im.getbbox()
    if box is None:
        raise ValueError("source is empty after keying")
    im = im.crop(box)
    # Premultiplied area averaging keeps the painted values; a hard alpha threshold
    # then gives the crisp silhouette edge the rig's pixel art uses.
    r, g, b, a = im.split()
    pre = Image.merge("RGBA", (
        Image.composite(r, Image.new("L", im.size, 0), a),
        Image.composite(g, Image.new("L", im.size, 0), a),
        Image.composite(b, Image.new("L", im.size, 0), a), a))
    small = pre.resize(size, Image.BOX)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    sp, op = small.load(), out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            rr, gg, bb, aa = sp[x, y]
            if aa >= 110:
                k = 255.0 / aa
                op[x, y] = (min(255, round(rr * k)), min(255, round(gg * k)), min(255, round(bb * k)), 255)
    return outline(out)


def outline(im: Image.Image, strength: float = 0.55) -> Image.Image:
    """Darken silhouette-edge pixels toward the rig's near-black outline."""
    px = im.load()
    w, h = im.size
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        r, g, b, a = px[x, y]
        dark = (24, 17, 14)
        px[x, y] = (round(r + (dark[0] - r) * strength), round(g + (dark[1] - g) * strength),
                    round(b + (dark[2] - b) * strength), a)
    return im


def jobs():
    for item, part in WHOLE.items():
        for facing in ("front", "rear"):
            yield SOURCES / f"{item}_{facing}.png", RIG / f"gear/{item}/{facing}_{part}.png", FIXED_SIZES[(item, facing)]
    for item, parts in PIECES.items():
        for facing in ("front", "rear"):
            for part in parts:
                yield SOURCES / f"{item}_{facing}_{part}.png", RIG / f"gear/{item}/{facing}_{part}.png", base_part_size(facing, part)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if any output differs from a fresh derivation")
    parser.add_argument("--only", default="", help="comma-separated item ids to process")
    args = parser.parse_args()
    only = {s for s in args.only.split(",") if s}
    manifest = {}
    stale = []
    for src, dst, size in jobs():
        item = dst.parent.name
        if only and item not in only:
            continue
        if not src.exists():
            print(f"missing source (stand-in kept): {src.relative_to(ROOT)}")
            continue
        out = reduce(key_green(Image.open(src)), size)
        rel = str(dst.relative_to(ROOT))
        if args.check:
            if not dst.exists() or Image.open(dst).convert("RGBA").tobytes() != out.tobytes():
                stale.append(rel)
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        out.save(dst)
        manifest[rel] = {"source": str(src.relative_to(ROOT)), "source_sha256": digest(src), "size": list(size)}
    if args.check:
        for rel in stale:
            print(f"stale: {rel}")
        return 1 if stale else 0
    if manifest:
        existing = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
        existing.update(manifest)
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        MANIFEST.write_text(json.dumps(dict(sorted(existing.items())), indent=2) + "\n")
    print(f"processed {len(manifest)} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

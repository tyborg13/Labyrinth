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

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "spec/assets/visible_gear_slice/sources"
RIG = ROOT / "assets/units/protagonist_cutout"
MANIFEST = ROOT / "spec/assets/visible_gear_slice/outputs.json"

# Attachment and weapon sizes are design decisions (spec/design/visible_gear_slice).
FIXED_SIZES = {
    ("war_maul", "front"): (95, 76), ("war_maul", "rear"): (95, 76),
    ("sawtooth_knife", "front"): (45, 32), ("sawtooth_knife", "rear"): (44, 33),
    ("splintered_shield", "front"): (50, 75), ("splintered_shield", "rear"): (44, 72),
    ("ward_kite", "front"): (46, 96), ("ward_kite", "rear"): (40, 90),
    ("parrying_dagger", "front"): (28, 46), ("parrying_dagger", "rear"): (20, 48),
    ("cracked_lantern", "front"): (15, 27), ("cracked_lantern", "rear"): (15, 27),
    ("crown_of_thorns", "front"): (56, 16), ("crown_of_thorns", "rear"): (58, 16),
    ("war_dancer_sash", "front"): (59, 36), ("war_dancer_sash", "rear"): (61, 38),
}
WHOLE = {"war_maul": "weapon_r", "sawtooth_knife": "weapon_r", "splintered_shield": "offhand",
         "ward_kite": "offhand", "parrying_dagger": "offhand", "cracked_lantern": "trinket",
         "crown_of_thorns": "trinket", "war_dancer_sash": "trinket"}
PIECES = {"undertaker_plate": ("torso", "arm_r", "arm_l", "hips"), "cinderweave_mail": ("torso", "arm_r", "arm_l", "hips"),
          "ironshod_sabatons": ("foot_r", "foot_l", "shin_r", "shin_l"),
         "emberstriders": ("foot_r", "foot_l", "shin_r", "shin_l")}
# Image generation paints far finer than the chunky hero; its texture a pixel or
# two wide reads as noise beside him (owner review 2026-10-06). The hero has
# ~2-pixel colour runs and only 4-9% orphan pixels (pixels unlike all four
# neighbours); raw reductions had 22-71%. Every gear texture is therefore
# consolidated at native size: posterised to 24 colours, a 3x3 mode filter, and
# orphan cleanup. The owner compared this with a Kuwahara filter and chose it for
# the closest match to the hero's colour blocking, accepting the loss of
# Cinderweave Mail's fine ring texture.
POSTERISE_COLOURS = 24


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


def reduce(im: Image.Image, size: tuple[int, int], chunky: bool = False) -> Image.Image:
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
    out = outline(out)
    if chunky:
        out = outline(consolidate(out))
    return out


def clean_orphans(im: Image.Image, threshold: int = 24, passes: int = 2) -> Image.Image:
    """Give each pixel unlike all four neighbours the colour of its closest neighbour."""
    a = np.asarray(im, dtype=np.float32).copy()
    for _ in range(passes):
        rgb, opaque = a[..., :3], a[..., 3] > 0
        shifted, valid = [], []
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            colour = np.roll(rgb, (dy, dx), (0, 1))
            mask = np.roll(opaque, (dy, dx), (0, 1))
            if dy: mask[0 if dy > 0 else -1, :] = False
            if dx: mask[:, 0 if dx > 0 else -1] = False
            shifted.append(colour)
            valid.append(mask)
        diff = np.stack([np.where(m, np.abs(c - rgb).sum(-1), np.inf) for c, m in zip(shifted, valid)])
        nearest = diff.min(0)
        orphan = opaque & np.isfinite(nearest) & (nearest >= threshold)
        choice = np.take_along_axis(np.stack(shifted), diff.argmin(0)[None, ..., None].repeat(3, -1), 0)[0]
        a[..., :3] = np.where(orphan[..., None], choice, rgb)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8)).copy()


def consolidate(im: Image.Image) -> Image.Image:
    alpha = im.getchannel("A")
    flat = im.convert("RGB").quantize(colors=POSTERISE_COLOURS, method=Image.Quantize.MEDIANCUT,
                                      dither=Image.Dither.NONE)
    flat = flat.convert("RGB").filter(ImageFilter.ModeFilter(3)).convert("RGBA")
    flat.putalpha(alpha)
    return clean_orphans(flat)


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
        out = reduce(key_green(Image.open(src)), size, True)
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

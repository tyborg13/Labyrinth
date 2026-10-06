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

# Native sizes are design decisions (spec/design/visible_gear_slice): whole items
# (weapons, offhands, trinkets) by "item|facing", and any piece that differs from
# the bare rig part (a robe's longer hips) by "item|facing|part". Every other
# piece takes the bare rig part's own size, so sleeves always match their mesh.
SIZES = ROOT / "spec/assets/visible_gear_slice/native_sizes.json"
REGISTRY = RIG / "gear_visuals.json"


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
    sizes = json.loads(SIZES.read_text())
    registry = json.loads(REGISTRY.read_text())
    for item, entry in registry["items"].items():
        for facing, ops in entry.get("facings", {}).items():
            for op in ops.get("replace", []) + ops.get("attach", []):
                part = op.get("part", "")
                whole = "attach" in ops and op in ops["attach"] or part == "weapon_r"
                source = SOURCES / (f"{item}_{facing}.png" if whole else f"{item}_{facing}_{part}.png")
                if whole:
                    size = tuple(sizes[f"{item}|{facing}"])
                else:
                    size = tuple(sizes.get(f"{item}|{facing}|{part}", base_part_size(facing, part)))
                yield source, RIG / op["file"], size, (facing, op) if op.get("occluded_by") else None, \
                    (facing, op, ops.get("weapon_grip", {})) if part == "weapon_r" else None


def occlude(im: Image.Image, facing: str, op: dict) -> Image.Image:
    """Clear pixels a rig part covers at rest (a fist over a held grip).

    The attachment rides the same bone as the part, so the hole stays aligned
    in every pose; the part then reads as gripping the item."""
    layout = json.loads((RIG / f"{facing}.json").read_text())
    part = next(p for p in layout["parts"] if p["name"] == op["occluded_by"])
    with Image.open(RIG / str(part["file"]).replace("res://assets/units/protagonist_cutout/", "")) as raw:
        cover = raw.convert("RGBA")
    out = im.copy()
    px, cp = out.load(), cover.load()
    dx = int(part["offset"][0]) - int(op["offset"][0])
    dy = int(part["offset"][1]) - int(op["offset"][1])
    for y in range(cover.height):
        for x in range(cover.width):
            tx, ty = x + dx, y + dy
            if cp[x, y][3] and 0 <= tx < out.width and 0 <= ty < out.height:
                px[tx, ty] = (0, 0, 0, 0)
    return out


# Grip layering (owner review 2026-10-06): a carried weapon draws behind the
# near leg, and the shaft crosses the palm under the fingers. The rig draws
# the palm (the whole glove) under the weapon, a grip piece of the weapon
# over the palm, and the fingers over both. The grip piece is the weapon within
# GRIP_RADIUS of the handle segment that runs from GRIP_BACK px toward the tip
# to GRIP_REACH px toward the pommel; the fingers are the glove's lit knuckle
# pixels (luma >= FINGER_LUMA) plus their one-pixel outline.
GRIP_REACH = 12
GRIP_BACK = 3
GRIP_RADIUS = 4
FINGER_LUMA = 95


def grip_piece(weapon: Image.Image, offset: list, landmarks: dict) -> Image.Image:
    gx, gy = landmarks["assembled"]
    if "pommel" in landmarks:
        px, py = landmarks["pommel"]
    else:
        tx, ty = landmarks["tip"]
        px, py = 2 * gx - tx, 2 * gy - ty
    dx, dy = px - gx, py - gy
    length = max((dx * dx + dy * dy) ** 0.5, 1e-6)
    ux, uy = dx / length, dy / length
    reach = min(length, GRIP_REACH)
    out = Image.new("RGBA", weapon.size, (0, 0, 0, 0))
    src, dst = weapon.load(), out.load()
    for y in range(weapon.height):
        for x in range(weapon.width):
            if not src[x, y][3]:
                continue
            rx, ry = x + offset[0] - gx, y + offset[1] - gy
            t = max(-GRIP_BACK, min(reach, rx * ux + ry * uy))
            if (rx - ux * t) ** 2 + (ry - uy * t) ** 2 <= GRIP_RADIUS ** 2:
                dst[x, y] = src[x, y]
    return out


def fingers(hand: Image.Image) -> Image.Image:
    px = hand.load()
    w, h = hand.size
    lit = {(x, y) for y in range(h) for x in range(w)
           if px[x, y][3] and 0.3 * px[x, y][0] + 0.59 * px[x, y][1] + 0.11 * px[x, y][2] >= FINGER_LUMA}
    keep = set(lit)
    for x, y in lit:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3]:
                keep.add((nx, ny))
    out = Image.new("RGBA", hand.size, (0, 0, 0, 0))
    op = out.load()
    for x, y in keep:
        op[x, y] = px[x, y]
    return out


def grip_path(dst: Path) -> Path:
    return dst.with_name(dst.stem + "_grip.png")


def base_layers():
    """Grip piece of the default sword and fingers overlay of the bare glove, per facing."""
    for facing in ("front", "rear"):
        layout = json.loads((RIG / f"{facing}.json").read_text())
        parts = {p["name"]: p for p in layout["parts"]}
        def load(name):
            with Image.open(RIG / str(parts[name]["file"]).replace("res://assets/units/protagonist_cutout/", "")) as im:
                return im.convert("RGBA"), parts[name]
        sword, part = load("weapon_r")
        yield RIG / facing / "weapon_r_grip.png", grip_piece(sword, part["offset"], layout["weapon_grip"]), part["file"]
        hand, part = load("hand_r")
        yield RIG / facing / "hand_r_fingers.png", fingers(hand), part["file"]


def write_or_check(dst: Path, out: Image.Image, check: bool, stale: list) -> bool:
    if check:
        if not dst.exists() or Image.open(dst).convert("RGBA").tobytes() != out.tobytes():
            stale.append(str(dst.relative_to(ROOT)))
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst)
    imp = Path(str(dst) + ".import")
    if not imp.exists():
        res = "res://" + str(dst.relative_to(ROOT))
        imp.write_text(f'[remap]\n\nimporter="keep"\n\n[deps]\n\nsource_file="{res}"\n')
    return True


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
    for src, dst, size, occlusion, grip in jobs():
        item = dst.parent.name
        if only and item not in only:
            continue
        if not src.exists():
            print(f"missing source (stand-in kept): {src.relative_to(ROOT)}")
            continue
        out = reduce(key_green(Image.open(src)), size, True)
        if occlusion:
            out = occlude(out, *occlusion)
        record = {"source": str(src.relative_to(ROOT)), "source_sha256": digest(src), "size": list(size)}
        if write_or_check(dst, out, args.check, stale):
            manifest[str(dst.relative_to(ROOT))] = record
        if grip and grip[2]:
            facing, op, landmarks = grip
            gdst = grip_path(dst)
            if write_or_check(gdst, grip_piece(out, op["offset"], landmarks), args.check, stale):
                manifest[str(gdst.relative_to(ROOT))] = dict(record, derived="grip")
    if not only:
        for dst, out, base in base_layers():
            write_or_check(dst, out, args.check, stale)
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

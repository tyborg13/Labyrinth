"""Shared pixel-density operations for painted RGBA assets.

Gear keeps its accepted palette/outline pipeline. Board treatment changes only
interior RGB, retaining native alpha, hidden RGB and the original silhouette edge.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageFilter

POSTERISE_COLOURS = 24


def clean_orphans(im: Image.Image, threshold: int = 24, passes: int = 2) -> Image.Image:
    """Give each pixel unlike all four neighbours the colour of its closest neighbour."""
    a = _clean_orphan_array(np.asarray(im, dtype=np.float32), threshold, passes)
    return Image.fromarray(np.rint(a.clip(0, 255)).astype(np.uint8)).copy()


def _clean_orphan_array(pixels: np.ndarray, threshold: int = 24, passes: int = 2) -> np.ndarray:
    a = pixels.copy()
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
    return a


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


def edge_ring(mask: np.ndarray) -> np.ndarray:
    """Nonzero-alpha pixels bordering transparency or the canvas boundary."""
    padded = np.pad(mask, 1, constant_values=False)
    interior = (padded[:-2, 1:-1] & padded[2:, 1:-1]
                & padded[1:-1, :-2] & padded[1:-1, 2:])
    return mask & ~interior


def _restore_edge(source: np.ndarray, treated: np.ndarray) -> Image.Image:
    ring = edge_ring(source[..., 3] > 0)
    treated[ring] = source[ring]
    return Image.fromarray(np.rint(treated.clip(0, 255)).astype(np.uint8))


def clean(im: Image.Image) -> Image.Image:
    source = np.asarray(im.convert("RGBA"))
    return _restore_edge(source, np.asarray(clean_orphans(im.convert("RGBA"))).copy())


def regrid(im: Image.Image, grid: float) -> Image.Image:
    """Average premultiplied colour on a frame-local grid, preserving source alpha."""
    if not math.isfinite(grid) or grid <= 0:
        raise ValueError("grid must be positive and finite")
    source = np.asarray(im.convert("RGBA"))
    premultiplied = source.astype(np.float32)
    premultiplied[..., :3] *= premultiplied[..., 3:4] / 255.0
    size = (max(1, round(im.width / grid)), max(1, round(im.height / grid)))
    # Resize float channels separately: Pillow's RGBA resize premultiplies on
    # its own, which would multiply our colour by alpha a second time.
    small = np.stack([np.asarray(Image.fromarray(premultiplied[..., c]).resize(
        size, Image.Resampling.BOX)) for c in range(4)], -1)
    mask = small[..., 3] > 0
    small[..., :3] *= 255.0 / np.maximum(small[..., 3:4], 1e-12)
    small[..., :3] = np.clip(small[..., :3], 0, 255)
    small = _clean_orphan_array(small)
    big = np.stack([np.asarray(Image.fromarray(small[..., c]).resize(
        im.size, Image.Resampling.NEAREST)) for c in range(3)], -1)
    nonempty = np.asarray(Image.fromarray(mask.astype(np.uint8)).resize(
        im.size, Image.Resampling.NEAREST)) > 0
    output = source.copy()
    write = (source[..., 3] > 0) & nonempty
    output[..., :3][write] = np.rint(big[write].clip(0, 255)).astype(np.uint8)
    return _restore_edge(source, output)


def frame_rects(size: tuple[int, int], frames: dict | None) -> list[tuple[int, int, int, int]]:
    """Validate sheet regions; reject overlaps and accidental partial grid frames."""
    width, height = size
    if frames is None:
        return [(0, 0, width, height)]
    if set(frames) == {"grid"}:
        cols, rows = frames["grid"]
        if cols <= 0 or rows <= 0 or width % cols or height % rows:
            raise ValueError("sheet dimensions must divide evenly into the frame grid")
        w, h = width // cols, height // rows
        return [(x * w, y * h, w, h) for y in range(rows) for x in range(cols)]
    if set(frames) != {"rects"}:
        raise ValueError("frames must contain grid or rects")
    rects = [tuple(region) for region in frames["rects"]]
    for index, (x, y, w, h) in enumerate(rects):
        if min(x, y) < 0 or min(w, h) <= 0 or x + w > width or y + h > height:
            raise ValueError("frame region is outside the image")
        for xx, yy, ww, hh in rects[:index]:
            if x < xx + ww and xx < x + w and y < yy + hh and yy < y + h:
                raise ValueError("frame regions must not overlap")
    return rects


def process(im: Image.Image, mode: str, grid: float, frames: dict | None = None) -> Image.Image:
    if mode not in ("clean", "regrid"):
        raise ValueError("mode must be clean or regrid")
    source = im.convert("RGBA")
    output = source.copy()
    for x, y, w, h in frame_rects(source.size, frames):
        frame = source.crop((x, y, x + w, y + h))
        treated = clean(frame) if mode == "clean" else regrid(frame, grid)
        output.paste(treated, (x, y))
    return output


def metrics(im: Image.Image) -> dict[str, float]:
    """Orphan fraction and mean horizontal run, over nonzero-alpha pixels."""
    pixels = np.asarray(im.convert("RGBA"), dtype=np.int16)
    rgb, opaque = pixels[..., :3], pixels[..., 3] > 0
    any_neighbour = np.zeros_like(opaque)
    unlike_all = np.ones_like(opaque)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        neighbour = np.roll(opaque, (dy, dx), (0, 1))
        if dy: neighbour[0 if dy > 0 else -1, :] = False
        if dx: neighbour[:, 0 if dx > 0 else -1] = False
        difference = np.abs(np.roll(rgb, (dy, dx), (0, 1)) - rgb).sum(-1)
        any_neighbour |= neighbour
        unlike_all &= ~neighbour | (difference >= 24)
    eligible = opaque & any_neighbour
    left_same = np.zeros_like(opaque)
    left_same[:, 1:] = (opaque[:, :-1]
                       & (np.abs(rgb[:, 1:] - rgb[:, :-1]).sum(-1) < 24))
    starts = opaque & ~left_same
    return {"orphan_share": float((eligible & unlike_all).sum()) / max(int(eligible.sum()), 1),
            "run_length": float(opaque.sum()) / max(int(starts.sum()), 1)}

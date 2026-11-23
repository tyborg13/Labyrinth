#!/usr/bin/env python3
"""Pack approved ground decals into the renderer's indexed atlases.
Sheets use 4x4 image pixels per art pixel; one atlas texel = one art pixel = one vfx-01 cell.
Electrified carries ramp in R, crack distance in G and angular sector * 32 in B.
"""
import argparse
from collections import deque
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APPROVED = ROOT / "spec/peer_benchmark/staged/grd/approved"
GREYS = (0, 64, 128, 191, 255)
BLOCK = 4
NEIGHBORS = tuple((dx, dy) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dx or dy)
SHEETS = {  # kind: (approved sheet, cols, rows, ramp name in data/vfx_pixel_style.json)
    "fire": ("fire_v2.png", 4, 3, "fire"),
    "rubble": ("rubble_v1.png", 4, 3, "neutral"),
    "ice": ("ice_v4.png", 3, 2, "ice"),
    "electrified": ("electric_v1.png", 3, 2, "lightning"),
}

def hex_rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def decals(sheet, cols, rows, ramp):
    import numpy as np
    from PIL import Image

    a = np.asarray(Image.open(sheet).convert("RGB")).astype(int)
    pal = np.array([hex_rgb(h) for h in ramp])
    green = (a[:, :, 0] < 60) & (a[:, :, 1] > 200) & (a[:, :, 2] < 60)
    H, W = green.shape
    out = []
    for r in range(rows):
        for c in range(cols):
            y0, y1, x0, x1 = r * H // rows, (r + 1) * H // rows, c * W // cols, (c + 1) * W // cols
            ys, xs = np.nonzero(~green[y0:y1, x0:x1])
            if len(xs) == 0: continue
            # snap the crop to the 4x4 art grid of the sheet
            gy0, gx0 = ((y0 + ys.min()) // BLOCK) * BLOCK, ((x0 + xs.min()) // BLOCK) * BLOCK
            gy1, gx1 = -(-(y0 + ys.max() + 1) // BLOCK) * BLOCK, -(-(x0 + xs.max() + 1) // BLOCK) * BLOCK
            block = a[gy0:gy1, gx0:gx1]; g = green[gy0:gy1, gx0:gx1]
            h, w = (gy1 - gy0) // BLOCK, (gx1 - gx0) // BLOCK
            cy = block[BLOCK // 2::BLOCK, BLOCK // 2::BLOCK][:h, :w]
            cg = g[BLOCK // 2::BLOCK, BLOCK // 2::BLOCK][:h, :w]
            dist = ((cy[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
            idx = dist.argmin(-1)
            rgba = np.zeros((h, w, 4), np.uint8)
            for i, grey in enumerate(GREYS):
                m = (idx == i) & ~cg
                rgba[m] = (grey, grey, grey, 255)
            out.append((rgba, int(dist.min(-1)[~cg].max()) if (~cg).any() else 0))
    return out

def encode_electrified(pixels, stride, rects, sector_count):
    """Add metadata in place while preserving the source ramp and silhouette."""
    for x, y, w, h in rects:
        offsets = {
            (dx, dy): ((y + dy) * stride + x + dx) * 4
            for dy in range(h) for dx in range(w)
            if pixels[((y + dy) * stride + x + dx) * 4 + 3]
        }
        links = {}
        for px, py in offsets:
            links[px, py] = [
                (px + dx, py + dy) for dx, dy in NEIGHBORS if (px + dx, py + dy) in offsets
            ]
        unvisited = set(offsets)
        for first in offsets:
            if first not in unvisited:
                continue
            component = [first]
            unvisited.remove(first)
            for point in component:
                for neighbor in links[point]:
                    if neighbor in unvisited:
                        unvisited.remove(neighbor)
                        component.append(neighbor)
            cores = [point for point in component if pixels[offsets[point]] == GREYS[-1]]
            if not cores:
                cores = [max(component, key=lambda p: (pixels[offsets[p]], -p[1], -p[0]))]
            cores.sort(key=lambda p: (p[1], p[0]))
            queue = deque((point, point, 0) for point in cores)
            visited = set(cores)
            while queue:
                (px, py), (cx, cy), distance = queue.popleft()
                angle = math.atan2(py - cy, px - cx) % math.tau
                sector = min(sector_count - 1, int(angle / math.tau * sector_count))
                offset = offsets[px, py]
                pixels[offset + 1] = min(distance, 255)
                pixels[offset + 2] = sector * 32
                for neighbor in links[px, py]:
                    if neighbor not in visited:
                        visited.add(neighbor)
                        queue.append((neighbor, (cx, cy), distance + 1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("worktree", type=Path, nargs="?", default=ROOT)
    parser.add_argument("--approved-dir", type=Path, default=APPROVED)
    parser.add_argument("--kind", choices=SHEETS)
    parser.add_argument("--sheet", type=Path, help="Use this approved replacement sheet for --kind.")
    parser.add_argument("--encode-electrified", action="store_true", help="Add channels to the installed atlas.")
    args = parser.parse_args()
    if args.sheet and not args.kind:
        parser.error("--sheet requires --kind")
    if args.encode_electrified and (args.kind or args.sheet):
        parser.error("--encode-electrified operates on the installed atlas")
    from PIL import Image

    wt = args.worktree
    ramps = json.loads((wt / "data/vfx_pixel_style.json").read_text())["ramps"]
    style_path = wt / "data/ground_surface_style.json"
    style = json.loads(style_path.read_text())
    sector_count = style["electrified"]["sector_count"]
    if args.encode_electrified:
        atlas = style["electrified"]["atlas"]
        path = wt / atlas["path"].removeprefix("res://")
        with Image.open(path) as source:
            image = source.convert("RGBA")
        pixels = bytearray(image.tobytes())
        encode_electrified(pixels, image.width, atlas["rects"], sector_count)
        Image.frombytes("RGBA", image.size, bytes(pixels)).save(path)
        print("electrified atlas channels encoded", path)
        return

    import numpy as np

    dest = wt / "assets/art/effects/ground"; dest.mkdir(parents=True, exist_ok=True)
    for kind, (sheet, cols, rows, ramp) in SHEETS.items():
        if args.kind and kind != args.kind:
            continue
        ds = decals(args.sheet or args.approved_dir / sheet, cols, rows, ramps[ramp])
        width = sum(d.shape[1] for d, _ in ds) + (len(ds) - 1)
        height = max(d.shape[0] for d, _ in ds)
        atlas = np.zeros((height, width, 4), np.uint8); rects = []; x = 0
        for d, _ in ds:
            atlas[:d.shape[0], x:x + d.shape[1]] = d; rects.append([x, 0, d.shape[1], d.shape[0]]); x += d.shape[1] + 1
        if kind == "electrified":
            encode_electrified(memoryview(atlas).cast("B"), width, rects, sector_count)
        Image.fromarray(atlas, "RGBA").save(dest / f"{kind}_decals.png")
        style[kind]["atlas"] = {"path": f"res://assets/art/effects/ground/{kind}_decals.png", "rects": rects}
        print(kind, "decals", len(ds), "atlas", atlas.shape[1], "x", atlas.shape[0], "max palette error", max(e for _, e in ds))
    style_path.write_text(json.dumps(style, indent=1) + "\n")

if __name__ == "__main__":
    main()

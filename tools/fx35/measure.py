"""Measure the Shadow pool and compare the installed atlases to fx-34."""

import hashlib
import io
import json
import math
import sys
from types import ModuleType
from unittest.mock import patch

import numpy as np
from PIL import Image

from stage import BASE, CATALOG, ROOT, base_file

BAKER = "tools/fx12/bake_tile_bursts.py"
PINS = "tests/approved_asset_pins.json"
MEASURE_FRAME = 4
EDGE_ANGLES = 64
EDGE_SAMPLES_PER_CELL = 64
MAX_CELL_RATIO = .35
WIDTH_TARGET = (.45, .55)
MIN_RAGGEDNESS = 1.35

sys.path.insert(0, str(ROOT / "tools/fx12"))
import bake_tile_bursts as current


def base_baker():
    module = ModuleType("fx34_baker")
    exec(compile(base_file(BAKER), f"{BASE}:{BAKER}", "exec"), vars(module))
    return module


def read_atlas(data, spec, pin):
    blob = b"blob " + str(len(data)).encode() + b"\0" + data
    if hashlib.sha1(blob).hexdigest() != pin:
        raise ValueError(f"Incorrect PNG pin for {spec['atlas']}")
    with Image.open(io.BytesIO(data)) as image:
        pixels = np.array(image)
    if hashlib.sha256(pixels.tobytes()).hexdigest() != spec["sha256_pixels"]:
        raise ValueError(f"Incorrect pixel hash for {spec['atlas']}")
    return pixels


def shadow_rasters(baker, low):
    pools = []
    draw_pool = baker.draw_shadow_pool

    def record_pool(img, frame, *items):
        pool = baker.blank()
        draw_pool(pool, frame, *items)
        img[:] = pool
        pools.append(pool[..., 3] != 0)

    with patch.object(baker, "draw_shadow_pool", record_pool):
        rows = baker.shadow(low)
    with patch.object(baker, "draw_shadow_pool", lambda *args: None):
        unpooled = baker.shadow(low)
    return np.array(rows), np.array(unpooled), np.array(pools)


def frame_indices(sheet, row, width, height):
    return sheet[row * height:(row + 1) * height].reshape(height, current.N, width).transpose(1, 0, 2)


def width(mask):
    columns = np.flatnonzero(mask.any(axis=0))
    return int(columns[-1] - columns[0] + 1)


def raggedness(low):
    items = current.shadow_tendrils(low, np.random.default_rng(current.SHADOW_SEED + low))
    angles = np.linspace(0, math.tau, EDGE_ANGLES, endpoint=False)[:, None]
    radii = np.linspace(0, current.HW, math.ceil(current.HW / current.CELL) * EDGE_SAMPLES_PER_CELL + 1)
    inside = current.shadow_pool_shape(radii * np.cos(angles), radii * np.sin(angles) / 2, MEASURE_FRAME, items)
    edges = np.max(np.where(inside, radii, 0), axis=1)
    return edges.max() / edges.min()


def compare():
    old_baker = base_baker()
    old_catalog = json.loads(base_file(CATALOG))
    catalog = json.loads((ROOT / CATALOG).read_text())
    old_pins = json.loads(base_file(PINS))["files"]
    pins = json.loads((ROOT / PINS).read_text())["files"]
    if {k: v for k, v in old_catalog.items() if k != "sizes"} != {k: v for k, v in catalog.items() if k != "sizes"}:
        raise ValueError("Catalog metadata changed outside the atlas hashes")
    if len(old_catalog["sizes"]) != len(catalog["sizes"]):
        raise ValueError("Atlas inventory changed")
    palette = np.array([list(bytes.fromhex(colour)) for colour in catalog["palette"]], dtype=np.uint8)
    legacy_rows = [row for name, row in catalog["rows"].items() if not name.startswith("shadow_")]
    legacy_bytes = 0
    changed_tendrils = 0
    measures = []
    for old_spec, spec in zip(old_catalog["sizes"], catalog["sizes"]):
        if {k: v for k, v in old_spec.items() if k != "sha256_pixels"} != {k: v for k, v in spec.items() if k != "sha256_pixels"}:
            raise ValueError("Atlas layout changed")
        path = spec["atlas"].removeprefix("res://")
        before = read_atlas(base_file(path), old_spec, old_pins[path])
        after = read_atlas((ROOT / path).read_bytes(), spec, pins[path])
        size = spec["tile_cells"][0]
        width_cells, height_cells = spec["frame_cells"]
        old_baker.use(size)
        current.use(size)
        # FX-21's identity check compares the decoded indices including empty cells.
        for row in legacy_rows:
            old = frame_indices(before, row, width_cells, height_cells)
            new = frame_indices(after, row, width_cells, height_cells)
            np.testing.assert_array_equal(new, old, err_msg=f"{size}: non-Shadow row {row}")
            legacy_bytes += old.size

        for part, low in (("hit", 0), ("floor", 1)):
            old_rows, old_unpooled, old_pool = shadow_rasters(old_baker, low)
            rows, unpooled, pool = shadow_rasters(current, low)
            np.testing.assert_array_equal(unpooled, old_unpooled, err_msg=f"{size}: {part} tendrils and motes")
            for layer, depth in enumerate(("rear", "front")):
                row = catalog["rows"][f"shadow_{part}_{depth}"]
                old = frame_indices(before, row, width_cells, height_cells)
                new = frame_indices(after, row, width_cells, height_cells)
                np.testing.assert_array_equal(palette[old], old_rows[layer], err_msg=f"{size}: base {part} {depth}")
                np.testing.assert_array_equal(palette[new], rows[layer], err_msg=f"{size}: installed {part} {depth}")
                occupied = old_unpooled[layer, ..., 3] != 0
                protected = occupied & ~old_pool if depth == "rear" else occupied
                changed_tendrils += np.count_nonzero((new != old) & protected)
                permitted = (old_pool | pool) if depth == "rear" else False
                if np.any((new != old) & np.logical_not(permitted)):
                    raise ValueError(f"{size}: {part} {depth} changed outside the pool")
            old = old_pool[MEASURE_FRAME]
            new = pool[MEASURE_FRAME]
            measures.append((size, part, int(old.sum()), int(new.sum()), width(old), width(new), raggedness(low)))

    print(f"FX-35 TENDRIL CELLS CHANGED OUTSIDE FORMER POOL: {changed_tendrils} (includes hit motes)")
    if changed_tendrils:
        raise ValueError("Tendril identity failed")
    print(f"FX-35 BAKE IDENTITY: PASS ({legacy_bytes} non-Shadow palette-index bytes, "
          f"{len(legacy_rows)} rows x {current.N} frames x {len(catalog['sizes'])} sizes, zero row shifts)")
    return measures


def print_table(measures):
    print("| Tile width | Version | Pool cells old → new | Cell ratio | Width old → new | Width ratio | Raggedness |")
    print("| ---: | --- | ---: | ---: | ---: | ---: | ---: |")
    for size, part, old_count, count, old_width, span, ragged in measures:
        print(f"| {size} | {part} | {old_count} → {count} | {count / old_count:.1%} | "
              f"{old_width} → {span} | {span / old_width:.1%} | {ragged:.2f} |")
    width_misses = sum(not WIDTH_TARGET[0] <= span / old_width <= WIDTH_TARGET[1]
                       for _, _, _, _, old_width, span, _ in measures)
    print(f"FX-35 WIDTH TARGET: {len(measures) - width_misses}/{len(measures)} within 45–55%")
    if any(count / old_count > MAX_CELL_RATIO or ragged < MIN_RAGGEDNESS
           for _, _, old_count, count, _, _, ragged in measures):
        raise ValueError("Pool cell count or raggedness missed its target")
    print("FX-35 POOL COUNT AND RAGGEDNESS: PASS")


if __name__ == "__main__":
    print_table(compare())

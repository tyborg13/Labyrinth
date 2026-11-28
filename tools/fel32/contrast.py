"""Compare the solid cores of the submitted threat strokes in replay floor pixels."""
import argparse
import json
import math
from pathlib import Path
from statistics import median

FIRE_COMBAT = 4
STONE_COMBAT = 1
FIRE_MINIMUM = 3.0
GEOMETRY_TOLERANCE = 0.0005
RED_WIDTH = 2
BAND_WIDTH = 5


def signed_distance(point, diamond):
    """Minimum distance to the four supporting lines, positive inside."""
    cx = (diamond[0][0] + diamond[2][0]) / 2
    cy = (diamond[0][1] + diamond[2][1]) / 2
    distances = []
    for index, (x, y) in enumerate(diamond[:4]):
        next_x, next_y = diamond[(index + 1) % 4]
        nx, ny = y - next_y, next_x - x
        normal = math.hypot(nx, ny)
        sign = 1 if nx * (cx - x) + ny * (cy - y) > 0 else -1
        distances.append(sign * (nx * (point[0] - x) + ny * (point[1] - y)) / normal)
    return min(distances)


def stroke_contains(point, stroke):
    return abs(signed_distance(point, stroke["points"])) < stroke["width"] / 2


def blend(base, rgba):
    return tuple(base_channel + (top - base_channel) * rgba[3]
                 for base_channel, top in zip(base, rgba[:3]))


def luminance(rgb):
    linear = (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)
    return sum(channel * weight for channel, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def ratio(left, right):
    dark, light = sorted((luminance(left), luminance(right)))
    return (light + 0.05) / (dark + 0.05)


def tile_pixels(tile, strokes, point, background):
    color = background
    if signed_distance(point, strokes[-1]["points"]) >= 0:
        color = blend(color, tile["fill"])
    for stroke in strokes:
        if stroke_contains(point, stroke):
            color = blend(color, stroke["rgba"])
    return color


def by_tile(moments, combat, fire):
    return {
        (row["turn"], *tile["tile"]): tile
        for row in moments if row["combat"] == combat
        for tile in row["tiles"]
        if tile["surface"] == ("fire" if fire else "") and (fire or not tile["rubble"])
    }


def check_combat(release, branch, name, combat, fire):
    before = by_tile(release, combat, fire)
    after = by_tile(branch, combat, fire)
    if not before or before.keys() != after.keys():
        raise ValueError(f"{name}: telegraphed tile set is empty or differs across replays")
    old_ratios, new_ratios = [], []
    for key, old in before.items():
        new = after[key]
        old_strokes, new_strokes = old["strokes"], new["strokes"]
        if [row["width"] for row in old_strokes] != [RED_WIDTH]:
            raise ValueError(f"{name} {key}: baseline should submit one red outline")
        if [row["width"] for row in new_strokes] != [BAND_WIDTH, RED_WIDTH]:
            raise ValueError(f"{name} {key}: branch did not submit a band followed by red")
        old_red, new_red = old_strokes[-1], new_strokes[-1]
        if old_red["rgba"] != new_red["rgba"] or old_red["antialias"] != new_red["antialias"]:
            raise ValueError(f"{name} {key}: red stroke properties changed")
        for tile, red in ((old, old_red), (new, new_red)):
            if any(abs(signed_distance(point, tile["diamond"]) - RED_WIDTH / 2) > GEOMETRY_TOLERANCE
                   for point in red["points"][:4]):
                raise ValueError(f"{name} {key}: red outline inset changed")
        # Use the same underlying textured pixels and fill sample for the A/B.
        # The replay's presentation clock controls flame and hero pulse independently of combat.
        pairs = [(red, inside) for red, inside in new["samples"]
                 if stroke_contains(red[0], new_red) and not stroke_contains(inside[0], new_red)]
        if not pairs:
            raise ValueError(f"{name} {key}: no matched pairs along the solid red core")
        # Express the verified release stroke in the branch's screen coordinates.
        old_strokes = [dict(old_red, points=new_red["points"])]
        old_ratios.append(median(ratio(*(tile_pixels(new, old_strokes, *sample) for sample in pair))
                                 for pair in pairs))
        new_ratios.append(median(ratio(*(tile_pixels(new, new_strokes, *sample) for sample in pair))
                                 for pair in pairs))
    old_median, new_median = median(old_ratios), median(new_ratios)
    passed = new_median >= (FIRE_MINIMUM if fire else old_median)
    minimum = f" min_after={min(new_ratios):.3f}" if fire else ""
    print(f"FEL32 {name} tiles={len(before)} contrast_before_median={old_median:.3f} "
          f"contrast_after_median={new_median:.3f}{minimum} {'PASS' if passed else 'FAIL'}")
    return passed


def check_adjacent(tiles):
    left, right = tiles
    for tile, neighbor in ((left, right), (right, left)):
        strokes = tile["strokes"]
        if [row["width"] for row in strokes] != [BAND_WIDTH, RED_WIDTH]:
            raise ValueError("ADJACENT: branch did not submit a band followed by red")
        band, red = strokes
        adjacent_red = neighbor["strokes"][-1]
        for point in band["points"][:4]:
            if abs(signed_distance(point, tile["diamond"]) - band["width"] / 2) > GEOMETRY_TOLERANCE:
                raise ValueError("ADJACENT: band centerline does not sit half a stroke inside")
        if band["antialias"]:
            raise ValueError("ADJACENT: band has an AA fringe beyond its solid stroke")
        xs, ys = zip(*tile["diamond"])
        shared_edge_core = 0
        for y in range(int(min(ys)), math.ceil(max(ys))):
            for x in range(int(min(xs)), math.ceil(max(xs))):
                point = (x + 0.5, y + 0.5)
                covered = stroke_contains(point, band)
                if covered and (signed_distance(point, tile["diamond"]) < 0 or stroke_contains(point, adjacent_red)):
                    raise ValueError("ADJACENT: band overlaps the neighbouring red line or exits its tile")
                neighbor_distance = signed_distance(point, neighbor["diamond"])
                shared_edge_core += stroke_contains(point, red) and -RED_WIDTH < neighbor_distance < 0
        if not shared_edge_core:
            raise ValueError("ADJACENT: no red pixels alongside the shared edge")
    print("FEL32 ADJACENT PASS")
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    load = lambda name: json.loads((args.output / name).read_text())
    before, after = load("release/moments.json"), load("branch/moments.json")
    passed = [
        check_combat(before, after, "FIRE", FIRE_COMBAT, True),
        check_combat(before, after, "STONE", STONE_COMBAT, False),
        check_adjacent(load("adjacent.json")["tiles"]),
    ]
    if not all(passed):
        raise SystemExit(1)
    print(f"FEL32 PASS cases={len(passed)}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        raise SystemExit(f"FEL32 FAIL {error}") from error

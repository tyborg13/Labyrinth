"""Resolve the existing witnesses into a shared case list and visual contract."""

import json
from pathlib import Path
import sys

TOOL = Path(__file__).resolve().parent
TOOLS = TOOL.parents[1]
PILLAR_TILE = (7, 7)
ORDINARY_EXIT = (4, 0)
SEALED_EXIT = (8, 4)
PLAIN_DOOR = (4, 8)
MARK_HOVERS = {"01": (2, 2), "04": (2, 3), "10": (4, 2)}
FRAME_SIZE = (1920, 1080)
REST_SETTLE_SECONDS = 0.35
TOOLTIP_SETTLE_SECONDS = 0.5
MARK_HOVER_SETTLE_SECONDS = 1.5


def stills(contract):
    return [Path(row["pattern"]).stem for row in json.loads(contract.read_text())["required_images"]]


def case(name, source, target, tile=None, *, mount="resume", settle=TOOLTIP_SETTLE_SECONDS):
    result = {"name": name, "source": str(source), "target": target, "mount": mount, "settle": settle}
    if tile is not None:
        result["tile"] = tile
    return result


def cases(prepared):
    fel01 = TOOLS / "fel01" / "fixtures"
    fel04 = TOOLS / "fel04"
    fel08 = TOOL.parent

    # Use the same five choices (and order) as fel-07/pair_sheet.py.
    sys.path.insert(0, str(TOOLS / "fel07"))
    from compare_census import EXPECTED

    results = []
    for name in stills(fel08 / "proof_contract.json"):
        if name.endswith("-C-hover"):
            results.append(case(name, fel01 / name.removesuffix("-C-hover"), "tile", PILLAR_TILE))
    ordinary = prepared / "ordinary"
    results.extend([
        case("exit-hover", ordinary, "tile", ORDINARY_EXIT, mount="load"),
        case("sealed-exit-hover", prepared / "sealed-snare", "tile", SEALED_EXIT, mount="load"),
        case("door-hover", ordinary, "tile", PLAIN_DOOR, mount="load"),
        case("objective-one-exit", ordinary, "hud", mount="load"),
        case("objective-two-exits-resumed", prepared / "resumed-snare", "hud"),
        case("objective-pre-battle", prepared / "pre-battle", "plate", mount="load", settle=REST_SETTLE_SECONDS),
    ])

    for name in stills(fel04 / "proof_contract.json"):
        fixture, pose = name.rsplit("-", 1)
        target = "marks" if pose == "rest" else "tile"
        settle = REST_SETTLE_SECONDS if pose == "rest" else MARK_HOVER_SETTLE_SECONDS
        results.append(case(name, fel04 / "fixtures" / fixture, target, MARK_HOVERS[fixture[:2]], settle=settle))

    fixtures = {path.name[:2]: path for path in fel01.iterdir() if path.is_dir()}
    for (number, category), (position, _) in EXPECTED.items():
        fixture = fixtures[number]
        tile = tuple(map(int, position.strip("()").split(",")))
        results.append(case(f"{fixture.name}-{category}-hover", fixture, "tile", tile))
    return results


def main(output):
    rows = cases(output / "fixtures")
    (output / "cases.json").write_text(json.dumps(rows, indent=2) + "\n")
    width, height = FRAME_SIZE
    contract = {
        "min_images": len(rows),
        "expected_sizes": [f"{width}x{height}"],
        "required_images": [
            {"pattern": row["name"] + ".png", "width": width, "height": height, "min_count": 1}
            for row in rows
        ],
    }
    (output / "proof-contract.json").write_text(json.dumps(contract, indent=2) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())

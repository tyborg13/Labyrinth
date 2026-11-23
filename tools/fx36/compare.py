"""Check all three proof rows and assemble the native contact sheets."""

import argparse
import json
from pathlib import Path

REVISIONS = ("old", "fx33", "now")
CASES = {"chain_bolt": 2, "storm_relay": 2, "capacitor": 3}
OFFSETS = (0, 2, 6, 10)
PRESERVED = ("routes", "damage", "bursts", "columns", "done", "opening_spark")
CROP = (640, 480)
REEL_SAMPLES = 180


def read_take(root, revision, case):
    return json.loads((root / revision / case / "take.json").read_text())


def check_takes(root, case, hops):
    takes = {revision: read_take(root, revision, case) for revision in REVISIONS}
    for revision, take in takes.items():
        if len(take["columns"]) != hops:
            raise ValueError(f"{case} {revision}: expected {hops} contact rows")
        for hop, columns in take["columns"].items():
            if [frame - columns[0] for frame in columns] != list(OFFSETS):
                raise ValueError(f"{case} {revision} hop {hop}: wrong contact offsets {columns}")
    before, after = takes["fx33"], takes["now"]
    if before["bolts"] or takes["old"]["bolts"] or len(after["bolts"]) != hops:
        raise ValueError(f"{case}: unexpected retained bolt counts")
    if takes["old"]["routes"] != after["routes"]:
        raise ValueError(f"{case}: the old fight took a different route")
    for field in PRESERVED:
        if before[field] != after[field]:
            raise ValueError(f"{case}: changed fx-33/fx-34 {field}")
    if after["reel_frames"] != REEL_SAMPLES or after["done"] >= REEL_SAMPLES:
        raise ValueError(f"{case}: incomplete reel segment")
    print(f"FX-36 PROOF {case} " + " · ".join(f"{rev} {take['columns']}" for rev, take in takes.items()))


def build_sheet(root, case, hop):
    from PIL import Image

    destination = root / "comparison" / case
    destination.mkdir(parents=True, exist_ok=True)
    names = [f"hop-{hop}-column-{column}.png" for column in range(len(OFFSETS))]
    names.append(f"hop-{hop}-contact-2x.png")
    sheet = Image.new("RGB", (CROP[0] * len(names), CROP[1] * len(REVISIONS)))
    for row, revision in enumerate(REVISIONS):
        for column, name in enumerate(names):
            source = root / revision / case / name
            with Image.open(source) as image:
                if image.size != CROP:
                    raise ValueError(f"Wrong size for {source}: {image.size}")
                sheet.paste(image, (column * CROP[0], row * CROP[1]))
    sheet_path = destination / f"hop-{hop}.png"
    sheet.save(sheet_path)
    print(sheet_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    for case, hops in CASES.items():
        check_takes(args.root, case, hops)
        if not args.dry_run:
            for hop in range(1, hops + 1):
                build_sheet(args.root, case, hop)
    print(f"FX-36 {'DRY RUN' if args.dry_run else 'NATIVE COMPARISON'} PASS · {args.root}")


if __name__ == "__main__":
    main()

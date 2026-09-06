#!/usr/bin/env python3
"""Check same-clock native surface PNGs against the original drawing path."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    paths = [Path(item["path"]) for item in manifest["images"]]
    reports = []
    for reference in sorted(path for path in paths if path.name.endswith("_reference.png")):
        cached = reference.with_name(reference.name.replace("_reference.png", "_cached.png"))
        if cached not in paths:
            raise ValueError(f"Missing matched cached frame: {cached}")
        with Image.open(reference) as source, Image.open(cached) as candidate:
            if source.size != (1920, 1080) or candidate.size != source.size:
                raise ValueError("Cache proof must use matched native 1920x1080 PNGs")
            difference = ImageChops.difference(source.convert("RGB"), candidate.convert("RGB"))
        red, green, blue = difference.split()
        maximum_band = ImageChops.lighter(ImageChops.lighter(red, green), blue)
        maximum = max(channel[1] for channel in difference.getextrema())
        mean = sum(ImageStat.Stat(difference).mean) / 3.0
        over_two = sum(maximum_band.histogram()[3:])
        # Native CanvasItem transforms can differ at a few antialiased edges.
        # At least 99.999% of pixels must stay within 2/255 per channel; whole-
        # image limits reject missing art, altered motion or alpha order.
        accepted = maximum <= 16 and mean <= 0.0001 and over_two / (1920 * 1080) <= 0.00001
        reports.append({"reference": str(reference), "cached": str(cached),
                        "max_channel_delta": maximum, "mean_channel_delta": mean,
                        "pixels_over_two": over_two, "accepted": accepted})
    passed = len(reports) == 4 and all(report["accepted"] for report in reports)
    result = {"schema_version": 1, "passed": passed,
              "limits": {"max_channel_delta": 16, "mean_channel_delta": 0.0001,
                         "max_pixel_fraction_over_two": 0.00001}, "comparisons": reports}
    encoded = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(encoded, end="")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

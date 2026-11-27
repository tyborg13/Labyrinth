"""Write the five changed native hovers as matched, unscaled crops."""

import argparse
import json
from math import ceil, floor
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from compare_census import EXPECTED, first_line, samples

FRAME_SIZE = (1920, 1080)
CROP_MARGIN = 24
LABEL_HEIGHT = 34
FONT_SIZE = 20
GAP = 12
BACKGROUND = "#181818"
LABEL_COLOR = "#ffffff"


def capture_bounds(directory):
    rows = (
        json.loads(line) for line in (directory / "pair_bounds.jsonl").read_text().splitlines()
    )
    return {row["frame"]: row for row in rows}


def common_crop(before, after):
    if not before["popups"] or not after["popups"]:
        raise ValueError(f"Missing embedded popup bounds for {before['frame']}")
    regions = [before["highlight"], after["highlight"], *before["popups"], *after["popups"]]
    width, height = FRAME_SIZE
    for left, top, right, bottom in regions:
        if not (0 <= left < right <= width and 0 <= top < bottom <= height):
            raise ValueError(f"Region lies outside the frame for {before['frame']}")
    return (
        max(0, floor(min(rect[0] for rect in regions)) - CROP_MARGIN),
        max(0, floor(min(rect[1] for rect in regions)) - CROP_MARGIN),
        min(width, ceil(max(rect[2] for rect in regions)) + CROP_MARGIN),
        min(height, ceil(max(rect[3] for rect in regions)) + CROP_MARGIN),
    )


def crop_frame(path, crop):
    with Image.open(path) as frame:
        if frame.size != FRAME_SIZE:
            raise ValueError(f"Expected a 1920x1080 capture at {path}")
        return frame.crop(crop).convert("RGB")


def matched_rows(base, branch):
    base_samples = samples(base / "observations.json", mode="native")
    branch_samples = samples(branch / "observations.json", mode="native")
    base_bounds = capture_bounds(base)
    branch_bounds = capture_bounds(branch)
    for key, (tile, expected) in EXPECTED.items():
        before, after = base_samples[key], branch_samples[key]
        if before["contents"]["tile"] != tile or after["contents"]["tile"] != tile:
            raise ValueError(f"Expected both captures of {key} at {tile}")
        if not first_line(before) or before["hover"]["tooltip_tile"] == tile \
                or first_line(after) != expected or after["hover"]["tooltip_tile"] != tile:
            raise ValueError(f"{key} at {tile} did not capture the before and after popup")
        before_frame, after_frame = before["frame"], after["frame"]
        if before_frame != after_frame:
            raise ValueError(f"Fixture name differs for {key}")
        crop = common_crop(base_bounds[before_frame], branch_bounds[after_frame])
        fixture = before_frame.removesuffix(f"-{key[1]}-hover.png")
        label = f"{fixture}  {key[1]}  {tile}"
        yield label, crop_frame(base / before_frame, crop), crop_frame(branch / after_frame, crop)


def write_sheet(rows, output):
    font = ImageFont.load_default(size=FONT_SIZE)
    column_width = max(before.width for _, before, _ in rows)
    width = max(2 * column_width + 3 * GAP,
                ceil(max(font.getlength(label) for label, _, _ in rows)) + 2 * GAP)
    height = LABEL_HEIGHT + GAP + sum(LABEL_HEIGHT + before.height + GAP for _, before, _ in rows)
    sheet = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    columns = (GAP, width - GAP - column_width)
    for label, x in zip(("Base", "Branch"), columns):
        draw.text((x, GAP), label, font=font, fill=LABEL_COLOR)
    y = LABEL_HEIGHT + GAP
    for label, before, after in rows:
        draw.text((GAP, y), label, font=font, fill=LABEL_COLOR)
        y += LABEL_HEIGHT
        for x, image in zip(columns, (before, after)):
            sheet.paste(image, (x, y))
        y += before.height + GAP
    sheet.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path)
    parser.add_argument("branch", type=Path)
    args = parser.parse_args()
    rows = list(matched_rows(args.base, args.branch))
    output = args.branch.resolve() / "pairs.png"
    write_sheet(rows, output)
    print(f"FEL07 PAIRS PASS rows={len(rows)}")
    print(output)


if __name__ == "__main__":
    main()

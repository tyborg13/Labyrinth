"""Compose matched crops and half-scale full frames from the validated stills."""

import json
from math import ceil, floor
from pathlib import Path
import re
import sys

from PIL import Image, ImageDraw, ImageFont

from cases import FRAME_SIZE

CROP_MARGIN = 48
MIN_CROP = (640, 400)
LABEL_HEIGHT = 34
FONT_SIZE = 20
LABEL_INSET = 10
LABEL_BACKGROUND = "#181818"
LABEL_COLOR = "#ffffff"
FULL_FRAME_SIZE = tuple(dimension // 2 for dimension in FRAME_SIZE)


def pixels(rect):
    """Round outwards and intersect with the 1920×1080 image."""
    return (
        max(0, floor(rect[0])),
        max(0, floor(rect[1])),
        min(FRAME_SIZE[0], ceil(rect[2])),
        min(FRAME_SIZE[1], ceil(rect[3])),
    )


def visible_regions(regions):
    for rect in regions:
        left, top, right, bottom = pixels(rect)
        if left < right and top < bottom:
            yield left, top, right, bottom


def crop_axis(start, end, limit, minimum):
    start = max(0, start - CROP_MARGIN)
    end = min(limit, end + CROP_MARGIN)
    length = max(end - start, minimum)
    origin = start - (length - (end - start)) // 2
    origin = max(0, min(origin, limit - length))
    return origin, origin + length


def common_crop(before, after):
    regions = []
    for row in (before, after):
        anchor = row["medallions"] or [row["anchor"]]
        regions.extend(visible_regions(anchor))
        regions.extend(visible_regions(popup["rect"] for popup in row["popups"]))
    if not regions:
        raise ValueError(f"No visible crop anchor for {before['case']}")
    left, top, right, bottom = zip(*regions)
    x0, x1 = crop_axis(min(left), max(right), FRAME_SIZE[0], MIN_CROP[0])
    y0, y1 = crop_axis(min(top), max(bottom), FRAME_SIZE[1], MIN_CROP[1])
    return x0, y0, x1, y1


def popup_status(before_frame, after_frame, before, after):
    regions = list(visible_regions(popup["rect"] for row in (before, after) for popup in row["popups"]))
    if not regions:
        return "No pop-up on either side"
    if all(before_frame.crop(rect).tobytes() == after_frame.crop(rect).tobytes() for rect in regions):
        return "UNCHANGED"
    return "Changed pixels in pop-up region"


def read_frame(path):
    with Image.open(path) as frame:
        if frame.size != FRAME_SIZE:
            raise ValueError(f"Expected a {FRAME_SIZE[0]}×{FRAME_SIZE[1]} frame at {path}")
        return frame.convert("RGBA")


def pair(before, after, case, path):
    width, height = before.size
    sheet = Image.new("RGB", (2 * width, height + LABEL_HEIGHT), LABEL_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=FONT_SIZE)
    for index, (image, label) in enumerate(((before, "before"), (after, "after"))):
        x = width * index
        draw.text((x + LABEL_INSET, LABEL_HEIGHT // 2), f"{case} · {label}", fill=LABEL_COLOR,
                  font=font, anchor="lm")
        sheet.paste(image, (x, LABEL_HEIGHT))
    sheet.save(path)


def escape(text):
    return re.sub(r"([\\`*_\[\]<>])", r"\\\1", text)


def describe_side(label, row):
    lines = [f"**{label}**", ""]
    if not row["popups"]:
        return [*lines, "No pop-up.", ""]
    for index, popup in enumerate(row["popups"], start=1):
        for panel in popup["panels"]:
            title = escape(panel["title"]) or "(No title text)"
            lines.append(f"- Pop-up {index} · **{title}**")
            lines.extend(f"  - {escape(line)}" for line in panel["lines"] if line)
    return [*lines, ""]


def write_case(output, name, before, after):
    before_path = Path("release") / before["frame"]
    after_path = Path("branch") / after["frame"]
    before_frame = read_frame(output / before_path)
    after_frame = read_frame(output / after_path)
    crop = common_crop(before, after)
    crop_name = f"{name}-pair.png"
    full_name = f"{name}-full-pair.png"
    pair(before_frame.crop(crop), after_frame.crop(crop), name, output / crop_name)
    pair(before_frame.resize(FULL_FRAME_SIZE, Image.Resampling.LANCZOS),
         after_frame.resize(FULL_FRAME_SIZE, Image.Resampling.LANCZOS), name, output / full_name)
    status = popup_status(before_frame, after_frame, before, after)
    return [
        f"## {name}", "", f"Crop rect `{crop}` · {status}", "",
        f"[Crop]({crop_name}) · [Full frames]({full_name}) · "
        f"[Before original]({before_path.as_posix()}) · [After original]({after_path.as_posix()})",
        "", *describe_side("Before", before), *describe_side("After", after),
    ]


def main(output):
    cases = json.loads((output / "cases.json").read_text())
    observations = []
    for side in ("release", "branch"):
        path = output / side / "observations.json"
        observations.append({row["case"]: row for row in json.loads(path.read_text())} if path.exists() else {})
    before, after = observations
    index = [
        "# Board pop-ups before and after", "",
        "Crop coordinates are left, top, right, bottom in the 1920×1080 frame.",
        "`UNCHANGED` requires exact pixel equality across the visible pop-up rectangles.", "",
    ]
    failures = 0
    for case in cases:
        name = case["name"]
        try:
            index.extend(write_case(output, name, before[name], after[name]))
        except (KeyError, OSError, ValueError) as exc:
            failures += 1
            print(f"FEL08 BA PAIR FAIL {name}: {exc}", file=sys.stderr)
            index.extend([f"## {name}", "", "Pair unavailable. See the side logs.", ""])
    path = output / "index.md"
    path.write_text("\n".join(index), encoding="utf-8")
    print(path)
    if failures:
        print(f"FEL08 BA PAIRS FAIL pairs={len(cases) - failures} missing={failures}", file=sys.stderr)
        return 1
    print(f"FEL08 BA PAIRS PASS cases={len(cases)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]).resolve()))

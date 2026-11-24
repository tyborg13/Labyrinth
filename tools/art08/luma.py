"""Measure visible sprite and one-tile floor-ring luma in native art-08 stills."""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
NATIVE_AFTER = Path("/private/tmp/labyrinth_codex/art-08/native/after")
FRAMES = ("01_burrowed_peak", "02_burrowed_trough", "04_after_burrow", "06_erupt_contact")
LUMA_WEIGHTS = (0.2126, 0.7152, 0.0722)  # Rec. 709 luma on the captured 8-bit RGB values.
OPAQUE = 255
RIM_PADDING = 2  # Account for the board's painted unit outline in floor exclusions.


def mapped_alpha(paint, size, captures):
    source = ROOT / paint["asset"] if "asset" in paint else captures / paint["mask"]
    with Image.open(source) as image:
        alpha = image.convert("RGBA").getchannel("A")
    x, y, width, height = paint["rect"]
    if width <= 0 or height <= 0:
        raise ValueError(f"Invalid drawn rect {paint['rect']}")
    # Inverse map viewport pixel centers into the original alpha canvas.
    return alpha.transform(size, Image.Transform.AFFINE,
                           (alpha.width / width, 0, -x * alpha.width / width,
                            0, alpha.height / height, -y * alpha.height / height),
                           resample=Image.Resampling.NEAREST)


def mean_luma(frame, geometry, captures):
    size = frame.size
    subject_alpha = mapped_alpha(geometry["subject"], size, captures)
    subject = np.asarray(subject_alpha) == OPAQUE
    ring = Image.new("L", size)
    pen = ImageDraw.Draw(ring)
    for polygon in geometry["floor_tiles"]:
        pen.polygon([tuple(point) for point in polygon], fill=255)
    ui = Image.new("L", size)
    pen = ImageDraw.Draw(ui)
    for x, y, width, height in geometry["ui"]:
        pen.rectangle((x, y, x + width, y + height), fill=255)
    exclusion = np.asarray(ui) > 0
    for unit in geometry["other_units"]:
        alpha = mapped_alpha(unit, size, captures)
        exclusion |= np.asarray(alpha.filter(ImageFilter.MaxFilter(1 + 2 * RIM_PADDING))) > 0
    subject &= ~exclusion
    floor = (np.asarray(ring) > 0) & ~exclusion
    floor &= np.asarray(subject_alpha.filter(ImageFilter.MaxFilter(1 + 2 * RIM_PADDING))) == 0
    if not subject.any() or not floor.any():
        raise ValueError("No unoccluded opaque sprite or floor pixels to measure")
    pixels = np.asarray(frame.convert("RGB"), dtype=np.float64)
    luma = np.sum(pixels * LUMA_WEIGHTS, axis=-1)
    return luma[subject].mean(), luma[floor].mean(), subject.sum(), floor.sum()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("after", type=Path, nargs="?", default=NATIVE_AFTER,
                        help="native after directory written by the art-08 launcher")
    args = parser.parse_args()
    records = json.loads((args.after / "frames.json").read_text())["frames"]
    for name in FRAMES:
        geometry = records[name].get("luma", {})
        if "other_units" not in geometry:
            raise SystemExit(f"{name} needs a native capture from the updated art-08 probe")
        with Image.open(args.after / f"{name}.png") as frame:
            body, floor, body_pixels, floor_pixels = mean_luma(frame, geometry, args.after)
        print(f"{name} opaque sprite={body:.2f} ({body_pixels} px) "
              f"floor ring={floor:.2f} ({floor_pixels} px) delta={body - floor:+.2f} "
              f"profile={geometry['subject']['profile']}")


if __name__ == "__main__":
    main()

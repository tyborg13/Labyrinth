#!/usr/bin/env python3
"""Build labeled 3x board crops from strike_trail_probe's native manifest.

Usage: python3 tools/build_strike_trail_sheet.py <capture-dir> --output-dir <scratch-dir>
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_dir", type=Path, help="Probe capture directory or visual_probe_runner result JSON")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    capture_dir = args.capture_dir
    if capture_dir.is_file():
        proof = json.loads(capture_dir.read_text())
        candidates = {Path(item["path"]).parent for item in proof.get("images", [])}
        candidates = [path for path in candidates if (path / "manifest.json").is_file()]
        if len(candidates) != 1:
            raise SystemExit("Proof JSON must identify one strike-trail capture directory")
        capture_dir = candidates[0]
    manifest = json.loads((capture_dir / "manifest.json").read_text())
    if manifest["size"] != [1920, 1080] or manifest["ui_scale"] != 1.0 or manifest["errors"]:
        raise SystemExit("Capture manifest must pass at 1920x1080, 100% UI scale")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    groups = {}
    for capture in manifest["captures"]:
        group = capture["view"] if capture["element"] == "none" and not capture["reduced"] else "accents"
        groups.setdefault(group, []).append(capture)
    for group, captures in groups.items():
        # Five effect checkpoints per row; preserve extra depth captures.
        columns = 5
        cell = 810
        header = 30
        rows = (len(captures) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * cell, rows * (cell + header)), (22, 20, 18))
        draw = ImageDraw.Draw(sheet)
        for index, capture in enumerate(captures):
            with Image.open(capture_dir / capture["file"]) as frame:
                if frame.size != (1920, 1080):
                    raise SystemExit("Wrong capture size: " + capture["file"])
                x, y, w, h = capture["crop"]
                # A 270px square preserves the pole/whip ends and near boot at 3x.
                crop = frame.crop((x + w // 8, y + h // 8, x + 7 * w // 8, y + 7 * h // 8))
                crop = crop.resize((cell, cell), Image.Resampling.NEAREST)
            px = index % columns * cell
            py = index // columns * (cell + header)
            sheet.paste(crop, (px, py + header))
            draw.text((px + 5, py + 5), f'{capture["motion"]} {capture["view"]} t={capture["progress"]:.2f} {capture["element"]} z={capture["weapon_z"]}', fill=(240, 230, 212))
        output = args.output_dir / f"strike_trail_{group}.png"
        sheet.save(output)
        print(output)


if __name__ == "__main__":
    main()

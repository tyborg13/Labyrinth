#!/usr/bin/env python3
"""Collect verified toolkit reels and exact-phase PNGs; never fabricate proof."""
import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parents[2] / "tools"))
from cutout_pipeline.cases import digest
from cutout_pipeline.proof import verify_render


def contact_sheet(review, clip, records):
    poses = {}
    bounds = None
    for key in records:
        pose = Image.open(review / (key["file"] + "_pose.png")).convert("RGBA")
        box = pose.getbbox()
        if not box:
            raise ValueError("Empty key pose: " + key["file"])
        bounds = box if bounds is None else (
            min(bounds[0], box[0]), min(bounds[1], box[1]),
            max(bounds[2], box[2]), max(bounds[3], box[3]),
        )
        poses[key["file"]] = pose
    # A common source-pixel crop contains every key of both painted facings.
    bounds = (bounds[0] - 8, bounds[1] - 8, bounds[2] + 8, bounds[3] + 8)
    w, h = bounds[2] - bounds[0], bounds[3] - bounds[1]
    phases = sorted(set(key["phase"] for key in records))
    cell_w = w * 2 + 24
    cell_h = h * 2 + round(h * 0.77) + 90
    sheet = Image.new("RGB", (cell_w * len(phases), cell_h * 2 + 42), "#211d23")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((12, 12), clip + " | exact authored phases | 2x poses + 0.77x board-scale thumbnails | source offsets preserved", fill="#efd39a", font=font)
    for key in records:
        x = phases.index(key["phase"]) * cell_w
        y = (0 if key["facing"] == "front" else cell_h) + 42
        draw.text((x + 12, y + 8), "%s  phase %.2f" % (key["facing"], key["phase"]), fill="#efd39a", font=font)
        crop = poses[key["file"]].crop(bounds)
        large = crop.resize((w * 2, h * 2), Image.Resampling.NEAREST)
        sheet.paste(large, (x + 12, y + 30), large)
        thumbnail = crop.resize((round(w * 0.77), round(h * 0.77)), Image.Resampling.NEAREST)
        ty = y + h * 2 + 52
        sheet.paste(thumbnail, (x + (cell_w - thumbnail.width) // 2, ty), thumbnail)
        draw.text((x + 12, ty - 16), "0.77x", fill="#aa9f91", font=font)
    sheet.save(review / (clip + "_contact_sheet.png"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keys", type=Path, required=True, help="Successful key_pose_probe user://probes/protagonist_gear_keys directory")
    args = parser.parse_args()
    manifest = json.loads((args.keys / "manifest.json").read_text())
    if manifest["errors"] or manifest["size"] != [1920, 1080] or manifest["ui_scale"] != 1.0:
        raise ValueError("Key capture did not pass its native proof contract")
    for relative, expected in manifest["source_sha256"].items():
        if digest(ROOT / relative) != expected:
            raise ValueError("Key pose source changed: " + relative)
    for name in ["heavy", "stab", "shield"]:
        case = ROOT / (name + "_v01")
        proof = Path("/private/tmp/protagonist-gear-" + name + "-v01")
        verification = verify_render(case, proof)
        if not verification["ok"]:
            raise ValueError("Stale/failed toolkit proof: " + json.dumps(verification))
        review = case / "review"
        review.mkdir(exist_ok=True)
        if (review / "cutout_review.mp4").exists():
            raise ValueError("Review already contains a reel; choose a fresh case version")
        for relative in ["videos/cutout_review.mp4", "videos/encoding.json", "front.tscn", "rear.tscn", "render_manifest.json"]:
            shutil.copyfile(proof / relative, review / Path(relative).name)
        keys = [key for key in manifest["keys"] if key["case"] == case.name]
        for key in keys:
            for suffix, size in [("_pose.png", (512, 512)), ("_board.png", (1920, 1080))]:
                source = args.keys / case.name / (key["file"] + suffix)
                with Image.open(source) as image:
                    if image.size != size:
                        raise ValueError("Wrong native capture resolution: " + str(source))
                shutil.copyfile(source, review / source.name)
        for clip in dict.fromkeys(key["clip"] for key in keys):
            contact_sheet(review, clip, [key for key in keys if key["clip"] == clip])
        (review / "key_manifest.json").write_text(json.dumps({"source_sha256": manifest["source_sha256"], "keys": keys}, indent=2) + "\n")
        print("GEAR_REVIEW_COLLECTED: " + case.name)


if __name__ == "__main__":
    main()

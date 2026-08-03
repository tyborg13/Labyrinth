#!/usr/bin/env python3
"""Validate dimensions, transparency, screenshot count, and trailer codecs."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = REPO_ROOT / "steam" / "assets"

REQUIRED_IMAGES = {
    "store/header_capsule.jpg": (920, 430),
    "store/small_capsule.jpg": (462, 174),
    "store/main_capsule.jpg": (1232, 706),
    "store/vertical_capsule.jpg": (748, 896),
    "store/page_background.jpg": (1438, 810),
    "library/library_capsule.jpg": (600, 900),
    "library/library_header.jpg": (920, 430),
    "library/library_hero.jpg": (3840, 1240),
    "library/library_logo.png": (1280, 720),
    "client/shortcut_icon.png": (512, 512),
    "client/app_icon.jpg": (184, 184),
}


def _validate_image(path: Path, expected_size: tuple[int, int]) -> list[str]:
    errors = []
    if not path.is_file():
        return [f"missing: {path.relative_to(REPO_ROOT)}"]
    with Image.open(path) as image:
        if image.size != expected_size:
            errors.append(
                f"wrong size: {path.relative_to(REPO_ROOT)} is {image.size}, expected {expected_size}"
            )
        if path.name == "library_logo.png":
            if image.mode != "RGBA":
                errors.append("library logo must be RGBA")
            else:
                minimum, maximum = image.getchannel("A").getextrema()
                if minimum != 0 or maximum != 255:
                    errors.append(
                        f"library logo must contain transparent and opaque pixels, alpha extrema were {(minimum, maximum)}"
                    )
    return errors


def _probe_trailer(path: Path) -> list[str]:
    if not path.is_file():
        return [f"missing: {path.relative_to(REPO_ROOT)}"]
    command = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "stream=codec_name,codec_type,width,height,r_frame_rate",
        "-of",
        "json",
        str(path),
    ]
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    streams = json.loads(result.stdout).get("streams", [])
    video = next((stream for stream in streams if stream.get("codec_type") == "video"), {})
    audio = next((stream for stream in streams if stream.get("codec_type") == "audio"), {})
    errors = []
    if video.get("codec_name") != "h264":
        errors.append(f"trailer video codec is {video.get('codec_name')}, expected h264")
    if (video.get("width"), video.get("height")) != (1920, 1080):
        errors.append(
            f"trailer size is {(video.get('width'), video.get('height'))}, expected (1920, 1080)"
        )
    if video.get("r_frame_rate") not in {"30/1", "60/1"}:
        errors.append(f"trailer frame rate is {video.get('r_frame_rate')}, expected 30 or 60 fps")
    if audio.get("codec_name") != "aac":
        errors.append(f"trailer audio codec is {audio.get('codec_name')}, expected aac")
    return errors


def main() -> int:
    errors = []
    for relative, expected_size in REQUIRED_IMAGES.items():
        errors.extend(_validate_image(ASSET_ROOT / relative, expected_size))

    screenshots = sorted((ASSET_ROOT / "screenshots").glob("*.png"))
    if len(screenshots) != 8:
        errors.append(f"expected 8 Steam screenshots, found {len(screenshots)}")
    for screenshot in screenshots:
        errors.extend(_validate_image(screenshot, (1920, 1080)))

    errors.extend(_validate_image(ASSET_ROOT / "trailer" / "poster.jpg", (1920, 1080)))
    errors.extend(_probe_trailer(ASSET_ROOT / "trailer" / "escape-the-umbra-gameplay.mp4"))

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Validated 11 images, 8 screenshots, trailer poster, and Steam-ready trailer codecs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

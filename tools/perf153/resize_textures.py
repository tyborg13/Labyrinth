#!/usr/bin/env python3
"""Build the six perf-153 production PNGs from the archived masters."""
from pathlib import Path

import numpy as np
from PIL import Image, PngImagePlugin

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art"
MASTERS = ROOT / "assets/_masters/perf-153"
SIZES = {
    "ui/campfire_choice_embrace_v2.png": (640, 640),
    "ui/campfire_choice_linger_v2.png": (640, 640),
    "ui/campfire_choice_purge_v2.png": (640, 640),
    "ui/campfire_choice_strength_v2.png": (640, 640),
    "ui/graftwright/ritual_clasp.png": (744, 248),
    "icons/map/ember_hoarder.png": (128, 128),
}


def resample(source: Path, output: Path, size: tuple[int, int]) -> None:
    with Image.open(source) as master:
        rgba = np.asarray(master.convert("RGBA"), dtype=np.float32) / 255.0
        srgb, alpha = rgba[..., :3], rgba[..., 3:4]
        linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
        premultiplied = np.concatenate((linear * alpha, alpha), axis=-1)
        channels = [
            np.asarray(Image.fromarray(channel).resize(size, Image.Resampling.LANCZOS))
            for channel in np.moveaxis(premultiplied, -1, 0)
        ]
        filtered = np.stack(channels, axis=-1)
        alpha = filtered[..., 3:4]
        linear = np.divide(
            filtered[..., :3], alpha,
            out=np.zeros_like(filtered[..., :3]), where=alpha > 0,
        ).clip(0, 1)
        srgb = np.where(linear <= 0.0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - 0.055)
        pixels = np.rint(np.concatenate((srgb, alpha.clip(0, 1)), axis=-1) * 255).astype(np.uint8)
        # Save straight alpha, as expected by the existing Godot import options.
        image = Image.fromarray(pixels).convert(master.mode)
        metadata = PngImagePlugin.PngInfo()
        if "srgb" in master.info:
            metadata.add(b"sRGB", bytes([master.info["srgb"]]))
        image.save(output, format="PNG", pnginfo=metadata)


if __name__ == "__main__":
    for path, size in SIZES.items():
        resample(MASTERS / path, ART / path, size)

#!/usr/bin/env python3
"""Animate the approved static biome lights; never modify the source paintings.

All motion is authored in data/biome_light_motion.json. Regenerate with:
  python3 tools/biome_light_idle.py --all --proof-dir /private/tmp/pt13-05-strips
Metrics use the director's top-45% region and a >24 RGBA channel delta (which
reproduces the old sheets' measured motion). Percentages include the loop seam.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "data/biome_light_motion.json"
SIDES = ("left", "right")
COMPARISON_BIOMES = ("vyraketh", "noctyrax", "vaeloryx")
COMPARISON_FRAMES = (0, 1)
COMPARISON_SCALE = 4
COMPARISON_PADDING = 4  # Proof-only source pixels around the emitting region.
COMPARISON_BACKGROUND = (32, 32, 40, 255)


def read_rgba(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        return np.asarray(image.convert("RGBA")).copy()


def png_bytes(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=False, compress_level=9)
    return buffer.getvalue()


def light_mask(source: np.ndarray, settings: dict, side: str) -> np.ndarray:
    """Colour + luminance selection, clipped above the painted holder."""
    rgb = source[..., :3].astype(float) / 255
    hi, lo = rgb.max(-1), rgb.min(-1)
    chroma = hi - lo
    hue = np.zeros(hi.shape)
    for channel, offset in ((0, 0), (1, 2), (2, 4)):
        selected = (rgb.argmax(-1) == channel) & (chroma > 0)
        hue[selected] = ((rgb[..., (channel + 1) % 3] - rgb[..., (channel + 2) % 3])
                         / np.maximum(chroma, 1e-9) + offset)[selected] * 60
    hue %= 360
    low, high = settings["hue_degrees"]
    hue_ok = (hue >= low) & (hue <= high) if low <= high else (hue >= low) | (hue <= high)
    luminance = (rgb * np.array([0.2126, 0.7152, 0.0722])).sum(-1)
    mask = ((source[..., 3] > 0) & hue_ok & (luminance >= settings["min_luminance"])
            & (chroma / np.maximum(hi, 1e-9) >= settings["min_saturation"]))
    x0, y0, x1, y1 = settings["bounds"]
    if side == "right":
        x0, x1 = source.shape[1] - x1, source.shape[1] - x0
    yy, xx = np.indices(mask.shape)
    return mask & (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)


def wave(phase: float, harmonics: list[list[float]]) -> float:
    return sum(weight * np.sin(2 * np.pi * (frequency * phase + offset))
               for frequency, weight, offset in harmonics) / sum(abs(h[1]) for h in harmonics)


def recolor(source: np.ndarray, mask: np.ndarray, gain: np.ndarray | float,
            palette: np.ndarray) -> np.ndarray:
    """Quantize brightness to colours already painted in this light region."""
    result = source.copy()
    target = source[mask, :3].astype(float) * (gain[mask, None] if isinstance(gain, np.ndarray) else gain)
    colors = palette[:, :3].astype(float)
    luminance = (colors * np.array([0.2126, 0.7152, 0.0722])).sum(-1)
    darkest = (luminance * palette[:, 3] / 255).min()
    alpha = source[mask, 3]
    # Small batches avoid a frame-size × palette-size temporary on large inputs.
    nearest = []
    for start in range(0, len(target), 128):
        distance = ((target[start:start + 128, None] - colors[None]) ** 2).sum(-1)
        # Preserve the painting's alpha without pairing a translucent edge
        # with a shade that falls below its darkest composited light colour.
        distance[luminance[None] * alpha[start:start + 128, None] / 255 < darkest] = np.inf
        nearest.extend(distance.argmin(-1))
    result[mask, :3] = colors[nearest].astype(np.uint8)
    return result


def filled_hull(mask: np.ndarray) -> np.ndarray:
    """Close enclosed gaps without bridging separate flames or stray embers."""
    outside = np.pad(~mask, 1, constant_values=True)
    reached = np.zeros_like(outside)
    pending = [(0, 0)]
    while pending:
        y, x = pending.pop()
        if not (0 <= y < outside.shape[0] and 0 <= x < outside.shape[1]):
            continue
        if reached[y, x] or not outside[y, x]:
            continue
        reached[y, x] = True
        pending.extend(((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)))
    return ~reached[1:-1, 1:-1]


def displacement_offsets(shape: tuple[int, int], phase: float, motion: dict,
                         side: str) -> tuple[np.ndarray, np.ndarray]:
    """The same authored periodic field drives sampling and the silhouette."""
    yy, xx = np.indices(shape)
    bottom = motion["anchor_y"]
    strength = np.clip((bottom - yy) / bottom, 0, 1) ** motion["tip_power"]
    strength = motion["root_strength"] + (1 - motion["root_strength"]) * strength
    spatial = yy / motion["noise_scale"]
    direction = -1 if side == "right" else 1
    dx = direction * motion["amplitude"][0] * strength * np.sin(2 * np.pi * (
        motion["cycles"][0] * phase + spatial))
    dy = -motion["amplitude"][1] * strength * (1 + np.sin(2 * np.pi * (
        motion["cycles"][1] * phase + xx / motion["noise_scale"]))) / 2
    return dx, dy


def displace(source: np.ndarray, mask: np.ndarray, phase: float, motion: dict,
             side: str) -> np.ndarray:
    """Gather every light destination; out-of-mask samples clamp to light.

    The closed destination hull cannot be evacuated by displacement. Painted
    non-light islands (cage bars, lantern frame) remain byte-identical. Outside
    that hull only transparent pixels reached by the moving silhouette enter
    the light region. No holder or background pixel is a sampling candidate.
    """
    result = source.copy()
    if not any(motion["amplitude"]):
        return result
    yy, xx = np.indices(mask.shape)
    dx, dy = displacement_offsets(mask.shape, phase, motion, side)
    sx = np.rint(xx - dx).astype(int)
    sy = np.rint(yy - dy).astype(int)
    valid = (sx >= 0) & (sx < source.shape[1]) & (sy >= 0) & (sy < source.shape[0])
    in_light = valid & mask[sy.clip(0, source.shape[0] - 1), sx.clip(0, source.shape[1] - 1)]
    writable = (source[..., 3] == 0) | mask
    destination = (filled_hull(mask) | in_light) & writable
    # Clamp to the nearest actual emitting sample, with row-major tie breaking.
    # Use the original displaced coordinates, even when outside the canvas.
    wanted = np.argwhere(destination & ~in_light)
    painted = np.argwhere(mask)
    for start in range(0, len(wanted), 128):
        batch = wanted[start:start + 128]
        queries = np.column_stack((sy[batch[:, 0], batch[:, 1]], sx[batch[:, 0], batch[:, 1]]))
        distances = ((queries[:, None] - painted[None]) ** 2).sum(-1)
        nearest = painted[distances.argmin(-1)]
        sy[batch[:, 0], batch[:, 1]] = nearest[:, 0]
        sx[batch[:, 0], batch[:, 1]] = nearest[:, 1]
    result[destination] = source[sy[destination], sx[destination]]
    return result


def tear_counts(source: np.ndarray, mask: np.ndarray, frames: np.ndarray) -> list[int]:
    """Dark regressions inside the light hull; original dark paint is exempt.

    Measure colour independently of edge coverage: translucent fringes must
    not lower the opaque core's floor. Missing alpha still counts as darkness.
    Only fully opaque samples define the approved painting's light-ramp floor.
    """
    weights = np.array([0.2126, 0.7152, 0.0722])
    luminance = (source[..., :3].astype(float) * weights).sum(-1)
    opaque_light = mask & (source[..., 3] == 255)
    if not opaque_light.any():
        raise ValueError("tear oracle requires opaque light-ramp pixels")
    darkest = luminance[opaque_light].min()
    coverage = luminance * source[..., 3] / 255
    darkest_coverage = coverage[mask].min()
    eligible = (filled_hull(mask) & (luminance >= darkest) & (source[..., 3] > 0)
                & (coverage >= darkest_coverage))
    size = (frames.shape[2], frames.shape[1])
    eligible = np.asarray(Image.fromarray(eligible).resize(size, Image.Resampling.NEAREST))
    light = (frames[..., :3].astype(float) * weights).sum(-1)
    # Retain the separate coverage check for partially evacuated pixels. It
    # cannot weaken the opaque colour floor that rejects holder contamination.
    frame_coverage = light * frames[..., 3] / 255
    dark = (light < darkest) | (frame_coverage < darkest_coverage) | (frames[..., 3] == 0)
    return np.count_nonzero(eligible & dark, axis=(1, 2)).tolist()


def particles(frame: np.ndarray, source: np.ndarray, mask: np.ndarray, phase: float,
              settings: dict, palette: np.ndarray, side: str) -> None:
    """Data-authored one-pixel paths; fade through the existing colour ramp."""
    order = np.argsort((palette[:, :3].astype(float) * np.array([0.2126, 0.7152, 0.0722])).sum(-1))
    for path in settings["paths"]:
        age = (phase - path["phase"]) % 1.0
        if age >= path["duration"]:
            continue
        age /= path["duration"]
        x = round(path["start"][0] + (path["end"][0] - path["start"][0]) * age)
        y = round(path["start"][1] + (path["end"][1] - path["start"][1]) * age)
        if side == "right":
            x = source.shape[1] - 1 - x
        if 0 <= y < frame.shape[0] and 0 <= x < frame.shape[1] and (source[y, x, 3] == 0 or mask[y, x]):
            brightness = np.sin(np.pi * age) ** settings["fade_power"]
            color = palette[order[round(brightness * (len(order) - 1))]]
            frame[y, x] = color


def generate_frames(source: np.ndarray, config: dict, biome: str, side: str) -> np.ndarray:
    settings = config["biomes"][biome]
    if settings["particles"]["count"] != len(settings["particles"]["paths"]):
        raise ValueError(f"particle count must match authored paths: {biome}")
    if settings["glint"]["count"] not in (0, 1):
        raise ValueError(f"only a single travelling glint is supported: {biome}")
    if len(settings["strike_frames"]) != len(settings["strike_motion_scale"]):
        raise ValueError(f"each strike needs a motion scale: {biome}")
    mask = light_mask(source, settings["mask"], side)
    if not mask.any():
        raise ValueError(f"empty light mask: {biome}/{side}")
    palette = np.unique(source[mask], axis=0)
    motion_mask = mask & light_mask(source, settings["motion_mask"], side) if settings["motion_mask"] else mask
    yy, xx = np.indices(mask.shape)
    # An ordered palette dissolve preserves the painting's colours while a
    # low-amplitude pulse remains visible on its coarse pixel grid. Each pixel
    # crosses between the two authored brightness endpoints twice per pulse;
    # it never changes position or alpha. No random frame-to-frame noise.
    dissolve = ((xx * settings["glow_dither"][0] + yy * settings["glow_dither"][1])
                % settings["glow_dither"][2]) / settings["glow_dither"][2]
    glow_low = recolor(source, mask, 1 - settings["glow_range"], palette)
    glow_high = recolor(source, mask, 1 + settings["glow_range"], palette)
    frames = []
    for index in range(config["frames"]):
        # Both paintings share the same temporal parameters. Spatial sampling
        # makes their loops distinct; the board retains its sole side offset.
        phase = index / config["frames"] + settings["phase_offset"]
        gain = 1 + settings["flicker_range"] * wave(phase, settings["flicker_harmonics"])
        frame = source.copy()
        if settings["glow_range"]:
            pulse = 1 - abs(2 * ((phase * settings["glow_cycles"]) % 1) - 1)
            frame[mask] = np.where((dissolve < pulse)[mask, None], glow_high[mask], glow_low[mask])
        frame = recolor(frame, mask, gain, palette)
        glint = settings["glint"]
        if glint["count"]:
            position = glint["start_y"] + (glint["end_y"] - glint["start_y"]) * (phase % 1)
            glint_gain = 1 + glint["gain"] * np.clip(1 - np.abs(yy - position) / glint["radius"], 0, 1)
            frame = recolor(frame, mask, glint_gain, palette)
        if index in settings["strike_frames"]:
            frame = recolor(frame, mask, 1 + settings["strike_gain"], palette)
        motion = settings["displacement"]
        motion_phase = phase
        if settings["strike_frames"]:
            # Four one-frame re-strikes; the other frames preserve the painted path.
            motion = dict(motion)
            if index not in settings["strike_frames"]:
                motion["amplitude"] = [0, 0]
            else:
                scale = settings["strike_motion_scale"][settings["strike_frames"].index(index)]
                motion["amplitude"] = [value * scale for value in motion["amplitude"]]
        frame = displace(frame, motion_mask, motion_phase, motion, side)
        particles(frame, source, mask, phase, settings["particles"], palette, side)
        frames.append(np.asarray(Image.fromarray(frame).resize(tuple(config["frame_size"]), Image.Resampling.NEAREST)))
    return np.array(frames)


def sheet_image(frames: np.ndarray, grid: list[int]) -> Image.Image:
    count, height, width, _ = frames.shape
    if count != grid[0] * grid[1]:
        raise ValueError("frame count does not match sheet grid")
    sheet = Image.new("RGBA", (width * grid[0], height * grid[1]))
    for index, frame in enumerate(frames):
        sheet.paste(Image.fromarray(frame), (index % grid[0] * width, index // grid[0] * height))
    return sheet


def motion_metrics(frames: np.ndarray, metric: dict) -> dict:
    region = frames[:, :int(frames.shape[1] * metric["top_fraction"])]
    delta = np.abs(region.astype(int) - np.roll(region, -1, axis=0).astype(int)).max(-1)
    steps = (delta > metric["channel_delta"]).mean(axis=(1, 2)) * 100
    return {"step_percent": steps.tolist(), "mean_percent": float(steps.mean()),
            "seam_percent": float(steps[-1]), "unique_frames": len({frame.tobytes() for frame in frames})}


def band_failures(report: dict, settings: dict) -> list[str]:
    low, high = settings["target_percent"]
    errors = []
    if not low <= report["mean_percent"] <= high:
        errors.append("mean outside motion band")
    if not low <= report["seam_percent"] <= high:
        errors.append("seam outside motion band")
    if not settings["strike_frames"] and any(not low <= step <= high for step in report["step_percent"]):
        errors.append("step outside motion band")
    if report["unique_frames"] < settings["minimum_unique_frames"]:
        errors.append("too few unique frames")
    if any(report.get("tears_per_frame", [])):
        errors.append("tears inside light hull")
    return errors


def comparison_crop(source: np.ndarray, old_sheet: np.ndarray, frames: np.ndarray,
                    settings: dict, side: str) -> Image.Image:
    """Proof-only 4x crop: old/new columns, frame 0/frame 1 rows."""
    height, width = frames.shape[1:3]
    x0, y0, x1, y1 = settings["mask"]["bounds"]
    if side == "right":
        x0, x1 = source.shape[1] - x1, source.shape[1] - x0
    box = (max(0, int((x0 - COMPARISON_PADDING) * width / source.shape[1])),
           max(0, int((y0 - COMPARISON_PADDING) * height / source.shape[0])),
           min(width, int(np.ceil((x1 + COMPARISON_PADDING) * width / source.shape[1]))),
           min(height, int(np.ceil((y1 + COMPARISON_PADDING) * height / source.shape[0]))))
    crop_width, crop_height = box[2] - box[0], box[3] - box[1]
    result = Image.new("RGBA", (crop_width * 2, crop_height * len(COMPARISON_FRAMES)), COMPARISON_BACKGROUND)
    for row, index in enumerate(COMPARISON_FRAMES):
        old = old_sheet[index // 4 * height:(index // 4 + 1) * height,
                        index % 4 * width:(index % 4 + 1) * width]
        for column, frame in enumerate((old, frames[index])):
            result.alpha_composite(Image.fromarray(frame).crop(box), (column * crop_width, row * crop_height))
    return result.resize((result.width * COMPARISON_SCALE, result.height * COMPARISON_SCALE), Image.Resampling.NEAREST)


def generate(config: dict, source_root: Path, output_root: Path, biome: str,
             proof_dir: Path | None = None, comparison_root: Path | None = None) -> dict:
    reports = {}
    for side in SIDES:
        source = read_rgba(source_root / biome / f"light_{side}.png")
        frames = generate_frames(source, config, biome, side)
        encoded = png_bytes(sheet_image(frames, config["grid"]))
        path = output_root / biome / f"light_{side}_idle.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encoded)
        mask = light_mask(source, config["biomes"][biome]["mask"], side)
        reports[side] = {**motion_metrics(frames, config["metric"]), "tears_per_frame": tear_counts(source, mask, frames),
                         "sha256": hashlib.sha256(encoded).hexdigest()}
        if proof_dir is not None:
            proof_dir.mkdir(parents=True, exist_ok=True)
            strip = sheet_image(frames, [len(frames), 1])
            strip = strip.resize((strip.width * config["proof_scale"], strip.height * config["proof_scale"]), Image.Resampling.NEAREST)
            (proof_dir / f"{biome}_{side}_strip.png").write_bytes(png_bytes(strip))
            if comparison_root is not None and biome in COMPARISON_BIOMES:
                old = read_rgba(comparison_root / biome / f"light_{side}_idle.png")
                crop = comparison_crop(source, old, frames, config["biomes"][biome], side)
                (proof_dir / f"{biome}_{side}_frames_00_01_old_vs_new_4x.png").write_bytes(png_bytes(crop))
    return reports


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--source-root", type=Path, default=ROOT / "assets/art/biomes")
    parser.add_argument("--output-root", type=Path, default=ROOT / "assets/art/biomes")
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument("--all", action="store_true")
    selection.add_argument("--biome")
    parser.add_argument("--proof-dir", type=Path)
    parser.add_argument("--comparison-root", type=Path, help="Prior sheets by biome; 4x old/new crops require --proof-dir.")
    args = parser.parse_args()
    if args.comparison_root is not None and args.proof_dir is None:
        parser.error("--comparison-root requires --proof-dir")
    config = json.loads(args.config.read_text())
    ids = list(config["biomes"]) if args.all else [args.biome]
    if any(biome not in config["biomes"] for biome in ids):
        parser.error("unknown biome")
    reports = {biome: generate(config, args.source_root, args.output_root, biome, args.proof_dir, args.comparison_root) for biome in ids}
    failures = []
    for biome, sides in reports.items():
        for side, report in sides.items():
            errors = band_failures(report, config["biomes"][biome])
            failures.extend(f"{biome}/{side}: {error}" for error in errors)
            print(f"BIOME LIGHT {biome}/{side}: mean={report['mean_percent']:.3f}% seam={report['seam_percent']:.3f}% unique={report['unique_frames']} tears={sum(report['tears_per_frame'])} {'FAIL' if errors else 'PASS'}")
    if args.proof_dir is not None:
        (args.proof_dir / "motion.json").write_text(json.dumps(reports, indent=2) + "\n")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Deterministic, presentation-only visual identity gate (numpy and Pillow).

The director-owned canon, prompt clauses and bands are inputs, never outputs.
Pixel hashes and density metrics deliberately share the board-density functions.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import io
import json
import math
import os
import re
from pathlib import Path
import shlex
import shutil
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

from pixel_density import metrics as density_metrics
from process_board_density import pixel_digest

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = Path("spec/art_identity")
DEFAULT_HEIGHTS = {"small": 150, "medium": 205, "large": 238}
PENDING_REART = (
    "arc_thrall", "briar_weaver", "burrow_grub", "ember_tick", "gale_herald",
    "glacial_mirror", "gloam_stalker", "gust_shrike", "hoarfrost_seer",
    "hollow_mimic", "slag_mortar", "storm_capacitor",
)
VIEWS = ("creature_front", "creature_rear", "beast_front", "beast_rear", "object_plinth")
MAQUETTE_REF_ROLES = frozenset(("maquette_parts", "maquette_clay", "identity", "canon", "edit_source"))
RESAMPLE = getattr(Image, "Resampling", Image)
# Proof-only dimensions and typography; no production rendering depends on these.
SHEET_DEFAULTS = {"width": 1920, "row_height": 320, "detail_height": 560,
                  "margin": 36, "font_size": 18, "table_line_height": 25,
                  "synthetic_origin": [160, 260], "synthetic_step_x": 320,
                  "label_offset": [-100, 8], "crop_above_slot": 280, "crop_below_slot": 70,
                  "detail_step_x": 570, "detail_offset_y": 30,
                  "ideal_line_extent": 250, "ideal_dash_period": 12, "ideal_dash_length": 6}
RAW_CANVAS_WIDTH = 1024
PROCESSED_FIT_SIZE = (251, 240) # Director-approved maximum width, height; never clip paint.


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(data, indent=2, sort_keys=True, allow_nan=False) + "\n").encode("utf-8"))


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def repo_path(root: Path, path: str) -> Path:
    path = path.removeprefix("res://")
    candidate = (root / path).resolve()
    if Path(path).is_absolute() or ".." in Path(path).parts or root.resolve() not in candidate.parents:
        raise ValueError("expected a repository-relative path: " + path)
    return candidate


def rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


def alpha_bbox(image: Image.Image) -> tuple:
    ys, xs = np.nonzero(np.asarray(image.convert("RGBA"))[..., 3] > 128)
    if not len(xs):
        raise ValueError("subject has no pixels with alpha > 128")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def disk(radius: int) -> np.ndarray:
    y, x = np.ogrid[-radius:radius + 1, -radius:radius + 1]
    return x * x + y * y <= radius * radius


def morphology(mask: np.ndarray, radius: int, dilate: bool = False) -> np.ndarray:
    """False outside support; callers pad before opening to preserve border paint."""
    padded = np.pad(mask, radius, constant_values=False)
    result = np.zeros_like(mask) if dilate else np.ones_like(mask)
    for y, x in np.argwhere(disk(radius)):
        shifted = padded[y:y + mask.shape[0], x:x + mask.shape[1]]
        if dilate:
            result |= shifted
        else:
            result &= shifted
    return result


def thin_share(mask: np.ndarray, radius: int) -> float:
    padded = np.pad(mask, radius + 2, constant_values=False)
    opened = morphology(morphology(padded, radius), radius, True)
    return float(1 - opened.sum() / max(1, mask.sum()))


def region_sizes(quantized: np.ndarray) -> list:
    """Four-connected components, including only pixels inside the silhouette."""
    seen = np.zeros(quantized.shape, dtype=bool)
    height, width = quantized.shape
    sizes = []
    for y, x in np.argwhere(quantized >= 0):
        if seen[y, x]:
            continue
        value = quantized[y, x]
        stack = [(int(y), int(x))]
        seen[y, x] = True
        count = 0
        while stack:
            cy, cx = stack.pop()
            count += 1
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if (0 <= ny < height and 0 <= nx < width and not seen[ny, nx]
                        and quantized[ny, nx] == value):
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        sizes.append(count)
    return sizes


def base_fits(mask: np.ndarray) -> list:
    profile = np.full(mask.shape[1], np.nan)
    for x in range(mask.shape[1]):
        ys = np.flatnonzero(mask[:, x])
        if len(ys):
            profile[x] = ys[-1]
    fits = []
    for start, end in ((0.08, 0.40), (0.60, 0.92)):
        xs = np.arange(int(start * mask.shape[1]), int(end * mask.shape[1]))
        xs = xs[np.isfinite(profile[xs])]
        if len(xs) < 2:
            raise ValueError("base profile needs at least two occupied columns on each side")
        slope, intercept = np.polyfit(xs, profile[xs], 1)
        fits.append({"slope": float(slope), "intercept": float(intercept),
                     "x0": int(xs[0]), "x1": int(xs[-1])})
    return fits


def lateral_axis(landmarks: dict) -> float:
    pair = landmarks.get("lateral_axis", landmarks)
    far, near = pair["far"], pair["near"]
    if len(far) != 2 or len(near) != 2 or not all(math.isfinite(float(v)) for v in far + near):
        raise ValueError("landmarks must be finite canvas [x, y] pairs")
    dx, dy = float(near[0]) - float(far[0]), float(near[1]) - float(far[1])
    if dx == 0 and dy == 0:
        raise ValueError("far and near landmarks must be distinct")
    return math.degrees(math.atan2(dy, dx))


def measure(path: Path, art_scale: float = 1.0, kind: str = "creature", anatomy: str = "") -> dict:
    if not math.isfinite(art_scale) or art_scale <= 0:
        raise ValueError("art_scale must be finite and positive")
    image = rgba(path)
    crop = image.crop(alpha_bbox(image))
    pixels = np.asarray(crop)
    mask = pixels[..., 3] > 128
    height, width = mask.shape
    mirror = mask[:, ::-1]
    symmetry = 0.0
    # Preserve prototype's Python floor division, including the odd-width lower endpoint.
    for shift in range(-width // 4, width // 4 + 1):
        shifted = np.roll(mirror, shift, axis=1)
        if shift > 0:
            shifted[:, :shift] = False
        elif shift < 0:
            shifted[:, shift:] = False
        symmetry = max(symmetry, float((mask & shifted).sum() / max(1, (mask | shifted).sum())))
    # scale.py crops on nonzero alpha before median filtering. Keep its sample
    # window even when faint fringe extends beyond the >128 measurement bbox.
    feature_crop = image.crop(image.getbbox())
    feature_mask = np.asarray(feature_crop)[..., 3] > 128
    luminance = np.asarray(feature_crop.convert("L").filter(ImageFilter.MedianFilter(3)), dtype=float)
    inner = morphology(feature_mask, 1)
    # A one-pixel synthetic line has no eroded interior. Its own samples are the
    # only defined quantiles; ordinary production silhouettes use the prototype interior.
    samples = luminance[inner] if inner.any() else luminance[feature_mask]
    quantiles = np.quantile(samples, [1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6])
    quantized = np.digitize(luminance, quantiles)
    quantized[~feature_mask] = -1
    regions = sum(size >= 4 for size in region_sizes(quantized))
    if not regions:
        raise ValueError("subject has no luminance regions of at least four pixels")
    rgb = pixels[..., :3].astype(float) / 255.0
    result = {"height": height, "width": width, "height_drawn": height * art_scale,
              "symmetry": symmetry, "thin_abs": thin_share(mask, 2),
              "thin_rel": thin_share(mask, round(0.03 * height)),
              "feature_px": float(np.sqrt(mask.sum() / regions)), "regions": regions,
              "chroma": float((rgb.max(-1) - rgb.min(-1))[mask].mean()),
              "value": float((rgb @ np.array([0.299, 0.587, 0.114]))[mask].mean()),
              "edge_light_share": edge_light_share(np.asarray(image))}
    if kind == "object":
        fits = base_fits(mask)
        result.update(base_v_left=fits[0]["slope"], base_v_right=fits[1]["slope"])
    result.update(density_metrics(image))
    return result


def silhouette_edge(mask: np.ndarray, clipped_border: bool = False) -> np.ndarray:
    # Match clean_outline.py exactly, including its clipped border neighbourhood.
    inner = mask.copy()
    inner[1:] &= mask[:-1]; inner[:-1] &= mask[1:]
    inner[:, 1:] &= mask[:, :-1]; inner[:, :-1] &= mask[:, 1:]
    if not clipped_border:
        inner[0] = False; inner[-1] = False; inner[:, 0] = False; inner[:, -1] = False
    return mask & ~inner


def edge_light_share(pixels: np.ndarray) -> float:
    edge = silhouette_edge(pixels[..., 3] > 0)
    luminance = (0.299 * pixels[..., 0] + 0.587 * pixels[..., 1] + 0.114 * pixels[..., 2]) / 255.0
    return float((edge & (luminance > 0.2)).sum() / max(1, edge.sum()))


# Exact prototype constants: changing them changes approved post-step pixels.
LAB_MATRIX = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
LAB_INVERSE = np.linalg.inv(LAB_MATRIX)
LAB_WHITE = np.array([0.95047, 1.0, 1.08883])
LEGACY_PALETTE_MATCH_PARAMETERS = {"space": "CIE Lab", "accent_percentile": 90, "accent_margin": 15,
                                   "std_floor": 1e-6, "green_residue_margin": 20}
ART07_V1_PALETTE_MATCH_PARAMETERS = {**LEGACY_PALETTE_MATCH_PARAMETERS,
                                     "accent_lightness": 80, "accent_hue_window_deg": 25}
PALETTE_MATCH_PARAMETERS = {**ART07_V1_PALETTE_MATCH_PARAMETERS,
                            "accent_hue_chroma_floor": 30, "accent_hue_bin_deg": 15,
                            "accent_hue_bin_min_share": 0.05, "max_protected_body_share": 0.25,
                            "exclude_green_from_protection": True, "allow_protected_share": False}
OUTLINE_PARAMETERS = {"tone": [20, 16, 21], "max_luminance": 0.2, "neighbours": 4,
                      "remove_isolated": True}


def to_lab(rgb: np.ndarray) -> np.ndarray:
    c = rgb / 255.0
    linear = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    xyz = linear @ LAB_MATRIX.T / LAB_WHITE
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def from_lab(lab: np.ndarray) -> np.ndarray:
    fy = (lab[..., 0] + 16) / 116
    f = np.stack([fy + lab[..., 1] / 500, fy, fy - lab[..., 2] / 200], -1)
    xyz = np.where(f > 6 / 29, f ** 3, 3 * (6 / 29) ** 2 * (f - 4 / 29)) * LAB_WHITE
    c = np.clip(xyz @ LAB_INVERSE.T, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055) * 255


def non_accent_mask(lab: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """One shared prototype mask for palette transfer and rear consistency."""
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    opaque = alpha > 0
    if not opaque.any():
        raise ValueError("non-accent measurement needs opaque pixels")
    return opaque & (chroma <= np.percentile(chroma[opaque], 90) + 15)


def non_accent_palette(path: Path) -> dict:
    pixels = np.asarray(rgba(path)).astype(float)
    mask = non_accent_mask(to_lab(pixels[..., :3]), pixels[..., 3])
    rgb = pixels[..., :3] / 255.0
    return {"chroma": float((rgb.max(-1) - rgb.min(-1))[mask].mean()),
            "value": float((rgb @ np.array([0.299, 0.587, 0.114]))[mask].mean())}


def palette_accent_protection(lab: np.ndarray, reference_hues: np.ndarray, parameters: dict) -> np.ndarray:
    """Unbounded v1 mask; current matching additionally gates these hits by chroma and green."""
    protected = lab[..., 0] >= parameters["accent_lightness"]
    if reference_hues.size:
        hues = np.unique(reference_hues % 360)
        circular = np.concatenate((hues[-1:] - 360, hues, hues[:1] + 360))
        hue = np.degrees(np.arctan2(lab[..., 2], lab[..., 1])) % 360
        right = np.searchsorted(circular, hue)
        distance = np.minimum(circular[right] - hue, hue - circular[right - 1])
        protected |= distance <= parameters["accent_hue_window_deg"]
    return protected


def valid_palette_parameters(parameters: dict) -> bool:
    if parameters in (LEGACY_PALETTE_MATCH_PARAMETERS, ART07_V1_PALETTE_MATCH_PARAMETERS):
        return True
    return (isinstance(parameters, dict) and type(parameters.get("allow_protected_share")) is bool
            and parameters == dict(PALETTE_MATCH_PARAMETERS, allow_protected_share=parameters["allow_protected_share"]))


def dominant_accent_hues(lab: np.ndarray, accents: np.ndarray, parameters: dict) -> np.ndarray:
    """Use centres of occupied 15-degree bins, weighted by reference accent pixel count."""
    hue = np.degrees(np.arctan2(lab[..., 2][accents], lab[..., 1][accents])) % 360
    if not hue.size:
        return np.array([], dtype=float)
    width = parameters["accent_hue_bin_deg"]
    counts = np.bincount(np.floor(hue / width).astype(int), minlength=round(360 / width))
    dominant = (counts > 0) & (counts / hue.size >= parameters["accent_hue_bin_min_share"])
    return (np.flatnonzero(dominant) + 0.5) * width


def bounded_accent_protection(rgb: np.ndarray, lab: np.ndarray, opaque: np.ndarray,
                              reference_hues: np.ndarray, parameters: dict) -> np.ndarray:
    chroma = np.hypot(lab[..., 1], lab[..., 2])
    floor = max(float(np.percentile(chroma[opaque], parameters["accent_percentile"])),
                parameters["accent_hue_chroma_floor"])
    light = lab[..., 0] >= parameters["accent_lightness"]
    hue = palette_accent_protection(lab, reference_hues, parameters) & (chroma >= floor)
    green = (rgb[..., 1] > rgb[..., 0]) & (rgb[..., 1] > rgb[..., 2])
    return opaque & (light | hue) & ~green


def palette_body_masks(front: np.ndarray, rear: np.ndarray, parameters: dict) -> tuple:
    """Return Lab values, transfer masks, protection and auditable original-body coverage."""
    Fl, Rl = to_lab(front[..., :3]), to_lab(rear[..., :3])
    fm, rm = non_accent_mask(Fl, front[..., 3]), non_accent_mask(Rl, rear[..., 3])
    original = (fm.copy(), rm.copy())
    protected = np.zeros(rm.shape, dtype=bool)
    shares = {"front": 0.0, "rear": 0.0}
    if "accent_lightness" in parameters:
        accents = (front[..., 3] > 0) & ~fm
        if "accent_hue_bin_deg" in parameters:
            reference_hues = dominant_accent_hues(Fl, accents, parameters)
            front_protected = bounded_accent_protection(front[..., :3], Fl, front[..., 3] > 0, reference_hues, parameters)
            protected = bounded_accent_protection(rear[..., :3], Rl, rear[..., 3] > 0, reference_hues, parameters)
        else:
            reference_hues = np.degrees(np.arctan2(Fl[..., 2][accents], Fl[..., 1][accents]))
            front_protected = palette_accent_protection(Fl, reference_hues, parameters)
            protected = palette_accent_protection(Rl, reference_hues, parameters)
        fm &= ~front_protected
        rm &= ~protected
        shares = {"front": float((original[0] & front_protected).sum() / max(1, original[0].sum())),
                  "rear": float((original[1] & protected).sum() / max(1, original[1].sum()))}
    return Fl, Rl, fm, rm, protected, shares


def palette_match(front: Image.Image, rear: Image.Image, parameters: dict = None, report: dict = None) -> Image.Image:
    parameters = PALETTE_MATCH_PARAMETERS if parameters is None else parameters
    if not valid_palette_parameters(parameters):
        raise ValueError("unsupported palette_match parameters")
    F, R = np.asarray(front.convert("RGBA")).astype(float), np.asarray(rear.convert("RGBA")).astype(float)
    for label, pixels, reason in (("front", F, "empty reference"), ("rear", R, "empty rear")):
        if not (pixels[..., 3] > 0).any():
            if not parameters.get("allow_protected_share", False):
                raise ValueError("palette_match %s body is empty (no opaque samples); pass --allow-protected-share to override" % label)
            if report is not None:
                # No body statistics were measured: null is distinct from a measured zero protected share.
                report.update(kind="palette_match", skipped=reason, protected_share=None, protected_body_share=None)
            return rear.convert("RGBA").copy()
    Fl, Rl, fm, rm, protected, shares = palette_body_masks(F, R, parameters)
    if report is not None:
        report.update(protected_body_share=shares)
    if "max_protected_body_share" in parameters:
        if not parameters["allow_protected_share"]:
            for label, mask in (("front", fm), ("rear", rm)):
                if not mask.any() or shares[label] > parameters["max_protected_body_share"]:
                    raise ValueError("palette_match %s body: %.1f%% protected%s; pass --allow-protected-share to override" %
                                     (label, shares[label] * 100, "; body is empty" if not mask.any() else ""))
        if not fm.any() or not rm.any():
            # The director's explicit override skips this step; retain its reason and coverage for replay.
            if report is not None:
                report.update(kind="palette_match", skipped="empty body", protected_share=shares)
            return rear.convert("RGBA").copy()
    elif "accent_lightness" in parameters:
        # Historical v1 replay only; current processing must never silently skip the transfer.
        if not fm.any() or not rm.any():
            return rear.convert("RGBA").copy()
    res = Rl.copy()
    for ch in range(3):
        mu_f, sd_f = Fl[..., ch][fm].mean(), Fl[..., ch][fm].std()
        mu_r, sd_r = Rl[..., ch][rm].mean(), Rl[..., ch][rm].std()
        res[..., ch] = np.where(rm, (Rl[..., ch] - mu_r) * (sd_f / max(sd_r, parameters["std_floor"])) + mu_f, Rl[..., ch])
    rgb = np.clip(np.rint(from_lab(res)), 0, 255)
    rgb = np.where((R[..., 3:] > 0) & rm[..., None], rgb, R[..., :3])
    margin = parameters["green_residue_margin"]
    green = (rgb[..., 1] > rgb[..., 0] + margin) & (rgb[..., 1] > rgb[..., 2] + margin) & (R[..., 3] > 0) & ~rm & ~protected
    rgb[green] = np.stack([rgb[green][:, [0, 2]].max(-1)] * 3, -1)
    return Image.fromarray(np.dstack([rgb, R[..., 3]]).astype(np.uint8))


def clean_outline(image: Image.Image) -> Image.Image:
    a = np.asarray(image.convert("RGBA")).copy()
    mask = a[..., 3] > 0
    neighbours = np.zeros_like(mask, dtype=int)
    neighbours[1:] += mask[:-1]; neighbours[:-1] += mask[1:]
    neighbours[:, 1:] += mask[:, :-1]; neighbours[:, :-1] += mask[:, 1:]
    a[mask & (neighbours == 0), 3] = 0
    edge = silhouette_edge(a[..., 3] > 0, clipped_border=True)
    luminance = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255.0
    a[edge & (luminance > 0.2), :3] = (20, 16, 21)
    return Image.fromarray(a)


def region_mask(rgb: np.ndarray, region: dict) -> np.ndarray:
    """Director prototype semantics, including hue wrap and the eight-way flood fill."""
    for key in ("min_lum", "max_lum", "min_chroma", "max_chroma", "max_value"):
        if key in region:
            limit = region[key]
            if type(limit) not in (int, float) or not math.isfinite(limit) or not 0 <= limit <= 1:
                raise ValueError(key + " must be a finite number in 0..1")
    for lower, upper in (("min_lum", "max_lum"), ("min_chroma", "max_chroma")):
        if region.get(lower, 0.0) > region.get(upper, 1.0):
            raise ValueError(lower + " must not exceed " + upper)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    chroma = (rgb.max(-1) - rgb.min(-1)) / 255.0
    candidate = np.zeros(lum.shape, bool)
    x0, y0, x1, y1 = region["box"]
    candidate[y0:y1, x0:x1] = True
    candidate &= (lum >= region.get("min_lum", 0.0)) & (lum <= region.get("max_lum", 1.0))
    candidate &= chroma >= region.get("min_chroma", 0.0)
    for key, values in (("max_chroma", chroma), ("max_value", rgb.max(-1) / 255.0)):
        if key in region:
            candidate &= values <= region[key]
    if region.get("hue_deg"):
        hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
        lo, hi = region["hue_deg"]
        candidate &= ((hue >= lo) & (hue <= hi)) if lo <= hi else ((hue >= lo) | (hue <= hi))
    if region.get("exclude_green", True):
        candidate &= ~((g > 200) & (r < 80) & (b < 80))
    if region.get("seed") is None:
        return candidate
    sx, sy = region["seed"]
    mask = np.zeros_like(candidate)
    mask[sy, sx] = candidate[sy, sx]
    if not mask.any():
        raise ValueError(f"{region['name']}: seed {region['seed']} is not a matching pixel")
    while True:
        grown = mask.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                grown |= np.roll(np.roll(mask, dy, 0), dx, 1)
        grown &= candidate
        if (grown == mask).all():
            return mask
        mask = grown


def tone_region(image: Image.Image, regions: list, report=None) -> Image.Image:
    pixels = np.asarray(image.convert("RGBA")).astype(float)
    for region in regions:
        rgb = pixels[..., :3]
        mask = region_mask(rgb, region)
        lab = to_lab(rgb[mask]) * np.array(region["lab_scale"])
        rgb[mask] = np.clip(np.rint(from_lab(lab)), 0, 255)
        pixels[..., :3] = rgb
        if report:
            report(f"{region['name']}: {int(mask.sum())} pixels toned")
    return Image.fromarray(pixels.astype(np.uint8))


def mask_reference(image: Image.Image, regions: list, report=None) -> Image.Image:
    pixels = np.asarray(image.convert("RGBA")).copy()
    rgb = pixels[..., :3].astype(float)
    for region in regions:
        hit = region_mask(rgb, region) & (pixels[..., 3] > 0)
        pixels[hit, 3] = 0
        if report:
            report(f"{region['name']}: {int(hit.sum())} pixels excluded")
    return Image.fromarray(pixels)


def composite_region(approved: Image.Image, edit: Image.Image, box: list) -> Image.Image:
    # The original director script intentionally discards alpha before resizing/pasting.
    result, edit = approved.convert("RGB"), edit.convert("RGB")
    if edit.size != result.size:
        edit = edit.resize(result.size, RESAMPLE.LANCZOS)
    result.paste(edit.crop(tuple(box)), tuple(box[:2]))
    return result


def recipe_input_path(path: str, kit_path: Path, label: str, maquette: bool = False) -> Path:
    """Constrain the resolved file, including symlinks, to the job's allowed input folders."""
    if not isinstance(path, str) or not path:
        raise ValueError(label + " input path missing")
    resolved = repo_path(kit_path.parent, path)
    if maquette and not any((kit_path.parent / folder).resolve() in resolved.parents
                            for folder in ("refs", "raw_inputs")):
        raise ValueError(label + " maquette input must be inside refs/ or raw_inputs/")
    return resolved


def recipe_input(binding: dict, kit_path: Path, label: str, maquette: bool = False,
                 allow_missing: bool = False, record: bool = False, input_changes: list = None):
    """All recipe paths are job-relative; hashes bind file bytes, not just decoded pixels."""
    if not isinstance(binding, dict) or (not record and not is_digest(binding.get("sha256"))):
        raise ValueError(label + " input sha256 missing or invalid")
    path = binding.get("path")
    resolved = recipe_input_path(path, kit_path, label, maquette)
    if not resolved.is_file():
        if allow_missing and not maquette:
            return None
        raise ValueError(label + " input missing: " + path)
    data = resolved.read_bytes()
    if record:
        old_digest = binding.get("sha256")
        binding["sha256"] = sha(data)
        if input_changes is not None and is_digest(old_digest) and old_digest != binding["sha256"]:
            input_changes.append("INPUT CHANGED %s %s->%s" % (path, old_digest, binding["sha256"]))
    elif sha(data) != binding["sha256"]:
        raise ValueError(label + " input sha256 changed: " + path)
    return data


def replay_raw_steps(kit_path: Path, allow_missing: bool = False):
    """Bind director files by bytes and gate outputs by decoded pixels, entirely in memory."""
    return raw_steps_image(read_json(kit_path), kit_path, allow_missing=allow_missing)


def raw_steps_image(kit: dict, kit_path: Path, allow_missing: bool = False, record: bool = False,
                    input_changes: list = None):
    """Share execution and validation between read-only replay and digest recording."""
    steps = kit.get("raw_steps")
    if not isinstance(steps, list) or not steps:
        raise ValueError("raw_steps must be a non-empty ordered list")
    inputs, previous_digest = [], None
    for index, step in enumerate(steps):
        label = "raw_steps[%d]" % index
        if not isinstance(step, dict):
            raise ValueError(label + " must be an object")
        kind, parameters, bindings = step["kind"], step["parameters"], step["inputs"]
        if not isinstance(parameters, dict) or not isinstance(bindings, dict):
            raise ValueError(label + " parameters and inputs must be objects")
        if kind == "composite_region":
            box = parameters.get("box")
            if (set(parameters) != {"box", "resample"} or parameters["resample"] != "LANCZOS"
                    or not isinstance(box, list) or len(box) != 4
                    or any(type(v) is not int for v in box) or not (0 <= box[0] < box[2] and 0 <= box[1] < box[3])):
                raise ValueError(label + " invalid composite_region parameters")
            expected = {"raw", "edit"}
        elif kind == "tone_region":
            if parameters != {"space": "CIE Lab"}:
                raise ValueError(label + " invalid tone_region parameters")
            expected = {"raw", "config"}
        else:
            raise ValueError(label + " unknown kind: " + str(kind))
        if set(bindings) != expected:
            raise ValueError(label + " input kinds mismatched")
        if index:
            previous = bindings["raw"]
            if record:
                if not isinstance(previous, dict) or not (set(previous) == {"previous_output_pixel_sha256"}
                                                         or "path" in previous):
                    raise ValueError(label + " raw input must name a file or the previous output pixels")
            elif previous != {"previous_output_pixel_sha256": previous_digest}:
                raise ValueError(label + " raw input does not bind the previous output pixels")
        data = {name: recipe_input(binding, kit_path, label + "." + name,
                                  kit.get("kit_kind") == "maquette", allow_missing, record, input_changes)
                for name, binding in bindings.items()
                if name != "raw" or not index or (record and "path" in binding)}
        previous_digest = step.get("output_raw_pixel_sha256")
        if not record and (not is_digest(previous_digest) or "output_raw_sha256" in step):
            raise ValueError(label + " requires output_raw_pixel_sha256 (re-record legacy byte digests)")
        inputs.append(data)
    # Missing standard-kit inputs may prevent replay, but never suppress validation of present files.
    if any(value is None for data in inputs for value in data.values()):
        return None
    output = None
    for index, (step, data) in enumerate(zip(steps, inputs)):
        raw = rgba(io.BytesIO(data["raw"])) if output is None else output
        if record and index:
            if "raw" in data and pixel_digest(rgba(io.BytesIO(data["raw"]))) != pixel_digest(raw):
                raise ValueError("raw_steps[%d] legacy raw input differs from previous output pixels" % index)
            step["inputs"]["raw"] = {"previous_output_pixel_sha256": pixel_digest(raw)}
        if step["kind"] == "composite_region":
            box = step["parameters"]["box"]
            if box[2] > raw.width or box[3] > raw.height:
                raise ValueError("composite_region box exceeds approved raw")
            result = composite_region(raw, rgba(io.BytesIO(data["edit"])), box)
        else:
            result = tone_region(raw, json.loads(data["config"]))
        output = result.convert("RGBA")
        if record:
            step["output_raw_pixel_sha256"] = pixel_digest(output)
            step.pop("output_raw_sha256", None)
        elif pixel_digest(output) != step["output_raw_pixel_sha256"]:
            raise ValueError("raw_steps[%d] output_raw_pixel_sha256 changed" % index)
    return output


def front_job_reference(front: dict, kit: dict, kit_path: Path, root: Path, record: bool = False) -> Image.Image:
    if (not isinstance(front, dict) or not isinstance(front.get("job_path"), str) or not front["job_path"]
            or set(front) - {"job_path", "pixel_sha256"}
            or (not record and not is_digest(front.get("pixel_sha256")))):
        raise ValueError("match_reference front requires job_path and pixel_sha256")
    front_kit = repo_path(root, front["job_path"])
    jobs = (root / IDENTITY / "jobs").resolve()
    if jobs not in front_kit.parents:
        raise ValueError("match_reference job_path must be inside spec/art_identity/jobs/")
    path_error = "match_reference job_path must be <id>/<job>/kit.json inside spec/art_identity/jobs/"
    try:
        declared = Path(front["job_path"].removeprefix("res://")).relative_to(IDENTITY / "jobs")
    except ValueError:
        raise ValueError(path_error) from None
    for relative in (declared, front_kit.relative_to(jobs)):
        if len(relative.parts) != 3 or relative.parts[0] != kit.get("id") or relative.name != "kit.json":
            raise ValueError(path_error)
    if front_kit == kit_path.resolve():
        raise ValueError("match_reference front job must not be the referencing kit itself")
    front_metadata = read_json(front_kit)
    if not isinstance(front_metadata, dict):
        raise ValueError("match_reference front kit.json must be an object")
    view = front_metadata.get("view")
    if not isinstance(view, str) or not view.endswith("_front"):
        raise ValueError("match_reference must name a front job kit.json")
    if not isinstance(kit.get("id"), str) or not kit["id"] or front_metadata.get("id") != kit["id"]:
        raise ValueError("match_reference front job id must match the referencing kit id")
    image = rgba(repo_path(front_kit.parent, "processed.png"))
    digest = pixel_digest(image)
    if record:
        front["pixel_sha256"] = digest
    elif digest != front["pixel_sha256"]:
        raise ValueError("match_reference front job processed pixel digest changed")
    return image


def derive_match_reference(spec: dict, kit_path: Path, root: Path = ROOT, record: bool = False,
                           input_changes: list = None) -> tuple:
    """Bind processed references by pixels; plain and masked references can name a front job."""
    kit = read_json(kit_path)
    maquette = kit.get("kit_kind") == "maquette"
    if not isinstance(spec, dict):
        raise ValueError("match_reference must be an object")
    if (set(spec) == {"path", "pixel_sha256"}
            or (record and "path" in spec and not set(spec) - {"path", "pixel_sha256", "sha256"})):
        path = recipe_input_path(spec["path"], kit_path, "match_reference", maquette)
        # A legacy local reference may still have a director-recorded file digest to audit.
        data = (recipe_input(spec, kit_path, "match_reference", maquette, record=True, input_changes=input_changes)
                if record and "sha256" in spec else None)
        image = rgba(io.BytesIO(data) if data is not None else path)
        if record:
            spec["pixel_sha256"] = pixel_digest(image)
            spec.pop("sha256", None)
        elif pixel_digest(image) != spec["pixel_sha256"]:
            raise ValueError("match_reference pixel digest changed")
    elif "job_path" in spec:
        image = front_job_reference(spec, kit, kit_path, root, record)
    elif set(spec) == {"derived_from", "mask_config"}:
        front_image = front_job_reference(spec["derived_from"], kit, kit_path, root, record)
        config = recipe_input(spec["mask_config"], kit_path, "match_reference.mask_config", maquette,
                              record=record, input_changes=input_changes)
        image = mask_reference(front_image, json.loads(config))
    else:
        raise ValueError("match_reference requires a processed front or derived_from and mask_config")
    return image, {"match_reference": spec, "reference_pixel_sha256": pixel_digest(image)}


def record_steps(kit_path: Path, root: Path = ROOT) -> list:
    """Rebind listed recipe inputs/outputs; write only after the entire recipe succeeds."""
    original = kit_path.read_text(encoding="utf-8")
    kit = json.loads(original)
    input_changes = []
    raw_steps_image(kit, kit_path, record=True, input_changes=input_changes)
    if "match_reference" in kit:
        derive_match_reference(kit["match_reference"], kit_path, root, record=True, input_changes=input_changes)
    if kit == json.loads(original):
        return ["UNCHANGED " + str(kit_path)]
    updated = json.dumps(kit, indent=2, sort_keys=True, allow_nan=False) + "\n"
    changes = list(difflib.unified_diff(original.splitlines(), updated.splitlines(),
                                      fromfile=str(kit_path), tofile=str(kit_path) + " (recorded)", lineterm=""))
    kit_path.write_bytes(updated.encode("utf-8"))
    return input_changes + changes


def direct_match_path(path: Path, kit_path: Path, root: Path) -> Path:
    """Legacy direct PNG arguments are repository-relative, and maquettes keep them job-local."""
    reference = repo_path(root, str(path))
    if read_json(kit_path).get("kit_kind") == "maquette" and kit_path.parent.resolve() not in reference.parents:
        raise ValueError("--match-front PNG must be inside the maquette job folder")
    return reference


def rear_consistency(front: Path, rear: Path) -> dict:
    a, b = non_accent_palette(front), non_accent_palette(rear)
    return {"chroma_delta": abs(a["chroma"] - b["chroma"]), "value_delta": abs(a["value"] - b["value"])}


def view_body(root: Path, view: str) -> bytes:
    contents = (root / IDENTITY / "views.md").read_bytes()
    marker = ("## " + view + "\n").encode("utf-8")
    if marker not in contents:
        raise ValueError("missing director view section: " + view)
    return contents.split(marker, 1)[1].split(b"\n## ", 1)[0]


def kit_version(root: Path, view: str, digests: list) -> str:
    return sha((root / IDENTITY / "preamble.md").read_bytes() + view_body(root, view)
               + "".join(sorted(digests)).encode("ascii"))


def prompt_kit_version(kit: dict, prompt: bytes):
    """Reconstruct the generation hash using only the job's captured inputs.

    Generation hashes the preamble before {K} substitution, the view clause,
    and sorted reference digests. Undo that substitution in its known contexts;
    never read today's preamble/views or regenerable reference PNGs. Historical
    custom prompts may not retain this exact serialization: for those the
    prompt hash and registry bindings still verify the recorded version field.
    Maquette jobs instead hash the whole captured prompt and ordered digests.
    """
    if kit.get("kit_kind") == "maquette":
        digests = "".join(ref["pixel_sha256"] for ref in kit["refs"]).encode("ascii")
        return sha(prompt + digests)
    preamble, view_marker, remainder = prompt.partition(b"\n## View\n")
    view, subject_marker, _ = remainder.partition(b"\n## Subject")
    if not view_marker or not subject_marker:
        return None
    factor = str(kit["K"]).encode("ascii")
    # Numeric boundaries preserve the literal 1024x1024 canvas dimensions.
    pattern = rb"(?<![0-9])" + factor + rb"(?=x|-pixel| pixels)|(?<=x)" + factor + rb"(?= block)"
    preamble = re.sub(pattern, b"{K}", preamble)
    digests = "".join(sorted(ref["pixel_sha256"] for ref in kit["refs"])).encode("ascii")
    return sha(preamble + view + digests)


def recorded_ref_digests(kit: dict) -> dict:
    return {ref["file"]: ref["pixel_sha256"] for ref in kit["refs"]}


def kit_version_verification(kit: dict, prompt: bytes) -> str:
    if kit.get("kit_kind") == "maquette":
        return "prompt_ordered_refs" if prompt_kit_version(kit, prompt) == kit["kit_version"] else "mismatched"
    return "prompt_reconstructed" if prompt_kit_version(kit, prompt) == kit["kit_version"] else "recorded"


def canon_entries(root: Path, include_retired: bool = False) -> dict:
    """Active canon (allowed as references for new kits); with include_retired, also entries retired after the
    art they appear in was generated, so historical kit provenance stays verifiable."""
    data = read_json(root / IDENTITY / "canon.json")
    entries = data["entries"] + (data.get("retired", []) if include_retired else [])
    return {entry["id"]: entry for entry in entries}


def matching_view(canon: dict, entry: dict, rear: bool) -> dict:
    desired = "rear" if rear else "front"
    if entry["view"] == desired:
        return entry
    suffix = "_" + entry["view"]
    stem = entry["id"][:-len(suffix)] if entry["id"].endswith(suffix) else entry["id"]
    matched = canon.get(stem + "_" + desired)
    if matched is None or matched["kind"] != entry["kind"]:
        raise ValueError("canon has no matching " + desired + " reference for " + entry["id"])
    return matched


def enlarged_ref(path: Path, factor: int) -> Image.Image:
    image = rgba(path)
    crop = image.crop(alpha_bbox(image))
    crop = crop.resize((crop.width * factor, crop.height * factor), RESAMPLE.NEAREST)
    canvas = Image.new("RGBA", (max(1024, crop.width + 64), max(1024, crop.height + 64)), "#00ff00")
    canvas.alpha_composite(crop, ((canvas.width - crop.width) // 2, (canvas.height - crop.height) // 2))
    return canvas


def footprint_guide(factor: int) -> Image.Image:
    image = Image.new("RGBA", (1024, 1024), "#00ff00")
    draw = ImageDraw.Draw(image)
    width = 0.8 * 248 * factor
    bottom = (512, 960)
    left, right = (512 - width / 2, 960 - width / 4), (512 + width / 2, 960 - width / 4)
    top = (512, 960 - width / 2)
    draw.line([left, top, right, bottom, left], fill="#282828", width=6)
    for x, y in (left, right):
        draw.line([(x, y), (x, y - 640)], fill="#5a5a5a", width=3)
    return image


def make_kit(args: argparse.Namespace, root: Path = ROOT) -> dict:
    if not args.id or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in args.id):
        raise ValueError("id must contain only letters, digits, underscores and hyphens")
    canon = canon_entries(root)
    kind = "object" if args.view == "object_plinth" else "creature"
    rear = args.view.endswith("_rear")
    if rear and not args.front_ref:
        raise ValueError("rear views require --front-ref")
    peers = []
    for peer_id in args.peers:
        if peer_id not in canon:
            raise ValueError("peer is not canon: " + peer_id)
        entry = canon[peer_id]
        if entry["kind"] != kind:
            raise ValueError("peer kind differs from candidate: " + peer_id)
        if entry["anatomy"] != args.anatomy:
            raise ValueError("peer anatomy differs from candidate: " + peer_id)
        peers.append(matching_view(canon, entry, rear))
    height = args.target_h if args.target_h is not None else DEFAULT_HEIGHTS[args.size_class]
    bands = read_json(root / IDENTITY / "bands.json")
    factors = [int(k) for k, interval in bands["kit_factor"].items() if interval[0] <= height <= interval[1]]
    if len(factors) != 1 or height <= 0 or (args.target_w is not None and args.target_w <= 0):
        raise ValueError("target size is outside the director kit-factor bands")
    factor = factors[0]
    subject_path = Path(args.subject)
    subject_rear = getattr(args, "subject_rear", None)
    if subject_rear is not None:
        if not rear:
            raise ValueError("--subject-rear requires a rear view")
        subject_path = Path(subject_rear)
    subject = subject_path.read_text(encoding="utf-8")
    out = Path(args.out_dir)
    refs_dir = out / "refs"
    if refs_dir.exists() and any(refs_dir.glob("*.png")):
        raise ValueError("refs directory already contains PNGs; use a fresh output directory")
    refs_dir.mkdir(parents=True, exist_ok=True)
    references = []
    if rear:
        target = refs_dir / "01_front_ref.png"
        shutil.copyfile(args.front_ref, target)
        references.append({"file": "refs/01_front_ref.png", "pixel_sha256": pixel_digest(rgba(target))})
    hero = canon["hero_rear" if rear else "hero_front"]
    for index, entry in enumerate([hero] + peers, 2 if rear else 1):
        name = "%02d_%s.png" % (index, entry["id"])
        reference = enlarged_ref(repo_path(root, entry["path"]), factor)
        reference.save(refs_dir / name)
        references.append({"file": "refs/" + name, "canon_id": entry["id"],
                           "pixel_sha256": pixel_digest(reference)})
    if kind == "object":
        reference = footprint_guide(factor)
        reference.save(refs_dir / "footprint_guide.png")
        references.append({"file": "refs/footprint_guide.png", "pixel_sha256": pixel_digest(reference)})
    preamble = (root / IDENTITY / "preamble.md").read_text(encoding="utf-8").replace("{K}", str(factor))
    body = view_body(root, args.view).decode("utf-8")
    width_text = ", %s pixels wide" % (args.target_w * factor) if args.target_w is not None else ""
    size = ("The whole subject is about %s pixels tall (%s game pixels)%s and centred horizontally, "
            "its lowest point about 60 pixels above the bottom edge. It is shown at its natural size, not a miniature."
            % (height * factor, height, width_text))
    subject_heading = "\n## Subject\n" if subject_rear is None else "\n## Subject (rear: %s)\n" % subject_rear
    prompt = preamble + "\n## View\n" + body + subject_heading + subject + "\n## Size\n" + size + "\n"
    (out / "prompt.md").write_bytes(prompt.encode("utf-8"))
    kit = {"id": args.id, "job_id": "id-%s-%s" % (args.id, args.view), "view": args.view,
           "kind": kind, "anatomy": args.anatomy, "size_class": args.size_class, "K": factor,
           "target_h": height, "target_w": args.target_w, "peers": list(args.peers), "refs": references,
           "prompt_path": "prompt.md", "prompt_sha256": sha(prompt.encode("utf-8")),
           "kit_version": kit_version(root, args.view, [ref["pixel_sha256"] for ref in references])}
    if subject_rear is not None:
        kit["subject_rear"] = str(subject_rear)
        kit["subject_rear_sha256"] = sha(subject_path.read_bytes())
    write_json(out / "kit.json", kit)
    return kit


def box_binary_sprite(rgb: np.ndarray, alpha: np.ndarray, size: tuple) -> Image.Image:
    """BOX-resize floating premultiplied channels, then unpremultiply/binarize."""
    def box(channel: np.ndarray) -> np.ndarray:
        image = Image.fromarray(channel.astype(np.float32))
        return np.asarray(image.resize(size, RESAMPLE.BOX), dtype=float)
    reduced_alpha = box(alpha)
    premultiplied = np.stack([box(rgb[..., channel] * alpha) for channel in range(3)], axis=-1)
    reduced_rgb = premultiplied / np.maximum(reduced_alpha[..., None], 1e-6)
    pixels = np.dstack((np.clip(np.rint(reduced_rgb), 0, 255), (reduced_alpha >= 0.5) * 255)).astype(np.uint8)
    return Image.fromarray(pixels)


def fit_sprite(sprite: Image.Image) -> tuple:
    """Uniformly fit all paint inside the authored limits without clipping it."""
    fit_scale = min(1.0, PROCESSED_FIT_SIZE[0] / sprite.width, PROCESSED_FIT_SIZE[1] / sprite.height)
    if fit_scale < 1.0:
        size = (max(1, round(sprite.width * fit_scale)), max(1, round(sprite.height * fit_scale)))
        pixels = np.asarray(sprite, dtype=float)
        sprite = box_binary_sprite(pixels[..., :3], pixels[..., 3] / 255, size)
    return sprite, fit_scale


def processing_palette_parameters(kit_path: Path, selection=None, allow_protected_share=None) -> dict:
    """A kit's recorded processing parameters take precedence over today's defaults."""
    if selection is None:
        sidecar = kit_path.parent / "processed.json"
        if sidecar.is_file():
            processed = read_json(sidecar)
            if not isinstance(processed, dict) or not isinstance(processed.get("post_steps", []), list):
                raise ValueError("recorded processed.json must contain an object with post_steps")
            steps = [step for step in processed.get("post_steps", [])
                     if isinstance(step, dict) and step.get("step") == "palette_match"]
            if steps:
                if len(steps) != 1 or not valid_palette_parameters(steps[0].get("parameters")):
                    raise ValueError("recorded palette_match parameters are missing or unsupported; choose --palette-parameters legacy or current explicitly")
                selection = steps[0]["parameters"]
        if selection is None:
            selection = PALETTE_MATCH_PARAMETERS
    elif isinstance(selection, str):
        if selection not in ("current", "legacy"):
            raise ValueError("palette parameters must be current or legacy")
        selection = PALETTE_MATCH_PARAMETERS if selection == "current" else LEGACY_PALETTE_MATCH_PARAMETERS
    if not valid_palette_parameters(selection):
        raise ValueError("unsupported palette_match parameters")
    parameters = dict(selection)
    if allow_protected_share is not None:
        if type(allow_protected_share) is not bool or "allow_protected_share" not in parameters:
            raise ValueError("--allow-protected-share requires current palette parameters")
        parameters["allow_protected_share"] = allow_protected_share
    return parameters


def process_raw(raw: Path, kit_path: Path, out: Path, root: Path = ROOT, match_front: Path = None,
                outline: bool = False, palette_parameters=None, allow_protected_share=None) -> dict:
    kit = read_json(kit_path)
    factor = kit["K"]
    if not isinstance(factor, int) or isinstance(factor, bool) or factor <= 0:
        raise ValueError("K must be a positive integer")
    if "raw_steps" in kit:
        image = replay_raw_steps(kit_path)
        raw_binding = {"raw_pixel_sha256": pixel_digest(image)}
        if raw is not None and sha(raw.read_bytes()) != kit["raw_steps"][0]["inputs"]["raw"]["sha256"]:
            raise ValueError("supplied raw differs from the first raw_steps input")
    elif raw is not None:
        raw_bytes = raw.read_bytes()
        image = rgba(io.BytesIO(raw_bytes))
        raw_binding = {"raw_sha256": sha(raw_bytes)}
    else:
        raise ValueError("process requires RAW or a kit with raw_steps")
    if image.width != image.height:
        raise ValueError("raw image must be square")
    k_eff = factor * image.width / RAW_CANVAS_WIDTH
    pixels = np.asarray(image.convert("RGB"), dtype=float)
    distance = np.abs(pixels - np.array([0, 255, 0])).max(-1)
    alpha = np.clip((distance - 40) / 40, 0, 1)
    # Despill partial-key pixels and a ring of ceil(k_eff) + 1 raw pixels (one output pixel and a margin) inside the
    # silhouette: opaque outline pixels blended with the
    # green background otherwise survive binarization as a green fringe. Interior greens (moss, accents) are kept.
    background = alpha <= 0.5
    ring = background.copy()
    for _ in range(math.ceil(k_eff) + 1):
        grown = ring.copy()
        grown[1:] |= ring[:-1]; grown[:-1] |= ring[1:]; grown[:, 1:] |= ring[:, :-1]; grown[:, :-1] |= ring[:, 1:]
        ring = grown
    spill = (alpha < 1) | (ring & ~background)
    # Unmix the key from spill pixels: a bright edge blended with green would otherwise despill to an olive fringe.
    # The green fraction f lowers alpha (binarization drops mostly-green blends) and is removed from the colour.
    other = pixels[..., [0, 2]].max(-1)
    green_share = np.where(spill, np.clip((pixels[..., 1] - other) / np.maximum(255.0 - other, 1.0), 0, 0.95), 0.0)
    alpha = np.minimum(alpha, 1.0 - green_share)
    pixels = (pixels - green_share[..., None] * np.array([0.0, 255.0, 0.0])) / (1.0 - green_share[..., None])
    pixels = np.clip(pixels, 0, 255)
    pixels[..., 1] = np.where(spill, np.minimum(pixels[..., 1], pixels[..., [0, 2]].max(-1)), pixels[..., 1])
    ys, xs = np.nonzero(alpha > 0.5)
    if not len(xs):
        raise ValueError("green-keyed raw has no subject")
    left, bottom = int(xs.min()), int(ys.max()) + 1
    # A non-integer block multiple may fall between raw pixels. Round the pad
    # outward, retaining the prototype's bottom-left anchor and all subject paint.
    height = math.ceil(math.ceil((bottom - int(ys.min())) / k_eff) * k_eff)
    width = math.ceil(math.ceil((int(xs.max()) + 1 - left) / k_eff) * k_eff)
    top = bottom - height
    a = np.zeros((height, width))
    rgb = np.zeros((height, width, 3))
    sub = alpha[max(0, top):bottom, left:left + width]
    a[height - sub.shape[0]:, :sub.shape[1]] = sub
    rgb[height - sub.shape[0]:, :sub.shape[1]] = pixels[max(0, top):bottom, left:left + width]
    sprite = box_binary_sprite(rgb, a, (max(1, round(width / k_eff)), max(1, round(height / k_eff))))
    sprite = sprite.crop(alpha_bbox(sprite))
    sprite, fit_scale = fit_sprite(sprite)
    # Binarization can empty an outside row. Trim only transparent padding so
    # registration follows the final painted bbox; never clip surviving paint.
    sprite = sprite.crop(alpha_bbox(sprite))
    placement = read_json(root / IDENTITY / "bands.json")["canvas"]
    size = placement["size"]
    x, y = placement["center_x"] - sprite.width // 2, placement["bottom_y"] - sprite.height
    if x < 0 or y < 0 or sprite.width > size or sprite.height > size:
        raise ValueError("director fit limits disagree with canvas placement")
    placed_x, placed_y = min(x, size - sprite.width), min(y, size - sprite.height)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(sprite, (placed_x, placed_y))
    post_steps = []
    if match_front is not None or "match_reference" in kit:
        direct_path = (direct_match_path(match_front, kit_path, root)
                       if match_front is not None and match_front.suffix.lower() != ".json" else None)
        if "match_reference" in kit:
            if match_front is not None:
                supplied = (read_json(match_front) if match_front.suffix.lower() == ".json" else
                            {"path": kit["match_reference"].get("path"), "pixel_sha256": pixel_digest(rgba(direct_path))})
                if supplied != kit["match_reference"]:
                    raise ValueError("explicit --match-front conflicts with kit match_reference")
            reference, binding = derive_match_reference(kit["match_reference"], kit_path, root)
        elif match_front.suffix.lower() == ".json":
            spec = read_json(match_front)
            # The descriptor is job-relative, just like the kit field; it is not another job.
            reference, binding = derive_match_reference(spec, kit_path, root)
        else:
            reference = rgba(direct_path)
            binding = {"reference": str(match_front), "reference_pixel_sha256": pixel_digest(reference)}
        parameters = processing_palette_parameters(kit_path, palette_parameters, allow_protected_share)
        step = {"step": "palette_match", "parameters": parameters, **binding,
                "pre_step_pixel_sha256": pixel_digest(canvas)}
        coverage = {}
        canvas = palette_match(reference, canvas, parameters, report=coverage)
        if "max_protected_body_share" in parameters:
            step.update(coverage)
        post_steps.append(step)
    if outline:
        post_steps.append({"step": "clean_outline", "parameters": OUTLINE_PARAMETERS,
                           "pre_step_pixel_sha256": pixel_digest(canvas)})
        canvas = clean_outline(canvas)
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    record = {**raw_binding, "pixel_sha256": pixel_digest(canvas), "K": factor,
              "k_eff": k_eff, "fit_scale": fit_scale,
              "drawn_size": list(sprite.size), "placement": [placed_x, placed_y],
              "shift": [placed_x - x, placed_y - y],
              "metrics": measure(out, kind=kit.get("kind", "creature"), anatomy=kit.get("anatomy", ""))}
    if post_steps:
        record["post_steps"] = post_steps
    if "raw_steps" in kit:
        record["raw_steps"] = kit["raw_steps"]
    write_json(out.with_suffix(".json"), record)
    return record


def validate_palette_skip(step: dict) -> None:
    """Validate explicit skip records even when archived raw inputs cannot be replayed."""
    if not any(key in step for key in ("kind", "skipped", "protected_share")):
        return
    parameters, shares, reason = step.get("parameters"), step.get("protected_share"), step.get("skipped")
    empty_samples = reason in ("empty reference", "empty rear")
    valid_shares = (("protected_share" in step and "protected_body_share" in step
                     and shares is None and step["protected_body_share"] is None) if empty_samples else
                    (reason == "empty body" and isinstance(shares, dict) and set(shares) == {"front", "rear"}
                     and all(in_band(value, (0.0, 1.0)) for value in shares.values())
                     and shares == step.get("protected_body_share") and 1.0 in shares.values()))
    if (not valid_palette_parameters(parameters) or parameters.get("allow_protected_share") is not True
            or step.get("kind") != "palette_match" or not valid_shares):
        raise ValueError("palette_match empty-body skip record invalid")


def verify_job_recipe(kit_path: Path, root: Path = ROOT, require_inputs: bool = False) -> list:
    """Read-only certification shared by registry checks and unregistered-job proof."""
    kit = read_json(kit_path)
    source = kit_path.parent / "processed.png"
    processed = read_json(source.with_suffix(".json"))
    steps = processed.get("post_steps", [])
    palette = [step for step in steps if step.get("step") == "palette_match"]
    if "raw_steps" in kit:
        if "raw_sha256" in processed:
            raise ValueError("processed raw_steps require raw_pixel_sha256, not raw_sha256")
        names = [step.get("step") for step in steps]
        if names not in ([], ["palette_match"], ["clean_outline"], ["palette_match", "clean_outline"]):
            raise ValueError("unsupported post_steps order for replay")
        for step in steps:
            valid = (valid_palette_parameters(step.get("parameters")) if step["step"] == "palette_match"
                     else step.get("parameters") == OUTLINE_PARAMETERS)
            if not valid or not is_digest(step.get("pre_step_pixel_sha256")):
                raise ValueError("processed post_steps parameters or pre-step digest invalid")
    if "match_reference" in kit:
        if len(palette) != 1 or palette[0].get("match_reference") != kit["match_reference"]:
            raise ValueError("processed match_reference mismatched")
    for step in palette:
        validate_palette_skip(step)
        if "reference_sha256" in step and ("raw_steps" in kit or "match_reference" in step):
            raise ValueError("palette_match requires reference_pixel_sha256, not reference_sha256")
        if "match_reference" in step:
            reference, binding = derive_match_reference(step["match_reference"], kit_path, root)
            if any(step.get(key) != value for key, value in binding.items()):
                raise ValueError("palette_match reference digest changed")
        elif "reference_pixel_sha256" in step or "reference_sha256" in step or "raw_steps" in kit:
            reference = rgba(direct_match_path(Path(step["reference"]), kit_path, root))
            if pixel_digest(reference) != step.get("reference_pixel_sha256"):
                raise ValueError("palette_match reference pixel digest changed")
        else:
            reference = None
        if step.get("skipped") in ("empty reference", "empty rear"):
            if reference is None or bool(np.asarray(reference)[..., 3].any()) != (step["skipped"] == "empty rear"):
                raise ValueError("palette_match empty-body skip reason differs from reference opacity")
    if processed.get("raw_steps") != kit.get("raw_steps"):
        raise ValueError("processed raw_steps mismatched")
    if "raw_steps" not in kit:
        return []
    raw = replay_raw_steps(kit_path, allow_missing=not require_inputs)
    if processed.get("raw_pixel_sha256") != kit["raw_steps"][-1]["output_raw_pixel_sha256"]:
        raise ValueError("processed raw_pixel_sha256 differs from final raw_steps output")
    if pixel_digest(rgba(source)) != processed.get("pixel_sha256"):
        raise ValueError("processed.png pixel digest changed")
    if raw is None:
        return ["SKIP raw_steps replay: inputs absent"]
    match_front = None
    with tempfile.TemporaryDirectory(prefix="art-identity-replay-") as folder:
        out = Path(folder) / "processed.png"
        # An explicit --match-front descriptor is retained in the sidecar even without a kit field.
        if palette and "match_reference" not in kit:
            if "match_reference" in palette[0]:
                match_front = Path(folder) / "match_reference.json"
                write_json(match_front, palette[0]["match_reference"])
            else:
                match_front = Path(palette[0]["reference"])
        replay = process_raw(None, kit_path, out, root, match_front, "clean_outline" in names,
                             palette_parameters=palette[0]["parameters"] if palette else None)
        for key in ("raw_pixel_sha256", "pixel_sha256", "raw_steps", "post_steps", "K", "k_eff", "fit_scale", "drawn_size", "placement", "shift"):
            if replay.get(key) != processed.get(key):
                raise ValueError("replayed processed " + key + " mismatched")
        byte_diagnostic = "identical" if out.read_bytes() == source.read_bytes() else "different (pixels match)"
    return ["MATCH raw_pixel_sha256 " + pixel_digest(raw), "MATCH pixel_sha256 " + processed["pixel_sha256"],
            "INFO processed.png encoded bytes " + byte_diagnostic]


def metric_bands(entry: dict, bands: dict) -> dict:
    result = {}
    if entry["kind"] == "creature":
        creature = bands["creature"]
        result.update(symmetry=(None, creature["symmetry_max"]), thin_abs=(None, creature["thin_abs_max"]),
                      thin_rel=(None, creature["thin_rel_max"]),
                      edge_light_share=(None, creature["edge_light_share_max"]),
                      feature_px=(creature["feature_px_min_small"] if entry["size_class"] == "small"
                                  else creature["feature_px_min"], None))
        # Rear feet mix the lateral axis with the stride toward the upper-right, so the angle gates front views only;
        # rears are judged visually against their approved front (director decision 2026-10-12).
        rear = (entry.get("facing") == "rear" or str(entry.get("view", "")).endswith("_rear")
                or "/rear/" in str(entry.get("path", "")))
        if not rear:
            result["lateral_axis"] = creature["lateral_axis_deg"]
    elif entry.get("anatomy") == "plinth":
        result.update(bands["object_plinth"])
    elif entry.get("anatomy") == "legged":
        result["lateral_axis"] = bands["object_legged"]["lateral_axis_deg"]
    else:
        raise ValueError("objects require plinth or legged anatomy")
    palette = bands["palette"]["boss" if entry.get("boss", False) else "normal"]
    result.update(chroma=(None, palette["chroma_max"]), value=(palette["value_min"], palette["value_max"]),
                  height_drawn=bands["size_class_canvas_height"][entry["size_class"]])
    if entry["kind"] == "creature" and not entry.get("boss", False):
        result["art_scale"] = bands["art_scale_new_normal"]
    return result


def in_band(value, band) -> bool:
    return (isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
            and (band[0] is None or value >= band[0]) and (band[1] is None or value <= band[1]))


def metric_failures(entry: dict, measured: dict, bands: dict) -> list:
    failures = []
    values = dict(measured, art_scale=entry.get("art_scale", 1.0))
    if entry.get("landmarks"):
        values["lateral_axis"] = lateral_axis(entry["landmarks"])
    exceptions = entry.get("exceptions", [])
    for metric, band in metric_bands(entry, bands).items():
        value = values.get(metric)
        if in_band(value, band):
            continue
        exception = next((e for e in exceptions if e.get("metric") == metric and e.get("value") == value
                          and isinstance(e.get("reason"), str) and e["reason"].strip()), None)
        hard_limit = bands["creature"].get(metric + "_max_with_exception") if entry["kind"] == "creature" else None
        if value is None or exception is None or (hard_limit is not None and value > hard_limit):
            failures.append("%s=%s outside %s" % (metric, value, list(band)))
    return failures


def coverage(root: Path) -> dict:
    enemies = read_json(root / "data/enemies.json")
    canon = canon_entries(root, include_retired=True)
    by_path = {e["path"]: e for e in canon.values()}
    paths = {}
    for enemy_id, enemy in enemies.items():
        for field, facing in (("art_path", "front"), ("art_rear_path", "rear")):
            if not enemy.get(field):
                continue
            path = enemy[field].removeprefix("res://")
            paths[path] = {"id": enemy_id, "kind": "creature", "anatomy": "", "facing": facing,
                           "art_scale": enemy.get("art_scale", 1.0), "boss": bool(enemy.get("boss_bar", False))}
    density = read_json(root / "spec/assets/board_pixel_density/registry.json")
    for rig in density["entries"]:
        if rig["kind"] != "rig" or rig["id"] not in enemies:
            continue
        for rests in rig.get("rest_paths", {}).values():
            for path in rests:
                paths[path] = {"id": rig["id"], "kind": "creature", "anatomy": "",
                               "art_scale": enemies[rig["id"]].get("art_scale", 1.0),
                               "boss": bool(enemies[rig["id"]].get("boss_bar", False))}
    # Canon protects hero references as well as all standing props.
    for path, entry in by_path.items():
        paths.setdefault(path, {"id": entry["id"], "art_scale": 1.0, "boss": False})
        paths[path].update({k: entry[k] for k in ("kind", "anatomy", "size_class")})
    return paths


def adopt_legacy(root: Path = ROOT) -> dict:
    target = root / IDENTITY / "registry.json"
    if target.exists():
        raise ValueError("registry already exists; adoption must not silently grandfather changed pixels")
    paths = coverage(root)
    # Include all twelve named reart jobs even before the remaining enemy units
    # are integrated. Missing pending files are warnings, never legacy baselines.
    for enemy_id in PENDING_REART:
        paths.setdefault("assets/art/enemies/" + enemy_id + ".png",
                         {"id": enemy_id, "kind": "creature", "anatomy": "", "art_scale": 1.0, "boss": False})
    entries = []
    bands = read_json(root / IDENTITY / "bands.json")
    for path, metadata in sorted(paths.items()):
        entry = dict(metadata, path=path, entry_kind="pending_reart" if metadata["id"] in PENDING_REART else "legacy")
        source = repo_path(root, path)
        if source.is_file():
            measured = measure(source, metadata["art_scale"], metadata["kind"], metadata.get("anatomy", ""))
            entry.update(metrics=measured, pixel_sha256=pixel_digest(rgba(source)))
            if "size_class" not in entry:
                entry["size_class"] = next((k for k, b in bands["size_class_canvas_height"].items()
                                             if in_band(measured["height_drawn"], b)), "outside_reference_bands")
        entries.append(entry)
    registry = {"version": 1, "entries": entries}
    write_json(target, registry)
    return registry


def is_digest(value) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)


def validate_maquette_refs(kit: dict, kit_path: Path, canon: dict, rear: bool) -> list:
    """Maquette structure/identity references are shipped inputs, not regenerable peers."""
    failures = []
    roles = set()
    refs_root = (kit_path.parent / "refs").resolve()
    if not kit_path.parent.name.startswith("mq"):
        failures.append("maquette job folder must be named mq* (its refs/ is committed only there)")
    if not str(kit.get("prompt_source", "")).startswith("spec/art_identity/maquettes/"):
        failures.append("maquette prompt_source must name a prompt under spec/art_identity/maquettes/")
    for ref in kit["refs"]:
        role = ref.get("role")
        if role not in MAQUETTE_REF_ROLES:
            failures.append("maquette reference role missing or unknown: " + str(role))
        else:
            roles.add(role)
        canon_id = ref.get("canon_id")
        if role == "canon" and canon_id not in canon:
            failures.append("maquette canon reference has unknown id: " + str(canon_id))
        elif role != "canon" and canon_id in canon:
            failures.append("non-canon maquette reference reuses canon id: " + str(canon_id))
        file = ref.get("file", "")
        if not isinstance(file, str):
            failures.append("maquette reference file must be a string: " + repr(file))
            continue
        try:
            path = repo_path(kit_path.parent, file)
            if not file.startswith("refs/") or refs_root not in path.parents:
                raise ValueError("outside refs/")
        except ValueError:
            failures.append("maquette reference must be job-relative under refs/: " + str(file))
            continue
        if not path.is_file():
            failures.append("maquette reference missing: " + file)
        elif pixel_digest(rgba(path)) != ref.get("pixel_sha256"):
            failures.append("maquette reference pixel digest changed: " + file)
    if "maquette_parts" not in roles:
        failures.append("maquette requires a maquette_parts reference")
    if rear and "identity" not in roles:
        failures.append("rear maquette requires an identity reference")
    return failures


def validate_kit_entry(entry: dict, root: Path, bands: dict, metadata: dict) -> tuple:
    failures, warnings = [], []
    kit_path = repo_path(root, entry["kit_path"])
    kit = read_json(kit_path)
    maquette = kit.get("kit_kind") == "maquette"
    job = kit.get("job_id") if maquette else "id-%s-%s" % (kit["id"], kit["view"])
    if not isinstance(job, str) or not job.strip() or kit.get("job_id") != job or entry.get("job_id") != job:
        failures.append("kit job id missing or mismatched")
    for key in ("kind", "anatomy", "size_class"):
        if entry.get(key) != kit.get(key):
            failures.append("kit " + key + " mismatched")
    refs = kit["refs"]
    canon = canon_entries(root, include_retired=True)
    rear = kit["view"].endswith("_rear")
    if kit["view"] not in VIEWS or kit["kind"] != ("object" if kit["view"] == "object_plinth" else "creature"):
        failures.append("kit view and kind disagree")
    if maquette:
        failures.extend(validate_maquette_refs(kit, kit_path, canon, rear))
    elif len(kit["peers"]) != 2:
        failures.append("kit requires exactly two canon peers")
    for peer_id in ([] if maquette else kit["peers"]):
        peer = canon.get(peer_id)
        if peer is None or peer["kind"] != kit["kind"] or peer["anatomy"] != kit["anatomy"]:
            failures.append("kit peer is not same-kind/anatomy canon: " + peer_id)
    if not maquette and not failures:
        expected_ids = ["hero_rear" if rear else "hero_front"] + [
            matching_view(canon, canon[p], rear)["id"] for p in kit["peers"]]
        if [ref["canon_id"] for ref in refs if "canon_id" in ref] != expected_ids:
            failures.append("kit must contain hero and both matching-view peer references in order")
        if len(refs) != 3 + int(rear) + int(kit["kind"] == "object"):
            failures.append("kit reference count mismatch")
    factor_bands = bands["kit_factor"]
    if str(kit["K"]) not in factor_bands or not in_band(kit["target_h"], factor_bands[str(kit["K"])]):
        failures.append("kit factor does not match target height")
    if not maquette and rear and (not refs or refs[0]["file"] != "refs/01_front_ref.png"):
        failures.append("rear job requires unchanged first front reference")
    # Standard refs are regenerable: bind their job records, not today's paint.
    # Maquette refs are shipped inputs; validate_maquette_refs checks the PNGs.
    ref_files = [ref["file"] for ref in refs]
    if len(set(ref_files)) != len(ref_files):
        failures.append("kit has duplicate reference paths")
    for ref in refs:
        if Path(ref["file"]).is_absolute() or ".." in Path(ref["file"]).parts:
            failures.append("kit reference path must be repository-relative")
        if not is_digest(ref.get("pixel_sha256")):
            failures.append("recorded reference pixel digest missing or invalid: " + ref["file"])
        if not maquette and ref.get("canon_id"):
            reference = canon.get(ref["canon_id"])
            if reference is None or reference["view"] != ("rear" if rear else "front"):
                failures.append("reference is not matching-view canon: " + ref["canon_id"])
    if entry.get("ref_pixel_sha256") != recorded_ref_digests(kit):
        failures.append("recorded reference pixel digests differ from registry")
    if not is_digest(kit.get("kit_version")) or entry.get("kit_version") != kit.get("kit_version"):
        failures.append("kit_version missing or changed")
    prompt = repo_path(root, entry["prompt_path"])
    if prompt.resolve() != repo_path(kit_path.parent, kit["prompt_path"]).resolve():
        failures.append("prompt path is not the job prompt")
    prompt_bytes = prompt.read_bytes()
    if sha(prompt_bytes) != kit.get("prompt_sha256"):
        failures.append("prompt digest changed")
    if entry.get("prompt_sha256") != kit.get("prompt_sha256"):
        failures.append("recorded prompt digest differs from registry")
    if maquette and prompt_kit_version(kit, prompt_bytes) != kit.get("kit_version"):
        failures.append("maquette kit_version does not reproduce from prompt and ordered reference digests")
    # Historical standard prompts may use the director-authorized recorded field.
    # Maquette versions must reproduce exactly; both retain all other bindings.
    raw_key = "raw_pixel_sha256" if "raw_steps" in kit else "raw_sha256"
    if not is_digest(entry.get(raw_key)):
        failures.append(raw_key + " missing or invalid")
    if "raw_steps" in kit and "raw_sha256" in entry:
        failures.append("raw_steps registry entry requires raw_pixel_sha256, not raw_sha256")
    if entry.get("raw_path"):
        raw_path = repo_path(root, entry["raw_path"])
        raw_digest = pixel_digest(rgba(raw_path)) if "raw_steps" in kit else sha(raw_path.read_bytes())
        if raw_digest != entry.get(raw_key):
            failures.append(raw_key + " changed")
    if not repo_path(root, entry["sheet_path"]).is_file():
        failures.append("review sheet missing")
    judge = entry.get("judge", {})
    if judge.get("verdict") != "PASS" or not isinstance(judge.get("date"), str) or not judge.get("date", "").strip():
        failures.append("judge requires PASS verdict and date")
    if not isinstance(entry.get("owner_approval"), str) or not entry.get("owner_approval", "").strip():
        failures.append("owner_approval note missing")
    actual = dict(entry)
    if metadata:
        actual["art_scale"] = metadata["art_scale"]
        actual["boss"] = metadata["boss"]
    source = repo_path(root, entry.get("source_path", str(kit_path.parent.resolve().relative_to(root.resolve())) + "/processed.png"))
    if source.resolve() != (kit_path.parent / "processed.png").resolve():
        failures.append("source path is not the job processed sprite")
    source_digest = pixel_digest(rgba(source))
    if source_digest != entry.get("source_pixel_sha256"):
        failures.append("source pixel digest changed")
    processed = read_json(source.with_suffix(".json"))
    if processed.get("pixel_sha256") != source_digest or processed.get(raw_key) != entry.get(raw_key):
        failures.append("processed sidecar digest mismatched")
    if entry.get("post_steps", []) != processed.get("post_steps", []):
        failures.append("processed post_steps mismatched")
    try:
        warnings.extend(line for line in verify_job_recipe(kit_path, root) if line.startswith("SKIP "))
    except Exception as exc:
        # Recipe errors belong to this entry; retain provenance failures and still check its metrics.
        failures.append("recipe: " + str(exc))
    actual["view"] = kit["view"]
    measured = measure(repo_path(root, entry["path"]), actual.get("art_scale", 1.0), entry["kind"], entry["anatomy"])
    failures.extend(metric_failures(actual, measured, bands))
    return failures, warnings


def check_registry(root: Path = ROOT, entry_id: str = None, strict: bool = False) -> tuple:
    registry = read_json(root / IDENTITY / "registry.json")
    bands = read_json(root / IDENTITY / "bands.json")
    covered = coverage(root)
    entries = registry["entries"]
    paths = [e["path"] for e in entries]
    reports, failures, warnings, skips = [], 0, 0, 0
    for path in sorted(set(covered) - set(paths)):
        reports.append("FAIL " + path + ": missing registry entry")
        failures += 1
    for path in sorted({p for p in paths if paths.count(p) > 1}):
        reports.append("FAIL " + path + ": duplicate registry entry")
        failures += 1
    selected = [e for e in entries if entry_id is None or e.get("id") == entry_id or e["path"] == entry_id]
    if entry_id is not None and not selected:
        reports.append("FAIL unknown id: " + entry_id)
        failures += 1
    for entry in sorted(selected, key=lambda e: e["path"]):
        path = entry["path"]
        errors = []
        try:
            state = entry["entry_kind"]
            if state == "pending_reart":
                if entry.get("id") not in PENDING_REART or path != "assets/art/enemies/" + entry["id"] + ".png":
                    errors.append("pending_reart is reserved for the twelve 2026-10-12 enemies")
                elif strict:
                    errors.append("pending_reart (2026-10-12 owner rejection)")
                else:
                    reports.append("WARN " + path + ": pending_reart (2026-10-12 owner rejection)")
                    warnings += 1
                    continue
            elif state in ("legacy", "kit"):
                if pixel_digest(rgba(repo_path(root, path))) != entry.get("pixel_sha256"):
                    errors.append("pixel digest changed")
                if state == "kit":
                    kit_errors, kit_warnings = validate_kit_entry(entry, root, bands, covered.get(path, {}))
                    errors.extend(kit_errors)
                    reports.extend("WARN " + path + ": " + warning for warning in kit_warnings)
                    skipped = [warning for warning in kit_warnings if warning.startswith("SKIP ")]
                    skips += len(skipped)
                    if strict:
                        errors.extend("strict: " + warning for warning in skipped)
                    if entry.get("kind") == "creature":
                        pair = [e for e in entries if e.get("id") == entry.get("id") and e.get("entry_kind") == "kit"
                                and e.get("kind") == "creature"]
                        front = next((e for e in pair if e.get("facing") == "front"), None)
                        rear = next((e for e in pair if e.get("facing") == "rear"), None)
                        if front and rear:
                            deltas = rear_consistency(repo_path(root, front["source_path"]), repo_path(root, rear["source_path"]))
                            for metric, value in deltas.items():
                                limit = bands["rear_consistency"][metric + "_max"]
                                excused = any(e.get("metric") == "rear_consistency." + metric and isinstance(e.get("reason"), str)
                                              and e["reason"].strip() and abs(float(e.get("value", -1)) - round(value, 6)) < 1e-6
                                              for e in entry.get("exceptions", []))
                                if value > limit and not excused:
                                    errors.append("rear_consistency.%s=%.6f outside [0, %s]" % (metric, value, limit))
            else:
                errors.append("unknown entry_kind: " + str(state))
        except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
            errors.append(str(exc))
        if errors:
            failures += 1
            reports.append("FAIL " + path + ": " + "; ".join(errors))
        else:
            detail = entry["entry_kind"]
            if detail == "kit":
                kit_path = repo_path(root, entry["kit_path"])
                kit = read_json(kit_path)
                detail += "; kit_version " + kit_version_verification(kit, repo_path(root, entry["prompt_path"]).read_bytes())
            reports.append("PASS " + path + " (" + detail + ")")
    reports.append("ART IDENTITY CHECK: %s (%d failures, %d pending_reart warnings, %d skipped replays)" %
                   ("FAIL" if failures else "PASS", failures, warnings, skips))
    return reports, failures


def proof_font() -> ImageFont.ImageFont:
    for path in ("DejaVuSansMono.ttf", "/System/Library/Fonts/Menlo.ttc", "C:/Windows/Fonts/consola.ttf"):
        try:
            return ImageFont.truetype(path, SHEET_DEFAULTS["font_size"])
        except OSError:
            pass
    return ImageFont.load_default()


def sheet_backdrop(root: Path) -> tuple:
    directory = root / IDENTITY / "backdrop"
    if (directory / "empty_board.png").is_file() and (directory / "slots.json").is_file():
        image = rgba(directory / "empty_board.png")
        slots = read_json(directory / "slots.json")
        return image, slots["rows"][0]
    width, height = SHEET_DEFAULTS["width"], SHEET_DEFAULTS["row_height"]
    image = Image.new("RGBA", (width, height), "#14100c")
    draw = ImageDraw.Draw(image)
    slots = []
    for index in range(6):
        x = SHEET_DEFAULTS["synthetic_origin"][0] + index * SHEET_DEFAULTS["synthetic_step_x"]
        y = SHEET_DEFAULTS["synthetic_origin"][1]
        draw.polygon([(x - 85, y), (x, y - 42.5), (x + 85, y), (x, y + 42.5)],
                     fill="#2a221a", outline="#3a2f24", width=2)
        slots.append({"centre": [x, y], "screen_px_per_canvas_px": 0.634})
    return image, slots


def draw_landmarks(draw: ImageDraw.ImageDraw, landmarks: dict, offset: tuple, scale: int = 2) -> None:
    pair = landmarks.get("lateral_axis", landmarks)
    points = [tuple(offset[i] + p[i] * scale for i in (0, 1)) for p in (pair["far"], pair["near"])]
    draw.line(points, fill="#e0483c", width=2)
    for x, y in points:
        draw.ellipse((x - 3, y - 3, x + 3, y + 3), fill="#e0483c")
    x, y = points[1]
    norm = math.sqrt(1.25)
    extent = SHEET_DEFAULTS["ideal_line_extent"]
    for distance in range(-extent, extent + 1, SHEET_DEFAULTS["ideal_dash_period"]):
        end = distance + SHEET_DEFAULTS["ideal_dash_length"]
        draw.line([(x + distance / norm, y + distance * 0.5 / norm),
                   (x + end / norm, y + end * 0.5 / norm)], fill="#c9a25e", width=1)


def render_board_row(backdrop: Image.Image, slots: list, subjects: list) -> Image.Image:
    """Shared native-size composition for candidate and independent-judge sheets."""
    if len(subjects) > len(slots) or not slots:
        raise ValueError("backdrop needs a slot for each row subject")
    top = max(0, math.floor(min(s["centre"][1] for s in slots) - SHEET_DEFAULTS["crop_above_slot"]))
    bottom = min(backdrop.height, math.ceil(max(s["centre"][1] for s in slots) + SHEET_DEFAULTS["crop_below_slot"]))
    row = backdrop.copy()
    draw = ImageDraw.Draw(row)
    font = proof_font()
    for (sprite, art_scale, label), slot in zip(subjects, slots):
        x, y = slot["centre"]
        draw.text((x + SHEET_DEFAULTS["label_offset"][0], top + SHEET_DEFAULTS["label_offset"][1]),
                  label, font=font, fill="#c9a25e")
        if sprite is None:
            continue
        screen_scale = slot["screen_px_per_canvas_px"] * art_scale
        sprite = sprite.resize((max(1, round(sprite.width * screen_scale)), max(1, round(sprite.height * screen_scale))), RESAMPLE.LANCZOS)
        row.alpha_composite(sprite, (round(x - 128 * screen_scale), round(y - 246 * screen_scale)))
    return row.crop((0, top, row.width, bottom))


def compose_board_scales(native: Image.Image, out: Path) -> None:
    """The exact native panel followed by the same pixels doubled with NEAREST."""
    output = Image.new("RGBA", (native.width * 2, native.height * 3), "#14100c")
    output.alpha_composite(native, (0, 0))
    output.alpha_composite(native.resize((native.width * 2, native.height * 2), RESAMPLE.NEAREST), (0, native.height))
    out.parent.mkdir(parents=True, exist_ok=True)
    output.convert("RGB").save(out)


def make_canon_sheet(out: Path, view: str = "front", root: Path = ROOT) -> list:
    if view not in ("front", "rear"):
        raise ValueError("canon-sheet view must be front or rear")
    canon = canon_entries(root)
    metadata = coverage(root)
    selected = [entry for entry in canon.values() if entry["kind"] == "object" or entry["view"] == view]
    if not selected:
        raise ValueError("canon has no entries for " + view)
    backdrop, slots = sheet_backdrop(root)
    subjects = [(rgba(repo_path(root, entry["path"])), metadata.get(entry["path"], {}).get("art_scale", 1.0), entry["id"])
                for entry in selected]
    rows = [render_board_row(backdrop, slots, subjects[index:index + len(slots)])
            for index in range(0, len(subjects), len(slots))]
    native = Image.new("RGBA", (backdrop.width, sum(row.height for row in rows)), "#14100c")
    y = 0
    for row in rows:
        native.alpha_composite(row, (0, y))
        y += row.height
    compose_board_scales(native, out)
    return [entry["id"] for entry in selected]


def processed_fit_scale(path: Path):
    sidecar = path.with_suffix(".json")
    if not sidecar.is_file():
        return None
    record = read_json(sidecar)
    if "fit_scale" not in record:
        return None
    if record.get("pixel_sha256") != pixel_digest(rgba(path)):
        raise ValueError("process sidecar pixel digest changed: " + str(sidecar))
    scale = record["fit_scale"]
    if not in_band(scale, (0, 1)) or scale == 0:
        raise ValueError("process fit_scale must be positive and at most one")
    return scale


def make_sheet(front: Path, rear: Path, kit_path: Path, out: Path, art_scale: float = 1.0,
               landmarks: dict = None, root: Path = ROOT) -> None:
    kit = read_json(kit_path)
    canon = canon_entries(root, include_retired=True)
    references = [matching_view(canon, canon[p], False) for p in kit["peers"]]
    meta = coverage(root)
    def scale_for(path: str) -> float:
        return meta.get(path, {}).get("art_scale", 1.0)
    candidate = rgba(front)
    candidate_path = str(front.resolve().relative_to(root.resolve())) if root.resolve() in front.resolve().parents else ""
    candidate_meta = meta.get(candidate_path, next((m for m in meta.values() if m["id"] == kit["id"]), {}))
    rear_image = rgba(rear) if rear is not None else None
    subjects = [(rgba(repo_path(root, canon["hero_front"]["path"])), 1.0, "hero"),
                (rgba(repo_path(root, references[0]["path"])), scale_for(references[0]["path"]), references[0]["id"]),
                (candidate, art_scale, "candidate front"), (rear_image, art_scale, "candidate rear (absent)" if rear_image is None else "candidate rear"),
                (ImageOps.mirror(candidate), art_scale, "candidate mirrored"),
                (rgba(repo_path(root, references[1]["path"])), scale_for(references[1]["path"]), references[1]["id"])]
    backdrop, slots = sheet_backdrop(root)
    if len(slots) < 6:
        raise ValueError("backdrop needs six ordered review slots")
    row = render_board_row(backdrop, slots[:6], subjects)
    font = proof_font()
    metric_rows = []
    bands = read_json(root / IDENTITY / "bands.json")
    for facing, path in (("front", front), ("rear", rear)):
        if path is None:
            continue
        measured = measure(path, art_scale, kit["kind"], kit["anatomy"])
        annotation = (landmarks.get(facing) if ('front' in landmarks or 'rear' in landmarks) else landmarks) if landmarks else None
        if annotation:
            measured["lateral_axis"] = lateral_axis(annotation)
        entry = dict(kit, art_scale=art_scale, landmarks=annotation or {}, boss=candidate_meta.get("boss", False),
                     facing=facing)
        limits = metric_bands(entry, bands)
        measured["art_scale"] = art_scale
        for metric, value in measured.items():
            limit = limits.get(metric)
            status = "INFO" if limit is None else ("PASS" if in_band(value, limit) else "FAIL")
            metric_rows.append((facing + "." + metric, "%0.4f" % value, str(limit) if limit else "unbanded", status))
        fit_scale = processed_fit_scale(path)
        metric_rows.append((facing + ".fit_scale", "%0.4f" % fit_scale if fit_scale is not None else "N/A", "unbanded", "INFO"))
        if "lateral_axis" in limits and not annotation:
            metric_rows.append((facing + ".lateral_axis", "MISSING", str(limits["lateral_axis"]), "FAIL"))
    if rear is not None and kit["kind"] == "creature":
        for metric, value in rear_consistency(front, rear).items():
            limit = bands["rear_consistency"][metric + "_max"]
            metric_rows.append(("rear_consistency." + metric, "%0.4f" % value, str((0, limit)),
                                "PASS" if value <= limit else "FAIL"))
    line_height = SHEET_DEFAULTS["table_line_height"]
    provenance = ["kit_version " + kit["kit_version"], "front pixels " + pixel_digest(candidate),
                  "rear pixels " + (pixel_digest(rear_image) if rear_image else "absent"),
                  "kit file sha256 " + sha(kit_path.read_bytes()), "prompt sha256 " + kit["prompt_sha256"]]
    provenance.extend(ref["file"] + " pixels " + ref["pixel_sha256"] for ref in kit["refs"])
    table_height = (len(metric_rows) + len(provenance) + 3) * line_height
    output = Image.new("RGBA", (row.width * 2, row.height * 3 + SHEET_DEFAULTS["detail_height"] + table_height), "#14100c")
    output.alpha_composite(row, (0, 0))
    output.alpha_composite(row.resize((row.width * 2, row.height * 2), RESAMPLE.NEAREST), (0, row.height))
    detail_y = row.height * 3
    draw = ImageDraw.Draw(output)
    for index, (label, sprite) in enumerate((("front", candidate), ("rear", rear_image))):
        x = SHEET_DEFAULTS["margin"] + index * SHEET_DEFAULTS["detail_step_x"]
        y = detail_y + SHEET_DEFAULTS["detail_offset_y"]
        draw.text((x, detail_y), label, font=font, fill="#c9a25e")
        if sprite is None:
            continue
        output.alpha_composite(sprite.resize((sprite.width * 2, sprite.height * 2), RESAMPLE.NEAREST), (x, y))
        annotation = (landmarks.get(label) if ('front' in landmarks or 'rear' in landmarks) else landmarks) if landmarks else None
        if annotation:
            draw_landmarks(draw, annotation, (x, y))
        if kit["view"] == "object_plinth":
            bb = alpha_bbox(sprite)
            mask = np.asarray(sprite.crop(bb))[..., 3] > 128
            for fit in base_fits(mask):
                points = [(x + 2 * (bb[0] + px), y + 2 * (bb[1] + fit["slope"] * px + fit["intercept"]))
                          for px in (fit["x0"], fit["x1"])]
                draw.line(points, fill="#e0483c", width=2)
    table_y = detail_y + SHEET_DEFAULTS["detail_height"]
    draw.text((SHEET_DEFAULTS["margin"], table_y), "metric                         value       band                  status", font=font, fill="#c9a25e")
    for index, (metric, value, band, status) in enumerate(metric_rows, 1):
        draw.text((SHEET_DEFAULTS["margin"], table_y + index * line_height), "%-30s %-11s %-21s %s" % (metric, value, band, status), font=font,
                  fill="#e0483c" if status == "FAIL" else ("#5fae62" if status == "PASS" else "#c9a25e"))
    for index, text in enumerate(provenance, len(metric_rows) + 2):
        draw.text((SHEET_DEFAULTS["margin"], table_y + index * line_height), text, font=font, fill="#c9a25e")
    out.parent.mkdir(parents=True, exist_ok=True)
    output.convert("RGB").save(out)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    measure_cmd = commands.add_parser("measure")
    measure_cmd.add_argument("path", type=Path)
    measure_cmd.add_argument("--art-scale", type=float, default=1.0)
    measure_cmd.add_argument("--kind", choices=("creature", "object"), default="creature")
    measure_cmd.add_argument("--anatomy", default="")
    kit = commands.add_parser("kit")
    for name in ("id", "subject", "anatomy", "out-dir"):
        kit.add_argument("--" + name, required=True)
    kit.add_argument("--view", required=True, choices=VIEWS)
    kit.add_argument("--size-class", required=True, choices=DEFAULT_HEIGHTS)
    kit.add_argument("--peers", nargs=2, required=True)
    kit.add_argument("--front-ref", type=Path)
    kit.add_argument("--subject-rear", type=Path)
    kit.add_argument("--target-h", type=int)
    kit.add_argument("--target-w", type=int)
    process_cmd = commands.add_parser("process")
    process_cmd.add_argument("raw", type=Path, nargs="?", help="omit to replay the kit's raw_steps")
    process_cmd.add_argument("--kit", required=True, type=Path)
    process_cmd.add_argument("--out", required=True, type=Path)
    process_cmd.add_argument("--match-front", type=Path)
    process_cmd.add_argument("--clean-outline", action="store_true")
    process_cmd.add_argument("--palette-parameters", choices=("current", "legacy"),
                             help="default: recorded kit parameters, or current for a new match")
    process_cmd.add_argument("--allow-protected-share", action="store_true", default=None,
                             help="allow protection above 25%%; skip an empty-body match with a recorded reason and shares")
    record_cmd = commands.add_parser("record-steps", help="recompute digests for an already-listed raw_steps recipe")
    record_cmd.add_argument("--kit", required=True, type=Path)
    sheet = commands.add_parser("sheet")
    sheet.add_argument("--front", required=True, type=Path)
    sheet.add_argument("--rear", type=Path)
    sheet.add_argument("--kit", required=True, type=Path)
    sheet.add_argument("--art-scale", type=float, default=1.0)
    sheet.add_argument("--landmarks", type=Path)
    sheet.add_argument("--out", required=True, type=Path)
    canon_sheet = commands.add_parser("canon-sheet")
    canon_sheet.add_argument("--out", required=True, type=Path)
    canon_sheet.add_argument("--view", choices=("front", "rear"), default="front")
    check = commands.add_parser("check")
    selection = check.add_mutually_exclusive_group()
    selection.add_argument("--id")
    selection.add_argument("--kit", type=Path, help="verify an unregistered job's processing recipe only")
    check.add_argument("--strict", action="store_true")
    commands.add_parser("adopt-legacy")
    return result


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    args = parser().parse_args()
    try:
        if args.command == "measure":
            print(json.dumps(measure(args.path, args.art_scale, args.kind, args.anatomy), indent=2, sort_keys=True, allow_nan=False))
        elif args.command == "kit":
            kit = make_kit(args)
            cu = os.environ.get("CU", "python3 ~/.claude/skills/orchestrate-codex/scripts/codex_unit.py")
            print("%s imagegen %s --prompt-file %s --ref %s/*.png" %
                  (cu, shlex.quote(kit["job_id"]), shlex.quote(str(Path(args.out_dir) / "prompt.md")),
                   shlex.quote(str(Path(args.out_dir) / "refs"))))
        elif args.command == "process":
            print(json.dumps(process_raw(args.raw, args.kit, args.out, match_front=args.match_front, outline=args.clean_outline,
                                         palette_parameters=args.palette_parameters, allow_protected_share=args.allow_protected_share),
                             indent=2, sort_keys=True))
        elif args.command == "record-steps":
            print("\n".join(record_steps(args.kit)))
        elif args.command == "sheet":
            make_sheet(args.front, args.rear, args.kit, args.out, args.art_scale,
                       read_json(args.landmarks) if args.landmarks else None)
            print("ART IDENTITY SHEET: " + str(args.out))
        elif args.command == "canon-sheet":
            ids = make_canon_sheet(args.out, args.view)
            print("ART IDENTITY CANON SHEET: %s (%d entries, %s)" % (args.out, len(ids), args.view))
        elif args.command == "adopt-legacy":
            registry = adopt_legacy()
            print("ADOPTED %d art identity entries" % len(registry["entries"]))
        elif args.command == "check":
            if args.kit:
                if "raw_steps" not in read_json(args.kit):
                    raise ValueError("check --kit requires raw_steps")
                print("\n".join(verify_job_recipe(args.kit, require_inputs=True)))
                print("ART IDENTITY REPLAY: PASS " + str(args.kit))
                return 0
            reports, failures = check_registry(entry_id=args.id, strict=args.strict)
            print("\n".join(reports))
            return 1 if failures else 0
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        print("ART IDENTITY ERROR: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Deterministic, presentation-only visual identity gate (numpy and Pillow).

The director-owned canon, prompt clauses and bands are inputs, never outputs.
Pixel hashes and density metrics deliberately share the board-density functions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shlex
import shutil
import sys

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
              "value": float((rgb @ np.array([0.299, 0.587, 0.114]))[mask].mean())}
    if kind == "object":
        fits = base_fits(mask)
        result.update(base_v_left=fits[0]["slope"], base_v_right=fits[1]["slope"])
    result.update(density_metrics(image))
    return result


def view_body(root: Path, view: str) -> bytes:
    contents = (root / IDENTITY / "views.md").read_bytes()
    marker = ("## " + view + "\n").encode("utf-8")
    if marker not in contents:
        raise ValueError("missing director view section: " + view)
    return contents.split(marker, 1)[1].split(b"\n## ", 1)[0]


def kit_version(root: Path, view: str, digests: list) -> str:
    return sha((root / IDENTITY / "preamble.md").read_bytes() + view_body(root, view)
               + "".join(sorted(digests)).encode("ascii"))


def canon_entries(root: Path) -> dict:
    return {entry["id"]: entry for entry in read_json(root / IDENTITY / "canon.json")["entries"]}


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
    subject = Path(args.subject).read_text(encoding="utf-8")
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
    prompt = preamble + "\n## View\n" + body + "\n## Subject\n" + subject + "\n## Size\n" + size + "\n"
    (out / "prompt.md").write_bytes(prompt.encode("utf-8"))
    kit = {"id": args.id, "job_id": "id-%s-%s" % (args.id, args.view), "view": args.view,
           "kind": kind, "anatomy": args.anatomy, "size_class": args.size_class, "K": factor,
           "target_h": height, "target_w": args.target_w, "peers": list(args.peers), "refs": references,
           "prompt_path": "prompt.md", "prompt_sha256": sha(prompt.encode("utf-8")),
           "kit_version": kit_version(root, args.view, [ref["pixel_sha256"] for ref in references])}
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


def process_raw(raw: Path, kit_path: Path, out: Path, root: Path = ROOT) -> dict:
    kit = read_json(kit_path)
    factor = kit["K"]
    if not isinstance(factor, int) or isinstance(factor, bool) or factor <= 0:
        raise ValueError("K must be a positive integer")
    image = rgba(raw)
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
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    record = {"raw_sha256": sha(raw.read_bytes()), "pixel_sha256": pixel_digest(canvas), "K": factor,
              "k_eff": k_eff, "fit_scale": fit_scale,
              "drawn_size": list(sprite.size), "placement": [placed_x, placed_y],
              "shift": [placed_x - x, placed_y - y],
              "metrics": measure(out, kind=kit.get("kind", "creature"), anatomy=kit.get("anatomy", ""))}
    write_json(out.with_suffix(".json"), record)
    return record


def metric_bands(entry: dict, bands: dict) -> dict:
    result = {}
    if entry["kind"] == "creature":
        creature = bands["creature"]
        result.update(symmetry=(None, creature["symmetry_max"]), thin_abs=(None, creature["thin_abs_max"]),
                      thin_rel=(None, creature["thin_rel_max"]),
                      feature_px=(creature["feature_px_min_small"] if entry["size_class"] == "small"
                                  else creature["feature_px_min"], None),
                      lateral_axis=creature["lateral_axis_deg"])
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
    canon = canon_entries(root)
    by_path = {e["path"]: e for e in canon.values()}
    paths = {}
    for enemy_id, enemy in enemies.items():
        path = enemy["art_path"].removeprefix("res://")
        paths[path] = {"id": enemy_id, "kind": "creature", "anatomy": "",
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


def validate_kit_entry(entry: dict, root: Path, bands: dict, metadata: dict) -> list:
    failures = []
    kit_path = repo_path(root, entry["kit_path"])
    kit = read_json(kit_path)
    job = "id-%s-%s" % (kit["id"], kit["view"])
    if kit.get("job_id") != job or entry.get("job_id") != job:
        failures.append("kit job id missing or mismatched")
    for key in ("kind", "anatomy", "size_class"):
        if entry.get(key) != kit.get(key):
            failures.append("kit " + key + " mismatched")
    refs = kit["refs"]
    canon = canon_entries(root)
    rear = kit["view"].endswith("_rear")
    if kit["view"] not in VIEWS or kit["kind"] != ("object" if kit["view"] == "object_plinth" else "creature"):
        failures.append("kit view and kind disagree")
    if len(kit["peers"]) != 2:
        failures.append("kit requires exactly two canon peers")
    for peer_id in kit["peers"]:
        peer = canon.get(peer_id)
        if peer is None or peer["kind"] != kit["kind"] or peer["anatomy"] != kit["anatomy"]:
            failures.append("kit peer is not same-kind/anatomy canon: " + peer_id)
    if not failures:
        expected_ids = ["hero_rear" if rear else "hero_front"] + [
            matching_view(canon, canon[p], rear)["id"] for p in kit["peers"]]
        if [ref["canon_id"] for ref in refs if "canon_id" in ref] != expected_ids:
            failures.append("kit must contain hero and both matching-view peer references in order")
        if len(refs) != 3 + int(rear) + int(kit["kind"] == "object"):
            failures.append("kit reference count mismatch")
    factor_bands = bands["kit_factor"]
    if str(kit["K"]) not in factor_bands or not in_band(kit["target_h"], factor_bands[str(kit["K"])]):
        failures.append("kit factor does not match target height")
    if rear and (not refs or refs[0]["file"] != "refs/01_front_ref.png"):
        failures.append("rear job requires unchanged first front reference")
    digests = []
    for ref in refs:
        path = repo_path(kit_path.parent, ref["file"])
        digest = pixel_digest(rgba(path))
        digests.append(digest)
        if ref["pixel_sha256"] != digest:
            failures.append("kit reference digest changed: " + ref["file"])
        if ref.get("canon_id"):
            reference = canon.get(ref["canon_id"])
            if reference is None or reference["view"] != ("rear" if rear else "front"):
                failures.append("reference is not matching-view canon: " + ref["canon_id"])
            elif pixel_digest(enlarged_ref(repo_path(root, reference["path"]), kit["K"])) != digest:
                failures.append("reference pixels do not match canon: " + ref["canon_id"])
        if ref["file"] == "refs/footprint_guide.png" and pixel_digest(footprint_guide(kit["K"])) != digest:
            failures.append("footprint guide differs from director geometry")
    version = kit_version(root, kit["view"], digests)
    if entry.get("kit_version") != kit.get("kit_version") or kit.get("kit_version") != version:
        failures.append("kit_version missing or changed")
    prompt = repo_path(root, entry["prompt_path"])
    if prompt.resolve() != repo_path(kit_path.parent, kit["prompt_path"]).resolve():
        failures.append("prompt path is not the job prompt")
    if sha(prompt.read_bytes()) != kit["prompt_sha256"]:
        failures.append("prompt digest changed")
    if not is_digest(entry.get("raw_sha256")):
        failures.append("raw sha256 missing or invalid")
    if entry.get("raw_path") and sha(repo_path(root, entry["raw_path"]).read_bytes()) != entry.get("raw_sha256"):
        failures.append("raw sha256 changed")
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
    measured = measure(repo_path(root, entry["path"]), actual.get("art_scale", 1.0), entry["kind"], entry["anatomy"])
    failures.extend(metric_failures(actual, measured, bands))
    return failures


def check_registry(root: Path = ROOT, entry_id: str = None, strict: bool = False) -> tuple:
    registry = read_json(root / IDENTITY / "registry.json")
    bands = read_json(root / IDENTITY / "bands.json")
    covered = coverage(root)
    entries = registry["entries"]
    paths = [e["path"] for e in entries]
    reports, failures, warnings = [], 0, 0
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
                    errors.extend(validate_kit_entry(entry, root, bands, covered.get(path, {})))
            else:
                errors.append("unknown entry_kind: " + str(state))
        except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
            errors.append(str(exc))
        if errors:
            failures += 1
            reports.append("FAIL " + path + ": " + "; ".join(errors))
        else:
            reports.append("PASS " + path + " (" + entry["entry_kind"] + ")")
    reports.append("ART IDENTITY CHECK: %s (%d failures, %d pending_reart warnings)" %
                   ("FAIL" if failures else "PASS", failures, warnings))
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
    canon = canon_entries(root)
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
        annotation = (landmarks.get(facing, landmarks) if landmarks else None)
        if annotation:
            measured["lateral_axis"] = lateral_axis(annotation)
        entry = dict(kit, art_scale=art_scale, landmarks=annotation or {}, boss=candidate_meta.get("boss", False))
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
        annotation = landmarks.get(label, landmarks) if landmarks else None
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
    kit.add_argument("--target-h", type=int)
    kit.add_argument("--target-w", type=int)
    process_cmd = commands.add_parser("process")
    process_cmd.add_argument("raw", type=Path)
    process_cmd.add_argument("--kit", required=True, type=Path)
    process_cmd.add_argument("--out", required=True, type=Path)
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
    check.add_argument("--id")
    check.add_argument("--strict", action="store_true")
    commands.add_parser("adopt-legacy")
    return result


def main() -> int:
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
            print(json.dumps(process_raw(args.raw, args.kit, args.out), indent=2, sort_keys=True))
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
            reports, failures = check_registry(entry_id=args.id, strict=args.strict)
            print("\n".join(reports))
            return 1 if failures else 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print("ART IDENTITY ERROR: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Register maquette labels, then fill explicitly requested hidden support paint.

Only Pillow/numpy (already used by art_identity_gate) are required. Blender owns
geometry; this tool never substitutes estimated silhouettes for missing solos.
See spec/cutout_workflow.md, 'From a maquette'.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import hashlib
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

from art_identity_gate import alpha_bbox, box_binary_sprite, fit_sprite, pixel_digest, silhouette_edge, to_lab
from cutout_pipeline.assets import apply_skin, segment
from cutout_pipeline.cases import (CutoutError, PROJECT, baseline, digest, init_case,
                                   load_case, local_path, read_json, write_json)
from cutout_pipeline.validation import validate

NATIVE_SIZE = 255
REASSIGNMENT_LIMIT = 0.15
MAGENTA = (255, 0, 255, 255)
GREEN = (0, 255, 0, 255)
# Proof/algorithm defaults, not player-facing tuning.
PROOF_DEFAULTS = {"sheet_columns": 5, "sheet_label_height": 28,
                  "keyframes_per_clip": 8, "mask_alpha_threshold": 128,
                  "pose_canvas": 512, "pose_offset": 128,
                  "joint_rounding_tolerance": 0.02,
                  "neighbour_connectivity": 4}
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
GAOLER_RECIPE = PROJECT / "experiments/cutouts/chainbound_gaoler/mq3/recipes/rig.json"
# Director-specified fill values; solver/seed choices are recorded, not motion tuning.
FILL_DEFAULTS = {"radius": 3, "palette_k": 6, "palette_min_own_pixels": 40,
                 "outline_tone": [20, 16, 21], "seed": 0,
                 "kmeans_max_iterations": 256, "diffusion_max_iterations": 4096,
                 "diffusion_residual_tolerance": 1e-6}


@dataclass
class Registration:
    """Pixel-edge affine map; joints and nearest-sampled images share this map."""
    scale: list[float]
    offset: list[float]
    trace: dict

    def point(self, point) -> list[float]:
        return [float(point[i]) * self.scale[i] + self.offset[i] for i in range(2)]

    def image(self, image: Image.Image) -> Image.Image:
        sx, sy = self.scale
        ox, oy = self.offset
        # Do not crop solos to the painting bbox: their occluded material can
        # extend beyond it. Only the common final 255px canvas clips anything.
        return image.transform((NATIVE_SIZE, NATIVE_SIZE), Image.Transform.AFFINE,
                               (1 / sx, 0, -ox / sx, 0, 1 / sy, -oy / sy),
                               resample=Image.Resampling.NEAREST)


def registration(raw: Path, record: dict) -> Registration:
    """Recover process_raw's crop/trim/fit, including nonintegral K and fit rounding.

    The record alone lacks the keyed bbox and two alpha trims. Recompute those
    from the digest-checked raw, using the actual gate's reducers. Palette and
    outline postprocessing cannot change this coordinate transform.
    """
    if digest(raw) != record["raw_sha256"]:
        raise CutoutError("Raw painting digest differs from processed.json")
    image = Image.open(raw).convert("RGBA")
    if image.width != image.height:
        raise CutoutError("process_raw requires square raw paint")
    k = record["K"] * image.width / 1024
    if not math.isclose(k, record["k_eff"]):
        raise CutoutError("Raw size/K do not match the approved registration")
    rgb = np.asarray(image.convert("RGB"), dtype=float)
    alpha = np.clip((np.abs(rgb - [0, 255, 0]).max(-1) - 40) / 40, 0, 1)
    background = alpha <= 0.5
    ring = background.copy()
    for _ in range(math.ceil(k) + 1):
        grown = ring.copy()
        grown[1:] |= ring[:-1]
        grown[:-1] |= ring[1:]
        grown[:, 1:] |= ring[:, :-1]
        grown[:, :-1] |= ring[:, 1:]
        ring = grown
    spill = (alpha < 1) | (ring & ~background)
    other = rgb[..., [0, 2]].max(-1)
    green = np.where(spill, np.clip((rgb[..., 1] - other) / np.maximum(255 - other, 1), 0, 0.95), 0)
    alpha = np.minimum(alpha, 1 - green)
    ys, xs = np.nonzero(alpha > 0.5)
    if not len(xs):
        raise CutoutError("Raw painting has no keyed subject")
    left, bottom = int(xs.min()), int(ys.max()) + 1
    height = math.ceil(math.ceil((bottom - int(ys.min())) / k) * k)
    width = math.ceil(math.ceil((int(xs.max()) + 1 - left) / k) * k)
    top = bottom - height
    padded = np.zeros((height, width))
    sub = alpha[max(0, top):bottom, left:left + width]
    padded[height - sub.shape[0]:, :sub.shape[1]] = sub
    reduced_size = (max(1, round(width / k)), max(1, round(height / k)))
    # Only alpha determines either trim; zero RGB intentionally avoids palette work.
    sprite = box_binary_sprite(np.zeros((height, width, 3)), padded, reduced_size)
    trim = alpha_bbox(sprite)
    sprite = sprite.crop(trim)
    before_fit = sprite.size
    sprite, fit = fit_sprite(sprite)
    after_fit = sprite.size
    final_trim = alpha_bbox(sprite)
    sprite = sprite.crop(final_trim)
    if list(sprite.size) != record["drawn_size"] or not math.isclose(fit, record["fit_scale"]):
        raise CutoutError("Recovered transform differs from approved process_raw record")
    scale = [reduced_size[i] / (width, height)[i] * after_fit[i] / before_fit[i] for i in range(2)]
    offset = [record["placement"][i] - final_trim[i] - trim[i] * after_fit[i] / before_fit[i]
              - (left, top)[i] * scale[i] for i in range(2)]
    return Registration(scale, offset, {"raw_size": list(image.size), "raw_crop": [left, top, left + width, bottom],
                                       "reduced_size": list(reduced_size), "trim": list(trim),
                                       "before_fit": list(before_fit), "after_fit": list(after_fit),
                                       "final_trim": list(final_trim), "placement": record["placement"]})


def projected(spec: dict, point, view: str, size: int = 1024) -> list[float]:
    """humanoid.py's orthographic camera, without a renderer dependency."""
    p = np.asarray(point, dtype=float).copy()
    p[:2] *= 1 if view == "front" else -1
    p -= np.asarray(spec.get("target", [0, 0, 1.2]))
    a, e = math.pi / 4, math.pi / 6
    right = np.array([-math.sin(a), math.cos(a), 0])
    up = np.array([-math.sin(e) * math.cos(a), -math.sin(e) * math.sin(a), math.cos(e)])
    scale = size / spec.get("ortho_scale", 3.4)
    return [size / 2 + float(p @ right) * scale, size / 2 - float(p @ up) * scale]


def shape_center(shape: dict, joints: dict) -> np.ndarray:
    def point(value):
        return np.asarray(joints[value] if isinstance(value, str) else value, dtype=float)
    if "a" in shape:
        return (point(shape["a"]) + point(shape["b"])) / 2
    if "pts" in shape:
        return np.asarray(shape["pts"]).mean(axis=0)
    return point(shape.get("at", shape.get("c"))) + np.asarray(shape.get("offset", [0, 0, 0]))


def camera_depths(spec: dict, view: str) -> dict[str, float]:
    """Distance along the camera axis to the mean primitive centre per label.

    A total order cannot represent intersecting 3D surfaces. Exact per-pixel
    visible ownership comes from the rendered map, not this scalar layer order.
    """
    direction = np.array([math.sqrt(3 / 8), math.sqrt(3 / 8), 0.5])
    result = {}
    for name in spec["labels"]:
        centers = [shape_center(s, spec["joints"]) for s in spec["shapes"] if s["part"] == name]
        if not centers:
            raise CutoutError("Label has no geometry: " + name)
        p = np.mean(centers, axis=0)
        p[:2] *= 1 if view == "front" else -1
        result[name] = 30 - float((p - np.asarray(spec.get("target", [0, 0, 1.2]))) @ direction)
    return result


def depth_order(depths: dict[str, float]) -> list[str]:
    return sorted(depths, key=lambda name: (-depths[name], name))


def display_palette(spec: dict, config_path: Path) -> dict:
    """Evaluate Blender's supplied AgX label transform, not an approximate RGB fit.

    Workbench material values are linear Rec.709; the PNG is AgX/sRGB. Its
    installed config and tetrahedral LUT provide the transform without adding
    an OpenColorIO Python dependency. These are diagnostic label colors only.
    """
    config = config_path.read_text()
    def matrix(name):
        section = config.split("name: " + name + "\n", 1)[1]
        values = section.split("matrix: [", 1)[1].split("]", 1)[0]
        return np.array([float(v) for v in values.split(",")]).reshape(4, 4)[:3, :3]
    conversion = matrix("Linear FilmLight E-Gamut") @ np.linalg.inv(matrix("Linear Rec.709"))
    section = config.split("name: AgX Base Rec.1886\n", 1)[1].split("- !<ViewTransform>", 1)[0]
    limits = [float(x) for x in re.search(r"allocation: lg2, vars: \[([^]]+)\]", section)[1].split(",")]
    filename = re.search(r"src: (AgX_[^,]+\.cube)", section)[1]
    lines = (config_path.parent / "luts" / filename).read_text().splitlines()
    size = int(next(l for l in lines if l.startswith("LUT_3D_SIZE")).split()[-1])
    lut = np.array([[float(x) for x in l.split()] for l in lines if l and l[0] in "-.0123456789"]).reshape(size, size, size, 3)
    result = {}
    for name, color in spec["labels"].items():
        log = np.log2(np.maximum(conversion @ color, np.finfo(float).tiny))
        coordinate = np.clip((log - limits[0]) / (limits[1] - limits[0]), 0, 1) * (size - 1)
        low = np.minimum(np.floor(coordinate).astype(int), size - 2)
        fraction = coordinate - low
        corner = low.copy()
        value = lut[corner[2], corner[1], corner[0]].copy()
        previous = value.copy()
        for axis in np.argsort(-fraction):
            corner[axis] += 1
            next_value = lut[corner[2], corner[1], corner[0]]
            value += fraction[axis] * (next_value - previous)
            previous = next_value
        # Rec.1886 (gamma 2.4) -> display-linear -> sRGB, as the OCIO view specifies.
        linear = np.maximum(value, 0) ** 2.4
        srgb = np.where(linear <= 0.0031308, 12.92 * linear, 1.055 * linear ** (1 / 2.4) - 0.055)
        result[name] = np.rint(srgb * 255).astype(int).tolist()
    return result


def decode_labels(image: Image.Image, palette: dict, names: list[str], depths: dict) -> np.ndarray:
    rgba = np.asarray(image.convert("RGBA"))
    result = np.full(rgba.shape[:2], -1, dtype=np.int16)
    # Antialiased and color-managed maps are categorical, never blend label IDs.
    order = sorted(range(len(names)), key=lambda i: (depths[names[i]], names[i]))
    colors = np.asarray([palette[names[i]] for i in order], dtype=float)
    mask = rgba[..., 3] > PROOF_DEFAULTS["mask_alpha_threshold"]
    rgb = rgba[mask, :3].astype(float)
    distances = ((rgb[:, None, :] - colors[None, :, :]) ** 2).sum(axis=2)
    result[mask] = np.asarray(order)[distances.argmin(axis=1)]
    return result


def nearest_labels(labels: np.ndarray, opaque: np.ndarray, names: list[str], depths: dict) -> tuple[np.ndarray, dict]:
    """Exact squared-Euclidean Voronoi assignment; depth wins ALL distance ties.

    A separable min-plus transform encodes depth rank below the integer squared
    distance. Unlike propagation/chamfer or unspecified EDT tie behavior, this
    also handles diagonal ties deterministically, with no scipy dependency.
    """
    if labels.shape != opaque.shape or not np.any(labels >= 0):
        raise CutoutError("Label map must match paint dimensions and contain labels")
    h, w = labels.shape
    order = sorted(range(len(names)), key=lambda i: (depths[names[i]], names[i]))
    rank = np.empty(len(names), dtype=np.int64)
    rank[order] = np.arange(len(names))
    base = len(names) + 1
    infinity = (h * h + w * w + 1) * base
    horizontal = np.full((h, w), infinity, dtype=np.int64)
    xcost = (np.arange(w)[:, None] - np.arange(w)[None, :]) ** 2 * base
    for y in range(h):
        seeds = np.flatnonzero(labels[y] >= 0)
        if len(seeds):
            horizontal[y] = (xcost[:, seeds] + rank[labels[y, seeds]][None, :]).min(axis=1)
    ycost = (np.arange(h)[:, None] - np.arange(h)[None, :]) ** 2 * base
    assigned = np.full_like(labels, -1)
    for x in range(w):
        values = (ycost + horizontal[:, x][None, :]).min(axis=1)
        assigned[:, x] = np.asarray(order)[values % base]
    assigned[~opaque] = -1
    report = {}
    for i, name in enumerate(names):
        owned = assigned == i
        count = int(owned.sum())
        changed = int((owned & (labels != i)).sum())
        share = changed / count if count else 0
        report[name] = {"painted_pixels": count, "reassigned_pixels": changed,
                        "reassigned_share": share, "above_15_percent": share > REASSIGNMENT_LIMIT}
    return assigned, report


def hidden_region(solo: np.ndarray, owners: np.ndarray, part: int) -> tuple[np.ndarray, np.ndarray]:
    # A solo outside ALL paint is a registration/silhouette disagreement, not
    # evidence of occlusion by another painted part. Report it separately.
    return solo & (owners >= 0) & (owners != part), solo & (owners < 0)


def material_neighbours(hidden: np.ndarray, owners: np.ndarray, part: int, names: list[str]) -> dict:
    """Report painted occluders and the four-connected boundary, by source label.

    Material appearance comes from those approved paint swatches; anatomy labels
    are retained instead of guessing which metal, skin or fabric to paint.
    """
    border = np.zeros_like(hidden)
    border[1:] |= hidden[:-1]
    border[:-1] |= hidden[1:]
    border[:, 1:] |= hidden[:, :-1]
    border[:, :-1] |= hidden[:, 1:]
    border &= ~hidden
    def counts(mask):
        return [{"part": names[i], "pixels": int(count)} for i, count in
                enumerate(np.bincount(owners[mask & (owners >= 0)], minlength=len(names)))
                if count and i != part]
    return {"occluding_parts": counts(hidden), "bordering_parts": counts(border)}


def label_core(mask: np.ndarray, distance: int) -> np.ndarray:
    """Euclidean distance to non-label pixels >= distance (pixel centres)."""
    result = mask.copy()
    padded = np.pad(mask, distance)
    h, w = mask.shape
    for dy in range(-distance + 1, distance):
        for dx in range(-distance + 1, distance):
            if dx * dx + dy * dy < distance * distance:
                result &= padded[distance + dy:distance + dy + h, distance + dx:distance + dx + w]
    return result


def material_reference(root: Path, spec: dict, palette: dict, view: str, policy: dict):
    names = list(spec["labels"])
    def source(which):
        directory = root / "source" / which
        transform = registration(directory / "raw.png", read_json(directory / "processed.json"))
        labels = decode_labels(transform.image(Image.open(root / f"source/maquette/{which}_parts.png")),
                               palette, names, camera_depths(spec, which))
        paint = np.array(Image.open(directory / "processed.png").convert("RGBA"))
        return paint, labels
    # Tabard is front-only: the same front material reference classifies both views.
    front, front_labels = source("front")
    tabard = label_core(front_labels == names.index("tabard"), policy["core_distance_px"]) & (front[..., 3] > 0)
    if not tabard.any():
        raise CutoutError("Tabard material core is empty")
    tabard_rgb = np.median(front[tabard, :3], axis=0)
    tabard_lab = to_lab(tabard_rgb)
    paint, labels = source(view)
    trousers = label_core(labels == names.index("thigh_near"), policy["core_distance_px"]) & (paint[..., 3] > 0)
    trousers &= np.linalg.norm(to_lab(paint[..., :3]) - tabard_lab, axis=-1) > policy["trousers_min_tabard_delta_e"]
    if not trousers.any():
        raise CutoutError("Trouser material core is empty: " + view)
    trousers_rgb = np.median(paint[trousers, :3], axis=0)
    return trousers, {"tabard_cloth": {"view": "front", "core_pixels": int(tabard.sum()),
            "median_rgb": tabard_rgb.tolist(), "median_lab": tabard_lab.tolist()},
        "trousers": {"view": view, "core_pixels": int(trousers.sum()),
            "mask_sha256": array_digest(trousers), "median_rgb": trousers_rgb.tolist(),
            "median_lab": to_lab(trousers_rgb).tolist()}}


def components8(mask: np.ndarray) -> list[np.ndarray]:
    remaining = set(zip(*np.nonzero(mask)))
    result = []
    while remaining:
        first = min(remaining)
        remaining.remove(first)
        pending, pixels = [first], []
        while pending:
            y, x = pending.pop()
            pixels.append((y, x))
            for dy in [-1, 0, 1]:
                for dx in [-1, 0, 1]:
                    neighbour = (y + dy, x + dx)
                    if neighbour in remaining:
                        remaining.remove(neighbour)
                        pending.append(neighbour)
        component = np.zeros_like(mask)
        yy, xx = zip(*pixels)
        component[yy, xx] = True
        result.append(component)
    return sorted(result, key=lambda c: (-int(c.sum()), bbox(c)[1], bbox(c)[0]))


def clean_ownership(owners, paint, names, solos, view, material, policy):
    """Simultaneous speck moves on complete parts (visible plus hidden support).

    Four-connected edge counts select the adjacent rest-painted part. Ties use
    label order. Unattached hidden-only islands may disappear; visible ones stay.
    Original ownership is retained separately to preserve every rest draw depth.
    """
    owners = owners.copy()
    report = {"material_transfers": {}, "specks": {}, "materials": material}
    if material:
        lab = to_lab(paint[..., :3])
        red = np.linalg.norm(lab - material["tabard_cloth"]["median_lab"], axis=-1) < np.linalg.norm(lab - material["trousers"]["median_lab"], axis=-1)
        transfer_parts = policy.get("tabard_transfer_parts", policy["trouser_parts"])
        delta = np.linalg.norm(lab - material["tabard_cloth"]["median_lab"], axis=-1)
        if "tabard_gate_delta_e" in policy:
            red |= delta <= policy["tabard_gate_delta_e"]
        radius = policy.get("tabard_dilation_px", 0)
        tabard_silhouette = solos["tabard"]
        padded = np.pad(tabard_silhouette, radius)
        dilated = np.zeros_like(tabard_silhouette)
        h, w = dilated.shape
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if dx * dx + dy * dy <= radius * radius:
                    dilated |= padded[radius + dy:radius + dy + h, radius + dx:radius + dx + w]
        report["tabard_dilation"] = {"radius_px": radius, "pixels": int(dilated.sum()),
            "basis": "Director's explicit part list selects complete owners; silhouette overlap is recorded, not used to crop paint transfers"}
        for name in transfer_parts:
            selected = (owners == names.index(name)) & red
            report["material_transfers"][name] = {"tabard_like_pixels": int(selected.sum()),
                "within_dilated_silhouette": int((selected & dilated).sum()),
                "moved_to_tabard": int(selected.sum()) if view == "front" else 0,
                "rear_unchanged": int(selected.sum()) if view == "rear" else 0}
            if view == "front":
                owners[selected] = names.index("tabard")
    hidden = [hidden_region(solos[name], owners, i)[0] for i, name in enumerate(names)]
    original, original_hidden = owners.copy(), [m.copy() for m in hidden]
    for i, name in enumerate(names):
        complete = (original == i) | original_hidden[i]
        components = components8(complete)
        records = []
        for component in components[1:]:
            count = int(component.sum())
            if count >= policy["speck_max_exclusive_px"]:
                continue
            border = _adjacent(component.astype(np.int16))
            border[component] = 0
            neighbours = [(int(border[original == n].sum()), n) for n in range(len(names)) if n != i]
            shared, target = max(neighbours, key=lambda value: (value[0], -value[1]))
            visible = component & (original == i)
            record = {"pixels": count, "visible_pixels": int(visible.sum()), "bbox": bbox(component), "shared_border_edges": shared}
            if shared:
                owners[visible] = target
                hidden[i][component] = False
                hidden[target] |= component & (owners != target)
                record.update(action="move", target=names[target])
            elif not visible.any():
                hidden[i][component] = False
                record.update(action="delete", reason="Hidden-only island; complete visible partition still covers it at rest")
            else:
                record.update(action="keep", reason="No adjacent rest-painted part; deleting visible RGBA would break exact rest identity")
            records.append(record)
        report["specks"][name] = {"components": len(components), "small_components": records,
            **{action + "_pixels": sum(r["pixels"] for r in records if r["action"] == action) for action in ["move", "delete", "keep"]}}
    report["motion_islands"] = []
    for item in policy.get("motion_islands", []):
        if item["view"] != view:
            continue
        part = names.index(item["part"])
        selected = np.zeros(owners.shape, dtype=bool)
        for x, y in item["points"]:
            selected[y, x] = owners[y, x] == part
        for component in components8(selected):
            border = _adjacent(component.astype(np.int16))
            border[component] = 0
            neighbours = [(int(border[owners == i].sum()), i) for i in range(len(names)) if i != part]
            shared, target = max(neighbours, key=lambda value: (value[0], -value[1]))
            if not shared:
                raise CutoutError("Motion island has no rest-adjacent owner: " + view + "/" + item["part"])
            owners[component] = target
            hidden[part][component] = False
            report["motion_islands"].append({"part": item["part"], "target": names[target],
                "pixels": int(component.sum()), "bbox": bbox(component), "shared_border_edges": shared,
                "evidence": item["evidence"], "reason": item["reason"]})
    for i in range(len(names)):
        hidden[i] &= (owners >= 0) & (owners != i)
    return owners, hidden, report


def chain_partition(root: Path, view: str, bones: dict, recipe: dict):
    """Map production link fractions onto the registered maquette chain axis."""
    if not recipe.get("articulated_chain"):
        return None
    original = read_json(root / f"source/production/{view}.json")["joints"]
    origin = np.asarray(original["chain_a"]["position"])
    axis = np.asarray(original["hook"]["position"]) - origin
    fractions = [float((np.asarray(original[name]["position"]) - origin) @ axis / (axis @ axis)) for name in ["chain_b", "chain_c"]]
    start = np.asarray(bones["chain"]["position"])
    delta = np.asarray(bones["hook"]["position"]) - start
    for name, fraction, parent in zip(["chain_b", "chain_c"], fractions, ["chain", "chain_b"]):
        bones[name] = {"position": (start + fraction * delta).tolist(), "parent": parent}
    bones["hook"]["parent"] = "chain_c"
    yy, xx = np.indices((NATIVE_SIZE, NATIVE_SIZE))
    along = (np.stack([xx + .5, yy + .5], axis=-1) - start) @ delta / (delta @ delta)
    return np.searchsorted(fractions, along, side="right")


def bbox(mask: np.ndarray):
    ys, xs = np.nonzero(mask)
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None


def save_image(path: Path, image: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    Path(str(path) + ".import").write_text('[remap]\n\nimporter="keep"\n')


def request_image(paint: Image.Image, owners: np.ndarray, part: int, hidden: np.ndarray) -> Image.Image:
    pixels = np.empty((*owners.shape, 4), dtype=np.uint8)
    pixels[:] = GREEN
    pixels[hidden] = MAGENTA
    pixels[owners == part] = np.asarray(paint)[owners == part]
    return Image.fromarray(pixels)


def contact_sheet(items: list[tuple[str, Image.Image]], output: Path, columns: int | None = None) -> None:
    columns = columns or PROOF_DEFAULTS["sheet_columns"]
    width = max(i.width for _, i in items)
    height = max(i.height for _, i in items)
    label = PROOF_DEFAULTS["sheet_label_height"]
    sheet = Image.new("RGBA", (columns * width, math.ceil(len(items) / columns) * (height + label)), GREEN)
    draw = ImageDraw.Draw(sheet)
    for i, (text, image) in enumerate(items):
        x, y = i % columns * width, i // columns * (height + label)
        draw.text((x + 2, y + 2), text, fill=(0, 0, 0, 255))
        sheet.alpha_composite(image, (x, y + label))
    save_image(output, sheet)


def rest_identity(root: Path) -> dict:
    _, config = load_case(root)
    result = {}
    for view, path in config["layouts"].items():
        layout = read_json(root / path)
        image = Image.new("RGBA", (NATIVE_SIZE, NATIVE_SIZE))
        for p in sorted(layout["parts"], key=lambda p: p["z_index"]):
            image.alpha_composite(Image.open(root / p["file"]).convert("RGBA"), tuple(p["offset"]))
        approved = Image.open(root / "source" / view / "processed.png").convert("RGBA")
        difference = np.asarray(image) != np.asarray(approved)
        result[view] = {"pixel_identical": not bool(difference.any()),
                        "different_pixels": int(difference.any(axis=2).sum()),
                        "rgba_sha256": pixel_digest(image)}
        save_image(root / "proof" / f"{view}_rest.png", image)
        save_image(root / "proof" / f"{view}_rest_3x.png", image.resize((765, 765), Image.Resampling.NEAREST))
    result["ok"] = all(r["pixel_identical"] for r in result.values())
    write_json(root / "proof/rest_identity.json", result)
    return result


def render_maquette(spec_path: Path, target: Path, blender: str) -> None:
    """Keep the protected spec intact; request every label in a derived copy."""
    spec = read_json(spec_path)
    spec["solo"] = list(spec["labels"])
    render_spec = target.parent / "render_spec.json"
    write_json(render_spec, spec)
    command = [blender, "-b", "--factory-startup", "-P", str(PROJECT / "spec/art_identity/maquettes/humanoid.py"),
               "--", str(render_spec.resolve()), str(target.resolve())]
    process = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (target.parent / "blender.log").write_text(process.stdout)
    if process.returncode:
        raise CutoutError(f"Blender exited {process.returncode}; see {target.parent / 'blender.log'}. No render was substituted.")


def render_manifest(directory: Path, spec: dict, allow_incomplete: bool = False) -> dict:
    """Validate the complete maquette input set before creating a case."""
    required = ["joints_px.json"] + [f"{view}_{kind}.png" for view in ["front", "rear"]
                for kind in ["parts", "clay", *["solo_" + name for name in spec["labels"]]]]
    missing = [name for name in required if not (directory / name).is_file()]
    if missing and (not allow_incomplete or any("_solo_" not in name for name in missing)):
        kind = "solo" if all("_solo_" in name for name in missing) else "maquette"
        raise CutoutError(f"Missing {kind} render(s) in {directory}: {', '.join(missing)}")
    files = {}
    for name in required:
        path = directory / name
        if name in missing:
            continue
        if path.suffix == ".png":
            with Image.open(path) as image:
                if image.size != (1024, 1024):
                    raise CutoutError(f"Maquette render must be 1024x1024: {path}")
                image.verify()
        files[name] = digest(path)
    joints = read_json(directory / "joints_px.json")
    for view in ["front", "rear"]:
        if set(joints.get(view, {})) != set(spec["joints"]):
            raise CutoutError("Maquette projected joint names differ from the spec: " + view)
    return {"files": files, "missing": missing, "complete": not missing}


def raw_for_job(job: Path, explicit: Path | None) -> Path:
    if explicit:
        return explicit
    raw = job / "raw.png"
    if raw.is_file():
        return raw
    raise CutoutError(f"Missing {raw}; use --front-raw/--rear-raw (the processed record alone cannot recover registration)")


def sample_exposure(root: Path, recipe: dict, task_id: str | None) -> None:
    if not recipe.get("motion_probe"):
        return
    if not task_id:
        branch = subprocess.check_output(["git", "branch", "--show-current"], cwd=PROJECT, text=True).strip()
        if not branch.startswith("codex/"):
            raise CutoutError("Pass --task-id for runner isolation outside a codex task branch")
        task_id = branch.removeprefix("codex/")
    samples = root / "proof/motion_samples.json"
    commands = [
        [sys.executable, str(PROJECT / "tools/godot_task_runner.py"), "--task-id", task_id, "--stream", "--", "godot",
         "--headless", "--path", str(PROJECT), "--script", str(root / recipe["motion_probe"]), "--", "--case", str(root / "cutout.json"), "--output", str(samples)],
        [sys.executable, str(root / recipe["exposure_tool"]), "--case", str(root), "--samples", str(samples)],
    ]
    for name, command in zip(["motion_samples", "exposure"], commands):
        process = subprocess.run(command, cwd=PROJECT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (root / "proof" / f"{name}.log").write_text(process.stdout)
        if process.returncode:
            raise CutoutError(f"{name} failed; see {root / 'proof' / (name + '.log')}")


def bind_layout(spec: dict, view: str, transform: Registration, projected_joints: dict, recipe: dict) -> tuple[dict, dict]:
    bones = {}
    for name, item in recipe["joints"].items():
        if "joint" in item:
            point = projected_joints[item["joint"]]
        else:
            shape = next(s for s in spec["shapes"] if s["part"] == item["plate"])
            point = projected(spec, np.mean(shape["pts"][:2], axis=0), view)
        bones[name] = {"position": transform.point(point), "parent": item["parent"]}
    mapping = {name: recipe["parts"][name] for name in spec["labels"]}
    return bones, mapping


def build_view(root: Path, spec: dict, view: str, palette: dict, recipe: dict, allow_incomplete: bool) -> dict:
    source = root / "source" / view
    record = read_json(source / "processed.json")
    paint = Image.open(source / "processed.png").convert("RGBA")
    if paint.size != (NATIVE_SIZE, NATIVE_SIZE) or pixel_digest(paint) != record["pixel_sha256"]:
        raise CutoutError("Approved processed paint size/digest differs from its record")
    if set(np.unique(np.asarray(paint)[..., 3])) - {0, 255}:
        raise CutoutError("Hidden underlays require process_raw's binary alpha")
    transform = registration(source / "raw.png", record)
    maquette = root / "source/maquette"
    names = list(spec["labels"])
    depths = camera_depths(spec, view)
    order = depth_order(depths)
    joints = read_json(maquette / "joints_px.json")[view]
    for name, point in spec["joints"].items():
        if not np.allclose(projected(spec, point, view), joints[name], atol=PROOF_DEFAULTS["joint_rounding_tolerance"]):
            raise CutoutError(f"Cached joints do not match the spec camera: {view}/{name}")
    registered = root / "registered"
    for kind in ["parts", "clay"]:
        save_image(registered / f"{view}_{kind}.png", transform.image(Image.open(maquette / f"{view}_{kind}.png").convert("RGBA")))
    label_image = Image.open(registered / f"{view}_parts.png")
    labels = decode_labels(label_image, palette, names, depths)
    owners, reassigned = nearest_labels(labels, np.asarray(paint)[..., 3] > 0, names, depths)
    original_owners = owners.copy()
    solos = {}
    for name in names:
        path = maquette / f"{view}_solo_{name}.png"
        if path.is_file():
            solo = transform.image(Image.open(path).convert("RGBA"))
            save_image(registered / path.name, solo)
            solos[name] = np.asarray(solo)[..., 3] > PROOF_DEFAULTS["mask_alpha_threshold"]
        else:
            solos[name] = np.zeros(owners.shape, dtype=bool)
    cleanup = {}
    hidden_masks = [hidden_region(solos[name], owners, i)[0] for i, name in enumerate(names)]
    if recipe.get("ownership_cleanup"):
        policy = recipe["ownership_cleanup"]
        trousers, material = material_reference(root, spec, palette, view, policy)
        owners, hidden_masks, cleanup = clean_ownership(owners, np.asarray(paint), names, solos, view, material, policy)
        np.save(registered / f"{view}_trousers.npy", trousers, allow_pickle=False)
        np.save(registered / f"{view}_original_owners.npy", original_owners, allow_pickle=False)
        write_json(root / f"proof/{view}_ownership_cleanup.json", cleanup)
    for i, name in enumerate(names):
        np.save(registered / f"{view}_hidden_{name}.npy", hidden_masks[i], allow_pickle=False)
    owner_image = Image.new("RGBA", paint.size)
    for i, name in enumerate(names):
        values = np.asarray(owner_image).copy()
        values[owners == i] = [*np.rint(np.asarray(spec["labels"][name]) * 255).astype(int), 255]
        owner_image = Image.fromarray(values.astype(np.uint8))
    save_image(root / "proof" / f"{view}_ownership_3x.png", owner_image.resize((765, 765), Image.Resampling.NEAREST))
    np.save(registered / f"{view}_owners.npy", owners, allow_pickle=False)
    joints, mapping = bind_layout(spec, view, transform, joints, recipe)
    chain_regions = chain_partition(root, view, joints, recipe)
    present = [name for i, name in enumerate(names) if np.any(owners == i)]
    pieces, piece_map = np.full(owners.shape, -1, dtype=np.int16), {}
    for i, name in enumerate(names):
        for original in range(len(names)):
            for link in (range(3) if name == "chain" and chain_regions is not None else [None]):
                mask = (owners == i) & (original_owners == original)
                if link is not None:
                    mask &= chain_regions == link
                if not mask.any():
                    continue
                piece = name + ("_from_" + names[original] if original != i else "") + ("_link_" + str(link) if link is not None else "")
                pieces[mask] = len(piece_map)
                piece_map[piece] = {"logical_part": name, "bone": ["chain", "chain_b", "chain_c"][link] if link is not None else mapping[name],
                                    "z_index": order.index(names[original]), "rest_depth_source": names[original]}
    piece_names = list(piece_map)
    ownership = {"priority_polygons": [[name, [[0, 0], [0, 0], [0, 0]]] for name in piece_names],
                 "pixel_overrides": [{"point": [int(x), int(y)], "name": piece_names[int(pieces[y, x])]}
                                     for y, x in zip(*np.nonzero(pieces >= 0))]}
    ownership_path = root / "recipes" / f"{view}_ownership.json"
    write_json(ownership_path, ownership)
    segmented = root / "segmented" / view
    split = segment(source / "processed.png", ownership_path, segmented)
    if not split["ok"] or Image.open(segmented / "reconstructed.png").tobytes() != paint.tobytes():
        raise CutoutError("Segmentation did not preserve all approved RGBA bytes")
    layout = {"version": 1, "facing": view, "canvas_size": [255, 255], "joints": joints,
              "parts": [], "rest_source": f"source/{view}/processed.png", "unmaterialized_parts": []}
    for p in split["parts"]:
        name = p["name"]
        p.update(file=f"segmented/{view}/{name}.png", **piece_map[name])
        layout["parts"].append(p)
    requests = []
    for i, name in enumerate(names):
        solo_path = maquette / f"{view}_solo_{name}.png"
        hidden = np.zeros(owners.shape, dtype=bool)
        outside = hidden.copy()
        available = solo_path.is_file()
        if available:
            hidden = hidden_masks[i]
            outside = solos[name] & (owners < 0)
        elif not allow_incomplete:
            raise CutoutError("Missing solo render: " + str(solo_path))
        request = request_image(paint, owners, i, hidden)
        relative = f"hidden_requests/{view}_{name}.png"
        save_image(root / relative, request)
        save_image(root / relative.replace(".png", "_4x.png"), request.resize((1020, 1020), Image.Resampling.NEAREST))
        entry = {"part": name, "view": view, "image": relative, "status": "measured" if available else "missing_solo_render",
                 "hidden_pixel_count": int(hidden.sum()) if available else None, "bounding_box": bbox(hidden),
                 "solo_outside_paint_pixels": int(outside.sum()) if available else None,
                 "motions": [], "exposure_status": "pending_motion_samples" if available else "unknown"}
        entry.update(material_neighbours(hidden, owners, i, names))
        entry["material"] = recipe.get("materials", {}).get(name, name + " approved paint")
        for relation in ["occluding_parts", "bordering_parts"]:
            for neighbour in entry[relation]:
                neighbour["material"] = recipe.get("materials", {}).get(neighbour["part"], neighbour["part"] + " approved paint")
        if hidden.any():
            entry["paint_nodes"] = []
            for link in (range(3) if name == "chain" and chain_regions is not None else [None]):
                mask = hidden if link is None else hidden & (chain_regions == link)
                if not mask.any():
                    continue
                suffix = "" if link is None else "_link_" + str(link)
                hidden_name = ("hidden_" + name if name in present else name) + suffix
                pixels = np.zeros((*owners.shape, 4), dtype=np.uint8)
                pixels[mask] = MAGENTA
                bounds = bbox(mask)
                hidden_file = f"hidden/{view}/{name}{suffix}.png"
                save_image(root / hidden_file, Image.fromarray(pixels).crop(bounds))
                layout["parts"].append({"name": hidden_name, "logical_part": name, "hidden_material": True,
                                        "file": hidden_file, "offset": bounds[:2],
                                        "bone": mapping[name] if link is None else ["chain", "chain_b", "chain_c"][link],
                                        "z_index": order.index(name) - len(names)})
                entry["paint_nodes"].append(hidden_name)
        elif name not in present:
            layout["unmaterialized_parts"].append({"part": name, "reason": entry["status"] if not available else "no_visible_or_occluded_pixels"})
        requests.append(entry)
    layout["landmarks"] = {}
    for side, label in recipe.get("sole_parts", {}).items():
        mask = owners == names.index(label)
        ys, xs = np.nonzero(mask)
        if not len(xs):
            raise CutoutError("Cannot obtain the existing foot-contact contour: " + label)
        bottom = ys.max()
        layout["landmarks"]["sole_" + side] = [float(np.median(xs[ys == bottom])), float(bottom + 1)]
    layout["logical_parts"] = names
    layout["maquette_depths"] = depths
    compatibility_path = root / f"source/production/{view}.json"
    rigid_mapping = {}
    if recipe.get("rigid_cloth"):
        original = read_json(compatibility_path)
        for name, item in recipe["rigid_cloth"].items():
            source_part = next(p for p in original["parts"] if p["name"] == item["production_part"])
            bone = source_part["bone"]
            parent = original["joints"][bone]["parent"]
            if mapping[name] != bone or joints[bone]["parent"] != parent:
                raise CutoutError(f"Rigid cloth must preserve production parenting: {view}/{name}")
            rigid_mapping[name] = {"production_part": source_part["name"], "bone": bone,
                                   "parent": parent, "attachment": "rigid_segment"}
            for part in layout["parts"]:
                if part.get("logical_part", part["name"]) == name and "equipment_slot" in source_part:
                    part["equipment_slot"] = source_part["equipment_slot"]
    if recipe["character_id"] == "chainbound_gaoler":
        original = read_json(compatibility_path)
        layout["motion_compatibility"] = {
            "joints": {n: j for n, j in original["joints"].items() if n.startswith("drape_")},
            "drape_end": original["landmarks"]["drape_end"],
            "basis": "Unpainted compatibility bones only; production restraint-chain solver has no output paint in this case"}
    write_json(root / f"layouts/{view}.json", layout)
    write_json(registered / f"{view}_registration.json", asdict(transform))
    write_json(registered / f"{view}_joints_px.json", {k: transform.point(v) for k, v in read_json(maquette / "joints_px.json")[view].items()})
    # Other anatomies may explicitly supply skin fields. The gaoler's approved
    # rigid_cloth recipe deliberately has none.
    fields = []
    for name, item in recipe.get("cloth", {}).items():
        parts = [p["name"] for p in layout["parts"] if p.get("logical_part", p["name"]) == name]
        if parts:
            fields.append({"name": name, "parts": parts, "bones": item["bones"], "bands": item["bands"], "grid": recipe["proof_defaults"]["mesh_grid"]})
    if fields:
        skin = {"facing": view, "input_layout": f"layouts/{view}.json", "output_layout": f"layouts/{view}_skinned.json", "fields": fields}
        skin_path = root / "recipes" / f"{view}_skinned.skin.json"
        write_json(skin_path, skin)
        apply_skin(root, skin_path)
    return {"requests": requests, "reassignment": reassigned, "depth_order": order,
            "bone_mapping": mapping, "rigid_cloth_mapping": rigid_mapping, "ownership_cleanup": cleanup,
            "unmaterialized_parts": layout["unmaterialized_parts"]}


def build(args) -> dict:
    root = args.case.resolve()
    spec = read_json(args.spec)
    recipe_path = args.rig_recipe or (GAOLER_RECIPE if args.spec.parent.name == "chainbound_gaoler" else None)
    if recipe_path is None:
        raise CutoutError("Supply --rig-recipe for this anatomy; joint parents/cloth weights are not inferred")
    recipe = read_json(recipe_path)
    if set(recipe["parts"]) != set(spec["labels"]):
        raise CutoutError("Rig recipe must bind every maquette label, with no extra parts")
    if set(recipe.get("cloth", {})) & set(recipe.get("rigid_cloth", {})):
        raise CutoutError("A cloth part cannot be both rigid and skinned")
    renders = render_manifest(args.renders, spec, args.allow_incomplete_renders) if args.renders else None
    if root.exists():
        if not args.resume_scaffold or read_json(root / "cutout.json")["source_baseline"].get("art_status") != "unbuilt":
            raise CutoutError("Choose a new case; --resume-scaffold accepts only an unbuilt init scaffold")
    else:
        init_case(root, recipe["character_id"], ["front", "rear"])
    (root / "source").mkdir(exist_ok=True)
    def copy(source, destination):
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.resolve() != destination.resolve():
            shutil.copyfile(source, destination)
    copy(args.spec, root / "source/spec.json")
    copy(recipe_path, root / "recipes/rig.json")
    for source in recipe.get("copy_files", []):
        copy(recipe_path.parent / source["from"], root / source["to"])
    for view, job, explicit in [("front", args.front_job, args.front_raw), ("rear", args.rear_job, args.rear_raw)]:
        for name in ["processed.png", "processed.json", "kit.json"]:
            copy(job / name, root / "source" / view / name)
        copy(raw_for_job(job, explicit), root / "source" / view / "raw.png")
    target = root / "source/maquette"
    if args.renders:
        target.mkdir(exist_ok=True)
        for name, expected in renders["files"].items():
            copy(args.renders / name, target / name)
            if digest(target / name) != expected:
                raise CutoutError("Maquette render changed while copying: " + name)
    else:
        render_maquette(args.spec, target, args.blender)
        renders = render_manifest(target, spec, args.allow_incomplete_renders)
    write_json(root / "source/maquette_manifest.json", renders)
    # The display transform belongs to the renderer. Requiring a recorded
    # palette avoids mistaking linear material RGB for color-managed PNG RGB.
    palette_path = args.palette
    if palette_path:
        palette = read_json(palette_path)
        copy(palette_path, root / "source/label_palette.json")
        provenance = palette_path.with_name(palette_path.stem + "_provenance.json")
        if provenance.is_file():
            copy(provenance, root / "source/label_palette_provenance.json")
    else:
        configs = sorted((Path(args.blender).resolve().parents[1] / "Resources").glob("*/datafiles/colormanagement/config.ocio"))
        config_path = args.color_config or (configs[-1] if configs else None)
        if config_path is None:
            raise CutoutError("Supply --palette or --color-config for this Blender installation")
        palette = display_palette(spec, config_path)
        write_json(root / "source/label_palette.json", palette)
        write_json(root / "source/label_palette_provenance.json", {"config": str(config_path), "sha256": digest(config_path),
                   "transform": "Linear Rec.709 -> Linear FilmLight E-Gamut -> AgX Base Rec.1886 tetrahedral LUT -> sRGB"})
    config_path, config = load_case(root)
    config.update({k: recipe[k] for k in ["motion", "clips", "rigid_bones", "contact_feet"]})
    config["design_placeholders"] = recipe.get("design_placeholders", {})
    write_json(config_path, config)
    views = {view: build_view(root, spec, view, palette, recipe, args.allow_incomplete_renders) for view in ["front", "rear"]}
    requests = [r for value in views.values() for r in value.pop("requests")]
    write_json(root / "hidden_requests/index.json", {"exposure_basis": "pending headless sampler measurement; unknown solos are not zero-sized requests", "requests": requests})
    config_path, config = load_case(root)
    if recipe.get("rear_fist_behind"):
        rear = read_json(root / config["layouts"]["rear"])
        config["draw_order_parts"] = {"rear": [p["name"] for p in rear["parts"] if p["bone"] in ["upper_fist", "fore_fist", "hand_fist"]]}
    config["source_baseline"] = {"kind": "maquette_registered_paint", "spec_sha256": digest(args.spec),
                                 "art_status": "hidden_material_incomplete", "production_integration": False}
    config["sources"] = sorted({str(p.relative_to(root)) for folder in ["source", "recipes", "registered", "probes"]
                                for p in (root / folder).rglob("*") if p.is_file() and p.suffix != ".import"}
                               | {item["to"] for item in recipe.get("copy_files", [])})
    write_json(config_path, config)
    report = {"views": views, "missing_solos": [f"{r['view']}_{r['part']}" for r in requests if r["status"] != "measured"],
              "hidden_layer_policy": "Camera-depth-ordered hidden underlays sit below the complete visible partition. This preserves 3D per-pixel occlusion at rest despite intersecting proxy parts; all underlays move with their own bones.",
              "depth_basis": "Mean primitive centre distance along humanoid.py camera axis; smaller is nearer",
              "chosen_defaults": PROOF_DEFAULTS, "rest_identity": rest_identity(root), "validation": validate(root)}
    report["ok"] = report["rest_identity"]["ok"] and report["validation"]["ok"]
    report["complete"] = report["ok"] and not report["missing_solos"] and not config["design_placeholders"]
    contact_sheet([(f"{r['view']}/{r['part']}\n" + (f"hidden={r['hidden_pixel_count']}" if r["status"] == "measured" else "UNKNOWN: MISSING SOLO"), Image.open(root / r["image"]).convert("RGBA")) for r in requests], root / "hidden_requests/contact_sheet.png")
    if report["ok"]:
        sample_exposure(root, recipe, getattr(args, "task_id", None))
        if recipe.get("motion_constraints_tool"):
            process = subprocess.run([sys.executable, str(root / recipe["motion_constraints_tool"]),
                "--case", str(root), "--bake-rear-arm"], cwd=PROJECT, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            (root / "proof/motion_constraints.log").write_text(process.stdout)
            if process.returncode:
                raise CutoutError("Motion constraint bake failed; see proof/motion_constraints.log")
            sample_exposure(root, recipe, getattr(args, "task_id", None))
    write_json(root / "build_report.json", report)
    for path in root.rglob("*.png"):
        Path(str(path) + ".import").write_text('[remap]\n\nimporter="keep"\n')
    baseline(root)
    return {k: report[k] for k in ["ok", "complete", "missing_solos", "rest_identity", "validation"]}


def part_palette(pixels: np.ndarray) -> tuple[np.ndarray, int]:
    """Seeded weighted RGB k-means; unique-color weights preserve pixel frequency."""
    colors, weights = np.unique(pixels.reshape(-1, 3), axis=0, return_counts=True)
    if not len(colors):
        raise CutoutError("Cannot derive a palette without approved donor pixels")
    colors = colors.astype(float)
    k = min(FILL_DEFAULTS["palette_k"], len(colors))
    rng = np.random.RandomState(FILL_DEFAULTS["seed"])
    centers = [colors[rng.choice(len(colors), p=weights / weights.sum())]]
    while len(centers) < k:
        distance = ((colors[:, None] - np.asarray(centers)[None]) ** 2).sum(-1).min(-1)
        probability = distance * weights
        centers.append(colors[rng.choice(len(colors), p=probability / probability.sum())])
    centers = np.asarray(centers)
    previous = None
    for iteration in range(FILL_DEFAULTS["kmeans_max_iterations"]):
        distances = ((colors[:, None] - centers[None]) ** 2).sum(-1)
        labels = distances.argmin(-1)
        if previous is not None and np.array_equal(previous, labels):
            palette = np.unique(np.rint(centers).clip(0, 255).astype(np.uint8), axis=0)
            return palette, iteration
        previous = labels
        for cluster in range(k):
            selected = labels == cluster
            centers[cluster] = (np.average(colors[selected], weights=weights[selected], axis=0)
                                if selected.any() else colors[(distances.min(-1) * weights).argmax()])
    raise CutoutError("Palette k-means did not converge")


def _adjacent(values: np.ndarray) -> np.ndarray:
    result = np.zeros_like(values)
    result[1:] += values[:-1]
    result[:-1] += values[1:]
    result[:, 1:] += values[:, :-1]
    result[:, :-1] += values[:, 1:]
    return result


def diffuse_rgb(rgb: np.ndarray, known: np.ndarray, target: np.ndarray) -> tuple[np.ndarray, dict]:
    """Harmonic diffusion with only approved fixed pixels and reflecting borders.

    Solve the four-neighbour discrete Laplace equation with diagonal-preconditioned
    conjugate gradients. Background/other materials are unknown, never black seeds.
    No random texture, new color source or extrapolated anatomy is introduced.
    """
    if not known.any():
        raise CutoutError("Diffusion needs approved source pixels")
    bounds = bbox(known | target)
    radius = FILL_DEFAULTS["radius"]
    left, top = max(0, bounds[0] - radius), max(0, bounds[1] - radius)
    right, bottom = min(known.shape[1], bounds[2] + radius), min(known.shape[0], bounds[3] + radius)
    crop = np.s_[top:bottom, left:right]
    fixed_mask = known[crop]
    unknown = (~fixed_mask)[..., None]
    fixed = np.where(fixed_mask[..., None], rgb[crop], 0.0)
    degree = _adjacent(np.ones(fixed_mask.shape))[..., None]
    def operator(values):
        return (degree * values - _adjacent(values)) * unknown
    x = np.broadcast_to(rgb[known].mean(0), fixed.shape).copy() * unknown
    residual = _adjacent(fixed) * unknown - operator(x)
    inverse_diagonal = 1 / np.maximum(degree, 1)
    z = residual * inverse_diagonal
    direction = z.copy()
    rz = (residual * z).sum((0, 1))
    tolerance = FILL_DEFAULTS["diffusion_residual_tolerance"]
    for iteration in range(FILL_DEFAULTS["diffusion_max_iterations"] + 1):
        error = np.abs(residual).max((0, 1))
        if error.max() <= tolerance:
            output = rgb.astype(float).copy()
            output[crop] = x + fixed
            return output, {"iterations": iteration, "max_residual": float(error.max()),
                            "domain": [left, top, right, bottom], "boundary": "reflecting",
                            "stencil": "four_neighbour", "solver": "diagonal_preconditioned_CG"}
        applied = operator(direction)
        denominator = (direction * applied).sum((0, 1))
        active = (error > tolerance) & (denominator > 0)
        alpha = np.divide(rz, denominator, out=np.zeros(3), where=active)
        x += direction * alpha
        residual -= applied * alpha
        z = residual * inverse_diagonal
        updated = (residual * z).sum((0, 1))
        beta = np.divide(updated, rz, out=np.zeros(3), where=active & (rz > 0))
        direction = z + direction * beta
        rz = updated
    raise CutoutError("Hidden-material diffusion did not converge")


def fill_pixels(paint: np.ndarray, visible: np.ndarray, hidden: np.ndarray,
                donor_rgb: np.ndarray, donor_mask: np.ndarray, method: str, palette_pixels=None, palette_reference=None, conditioning_visible=None, value_pixels=None, excluded_material=None) -> tuple[np.ndarray, dict]:
    own_count = int(visible.sum())
    if palette_pixels is None:
        palette_pixels = paint[visible, :3] if own_count >= FILL_DEFAULTS["palette_min_own_pixels"] else donor_rgb[donor_mask]
    if not len(palette_pixels):
        raise CutoutError("No same-material palette fallback for a part with fewer than 40 visible pixels")
    palette, iterations = part_palette(palette_pixels)
    quantization_palette = palette
    if palette_reference:
        distance = np.linalg.norm(to_lab(palette) - palette_reference["median_lab"], axis=-1)
        quantization_palette = palette[distance <= palette_reference["max_delta_e"]]
        if not len(quantization_palette):
            raise CutoutError("No sampled palette centroid satisfies the material gate")
    if excluded_material:
        distances = np.linalg.norm(to_lab(quantization_palette) - excluded_material["median_lab"], axis=-1)
        quantization_palette = quantization_palette[distances > excluded_material["delta_e"]]
        if not len(quantization_palette):
            raise CutoutError("All sampled palette centroids collide with the excluded material")
    seed = np.where(donor_mask[..., None], donor_rgb, 0).astype(np.uint8)
    conditioning_visible = visible if conditioning_visible is None else conditioning_visible
    seed[conditioning_visible] = paint[conditioning_visible, :3]
    known = conditioning_visible | donor_mask
    metrics = {}
    if hidden.any():
        if method == "telea":
            import cv2
            # Only same-material donors and this part are known; all other RGB
            # is masked out. A neighbour may legitimately cover a hidden pixel.
            filled = cv2.inpaint(seed, (~known).astype(np.uint8) * 255,
                                 FILL_DEFAULTS["radius"], cv2.INPAINT_TELEA)
        elif method == "diffusion":
            filled, metrics = diffuse_rgb(seed, known, hidden)
        else:
            raise CutoutError("Unknown hidden-fill method: " + method)
    else:
        filled = seed
    result = np.zeros_like(paint)
    result[visible] = paint[visible]
    choices = ((filled[hidden, None, :].astype(float) - quantization_palette[None].astype(float)) ** 2).sum(-1).argmin(-1)
    result[hidden, :3] = quantization_palette[choices]
    result[hidden, 3] = 255
    # Use the gate's edge definition/tone, without its alpha deletion or any
    # recoloring of visible paint. The edge is of the WHOLE part, not the hole.
    outline = hidden & silhouette_edge(visible | hidden, clipped_border=True)
    result[outline, :3] = FILL_DEFAULTS["outline_tone"]
    if value_pixels is not None and hidden.any():
        # Match the complete empirical same-part value distribution, not just
        # the diffusion's shadow-biased cluster. Keep diffuse spatial ranking.
        interior = hidden & ~outline
        target_l = np.sort(to_lab(value_pixels)[:, 0])
        positions = np.flatnonzero(interior)
        order = np.argsort(to_lab(filled[interior])[:, 0], kind="stable")
        quantiles = (np.arange(len(positions)) + int(outline.sum()) + 0.5) / int(hidden.sum())
        targets = target_l[np.minimum((quantiles * len(target_l)).astype(int), len(target_l) - 1)]
        choices = abs(targets[:, None] - to_lab(quantization_palette)[None, :, 0]).argmin(axis=1)
        result.reshape(-1, 4)[positions[order], :3] = quantization_palette[choices]
        actual_l = to_lab(result[hidden, :3])[:, 0]
        q25, q75 = np.percentile(target_l, [25, 75])
        metrics["value_distribution"] = {"basis": "same-view same-part visible RGBA; L* empirical quantiles, outlines included in gate",
            "visible_pixels": len(target_l), "visible_median_l": float(np.median(target_l)),
            "hidden_median_l": float(np.median(actual_l)),
            "median_difference_l": float(abs(np.median(actual_l) - np.median(target_l))),
            "visible_midtones_l": [float(q25), float(q75)],
            "hidden_midtones_pixels": int(((actual_l >= q25) & (actual_l <= q75)).sum())}
    return result, {"method": method if hidden.any() else "no_hidden_pixels", "diffusion": metrics,
                    "palette": palette.tolist(), "quantization_palette": quantization_palette.tolist(), "palette_iterations": iterations,
                    "palette_source": "own_visible" if own_count >= FILL_DEFAULTS["palette_min_own_pixels"] else "same_material_neighbours",
                    "palette_sample_pixels": len(palette_pixels), "own_visible_pixels": own_count,
                    "donor_visible_pixels": int(donor_mask.sum()),
                    "own_conditioning_pixels": int(conditioning_visible.sum()),
                    "conditioning_pixels_in_hidden_region": int((donor_mask & hidden).sum()),
                    "hidden_pixels": int(hidden.sum()), "outline_pixels": int(outline.sum())}


def same_material_donors(request: dict, names: list[str], owners: np.ndarray) -> tuple[list[str], np.ndarray]:
    """Allow only explicitly listed neighbours with the exact recorded material."""
    donors = sorted({n["part"] for relation in ["occluding_parts", "bordering_parts"]
                     for n in request[relation] if n["material"] == request["material"]
                     and n["part"] != request["part"]})
    return donors, np.isin(owners, [names.index(n) for n in donors])


def fill_donors(request: dict, names: list[str], views: dict, cross_view_enabled: bool):
    """Keep local donors first; sparse parts may use the approved paired view.

    Both paintings already share the registered native canvas. Borrow only the
    same label's visible RGB at those coordinates, without fitting or mirroring
    it. This conditions the diffusion; it never changes the target part mask.
    """
    paint, owners, _ = views[request["view"]]
    donors, mask = same_material_donors(request, names, owners)
    rgb, cross_view = paint[..., :3], None
    label = names.index(request["part"])
    if cross_view_enabled and int((owners == label).sum()) < FILL_DEFAULTS["palette_min_own_pixels"] and not mask.any():
        other_views = [(view, source, source_owners) for view, (source, source_owners, _) in views.items()
                       if view != request["view"] and np.any(source_owners == label)]
        if len(other_views) == 1:
            cross_view, source, source_owners = other_views[0]
            rgb, mask = source[..., :3], source_owners == label
    return donors, rgb, mask, cross_view


def array_digest(values: np.ndarray) -> str:
    return hashlib.sha256(np.ascontiguousarray(values).tobytes()).hexdigest()


def fill_hidden(args) -> dict:
    """Fill runtime underlays only; immutable requests remain the mask authority.

    Prepare every result before touching files. Subsequent calls accept only the
    previous generated bytes, so a director's later manual paint is never erased.
    """
    config_path, config = load_case(args.case)
    root = config_path.parent
    if not validate(root)["ok"] or not rest_identity(root)["ok"]:
        raise CutoutError("Validate the case and exact approved rest before filling")
    recipe_path = root / "recipes/hidden_fill.json"
    if recipe_path.exists():
        recipe = read_json(recipe_path)
        if recipe["parameters"] != FILL_DEFAULTS:
            raise CutoutError("Recorded fill parameters differ from this implementation")
    else:
        try:
            import cv2
            method = "telea"
        except ImportError:
            method = "diffusion"
        recipe = {"schema_version": 1, "method": method, "parameters": FILL_DEFAULTS,
                  "donor_policy": "Own visible paint and listed exact same-material neighbours only; no cross-view borrowing",
                  "palette_policy": "Own visible RGB when >=40 pixels; otherwise same-material neighbours; seeded weighted RGB k-means",
                  "outline_policy": "Filled pixels on the four-connected boundary of the whole part only; alpha unchanged"}
    if getattr(args, "cross_view_fallback", False):
        recipe["cross_view_fallback"] = "same_part"
        recipe["donor_policy"] = "Own visible paint and listed exact same-material neighbours; when own count <40 and no local neighbour, use the same part's visible paint in the paired view"
        recipe["palette_policy"] = "Own visible RGB when >=40 pixels; otherwise local same-material neighbours, then the approved same-part cross-view fallback; seeded weighted RGB k-means"
    if recipe.get("cross_view_fallback") not in [None, "same_part"]:
        raise CutoutError("Unknown recorded cross-view donor policy")
    if recipe["method"] not in ["telea", "diffusion"]:
        raise CutoutError("Unknown recorded fill method")
    old_path = root / "hidden_fills/index.json"
    old = read_json(old_path) if old_path.exists() else {}
    for relative, expected in old.get("protected_inputs", {}).items():
        if digest(local_path(root, relative)) != expected:
            raise CutoutError("Fill source/provenance changed: " + relative)
    old_records = {(r["view"], r["part"]): r for r in old.get("requests", [])}
    names = list(read_json(root / "source/spec.json")["labels"])
    rig_recipe = read_json(root / "recipes/rig.json")
    if rig_recipe.get("ownership_cleanup"):
        recipe["trousers_policy"] = {"parts": rig_recipe["ownership_cleanup"]["trouser_parts"],
            "donors": "view trousers core plus own still-owned original visible pixels; no coat, tabard or cross-view source",
            "quantization": "k6 sampled palette; hidden interiors use only centroids within the director's material DeltaE limit; outlines retain their tone",
            "max_delta_e": rig_recipe["ownership_cleanup"]["fill_median_max_delta_e"]}
    if rig_recipe.get("hidden_value_distribution"):
        recipe["value_distribution_policy"] = rig_recipe["hidden_value_distribution"]
        recipe["value_distribution_policy"]["quantization"] = "Empirical same-part visible L* quantiles assigned in diffusion L* order; nearest sampled k6 palette centroid; include unchanged outline in median gate"
        recipe["trousers_policy"]["superseded_parts"] = rig_recipe["hidden_value_distribution"]["parts"]
    requests = read_json(root / "hidden_requests/index.json")["requests"]
    if {(r["view"], r["part"]) for r in requests} != {(v, n) for v in config["layouts"] for n in names}:
        raise CutoutError("Hidden requests must cover every view and label")
    protected = {p for folder in ["source", "registered", "segmented"] for p in (root / folder).rglob("*")
                 if p.is_file() and p.suffix != ".import"}
    protected.update((root / "hidden_requests").glob("*.png"))
    protected.update(local_path(root, p) for p in config["layouts"].values())
    protected.add(root / "recipes/rig.json")
    protected_inputs = {str(p.relative_to(root)): digest(p) for p in sorted(protected)}
    views = {v: (np.array(Image.open(root / f"source/{v}/processed.png").convert("RGBA")),
                 np.load(root / f"registered/{v}_owners.npy", allow_pickle=False),
                 read_json(local_path(root, p))) for v, p in config["layouts"].items()}
    material_references = {}
    if rig_recipe.get("ownership_cleanup"):
        spec = read_json(root / "source/spec.json")
        palette = read_json(root / "source/label_palette.json")
        for view, (paint, owners, _) in views.items():
            depths = camera_depths(spec, view)
            labels = decode_labels(Image.open(root / f"registered/{view}_parts.png"), palette, names, depths)
            original, _ = nearest_labels(labels, paint[..., 3] > 0, names, depths)
            trousers, reference = material_reference(root, spec, palette, view, rig_recipe["ownership_cleanup"])
            solos = {n: np.asarray(Image.open(root / f"registered/{view}_solo_{n}.png"))[..., 3] > PROOF_DEFAULTS["mask_alpha_threshold"] for n in names}
            expected, masks, cleanup = clean_ownership(original, paint, names, solos, view, reference, rig_recipe["ownership_cleanup"])
            if (not np.array_equal(original, np.load(root / f"registered/{view}_original_owners.npy", allow_pickle=False))
                    or not np.array_equal(expected, owners)
                    or not np.array_equal(trousers, np.load(root / f"registered/{view}_trousers.npy", allow_pickle=False))
                    or cleanup != read_json(root / f"proof/{view}_ownership_cleanup.json")
                    or any(not np.array_equal(mask, np.load(root / f"registered/{view}_hidden_{name}.npy", allow_pickle=False)) for name, mask in zip(names, masks))):
                raise CutoutError("Ownership cleanup differs from source-derived recipe: " + view)
            material_references[view] = reference
    prepared, records, pending = [], [], []
    for request in requests:
        view, part = request["view"], request["part"]
        paint, owners, layout = views[view]
        visible = owners == names.index(part)
        image_path = local_path(root, request["image"])
        request_pixels = np.array(Image.open(image_path).convert("RGBA"))
        hidden = np.all(request_pixels == MAGENTA, axis=-1)
        solo = np.asarray(Image.open(root / f"registered/{view}_solo_{part}.png").convert("RGBA"))[..., 3] > PROOF_DEFAULTS["mask_alpha_threshold"]
        expected_hidden, _ = hidden_region(solo, owners, names.index(part))
        if rig_recipe.get("ownership_cleanup"):
            expected_hidden = np.load(root / f"registered/{view}_hidden_{part}.npy", allow_pickle=False)
        if (request["status"] != "measured" or int(hidden.sum()) != request["hidden_pixel_count"]
                or not np.array_equal(hidden, expected_hidden)
                or not np.array_equal(request_pixels, np.asarray(request_image(Image.fromarray(paint), owners, names.index(part), hidden)))):
            raise CutoutError(f"Hidden request does not match approved ownership/solo: {view}/{part}")
        materials = rig_recipe.get("materials", {})
        if request["material"] != materials.get(part, part + " approved paint"):
            raise CutoutError(f"Request material differs from rig recipe: {view}/{part}")
        for relation, neighbours in material_neighbours(hidden, owners, names.index(part), names).items():
            expected = [dict(n, material=materials.get(n["part"], n["part"] + " approved paint")) for n in neighbours]
            if request[relation] != expected:
                raise CutoutError(f"Request neighbours differ from approved ownership: {view}/{part}")
        donors, donor_rgb, donor_mask, donor_view = fill_donors(request, names, views, recipe.get("cross_view_fallback") == "same_part")
        palette_pixels, trousers_reference, conditioning_visible = None, None, visible
        value_pixels = None
        excluded_material = None
        cleanup_policy = rig_recipe.get("ownership_cleanup", {})
        if view == "front" and part in cleanup_policy.get("tabard_transfer_parts", []):
            excluded_material = dict(material_references[view]["tabard_cloth"], delta_e=cleanup_policy["tabard_gate_delta_e"])
        value_policy = rig_recipe.get("hidden_value_distribution", {})
        if part in value_policy.get("parts", []):
            if not visible.any():
                raise CutoutError("No visible same-part value reference: " + view + "/" + part)
            donors, donor_view = [part], None
            donor_rgb, donor_mask = paint[..., :3], visible.copy()
            palette_pixels = paint[visible, :3]
            value_pixels = palette_pixels
        elif part in rig_recipe.get("ownership_cleanup", {}).get("trouser_parts", []):
            donors, donor_view = ["trousers_core"], None
            donor_rgb = paint[..., :3]
            donor_mask = np.load(root / f"registered/{view}_trousers.npy", allow_pickle=False)
            original_owners = np.load(root / f"registered/{view}_original_owners.npy", allow_pickle=False)
            conditioning_visible = visible & (original_owners == names.index(part))
            palette_pixels = np.concatenate([donor_rgb[donor_mask], paint[conditioning_visible, :3]])
            trousers_reference = material_references[view]["trousers"]
        record = {"view": view, "part": part, "material": request["material"],
                  "request": request["image"], "request_sha256": digest(image_path),
                  "visible_mask_sha256": array_digest(visible), "hidden_mask_sha256": array_digest(hidden),
                  "donor_mask_sha256": array_digest(donor_mask), "donor_parts": donors,
                  "own_conditioning_mask_sha256": array_digest(conditioning_visible),
                  "source_paint_sha256": digest(root / f"source/{view}/processed.png"),
                  "visible_rgba_sha256": array_digest(paint[visible]),
                  "donor_rgb_sha256": array_digest(donor_rgb[donor_mask]),
                  "own_visible_pixels": int(visible.sum()), "donor_visible_pixels": int(donor_mask.sum()),
                  "hidden_pixels": int(hidden.sum()), "seed": FILL_DEFAULTS["seed"]}
        if donor_view:
            record["cross_view_donor"] = {"view": donor_view, "part": part,
                "source": f"source/{donor_view}/processed.png",
                "source_sha256": digest(root / f"source/{donor_view}/processed.png"),
                "owners": f"registered/{donor_view}_owners.npy",
                "owners_sha256": digest(root / f"registered/{donor_view}_owners.npy"),
                "visible_pixels": int(donor_mask.sum()),
                "registration": "native_canvas_coordinates_untransformed",
                "reason": "Own visible count <40 and no listed same-material neighbour in this view"}
        missing = int(visible.sum()) < FILL_DEFAULTS["palette_min_own_pixels"] and not donor_mask.any()
        if missing:
            todo = f"TODO_DESIGN_hidden_donor_{view}_{part}"
            pending.append(todo)
            record.update(status="pending_design", method="unfilled", palette=[], outline_pixels=0,
                          design_placeholder=todo, reason="Fewer than 40 own visible pixels and no eligible palette donor")
            result = np.zeros_like(paint)
            result[visible] = paint[visible]
            result[hidden] = MAGENTA
        else:
            result, metrics = fill_pixels(paint, visible, hidden, donor_rgb, donor_mask, recipe["method"], palette_pixels,
                dict(trousers_reference, max_delta_e=rig_recipe["ownership_cleanup"]["fill_median_max_delta_e"]) if trousers_reference else None, conditioning_visible, value_pixels, excluded_material)
            record.update(metrics, status="filled" if hidden.any() else "no_hidden_pixels")
            if excluded_material:
                record["excluded_tabard_reference"] = excluded_material
            if donor_view:
                record["palette_source"] = "same_part_other_view"
        if value_pixels is not None:
            record["palette_source"] = "same_view_same_part_visible_value_distribution"
            record["value_distribution"] = record["diffusion"].pop("value_distribution", {})
            if len(value_pixels) < FILL_DEFAULTS["palette_min_own_pixels"]:
                record["design_placeholder"] = "TODO_DESIGN_sparse_value_reference_" + view + "_" + part
                record["design_reason"] = "Literal same-view reference has fewer than 40 pixels; brighter core fallback needs director's decision"
        if trousers_reference and hidden.any():
            median = np.median(result[hidden, :3], axis=0)
            delta = float(np.linalg.norm(to_lab(median) - trousers_reference["median_lab"]))
            record.update(palette_source="trousers_core_and_remaining_own_visible", material_median_rgb=median.tolist(),
                          trousers_median_delta_e=delta, trousers_reference=trousers_reference)
            if delta > rig_recipe["ownership_cleanup"]["fill_median_max_delta_e"]:
                raise CutoutError(f"Trouser fill median exceeds material gate: {view}/{part}: {delta}")
        if not np.array_equal(result[visible], paint[visible]):
            raise CutoutError(f"Rest-visible paint changed: {view}/{part}")
        runtime_images = []
        if hidden.any():
            matches = [p for p in layout["parts"] if p.get("hidden_material") and p.get("logical_part") == part]
            covered = np.zeros_like(hidden)
            previous = old_records.get((view, part))
            previous_outputs = {r["output"]: r for r in previous.get("outputs", [previous])} if previous else {}
            outputs = []
            for node in matches:
                runtime_path = local_path(root, node["file"])
                before = np.array(Image.open(runtime_path).convert("RGBA"))
                x, y = node["offset"]
                crop = np.s_[y:y + before.shape[0], x:x + before.shape[1]]
                mask = before[..., 3] == 255
                if np.any(mask & ~hidden[crop]) or np.any(covered[crop] & mask):
                    raise CutoutError(f"Underlay alpha/offset differs from request: {view}/{part}")
                covered[crop] |= mask
                old_output = previous_outputs.get(node["file"])
                current_digest = digest(runtime_path)
                if old_output:
                    if current_digest != old_output["output_sha256"]:
                        raise CutoutError("Preserve manually changed hidden paint: " + node["file"])
                elif not np.all(before[mask] == MAGENTA):
                    raise CutoutError("Underlay already contains unrecorded paint: " + node["file"])
                after = before.copy()
                after[mask, :3] = result[crop][mask, :3]
                output = {"output": node["file"], "original_sha256": old_output["original_sha256"] if old_output else current_digest,
                          "output_rgba_sha256": array_digest(after), "alpha_sha256": array_digest(after[..., 3]),
                          "remaining_magenta_pixels": int(np.all(after == MAGENTA, axis=-1).sum())}
                outputs.append(output)
                runtime_images.append((output, Image.fromarray(after)))
            if not np.array_equal(covered, hidden):
                raise CutoutError(f"Hidden underlays do not cover request: {view}/{part}")
            record["outputs"] = outputs
            record["remaining_magenta_pixels"] = sum(r["remaining_magenta_pixels"] for r in outputs)
            if len(outputs) == 1:
                record.update(outputs[0])
            if not missing and record["remaining_magenta_pixels"]:
                raise CutoutError(f"Filled underlay still contains magenta: {view}/{part}")
        preview = np.full_like(paint, GREEN)
        preview[visible | hidden] = result[visible | hidden]
        record["preview"] = f"hidden_fills/{view}_{part}.png"
        records.append(record)
        prepared.append((record, runtime_images, Image.fromarray(preview)))
    # No source/runtime changes have been made before the complete preflight above.
    write_json(recipe_path, recipe)
    for record, runtime_images, preview in prepared:
        for output, runtime_image in runtime_images:
            save_image(root / output["output"], runtime_image)
            output["output_sha256"] = digest(root / output["output"])
        if len(runtime_images) == 1:
            record.update(runtime_images[0][0])
        save_image(root / record["preview"], preview)
        record["preview_sha256"] = digest(root / record["preview"])
    contact_sheet([(f"{r['view']}/{r['part']}\n{r['status']} {r['hidden_pixels']} px", preview)
                   for r, _, preview in prepared], root / "hidden_fills/contact_sheet.png")
    review_decisions = {r["design_placeholder"]: r["design_reason"] for r in records if "design_reason" in r}
    config.setdefault("design_placeholders", {}).update(review_decisions)
    manifest = {"schema_version": 1, "complete": not pending, "method": recipe["method"],
                "review_decisions": review_decisions,
                "parameters": FILL_DEFAULTS, "implementation_sha256": digest(Path(__file__)),
                "recipe_sha256": digest(recipe_path), "protected_inputs": protected_inputs,
                "pending_design": pending, "requests": records}
    write_json(old_path, manifest)
    config["hidden_fill"] = {"recipe": "recipes/hidden_fill.json", "manifest": "hidden_fills/index.json", "pending_design": pending}
    config["sources"] = sorted(set(config["sources"]) | {"recipes/hidden_fill.json", "hidden_fills/index.json"})
    config["source_baseline"]["art_status"] = "hidden_material_incomplete" if pending else "hidden_filled_pending_director_review"
    write_json(config_path, config)
    report = {"complete": not pending, "method": recipe["method"], "requests": len(records),
              "filled_requests": sum(r["status"] == "filled" for r in records), "pending_design": pending, "review_decisions": review_decisions,
              "cross_view_requests": sum("cross_view_donor" in r for r in records),
              "remaining_magenta_pixels": sum(r.get("remaining_magenta_pixels", 0) for r in records),
              "rest_identity": rest_identity(root), "validation": validate(root)}
    report["ok"] = report["rest_identity"]["ok"] and report["validation"]["ok"]
    if not all(digest(root / p) == value for p, value in protected_inputs.items()):
        raise CutoutError("Protected source/request/visible bytes changed")
    if report["ok"]:
        sample_exposure(root, rig_recipe, getattr(args, "task_id", None))
    if not all(digest(root / p) == value for p, value in protected_inputs.items()):
        raise CutoutError("Protected source/request/visible bytes changed during sampling")
    write_json(root / "proof/hidden_fill_report.json", report)
    baseline(root)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    if sys.argv[1:2] == ["fill-hidden"]:
        parser.add_argument("command", choices=["fill-hidden"])
        parser.add_argument("--case", type=Path, required=True)
        parser.add_argument("--task-id")
        parser.add_argument("--cross-view-fallback", action="store_true", help="Record explicit same-part donor fallback for sparse parts without local same-material neighbours")
        args = parser.parse_args()
        action = fill_hidden
    else:
        args = build_arguments(parser)
        action = build
    try:
        import json
        report = action(args)
        print(json.dumps(report, indent=2))
        return 0 if report["ok"] else 1
    except (CutoutError, OSError, ValueError, KeyError, ImportError, subprocess.CalledProcessError) as error:
        print(f"MAQUETTE_CUTOUT: FAIL: {error}", file=sys.stderr)
        return 1


def build_arguments(parser):
    for name in ["spec", "front-job", "rear-job", "case"]:
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ["front-raw", "rear-raw", "renders", "palette", "rig-recipe", "color-config"]:
        parser.add_argument("--" + name, type=Path)
    parser.add_argument("--blender", default=BLENDER)
    parser.add_argument("--task-id", help="Headless sampler runner isolation; defaults to the current codex branch id")
    parser.add_argument("--resume-scaffold", action="store_true")
    parser.add_argument("--allow-incomplete-renders", action="store_true", help="Explicit diagnostic build; unknown solos stay unknown")
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(main())

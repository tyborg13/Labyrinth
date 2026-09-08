from __future__ import annotations

import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

from .cases import CutoutError, ID, digest, fresh_directory, load_case, local_path, read_json, write_json


def segment(source_path: Path, ownership_path: Path, output: Path) -> dict:
    """Copy manually assigned source pixels; do not infer anatomical ownership."""
    source = Image.open(source_path).convert("RGBA")
    if source.size != (255, 255):
        raise CutoutError("Register the complete source to 255x255 before splitting; never resize each crop independently")
    definition = read_json(ownership_path)
    entries = definition.get("priority_polygons", [])
    if not entries:
        raise CutoutError("ownership.json needs priority_polygons: [[part_name, [[x,y], ...]], ...]")
    owners: dict[tuple[int, int], str] = {}
    names: list[str] = []
    for name, polygon in entries:
        if not ID.fullmatch(name) or len(polygon) < 3:
            raise CutoutError("Ownership needs named polygons with at least three points")
        if name not in names:
            names.append(name)
        mask = Image.new("1", source.size)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=1)
        for y in range(source.height):
            for x in range(source.width):
                if mask.getpixel((x, y)) and source.getpixel((x, y))[3]:
                    owners.setdefault((x, y), name)
    for override in definition.get("pixel_overrides", []):
        point, name = tuple(override["point"]), override["name"]
        if name not in names or len(point) != 2 or not all(isinstance(v, int) for v in point) or not (0 <= point[0] < 255 and 0 <= point[1] < 255) or not source.getpixel(point)[3]:
            raise CutoutError("A pixel override must name an existing part and an opaque source pixel")
        owners[point] = name
    unassigned = [p for y in range(255) for x in range(255) if source.getpixel(p := (x, y))[3] and p not in owners]
    root = fresh_directory(output)
    overview = Image.new("RGBA", source.size)
    reconstruction = Image.new("RGBA", source.size)
    parts = []
    for index, name in enumerate(names):
        image = Image.new("RGBA", source.size)
        color = ((index * 83 + 71) % 200 + 40, (index * 137 + 41) % 200 + 40, (index * 61 + 91) % 200 + 40, 255)
        for point, owner in owners.items():
            if owner == name:
                # Preserve partial alpha instead of turning every owned edge opaque.
                image.putpixel(point, source.getpixel(point))
                overview.putpixel(point, color)
                reconstruction.putpixel(point, source.getpixel(point))
        bbox = image.getbbox()
        if not bbox:
            raise CutoutError(f"Empty ownership polygon: {name}")
        image.crop(bbox).save(root / f"{name}.png")
        parts.append({"name": name, "file": f"{name}.png", "offset": list(bbox[:2]), "bbox": list(bbox)})
    for point in unassigned:
        overview.putpixel(point, (255, 0, 255, 255))
    overview.save(root / "ownership.png")
    reconstruction.save(root / "reconstructed.png")
    report = {"ok": not unassigned, "source_sha256": digest(source_path), "ownership_sha256": digest(ownership_path), "parts": parts, "unassigned_pixels": len(unassigned), "unassigned_coordinates": unassigned, "coordinate_space": "unchanged registered source pixels"}
    write_json(root / "segmentation.json", report)
    return report


def _smooth(value: float) -> float:
    value = min(1.0, max(0.0, value))
    return value * value * (3.0 - 2.0 * value)


def skin_mesh(part: dict, image_size: tuple[int, int], field: dict) -> dict:
    """Use one shared source-space weight field for every overlapping piece."""
    x0, y0 = part["offset"]
    width, height = image_size
    step_x, step_y = field.get("grid", [2, 1])
    if not all(isinstance(v, int) and 1 <= v <= 32 for v in [step_x, step_y]):
        raise CutoutError("Skin grid uses positive integer pixel steps (1..32)")
    bones = field["bones"]
    bands = field["bands"]
    if len(bones) != len(bands) + 1 or len(set(bones)) != len(bones):
        raise CutoutError("Skin field needs one blend band per successive bone")
    for band in bands:
        if not math.isfinite(band["width"]) or band["width"] <= 0 or math.hypot(*band["axis"]) == 0:
            raise CutoutError("Skin blend width and axis must be nonzero")
    xs = list(range(x0, x0 + width, step_x)) + [x0 + width]
    ys = list(range(y0, y0 + height, step_y)) + [y0 + height]
    points = [[x, y] for y in ys for x in xs]
    weights = {name: [] for name in bones}
    for x, y in points:
        values = [1.0]
        for band in bands:
            ax, ay = band["axis"]
            length = math.hypot(ax, ay)
            cx, cy = band["center"]
            factor = _smooth(((x - cx) * ax + (y - cy) * ay) / length / band["width"] + 0.5)
            values = [v * (1.0 - factor) for v in values] + [factor]
        for name, value in zip(bones, values):
            weights[name].append(round(value, 8))
    triangles = []
    for row in range(len(ys) - 1):
        for column in range(len(xs) - 1):
            i = row * len(xs) + column
            triangles.extend([[i, i + 1, i + len(xs) + 1], [i, i + len(xs) + 1, i + len(xs)]])
    return {"equipment_slot": part.get("equipment_slot", ""), "name": "Skin_" + part["name"], "replaces_part": part["name"], "file": part["file"], "offset": part["offset"], "bbox": [x0, y0, x0 + width, y0 + height], "z_index": part.get("z_index", 0), "vertices": points, "uvs": [[x - x0, y - y0] for x, y in points], "triangles": triangles, "weights": weights, "family": field["name"], "coordinate_space": "registered source pixels; crop-local UV pixels"}


def apply_skin(case: Path, recipe_path: Path) -> Path:
    config_path, config = load_case(case)
    root = config_path.parent
    recipe = read_json(recipe_path)
    facing = recipe["facing"]
    if facing not in config["layouts"]:
        raise CutoutError(f"Unknown case facing: {facing}")
    source_path = local_path(root, recipe["input_layout"])
    target_path = local_path(root, recipe["output_layout"])
    if target_path.exists():
        raise CutoutError("Skin output already exists; use a new layout version")
    recipe_copy = root / "recipes" / (target_path.stem + ".skin.json")
    if recipe_copy.exists() and recipe_copy.resolve() != recipe_path.resolve():
        raise CutoutError("Recipe destination already exists")
    layout = read_json(source_path)
    parts = {p["name"]: p for p in layout["parts"]}
    replaced: set[str] = set()
    additions = []
    for field in recipe["fields"]:
        if any(b not in layout["joints"] for b in field["bones"]):
            raise CutoutError("Skin field names an unknown joint")
        for name in field["parts"]:
            if name not in parts or name in replaced:
                raise CutoutError(f"Unknown or repeatedly skinned part: {name}")
            replaced.add(name)
            part = parts[name]
            with Image.open(local_path(root, part["file"])) as image:
                additions.append(skin_mesh(part, image.size, field))
    layout["joint_meshes"] = [m for m in layout.get("joint_meshes", []) if m.get("replaces_part") not in replaced] + additions
    write_json(target_path, layout)
    config["layouts"][facing] = str(target_path.relative_to(root))
    # The original input and recipe remain inspectable and participate in proof hashes.
    write_json(recipe_copy, recipe)
    config["sources"] = sorted(set(config.get("sources", []) + [str(source_path.relative_to(root)), str(recipe_copy.relative_to(root))]))
    write_json(config_path, config)
    return target_path


def replace_part(case: Path, facing: str, part_name: str, image_path: Path, offset: tuple[int, int]) -> Path:
    config_path, config = load_case(case)
    root = config_path.parent
    if facing not in config["layouts"]:
        raise CutoutError("Unknown facing")
    layout_path = local_path(root, config["layouts"][facing])
    layout = read_json(layout_path)
    matches = [p for p in layout["parts"] if p["name"] == part_name]
    if len(matches) != 1:
        raise CutoutError("Select one existing named part")
    if any(m.get("replaces_part") == part_name for m in layout.get("joint_meshes", [])) or matches[0].get("cape_segment"):
        raise CutoutError("This part is skinned: register its new paint and rebuild its mesh/UVs with a skin recipe")
    image = Image.open(image_path)
    if image.mode != "RGBA" or image.getbbox() is None:
        raise CutoutError("Replacement must be nonempty RGBA")
    relative = f"assets/{facing}/{part_name}_{digest(image_path)[:12]}.png"
    destination = root / relative
    if destination.exists():
        raise CutoutError("That replacement is already present; use a new variant or edit registration explicitly")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(image_path, destination)
    Path(str(destination) + ".import").write_text('[remap]\n\nimporter="keep"\n')
    matches[0].update({"file": relative, "offset": list(offset)})
    layout.pop("rest_source_sha256", None)
    # A prior assembled rest must not masquerade as the replacement silhouette.
    layout.pop("rest_source", None)
    write_json(layout_path, layout)
    return destination

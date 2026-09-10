"""Explicit background ownership and whole-source registration, no repaint."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

SOURCE = Path(__file__).resolve().parents[1] / "source"
for name in ["rear", "hidden_calyx", "hidden_roots"]:
    path = SOURCE / (name + "_generated.png")
    original = Image.open(path).convert("RGBA")
    mask = Image.new("L", original.size)
    mask.putdata([0 if max(r, g, b) - min(r, g, b) < 12 and min(r, g, b) > 135 else 255 for r, g, b, _ in original.getdata()])
    bbox = mask.getbbox()
    scale = 251 / (bbox[3] - bbox[1])
    size = (round((bbox[2] - bbox[0]) * scale), 251)
    offset = (round(127 - size[0] / 2), 2)
    # Neutral highlights inside these explicit solid material regions belong
    # to the creature. They must not become alpha holes through chroma masking.
    solid_polygons = []
    if name == "rear":
        solid_polygons = [[[80, 25], [120, 13], [152, 25], [171, 42], [153, 73], [102, 79], [76, 49]], [[82, 76], [163, 77], [185, 150], [166, 209], [130, 214], [105, 203], [73, 166], [67, 114]]]
        draw = ImageDraw.Draw(mask)
        for polygon in solid_polygons:
            draw.polygon([((x - offset[0]) / scale + bbox[0], (y - offset[1]) / scale + bbox[1]) for x, y in polygon], fill=255)
    mask.save(SOURCE / (name + "_source_ownership_mask.png"))
    owned = original.copy()
    owned.putalpha(mask)
    assert all(before[:3] == after[:3] for before, after in zip(original.getdata(), owned.getdata()))
    owned.save(SOURCE / (name + "_owned.png"))
    recipe = {"source": path.name, "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "source_bbox": bbox, "background_rule": "Exclude neutral pixels where channel range <12 and min RGB >135", "foreground_inclusion_polygons_registered": solid_polygons, "source_rgb_preserved": True, "mask": name + "_source_ownership_mask.png", "mask_sha256": hashlib.sha256((SOURCE / (name + "_source_ownership_mask.png")).read_bytes()).hexdigest()}
    if name == "rear":
        registered = Image.new("RGBA", (255, 255))
        registered.paste(owned.crop(bbox).resize(size, Image.Resampling.NEAREST), offset)
        registered.save(SOURCE / "rear_registered.png")
        recipe.update({"target_size": [255, 255], "uniform_scale": scale, "raster_size_rounding": size, "offset": offset, "resampler": "nearest; entire creature at once"})
    (SOURCE / (name + "_registration.json")).write_text(json.dumps(recipe, indent=2) + "\n")

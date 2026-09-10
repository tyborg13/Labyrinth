"""Cinder Droplet v01 registration: copy existing paint, never synthesize pixels.

The generated rear has a painted neutral checkerboard. Its explicitly recorded
matte excludes neutral light background pixels; source RGB is retained verbatim.
This is a source ownership/registration recipe, not an art generator.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

CASE = Path(__file__).resolve().parent / "v01"
SOURCE = CASE / "source"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    (CASE / "recipes").mkdir(exist_ok=True)
    front = Image.open(SOURCE / "front_original.png")
    front.save(SOURCE / "front_registered.png")
    rear_source = Image.open(SOURCE / "rear_generated.png").convert("RGBA")
    # The dark, warm creature is distinct from the bright neutral matte.
    # Selection is bounded to the inspected source silhouette rectangle.
    rear = Image.new("RGBA", rear_source.size)
    for y in range(327, 1022):
        for x in range(208, 1085):
            r, g, b, a = rear_source.getpixel((x, y))
            if min(r, g, b) >= 145 and max(r, g, b) - min(r, g, b) <= 35:
                continue
            rear.putpixel((x, y), (r, g, b, a))
    rear.getchannel("A").save(SOURCE / "rear_explicit_matte.png")
    # One uniform registration of the complete image; never fit individual limbs.
    crop = [208, 327, 1085, 1022]
    size = [175, 139]
    rear = rear.crop(crop).resize(size, Image.Resampling.NEAREST)
    registered = Image.new("RGBA", (255, 255))
    registered.paste(rear, (40, 80))
    registered.save(SOURCE / "rear_registered.png")
    # The infill's whole creature is registered at the same source height. Only
    # explicit interior belly/socket polygons will be selected in author_rig.py.
    infill = Image.open(SOURCE / "hidden_belly_generated.png").convert("RGBA")
    infill = infill.crop((290, 322, 946, 962)).resize((131, 128), Image.Resampling.NEAREST)
    hidden = Image.new("RGBA", (255, 255))
    hidden.paste(infill, (62, 80))
    hidden.save(SOURCE / "hidden_belly_registered.png")
    recipe = {
        "coordinate_space": "255x255 native pixels; nearest-neighbor whole-source registration; unchanged front RGBA",
        "projection": "2:1 board; front faces lower-left, rear faces upper-right; reflected views use the shared facing policy",
        "front": {"input": "source/front_original.png", "output": "source/front_registered.png", "crop": [0,0,255,255], "size": [255,255], "offset": [0,0]},
        "rear": {"input": "source/rear_generated.png", "output": "source/rear_registered.png", "crop": crop, "size": size, "offset": [40,80], "matte": "source/rear_explicit_matte.png", "background_rule": "Within the inspected source bounding rectangle, exclude pixels with min(R,G,B)>=145 and max-min<=35; no other RGB edits. All outside pixels excluded.", "registration_rounding": "Uniform 0.2 scale rounded to whole pixels; 877x695 -> 175x139."},
        "hidden_belly": {"input": "source/hidden_belly_generated.png", "output": "source/hidden_belly_registered.png", "crop": [290,322,946,962], "size": [131,128], "offset": [62,80], "selection": "Only interior concealed belly and socket ownership, never cap/face or background."},
        "digests": {p.name: digest(p) for p in sorted(SOURCE.glob("*.png"))}
    }
    (CASE / "recipes" / "registration.json").write_text(json.dumps(recipe, indent=2)+"\n")
    review = Image.new("RGBA", (510,255))
    review.paste(front, (0,0))
    review.paste(registered, (255,0))
    review.resize((1020,510), Image.Resampling.NEAREST).save(CASE / "source" / "registered_views_review.png")


if __name__ == "__main__":
    main()

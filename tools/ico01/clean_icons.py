#!/usr/bin/env python3
"""Remove sheet-slicing scraps from 64 px icons, then center each icon and bring it to the family's size (longest side 56 px).
Run once from the repo root; kept as the record of how the files changed."""
from pathlib import Path
from PIL import Image

ICONS = Path("assets/art/icons")
# icon: False keeps the painted size and only removes the scrap and centers; True also brings it to 56 px.
EDITS = {"blink": False, "block": True, "cinder_marks": True, "fatigue": True, "raise_terrain": True, "ranged": True, "rewards": False,
         "run": True, "targeting": False, "terrain_burst": True, "traps": False, "detonate_cinders": True, "frost_armor": True, "loadout": True}
TARGET = 56

def components(image):
    width, height = image.size
    pixels = image.load()
    seen, found = set(), []
    for start in ((x, y) for y in range(height) for x in range(width)):
        if start in seen or pixels[start][3] <= 8:
            continue
        stack, part = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            part.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    near = (x + dx, y + dy)
                    if 0 <= near[0] < width and 0 <= near[1] < height and near not in seen and pixels[near][3] > 8:
                        seen.add(near)
                        stack.append(near)
        found.append(part)
    return found

def remove_scraps(image):
    parts = components(image)
    body = [pixel for part in parts if len(part) > 60 for pixel in part]
    removed = 0
    for part in parts:
        if len(part) > 60:
            continue
        if min(max(abs(x - bx), abs(y - by)) for x, y in part for bx, by in body) >= 9:
            for pixel in part:
                image.putpixel(pixel, (0, 0, 0, 0))
                removed += 1
    return removed

def epx(image):
    """Scale2x: doubles pixel art without blurring its edges."""
    width, height = image.size
    source, out = image.load(), Image.new("RGBA", (width * 2, height * 2))
    target = out.load()
    def at(x, y):
        return source[min(max(x, 0), width - 1), min(max(y, 0), height - 1)]
    for y in range(height):
        for x in range(width):
            p, a, b, c, d = at(x, y), at(x, y - 1), at(x + 1, y), at(x - 1, y), at(x, y + 1)
            target[2 * x, 2 * y] = a if c == a and c != d and a != b else p
            target[2 * x + 1, 2 * y] = b if a == b and a != c and b != d else p
            target[2 * x, 2 * y + 1] = c if d == c and d != b and c != a else p
            target[2 * x + 1, 2 * y + 1] = d if b == d and b != a and d != c else p
    return out

def premultiplied_resize(image, size):
    out = image.convert("RGBa").resize(size, Image.Resampling.BOX).convert("RGBA")
    out.putalpha(out.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    return out

for name, rescale in EDITS.items():
    path = ICONS / f"{name}.png"
    image = Image.open(path).convert("RGBA")
    assert image.size == (64, 64), path
    removed = remove_scraps(image)
    art = image.crop(image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox())
    if rescale:
        scale = TARGET / max(art.size)
        size = (max(1, round(art.size[0] * scale)), max(1, round(art.size[1] * scale)))
        art = premultiplied_resize(epx(epx(art)), size)
    out = Image.new("RGBA", (64, 64))
    out.paste(art, ((64 - art.size[0]) // 2, (64 - art.size[1]) // 2))
    out.save(path)
    print(name, "removed", removed, "art", art.size)

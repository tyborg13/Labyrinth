"""Lossless native frame IO, with explicit full-frame/crop coordinates.

The capture environment never changes. ``size`` is the original image space;
``crop`` is [x, y, width, height] in that space. A storage index describes each
surface because rig layers (512 square), rest art (255 square), and review
canvases (1920x1080) coexist in the same capture. Old captures need no index.
Logical filenames remain stable; ``stored_file`` names the actual codec file.
"""
from __future__ import annotations

from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import struct

from PIL import Image

MARGIN_PX = 16
RAW_MAGIC = b"UCAPRGBA"
RAW_HEADER = struct.Struct("<8sII")
INDEX_NAME = "native_storage.json"


def crop_rect(bounds, size, margin=MARGIN_PX):
    """Round outward, add the approved margin, then clamp to the frame."""
    x, y, w, h = bounds
    left = max(0, min(size[0], math.floor(x) - margin))
    top = max(0, min(size[1], math.floor(y) - margin))
    right = max(left, min(size[0], math.ceil(x + w) + margin))
    bottom = max(top, min(size[1], math.ceil(y + h) + margin))
    if right == left or bottom == top:
        raise ValueError("Action canvas does not intersect the frame")
    return left, top, right - left, bottom - top


def to_crop(point, crop):
    return point[0] - crop[0], point[1] - crop[1]


def to_full(point, crop):
    return point[0] + crop[0], point[1] + crop[1]


def crop_box(box, crop):
    return (*to_crop(box[:2], crop), *to_crop(box[2:], crop))


@lru_cache(maxsize=32)
def _read_index(path, modified_ns, length):
    return json.loads(path.read_bytes())


def storage_record(path):
    path = Path(path).absolute()
    for parent in path.parents:
        index = parent / INDEX_NAME
        if index.is_file():
            stat = index.stat()
            records = _read_index(index, stat.st_mtime_ns, stat.st_size).get("files", {})
            return parent, records.get(path.relative_to(parent).as_posix())
        # A case root bounds the search; do not accidentally adopt another run.
        if (parent / "cutout.json").is_file():
            break
    return path.parent, None


def stored_path(path):
    root, record = storage_record(path)
    return root / record["stored_file"] if record else Path(path)


def frame_digest(path):
    return hashlib.sha256(stored_path(path).read_bytes()).hexdigest()


def frame_exists(path):
    return stored_path(path).is_file()


def read_pixels(path):
    """Read stored pixels, without expanding a crop. RGBA needs only Pillow."""
    path = Path(path)
    if path.suffix == ".rgba":
        data = path.read_bytes()
        if len(data) < RAW_HEADER.size:
            raise ValueError("Truncated RGBA header: " + str(path))
        magic, width, height = RAW_HEADER.unpack_from(data)
        if magic != RAW_MAGIC or not width or not height or len(data) != RAW_HEADER.size + width * height * 4:
            raise ValueError("Invalid RGBA frame: " + str(path))
        return Image.frombytes("RGBA", (width, height), data[RAW_HEADER.size:])
    with Image.open(path) as image:
        return image.copy()


def load_frame(path, manifest=None, row=None, *, cropped=False):
    """Return an image in its original space (or stored pixels with cropped=True).

    Explicit row geometry overrides manifest geometry. Automatic index lookup
    makes nested pieces, floor probes, sheets and reels use the same mapping.
    No alpha compositing is used when pasting: hidden RGB remains lossless.
    Outside an opaque board crop we restore that clip's full reference frame.
    Transparent rig surfaces use exact transparent padding instead.
    """
    if not isinstance(path, (str, Path)):
        return Image.open(path)  # Legacy BytesIO source-art callers.
    path = Path(path)
    root, record = storage_record(path)
    if record is None and manifest is None and not (root / INDEX_NAME).is_file():
        # Support crop-only manifests, without requiring our optional index.
        for parent in path.absolute().parents:
            candidate = parent / "frames.json"
            if candidate.is_file():
                stat = candidate.stat()
                candidate_manifest = _read_index(candidate, stat.st_mtime_ns, stat.st_size)
                if "crop" in candidate_manifest:
                    manifest = candidate_manifest
                    root = parent
                break
    geometry = record or (dict(manifest or {}, **(row or {})))
    actual = root / record["stored_file"] if record else path
    image = read_pixels(actual)
    crop = geometry.get("crop")
    if cropped or crop is None:
        return image
    size = tuple(geometry["size"])
    x, y, width, height = crop
    if any(type(v) is not int for v in (*size, *crop)) or min(width, height) <= 0 or min(x, y) < 0 or x + width > size[0] or y + height > size[1]:
        raise ValueError("Invalid native crop: " + str(path))
    if image.size != (width, height):
        raise ValueError("Stored frame dimensions differ from crop: " + str(path))
    reference = geometry.get("reference")
    result = read_pixels(root / reference).convert("RGBA") if reference else Image.new("RGBA", size)
    if result.size != size:
        raise ValueError("Full reference dimensions differ: " + str(path))
    result.paste(image.convert("RGBA"), (x, y))
    return result


def export_frame(path, directory):
    """Materialize a full PNG for legacy concat demuxers in caller-owned scratch.

    Callers use a temporary directory for the lifetime of their encoder. The
    cache key includes payload bytes, so a changed capture cannot reuse a still.
    """
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256((str(Path(path).absolute()) + frame_digest(path)).encode()).hexdigest()
    target = directory / (key + '.png')
    if not target.is_file():
        load_frame(path).save(target)
    return target

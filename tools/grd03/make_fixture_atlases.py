"""Write disposable ramp-index PNGs from the fixture rects in the ground style."""
import argparse
import json
from pathlib import Path
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from build_atlases import encode_electrified

STYLE = ROOT / "data/ground_surface_style.json"
OUTPUT = ROOT / "output/grd-03"
GREYS = (0, 64, 128, 191, 255)
KINDS = ("fire", "ice", "rubble", "electrified")


def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))


def write_atlas(path, rects, sector_count=0):
    width = max(x + w for x, _, w, _ in rects)
    height = max(y + h for _, y, _, h in rects)
    pixels = bytearray(width * height * 4)
    for decal, (x, y, w, h) in enumerate(rects):
        for dy in range(h):
            for dx in range(w):
                px = (2 * dx + 1 - w) / w
                py = (2 * dy + 1 - h) / h
                if px * px + py * py < 1:
                    value = GREYS[(dx + dy + decal) % len(GREYS)]
                    i = ((y + dy) * width + x + dx) * 4
                    pixels[i:i + 4] = bytes((value, value, value, 255))
    if sector_count:
        encode_electrified(pixels, width, rects, sector_count)
    stride = width * 4
    rows = b"".join(b"\0" + pixels[i:i + stride] for i in range(0, len(pixels), stride))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", choices=KINDS, help="Generate only this fixture atlas.")
    args = parser.parse_args()
    kinds = (args.kind,) if args.kind else KINDS
    style = json.loads(STYLE.read_text())
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / ".gdignore").touch()
    for kind in kinds:
        spec = style[kind]["fixture_atlas"]
        path = ROOT / spec["path"]
        if not path.resolve().is_relative_to(OUTPUT.resolve()):
            raise ValueError(f"Fixture atlas must stay under {OUTPUT}: {path}")
        write_atlas(path, spec["rects"], style[kind]["sector_count"] if kind == "electrified" else 0)
    print(f"GRD-03 FIXTURE ATLASES: {len(kinds)} PNGs in {OUTPUT / 'atlases'}")


if __name__ == "__main__":
    main()

"""Derive a palette-match reference with front-only parts removed (director step).

`--match-front` fits a rear's Lab mean/spread to the whole front; a saturated part that only exists on the front (the
gaoler's oxblood tabard) then pushes every rear part toward its colour. This writes a copy of the front with those
regions made transparent, to be used as the `--match-front` reference for the rear.
Usage: python3 mask_reference.py FRONT_PROCESSED OUT CONFIG.json   (CONFIG: tone_region.py regions; lab_scale ignored)
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from art_identity_gate import mask_reference, rgba  # noqa: E402


def mask(src: Path, out: Path, regions: list) -> None:
    mask_reference(rgba(src), regions, report=print).save(out)


if __name__ == "__main__":
    mask(Path(sys.argv[1]), Path(sys.argv[2]), json.loads(Path(sys.argv[3]).read_text()))

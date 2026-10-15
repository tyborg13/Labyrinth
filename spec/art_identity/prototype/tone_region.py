"""Deterministic local tone edit on a raw painting (director step; generalises maquettes/chainbound_gaoler/tone_tabard.py).

Usage: python3 tone_region.py SRC OUT CONFIG.json
CONFIG is a list of regions applied in order; each region:
  {"name": str, "box": [x0, y0, x1, y1],            raw-pixel box the edit may touch
   "seed": [x, y] | null,                           flood-fill (8-way) from here through matching pixels; null = whole box
   "min_lum": 0..1, "max_lum": 0..1,                Rec.601 luminance window of pixels that may change
   "min_chroma": 0..1, "max_chroma": 0..1,         optional inclusive RGB (max-min)/255 chroma limits
   "max_value": 0..1,                              optional inclusive max(R,G,B)/255 cap, not luminance
   "hue_deg": [lo, hi] | null,                     optional hue window (lo > hi wraps)
   "exclude_green": true,                           never touch key-green background
   "lab_scale": [L, a, b]}                          CIE Lab multipliers (prototype/match_palette.py conversion)
Prints the changed pixel count per region.
Omitting max_chroma/max_value preserves existing recipes exactly. All luminance/chroma/value limits must be
finite numbers in 0..1, not booleans, and each minimum must be <= its maximum. Selectors combine before seed
filling and Lab scaling. The shared reference-mask selector supports them too.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from art_identity_gate import region_mask, rgba, tone_region  # noqa: E402


def tone(src: Path, out: Path, regions: list) -> None:
    tone_region(rgba(src), regions, report=print).save(out)


if __name__ == "__main__":
    tone(Path(sys.argv[1]), Path(sys.argv[2]), json.loads(Path(sys.argv[3]).read_text()))

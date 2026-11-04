"""rr-58 roots and proof-only defaults; no motion or presentation tuning."""
from pathlib import Path
import sys
import math
import hashlib
import json

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / 'tools'), str(Path(__file__).parent)]
from cutout_pipeline.cases import read_json, write_json, digest

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-58')
RIGS = {'chainbound_gaoler': 'rr44', 'hoarfrost_seer': 'rr10'}
DEFAULTS = {'fps': 60, 'canvas_size_px': 1024, 'source_offset_px': 384,
            'strip_gutter_px': 24, 'magnification': 3, 'sample_timeout_s': 180,
            'request_padding_px': 3, 'triangle_batch_size': 128, 'cpu_workers': 4,
            'proof_background_rgba': [42, 42, 47, 255]}


def assets(rig):
    return ROOT / 'assets/units' / (rig + '_cutout')


def case(rig):
    return ROOT / 'experiments/cutouts' / rig / 'rr58'


def baseline_case(rig):
    return case(rig).parent / RIGS[rig]


def release(rig, view, clip):
    motion = read_json(assets(rig) / 'humanoid_v2/compiled_motion.json')
    item = 'chain' if rig == 'chainbound_gaoler' else 'staff'
    return motion.get('view_release_at', {}).get(view, {}).get(
        clip, motion['clips'][clip].get('release_at', {})).get(item, float('inf'))


def frame_count(definition):
    # Godot roundi, including positive half frames (Python round uses ties-even).
    return math.floor(definition['seconds'] * DEFAULTS['fps'] + .5)


def layout_fingerprint(layout):
    # Bind every value without duplicating multi-megabyte immutable skin grids.
    return hashlib.sha256(json.dumps(layout, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

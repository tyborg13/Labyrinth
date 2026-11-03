"""rr-44's protected inputs and derived-case paths."""
from pathlib import Path
import sys
sys.path[:0] = [str(Path(__file__).resolve().parents[3]), str(Path(__file__).resolve().parents[3]/'tools')]
from cutout_pipeline.cases import read_json, digest

PROJECT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).parent/'rr42'
CASE = Path(__file__).parent/'rr44'
ASSETS = PROJECT/'assets/units/chainbound_gaoler_cutout'
STAGED = PROJECT/'spec/peer_benchmark/staged/rr-44'
JOBS = PROJECT/'spec/art_identity/jobs/chainbound_gaoler'
VIEWS = {'front': ('mq3_front_v4', 'mq3_front_v5'), 'rear': ('mq3_rear_v3', 'mq3_rear_v4')}
DEFAULTS = {'crop_context_px': 12, 'crop_zoom': 4, 'sample_timeout_s': 85,
            'sweep_shard_frames': 2, 'sweep_shard_timeout_s': 85, 'sweep_workers': 8,
            'matrix_tolerance': 0.0001, 'presentation_angle_tolerance_deg': .751}


def protected():
    files = read_json(STAGED/'provenance.json')['files']
    for name, expected in files.items():
        if digest(STAGED/name) != expected:
            raise ValueError('Changed protected rr-44 input: '+name)
    return files

"""CPU estimate of the three director-traced rear shoulder pinholes."""
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings, clean_metrics
from maquette_motion.pixels import rest_identity, PROOF_DEFAULTS
from rr15_cpu_proof import CASE, SCRATCH, frame_state

FRAMES = (('tether', 61), ('jab', 26), ('jab', 27))
BEFORE = PROJECT / 'tests/rr11/rr15/rear_shoulder_before.png'


def composite(layers):
    image = Image.new('RGBA', (PROOF_DEFAULTS['canvas_size'],) * 2)
    for part, paint, _ in sorted(layers, key=lambda row: row[0]['z_index']):
        image.alpha_composite(Image.fromarray(paint))
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(SCRATCH):
        raise ValueError('CPU proof stays under ' + str(SCRATCH))
    samples, inputs = read_json(CASE / 'proof/samples.json'), bindings(CASE)
    if samples['inputs'] != inputs or not samples['ok'] or samples['errors']:
        raise ValueError('Regenerate bound samples before shoulder proof')
    args.output.mkdir(parents=True, exist_ok=True)
    model = CpuPose(CASE, read_json(CASE / 'layouts/rear.json'))
    overrides = {p['name']: model.image(p['file']).copy() for p in model.layout['parts']}
    overrides['hidden_upper_near'] = np.asarray(Image.open(BEFORE).convert('RGBA'))
    rows = []
    for clip, frame in FRAMES:
        pose = next(r for r in samples['samples'] if r['view'] == 'rear' and
                    r['kind'] == 'presented' and r['clip'] == clip and r['frame'] == frame)
        current = frame_state(model, pose)
        before = frame_state(model, pose, overrides)
        metrics = clean_metrics(current[0])
        rejected = {name: metrics[name] for name in ('outside_pixels', 'exposed_outline_pixels',
            'dark_slab_blocks', 'outline_outside_pixels', 'stray_components') if metrics[name]}
        stem = f'rear_{clip}_{frame:04d}'
        composite(before[0]).save(args.output / (stem + '_before.png'))
        composite(current[0]).save(args.output / (stem + '_after.png'))
        ok = not current[-1] and not rejected and before[-1] == [2]
        rows.append({'clip': clip, 'frame': frame, 'ok': ok, 'holes_before': before[-1],
                     'holes_after': current[-1], 'rejected_metrics': rejected,
                     'before': stem + '_before.png', 'after': stem + '_after.png'})
        print('RR15 CPU REAR %s %d: %s (holes %s -> %s; rejected metrics %d)' %
              (clip.upper(), frame, 'PASS' if ok else 'FAIL', before[-1], current[-1], len(rejected)))
    if inputs != bindings(CASE):
        raise ValueError('Inputs changed during CPU proof')
    rest = rest_identity(CASE)
    write_json(args.output / 'report.json', {'native_pixels': False,
        'scope': 'CPU native estimate only; director windowed recapture required',
        'ok': rest['ok'] and all(row['ok'] for row in rows), 'frames': rows,
        'rest': rest, 'inputs': inputs, 'before_fixture_sha256': digest(BEFORE)})
    return int(not rest['ok'] or any(not row['ok'] for row in rows))


if __name__ == '__main__':
    raise SystemExit(main())

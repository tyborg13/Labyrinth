"""Feedback-3 CPU seam diagnostic. GPU acceptance still requires recapture."""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings, clean_metrics
from humanoid_cutout.native_exceptions import load, JOINT_HOLE_RULE
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from maquette_motion.pixels import PROOF_DEFAULTS

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
SCRATCH = Path('/private/tmp/labyrinth_codex/rr-13')
PROGRESS_INTERVAL_FRAMES = 50


def frame_state(model, row):
    layers, maps = model.layers(row)
    seams = model.masks(row, model.layout['proof_joint_seams'], maps)
    references = model.masks(row, model.layout['proof_rest_holes'], maps)
    seam = np.logical_or.reduce(seams)
    owners = posed_owners(layers, model.layout['parts'], row['bones'], PROOF_DEFAULTS['source_offset'])
    holes = joint_holes(owners > 0, seam, owners, references)
    return layers, owners, seam, references, holes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--view', choices=('front', 'rear'), required=True)
    parser.add_argument('--samples', type=Path, default=CASE / 'proof/samples.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(SCRATCH):
        raise ValueError('CPU diagnostic output must stay under ' + str(SCRATCH))
    args.output.mkdir(parents=True, exist_ok=True)
    report = read_json(args.samples)
    inputs = bindings(CASE)
    if report['inputs'] != inputs or not report['ok'] or report['errors']:
        raise ValueError('Refresh headless bone evidence before CPU diagnostic proof')
    layout = read_json(CASE / f'layouts/{args.view}.json')
    model = CpuPose(CASE, layout)
    exceptions = load(CASE)
    failures, materials, approved, count = [], [], [], 0
    for row in report['samples']:
        if row['view'] != args.view or row['kind'] != 'presented':
            continue
        layers, owners, seam, references, holes = frame_state(model, row)
        key = (row['view'], row['clip'], row['frame'])
        if holes:
            record = dict(view=key[0], clip=key[1], frame=key[2], pixel_counts=holes)
            if (*key, JOINT_HOLE_RULE) in exceptions:
                approved.append(record)
            else:
                failures.append(record)
                composite = Image.new('RGBA', (PROOF_DEFAULTS['canvas_size'],) * 2)
                for part, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
                    composite.alpha_composite(Image.fromarray(image))
                composite.save(args.output / ('%s_%s_%04d.png' % key))
        metric = clean_metrics(layers)
        if metric['dark_slab_blocks'] or metric['exposed_outline_pixels']:
            materials.append(dict(view=key[0], clip=key[1], frame=key[2],
                dark_slab_blocks=metric['dark_slab_blocks'], exposed_outline_pixels=metric['exposed_outline_pixels']))
        count += 1
        if count % PROGRESS_INTERVAL_FRAMES == 0:
            print('CPU %s: %d frames; %d unapproved hole frames' % (args.view, count, len(failures)), flush=True)
    write_json(args.output / 'report.json', {'native_pixels': False,
        'scope': 'director-requested CPU-posed triangles and rigid layers; not GPU acceptance',
        'ok': not failures and not materials, 'inputs': inputs, 'frames': count,
        'new_joint_holes': failures, 'material_failures': materials, 'approved_holes': approved})
    print('RR13 CPU %s: %s (%d frames; %d unapproved joint-hole frames; %d material failures)' %
        (args.view.upper(), 'PASS' if not failures and not materials else 'FAIL', count, len(failures), len(materials)))
    for row in failures:
        print(json.dumps(row))
    return int(bool(failures or materials))


if __name__ == '__main__':
    raise SystemExit(main())

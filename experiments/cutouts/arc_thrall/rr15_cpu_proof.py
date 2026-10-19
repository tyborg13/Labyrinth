"""Thrall CPU posing estimate, explicitly separate from native acceptance."""
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings, clean_metrics
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from maquette_motion.pixels import PROOF_DEFAULTS

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
SCRATCH = Path('/private/tmp/labyrinth_codex/rr-15')
PROGRESS_INTERVAL_FRAMES = 50


def frame_state(model, pose, overrides=None):
    layers, maps = model.layers(pose, overrides)
    seams = model.masks(pose, model.layout['proof_joint_seams'], maps)
    references = model.masks(pose, model.layout['proof_rest_holes'], maps)
    seam = np.logical_or.reduce(seams)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'], PROOF_DEFAULTS['source_offset'])
    defects = joint_holes(owners > 0, seam, owners, references)
    return layers, owners, seam, references, defects


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--view', choices=('front', 'rear'), required=True)
    parser.add_argument('--samples', type=Path, default=CASE / 'proof/samples.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(SCRATCH):
        raise ValueError('CPU diagnostic output must stay under ' + str(SCRATCH))
    args.output.mkdir(parents=True, exist_ok=True)
    samples, inputs = read_json(args.samples), bindings(CASE)
    if samples['inputs'] != inputs or not samples['ok'] or samples['errors']:
        raise ValueError('Refresh headless bone samples before CPU proof')
    model = CpuPose(CASE, read_json(CASE / f'layouts/{args.view}.json'))
    failures, count = [], 0
    for pose in samples['samples']:
        if pose['view'] != args.view or pose['kind'] != 'presented':
            continue
        layers, owners, seam, references, defects = frame_state(model, pose)
        metric = clean_metrics(layers)
        rejected = {name: metric[name] for name in ('outside_pixels', 'exposed_outline_pixels',
            'dark_slab_blocks', 'outline_outside_pixels', 'stray_components') if metric[name]}
        if rejected or defects:
            failures.append(dict(clip=pose['clip'], frame=pose['frame'], holes=defects, metrics=rejected))
            composite = Image.new('RGBA', (PROOF_DEFAULTS['canvas_size'],) * 2)
            for part, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
                composite.alpha_composite(Image.fromarray(image))
            composite.save(args.output / ('%s_%s_%04d.png' % (args.view, pose['clip'], pose['frame'])))
        count += 1
        if count % PROGRESS_INTERVAL_FRAMES == 0:
            print('CPU %s: %d frames; %d failing frames' % (args.view, count, len(failures)), flush=True)
    if bindings(CASE) != inputs:
        raise ValueError('Inputs changed during CPU proof; discard this estimate')
    write_json(args.output / 'report.json', {'native_pixels': False, 'ok': not failures,
        'scope': 'CPU posed triangles/rigid surfaces estimate only; director GPU recapture required',
        'view': args.view, 'frames': count, 'failures': failures, 'inputs': inputs})
    print('RR15 CPU %s: %s (%d frames; %d failing frames)' %
        (args.view.upper(), 'FAIL' if failures else 'PASS', count, len(failures)))
    return int(bool(failures))


if __name__ == '__main__':
    raise SystemExit(main())

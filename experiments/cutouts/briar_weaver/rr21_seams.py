"""Every-frame CPU construction diagnostics; never native acceptance evidence."""
import argparse
import numpy as np
from PIL import Image
from rr21_case import CASE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.anatomy import load
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import clean_metrics, bindings
from humanoid_cutout.silhouette_gates import joint_holes, posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS


def state(model, pose):
    layers, maps = model.layers(pose)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'],
                          PROOF_DEFAULTS['source_offset'], load(CASE)['ownership'])
    seams = np.logical_or.reduce(model.masks(pose, model.layout['proof_joint_seams'], maps))
    references = model.masks(pose, model.layout['proof_rest_holes'], maps)
    pockets = joint_holes(owners > 0, seams, owners, references, pocket_details=True)
    return layers, maps, owners, pockets


def report(samples, move_only=False):
    if samples['inputs'] != bindings(CASE): raise ValueError('Refresh samples before CPU seam diagnostics')
    fingerprint = digest(CASE / 'proof/logs/samples.json')
    result = {}
    for view in ('front', 'rear'):
        model = CpuPose(CASE, read_json(CASE / f'layouts/{view}.json'))
        failures, count = [], 0
        for pose in samples['samples']:
            if pose['view'] != view or pose['kind'] != 'presented' or (move_only and pose['clip'] != 'move'): continue
            layers, _, _, pockets = state(model, pose)
            metrics = clean_metrics(layers)
            defects = {k: metrics[k] for k in ('outside_pixels', 'exposed_outline_pixels',
                'dark_slab_blocks', 'outline_outside_pixels', 'stray_components') if metrics[k]}
            count += 1
            if pockets or defects:
                failures.append({'clip': pose['clip'], 'frame': pose['frame'], 'pockets': pockets, 'metrics': defects})
                image = Image.new('RGBA', (PROOF_DEFAULTS['canvas_size'],) * 2)
                for _, pixels, _ in sorted(layers, key=lambda r: r[0]['z_index']): image.alpha_composite(Image.fromarray(pixels))
                path = CASE / f'proof/seam_cpu/{view}_{pose["clip"]}_{pose["frame"]:04d}.png'
                path.parent.mkdir(parents=True, exist_ok=True)
                image.save(path)
        result[view] = {'ok': not failures, 'frames': count, 'failures': failures, 'native_pixels': False,
                        'samples_sha256': fingerprint}
        print(f'RR21 {view.upper()} CPU SEAMS/CLEAN: {"FAIL" if failures else "PASS"} ({count} frames; {len(failures)} failures)', flush=True)
    if samples['inputs'] != bindings(CASE) or fingerprint != digest(CASE / 'proof/logs/samples.json'):
        raise ValueError('Inputs changed during CPU seam diagnostics')
    name = 'move_cpu_seams' if move_only else 'cpu_seams'
    write_json(CASE / f'proof/logs/{name}.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--move-only', action='store_true')
    args = parser.parse_args()
    result = report(read_json(CASE / 'proof/logs/samples.json'), args.move_only)
    raise SystemExit(int(any(not r['ok'] for r in result.values())))

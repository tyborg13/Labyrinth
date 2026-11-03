"""Full posed CPU coverage diagnostic. Never native renderer acceptance."""
import argparse
from collections import Counter
from copy import deepcopy
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from rr32_case import PROJECT, CASE
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import bindings, EPSILON
from humanoid_cutout.bone_evidence import read_report, evidence_errors
from humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.source_space import DetachedSource, pocket_report
from maquette_motion import pixels


CPU_MASK_UV_MARGIN_PX = 1  # Conservative nearest-sampling margin, proof only.


def coverage_cpu(case, layout):
    """Skip only triangles whose UV bounds cannot sample the reference mask.

    Rear rest-hole templates span the entire source canvas. Their transparent
    triangles dominate diagnostic time. Vertices, weights and every possibly
    opaque fragment remain exactly the shared CPU raster's input.
    """
    cpu = CpuPose(case, layout)
    for record in layout['proof_rest_holes']:
        if 'mesh_template' not in record: continue
        path = record['mesh_template']
        mesh = deepcopy(read_json(case / path))
        mask = cpu.image(record['file'])[..., 3] > 0
        y, x = np.nonzero(mask)
        uv = np.asarray(mesh['uvs'])[np.asarray(mesh['triangles'])]
        low, high = uv.min(axis=1), uv.max(axis=1)
        margin = CPU_MASK_UV_MARGIN_PX
        keep = ((high >= [x.min() - margin, y.min() - margin]).all(axis=1) &
                (low <= [x.max() + 1 + margin, y.max() + 1 + margin]).all(axis=1))
        previous = cpu.templates.get(path)
        if previous is not None:
            retained = {tuple(t) for t in previous['triangles']}
            keep |= np.array([tuple(t) in retained for t in mesh['triangles']])
        mesh['triangles'] = np.asarray(mesh['triangles'])[keep].tolist()
        cpu.templates[path] = mesh
    return cpu


def inspect(case, layout, pose, cpu=None):
    cpu = cpu or coverage_cpu(case, layout)
    layers, maps = cpu.layers(pose)
    owners = posed_owners(layers, layout['parts'], pose['bones'], pixels.PROOF_DEFAULTS['source_offset'])
    seams = cpu.masks(pose, layout['proof_joint_seams'], maps)
    references = cpu.masks(pose, layout['proof_rest_holes'], maps)
    tears = joint_holes(owners > 0, np.logical_or.reduce(seams), owners, references, pocket_details=True)
    pockets = pocket_report(layers, tears)
    transforms = {name: [float(t[0,0]), float(t[1,0]), float(t[0,1]), float(t[1,1]), float(t[0,2]), float(t[1,2])]
                  for name, t in [(p['name'], sprite_transform(layout, pose, p)) for p in layout['parts']]}
    detached = DetachedSource(case, layout).report(layers, transforms)
    composite = np.zeros_like(layers[0][1])
    for _, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
        mask = image[..., 3] > 0; composite[mask] = image[mask]
    return {'view': pose['view'], 'clip': pose['clip'], 'frame': pose['frame'],
            'tears': tears, **pockets, 'strays': detached['unmatched_components']}, composite


def run(case=CASE, selection=None, view=None, output=None):
    case = Path(case)
    index_path = case / 'proof/samples.json'
    index_digest = digest(index_path)
    index = read_json(index_path)
    samples = read_report(case)
    sample_path = (case / 'proof' / index['full_samples']['file']).resolve() if 'full_samples' in index else index_path
    sample_digest = digest(sample_path)
    if 'full_samples' in index and sample_digest != index['full_samples']['sha256']:
        raise ValueError('CPU coverage: bone evidence changed during validation')
    if digest(index_path) != index_digest:
        raise ValueError('CPU coverage: sample index changed during validation')
    input_stamp = bindings(case)
    data = read_json(case / 'compiled_motion.json')
    findings = evidence_errors(data, samples, input_stamp, EPSILON)
    if findings: raise ValueError('CPU coverage: invalid bone evidence: ' + '; '.join(findings))
    # The shared evidence gate has checked every compiled clip/view/frame,
    # including duplicates, phases, authored keys, sampler status and hashes.
    expected = {(r['view'], r['clip'], r['frame']) for r in samples['samples'] if r['kind'] == 'presented'}
    if selection is not None:
        if not selection or not selection <= expected: raise ValueError('CPU coverage: invalid frame selection')
        expected &= selection
    if view is not None:
        if view not in data['view_tracks']: raise ValueError('CPU coverage: unknown view')
        expected = {key for key in expected if key[0] == view}
    if not expected: raise ValueError('CPU coverage: empty sweep inventory')
    layouts = {v: read_json(case / f'layouts/{v}.json') for v in data['view_tracks']}
    cpus = {v: coverage_cpu(case, l) for v, l in layouts.items()}
    result, cache = [], {}
    output = Path(output) if output is not None else case / 'proof/seam_cpu/feedback2'
    output.mkdir(parents=True, exist_ok=True)
    for pose in samples['samples']:
        if pose['kind'] != 'presented' or (view and pose['view'] != view): continue
        key = (pose['view'], pose['clip'], pose['frame'])
        if key not in expected: continue
        signature = (pose['view'], pose['clip'], tuple((n, tuple(b['global'])) for n, b in pose['bones'].items()))
        if signature not in cache:
            cache[signature] = inspect(case, layouts[pose['view']], pose, cpus[pose['view']])
        cached, image = cache[signature]
        row = dict(cached, frame=pose['frame'])
        result.append(row)
        if pose['frame'] == 0: print('RR32 CPU CLIP: ' + pose['view'] + '/' + pose['clip'], flush=True)
        if selection or row['failures'] or row['strays']:
            Image.fromarray(image).save(output / ('%s_%s_%04d.png' % key))
    actual = [(r['view'], r['clip'], r['frame']) for r in result]
    if len(actual) != len(expected) or set(actual) != expected:
        raise ValueError('CPU coverage: incomplete sweep inventory')
    errors = [r for r in result if r['failures'] or r['strays']]
    if bindings(case) != input_stamp: raise ValueError('CPU coverage: inputs changed during sweep')
    if digest(index_path) != index_digest or digest(sample_path) != sample_digest:
        raise ValueError('CPU coverage: bone evidence changed during sweep')
    report = {'ok': not errors, 'native_pixels': False, 'frames': len(result),
              'inputs': input_stamp, 'samples_sha256': sample_digest, 'expected_frames': len(expected),
              'error_frames': len(errors), 'results': result}
    write_json(output / ('coverage_' + view + '.json' if view else 'coverage.json'), report)
    print('RR32 CPU COVERAGE: %s (%d frames; %d error frames; NOT native proof)' %
          ('FAIL' if errors else 'PASS', len(result), len(errors)))
    print('RR32 CPU SEAMS: %s (%d frames; %d joint tears; %d stray components; NOT native proof)' %
          ('FAIL' if errors else 'PASS', len(result), sum(len(r['failures']) for r in result), sum(len(r['strays']) for r in result)))
    print(Counter((r['view'], r['clip']) for r in errors))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, default=CASE)
    parser.add_argument('--representatives', action='store_true')
    parser.add_argument('--view', choices=['front', 'rear'])
    parser.add_argument('--output', type=Path, help='Capture/report directory; defaults beneath the supplied case')
    args = parser.parse_args()
    selection = {('front','death',60), ('front','death',89), ('front','move',25),
                 ('front','call_the_wind',25), ('rear','death',55), ('rear','death',45),
                 ('front','gust_bolt',24), ('rear','still_air',19), ('rear','move',28)} if args.representatives else None
    raise SystemExit(int(not run(args.case, selection, args.view, args.output)['ok']))

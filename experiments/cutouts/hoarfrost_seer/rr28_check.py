"""Strict CPU seam census and raw pose/paint/rest preservation for rr-28.

CPU estimates do not certify native pixels. The director reruns the existing
1920x1080 proof sequences after this headless implementation handoff.
"""
import argparse
import hashlib
import json
import re
import subprocess

import numpy as np

from rr28_build import PROJECT, BASE_REVISION, RIGS, paths, production_layouts
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings
from humanoid_cutout.anatomy import load
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.source_space import DetachedSource, pocket_report
from maquette_motion.pixels import PROOF_DEFAULTS, rest_identity

PROGRESS_INTERVAL_FRAMES = 50


def model_for(name, case, layout):
    if name == 'mimic':
        # The maintained Mimic diagnostic prunes only wholly transparent
        # proof-template triangles. Paint geometry and weights remain exact.
        import sys
        sys.path.insert(0, str(case.parent))
        from cpu_proof import CpuPose as MimicPose
        return MimicPose(case, layout)
    return CpuPose(case, layout)


def frame_report(model, pose):
    layers, maps = model.layers(pose)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'],
        PROOF_DEFAULTS['source_offset'], load(model.case)['ownership'])
    seam = np.logical_or.reduce(model.masks(pose, model.layout['proof_joint_seams'], maps))
    references = model.masks(pose, model.layout['proof_rest_holes'], maps)
    tears = joint_holes(owners > 0, seam, owners, references, pocket_details=True)
    return layers, pocket_report(layers, tears)


def census(name):
    case, _, recipe = paths(name)
    current = bindings(case)
    samples = read_report(case)
    if not samples['ok'] or samples['errors'] or samples['inputs'] != current:
        raise ValueError('Refresh bound headless samples before the census: ' + name)
    views = {}
    for view in ('front', 'rear'):
        model = model_for(name, case, read_json(case / f'layouts/{view}.json'))
        detached = DetachedSource(case, model.layout)
        cache, records, failures, count = {}, [], [], 0
        for pose in samples['samples']:
            if pose['view'] != view or pose['kind'] != 'presented':
                continue
            # Equal snapped bones can still have different rigid angle-tie transforms.
            key = json.dumps([pose['clip'], pose['bones'], pose['parts']], sort_keys=True)
            if key not in cache:
                layers, space = frame_report(model, pose)
                source = detached.report(layers, {k: p['transform'] for k, p in pose['parts'].items()})
                cache[key] = {**space, 'source_components': source['source_components'],
                    'unmatched_components': source['unmatched_components']}
            row = {'clip': pose['clip'], 'frame': pose['frame'], **cache[key]}
            if any(row[k] for k in ('failures', 'air_pockets', 'source_components', 'unmatched_components')):
                records.append(row)
            if row['failures'] or row['unmatched_components']:
                failures.append(row)
            count += 1
            if count % PROGRESS_INTERVAL_FRAMES == 0:
                print(f'RR28 CPU {name}/{view}: {count} frames; {len(failures)} failing', flush=True)
        views[view] = {'ok': not failures, 'frames': count, 'unique_poses': len(cache),
            'pocket_failures': sum(len(r['failures']) for r in failures),
            'unmatched_detached_components': sum(len(r['unmatched_components']) for r in failures),
            'failures': failures, 'records': records}
        print(f'RR28 STRICT CENSUS {name.upper()} {view.upper()}: {"PASS" if not failures else "FAIL"} '
              f'({count} frames; {views[view]["pocket_failures"]} pocket failures; '
              f'{views[view]["unmatched_detached_components"]} unmatched detached)', flush=True)
    if bindings(case) != current:
        raise ValueError('Inputs changed during census')
    output = case / 'proof/logs/rr28/census.full.json'
    write_json(output, {'ok': all(v['ok'] for v in views.values()), 'native_pixels': False,
        'scope': 'Canonical pocket_report plus independent joint_holes; no exceptions',
        'inputs': current, 'views': views})
    summary = {'ok': all(v['ok'] for v in views.values()), 'native_pixels': False,
        'full_report': {'file': str(output.relative_to(case)), 'sha256': digest(output)},
        'views': {v: {k: value for k, value in r.items() if k != 'records'} for v, r in views.items()}}
    write_json(recipe / 'census.json', summary)
    return summary


def committed(path):
    return subprocess.check_output(['git', 'show', BASE_REVISION + ':' + str(path.relative_to(PROJECT))], cwd=PROJECT)


def raw_rows(source):
    match = re.search(r'"samples"\s*:\s*\[', source)
    decoder, position, result = json.JSONDecoder(), match.end(), []
    while True:
        while source[position].isspace() or source[position] == ',':
            position += 1
        if source[position] == ']':
            return result
        _, end = decoder.raw_decode(source, position)
        result.append(source[position:end])
        position = end


def preservation(name, before):
    case, assets, recipe = paths(name)
    compact = read_json(case / 'proof/samples.json')
    full = case / 'proof' / compact['full_samples']['file'] if 'full_samples' in compact else case / 'proof/samples.json'
    old, new = raw_rows(before.read_text()), raw_rows(full.read_text())
    pinned = json.loads(committed(PROJECT / 'experiments/cutouts/hollow_mimic/rr26_feedback3_pose_hashes.json'))['units'][name]
    original_hash = hashlib.sha256('\n'.join(old).encode()).hexdigest()
    if original_hash != pinned['raw_after_sha256']:
        raise ValueError('Baseline raw rows differ from committed pose identity: ' + name)
    protected, changed = {}, []
    for folder in (case, assets):
        for path in sorted(folder.rglob('*')):
            if not path.is_file() or 'proof' in path.relative_to(folder).parts:
                continue
            if path.suffix != '.png' and path.name not in ('compiled_motion.json', 'director_motion.json', 'motion.gd', 'anatomy.json', 'inputs.json'):
                continue
            relative = str(path.relative_to(PROJECT))
            same = committed(path) == path.read_bytes()
            protected[relative] = {'sha256': digest(path), 'byte_identical': same}
            if not same:
                changed.append(relative)
    layout_changes = []
    for path in [case / f'layouts/{v}.json' for v in ('front', 'rear')] + [
            p for v in ('front', 'rear') for p in production_layouts(assets, v)]:
        previous, current = json.loads(committed(path)), read_json(path)
        # The sole authorized layout delta is the clip-scoped copy recipe.
        current.pop('gait_continuations', None)
        if current != previous:
            layout_changes.append(str(path.relative_to(PROJECT)))
    rests = rest_identity(case)
    result = {'ok': old == new and not changed and not layout_changes and rests['ok'],
        'base_revision': BASE_REVISION, 'pose_rows': len(old), 'raw_pose_rows_identical': old == new,
        'raw_before_sha256': hashlib.sha256('\n'.join(old).encode()).hexdigest(),
        'raw_after_sha256': hashlib.sha256('\n'.join(new).encode()).hexdigest(),
        'committed_raw_pose_sha256': pinned['raw_after_sha256'], 'baseline_samples_sha256': digest(before), 'protected_files': protected,
        'unexpected_changed_files': changed, 'unexpected_layout_changes': layout_changes,
        'rest_identity': rests}
    write_json(recipe / 'preservation.json', result)
    print(f'RR28 {name.upper()} POSE ROW IDENTITY: {"PASS" if old == new else "FAIL"} ({len(old)} raw rows)')
    print(f'RR28 {name.upper()} PAINT/REST/MOTION IDENTITY: {"PASS" if not changed and not layout_changes and rests["ok"] else "FAIL"} '
          f'({len(protected)} protected files; {len(changed) + len(layout_changes)} unexpected changes; exact rest composites)')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('census', 'preservation'))
    parser.add_argument('--rig', choices=RIGS, required=True)
    parser.add_argument('--before', type=__import__('pathlib').Path)
    args = parser.parse_args()
    if args.stage == 'preservation' and args.before is None:
        parser.error('--before is required for raw pose preservation')
    result = census(args.rig) if args.stage == 'census' else preservation(args.rig, args.before)
    raise SystemExit(int(not result['ok']))

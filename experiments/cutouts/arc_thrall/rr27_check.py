"""Thrall-only strict census and lexical pose/rest preservation evidence."""
from copy import deepcopy
import hashlib
import json
import re
import subprocess

from rr27_build import PROJECT, CASE, RECIPE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import bindings
from humanoid_cutout.source_space import DetachedSource, pocket_report
from rr24_seams import SkirtAirPolicy, frame_report

# The clean branch supplied by the director, before any rr-27 implementation.
BASE_REVISION = '0e8b6e8d70d978f1c60f134597d8c01dd80fab17'
PROGRESS_INTERVAL_FRAMES = 50


def committed(relative):
    return subprocess.check_output(['git', 'show', BASE_REVISION + ':' + relative], cwd=PROJECT)


def raw_rows(source, inventory):
    match = re.search('"' + inventory + r'"\s*:\s*\[', source)
    if match is None:
        return []
    decoder, position, result = json.JSONDecoder(), match.end(), []
    while True:
        while source[position].isspace() or source[position] == ',':
            position += 1
        if source[position] == ']':
            return result
        _, end = decoder.raw_decode(source, position)
        result.append(source[position:end])
        position = end


def preservation(samples):
    relative = str((CASE / 'proof/samples.json').relative_to(PROJECT))
    after = (PROJECT / relative).read_text()
    # Director rr-27 feedback 2 repins exactly rear/tether. The complete raw
    # row sequence outside that scope retains its original byte hash.
    from rr27_tether_identity import pose_report, motion_is_exact
    identity = pose_report(after)
    inventories,changed = identity['inventories'],identity['changed_pose_rows']
    protected = {}
    for folder in (CASE, PROJECT / 'assets/units/arc_thrall_cutout'):
        for path in sorted(folder.rglob('*')):
            if not path.is_file() or 'proof' in path.relative_to(folder).parts:
                continue
            if path.suffix != '.png' and path.name not in ('compiled_motion.json', 'director_motion.json', 'motion.gd'):
                continue
            relative = str(path.relative_to(PROJECT))
            original = committed(relative)
            protected[relative] = {'before_sha256': hashlib.sha256(original).hexdigest(),
                                   'after_sha256': digest(path)}
    changed_files = [p for p, row in protected.items() if row['before_sha256'] != row['after_sha256']]
    from rr27_preservation import copy_removal_is_exact
    authorized = [p for p in changed_files if copy_removal_is_exact(p,committed(p))]
    authorized_motion = [p for p in changed_files if motion_is_exact(p,committed(p))]
    unexpected = [p for p in changed_files if p not in authorized+authorized_motion]
    result = {'ok': identity['ok'] and not unexpected, 'base_revision': BASE_REVISION,
        'inventories': inventories, 'changed_pose_rows': changed, 'changed_protected_files': changed_files,
        'added_pose_rows':identity['added_pose_rows'],'removed_pose_rows':identity['removed_pose_rows'],
        'pose_identity_errors':identity['errors'],
        'authorized_continuation_removals':authorized,'unexpected_changes':unexpected,
        'authorized_rear_tether_motion':authorized_motion,
        'protected_files': protected, 'inputs': samples['inputs']}
    write_json(RECIPE / 'preservation.json', result)
    print('RR27 POSE ROW IDENTITY: %s (%d other rows byte-identical; %d changed + %d added rear tether rows)' %
          ('PASS' if identity['ok'] else 'FAIL',sum(r['unchanged_scope_rows'] for r in inventories.values()),
           len(changed),len(identity['added_pose_rows'])))
    print('RR27 PAINT/REST/MOTION IDENTITY: %s (%d protected files; %d copy-removal outputs; %d rear-tether motion outputs; %d unexpected)' %
          ('PASS' if not unexpected else 'FAIL',len(protected),len(authorized),len(authorized_motion),len(unexpected)))
    return result


def census(samples):
    current = bindings(CASE)
    if not samples['ok'] or samples['inputs'] != current:
        raise ValueError('Refresh Thrall samples before the strict census')
    views = {}
    for view in ('front', 'rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        model = CpuPose(CASE, deepcopy(layout))
        policy = SkirtAirPolicy(CASE, layout)
        detached = DetachedSource(CASE, layout)
        records, failures, count = [], [], 0
        for pose in samples['samples']:
            if pose['view'] != view or pose['kind'] != 'presented':
                continue
            layers, _, _, _, independent = frame_report(model, pose, policy)
            space = pocket_report(layers, independent['failures'])
            components = detached.report(layers, {k: p['transform'] for k, p in pose['parts'].items()})
            row = {'clip': pose['clip'], 'frame': pose['frame'], **space,
                   'unmatched_components': components['unmatched_components'],
                   'source_components': components['source_components']}
            if any(row[name] for name in ('failures', 'air_pockets', 'unmatched_components', 'source_components')):
                records.append(row)
            if space['failures'] or components['unmatched_components']:
                failures.append(row)
            count += 1
            if count % PROGRESS_INTERVAL_FRAMES == 0:
                print(f'RR27 CENSUS {view}: {count} frames; {len(failures)} failing', flush=True)
        unmatched = sum(len(r['unmatched_components']) for r in records)
        pockets = sum(len(r['failures']) for r in records)
        views[view] = {'ok': not failures, 'frames': count, 'unmatched_detached_components': unmatched,
            'pocket_failures': pockets, 'failures': failures, 'records': records}
        print(f'RR27 STRICT CENSUS {view.upper()}: {"PASS" if not failures else "FAIL"} '
              f'({count} frames; {unmatched} unmatched detached; {pockets} pocket failures)', flush=True)
    if bindings(CASE) != current:
        raise ValueError('Inputs changed during census')
    result = {'ok': all(v['ok'] for v in views.values()), 'native_pixels': False,
        'scope': 'Canonical source_space.py plus independent rr24 joint-tear detection; no exceptions',
        'inputs': current, 'views': views}
    write_json(RECIPE / 'census.json', result)
    return result


if __name__ == '__main__':
    samples = read_json(CASE / 'proof/samples.json')
    preserved = preservation(samples)
    result = census(samples)
    raise SystemExit(int(not (preserved['ok'] and result['ok'])))

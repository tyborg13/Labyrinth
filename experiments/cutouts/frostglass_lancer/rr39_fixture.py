"""Retain hash-bound rr-37 native failures; no external paths at test time."""
import shutil
from rr37_case import CASE
from rr37_fixture import compact_layout
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_frames import frame_digest

TARGET = CASE.parent / 'rr39_fixture'
SELECTION = {('front', 'cast', f) for f in (0, 4, 12, 30)} | {
    ('front', 'lunge', f) for f in (6, 12, 18)} | {
    ('front', 'guard', 25), ('front', 'jab', 12), ('front', 'pin', 12),
    ('rear', 'guard', 13), ('rear', 'guard', 42), ('rear', 'move', 9),
    ('rear', 'move', 41), ('rear', 'hit', 10), ('rear', 'lunge', 22),
    ('rear', 'lunge', 36), ('rear', 'death', 72), ('rear', 'cast', 0)}


def retain(source_case):
    if TARGET.exists(): raise ValueError('Immutable rr-37 fixture already retained')
    capture = source_case / 'proof/native'
    source = source_case / 'proof/production_case'
    full = read_json(capture / 'frames.json')
    report = {k: full[k] for k in ('native_pixels', 'size', 'ui_scale', 'fps', 'inputs')}
    report.update(selection_only=True, source_manifest_sha256=digest(capture/'frames.json'),
                  source_gate_log_sha256=digest(source_case/'proof/logs/native_gates.json'),
                  purpose='rr-39: immutable rr-37 native far-arm/hem failures and two rest controls')
    files = []
    for key in ('frames', 'pieces', 'rest_holes', 'joint_seams'):
        report[key] = [r for r in full[key] if (r['view'], r['clip'], r['frame']) in SELECTION]
        for row in report[key]:
            assert frame_digest(capture/row['file']) == row['sha256']
            files.append(row['file'])
            if 'checks' in row:
                assert frame_digest(capture/row['checks']) == row['checks_sha256']
                files.append(row['checks'])
    files += [v+'_rest.png' for v in ('front', 'rear')]
    index = read_json(capture/'native_storage.json')
    kept = {f: index['files'][f] for f in files}
    for row in kept.values():
        target = TARGET/row['stored_file']; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(capture/row['stored_file'], target)
    write_json(TARGET/'native_storage.json', dict(version=index['version'], files=kept))
    write_json(TARGET/'frames.json', report)
    samples = source/'proof/logs/samples.json'
    write_json(TARGET/'poses.json', {'full_samples_sha256': digest(samples),
        'samples': [r for r in read_json(samples)['samples'] if r['kind']=='presented'
                    and (r['view'], r['clip'], r['frame']) in SELECTION]})
    for view in ('front', 'rear'):
        layout_path = source/f'layouts/{view}.json'
        layout = read_json(layout_path)
        for part in layout['parts']:
            for path in (part['file'], layout['proof_layers'][part['name']]['mask']):
                target = TARGET/'case'/path; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source/path, target)
        path = layout['rest_source']; target = TARGET/'case'/path
        target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(source/path, target)
        write_json(TARGET/f'case/layouts/{view}.json', compact_layout(layout, digest(layout_path)))
    for name in ('anatomy.json', 'compiled_motion.json'):
        shutil.copyfile(source/name, TARGET/'case'/name)
    import hashlib
    import numpy as np
    from PIL import Image
    from maquette_motion.features import source_pixels
    from rr39_underlay import inputs
    _, footprint = inputs()
    original = read_json(source_case/'layouts/front.json')
    outside = {p['name']: hashlib.sha256(source_pixels(source_case, p)[~footprint].tobytes()).hexdigest()
               for p in original['parts']}
    write_json(TARGET/'source_outside_footprint.json',
        {'scope': 'untreated rr-37 source cuts outside director footprint', 'parts': outside})
    print('RR39 RR37 NATIVE FIXTURE: PASS (%d selected frames; exact bytes and source hashes)' % len(report['frames']))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-case', required=True, type=__import__('pathlib').Path)
    retain(parser.parse_args().source_case)


def models():
    from rr37_feedback3_fixture import models as historical_models
    return historical_models(TARGET)

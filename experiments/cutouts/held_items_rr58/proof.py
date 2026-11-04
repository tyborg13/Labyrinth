"""Ownership, immutable motion and native/CPU held-frame comparison for rr-58."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import numpy as np
from PIL import Image
from config import ROOT, RIGS, SCRATCH, DEFAULTS, assets, case, release, frame_count, layout_fingerprint, read_json, write_json, digest
from partition import images_for, seer_rear


def ownership():
    errors = []
    for rig in RIGS:
        root = assets(rig) / 'humanoid_v2'
        for name, expected in read_json(case(rig) / 'baseline_hashes.json').items():
            if name in ('front.json', 'rear.json'): continue
            if digest(root / name) != expected: errors.append(rig + ': protected input changed: ' + name)
        for view in ('front', 'rear'):
            layout = read_json(root / (view + '.json'))
            before = read_json(case(rig) / ('baseline_' + view + '.json'))
            # Only release textures and explicit design requests may differ.
            copy = read_json(root / (view + '.json'))
            for part in copy['parts']: part.pop('release_texture', None)
            for item in copy['held_items'].values():
                for key in list(item):
                    if key.startswith('TODO_DESIGN_'): item.pop(key)
            if layout_fingerprint(copy) != before['canonical_layout_sha256']:
                errors.append(rig + '/' + view + ': changed held layout or motion values')
            from recipes import released
            changed, classifications, fills = released(rig, view, root, layout)
            for name, full in changed.items():
                part = next(p for p in layout['parts'] if p['name'] == name)
                variant = part['release_texture']; a, b, c, d = variant['bbox']
                actual = np.asarray(Image.open(root / variant['file']).convert('RGBA'))
                checks = np.asarray(Image.open(root / variant['mask']).convert('RGBA'))
                if not np.array_equal(actual, full[b:d, a:c]): errors.append(name + ': release recipe differs')
                if not np.array_equal(checks, classifications[name][b:d, a:c]): errors.append(name + ': release outline provenance differs')
                if digest(root / variant['file']) != variant['source_sha256']: errors.append(name + ': stale release hash')
                if variant['sprite_offset'] != [a - part['offset'][0], b - part['offset'][1]]:
                    errors.append(name + ': source crop registration changed')
            for fill in fills:
                mapping = fill['texels']
                if len({(x, y) for x, y, _, _ in mapping}) != len(mapping): errors.append('Repeated fill target')
                print(f'RR58 ITEM FILL: {rig}/{view}: {len(mapping)} exact own-item texels')
    print('RR58 OWNERSHIP / HELD LAYOUTS: ' + ('FAIL' if errors else 'PASS'))
    if errors: raise ValueError('; '.join(errors))


def transforms(rig, before, after):
    old, new = read_json(before), read_json(after)
    if not old['ok'] or not new['ok']: raise ValueError('Sample errors')
    expected = {(v, c, f) for v in ('front', 'rear')
                for c, d in read_json(assets(rig) / 'humanoid_v2/compiled_motion.json')['clips'].items()
                for f in range(frame_count(d))}
    index = {(r['view'], r['clip'], r['frame']): r for r in old['samples']}
    current = {(r['view'], r['clip'], r['frame']): r for r in new['samples']}
    if set(index) != expected or set(current) != expected: raise ValueError('Incomplete transform inventory')
    for key, row in current.items():
        if any(index[key][field] != row[field] for field in ('bones', 'parts', 'phase')):
            raise ValueError('Changed transforms: ' + str(key))
        if row['phase'] < release(rig, row['view'], row['clip']) and index[key]['textures'] != row['textures']:
            raise ValueError('Changed in-hand texture binding: ' + str(key))
    print(f'RR58 ALL TRANSFORMS: PASS ({rig}; {len(expected)} frames, including the entire drop)')


def native_diff(rig, before, after, output):
    old, new = read_json(before / 'frames.json'), read_json(after / 'frames.json')
    if not old['native_pixels'] or not new['native_pixels']: raise ValueError('Real-renderer captures required')
    from humanoid_cutout.gates import bindings
    for manifest in (old, new):
        if manifest['inputs'] != bindings(Path(manifest['case_directory'])): raise ValueError('Stale native input closure')
        if manifest['probe_sha256'] != digest(Path(__file__).with_name('native.gd')): raise ValueError('Stale native probe')
    index = {(r['view'], r['clip'], r['frame']): r for r in old['frames']}
    expected = {(v, c, f) for v in ('front', 'rear')
                for c, d in read_json(assets(rig) / 'humanoid_v2/compiled_motion.json')['clips'].items()
                for f in range(frame_count(d))}
    current = {(r['view'], r['clip'], r['frame']): r for r in new['frames']}
    if (set(index) != expected or set(current) != expected or
            len(old['frames']) != len(expected) or len(new['frames']) != len(expected)):
        raise ValueError('Incomplete/duplicate native frame inventory')
    differences, count = [], 0
    for key, row in current.items():
        previous = index[key]
        if previous['phase'] != row['phase']: raise ValueError('Different native phases')
        if row['phase'] >= release(rig, row['view'], row['clip']): continue
        images = []
        for root, record in ((before, previous), (after, row)):
            path = root / record['file']
            if digest(path) != record['sha256']: raise ValueError('Changed native frame')
            image = np.asarray(Image.open(path).convert('RGBA'))
            if image.shape != (DEFAULTS['canvas_size_px'], DEFAULTS['canvas_size_px'], 4): raise ValueError('Wrong native frame size')
            images.append(image)
        a, b = images
        for y, x in np.argwhere(np.any(a != b, axis=-1)):
            differences.append({'view': key[0], 'clip': key[1], 'frame': key[2], 'xy': [int(x), int(y)],
                                'before': a[y, x].tolist(), 'after': b[y, x].tolist()})
        count += 1
    result = {'ok': not differences, 'native_pixels': True, 'frames': count,
              'differing_pixels': len(differences), 'pixels': differences,
              'before_manifest_sha256': digest(before / 'frames.json'), 'after_manifest_sha256': digest(after / 'frames.json')}
    write_json(output, result)
    print(f'RR58 NATIVE IN-HAND PIXELS: {len(differences)} differing pixels ({rig}; {count} frames)')
    return result


def collect(rig, output):
    motion = read_json(assets(rig) / 'humanoid_v2/compiled_motion.json')
    rows = [read_json(output / (v + '_' + c + '.json')) for v in ('front', 'rear') for c in motion['clips']]
    # Preserve every new component finding; filling never introduces exemptions.
    regressions = [dict(view=r['view'], clip=r['clip'], **finding) for r in rows
                   for finding in r['changed_gate_metrics']
                   if finding['after']['components'] > finding['before']['components']
                   or finding['after']['dark_slab_blocks'] > finding['before']['dark_slab_blocks']
                   or finding['after']['exposed_outline_pixels'] > finding['before']['exposed_outline_pixels']
                   or sum(finding['after']['joint_holes']) > sum(finding['before']['joint_holes'])]
    result = {'native_pixels': False, 'frames': sum(len(r['frames']) for r in rows),
              'in_hand_frames': sum(r['in_hand_frames'] for r in rows),
              'differing_pixels': sum(r['differing_pixels'] for r in rows),
              'changed_gate_rows': sum(len(r['changed_gate_metrics']) for r in rows),
              'in_hand_ok': all(r['ok'] for r in rows), 'gate_regressions': regressions,
              'gate_ok': not regressions, 'design_ready': all(r['status'] == 'filled' for r in read_json(case(rig) / 'underlay_requests/index.json')['regions'])}
    write_json(output / 'summary.json', result)
    print(f'RR58 CPU ALL FRAMES: {rig}: {result["frames"]} frames; {result["in_hand_frames"]} in-hand; {result["differing_pixels"]} differing pixels; {len(regressions)} new gate findings; fills complete={result["design_ready"]}', flush=True)
    return result


def sweep_all(rig, output, proof_root=SCRATCH):
    folder = proof_root / rig
    transforms(rig, folder / 'before_samples.json', folder / 'after_samples.json')
    motion = read_json(folder / 'after/compiled_motion.json')
    jobs = [(v, c) for v in ('front', 'rear') for c in motion['clips']]
    output.mkdir(parents=True, exist_ok=True)
    def run(job):
        view, clip = job
        command = [sys.executable, '-B', str(Path(__file__).with_name('cpu.py')), '--rig', rig,
            '--case', str(folder / 'after'), '--before', str(folder / 'before_samples.json'),
            '--after', str(folder / 'after_samples.json'), '--view', view, '--clip', clip,
            '--output', str(output / (view + '_' + clip + '.json'))]
        return subprocess.run(command, cwd=ROOT, check=True)
    with ThreadPoolExecutor(max_workers=DEFAULTS['cpu_workers']) as pool: list(pool.map(run, jobs))
    return collect(rig, output)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--rig', choices=RIGS)
    p.add_argument('--sweep', action='store_true')
    p.add_argument('--collect', action='store_true')
    p.add_argument('--proof-root', type=Path, default=SCRATCH)
    for field in ('native-before', 'native-after', 'output'): p.add_argument('--' + field, type=Path)
    a = p.parse_args()
    if a.sweep:
        result = sweep_all(a.rig, a.output, a.proof_root)
        raise SystemExit(not (result['in_hand_ok'] and result['gate_ok']))
    elif a.collect:
        result = collect(a.rig, a.output)
        raise SystemExit(not (result['in_hand_ok'] and result['gate_ok']))
    elif a.native_before: raise SystemExit(not native_diff(a.rig, a.native_before, a.native_after, a.output)['ok'])
    else: ownership()

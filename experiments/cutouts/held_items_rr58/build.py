"""Install release-only partitions and bound director paint requests for rr-58."""
import argparse
import shutil
import numpy as np
from PIL import Image
from config import ROOT, RIGS, DEFAULTS, assets, case, baseline_case, release, layout_fingerprint, read_json, write_json, digest


def save_png(path, image):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).save(path)
    path.with_name(path.name + '.import').write_text('[remap]\n\nimporter="keep"\n')


def build():
    from recipes import released
    for rig in RIGS:
        records = []
        request_path = case(rig) / 'underlay_requests/index.json'
        requests = read_json(request_path)
        for view in ('front', 'rear'):
            production_root = assets(rig) / 'humanoid_v2'
            path = production_root / (view + '.json')
            layout = read_json(path)
            for source_root, source_layout, production in (
                (baseline_case(rig), read_json(baseline_case(rig) / f'layouts/{view}.json'), False),
                (production_root, layout, True)):
                changed, checks, fills = released(rig, view, source_root, source_layout)
                for name, full in changed.items():
                    part = next(p for p in source_layout['parts'] if p['name'] == name)
                    y, x = np.nonzero(full[..., 3]); old = part['bbox']
                    bounds = [min(old[0], int(x.min())), min(old[1], int(y.min())),
                              max(old[2], int(x.max()) + 1), max(old[3], int(y.max()) + 1)]
                    a, b, c, d = bounds
                    relative = f'{view}/{name}_released.png'
                    check = f'{view}/{name}_released_checks.png'
                    output = production_root / relative if production else case(rig) / 'pieces' / relative
                    check_path = production_root / check if production else case(rig) / 'checks' / check
                    save_png(output, full[b:d, a:c]); save_png(check_path, checks[name][b:d, a:c])
                    if production:
                        part['release_texture'] = {'file': relative, 'mask': check, 'offset': bounds[:2],
                            'bbox': bounds, 'sprite_offset': [a - old[0], b - old[1]],
                            'release_at': {'death': release(rig, view, 'death')}, 'source_sha256': digest(output),
                            'held_presentation': 'original byte-identical composite cache'}
                for fill in fills:
                    fill['paint_scope'] = 'production' if production else 'source'
                    records.append(fill)
                    if production:
                        row = next(r for r in requests['regions'] if r['view'] == view)
                        row['status'] = 'filled' if fill['mask_complete'] else 'needs_mask_correction'
                        row['fill'] = {k: v for k, v in fill.items() if k not in ('rgba', 'texels')}
                        item = 'chain' if rig == 'chainbound_gaoler' else 'staff'
                        if fill['mask_complete']:
                            for key in list(layout['held_items'][item]):
                                if key.startswith('TODO_DESIGN_'): layout['held_items'][item].pop(key)
            write_json(path, layout)
        write_json(case(rig) / 'ownership.json', {'native_pixels': False, 'new_colours': 0,
            'director_decision': 'rr-58 feedback 1: exact integer copies of each item own paint; release only',
            'donor_fills': records, 'note': 'Original held textures and every motion value stay protected.'})
        write_json(request_path, requests)
    print('RR58 RELEASE FILLS: existing item texels copied; statuses/provenance recorded')


def prepare(rig, target, before=False):
    """Portable runtime proof closure, built from current production and masks."""
    source = baseline_case(rig)
    target.mkdir(parents=True, exist_ok=True)
    # A new isolated output only: do not overwrite a prior capture's inputs.
    if (target / 'cutout.json').exists(): raise ValueError('Use a fresh proof case: ' + str(target))
    for name in ('anatomy.json', 'inputs.json', 'cutout.json', 'compiled_motion.json', 'director_motion.json'):
        shutil.copyfile(source / name, target / name)
    # Historical cases retain their authoring walk durations. Sample the live
    # compiled clock and tracks, including subsequent gait/death integrations.
    for name in ('compiled_motion.json', 'director_motion.json'):
        shutil.copyfile(assets(rig) / 'humanoid_v2' / name, target / name)
    anatomy = read_json(target / 'anatomy.json')
    anatomy['integration']['binding_files'] = sorted(set(anatomy['integration']['binding_files'] + ['held_contract.gd']))
    anatomy['integration']['binding_folders'].append('experiments/cutouts/held_items_rr58')
    write_json(target / 'anatomy.json', anatomy)
    for folder in ('features', 'holes', 'seams', 'tucks', 'ownership', 'uncovered', 'checks'):
        if (source / folder).exists(): shutil.copytree(source / folder, target / folder, dirs_exist_ok=True)
    root = assets(rig) / 'humanoid_v2'
    for view in ('front', 'rear'):
        layout = read_json(root / (view + '.json'))
        original = read_json(source / f'layouts/{view}.json')
        for key, value in original.items():
            if key.startswith('proof_'): layout[key] = value
        for part in layout['parts']:
            files = [part['file']]
            variant = part.get('release_texture', {})
            if before: part.pop('release_texture', None)
            elif variant: files += [variant['file'], variant['mask']]
            for name in files:
                (target / name).parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(root / name, target / name)
        for name in (layout['rest_source'],):
            (target / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / name, target / name)
        layout['motion_data'] = str(target / 'compiled_motion.json')
        write_json(target / f'layouts/{view}.json', layout)
    write_json(target / 'rr58_binding.json', {'rig': rig, 'before': before,
        'production_motion_sha256': digest(root / 'compiled_motion.json')})
    print('RR58 PROOF CASE: ' + str(target))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--prepare', type=str, choices=RIGS)
    p.add_argument('--output', type=__import__('pathlib').Path)
    p.add_argument('--before', action='store_true')
    a = p.parse_args()
    if a.prepare: prepare(a.prepare, a.output, a.before)
    else: build()

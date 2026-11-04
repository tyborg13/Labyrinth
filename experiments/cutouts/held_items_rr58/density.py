"""Register exact partitions of existing treated paint; never regrid the palm."""
import hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from config import ROOT, RIGS, assets, case, read_json, write_json, digest
from build import save_png
import process_board_density as density


def blob_hash(path):
    data = path.read_bytes()
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def install():
    from proof import ownership
    ownership()  # Verify every exact donor recipe before replacing adopted variants.
    registry = read_json(density.REGISTRY)
    manifest = read_json(density.MANIFEST)
    count = 0
    for rig in RIGS:
        entry = next(e for e in registry['entries'] if e['id'] == rig + '_cutout')
        root = assets(rig) / 'humanoid_v2'
        domain = case(rig) / 'released_density_domain.png'
        save_png(domain, np.full((255, 255), 255, np.uint8))
        paths = []
        for view in ('front', 'rear'):
            for part in read_json(root / (view + '.json'))['parts']:
                if not part.get('release_texture'): continue
                variant = part['release_texture']
                path = str((root / variant['file']).relative_to(ROOT)); paths.append(path)
                entry['paths'] = sorted(set(entry['paths']) | {path})
                entry.setdefault('source_partitions', {})[path] = {
                    'mask': {'path': str(domain.relative_to(ROOT)), 'sha256': digest(domain)},
                    'source_offset': variant['offset']}
                checks = str((root / variant['mask']).relative_to(ROOT))
                registry['excluded_paths'][checks] = {'category': 'never_drawn',
                    'reason': 'rr-58 release ownership proof mask; categorical data, never production paint.'}
        # Only validated rr-58 released variants can replace their adopted source.
        missing = [p for p in paths if not (density.SOURCES / p).exists()]
        changed = [p for p in paths if (density.SOURCES / p).exists() and (density.SOURCES / p).read_bytes() != (ROOT / p).read_bytes()]
        if missing: density.adopt(missing, False)
        if changed: density.adopt(changed, True)
        for path in paths:
            source = density.SOURCES / path
            source.with_name(source.name + '.import').write_text('[remap]\n\nimporter="keep"\n')
            image, record = density.derive(entry, path)
            if not np.array_equal(np.asarray(image), np.asarray(Image.open(ROOT / path).convert('RGBA'))):
                raise ValueError('Exact partition changed paint')
            manifest[path] = record
        count += len(paths)
    write_json(density.REGISTRY, registry)
    write_json(density.MANIFEST, manifest)
    seal()
    print(f'RR58 DENSITY PARTITIONS: PASS ({count} exact released parts; native rest records retained)')


def seal():
    pins_path = ROOT / 'tests/approved_asset_pins.json'
    pins = read_json(pins_path)
    for rig in RIGS:
        base = assets(rig)
        path = base / 'integration.json'
        record = read_json(path)
        for name in list(record['files']):
            file = base / name
            if file.exists(): record['files'][name] = digest(file)
        for file in list((base / 'humanoid_v2').rglob('*')) + [base / 'rig.gd', base / 'held_contract.gd', base / 'held_contract.gd.uid']:
            if not file.is_file(): continue
            record['files'][str(file.relative_to(base))] = digest(file)
            relative = str(file.relative_to(ROOT))
            if relative in pins['files'] or ('released' in file.name and file.suffix == '.png'):
                pins['files'][relative] = blob_hash(file)
            if file.suffix == '.png' and 'released' in file.name:
                image = Image.open(file).convert('RGBA')
                pins['images'][relative] = {'size': list(image.size), 'alpha_bounds': list(image.getbbox())}
        record['held_item_partition'] = {'task': 'rr-58', 'native_proof': 'pending director',
            'ownership': str((case(rig) / 'ownership.json').relative_to(ROOT)),
            'underlay_requests': str((case(rig) / 'underlay_requests/index.json').relative_to(ROOT)),
            'design_placeholders': [r['status'] for r in read_json(case(rig) / 'underlay_requests/index.json')['regions'] if r['status'] != 'filled']}
        entry = next(e for e in density.load_registry()['entries'] if e['id'] == rig + '_cutout')
        record['density']['native_rest_pending'] = density.rest_errors([entry], read_json(density.MANIFEST))
        write_json(path, record)
        relative = str(path.relative_to(ROOT))
        if relative in pins['files']: pins['files'][relative] = blob_hash(path)
    # The approved-content inventory intentionally covers PNG/JSON resources.
    # Scripts and sidecars are bound by integration.files, not this inventory.
    for relative in list(pins['files']):
        if any(relative.startswith('assets/units/' + r + '_cutout/') for r in RIGS) and Path(relative).suffix in ('.gd', '.import'):
            pins['files'].pop(relative)
    write_json(pins_path, pins)


if __name__ == '__main__': install()

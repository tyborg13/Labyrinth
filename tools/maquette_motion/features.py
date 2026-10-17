"""Source-pixel feature ownership. Masks copy approved paint, never repaint it."""
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import CutoutError, digest, read_json

VIEWS = ('front', 'rear')


def declarations(root, view):
    path = root / 'features.json'
    if not path.exists():
        return []
    data = read_json(path)
    if data.get('TODO_DESIGN'):
        raise CutoutError('Unresolved feature design: ' + ', '.join(data['TODO_DESIGN']))
    result = []
    occupied = np.zeros((255, 255), dtype=bool)
    paint = np.asarray(Image.open(root / f'source/{view}/processed.png').convert('RGBA'))
    if data['approved_sha256'][view] != digest(root / f'source/{view}/processed.png'):
        raise CutoutError('Feature masks refer to different approved art: ' + view)
    names = set()
    for feature in data['features']:
        name = feature['name']
        if name in names:
            raise CutoutError('Duplicate feature name: ' + name)
        names.add(name)
        definition = feature['views'][view]
        relative = definition['mask']
        if not isinstance(relative, str) or relative.startswith('TODO_DESIGN_'):
            raise CutoutError('Unresolved feature mask: ' + name + '/' + view)
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()):
            raise CutoutError('Feature mask must be case-owned')
        image = np.asarray(Image.open(path).convert('L'))
        if image.shape != occupied.shape or set(np.unique(image)) - {0, 255}:
            raise CutoutError('Feature mask must be binary 255x255: ' + name)
        mask = image > 0
        if np.any(mask & occupied) or np.any(mask & (paint[..., 3] == 0)):
            raise CutoutError('Feature overlaps another feature or transparent paint: ' + name)
        if not mask.any() and not definition.get('occluded_reason'):
            raise CutoutError('Empty feature needs an explicit occlusion declaration: ' + name)
        if not isinstance(definition['owner'], str) or definition['owner'].startswith('TODO_DESIGN_'):
            raise CutoutError('Unresolved feature owner: ' + name + '/' + view)
        occupied |= mask
        result.append(dict(definition, name=name, pixels=mask))
    return result


def ownership(root, view, owners, names, solos):
    features = declarations(root, view)
    previous = owners.copy()
    for feature in features:
        if feature['owner'] not in names:
            raise CutoutError('Unknown feature owner: ' + feature['owner'])
        owners[feature['pixels']] = names.index(feature['owner'])
    # Previously visible pixels also need support after their feature is moved
    # to another bone, even when a proxy solo underestimated that material.
    hidden = [(solos[name] | (previous == i)) & (owners >= 0) & (owners != i)
              for i, name in enumerate(names)]
    return owners, hidden, features


def source_pixels(root, part):
    result = np.zeros((255, 255, 4), dtype=np.uint8)
    image = np.asarray(Image.open(root / part['file']).convert('RGBA'))
    x, y = part['offset']
    result[y:y + image.shape[0], x:x + image.shape[1]] = image
    return result


def integrity_report(root, samples):
    """Check actual painted nodes, not just an owners.npy declaration.

    A feature is a single physical Sprite2D attached to its declared bone. No
    other visible part may carry its source pixels. Any overlapping hidden fill
    must have a strictly lower layer. Sampled matrices must match that owner at
    every action pose, including rest/loop holds and inherited body transforms.
    """
    failures, results = [], []
    if not (root / 'features.json').exists() or not read_json(root / 'features.json').get('features'):
        return {'errors': ['Missing protected-feature declarations'], 'features': []}
    for view in VIEWS:
        layout = read_json(root / f'layouts/{view}.json')
        paint = np.asarray(Image.open(root / f'source/{view}/processed.png').convert('RGBA'))
        rows = [r for r in samples if r['view'] == view]
        for feature in declarations(root, view):
            mask = feature['pixels']
            nodes = [p for p in layout['parts'] if p.get('feature') == feature['name']]
            expected_bone = read_json(root / 'compiled_motion.json')['parts'][feature['owner']]
            result = {'feature': feature['name'], 'view': view, 'mask_pixels': int(mask.sum()),
                      'preserved_pixels': 0, 'painted_nodes': [p['name'] for p in nodes],
                      'owner': feature['owner'], 'owner_bone': expected_bone,
                      'sampled_poses': len(rows),
                      'poses_by_clip': {clip: sum(r['clip'] == clip for r in rows)
                                        for clip in sorted({r['clip'] for r in rows})},
                      'occluded_reason': feature.get('occluded_reason'), 'errors': []}
            results.append(result)
            start = len(failures)
            if not mask.any():
                if nodes:
                    failures.append(f'{view}/{feature["name"]}: occluded feature has painted nodes')
                result['errors'] = failures[start:]
                result['ok'] = not result['errors']
                continue
            if len(nodes) != 1:
                failures.append(f'{view}/{feature["name"]}: feature needs exactly one painted node')
                result['errors'] = failures[start:]
                result['ok'] = False
                continue
            node = nodes[0]
            if node['bone'] != expected_bone:
                failures.append(f'{view}/{feature["name"]}: feature attached to wrong bone')
            pixels = source_pixels(root, node)
            result['preserved_pixels'] = int((mask & np.all(pixels == paint, axis=-1)).sum())
            if not np.array_equal(pixels[..., 3] > 0, mask) or not np.array_equal(pixels[mask], paint[mask]):
                failures.append(f'{view}/{feature["name"]}: missing, split or repainted feature pixels')
            for part in layout['parts']:
                if part is node:
                    continue
                overlap = (source_pixels(root, part)[..., 3] > 0) & mask
                if overlap.any() and (not (part.get('hidden_material') or part.get('seam_underlay')) or part['z_index'] >= node['z_index']):
                    failures.append(f'{view}/{feature["name"]}: overlapping {part["name"]} is not behind feature')
            if not rows:
                failures.append(f'{view}/{feature["name"]}: no sampled poses')
            for row in rows:
                observed = row['parts'].get(node['name'], {})
                if observed.get('bone') != expected_bone or 'transform' not in observed:
                    failures.append(f'{view}/{feature["name"]}/{row["clip"]}/frame={row.get("frame", "unspecified")}/phase={row["phase"]}: sampled feature ownership differs')
                    break
            result['errors'] = failures[start:]
            result['ok'] = not result['errors']
    return {'errors': failures, 'features': results}


def integrity_errors(root, samples):
    return integrity_report(root, samples)['errors']

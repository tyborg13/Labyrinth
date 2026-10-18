"""Stage protected inputs and source-pixel features; never publish partial rigs.

Run from the worktree root. Every output belongs to one of the two rr-07 cases.
Unspecified animation attachments are data placeholders, not guessed motion.
"""
from collections import deque
from pathlib import Path
import argparse
import shutil

import numpy as np
from PIL import Image, ImageFilter

from rr07_inputs import (PROJECT, CREATURES, VIEWS, DIRECTOR, PROOF_DEFAULTS,
                         audit, delivery_for, job_for, raw_image,
                         registered_transform, label_palette, compile_recipe,
                         raw_source_path, registration_audit,
                         read_json, write_json, digest, CutoutError)
from maquette_cutout import decode_labels
from maquette_motion.features import declarations

VERSION = 'mq5'
# Source-coordinate selections identify existing approved pixels only. They do
# not paint, move, resize, recolour or add pixels to the approved source.
SELECTIONS = {
    'hoarfrost_seer': {
        'ice_crystal': {'owner': 'staff_crystal', 'colour': 'ice',
                        'front': [50, 39, 82, 101], 'rear': [174, 22, 205, 89]}},
    'arc_thrall': {
        'spark_upper': {'owner': 'club', 'colour': 'violet',
                        'front': [201, 160, 217, 180], 'rear': [43, 170, 67, 191]},
        'spark_lower': {'owner': 'club', 'colour': 'violet',
                        'front': [208, 182, 226, 207], 'rear': [32, 200, 51, 218]},
        'chain_stub': {'owner': 'collar', 'colour': 'chain',
                       'front': [99, 84, 110, 108], 'rear': None}},
}


def case_for(creature):
    return PROJECT / 'experiments/cutouts' / creature / VERSION


def copy_protected(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and digest(source) != digest(target):
        raise CutoutError('Refusing to overwrite changed protected copy: ' + str(target))
    if not target.exists():
        shutil.copyfile(source, target)


def filled(mask):
    """Fill bounded four-connected holes, preserving the external silhouette."""
    outside = np.zeros_like(mask)
    pending = deque()
    height, width = mask.shape
    for y, x in [(y, x) for y in range(height) for x in (0, width - 1)] + [
                 (y, x) for x in range(width) for y in (0, height - 1)]:
        if not mask[y, x] and not outside[y, x]:
            outside[y, x] = True
            pending.append((y, x))
    while pending:
        y, x = pending.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < height and 0 <= xx < width and not mask[yy, xx] and not outside[yy, xx]:
                outside[yy, xx] = True
                pending.append((yy, xx))
    return ~outside


def feature_mask(paint, selection, view):
    box = selection[view]
    if box is None:
        return np.zeros(paint.shape[:2], dtype=bool), np.zeros(paint.shape[:2], dtype=bool)
    r, g, b = paint[..., :3].astype(int).transpose(2, 0, 1)
    if selection['colour'] == 'ice':
        # A whole crystal includes its dark painted outline, not merely cyan
        # highlights. The inspected source rectangle ends at the crystal base.
        colour = np.ones(paint.shape[:2], dtype=bool)
    elif selection['colour'] == 'violet':
        colour = (b > r) & (r > g)
    else:
        # The olive chain and collar use R≈G>B. Adjacent skin is red-brown.
        colour = (r >= g) & (r - g <= 16) & (g > b + 10)
    domain = np.zeros(paint.shape[:2], dtype=bool)
    left, top, right, bottom = box
    domain[top:bottom, left:right] = True
    seed = domain & colour & (paint[..., 3] > 0)
    if not seed.any():
        raise CutoutError('TODO_DESIGN_empty_feature_' + selection['owner'] + '_' + view)
    rim = np.asarray(Image.fromarray(seed.astype('uint8') * 255).filter(ImageFilter.MaxFilter(3))) > 0
    mask = filled(rim) & (paint[..., 3] > 0)
    return mask, seed


def feature_crops(case, view, name, paint, mask):
    if not mask.any():
        return None
    ys, xs = np.nonzero(mask)
    border = mask & ~np.asarray(Image.fromarray(mask.astype('uint8') * 255).filter(ImageFilter.MinFilter(3))).astype(bool)
    overlay = paint.copy()
    # Diagnostic outline only; it is never referenced by a layout or renderer.
    overlay[border] = [255, 64, 192, 255]
    pad = PROOF_DEFAULTS['outline_crop_margin_px']
    box = (max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad),
           min(255, int(xs.max()) + pad + 1), min(255, int(ys.max()) + pad + 1))
    original = Image.fromarray(paint).crop(box)
    outline = Image.fromarray(overlay).crop(box)
    pair = Image.new('RGBA', (original.width * 2, original.height))
    pair.paste(original, (0, 0)); pair.paste(outline, (original.width, 0))
    relative = f'proof/features/{view}_{name}_outline.png'
    target = case / relative; target.parent.mkdir(parents=True, exist_ok=True)
    zoom = PROOF_DEFAULTS['outline_zoom']
    pair.resize((pair.width * zoom, pair.height * zoom), Image.Resampling.NEAREST).save(target)
    return relative


def stage_features(case, creature):
    features = {'schema_version': 1,
        'approved_sha256': {v: digest(case / f'source/{v}/processed.png') for v in VIEWS},
        'features': []}
    records = []
    for name, selection in SELECTIONS[creature].items():
        entry = {'name': name, 'views': {}}
        for view in VIEWS:
            paint = np.asarray(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))
            mask, seed = feature_mask(paint, selection, view)
            relative = f'features/{view}_{name}.png'
            path = case / relative; path.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(mask.astype('uint8') * 255).save(path)
            entry['views'][view] = {'owner': selection['owner'], 'mask': relative}
            if selection[view] is None:
                entry['views'][view]['occluded_reason'] = 'The collar chain stub is on the front; the rear view occludes it (rr-07 brief).'
            records.append({'feature': name, 'view': view, 'owner': selection['owner'],
                'seed_pixels': int(seed.sum()), 'mask_pixels': int(mask.sum()),
                'rim_px': 1, 'holes_filled': True, 'mask_sha256': digest(path),
                'outline_crop': feature_crops(case, view, name, paint, mask)})
        features['features'].append(entry)
    write_json(case / 'features.json', features)
    write_json(case / 'recipes/feature_selections.json', {
        'source': 'Approved mq5 paintings; rr-07 feature ownership',
        'selections': SELECTIONS[creature],
        'policy': 'Source colour seeds in explicit source rectangles; one 8-neighbour pixel rim; fill bounded holes; intersect approved opaque paint',
        'chain_colour_selection': {'r_minus_g_max': 16, 'g_minus_b_exclusive_min': 10},
        'proof_defaults': PROOF_DEFAULTS})
    for view in VIEWS:
        declarations(case, view)
    return records


def stage(creature):
    delivery = audit(creature)  # Required to succeed before creating anything.
    registration_sources = registration_audit(creature)
    if not registration_sources['ok']:
        raise CutoutError('; '.join(row['error'] for row in registration_sources['views'] if not row['ok']))
    case = case_for(creature)
    case.mkdir(parents=True, exist_ok=True)
    folder = delivery_for(creature)
    spec = compile_recipe(read_json(folder.parent / 'measurements.json'))
    copy_protected(DIRECTOR, case / 'director_motion.json')
    copy_protected(folder.parent / 'measurements.json', case / 'source/measurements.json')
    write_json(case / 'source/spec_native.json', spec)
    write_json(case / 'source/label_palette.json', label_palette(spec['labels']))
    for name in delivery['files']:
        copy_protected(folder / name, case / 'source/maquette' / name)
    write_json(case / 'proof/delivery.json', delivery)
    write_json(case / 'proof/registration_sources.json', registration_sources)
    for view in VIEWS:
        job = job_for(creature, view)
        for name in ('processed.png', 'processed.json', 'kit.json'):
            copy_protected(job / name, case / 'source' / view / name)
        raw = case / f'source/{view}/raw.png'
        original = raw_source_path(creature, view)
        if original is None:
            raw_image(creature, view).save(raw)
        else:
            copy_protected(original, raw)
        transform = registered_transform(raw, read_json(job / 'processed.json'))
        write_json(case / f'registered/{view}_registration.json', {
            'scale': transform.scale, 'offset': transform.offset, 'trace': transform.trace})
        for kind in ('parts', 'clay', *('solo_' + n for n in spec['labels'])):
            target = case / f'registered/{view}_{kind}.png'
            transform.image(Image.open(folder / f'{view}_{kind}.png').convert('RGBA')).save(target)
    features = stage_features(case, creature)
    from rr07_geometry import recipe_for
    recipe = recipe_for(creature, spec)
    write_json(case / 'rig_recipe.json', recipe)
    write_json(case / 'recipes/animation_attachments.json', {
        'director_decisions': recipe['director_decisions'], 'unresolved': {},
        'native_joint_positions': 'source/maquette/joints_px.json'})
    labels = list(spec['labels'])
    mismatches = []
    for view in VIEWS:
        image = Image.open(case / f'registered/{view}_parts.png')
        # This diagnostic only decodes categorical colour, with stable label
        # order on exact colour ties. It does not assign outside-label paint.
        decoded = decode_labels(image, label_palette(spec['labels']), labels,
                                {name: 0 for name in labels})
        paint = np.asarray(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))
        for feature in declarations(case, view):
            mask = feature['pixels']
            outside = mask & (decoded != labels.index(feature['owner']))
            mismatches.append({'view': view, 'feature': feature['name'], 'owner': feature['owner'],
                'painted_pixels_outside_native_label': int(outside.sum()),
                'mask_pixels': int(mask.sum()), 'paint_moved': False})
    write_json(case / 'proof/registration_disagreements.json', {'features': mismatches,
        'policy': 'Report categorical disagreement; approved paint remains at its original coordinates.'})
    result = {'input_ok': True, 'feature_declarations_ok': True, 'production_ready': False,
              'features': features, 'TODO_DESIGN': [],
              'unrun_gates': ['rig rest identity', 'signed bone motion', 'connected parts',
                'hidden material and dark slabs', 'seam underlays', 'shimmer',
                'native exact-tie agreement', 'production progression', 'motion mutations']}
    write_json(case / 'proof/preparation.json', result)
    for path in case.rglob('*.png'):
        Path(str(path) + '.import').write_text('[remap]\n\nimporter="keep"\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--creature', choices=CREATURES, required=True)
    args = parser.parse_args()
    result = stage(args.creature)
    print('RR07 INPUT/FEATURE PREPARATION: PASS (%s)' % args.creature)
    for row in result['features']:
        print('FEATURE %s/%s: %d px; %s' % (row['view'], row['feature'], row['mask_pixels'], row['outline_crop']))
    print('RR07 ATTACHMENT DECISIONS: recorded (director feedback 1)')


if __name__ == '__main__':
    main()

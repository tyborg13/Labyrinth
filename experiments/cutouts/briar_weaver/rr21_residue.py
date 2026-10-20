"""Director feedback 1: exact chroma-key band and declared feature exemption.

Only derived RGB changes. Alpha, ownership, masks and protected art stay exact.
Nearest donors use squared source-pixel distance; ties use y/x then layer order.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from humanoid_cutout.native_frames import load_frame

RESIDUE_DELTA = 12
RESIDUE_RATIO_NUMERATOR = 3
RESIDUE_RATIO_DENOMINATOR = 2


def residue(rgba):
    rgba = np.asarray(rgba).astype(np.int32)
    maximum = np.maximum(rgba[..., 0], rgba[..., 2])
    return ((rgba[..., 3] > 0) & (rgba[..., 1] >= maximum + RESIDUE_DELTA) &
            (RESIDUE_RATIO_DENOMINATOR * rgba[..., 1] >= RESIDUE_RATIO_NUMERATOR * maximum))


def feature_definitions(case, view):
    definitions = json.loads((Path(case) / 'feature_masks.json').read_text()).get(view, [])
    for feature in definitions:
        path = Path(case) / feature['mask']
        if hashlib.sha256(path.read_bytes()).hexdigest() != feature['sha256']:
            raise ValueError('Declared feature mask changed: ' + feature['name'])
    return definitions


def feature_mask(case, view, piece=None):
    mask = np.zeros((255, 255), dtype=bool)
    for feature in feature_definitions(case, view):
        if piece is None or feature['piece'] == piece:
            image = np.asarray(Image.open(Path(case) / feature['mask']))
            if image.shape != mask.shape: raise ValueError('Feature must be source-sized: ' + feature['name'])
            mask |= image > 0
    return mask


def clean_piece(layers, exempt):
    """Visible paint and hidden supports share only their own logical donors."""
    layers = [np.asarray(image).copy() for image in layers]
    positions, colors = [], []
    for index, image in enumerate(layers):
        valid = (image[..., 3] > 0) & ~residue(image)
        yx = np.argwhere(valid)
        positions.extend((int(y), int(x), index) for y, x in yx)
        colors.extend(image[valid, :3])
    if positions:
        positions = np.asarray(positions)
        colors = np.asarray(colors)
        order = np.lexsort((positions[:, 2], positions[:, 1], positions[:, 0]))
        positions, colors = positions[order], colors[order]
    replaced = []
    for image in layers:
        targets = np.argwhere(residue(image) & ~exempt)
        if len(targets) and not len(positions): raise ValueError('TODO_DESIGN_residue_same_piece_donor')
        for y, x in targets:
            squared = np.sum((positions[:, :2] - [y, x]) ** 2, axis=1)
            image[y, x, :3] = colors[int(squared.argmin())]
        replaced.append(len(targets))
    return layers, replaced


def outside_count(image, exempt):
    image = np.asarray(image.convert('RGBA') if isinstance(image, Image.Image) else image)
    if image.shape[:2] != exempt.shape: raise ValueError('Residue surface/mask dimensions differ')
    return int((residue(image) & ~exempt).sum())


def source_report(case, assets):
    """Check case pieces/supports, treated production parts and both rests."""
    case, assets = Path(case), Path(assets)
    rows, errors = [], []
    for root, label in [(case, 'case'), (assets / 'humanoid_v2', 'production')]:
        for view in ('front', 'rear'):
            layout_path = root / (f'layouts/{view}.json' if label == 'case' else f'{view}.json')
            layout = json.loads(layout_path.read_text())
            for part in layout['parts']:
                image = Image.open(root / part['file']).convert('RGBA')
                x, y = part['offset']
                mask = feature_mask(case, view, part['logical_part'])[y:y + image.height, x:x + image.width]
                count = outside_count(image, mask)
                rows.append({'family': label, 'view': view, 'part': part['name'], 'residue_outside_features': count})
                if count: errors.append(f'{label}/{view}/{part["name"]}: {count} residue texels outside features')
                from humanoid_cutout.gait_continuations import texture
                variants = {'move': layout.get('gait_continuations', {})}
                variants.update(layout.get('clip_continuations', {}))
                for clip, recipes in variants.items():
                    if part['name'] not in recipes: continue
                    pixels = texture(root, layout, part, gait=clip == 'move', clip=clip)
                    count = outside_count(pixels, mask)
                    rows.append({'family': label, 'view': view, 'part': part['name'], 'clip': clip, 'residue_outside_features': count})
                    if count: errors.append(f'{label}/{view}/{clip}/{part["name"]}: {count} residue texels outside features')
            rest = Image.open(root / layout['rest_source']).convert('RGBA')
            count = outside_count(rest, feature_mask(case, view))
            rows.append({'family': label, 'view': view, 'part': 'rest', 'residue_outside_features': count})
            if count: errors.append(f'{label}/{view}/rest: {count} residue texels outside features')
    return {'ok': not errors, 'errors': errors, 'surfaces': rows}


def presented_feature_mask(case, layout, pieces, image_shape):
    """Transport rigid feature UVs using the existing native quad/tie oracle.

    The native gate independently validates these captured physical transforms
    and rigid source pixels. A UV tie is exempt only when that exact source
    colour was actually captured on the isolated head at the candidate texel.
    No mesh is CPU-rasterized and no colour-derived exception is inferred.
    """
    from maquette_motion.pixels import render, unpack
    mask = np.zeros(image_shape, dtype=bool)
    for feature in feature_definitions(case, layout['facing']):
        part = next(p for p in layout['parts'] if p['name'] == feature['piece'])
        row = next((r for r in pieces if r['name'] == part['name']), None)
        if row is None: raise ValueError('Missing native feature owner: ' + feature['name'])
        rgba = np.zeros((255, 255, 4), dtype=np.uint8)
        rgba[feature_mask(case, layout['facing'], feature['piece'])] = 255
        image = Image.fromarray(rgba).crop(tuple(part['bbox']))
        projected = render(image, unpack(row['transform']), with_ties=True)
        paint = render(Image.open(Path(case) / part['file']).convert('RGBA'), unpack(row['transform']), with_ties=True)
        actual = np.asarray(load_frame(row['absolute_file']).convert('RGBA'))
        if actual.shape[:2] != image_shape: raise ValueError('Native feature owner dimensions differ')
        for feature_pixels, paint_pixels in zip(projected.candidates, paint.candidates):
            mask |= (feature_pixels[..., 3] > 0) & np.all(actual == paint_pixels, axis=-1)
    return mask

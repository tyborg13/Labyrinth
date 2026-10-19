"""Director chroma-key band; feature exemptions use occluded native masks."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import digest, read_json
from rr22_surfaces import residue_mask

NATIVE_SIZE = (512, 512)


def count(image, feature=None):
    residue = residue_mask(np.asarray(image.convert('RGBA')))
    return int((residue & ~feature if feature is not None else residue).sum())


def piece_feature(case, layout, piece):
    result = np.zeros((255, 255), dtype=bool)
    for feature in layout.get('features', []):
        if feature['piece'] == piece:
            result |= np.asarray(Image.open(case / feature['mask'])) > 0
    return result


def source_errors(case, layout, feature_case=None, feature_layout=None):
    from maquette_motion.features import source_pixels
    errors = []
    feature_case = feature_case or case
    feature_layout = feature_layout or layout
    for part in layout['parts']:
        amount = count(Image.fromarray(source_pixels(case, part)),
                       piece_feature(feature_case, feature_layout, part['logical_part']))
        if amount: errors.append(f'{layout["facing"]}/{part["name"]}: {amount} residue texels outside features')
    feature = np.logical_or.reduce([piece_feature(feature_case, feature_layout, p['logical_part']) for p in layout['parts']])
    rest_path = case / layout.get('rest_source', layout.get('rest_texture', ''))
    rest = count(Image.open(rest_path), feature)
    if rest: errors.append(f'{layout["facing"]}/rest: {rest} residue texels outside features')
    return errors


def frame_errors(image, feature=None):
    amount = count(image, feature)
    return [f'{amount} residue texels outside features'] if amount else []


def native_errors(case, capture):
    manifest = read_json(capture / 'frames.json')
    layouts = {view: read_json(case / f'layouts/{view}.json') for view in ('front', 'rear')}
    expected = {(row['view'], row['clip'], row['frame'], feature['name'])
                for row in manifest['frames'] for feature in layouts[row['view']]['features']}
    records, errors, masks = {}, [], {}
    for row in manifest.get('feature_masks', []):
        key = (row['view'], row['clip'], row['frame'], row['name'])
        if key not in expected or key in records:
            errors.append('unexpected/duplicate native feature mask: ' + str(key))
            continue
        records[key] = row
        path = capture / row['file']
        if not path.is_file() or digest(path) != row['sha256']:
            errors.append('changed/missing native feature mask: ' + str(key))
            continue
        image = Image.open(path).convert('RGBA')
        if image.size != NATIVE_SIZE:
            errors.append('native feature mask dimensions differ: ' + str(key))
            continue
        rgba = np.asarray(image)
        # Actual renderer occlusion decides white; black paint blocks the mask.
        masks[key] = (rgba[..., 0] > 0) & (rgba[..., 3] > 0)
    if set(records) != expected: errors.append('incomplete native feature-mask coverage')
    for row in manifest['frames']:
        feature = np.zeros(tuple(reversed(NATIVE_SIZE)), dtype=bool)
        for definition in layouts[row['view']]['features']:
            feature |= masks.get((row['view'], row['clip'], row['frame'], definition['name']), False)
        errors += [row['file'] + ': ' + error for error in frame_errors(Image.open(capture / row['file']), feature)]
    return errors

"""Director-authorized edit of the exposed rear trunk socket cap only."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion import hidden_material, material_palette, support_seeds, continuity, pixels
from maquette_motion.features import source_pixels


def apply(case, samples):
    if read_json(case / 'cutout.json')['character_id'] != 'shale_bloomer':
        return None
    layout = read_json(case / 'layouts/rear.json')
    index, part = next((i, p) for i, p in enumerate(layout['parts']) if p['name'] == 'hidden_trunk')
    body = next(p for p in layout['parts'] if p['name'] == 'trunk')
    visible = source_pixels(case, body)
    cap_bottom = int(np.nonzero(visible[..., 3])[0].min())
    approved = support_seeds.approved(case, 'rear', part)
    cap = (approved[..., 3] > 0) & (np.indices(approved.shape[:2])[0] < cap_bottom)
    image = np.asarray(Image.open(case / part['file']).convert('RGBA'))
    local_y, local_x = np.indices(image.shape[:2])
    uv = np.zeros_like(image)
    uv[..., 0], uv[..., 1], uv[..., 3] = local_x + part['offset'][0], local_y + part['offset'][1], image[..., 3]
    requested = np.zeros_like(cap)
    images = {p['name']: Image.open(case / p['file']).convert('RGBA') for p in layout['parts']}
    rest_row = next(r for r in samples['samples'] if r['view'] == 'rear' and r['clip'] == 'idle' and r['frame'] == 0)
    _, rest_painter = hidden_material.render_layers(case, layout, rest_row, images)
    rest_coordinates = pixels.render(Image.fromarray(uv), pixels.unpack(rest_row['parts'][part['name']]['transform']))
    rest_selected = rest_painter == index
    rest_visible_source = np.zeros_like(cap)
    rest_visible_source[rest_coordinates[..., 1][rest_selected], rest_coordinates[..., 0][rest_selected]] = True
    cap &= ~rest_visible_source
    seen = set()
    for row in (r for r in samples['samples'] if r['view'] == 'rear'):
        signature = tuple((n, tuple(v['transform']), v['alpha']) for n, v in row['parts'].items())
        if signature in seen:
            continue
        seen.add(signature)
        _, painter = hidden_material.render_layers(case, layout, row, images)
        selected = painter == index
        if not selected.any():
            continue
        coordinates = pixels.render(Image.fromarray(uv), pixels.unpack(row['parts'][part['name']]['transform']))
        x, y = coordinates[..., 0][selected], coordinates[..., 1][selected]
        requested[y, x] |= cap[y, x]
    current = source_pixels(case, part)
    requested &= current[..., 3] > 0
    donor = approved.copy()
    donor[cap] = 0
    own = visible[..., 3] > 0
    donor[own] = visible[own]
    for feature in layout['parts']:
        if feature.get('feature'):
            protected = source_pixels(case, feature)[..., 3] > 0
            donor[protected] = 0
            requested &= ~protected
    definition = material_palette.rules(case, 'rear')
    replacement = continuity.nearest_existing(donor, requested, definition) if requested.any() else np.zeros_like(current)
    before = current.copy()
    current[requested] = replacement[requested]
    continuity.store(case, part, current)
    changed = requested & np.any(before != current, axis=-1)
    mask_path = 'support/rear_socket_derived_edit.png'
    (case / 'support').mkdir(exist_ok=True)
    Image.fromarray(changed.astype(np.uint8) * 255).save(case / mask_path)
    record = {'authority': 'Director rr-05 feedback 11 decision 4', 'view': 'rear', 'part': part['name'],
              'region': 'Approved hidden trunk cap above the first rest-visible trunk scanline, and exposed in a sampled pose',
              'cap_bottom_source_y_exclusive': cap_bottom, 'exposed_cap_pixels': int(requested.sum()),
              'changed_pixels': int(changed.sum()), 'mask': mask_path, 'mask_sha256': digest(case / mask_path),
              'donors': 'Nearest non-outline original trunk/body paint outside the socket cap',
              'preview_unchanged': True}
    derivation = read_json(case / 'support_derivation.json')
    derivation['director_authorized_derived_edits'] = [record]
    for item in derivation['parts']:
        if item['view'] == 'rear' and item['part'] == part['name']:
            item['original_painted_rgba_preserved'] = not changed.any()
            item['original_painted_rgba_preserved_except_authorized_edit'] = True
            item['authorized_edited_pixels'] = int(changed.sum())
    write_json(case / 'support_derivation.json', derivation)
    return record

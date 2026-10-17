"""Derive connected ownership and joint underlays from existing approved pixels."""
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_motion.features import source_pixels, declarations
from maquette_motion.silhouette import components, dilate, part_report

NEIGHBOURS_8 = tuple((dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)


def adjacent_counts(mask, labels, count):
    """Count actual 8-neighbour contact edges, not bounding-box proximity."""
    contacts = np.zeros(count, dtype=np.int64)
    h, w = mask.shape
    for dy, dx in NEIGHBOURS_8:
        source = mask[max(0, -dy):min(h, h - dy), max(0, -dx):min(w, w - dx)]
        values = labels[max(0, dy):min(h, h + dy), max(0, dx):min(w, w + dx)][source]
        contacts += np.bincount(values[values >= 0], minlength=count)
    return contacts


def clean_visible(case, view, layout):
    parts = [p for p in layout['parts'] if not any(p.get(k) for k in
             ('hidden_material', 'feature', 'seam_underlay', 'silhouette_backing'))]
    plane = np.full((255, 255), -1, dtype=np.int32)
    pending, records = [], []
    for index, part in enumerate(parts):
        labels, groups = components(source_pixels(case, part)[..., 3] > 0)
        if not groups:
            raise CutoutError('Empty visible owner: ' + view + '/' + part['name'])
        plane[labels == groups[0][0]] = index
        for label, _ in groups[1:]:
            pending.append((index, labels == label))
    # Attach an orphan only to an already connected neighbour. This prevents
    # cyclic reassignments between two orphan chunks. Contact count wins; equal
    # counts use stable layout order. Protected feature masks are never eligible.
    while pending:
        choices = []
        for order, (original, mask) in enumerate(pending):
            contacts = adjacent_counts(mask, plane, len(parts))
            contacts[original] = 0
            if contacts.max():
                choices.append((int(contacts.max()), -order, int(contacts.argmax())))
        if not choices:
            names = ', '.join(parts[index]['name'] for index, _ in pending)
            raise CutoutError(f'TODO_DESIGN_disconnected_protected_boundary_{view}: {names}')
        _, negative_order, destination = max(choices)
        original, mask = pending.pop(-negative_order)
        plane[mask] = destination
        records.append({'from': parts[original]['name'], 'to': parts[destination]['name'], 'pixels': int(mask.sum())})
    paint = np.array(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))
    for index, part in enumerate(parts):
        image = np.zeros_like(paint)
        image[plane == index] = paint[plane == index]
        store(case, part, image)
    return records


def store(case, part, image):
    ys, xs = np.nonzero(image[..., 3])
    if not len(xs):
        raise CutoutError('Empty continuity node: ' + part['name'])
    # Preserve the old crop anchor even when its outer pixels were reassigned.
    # Extra support may extend the crop; it never changes source registration.
    left, top = min(int(xs.min()), part['offset'][0]), min(int(ys.min()), part['offset'][1])
    right = max(int(xs.max()) + 1, part.get('bbox', [0, 0, 0, 0])[2])
    bottom = max(int(ys.max()) + 1, part.get('bbox', [0, 0, 0, 0])[3])
    part['offset'] = [left, top]
    part['bbox'] = [left, top, right, bottom]
    Image.fromarray(image).crop(part['bbox']).save(case / part['file'])


def nearest_existing(seed, target):
    """Copy exact existing RGBA texels; no interpolation, palette or new paint."""
    result = seed.copy()
    visited = seed[..., 3] > 0
    pending = deque((int(y), int(x)) for y, x in zip(*np.nonzero(visited)))
    h, w = visited.shape
    while pending:
        y, x = pending.popleft()
        for dy, dx in NEIGHBOURS_8:
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and not visited[yy, xx]:
                visited[yy, xx] = True
                result[yy, xx] = result[y, x]
                pending.append((yy, xx))
    result[~target] = 0
    return result


def prepare(case):
    """Ownership cleanup is independent of the searched overlap margin."""
    result = {}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        transferred = clean_visible(case, view, layout)
        write_json(case / f'layouts/{view}.json', layout)
        result[view] = transferred
    return result


def underlays(case, margin):
    records = []
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        paint = np.array(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))
        opaque = paint[..., 3] > 0
        all_pixels = {p['name']: source_pixels(case, p) for p in layout['parts']}
        visible = [p for p in layout['parts'] if not any(p.get(k) for k in
                   ('hidden_material', 'seam_underlay', 'silhouette_backing'))]
        for part in layout['parts']:
            if not part.get('hidden_material'):
                continue
            # Material belonging to this bone supplies a connected support
            # surface beneath its visible crops, including painted Wisp veins.
            owners = [p for p in visible if p['bone'] == part['bone']]
            seed = all_pixels[part['name']].copy()
            footprint = np.zeros_like(opaque)
            for owner in owners:
                own = all_pixels[owner['name']]
                selected = own[..., 3] > 0
                footprint |= selected
                if not owner.get('feature'):
                    seed[selected] = own[selected]
            if not footprint.any():
                labels, groups = components(seed[..., 3] > 0)
                if not groups:
                    raise CutoutError('No support seed: ' + view + '/' + part['name'])
                footprint = labels == groups[0][0]
            candidate = ((seed[..., 3] > 0) | dilate(footprint, margin)) & opaque
            labels, groups = components(candidate)
            connected = labels == max(groups, key=lambda item: int(((labels == item[0]) & footprint).sum()))[0]
            before = int((seed[..., 3] > 0).sum())
            seed[~connected] = 0
            result = nearest_existing(seed, connected)
            store(case, part, result)
            records.append({'view': view, 'part': part['name'], 'overlap_margin_px': margin,
                            'pixels': int(connected.sum()), 'original_seed_pixels': before})
        write_json(case / f'layouts/{view}.json', layout)
    return records


def seal(case, transfers, supports, margin, bleed=None):
    """Refresh generated runtime provenance; approved source inputs stay fixed."""
    report = part_report(case)
    if report['errors']:
        raise CutoutError('Continuity derive gate failed: ' + str(report['errors'][:5]))
    index_path = case / 'hidden_fills/index.json'
    index = read_json(index_path)
    for relative in index['protected_inputs']:
        index['protected_inputs'][relative] = digest(case / relative)
    for record in index['requests']:
        for output in record.get('outputs', []):
            output['output_sha256'] = digest(case / output['output'])
    index['continuity'] = {'tool_sha256': digest(Path(__file__)), 'joint_overlap_margin_px': margin,
                           'policy': 'Exact approved RGBA donors; hidden complete bone support, clipped to approved rest alpha'}
    if bleed is not None:
        index['continuity']['bleed_policy'] = 'Nearest-edge RGBA replication; per-joint ceil(maximum sampled separation)+1 source pixel; covered by a higher neighbour at rest; feature donors and new feature targets excluded; reject new enclosed gaps'
        index['continuity']['bleed_tool_sha256'] = digest(Path(__file__).with_name('bleed.py'))
        index['continuity']['seam_tool_sha256'] = digest(Path(__file__).with_name('seam_support.py'))
    write_json(index_path, index)
    write_json(case / 'proof/continuity.json', {'ok': True, 'transfers': transfers, 'supports': supports,
               'joint_overlap_margin_px': margin, 'part_gate': report})


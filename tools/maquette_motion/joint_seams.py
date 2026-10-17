"""Feedback 8: local seam bands, never a whole-creature backing.

Rest ownership, including features assigned to their logical owners, supplies
the regions (hidden fills/bleed are not ownership). Feature pixels supply
neither band paint nor band coverage.
Boundary length is the number of shared unit pixel edges. Band width is the
total width, centred on those edges. Distances are Euclidean source pixels.
Equal-depth, independently moving siblings require a director-supplied owner.
"""
import math
import shutil
import numpy as np
from PIL import Image
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_motion.bleed import edge_texels, source_transform
from maquette_motion.features import source_pixels

MIN_BOUNDARY_PX = 3
SEPARATION_MARGIN_PX = 1
UNDERLAY_FLAG = 'seam_underlay'


def material_parts(layout):
    return [p for p in layout['parts'] if not any(p.get(k) for k in
            ('hidden_material', 'feature', 'silhouette_backing', UNDERLAY_FLAG))]


def rest_regions(case, layout):
    parts = material_parts(layout)
    regions = {p['name']: source_pixels(case, p)[..., 3] > 0 for p in parts}
    features = [(p, source_pixels(case, p)[..., 3] > 0) for p in layout['parts'] if p.get('feature')]
    for _, mask in features:
        for region in regions.values():
            region &= ~mask
    for feature, mask in features:
        owner = feature.get('logical_part', feature['bone'])
        if owner not in regions:
            raise CutoutError('TODO_DESIGN_seam_feature_owner_' + feature['name'] + ': no material owner ' + owner)
        regions[owner] |= mask
    return regions


def boundary(a, b):
    """Shared grid edges, represented as closed segments in source coordinates."""
    result = []
    for mask, vertical in (((a[:, :-1] & b[:, 1:]) | (b[:, :-1] & a[:, 1:]), True),
                           ((a[:-1] & b[1:]) | (b[:-1] & a[1:]), False)):
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            result.append(((x + 1, y), (x + 1, y + 1)) if vertical else
                          ((x, y + 1), (x + 1, y + 1)))
    return np.asarray(result, dtype=float).reshape((-1, 2, 2))


def band(edges, domain, width):
    """Pixel centres within half the total width of an exact shared edge."""
    ys, xs = np.nonzero(domain)
    points = np.stack((xs + .5, ys + .5), axis=1)
    squared = np.full(len(points), np.inf)
    for start, end in edges:
        delta = points - np.minimum(np.maximum(points, start), end)
        squared = np.minimum(squared, np.sum(delta * delta, axis=1))
    result = np.zeros_like(domain)
    result[ys, xs] = squared <= (width / 2) ** 2
    return result


def depth(layout, bone):
    count = 0
    while layout['joints'][bone]['parent'] is not None:
        count += 1
        bone = layout['joints'][bone]['parent']
    return count


def parent_part(layout, first, second, decisions):
    key = '|'.join(sorted((first['name'], second['name'])))
    if key in decisions:
        return next((p for p in (first, second) if p['name'] == decisions[key]), None)
    depths = depth(layout, first['bone']), depth(layout, second['bone'])
    if depths[0] != depths[1]:
        return first if depths[0] < depths[1] else second
    # Wisp veins are painted on core and explicitly ride core. Their physical
    # body node is also the parent paint donor; no relative motion is introduced.
    if first['bone'] == second['bone']:
        return next((p for p in (first, second) if p['name'] == p['bone']), None)
    return None


def derive_view(case, view, layout, samples, decisions=None):
    parts = material_parts(layout)
    images = {p['name']: source_pixels(case, p) for p in parts}
    regions = rest_regions(case, layout)
    protected = np.zeros((255, 255), dtype=bool)
    for part in layout['parts']:
        if part.get('feature'):
            protected |= source_pixels(case, part)[..., 3] > 0
    rows = [r for r in samples['samples'] if r['view'] == view]
    records, surfaces, pending = [], {}, []
    for index, first in enumerate(parts):
        for second in parts[index + 1:]:
            a, b = (regions[p['name']] for p in (first, second))
            edges = boundary(a, b)
            if len(edges) < MIN_BOUNDARY_PX:
                continue
            pair = [first['name'], second['name']]
            name = 'seam_' + '_'.join(pair)
            record = {'name': name, 'parts': pair, 'shared_boundary_px': len(edges)}
            parent = parent_part(layout, first, second, decisions or {})
            if parent is None:
                placeholder = 'TODO_DESIGN_seam_parent_' + view + '_' + '_'.join(pair)
                record['parent'] = placeholder
                pending.append({'name': placeholder, 'view': view, 'parts': pair,
                                'bones': [p['bone'] for p in (first, second)],
                                'depths': [depth(layout, p['bone']) for p in (first, second)],
                                'shared_boundary_px': len(edges),
                                'reason': 'Equal-depth siblings have no nearer-root part; donor and attachment need a director decision'})
                records.append(record)
                continue
            maximum, worst = 0., None
            # A rigid-affine displacement has its maximum on segment endpoints.
            points = np.c_[edges.reshape((-1, 2)), np.ones(len(edges) * 2)].T
            for row in rows:
                if first['bone'] == second['bone']:
                    break  # One shared affine; crop cancellation is not motion.
                difference = source_transform(row, first) - source_transform(row, second)
                # Match the existing bleed oracle's explicit 2D arithmetic.
                # Small BLAS matmuls on this host emitted spurious overflow/
                # invalid warnings despite all inputs and results being finite.
                delta = (difference[:2, 0, None] * points[0] +
                         difference[:2, 1, None] * points[1] + difference[:2, 2, None])
                separation = float(np.linalg.norm(delta, axis=0).max())
                if not math.isfinite(separation):
                    raise CutoutError(f'Non-finite joint separation: {view}/{name}/{row["clip"]}/{row["frame"]}')
                if separation > maximum:
                    maximum, worst = separation, {'clip': row['clip'], 'frame': row['frame']}
            width = math.ceil(maximum) + SEPARATION_MARGIN_PX
            target = band(edges, (a | b) & ~protected, width)
            donor = images[parent['name']].copy()
            donor[protected] = 0
            image = edge_texels(donor, target)
            surfaces[name] = image
            record.update(parent=parent['name'], bone=parent['bone'],
                          maximum_sampled_separation_px=maximum, worst_pose=worst,
                          band_width_px=width, pixels=int(target.sum()),
                          parent_z_index=parent['z_index'])
            records.append(record)
    return records, surfaces, pending


def install(case, samples):
    """Replace only derived seam/backing nodes; existing material is immutable."""
    decision_path = case / 'seam_parent_decisions.json'
    decisions = read_json(decision_path) if decision_path.exists() else {}
    records, pending = {}, []
    shutil.rmtree(case / 'backing', ignore_errors=True)
    (case / 'backing.json').unlink(missing_ok=True)
    shutil.rmtree(case / 'seams', ignore_errors=True)
    for view in ('front', 'rear'):
        path = case / f'layouts/{view}.json'
        layout = read_json(path)
        layout['parts'] = [p for p in layout['parts'] if not p.get('silhouette_backing') and not p.get(UNDERLAY_FLAG)]
        joints, surfaces, unresolved = derive_view(case, view, layout, samples, decisions.get(view))
        pending.extend(unresolved)
        nodes = []
        base = min(p['z_index'] for p in layout['parts']) - len(surfaces)
        parent_order = {p['name']: index for index, p in enumerate(layout['parts'])}
        installed = sorted((r for r in joints if r['name'] in surfaces),
                           key=lambda r: (r['parent_z_index'], parent_order[r['parent']]))
        for order, record in enumerate(installed):
            image = surfaces[record['name']]
            ys, xs = np.nonzero(image[..., 3])
            bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
            relative = f'seams/{view}/{record["name"]}.png'
            (case / relative).parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(image).crop(bounds).save(case / relative)
            nodes.append({'name': record['name'], UNDERLAY_FLAG: True, 'bone': record['bone'],
                          'file': relative, 'offset': bounds[:2], 'bbox': bounds, 'z_index': base + order})
            record.update(file=relative, sha256=digest(case / relative))
        layout['parts'] = nodes + layout['parts']
        write_json(path, layout)
        records[view] = joints
    result = {'policy': __doc__, 'minimum_shared_boundary_px': MIN_BOUNDARY_PX,
              'width': 'total width centred on boundary; ceil(max sampled separation) + 1 px',
              'paint': 'nearest approved parent texel, excluding features; stable row/column distance ties',
              'views': records, 'TODO_DESIGN': pending}
    from maquette_motion.seam_pose import body_part
    result['reference_body_bones'] = {view: body_part(read_json(case / f'layouts/{view}.json'))['bone']
                                      for view in ('front', 'rear')}
    write_json(case / 'seams.json', result)
    config = read_json(case / 'cutout.json')
    config['sources'] = sorted((set(config['sources']) - {'backing.json'}) | {'seams.json'} |
                               ({'seam_parent_decisions.json'} if decision_path.exists() else set()))
    write_json(case / 'cutout.json', config)
    return result


def definition_errors(case, samples):
    errors = []
    if not (case / 'seams.json').is_file():
        return ['Missing derived joint seam underlays']
    saved = read_json(case / 'seams.json')
    decisions = read_json(case / 'seam_parent_decisions.json') if (case / 'seam_parent_decisions.json').exists() else {}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        from maquette_motion.seam_pose import body_part
        if saved.get('reference_body_bones', {}).get(view) != body_part(layout)['bone']:
            errors.append(view + ': seam proof reference does not match common body bone')
        if any(p.get('silhouette_backing') for p in layout['parts']):
            errors.append(view + ': rejected silhouette backing is still installed')
        expected, surfaces, pending = derive_view(case, view, layout, samples, decisions.get(view))
        errors.extend(p['name'] for p in pending)
        nodes = {p['name']: p for p in layout['parts'] if p.get(UNDERLAY_FLAG)}
        if set(nodes) != set(surfaces):
            errors.append(view + ': seam node coverage differs from adjacent rest pairs')
        by_name = {r['name']: r for r in saved['views'][view]}
        material_z = min(p['z_index'] for p in layout['parts'] if not p.get(UNDERLAY_FLAG))
        for record in expected:
            name = record['name']
            if any(by_name.get(name, {}).get(k) != v for k, v in record.items()):
                errors.append(view + '/' + name + ': seam derivation record differs')
            if name not in nodes or name not in surfaces:
                continue
            node = nodes[name]
            if node['bone'] != record['bone'] or node['z_index'] >= material_z:
                errors.append(view + '/' + name + ': seam attachment/draw order differs')
            if not np.array_equal(source_pixels(case, node), surfaces[name]):
                errors.append(view + '/' + name + ': seam pixels differ from clipped parent-edge replication')
    return errors

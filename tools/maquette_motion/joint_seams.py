"""Director feedback 9: local seam bands, never a whole-creature backing.

Rest ownership, including features assigned to their logical owners, supplies
the regions (hidden fills/bleed are not ownership). Feature pixels supply
neither band paint nor band coverage.
Boundary length is the number of shared unit pixel edges. Reach on each side
is ceil(maximum sampled separation) + 1, capped at 4 source pixels. Siblings
use the lower-drawn part as owner and paint donor. Each retained 8-connected
band component is one node; components smaller than 3 pixels are discarded.
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
MAX_BAND_REACH_PX = 4
MIN_COMPONENT_PIXELS = 3
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
    # Director: any equal-depth pair (siblings or cousins) is owned by the part drawn lower.
    # Stable layout order is also the native draw order for equal z values.
    return min((first, second), key=lambda p: (p['z_index'], layout['parts'].index(p)))


def connected_bands(name, image):
    """Stable, separate nodes; a discarded speck cannot become posed debris."""
    from maquette_motion.silhouette import components
    labels, sizes = components(image[..., 3] > 0)
    retained = [(label, size) for label, size in sizes if size >= MIN_COMPONENT_PIXELS]
    surfaces = {}
    for index, (label, _) in enumerate(retained):
        node = name if len(retained) == 1 else f'{name}_component_{index + 1:02d}'
        component = np.zeros_like(image)
        component[labels == label] = image[labels == label]
        surfaces[node] = component
    return surfaces, [size for _, size in sizes if size < MIN_COMPONENT_PIXELS]


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
                                'reason': 'Equal-depth parts with different immediate parents need a director-supplied seam owner'})
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
            derived_reach = math.ceil(maximum) + SEPARATION_MARGIN_PX
            reach = min(derived_reach, MAX_BAND_REACH_PX)
            target = band(edges, (a | b) & ~protected, 2 * reach)
            donor = images[parent['name']].copy()
            donor[protected] = 0
            definition = None
            if (case / 'support_derivation.json').exists():
                from maquette_motion import material_palette
                definition = material_palette.rules(case, view)
                if not (material_palette.interior_donors(donor, definition)[..., 3] > 0).any():
                    for same_bone in layout['parts']:
                        if same_bone['bone'] == parent['bone'] and same_bone.get('hidden_material'):
                            from maquette_motion.support_seeds import approved
                            donor = approved(case, view, same_bone)
                            donor[protected] = 0
                            if (material_palette.interior_donors(donor, definition)[..., 3] > 0).any():
                                break
            image = edge_texels(donor, target, definition)
            components, discarded = connected_bands(name, image)
            surfaces.update(components)
            record.update(parent=parent['name'], bone=parent['bone'],
                          maximum_sampled_separation_px=maximum, worst_pose=worst,
                          derived_reach_per_side_px=derived_reach, reach_per_side_px=reach,
                          band_width_px=2 * reach, pixels=int(target.sum()),
                          discarded_component_pixels=discarded,
                          components=[{'name': node, 'pixels': int((surface[..., 3] > 0).sum())}
                                      for node, surface in components.items()],
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
        installed = sorted(((r, c) for r in joints for c in r.get('components', [])),
                           key=lambda item: (item[0]['parent_z_index'], parent_order[item[0]['parent']]))
        for order, (record, component) in enumerate(installed):
            image = surfaces[component['name']]
            ys, xs = np.nonzero(image[..., 3])
            bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
            relative = f'seams/{view}/{component["name"]}.png'
            (case / relative).parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(image).crop(bounds).save(case / relative)
            nodes.append({'name': component['name'], UNDERLAY_FLAG: True, 'bone': record['bone'],
                          'file': relative, 'offset': bounds[:2], 'bbox': bounds, 'z_index': base + order})
            component.update(file=relative, sha256=digest(case / relative))
        layout['parts'] = nodes + layout['parts']
        write_json(path, layout)
        records[view] = joints
    result = {'policy': __doc__, 'minimum_shared_boundary_px': MIN_BOUNDARY_PX,
              'width': 'reach per side = min(ceil(max sampled separation) + 1 px, 4 px)',
              'minimum_component_pixels': MIN_COMPONENT_PIXELS,
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
            actual = dict(by_name.get(name, {}))
            if 'components' in actual:
                actual['components'] = [{k: v for k, v in c.items() if k not in ('file', 'sha256')}
                                        for c in actual['components']]
            if actual != record:
                errors.append(view + '/' + name + ': seam derivation record differs')
            for component in record.get('components', []):
                name = component['name']
                if name not in nodes:
                    continue
                node = nodes[name]
                if node['bone'] != record['bone'] or node['z_index'] >= material_z:
                    errors.append(view + '/' + name + ': seam attachment/draw order differs')
                if not np.array_equal(source_pixels(case, node), surfaces[name]):
                    errors.append(view + '/' + name + ': seam pixels differ from clipped parent-edge replication')
    return errors

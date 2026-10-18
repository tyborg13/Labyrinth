"""Derived dark slabs block; approved painted shadows are informational (fb12)."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion import pixels, silhouette, material_palette, material_provenance

BLOCK_SIDE_PX = 3


def render_layers(case, layout, row, images=None, source_classes=None):
    """Source-nearest composition and topmost painter, optionally texel approval.

    Approval uses the same local crop, matrix and nearest-source sampling as
    RGBA. It travels with the texel, rather than classifying an entire node.
    """
    size = pixels.PROOF_DEFAULTS['canvas_size']
    result = Image.new('RGBA', (size, size))
    painter = np.full((size, size), -1, dtype=np.int32)
    approved = np.zeros((size, size), dtype=bool)
    for index, part in sorted(enumerate(layout['parts']), key=lambda item: item[1]['z_index']):
        node = row['parts'][part['name']]
        if node['alpha'] <= 0:
            continue
        image = images[part['name']] if images else Image.open(case / part['file']).convert('RGBA')
        transform = pixels.unpack(node['transform'])
        corners = np.array([[0, 0, 1], [image.width, 0, 1], [0, image.height, 1], [image.width, image.height, 1]]).T
        points = (transform @ corners)[:2] + pixels.PROOF_DEFAULTS['source_offset']
        low = np.maximum(0, np.floor(points.min(axis=1)).astype(int) - 1)
        high = np.minimum(size, np.ceil(points.max(axis=1)).astype(int) + 1)
        if np.any(low >= high):
            continue
        left, top, right, bottom = map(int, (*low, *high))
        paint = pixels.render(image, transform, (left, top, right, bottom))
        paint[..., 3] = pixels.modulated_alpha(paint[..., 3], node['alpha'])
        result.alpha_composite(Image.fromarray(paint), (left, top))
        occupied = paint[..., 3] > 0
        painter[top:bottom, left:right][occupied] = index
        if source_classes is not None:
            classes = pixels.render(source_classes[part['name']], transform, (left, top, right, bottom))
            approved[top:bottom, left:right][occupied] = classes[..., 0][occupied] > 0
    layers = (np.asarray(result), painter)
    return (*layers, approved) if source_classes is not None else layers


def measure(image, painter, layout, definition, approved):
    eligible = [i for i, p in enumerate(layout['parts']) if p.get('hidden_material') or p.get('seam_underlay')]
    exposed = np.isin(painter, eligible)
    occupied = painter >= 0
    derived = occupied & ~approved
    outline = material_palette.outline_class(image, definition)
    dark = derived & outline
    labels, groups = silhouette.components(dark)
    side = BLOCK_SIDE_PX
    blocks = np.ones((dark.shape[0] - side + 1, dark.shape[1] - side + 1), dtype=bool)
    for y in range(side):
        for x in range(side):
            blocks &= dark[y:y + blocks.shape[0], x:x + blocks.shape[1]]
    bad_labels = set(labels[:blocks.shape[0], :blocks.shape[1]][blocks].tolist())
    bad = np.isin(labels, list(bad_labels)) if bad_labels else np.zeros_like(dark)
    owners = {layout['parts'][i]['name']: int((bad & (painter == i)).sum())
              for i in np.unique(painter[bad]) if i >= 0}
    painted_groups = silhouette.components(occupied & approved & outline)[1]
    hidden_painted_groups = silhouette.components(exposed & approved & outline)[1]
    return {'exposed_hidden_pixels': int(exposed.sum()), 'outline_class_pixels': int(dark.sum()),
            'largest_dark_component': groups[0][1] if groups else 0,
            'derived_pixels': int(derived.sum()),
            'approved_painted_pixels': int((occupied & approved).sum()),
            'exposed_approved_hidden_pixels': int((exposed & approved).sum()),
            'largest_approved_dark_component': painted_groups[0][1] if painted_groups else 0,
            'largest_approved_hidden_dark_component': hidden_painted_groups[0][1] if hidden_painted_groups else 0,
            'slab_components': len(bad_labels), 'slab_pixels': int(bad.sum()), 'slab_painters': owners}, dark, bad


def report(case, samples):
    failures, poses, definitions, provenance = [], [], {}, {}
    maxima = {}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        definitions[view] = material_palette.rules(case, view)
        images = {p['name']: Image.open(case / p['file']).convert('RGBA') for p in layout['parts']}
        classes, provenance[view] = material_provenance.source_classes(case, view, layout, images)
        cache = {}
        for row in (r for r in samples['samples'] if r['view'] == view):
            signature = tuple((n, tuple(v['transform']), v['alpha']) for n, v in row['parts'].items())
            if signature not in cache:
                image, painter, approved = render_layers(case, layout, row, images, classes)
                cache[signature] = measure(image, painter, layout, definitions[view], approved)[0]
            metric = dict(view=view, clip=row['clip'], frame=row['frame'], **cache[signature])
            poses.append(metric)
            key = view + '_' + row['clip']
            group = maxima.setdefault(key, {})
            for field in ('exposed_hidden_pixels', 'derived_pixels', 'largest_dark_component', 'slab_pixels',
                          'approved_painted_pixels', 'exposed_approved_hidden_pixels',
                          'largest_approved_dark_component', 'largest_approved_hidden_dark_component'):
                if field not in group or metric[field] > group[field][field]:
                    group[field] = {k: metric[k] for k in ('view', 'clip', 'frame', field)}
            if metric['slab_components']:
                failures.append(f'{view}/{row["clip"]}/{row["frame"]:04d}: exposed derived dark slab ({metric["slab_pixels"]}px; {metric["slab_painters"]})')
    return {'ok': not failures, 'errors': failures, 'block_side_px': BLOCK_SIDE_PX,
            'blocking_scope': 'Exposed derived source texels only; approved visible and hidden-request paint report-only',
            'provenance_policy': 'Exact original hidden-request mask/RGBA or visible source RGBA; seams, dilation, bleed and edited texels are derived',
            'source_provenance': provenance,
            'outline_rules': definitions, 'max_by_clip': maxima, 'poses': poses}

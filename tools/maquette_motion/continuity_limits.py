"""Bound static hidden-fill repairs without changing protected motion keys."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import compose, components, dilate, measure, rest_hole_owners, pose_rest_holes


def unfillable_holes(case, report, silhouette):
    results = []
    bad = {(r['view'], r['clip'], r['frame']) for r in silhouette['poses'] if r['new_holes']}
    compiled = read_json(case / 'compiled_motion.json')
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        paint = Image.open(case / f'source/{view}/processed.png').convert('RGBA')
        definitions = rest_hole_owners(case, layout)
        images = {p['name']: Image.open(case / p['file']).convert('RGBA') for p in layout['parts']}
        for row in (r for r in report['samples'] if r['view'] == view):
            if (view, row['clip'], row['frame']) not in bad:
                continue
            actual = compose(case, layout, row, images)
            _, _, holes = measure(actual, pose_rest_holes(definitions, row))
            if not holes:
                continue
            ys, xs = np.nonzero(np.logical_or.reduce(holes))
            left, top = max(0, int(xs.min()) - 1), max(0, int(ys.min()) - 1)
            right, bottom = min(actual.shape[1], int(xs.max()) + 2), min(actual.shape[0], int(ys.max()) + 2)
            bounds = left, top, right, bottom
            maximum = np.zeros_like(actual)
            represented = set()
            for part in layout['parts']:
                if part['bone'] in represented or row['parts'][part['name']]['alpha'] <= 0:
                    continue
                represented.add(part['bone'])
                transform = pixels.unpack(row['parts'][part['name']]['transform'])
                transform[:2, 2] -= transform[:2, :2] @ np.asarray(part['offset'])
                maximum[top:bottom, left:right] |= pixels.render(paint, transform, bounds)[..., 3] > 0
            for hole in holes:
                remaining = hole & ~maximum
                labels, groups = components(remaining, 4)
                if not groups or groups[0][1] < 2:
                    continue
                blocked = labels == groups[0][0]
                boundary = dilate(hole, 1) & ~hole
                contributors = []
                bones = set()
                for part in layout['parts']:
                    image = pixels.render(images[part['name']], pixels.unpack(row['parts'][part['name']]['transform']), bounds)
                    contact = int((boundary[top:bottom, left:right] & (image[..., 3] > 0)).sum())
                    if contact:
                        bones.add(part['bone'])
                        contributors.append({'part': part['name'], 'bone': part['bone'], 'boundary_pixels': contact})
                # Include inherited root/trunk channels as well as rim parts.
                for bone in list(bones):
                    parent = layout['joints'][bone]['parent']
                    while parent:
                        bones.add(parent)
                        parent = layout['joints'][parent]['parent']
                tracks = [track for track in compiled['view_tracks'][view][row['clip']] if track['bone'] in bones]
                authored = read_json(case / 'director_motion.json')[compiled['creature']]['clips'][row['clip']]['keys']
                results.append({'name': f'TODO_DESIGN_silhouette_{view}_{row["clip"]}_{row["frame"]:04d}',
                        'view': view, 'clip': row['clip'], 'frame': row['frame'], 'phase': row['phase'],
                        'presented_phase': row['presented_phase'], 'unfillable_pixels': int(blocked.sum()),
                        'coordinates': np.argwhere(blocked)[:, ::-1].tolist(), 'contributors': contributors,
                        'channels_and_keys': tracks,
                        'authored_keys': {t['source']: authored[t['source']] for t in tracks},
                        'reason': 'An enclosed background component remains even with all approved opaque rest pixels available to every currently painted bone. Static underlay extension cannot fill this component at the fixed cleaned ownership and authored transforms. A motion/visible-ownership decision is required.'})
    return results


def unfillable_hole(case, report, silhouette):
    # The search needs only its first certificate; the handoff records all.
    for row in report['samples']:
        single = dict(report, samples=[row])
        records = unfillable_holes(case, single, silhouette)
        if records: return records[0]
    return None

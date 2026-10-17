"""Director-authorized, draw-order-covered edge replication at sampled joints."""
import math
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, write_json
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components, dilate
from maquette_motion.continuity import store


def edge_texels(seed, target):
    """Exact squared-Euclidean nearest donor; stable row/column tie order."""
    h, w = target.shape
    distance = np.full((h, w), np.inf)
    donor_x = np.zeros((h, w), dtype=int)
    for y in range(h):
        xs = np.flatnonzero(seed[y, :, 3])
        if len(xs):
            squared = (np.arange(w)[:, None] - xs) ** 2
            indices = squared.argmin(axis=1)
            distance[y] = squared[np.arange(w), indices]
            donor_x[y] = xs[indices]
    result = np.zeros_like(seed)
    for x in range(w):
        squared = distance[:, x, None] + (np.arange(h)[:, None] - np.arange(h)) ** 2
        donor_y = squared.argmin(axis=0)
        result[:, x] = seed[donor_y, donor_x[donor_y, x]]
    result[~target] = 0
    return result


def source_transform(row, part):
    matrix = pixels.unpack(row['parts'][part['name']]['transform']).copy()
    matrix[:2, 2] -= matrix[:2, :2] @ np.asarray(part['offset'])
    return matrix


def domains(case, samples):
    """Margin = ceil(maximum sampled joint separation) + one source pixel.

    A support node is behind every eligible neighbour. Its new texels occupy
    only that neighbour's original alpha, inside approved rest alpha. Neither
    feature paint nor feature masks can supply or receive replicated texels.
    """
    records, surfaces = [], {}
    for view in ('front', 'rear'):
        path = case / f'layouts/{view}.json'
        layout = read_json(path)
        original = {p['name']: source_pixels(case, p) for p in layout['parts']}
        rest = np.array(Image.open(case / f'source/{view}/processed.png').convert('RGBA'))[..., 3] > 0
        protected = np.zeros_like(rest)
        for part in layout['parts']:
            if part.get('feature'):
                protected |= original[part['name']][..., 3] > 0
        rows = [r for r in samples['samples'] if r['view'] == view]
        for part in layout['parts']:
            if not part.get('hidden_material'):
                continue
            seed = original[part['name']].copy()
            footprint = seed[..., 3] > 0
            donor = seed.copy()
            donor[protected] = 0
            target = footprint.copy()
            joints = []
            for neighbour in layout['parts']:
                if neighbour.get('feature') or neighbour['bone'] == part['bone']:
                    continue
                if neighbour['z_index'] <= part['z_index']:
                    continue
                other = original[neighbour['name']][..., 3] > 0
                contact = dilate(footprint, 1, grid_distance=True) & other & ~protected
                if not contact.any():
                    continue
                ys, xs = np.nonzero(contact)
                points = np.stack((xs + .5, ys + .5, np.ones(len(xs))))
                maximum, worst = 0., None
                for row in rows:
                    difference = source_transform(row, part) - source_transform(row, neighbour)
                    delta = difference[:2, 0, None] * points[0] + difference[:2, 1, None] * points[1] + difference[:2, 2, None]
                    separation = np.linalg.norm(delta, axis=0).max()
                    if separation > maximum:
                        maximum, worst = float(separation), {'clip': row['clip'], 'frame': row['frame']}
                margin = math.ceil(maximum) + 1
                addition = dilate(footprint, margin) & other & rest & ~protected
                target |= addition
                joints.append({'neighbour': neighbour['name'], 'maximum_sampled_separation_px': maximum,
                               'margin_px': margin, 'worst_pose': worst, 'eligible_pixels': int(addition.sum())})
            labels, groups = components(target)
            connected = labels == max(groups, key=lambda g: int(((labels == g[0]) & footprint).sum()))[0]
            result = edge_texels(donor, connected)
            # Existing material is immutable at its original pixels; only the
            # newly covered neighbour region receives synthesized edge paint.
            result[footprint] = seed[footprint]
            surfaces[view, part['name']] = (seed, result)
            records.append({'view': view, 'part': part['name'], 'added_pixels': int((connected & ~footprint).sum()),
                            'joints': joints})
    return records, surfaces


def extend(case, samples):
    records, surfaces = domains(case, samples)
    for view in ('front', 'rear'):
        path = case / f'layouts/{view}.json'
        layout = read_json(path)
        for part in layout['parts']:
            if (view, part['name']) in surfaces:
                store(case, part, surfaces[view, part['name']][1])
        write_json(path, layout)
    return records

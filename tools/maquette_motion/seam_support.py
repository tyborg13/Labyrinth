"""Use only seam-needed bleed; reject support that encloses another gap."""
from collections import deque
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, write_json
from maquette_motion import pixels, silhouette
from maquette_motion.bleed import domains, source_transform
from maquette_motion.continuity import NEIGHBOURS_8, store
from maquette_motion.features import source_pixels


def connected_extension(seed, requested, allowed):
    visited = seed.copy()
    pending = deque(map(tuple, np.argwhere(seed)))
    wanted = set(map(tuple, np.argwhere(requested & ~seed)))
    parents = {}
    h, w = seed.shape
    while pending and wanted:
        y, x = pending.popleft()
        for dy, dx in NEIGHBOURS_8:
            a, b = y + dy, x + dx
            if 0 <= a < h and 0 <= b < w and allowed[a, b] and not visited[a, b]:
                visited[a, b] = True
                parents[a, b] = y, x
                pending.append((a, b))
                wanted.discard((a, b))
    result = seed.copy()
    for point in map(tuple, np.argwhere(requested & visited)):
        while point in parents and not result[point]:
            result[point] = True
            point = parents[point]
    return result


def uv_image(domain):
    result = np.zeros_like(domain)
    ys, xs = np.indices(domain.shape[:2])
    result[..., 0], result[..., 1], result[..., 3] = xs, ys, domain[..., 3]
    return Image.fromarray(result)


def project_addition(image, mask, row, part):
    ys, xs = np.nonzero(mask)
    matrix = source_transform(row, part)
    corners = np.array([[xs.min(), ys.min(), 1], [xs.max() + 1, ys.min(), 1],
                        [xs.max() + 1, ys.max() + 1, 1], [xs.min(), ys.max() + 1, 1]]).T
    points = matrix @ corners
    size = pixels.PROOF_DEFAULTS['canvas_size']
    low = np.maximum(0, np.floor(points[:2].min(axis=1) + pixels.PROOF_DEFAULTS['source_offset']).astype(int) - 1)
    high = np.minimum(size, np.ceil(points[:2].max(axis=1) + pixels.PROOF_DEFAULTS['source_offset']).astype(int) + 1)
    result = np.zeros((size, size, 4), np.uint8)
    left, top, right, bottom = int(low[0]), int(low[1]), int(high[0]), int(high[1])
    if left < right and top < bottom:
        result[top:bottom, left:right] = pixels.render(image, matrix, (left, top, right, bottom))
    return result


def repair(case, samples):
    records, surfaces = domains(case, samples)
    attempts = []
    for view in ('front', 'rear'):
        path = case / f'layouts/{view}.json'
        layout = read_json(path)
        parts = {p['name']: p for p in layout['parts']}
        for part in parts.values():
            if part['name'] == part['bone']:
                part.setdefault('presentation_anchor', part['offset'].copy())
        definitions = silhouette.rest_hole_owners(case, layout)
        images = {n: Image.open(case / p['file']).convert('RGBA') for n, p in parts.items()}
        unique = {}
        for row in samples['samples']:
            if row['view'] == view:
                key = tuple((n, tuple(v['transform']), v['alpha']) for n, v in row['parts'].items())
                unique.setdefault(key, row)
        states = []
        for row in unique.values():
            alpha = silhouette.compose(case, layout, row, images)
            rest = silhouette.pose_rest_holes(definitions, row)
            metric, _, holes = silhouette.measure(alpha, rest)
            states.append(dict(row=row, alpha=alpha, rest=rest, metric=metric, holes=holes))
        masks = {n: surfaces[view, n][0][..., 3] > 0 for n in parts if (view, n) in surfaces}
        coordinates = {n: uv_image(surfaces[view, n][1]) for n in masks}
        while True:
            targets = {n: np.zeros_like(mask) for n, mask in masks.items()}
            for state in states:
                for hole in state['holes']:
                    ys, xs = np.nonzero(hole)
                    bounds = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
                    left, top, right, bottom = bounds
                    remaining = hole[top:bottom, left:right]
                    for n in masks:
                        if state['row']['parts'][n]['alpha'] <= 0:
                            continue
                        uv = pixels.render(coordinates[n], source_transform(state['row'], parts[n]), bounds)
                        covered = (uv[..., 3] > 0) & remaining
                        # Retain every eligible donor. A donor that covers more
                        # of this hole may be unsafe in another pose; that must
                        # not prevent a different joint from supplying support.
                        targets[n][uv[..., 1][covered], uv[..., 0][covered]] = True
            added = 0
            for n, requested in targets.items():
                original = masks[n]
                candidate = connected_extension(original, requested, surfaces[view, n][1][..., 3] > 0)
                while (candidate & ~original).any():
                    texels = np.zeros_like(surfaces[view, n][1])
                    texels[candidate & ~original] = surfaces[view, n][1][candidate & ~original]
                    uv_source = uv_image(texels)
                    trials, rejected, worsened = [], np.zeros_like(candidate), False
                    for state in states:
                        row = state['row']
                        projected = project_addition(uv_source, candidate & ~original, row, parts[n])
                        delta = pixels.round_pixels(projected[..., 3] * row['parts'][n]['alpha']) > 0
                        alpha = state['alpha'] | delta
                        if np.array_equal(alpha, state['alpha']):
                            trials.append((state['alpha'], state['metric'], state['holes']))
                            continue
                        metric, _, holes = silhouette.measure(alpha, state['rest'])
                        if metric['new_hole_pixels'] > state['metric']['new_hole_pixels'] or metric['detached_pixels'] > state['metric']['detached_pixels']:
                            worsened = True
                            boundary = np.zeros_like(alpha)
                            for hole in holes: boundary |= silhouette.dilate(hole, 1, grid_distance=True) & ~hole
                            bad = boundary & delta & ~state['alpha']
                            rejected[projected[..., 1][bad], projected[..., 0][bad]] = True
                        trials.append((alpha, metric, holes))
                    if worsened and not rejected.any():
                        break
                    if rejected.any():
                        labels, groups = silhouette.components(candidate & ~rejected)
                        candidate = labels == max(groups, key=lambda g: int(((labels == g[0]) & original).sum()))[0]
                        candidate |= original
                        continue
                    if sum(t[1]['new_hole_pixels'] for t in trials) >= sum(s['metric']['new_hole_pixels'] for s in states):
                        break
                    masks[n] = candidate
                    added += int((candidate & ~original).sum())
                    for state, (alpha, metric, holes) in zip(states, trials):
                        state.update(alpha=alpha, metric=metric, holes=holes)
                    break
            attempts.append({'view': view, 'added_pixels': added,
                             'new_hole_pixels': sum(s['metric']['new_hole_pixels'] for s in states)})
            print('MAQUETTE SEAM BLEED: ' + str(attempts[-1]), flush=True)
            if not added: break
        for n, mask in masks.items():
            image = surfaces[view, n][1].copy()
            image[~mask] = 0
            store(case, parts[n], image)
        write_json(path, layout)
    for record in records:
        seed, domain = surfaces[record['view'], record['part']]
        result = source_pixels(case, next(p for p in read_json(case / f'layouts/{record["view"]}.json')['parts'] if p['name'] == record['part']))
        record['accepted_pixels'] = int(((result[..., 3] > 0) & (seed[..., 3] == 0)).sum())
    return {'joints': records, 'attempts': attempts}

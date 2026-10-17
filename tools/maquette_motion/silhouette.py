"""Eight-connected paint and pose silhouette checks, without optional packages."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion import pixels

# Acceptance limits supplied by director feedback 4, in source/native pixels.
DETACHED_DISTANCE_PX = 2
MIN_NEW_HOLE_PIXELS = 2
BACKGROUND_CONNECTIVITY = 4


def components(mask, connectivity=8):
    """Run-length union/find; avoid a Python visit for every background pixel."""
    mask = np.asarray(mask, dtype=bool)
    labels = np.zeros(mask.shape, dtype=np.int32)
    parent = [0]
    runs, previous = [], []

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    edges = np.diff(np.pad(mask.astype(np.int8), ((0, 0), (1, 1))), axis=1)
    for y in range(mask.shape[0]):
        if not mask[y].any():
            previous = []
            continue
        starts, ends = np.flatnonzero(edges[y] == 1), np.flatnonzero(edges[y] == -1)
        current, cursor = [], 0
        for start, end in zip(starts, ends):
            index = len(parent)
            parent.append(index)
            while cursor < len(previous) and previous[cursor][1] < start + (connectivity == 4):
                cursor += 1
            for a, b, other in previous[cursor:]:
                if a > end - (connectivity == 4):
                    break
                first, second = find(index), find(other)
                if first != second:
                    parent[second] = first
            current.append((int(start), int(end), index))
            runs.append((y, int(start), int(end), index))
        previous = current
    for y, start, end, index in runs:
        labels[y, start:end] = find(index)
    ids, sizes = np.unique(labels[mask], return_counts=True)
    ordered = sorted(zip(ids.tolist(), sizes.tolist()), key=lambda item: (-item[1], item[0]))
    return labels, ordered


def dilate(mask, radius, grid_distance=False):
    result = np.zeros_like(mask)
    padded = np.pad(mask, radius)
    h, w = mask.shape
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if grid_distance or dx * dx + dy * dy <= radius * radius:
                result |= padded[radius + dy:radius + dy + h, radius + dx:radius + dx + w]
    return result


def holes(mask):
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return []
    left, top = max(0, int(xs.min()) - 1), max(0, int(ys.min()) - 1)
    right, bottom = min(mask.shape[1], int(xs.max()) + 2), min(mask.shape[0], int(ys.max()) + 2)
    labels, groups = components(~mask[top:bottom, left:right], BACKGROUND_CONNECTIVITY)
    exterior = set(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])).tolist())
    result = []
    for label, _ in groups:
        if label not in exterior:
            hole = np.zeros_like(mask)
            hole[top:bottom, left:right] = labels == label
            result.append(hole)
    return result


def measure(mask, rest_holes=(), distance=DETACHED_DISTANCE_PX, anatomy=None, grid_distance=False):
    labels, groups, enclosed = anatomy if anatomy is not None else (*components(mask), holes(mask))
    detached = []
    if groups:
        nearby = dilate(labels == groups[0][0], distance, grid_distance)
        detached = [labels == label for label, _ in groups[1:] if not nearby[labels == label].any()]
    current_holes = [h for h in enclosed if int(h.sum()) >= MIN_NEW_HOLE_PIXELS]
    # A rest hole may deform, but cannot explain two new enclosed components.
    available = list(rest_holes)
    new = []
    for hole in current_holes:
        overlaps = [int((hole & old).sum()) for old in available]
        if overlaps and max(overlaps):
            available.pop(int(np.argmax(overlaps)))
        else:
            new.append(hole)
    return {'detached_pixels': sum(int(c.sum()) for c in detached), 'islands': len(detached),
            'new_hole_pixels': sum(int(h.sum()) for h in new), 'new_holes': len(new)}, detached, new


def compose(case, layout, row, images=None):
    size = pixels.PROOF_DEFAULTS['canvas_size']
    result = np.zeros((size, size), dtype=bool)
    for part in layout['parts']:
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
        left, top, right, bottom = int(low[0]), int(low[1]), int(high[0]), int(high[1])
        alpha = pixels.render(image, transform, (left, top, right, bottom))[..., 3]
        result[top:bottom, left:right] |= pixels.modulated_alpha(alpha, node['alpha']) > 0
    return result


def rest_hole_owners(case, layout):
    from maquette_motion.features import source_pixels
    paint = np.array(Image.open(case / layout['rest_source']).convert('RGBA'))
    visible = [p for p in layout['parts'] if not p.get('hidden_material') and not p.get('seam_underlay')]
    result = []
    for hole in holes(paint[..., 3] > 0):
        border = dilate(hole, 1) & ~hole
        owner = max(visible, key=lambda p: int((border & (source_pixels(case, p)[..., 3] > 0)).sum()))
        image = np.zeros_like(paint)
        image[hole] = 255
        result.append((owner, Image.fromarray(image)))
    return result


def pose_rest_holes(definitions, row):
    result = []
    for part, image in definitions:
        transform = pixels.unpack(row['parts'][part['name']]['transform'])
        transform[:2, 2] -= transform[:2, :2] @ np.asarray(part['offset'])
        result.append(pixels.render(image, transform)[..., 3] > 0)
    return result


def pose_report(case, report, native=None, legacy_hole_gate=False):
    """Every 60 Hz pose, both views and all clips, including death and loop holds."""
    failures, results = [], []
    native_rows = {} if native is None else {(r['view'], r['clip'], r['frame']): r for r in native['frames']}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        definitions = rest_hole_owners(case, layout)
        images = {p['name']: Image.open(case / p['file']).convert('RGBA') for p in layout['parts']}
        cache, measurements = {}, {}
        for row in (r for r in report['samples'] if r['view'] == view):
            key = (view, row['clip'], row['frame'])
            if native is None:
                signature = tuple((name, tuple(node['transform']), node['alpha']) for name, node in row['parts'].items())
                if signature not in cache:
                    cache[signature] = compose(case, layout, row, images)
                mask = cache[signature]
            else:
                if key not in native_rows:
                    failures.append(f'{view}/{row["clip"]}/{row["frame"]}: missing native silhouette')
                    continue
                mask = np.array(Image.open(native['directory'] / native_rows[key]['file']).convert('RGBA'))[..., 3] > 0
                if mask.shape != (pixels.PROOF_DEFAULTS['canvas_size'], pixels.PROOF_DEFAULTS['canvas_size']):
                    failures.append(f'{view}/{row["clip"]}/{row["frame"]}: wrong native silhouette dimensions')
                    continue
            signature = tuple((name, tuple(node['transform']), node['alpha']) for name, node in row['parts'].items())
            cache_key = (signature, native_rows[key]['sha256'] if native is not None else None)
            if cache_key not in measurements:
                rest = pose_rest_holes(definitions, row)
                anatomy = (*components(mask), holes(mask))
                metric, _, _ = measure(mask, rest, anatomy=anatomy)
                historical, _, _ = measure(mask, rest, distance=3, anatomy=anatomy, grid_distance=True)
                measurements[cache_key] = metric, historical
            metric, historical = measurements[cache_key]
            results.append({'view': view, 'clip': row['clip'], 'frame': row['frame'], **metric,
                            'director_distance_3px': historical})
            if metric['islands'] or (legacy_hole_gate and metric['new_holes']):
                failures.append(f'{view}/{row["clip"]}/{row["frame"]}: detached {metric["detached_pixels"]}px/{metric["islands"]} islands; new holes {metric["new_hole_pixels"]}px/{metric["new_holes"]}')
    worst, historical_worst, hole_worst = {}, {}, {}
    for row in results:
        key = row['view'] + '_' + row['clip']
        if key not in worst or (row['detached_pixels'], row['islands']) > (worst[key]['detached_pixels'], worst[key]['islands']):
            worst[key] = row
        if key not in historical_worst or (row['director_distance_3px']['detached_pixels'], row['director_distance_3px']['islands']) > (historical_worst[key]['director_distance_3px']['detached_pixels'], historical_worst[key]['director_distance_3px']['islands']):
            historical_worst[key] = row
        if key not in hole_worst or row['new_hole_pixels'] > hole_worst[key]['new_hole_pixels']:
            hole_worst[key] = row
    return {'ok': not failures, 'errors': failures, 'native_pixels': native is not None,
            'detached_distance_px': DETACHED_DISTANCE_PX, 'minimum_new_hole_pixels': MIN_NEW_HOLE_PIXELS,
            'detached_distance_metric': 'Euclidean (conservative relative to 8-neighbour grid distance)',
            'director_table_distance_metric': '8-neighbour grid distance >3 px; exactly reproduces supplied worst-pose table',
            'background_connectivity': BACKGROUND_CONNECTIVITY,
            'hole_policy': 'legacy hole counts are diagnostic; feedback8 seam_pose gates interior tears and reports natural negative space', 'poses': results, 'worst_by_clip': worst,
            'worst_by_clip_distance_3px': historical_worst, 'worst_holes_by_clip': hole_worst}


def part_report(case):
    errors, rows = [], []
    from maquette_motion.features import source_pixels
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        for part in layout['parts']:
            _, groups = components(source_pixels(case, part)[..., 3] > 0)
            rows.append({'view': view, 'part': part['name'], 'components': len(groups), 'pixels': sum(n for _, n in groups)})
            if len(groups) != 1:
                errors.append(f'{view}/{part["name"]}: expected one 8-connected painted component, got {len(groups)}')
    return {'ok': not errors, 'errors': errors, 'parts': rows}

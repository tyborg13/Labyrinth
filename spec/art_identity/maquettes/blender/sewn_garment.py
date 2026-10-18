"""A continuous rest garment: torso armholes share vertices with both sleeves.

Attachment loops are cut in the measured torso grid, then extruded along the
measured limb chain. There are no independently simulated shoulder rings.
Semantic source-face tags survive cloth, contact subdivision and cache replay.
"""
from collections import Counter
import numpy as np

SEWN_DEFAULTS = {'revision': 1, 'epsilon': 1e-10, 'owner_attribute': 'sewn_owner'}


def boundary_loop(row0, row1, col0, width, columns):
    def at(r, c):
        return r * columns + c % columns
    return ([at(row0, c) for c in range(col0, col0 + width)] +
            [at(r, col0 + width) for r in range(row0, row1)] +
            [at(row1, c) for c in range(col0 + width, col0, -1)] +
            [at(r, col0) for r in range(row1, row0, -1)])


def sew(torso, sleeves, spec, settings):
    from copy import deepcopy
    from .contract import pattern_mesh
    result = deepcopy(torso)
    vertices, original_faces = pattern_mesh(torso['pattern'], torso['rag'])
    vertices = list(vertices)
    columns = torso['pattern']['columns']
    rows = len(torso['pattern']['rows'])
    blocked, holes = set(), []
    for sleeve, seam in zip(sleeves, settings):
        start, end = seam['rows']
        shoulder = np.array(spec['joints'][seam['shoulder']])
        centre = np.mean(np.array(torso['pattern']['rows'][start]['points']), axis=0)
        delta = shoulder - centre
        angles = np.arctan2(np.array(torso['pattern']['rows'][start]['points'])[:, 1] - centre[1],
                            np.array(torso['pattern']['rows'][start]['points'])[:, 0] - centre[0])
        angle = np.arctan2(delta[1], delta[0])
        middle = int(np.argmin(np.abs(np.angle(np.exp(1j * (angles - angle))))))
        col0 = middle - seam['columns'] // 2
        hole = boundary_loop(start, end, col0, seam['columns'], columns)
        for r in range(start, end):
            for c in range(col0, col0 + seam['columns']):
                blocked.add(r * columns + c % columns)
        holes.append((sleeve, hole))
    faces = [list(f) for i, f in enumerate(original_faces) if i not in blocked]
    owners = [list(spec['labels']).index(torso['part'])] * len(faces)
    pins = set(torso['pattern']['pins'])
    sewn_parts = [torso['part']]
    for sleeve, hole in holes:
        source = np.array([row['points'] for row in sleeve['pattern']['rows']], float)
        # The first sleeve ring is replaced by the torso boundary itself.
        # Equal counts give an actual sewn junction, not coincident surfaces.
        if len(hole) != source.shape[1]:
            raise ValueError('Sewn armhole and sleeve circumference counts differ')
        first = source[0]
        boundary = np.array([vertices[i] for i in hole])
        choices = [(float(np.sum((boundary - np.roll(first[::direction], shift, axis=0)) ** 2)), direction, shift)
                   for direction in (1, -1) for shift in range(len(hole))]
        _, direction, shift = min(choices)
        source = np.roll(source[:, ::direction], shift, axis=1)
        previous = hole
        pair = sleeve['joint_parts']
        sewn_parts.extend(pair)
        for row_index, ring in enumerate(source[1:], 1):
            ring_indices = list(range(len(vertices), len(vertices) + len(ring)))
            vertices.extend(ring.tolist())
            owner = list(spec['labels']).index(pair[0 if row_index < (len(source) - 1) / 2 else 1])
            for j, a in enumerate(previous):
                k = (j + 1) % len(hole)
                faces.append([a, previous[k], ring_indices[k], ring_indices[j]])
                owners.append(owner)
            previous = ring_indices
        upper = sorted(range(len(previous)), key=lambda j: (-vertices[previous[j]][2], j))[:2]
        pins.update(previous[j] for j in upper)
    used = sorted({i for f in faces for i in f})
    remap = {old: new for new, old in enumerate(used)}
    result['pattern']['explicit'] = {'vertices': [vertices[i] for i in used],
        'faces': [[remap[i] for i in f] for f in faces], 'owners': owners}
    result['pattern']['pins'] = sorted(remap[i] for i in pins if i in remap)
    result['sewn_parts'] = sewn_parts
    result['sewn_revision'] = SEWN_DEFAULTS['revision']
    result['drape'].pop('cutout_regions', None)
    return result


def topology_report(vertices, faces):
    edges = Counter(tuple(sorted((a, b))) for f in faces for a, b in zip(f, f[1:] + f[:1]))
    adjacency = {i: set() for i in range(len(vertices))}
    for a, b in edges:
        adjacency[a].add(b)
        adjacency[b].add(a)
    seen, stack = set(), [0]
    while stack:
        i = stack.pop()
        if i not in seen:
            seen.add(i)
            stack.extend(adjacency[i] - seen)
    boundary = {i for e, count in edges.items() if count == 1 for i in e}
    loops = 0
    while boundary:
        loops += 1
        stack = [min(boundary)]
        while stack:
            i = stack.pop()
            if i in boundary:
                boundary.remove(i)
                stack.extend(j for j in adjacency[i] if tuple(sorted((i, j))) in edges and edges[tuple(sorted((i, j)))] == 1)
    return {'connected': len(seen) == len(vertices), 'nonmanifold_edges': sum(c > 2 for c in edges.values()),
            'boundary_loops': loops}

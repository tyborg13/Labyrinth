"""Measure complete painted texel edges through the actual presented skin field.

Each unit horizontal/vertical edge bordering an opaque texel is clipped against
the source triangles. Its posed length is the sum of those affine subsegments,
not a bone scale, triangle diagonal, or a distance between rounded pixels.
Hidden material is included. The caller supplies the limit; nothing alters poses.
"""
import math

import numpy as np
from PIL import Image

from .bone_evidence import evidence_errors
from .gates import matrix

WEIGHT_SUM_EPSILON = 1e-6
GEOMETRY_EPSILON = 1e-9  # Source geometry roundoff, never a stretch allowance.


def texel_edges(image):
    occupied = np.asarray(image)[..., 3] > 0
    y, x = np.nonzero(occupied)
    edges = []
    for px, py in zip(x.tolist(), y.tolist()):
        # Retain the owning texel: a split UV boundary has two physical sides.
        edges.extend(((px, py, 0, px, py), (px, py + 1, 0, px, py),
                      (px, py, 1, px, py), (px + 1, py, 1, px, py)))
    return np.asarray(edges, dtype=int).reshape(-1, 5)


def edge_segments(mesh, image):
    """Barycentric endpoints of each edge's nonoverlapping triangle intervals."""
    edges = texel_edges(image)
    if not len(edges):
        return edges, []
    starts = edges[:, :2].astype(float)
    ends = starts.copy()
    ends[np.arange(len(edges)), edges[:, 2]] += 1
    vertices = np.asarray(mesh['uvs'], dtype=float)
    if not np.isfinite(vertices).all():
        raise ValueError('nonfinite skin UVs')
    claimed = [[] for _ in edges]
    segments = []
    for indices in np.asarray(mesh['triangles'], dtype=int):
        tri = vertices[indices]
        basis = np.column_stack((tri[1] - tri[0], tri[2] - tri[0]))
        if abs(np.linalg.det(basis)) <= GEOMETRY_EPSILON:
            raise ValueError('degenerate source skin triangle')
        low, high = tri.min(0), tri.max(0)
        selected = np.flatnonzero(np.all(ends >= low - GEOMETRY_EPSILON, axis=1) &
                                  np.all(starts <= high + GEOMETRY_EPSILON, axis=1))
        if not len(selected):
            continue
        inverse = np.linalg.inv(basis)
        ab = (starts[selected] - tri[0]) @ inverse.T
        cd = (ends[selected] - tri[0]) @ inverse.T
        a = np.column_stack((1 - ab.sum(1), ab))
        b = np.column_stack((1 - cd.sum(1), cd))
        context_ab = (edges[selected, 3:5] + .5 - tri[0]) @ inverse.T
        context = np.column_stack((1 - context_ab.sum(1), context_ab))
        for edge, first, last, interior in zip(selected, a, b, context):
            # On a UV seam, use the limit from inside this particular texel.
            outside = (np.abs(first) <= GEOMETRY_EPSILON) & (np.abs(last) <= GEOMETRY_EPSILON) & (interior < -GEOMETRY_EPSILON)
            if outside.any():
                continue
            lo, hi = 0., 1.
            for initial, delta in zip(first, last - first):
                if abs(delta) <= GEOMETRY_EPSILON:
                    if initial < -GEOMETRY_EPSILON:
                        hi = -1.
                        break
                elif delta > 0:
                    lo = max(lo, -initial / delta)
                else:
                    hi = min(hi, -initial / delta)
            if hi - lo <= GEOMETRY_EPSILON:
                continue
            # Shared triangle boundaries must contribute once, not twice.
            intervals = [(lo, hi)]
            for used_lo, used_hi in claimed[edge]:
                remaining = []
                for left, right in intervals:
                    if used_lo > left: remaining.append((left, min(right, used_lo)))
                    if used_hi < right: remaining.append((max(left, used_hi), right))
                intervals = [(l, r) for l, r in remaining if r-l > GEOMETRY_EPSILON]
            for left, right in intervals:
                segments.append((edge, indices, first + (last-first)*left,
                                 first + (last-first)*right, right-left))
                claimed[edge].append((left, right))
    coverage = np.array([sum(r-l for l, r in row) for row in claimed])
    if not np.allclose(coverage, 1., atol=GEOMETRY_EPSILON, rtol=0):
        raise ValueError('painted texel edge outside skin topology')
    return edges, segments


def posed_vertices(layout, mesh, pose):
    vertices = np.asarray(mesh['vertices'], dtype=float)
    result = np.zeros_like(vertices)
    total = np.zeros(len(vertices))
    for name, values in mesh['weights'].items():
        weights = np.asarray(values, dtype=np.float32).astype(float)
        if weights.shape != total.shape or not np.isfinite(weights).all() or np.min(weights) < 0:
            raise ValueError('invalid skin weights')
        transform = matrix(pose['bones'][name]['global'])
        bind = np.asarray(layout['joints'][name]['position'])
        delta = vertices-bind
        posed = np.column_stack((delta[:, 0]*transform[0, 0] + delta[:, 1]*transform[0, 1] + transform[0, 2],
                                 delta[:, 0]*transform[1, 0] + delta[:, 1]*transform[1, 1] + transform[1, 2]))
        result += weights[:, None] * posed
        total += weights
    if not np.allclose(total, 1., atol=WEIGHT_SUM_EPSILON, rtol=0) or not np.isfinite(result).all():
        raise ValueError('invalid presented skin geometry')
    return result


def declared_scale(part):
    scale = part.get('declared_uniform_scale', 1.)
    if type(scale) not in (int, float) or not math.isfinite(scale) or scale <= 0:
        raise ValueError('invalid declared uniform scale')
    return scale


def measure(layout, mesh, image, rows, *, declared_uniform_scale=1.):
    scale = declared_scale(dict(declared_uniform_scale=declared_uniform_scale))
    edges, segments = edge_segments(mesh, image)
    if not len(edges):
        raise ValueError('empty skinned material')
    owners = np.array([s[0] for s in segments])
    indices = np.array([s[1] for s in segments])
    delta = np.array([s[3]-s[2] for s in segments])
    rest = np.asarray(mesh['vertices'], dtype=float)
    rest_lengths = np.bincount(owners, weights=np.linalg.norm(
        np.sum(rest[indices] * delta[..., None], axis=1), axis=1), minlength=len(edges))
    if np.min(rest_lengths) <= GEOMETRY_EPSILON:
        raise ValueError('collapsed rest texel edge')
    maximum, worst, frames = 0., None, []
    for pose in rows:
        vertices = posed_vertices(layout, mesh, pose)
        lengths = np.bincount(owners, weights=np.linalg.norm(
            np.sum(vertices[indices] * delta[..., None], axis=1), axis=1), minlength=len(edges))
        ratios = lengths / (rest_lengths * scale)
        index = int(ratios.argmax())
        stretch = max(0., float(ratios[index]-1))
        row = dict(clip=pose['clip'], frame=pose['frame'], phase=pose['phase'],
                   maximum_stretch=stretch, edge=edges[index, :3].tolist(), texel=edges[index, 3:5].tolist())
        frames.append(row)
        if worst is None or stretch > maximum:
            maximum, worst = stretch, row
    return dict(maximum_stretch=maximum, maximum_percent=maximum*100,
                worst=worst, frames=frames, texel_edges=len(edges), sampled_frames=len(rows),
                declared_uniform_scale=scale, kind='skinned')


def rigid_measure(part, rows):
    """A rigid affine basis has one constant strain over every painted texel.

    Divide out only the explicitly declared uniform scale. Joint spacing in
    the rigid gait is not a texture deformation and is never inferred from
    parent/child distances. Singular values also catch shear hidden by unit
    determinant or by short horizontal/vertical edges.
    """
    scale = declared_scale(part)
    maximum, worst, frames = 0., None, []
    for pose in rows:
        basis = matrix(pose['parts'][part['name']]['transform'])[:2, :2]
        if not np.isfinite(basis).all(): raise ValueError('nonfinite rigid geometry')
        stretch = max(0., float(np.linalg.svd(basis, compute_uv=False)[0] / scale - 1))
        row = dict(clip=pose['clip'], frame=pose['frame'], phase=pose['phase'],
                   maximum_stretch=stretch)
        frames.append(row)
        if worst is None or stretch > maximum: maximum, worst = stretch, row
    if not rows: raise ValueError('missing presented rigid geometry')
    return dict(maximum_stretch=maximum, maximum_percent=maximum*100,
                worst=worst, frames=frames, sampled_frames=len(rows),
                declared_uniform_scale=scale, kind='rigid',
                basis='maximum affine singular value / declared uniform scale')


def report(case, layouts, data, samples, current_bindings, *, maximum_stretch):
    if not isinstance(maximum_stretch, (int, float)) or not math.isfinite(maximum_stretch) or maximum_stretch < 0:
        raise ValueError('stretch limit must be finite and nonnegative')
    errors = evidence_errors(data, samples, current_bindings, .0001)
    pieces = {}
    for view, layout in layouts.items():
        parts = {part['name']: part for part in layout['parts']}
        rows = [r for r in samples['samples'] if r['view'] == view and r['kind'] == 'presented']
        for mesh in layout.get('joint_meshes', []):
            name = view + '/' + mesh['name']
            try:
                with Image.open(case / mesh['file']) as image:
                    # A mesh is the deformation field for its declared piece;
                    # scale belongs to that piece, just as for a rigid sprite.
                    measured = measure(layout, mesh, image.convert('RGBA'), rows,
                        declared_uniform_scale=declared_scale(parts[mesh['name']]))
                pieces[name] = measured
                if measured['maximum_stretch'] > maximum_stretch + GEOMETRY_EPSILON:
                    errors.append('%s: %.6f%% exceeds %.6f%% at %s/%s' % (
                        name, measured['maximum_percent'], maximum_stretch*100,
                        measured['worst']['clip'], measured['worst']['frame']))
            except (ValueError, KeyError, IndexError, OSError) as error:
                errors.append(name + ': ' + str(error))
        meshes = {m['name'] for m in layout.get('joint_meshes', [])}
        for part in layout['parts']:
            if part['name'] in meshes: continue
            name = view + '/' + part['name']
            try:
                measured = rigid_measure(part, rows)
                pieces[name] = measured
                if measured['maximum_stretch'] > maximum_stretch + GEOMETRY_EPSILON:
                    errors.append('%s: %.6f%% exceeds %.6f%% at %s/%s' % (
                        name, measured['maximum_percent'], maximum_stretch*100,
                        measured['worst']['clip'], measured['worst']['frame']))
            except (ValueError, KeyError, IndexError) as error:
                errors.append(name + ': ' + str(error))
    if not pieces: errors.append('stretch: no painted pieces measured')
    return dict(ok=not errors, errors=errors, maximum_stretch=maximum_stretch,
                basis='presented transforms; skin texel edges and rigid local strain; hidden material included; declared uniform scale removed',
                native_pixels=False, pieces=pieces)

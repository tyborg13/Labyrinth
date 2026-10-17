"""NumPy triangle meshes shared by the fit tool and Blender.

Coordinates are x forward, y left, z up. Rotations use Blender XYZ Euler
angles (radians). Legacy tessellation is retained; no Blender modifiers are
allowed to change geometry after this module has built it.
"""
from __future__ import annotations

from dataclasses import dataclass
import math

import numpy as np


# Numerical approximation settings, not creature design values.
MESH_DEFAULTS = {"sphere_segments": 24, "sphere_rings": 12,
                 "capsule_segments": 20, "capsule_rings": 10,
                 "bevel_segments": 4, "torus_segments": 48,
                 "torus_sides": 12, "loft_segments": 32,
                 "limb_steps": 16, "cloth_rows": 24, "cloth_columns": 64,
                 "remesh_max_cells": 8_000_000, "remesh_relax_steps": 2,
                 "remesh_relax_weight": 0.25}


@dataclass
class Mesh:
    vertices: np.ndarray
    faces: np.ndarray

    def __post_init__(self):
        self.vertices = np.asarray(self.vertices, dtype=float).reshape(-1, 3)
        self.faces = np.asarray(self.faces, dtype=np.int32).reshape(-1, 3)
        if not np.isfinite(self.vertices).all():
            raise ValueError("Non-finite mesh coordinates")
        if self.faces.size and (self.faces.min() < 0 or self.faces.max() >= len(self.vertices)):
            raise ValueError("Mesh index outside vertex array")


def join(meshes):
    vertices, faces, offset = [], [], 0
    for mesh in meshes:
        vertices.append(mesh.vertices)
        faces.append(mesh.faces + offset)
        offset += len(mesh.vertices)
    return Mesh(np.concatenate(vertices) if vertices else [], np.concatenate(faces) if faces else [])


def welded(mesh):
    vertices, inverse = np.unique(np.round(mesh.vertices, 12), axis=0, return_inverse=True)
    faces = inverse[mesh.faces]
    valid = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 2] != faces[:, 0])
    return Mesh(vertices, faces[valid])


def euler(rot):
    x, y, z = rot
    cx, cy, cz = np.cos(rot)
    sx, sy, sz = np.sin(rot)
    return np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]) @ np.array(
        [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]) @ np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])


def transform(mesh, centre=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0)):
    return Mesh((mesh.vertices * scale) @ euler(rot).T + centre, mesh.faces.copy())


def grid_mesh(rows, close=False):
    rows = np.asarray(rows, dtype=float)
    h, w = rows.shape[:2]
    faces = []
    for i in range(h - 1):
        for j in range(w if close else w - 1):
            k = (j + 1) % w
            a, b, c, d = i * w + j, i * w + k, (i + 1) * w + k, (i + 1) * w + j
            faces.extend([(a, b, c), (a, c, d)])
    return welded(Mesh(rows.reshape(-1, 3), faces))


def sphere(segments=24, rings=12, polar=(0, math.pi), azimuth=(0, 2 * math.pi)):
    if segments < 3 or rings < 2 or not 0 <= polar[0] < polar[1] <= math.pi or not 0 < azimuth[1] - azimuth[0] <= 2 * math.pi + 1e-12:
        raise ValueError('Invalid sphere tessellation or cut angles')
    closed = math.isclose(azimuth[1] - azimuth[0], 2 * math.pi)
    phis = np.linspace(*azimuth, segments, endpoint=False) if closed else np.linspace(*azimuth, segments + 1)
    rows = [[[math.sin(t) * math.cos(p), math.sin(t) * math.sin(p), math.cos(t)] for p in phis]
            for t in np.linspace(*polar, rings + 1)]
    # Parameterisation above winds inward; reverse for solidify and Blender normals.
    mesh = grid_mesh(rows, closed)
    return Mesh(mesh.vertices, mesh.faces[:, ::-1])


def axis_frame(a, b):
    d = np.asarray(b, dtype=float) - a
    length = np.linalg.norm(d)
    if length <= 0:
        raise ValueError("Limb endpoints must differ")
    z = d / length
    # Minimal rotation from +Z, as in Blender's rotation_difference.
    if z[2] < -1 + 1e-12:
        return np.diag([1., -1., -1.]), length
    v = np.cross([0, 0, 1], z)
    skew = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + skew + skew @ skew / (1 + z[2]), length


def frustum(a, b, r1, r2, segments=20):
    frame, length = axis_frame(a, b)
    rows = [[[r * math.cos(p), r * math.sin(p), z] for p in np.arange(segments) * 2 * math.pi / segments]
            for r, z in [(r1, 0), (r2, length)]]
    mesh = grid_mesh(rows, True)
    # Ring order can change during weld; build caps from original coordinates.
    caps = []
    for ring, reverse in [(rows[0], True), (rows[1], False)]:
        cap = Mesh(ring, [(0, j + 1, j) if reverse else (0, j, j + 1) for j in range(1, segments - 1)])
        caps.append(cap)
    mesh = join([mesh, *caps])
    return Mesh(mesh.vertices @ frame.T + a, mesh.faces)


def capsule(a, b, r1, r2):
    unit = sphere(MESH_DEFAULTS['capsule_segments'], MESH_DEFAULTS['capsule_rings'])
    return [frustum(a, b, r1, r2), transform(unit, a, [r1] * 3), transform(unit, b, [r2] * 3)]


def limb(a, b, radii, mid_at):
    if len(radii) != 3 or min(radii) <= 0 or not 0 < mid_at < 1:
        raise ValueError("limb requires three positive radii and 0 < mid_at < 1")
    frame, length = axis_frame(a, b)
    ts = np.unique(np.r_[np.linspace(0, 1, MESH_DEFAULTS['limb_steps'] + 1), mid_at])
    rs = np.interp(ts, [0, mid_at, 1], radii)
    segments = MESH_DEFAULTS['capsule_segments']
    phi = np.arange(segments) * 2 * math.pi / segments
    rows = [np.column_stack([r * np.cos(phi), r * np.sin(phi), np.full(segments, t * length)]) for t, r in zip(ts, rs)]
    mesh = grid_mesh(rows, True)
    mesh = Mesh(mesh.vertices @ frame.T + a, mesh.faces)
    caps = [plate(np.asarray(rows[0])[::-1] @ frame.T + a, 0), plate(np.asarray(rows[-1]) @ frame.T + a, 0)]
    mesh = join([mesh, *caps])
    unit = sphere(segments, MESH_DEFAULTS['capsule_rings'])
    return [mesh, transform(unit, a, [radii[0]] * 3), transform(unit, b, [radii[2]] * 3)]


def rounded_box(bevel, taper):
    if not 0 <= bevel < 1 or taper <= 0:
        raise ValueError("box requires 0 <= bevel < 1 and positive taper")
    if bevel == 0:
        samples = [-1., 1.]
    else:
        core = 1 - bevel
        q = core + bevel * np.tan(np.linspace(0, math.pi / 4, MESH_DEFAULTS['bevel_segments'] // 2 + 1))
        samples = np.r_[-q[::-1], q]
    meshes = []
    for axis in range(3):
        for sign in (-1, 1):
            rows = []
            for u in samples:
                row = []
                for v in samples:
                    p = np.roll([u, v, sign], axis).astype(float)
                    if bevel:
                        inner = np.clip(p, -1 + bevel, 1 - bevel)
                        d = p - inner
                        if taper == 1:
                            p = inner + bevel * d / np.linalg.norm(d)
                        else:
                            # Round the tapered polyhedron in its original
                            # local metric, rather than tapering a rounded cube
                            # (which shrinks the bevel at the top).
                            slope = (1 - taper) / 2
                            norm = math.sqrt(1 + slope * slope)
                            radius = bevel * (norm + slope * inner[2] / (1 - bevel))
                            centre = inner.copy()
                            centre[2] *= (1 - radius) / (1 - bevel)
                            span = (1 + taper) / 2 - slope * centre[2] - radius * norm
                            centre[:2] = inner[:2] / (1 - bevel) * span
                            n = np.array([d[0] / norm, d[1] / norm,
                                          d[2] + slope / norm * (abs(d[0]) + abs(d[1]))])
                            p = centre + radius * n / np.linalg.norm(n)
                    else:
                        p[:2] *= 1 + (taper - 1) * (p[2] + 1) / 2
                    row.append(p)
                rows.append(row)
            m = grid_mesh(rows)
            if sign > 0:
                m.faces = m.faces[:, ::-1]
            meshes.append(m)
    return welded(join(meshes))


def solidify(mesh, thick):
    if not thick:
        return mesh
    normals = vertex_normals(mesh)
    count = len(mesh.vertices)
    # Blender SOLIDIFY defaults to offset=-1 (original surface stays put).
    vertices = np.r_[mesh.vertices, mesh.vertices - thick * normals]
    faces = [*mesh.faces.tolist(), *(mesh.faces[:, ::-1] + count).tolist()]
    edges = {}
    for face in mesh.faces:
        for a, b in zip(face, np.roll(face, -1)):
            key = tuple(sorted((a, b)))
            edges.setdefault(key, []).append((int(a), int(b)))
    for values in edges.values():
        if len(values) == 1:
            a, b = values[0]
            faces.extend([(b, a, a + count), (b, a + count, b + count)])
    return Mesh(vertices, faces)


def vertex_normals(mesh):
    normals = np.zeros_like(mesh.vertices)
    tri = mesh.vertices[mesh.faces]
    ns = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    # Unit face normals approximate Blender's default angle-averaged normals.
    ns /= np.maximum(np.linalg.norm(ns, axis=1, keepdims=True), 1e-15)
    for i in range(3):
        np.add.at(normals, mesh.faces[:, i], ns)
    return normals / np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-15)


def plate(points, thick):
    # Ear clipping supports concave ragged plates; a fan would fill notches.
    points = np.asarray(points, dtype=float)
    normal = np.zeros(3)
    for a, b in zip(points, np.roll(points, -1, axis=0)):
        normal += np.cross(a, b)
    xy = np.delete(points, np.argmax(abs(normal)), axis=1)
    area = np.sum(xy[:, 0] * np.roll(xy[:, 1], -1) - xy[:, 1] * np.roll(xy[:, 0], -1))
    direction = 1 if area > 0 else -1
    ids, faces = list(range(len(points))), []
    def cross(a, b):
        return a[0] * b[1] - a[1] * b[0]
    while len(ids) > 3:
        for k, b in enumerate(ids):
            a, c = ids[k - 1], ids[(k + 1) % len(ids)]
            if cross(xy[b] - xy[a], xy[c] - xy[b]) * direction <= 1e-12:
                continue
            others = [v for v in ids if v not in (a, b, c)]
            if any(all(cross(xy[v] - xy[u], xy[p] - xy[u]) * direction >= -1e-12
                       for u, v in [(a, b), (b, c), (c, a)]) for p in others):
                continue
            faces.append((a, b, c)); ids.pop(k)
            break
        else:
            raise ValueError("Degenerate or self-intersecting plate")
    return solidify(Mesh(points, [*faces, tuple(ids)]), thick)


def torso(shape):
    sections = shape['sections']
    if len(sections) < 2 or any(a['z'] >= b['z'] for a, b in zip(sections, sections[1:])):
        raise ValueError("torso sections must have increasing z")
    phi = np.arange(MESH_DEFAULTS['loft_segments']) * 2 * math.pi / MESH_DEFAULTS['loft_segments']
    rows = []
    lean = shape.get('lean', [0, 0])
    for s in sections:
        if min(s['width'], s['depth']) < 0 or s['round'] <= 0:
            raise ValueError("Nonnegative torso width/depth and positive round required")
        # width is lateral (Y), depth is forward (X); round is superellipse exponent.
        p = 2 / s['round']
        rows.append(np.column_stack([s['depth'] / 2 * np.sign(np.cos(phi)) * abs(np.cos(phi)) ** p + lean[0] * s['z'],
                                     s['width'] / 2 * np.sign(np.sin(phi)) * abs(np.sin(phi)) ** p + lean[1] * s['z'],
                                     np.full(len(phi), s['z'])]))
    mesh = grid_mesh(rows, True)
    caps = [plate(row, 0) for row in (rows[0][::-1], rows[-1]) if np.ptp(row[:, 0]) * np.ptp(row[:, 1]) > 1e-12]
    return welded(join([mesh, *caps]))


def cloak(shape, joints):
    anchors = np.array([point(p, joints) for p in shape['anchors']])
    if len(anchors) < 2:
        raise ValueError("cloak requires at least two anchors")
    # Anchors run from the far shoulder around the back to the near shoulder.
    # Wrap=pi spans the back half; each labelled half can specify angle_range.
    wrap = shape['wrap']
    if not 0 < wrap <= 2 * math.pi or shape['length'] <= 0 or shape['hem_width'] <= 0:
        raise ValueError('cloak requires positive length/hem_width and 0 < wrap <= 2*pi')
    angle = shape.get('angle_range', [-wrap / 2, wrap / 2])
    cols, rows = MESH_DEFAULTS['cloth_columns'], MESH_DEFAULTS['cloth_rows']
    us = np.linspace(0, 1, cols + 1)
    theta = np.linspace(*angle, cols + 1)
    centre = anchors.mean(axis=0)
    top = np.column_stack([np.interp(us, np.linspace(0, 1, len(anchors)), anchors[:, i]) for i in range(3)])
    folds, rag = shape['folds'], shape['rag']
    if any(data['count'] < 0 or int(data['count']) != data['count'] or data['depth'] < 0 for data in (folds, rag)):
        raise ValueError('fold/rag counts must be nonnegative integers and depths nonnegative')
    rng = np.random.default_rng(rag['seed'])
    notch_depths = rng.uniform(0, rag['depth'], rag['count']) if rag['count'] else np.array([])
    phase = us * rag['count']
    notch = (1 - abs(2 * (phase % 1) - 1)) * notch_depths[np.minimum(phase.astype(int), rag['count'] - 1)] if rag['count'] else 0
    radius = shape['hem_width'] / 2
    hem = np.column_stack([-radius * np.cos(theta), radius * np.sin(theta),
                           np.full(cols + 1, centre[2] - shape['length']) + notch])
    hem[:, :2] += centre[:2]
    result = []
    for t in np.linspace(0, 1, rows + 1):
        p = top * (1 - t) + hem * t
        # Flare is an explicit radial bow beyond linear shoulder-to-hem drape.
        bow = shape['flare'] * math.sin(math.pi * t)
        fold = folds['depth'] * np.sin(us * folds['count'] * 2 * math.pi) * t
        p[:, 0] -= (bow + fold) * np.cos(theta)
        p[:, 1] += (bow + fold) * np.sin(theta)
        result.append(p)
    return solidify(grid_mesh(result), shape['thick'])


def point(value, joints):
    return np.asarray(joints[value] if isinstance(value, str) else value, dtype=float)


def shape_meshes(shape, joints):
    kind = shape['type']
    centre = (point(shape['at'], joints) + shape.get('offset', [0, 0, 0])) if 'at' in shape else np.array(shape.get('c', [0, 0, 0]))
    rot = shape.get('rot', [0, 0, 0])
    if kind in ('capsule', 'limb', 'cylinder'):
        a, b = point(shape['a'], joints), point(shape['b'], joints)
        if kind == 'capsule':
            return capsule(a, b, shape['r1'], shape.get('r2', shape['r1']))
        if kind == 'limb':
            return limb(a, b, shape['radii'], shape['mid_at'])
        return [frustum(a, b, shape['r'], shape['r'], shape.get('segments', 12))]
    if kind in ('ellipsoid', 'shell'):
        cut = shape.get('cut', {})
        mesh = sphere(shape.get('segments', 24), shape.get('rings', 12),
                      cut.get('polar', [0, math.pi]), cut.get('azimuth', [0, 2 * math.pi]))
        mesh = transform(mesh, centre, shape['s'], rot)
        return [solidify(mesh, shape.get('thick', 0))] if kind == 'shell' else [mesh]
    if kind == 'box':
        return [transform(rounded_box(shape.get('bevel', 0), shape.get('taper', 1)), centre, np.array(shape['s']) / 2, rot)]
    if kind == 'plate':
        return [plate(shape['pts'], shape.get('thick', 0.04))]
    if kind == 'torso':
        return [transform(torso(shape), centre, rot=rot)]
    if kind == 'cloak':
        return [cloak(shape, joints)]
    if kind == 'mesh':
        return [Mesh(shape['vertices'], shape['faces'])]
    if kind == 'cone':
        half = shape['depth'] / 2
        return [transform(frustum([0, 0, -half], [0, 0, half], shape['r1'], shape['r2'], shape.get('segments', 24)), centre, rot=rot)]
    if kind == 'chain':
        a, b = point(shape['a'], joints), point(shape['b'], joints)
        result = []
        r = shape['r']
        segments, sides = MESH_DEFAULTS['torus_segments'], MESH_DEFAULTS['torus_sides']
        for i in range(shape['links']):
            rows = [[[(r + r * 0.32 * math.cos(v)) * math.cos(u), (r + r * 0.32 * math.cos(v)) * math.sin(u), r * 0.32 * math.sin(v)]
                     for v in np.arange(sides) * 2 * math.pi / sides] for u in np.arange(segments + 1) * 2 * math.pi / segments]
            mesh = grid_mesh(rows, True)
            result.append(transform(mesh, a + (b - a) * (i + 0.5) / shape['links'], rot=[math.pi / 2 * (i % 2), 0, 0]))
        return result
    raise ValueError("Unknown primitive: " + kind)


def build_meshes(spec):
    """Return ordered per-part meshes; optional remeshing happens here, once."""
    parts = {}
    for shape in spec['shapes']:
        if shape['part'] not in spec['labels']:
            raise ValueError("Unlabelled part: " + shape['part'])
        parts.setdefault(shape['part'], []).extend(shape_meshes(shape, spec['joints']))
    for part, meshes in parts.items():
        options = part_options(spec, part)
        if options.get('smooth'):
            from .remesh import voxel_union
            parts[part] = [voxel_union(meshes, options.get('voxel', 0))]
    result = {part: join(meshes) for part, meshes in parts.items()}
    if spec.get('fit_width_profile'):
        for part, mesh in result.items():
            mesh.vertices = deform_width(spec, mesh.vertices, part)
    return result


def part_options(spec, part):
    options = dict(spec.get('part_options', {}).get(part, {}))
    for shape in spec['shapes']:
        if shape['part'] == part and 'smooth' in shape:
            options.update({key: shape[key] for key in ('smooth', 'voxel') if key in shape})
    return options


def deform_width(spec, vertices, part=None):
    """Final band-width map shared by mesh vertices and joint coordinates."""
    profile = spec.get('fit_width_profile')
    values = np.asarray(vertices, dtype=float)
    if not profile:
        return values
    from .raster import camera, project
    matrix, _, basis, scale = camera(spec)
    if not np.allclose(matrix, np.eye(4)):
        raise ValueError('Fitting requires identity front object transform')
    pixels = project(spec, values, size=profile['size'])
    definition = profile['frame']
    height = definition['sole_bottom'] - definition['head_top']
    fractions = (pixels[..., :2] - [definition['ground_x'], definition['head_top']]) / height
    band_ratios = profile.get('parts', {}).get(part, profile['ratios'])
    ratios = np.interp(fractions[..., 1], (np.arange(24) + 0.5) / 24, band_ratios)
    displacement = fractions[..., 0] * height / profile['size'] * scale * (ratios - 1)
    return values + displacement[..., None] * basis[0]

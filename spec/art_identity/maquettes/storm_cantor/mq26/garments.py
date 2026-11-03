"""Tabard and full back cloak on the take-three body.

The tabard keeps mq-17 r3's construction (width, folds, rag, sigil trace) and
mq-19's five torn points, hung from the new sash in front of the new thighs.
The cloak is mq-19's generator (feedback-3 rules, mq-22 ratified profiles),
run on this body; only its seam supports change to the new hood mantle and
pauldron lames, through an open-hem attachment sampler.
"""
from contextlib import contextmanager
from functools import lru_cache
import math
import numpy as np

from ..forms import normal_sheet, cord
from ..mq19.attachment import surface_intersections

TABARD_TOPOLOGY = {'rows': 17, 'columns': 25}


def support_triangles(pieces, to_local):
    tris = []
    for piece in pieces:
        v = to_local(np.asarray(piece['vertices'], float))
        for face in piece['faces']:
            for k in range(1, len(face) - 1):
                tris.append(v[[face[0], face[k], face[k + 1]]])
    return np.asarray(tris)


def front_surface(triangles, y, z):
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    e = b - a; f = c - a; det = e[:, 1] * f[:, 2] - e[:, 2] * f[:, 1]
    valid = abs(det) > 1e-12; safe = np.where(valid, det, 1)
    q = ((y - a[:, 1]) * f[:, 2] - (z - a[:, 2]) * f[:, 1]) / safe
    r = (e[:, 1] * (z - a[:, 2]) - e[:, 2] * (y - a[:, 1])) / safe
    hit = valid & (q >= 0) & (r >= 0) & (q + r <= 1)
    return float(np.max(a[hit, 0] + q[hit] * e[hit, 0] + r[hit] * f[hit, 0])) if hit.any() else -np.inf


def tabard(fr, j, c, baseline, supports, H):
    """Return tabard piece, sigil piece and mq-19 tabard design data (pelvis-local)."""
    t = c['tabard']; cal = baseline['source_calipers']; u = baseline['mq17']['source_unit_m_per_px']
    nr, nc = TABARD_TOPOLOGY['rows'], TABARD_TOPOLOGY['columns']
    thick = baseline['feedback1']['cloth_min_thickness'] * H
    top = t['top_z'] * H
    midshin = float(fr.to_pelvis([(j['knee_near'] + j['ankle_near']) / 2])[0, 2])
    source_hem = np.asarray(cal['tabard_hem_y']); source_u = np.linspace(-1, 1, len(source_hem))
    tris = support_triangles(supports, fr.to_pelvis)
    columns = np.linspace(-1, 1, nc)
    rag = np.asarray([(max(source_hem) - np.interp(s, source_u, source_hem)) * u for s in columns])
    base_hem = midshin + rag
    centres, depths = [2, 7, 12, 17, 22], [.04, .06, .03, .05, .04]
    tents = sum(d * np.maximum(0, 1 - abs(np.arange(nc) - k) / 2.5) for k, d in zip(centres, depths)) * H
    hem = base_hem - tents
    rows = []; supported = -np.inf
    for i, tt in enumerate(np.linspace(0, 1, nr)):
        zs = (1 - tt) * top + tt * (hem if i == nr - 1 else base_hem)
        hits = [front_surface(tris, s * t['width'] * H / 2, z) for s, z in zip(columns, zs)]
        supported = max(supported, max(hits))
        row = []
        for k, s in enumerate(columns):
            base = max(hits[k], supported - thick * math.sin(math.pi * s / 2) ** 2, t['minimum_front'] * H) + thick + t['standoff'] * H
            fold = thick * (1 - math.cos(3 * math.pi * (s + 1))) * math.sin(math.pi * tt / 2)
            row.append([base + fold, s * t['width'] * H / 2, zs[k]])
        rows.append(row)
    rows = np.asarray(rows)
    piece = normal_sheet('front_tabard', 'tabard', 'pelvis', rows, thick)
    # Exact director hem on the paired mid-surface (both skins share the Z shift).
    count = nr * nc; v = np.asarray(piece['vertices'])
    for offset in (0, count):
        v[offset + (nr - 1) * nc: offset + nr * nc, 2] += hem - (v[(nr - 1) * nc:nr * nc, 2] + v[count + (nr - 1) * nc:count + nr * nc, 2]) / 2
    piece['vertices'] = np.round(fr.pelvis(v), 8).tolist()
    # Sigil trace: the source sigil, placed below the sash as on the original.
    path = []
    for x, y in cal['sigil_trace_source_px']:
        z = top - (y - t['sigil_reference_y']) / 232 * H
        s = (x - 126) * u / (t['width'] * H / 2)
        tt = np.clip((top - z) / (top - midshin), 0, 1)
        along = [np.interp(s, columns, r[:, 0]) for r in rows]
        path.append([float(np.interp(tt, np.linspace(0, 1, nr), along)) + thick, (x - 126) * u, z])
    sigils = cord('tabard_sigils', 'tabard', 'pelvis', fr.pelvis(path).tolist(), .45 * u)
    sigils['vertices'] = np.round(sigils['vertices'], 8).tolist()
    design = {'points': 5, 'point_columns': centres, 'point_depths_over_H': depths, 'tent_half_width_columns': 2.5,
              'base_hem_z_over_H': (base_hem / H).tolist(), 'hem_z_over_H': (hem / H).tolist(),
              'top_z_over_H': t['top_z'], 'midshin_local_over_H': midshin / H}
    return piece, sigils, design, [nr, nc]


# ---------------------------------------------------------- cloak seam ----
def support_geometry(spec, hems, points=None):
    """Mantle hem ring (closed) and pauldron lame rims (open arcs), in H units."""
    H = spec['mq19']['gauge_H_m']; out = []
    for name, hem, closed in hems:
        v = np.asarray(spec_piece(spec, name)['vertices'] if points is None else points[name + '_render'], float) / H
        faces = spec_piece(spec, name)['faces']
        tris = np.asarray([[v[f[0]], v[f[i]], v[f[i + 1]]] for f in faces for i in range(1, len(f) - 1)])
        out.append((name, np.asarray(hem(v), float), closed, tris))
    return out


def spec_piece(spec, name):
    return next(p for p in spec['pieces'] if p['id'] == name)


def open_hem_intersections(hem, closed, origin, radial, tangent):
    following = np.roll(hem, -1, axis=0) if closed else hem[1:]
    start = hem if closed else hem[:-1]
    a = (start - origin) @ tangent; b = (following - origin) @ tangent
    valid = (a * b <= 0) & (abs(a - b) > 1e-12)
    t = a[valid] / (a[valid] - b[valid])
    points = start[valid] + t[:, None] * (following[valid] - start[valid])
    return [p for p in points if (p - origin) @ radial > 0]


def sampler_factory(hem_sources):
    """mq-19's .01 H lap rule on the take-three supports (same signature)."""
    def sampler(spec, points=None):
        H = spec['mq19']['gauge_H_m']; geometry = support_geometry(spec, hem_sources, points)
        near, far = (np.asarray(spec['joints']['shoulder_' + s]) / H for s in ('near', 'far'))
        origin = (near + far) / 2; origin[2] = 0
        transverse = near - far; transverse[2] = 0; transverse /= np.linalg.norm(transverse)
        forward = np.array([transverse[1], -transverse[0], 0.])
        @lru_cache(maxsize=None)
        def sample(u):
            theta = math.radians(200) * (u - .5)
            radial = -forward * math.cos(theta) + transverse * math.sin(theta)
            tangent = forward * math.sin(theta) + transverse * math.cos(theta)
            candidates = []
            for name, hem, closed, tris in geometry:
                for edge in open_hem_intersections(hem, closed, origin, radial, tangent):
                    hits = surface_intersections(tris, origin, radial, tangent, edge[2] + .01)
                    if hits:
                        on = max(hits, key=lambda p: (p - origin) @ radial)
                        candidates.append(((edge - origin) @ radial, name, edge, on))
            if not candidates:
                raise ValueError('No take-three garment supports the .01 H lap at u=' + str(u))
            _, name, edge, on = max(candidates, key=lambda q: q[0])
            return {'support': name, 'hem': edge, 'on_surface': on, 'radial': radial}
        return sample
    return sampler


@contextmanager
def take_three_supports(hem_sources):
    from ..mq19 import attachment
    original = attachment.sampler
    attachment.sampler = sampler_factory(hem_sources)
    try:
        yield attachment.sampler
    finally:
        attachment.sampler = original


def hem_sources(spec):
    """Callables reading each support's live hem from its own vertices (H units)."""
    layout = spec['mq26']['support_hems']
    def mantle(v):
        nr, nc = layout['hood_mantle']['grid']; count = nr * nc
        mid = (v[:count] + v[count:]) / 2
        return mid.reshape(nr, nc, 3)[-1]
    def rim(name):
        lo, hi = layout[name]['hem_vertex_range']
        return lambda v: v[lo:hi]
    return [('hood_mantle', mantle, True), ('pauldron_far', rim('pauldron_far'), False),
            ('pauldron_near', rim('pauldron_near'), False)]


def cloak(spec):
    from ..mq19.cloak_generator import generate
    with take_three_supports(hem_sources(spec)):
        return generate(spec)

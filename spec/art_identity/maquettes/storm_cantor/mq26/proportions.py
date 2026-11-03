"""Sprite-style proportions on the front capture camera (orthographic, NumPy).

The original's values were measured on its 3/4 sprite, so this unit measures
its own front capture the same way: screen heights above the sole line and
screen widths, both divided by the figure's own sole-to-taller-tine height.
3D body-space values are reported beside them.
"""
import numpy as np
from .frames import screen_basis

PROPORTION_DEFAULTS = {'central_band': [.25, .75], 'slices': 11}
LIMBS = {'thigh': ('hip', 'knee'), 'shin': ('knee', 'ankle'), 'upper_arm': ('shoulder', 'elbow'), 'forearm': ('elbow', 'hand')}
PIECES = {'thigh': 'thigh_plate_', 'shin': 'shin_plate_', 'upper_arm': 'upper_plate_', 'forearm': 'fore_plate_'}


def screen(spec, points):
    basis = screen_basis(spec, 'front')
    p = np.atleast_2d(np.asarray(points, float))
    return np.column_stack([p @ basis[0], p @ basis[1]])


def registered_height(spec):
    """The original's H on the shared proof scale (mq-17: 232 of 256 source px)."""
    reference = spec.get('mq19', {}).get('reference_ortho_scale', spec['ortho_scale'])
    return float(reference * spec['mq17']['source_drawn_height_px'] / 256)


def figure_height(spec, points):
    """(sole line, taller-tine top, height) in screen metres; staff excluded."""
    body = np.concatenate([np.asarray(v, float) for name, v in points.items()
                           if not name.startswith('staff') and not name.startswith('pennant')])
    sole = float(screen(spec, body)[:, 1].min())
    tops = {side: float(screen(spec, points['helm_tine_' + side + '_render'])[:, 1].max()) for side in ('near', 'far')}
    taller = max(tops, key=tops.get)
    return sole, tops[taller], tops[taller] - sole, taller


def limb_width(spec, vertices, faces, a, b):
    """Silhouette width across the projected bone axis (triangle/line cuts)."""
    q = screen(spec, vertices); a2, b2 = screen(spec, [a, b])
    axis = b2 - a2; axis /= np.linalg.norm(axis); normal = np.array([-axis[1], axis[0]])
    tris = np.asarray([[q[f[0]], q[f[k]], q[f[k + 1]]] for f in faces for k in range(1, len(f) - 1)])
    lo, hi = PROPORTION_DEFAULTS['central_band']; widths = []
    for t in np.linspace(lo, hi, PROPORTION_DEFAULTS['slices']):
        m = a2 + (b2 - a2) * t
        along = np.einsum('tkj,j->tk', tris - m, axis); across = np.einsum('tkj,j->tk', tris - m, normal)
        cuts = []
        for i, j in ((0, 1), (1, 2), (2, 0)):
            u, v = along[:, i], along[:, j]
            hit = (u * v <= 0) & (abs(u - v) > 1e-15)
            w = u[hit] / (u[hit] - v[hit])
            cuts.append(across[hit, i] + w * (across[hit, j] - across[hit, i]))
        cuts = np.concatenate(cuts)
        if len(cuts): widths.append(float(cuts.max() - cuts.min()))
    return max(widths) if widths else 0.


def measure(spec, points, joints, H, faces=None):
    """Return {name: {'screen_over_H', 'body_over_H'}} for the brief's proportions."""
    j = {k: np.asarray(v, float) for k, v in joints.items()}
    faces = faces or {p['id'] + '_render': p['faces'] for p in spec['pieces']}
    sole, top, own, taller = figure_height(spec, points)
    height = registered_height(spec)
    out = {'definition': 'Front capture camera at the shared proof scale (the contact sheet shows the original at 4x beside '
                         'the clay at 1:1 on one sole line). Heights: above the lowest body pixel row (sole line); widths: '
                         'screen extent; both over the registered H (the original\'s 232 px = 928 capture px). '
                         'Limb widths: widest perpendicular screen extent over the central half of the segment. '
                         'body_over_H: the 3D body-space value over the inherited H gauge.',
           'registered_height_m': height, 'own_height_over_H': own / height, 'taller_tine': taller}
    hips = screen(spec, [j['hip_near'], j['hip_far']])[:, 1].mean()
    out['hip_joint'] = {'screen_over_H': float((hips - sole) / height),
                        'body_over_H': float((j['hip_near'][2] + j['hip_far'][2]) / 2 / H)}
    for name, (a, b) in LIMBS.items():
        rows = {}
        for side in ('near', 'far'):
            v = np.asarray(points[PIECES[name] + side + '_render'])
            rows[side] = limb_width(spec, v, faces[PIECES[name] + side + '_render'], j[a + '_' + side], j[b + '_' + side]) / height
        out[name + '_width'] = {'screen_over_H': float(np.mean(list(rows.values()))), 'near': rows['near'], 'far': rows['far']}
    def across(names):
        v = np.concatenate([np.asarray(points[n + '_render']) for n in names])
        x = screen(spec, v)[:, 0]
        return float((x.max() - x.min()) / height)
    out['waist_sash'] = {'screen_over_H': across(['waist_sash'])}
    out['chest'] = {'screen_over_H': across([n[:-7] for n in points if n.startswith('rib_')])}
    near = screen(spec, points['pauldron_near_render'])[:, 0]; far = screen(spec, points['pauldron_far_render'])[:, 0]
    out['pauldron_span'] = {'screen_over_H': float((max(near.max(), far.max()) - min(near.min(), far.min())) / height)}
    return out

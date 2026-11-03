"""Staff: mq-19's grounded shaft, pennant and sigils; a new lightning fork.

The fork is three faceted lightning blades, each with two zig-zag bends and a
sharp apex, rising from a faceted socket. There is no ring, bead or ball.
"""
from copy import deepcopy
import math
import numpy as np

from spec.art_identity.maquettes.blender.faceted_forms import blade, polygon_loft
from ..forms import shell, union
from ..mq19.pose import staff_frame

FORK_TOPOLOGY = {'socket_sides': 8}


def lightning_path(length, zigzag, splay_degrees, lateral0):
    """Up, a sharp sideways zag, then up to the point (staff-local y, z)."""
    a = math.radians(splay_degrees)
    def advance(p, up, side):
        return p + np.array([0., side * math.cos(a) + up * math.sin(a), up * math.cos(a) - side * math.sin(a)])
    p0 = np.array([0., lateral0, 0.])
    p1 = advance(p0, .42 * length, zigzag)
    p2 = advance(p1, .12 * length, -2 * zigzag)
    p3 = advance(p2, .46 * length, zigzag)
    return [p0, p1, p2, p3]


def fork_pieces(base, r, c, H):
    f = c['fork']; parts = []; info = {}
    centre = f['centre_length'] * H
    layout = {'fork_centre': (centre, 0., 0.), 'fork_outer': (centre * f['side_ratio'], -f['splay_degrees'], -f['root_offset']),
              'fork_inner': (centre * f['side_ratio'], f['splay_degrees'], f['root_offset'])}
    top = base + r[:, 2] * f['socket_height'] * H
    for name, (length, splay, offset) in layout.items():
        # Similar shapes: the zig-zag scales with each tine's length.
        local = lightning_path(length, f['zigzag'] * H * length / centre, splay, offset * H)
        lengths = np.r_[0, np.cumsum(np.linalg.norm(np.diff(local, axis=0), axis=1))]
        half = f['base_width'] / 2 * H * (1 - (lengths / lengths[-1]) ** f['taper_power'])
        world = top + np.einsum('nj,kj->nk', np.asarray(local), r)
        v, fc, _ = blade(world, half, half * f['depth_ratio'], r[:, 0])
        parts.append((name, v, fc))
        info[name] = {'length_m': float(lengths[-1]), 'path': world.tolist(), 'base_width_m': f['base_width'] * H}
    # Faceted socket from the shaft into the fork root.
    sections = []
    for t, scale in ((-f['socket_height'] * .5, 1.02), (0., 1.12), (f['socket_height'], 1.35)):
        ring = []
        for k in range(FORK_TOPOLOGY['socket_sides']):
            a = math.tau * k / FORK_TOPOLOGY['socket_sides']
            ring.append((base + r[:, 2] * t * H + (r[:, 0] * math.cos(a) + r[:, 1] * math.sin(a)) * c['shaft_radius'] * scale * H).tolist())
        sections.append(ring)
    v, fc, _ = polygon_loft(sections)
    parts.append(('fork_socket', v, fc))
    return parts, info


def staff(baseline, j, design_pose, c, H):
    """Transform the mq-17 staff exactly as mq-19 does; replace only the fork."""
    r = staff_frame(design_pose); grip = np.asarray(j['hand_far'])
    source = next(p for p in baseline['pieces'] if p['id'] == 'staff')
    components = baseline['mq17']['staff_components']
    a, b = components['shaft']
    shaft = np.asarray(source['vertices'][a:b]).reshape(-1, 12, 3).mean(1)
    delta = r[:, 2]; butt = grip - delta * (grip[2] / delta[2])
    base = butt + delta * ((shaft[-1, 2] - shaft[0, 2]) / delta[2])
    old_base = np.asarray(baseline['mq17']['staff']['fork_base'])
    points = np.asarray(source['vertices'])
    moved = base + np.einsum('nj,kj->nk', points - old_base, r)
    count = 12
    moved[a:a + count] = butt + np.einsum('nj,kj->nk', points[a:a + count] - shaft[0], r)
    moved[a:a + count] -= np.outer(moved[a:a + count, 2] / delta[2], delta)
    moved[a + count:b] = base + np.einsum('nj,kj->nk', points[a + count:b] - shaft[-1], r)
    faces_by = {}
    # Recover each inherited component's faces from the union's vertex ranges.
    for name, (lo, hi) in components.items():
        faces_by[name] = [[i - lo for i in face] for face in source['faces'] if lo <= face[0] < hi]
    keep = {name: (moved[lo:hi].tolist(), faces_by[name]) for name, (lo, hi) in components.items()
            if name in ('shaft', 'pennant')}
    fork, info = fork_pieces(base, r, c, H)
    ordered = [('shaft',) + keep['shaft']] + fork + [('pennant',) + keep['pennant']]
    parts = []; layout = {}; start = 0
    for name, v, fc in ordered:
        parts.append({'vertices': np.asarray(v).tolist(), 'faces': fc, 'flat_faces': [] if name in ('shaft', 'pennant') else list(range(len(fc)))})
        layout[name] = [start, start + len(v)]; start += len(v)
    piece = union('staff', 'staff', 'hand_far', parts)
    sigils = deepcopy(next(p for p in baseline['pieces'] if p['id'] == 'pennant_sigils'))
    sigils['vertices'] = np.round(base + np.einsum('nj,kj->nk', np.asarray(sigils['vertices']) - old_base, r), 8).tolist()
    return [piece, sigils], {'components': layout, 'butt': butt.tolist(), 'fork_base': base.tolist(),
                             'axis': delta.tolist(), 'frame': r.tolist(), 'fork': info}

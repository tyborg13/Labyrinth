"""Hand gates on the 1088 px front capture (parts map + clay), and a portable twin.

Near hand: between every adjacent pair of fingers, and between the thumb and
its nearest finger, the line joining their phalanx centres crosses at least
one pixel that is not hand_near (background or another part) or a clay
luminance dip; each digit's centre pixel shows hand_near. Far hand: along
the projected shaft through the grip the shaft centreline is covered by
hand_far pixels, with staff pixels visible above and below the grip.
"""
import numpy as np
from spec.art_identity.maquettes.raster import project, triangle_samples

HAND_CAPTURE_DEFAULTS = {'end_margin_px': 2, 'luma_dip': 18., 'grip_cover_fraction': .5, 'staff_search_px': 60,
                         'window_margin_px': 30}


def centre(points):
    return np.asarray(points, float).reshape(-1, 3).mean(0)


def digit_centres(spec, pts, side):
    """Projected centres of the middle and distal phalanges of each digit."""
    out = {}
    for name in [('finger_%d_' % i) for i in range(4)] + ['thumb_']:
        count = 2 if name == 'thumb_' else 3
        rows = []
        for k in range(count - 2 if name == 'thumb_' else 1, count):
            v = np.asarray(pts[name + side + '_' + str(k) + '_render'])
            rows.append(project(spec, v[:-1].mean(0) if len(v) % 6 == 1 else v.mean(0), 'front', spec['mq19']['capture_px'])[:2])
        out[name.rstrip('_')] = rows
    return out


def separated(owners, luma, a, b, label):
    a, b = np.asarray(a), np.asarray(b); n = int(np.ceil(np.linalg.norm(b - a))) + 1
    m = HAND_CAPTURE_DEFAULTS['end_margin_px']
    samples = [a + (b - a) * t for t in np.linspace(0, 1, n)][m:-m] if n > 2 * m + 1 else []
    ends = [owners[int(p[1]), int(p[0])] for p in (a, b)]
    if not samples: return False, 'digits overlap on screen'
    values = []
    for p in samples:
        x, y = int(p[0]), int(p[1])
        if owners[y, x] != label: return True, 'background or other part'
        if luma is not None: values.append(luma[y, x])
    if luma is not None and values:
        edge = min(luma[int(a[1]), int(a[0])], luma[int(b[1]), int(b[0])])
        if edge - min(values) >= HAND_CAPTURE_DEFAULTS['luma_dip']:
            return True, 'clay contrast'
    return False, 'continuous ' + str(ends)


def near_gate(spec, pts, owners, luma, labels):
    label = labels.index('hand_near'); c = digit_centres(spec, pts, 'near'); rows = {}; visible = {}
    for name, centres in c.items():
        visible[name] = any(owners[int(p[1]), int(p[0])] == label for p in centres)
    pairs = [('finger_0', 'finger_1'), ('finger_1', 'finger_2'), ('finger_2', 'finger_3')]
    thumb = np.asarray(c['thumb'][-1])
    nearest = min(('finger_%d' % i for i in range(4)), key=lambda n: np.linalg.norm(np.asarray(c[n][-1]) - thumb))
    pairs.append(('thumb', nearest))
    for a, b in pairs:
        result = [separated(owners, luma, p, q, label) for p, q in zip(c[a][-2:], c[b][-2:])]
        rows[a + '|' + b] = {'separated': any(r[0] for r in result), 'evidence': [r[1] for r in result]}
    passed = all(visible.values()) and all(r['separated'] for r in rows.values())
    return {'passed': bool(passed), 'digits_visible': visible, 'separations': rows,
            'digit_centres_px': {k: [list(map(float, p)) for p in v] for k, v in c.items()}}


def far_gate(spec, pts, owners, labels):
    hand = labels.index('hand_far'); staff = labels.index('staff'); size = spec['mq19']['capture_px']
    axis_points = np.asarray(spec['mq26']['far_hand']['fingers']['0'] + spec['mq26']['far_hand']['fingers']['3']).reshape(-1, 3)
    s = np.asarray(spec['mq26']['far_hand']['shaft_axis']); grip = np.asarray(spec['joints']['hand_far'])
    heights = [(p - grip) @ s for p in axis_points]
    lo, hi = min(heights), max(heights); covered = total = 0
    for t in np.linspace(lo, hi, 24):
        x, y = project(spec, grip + s * t, 'front', size)[:2]; total += 1
        covered += int(owners[int(y), int(x)] == hand)
    # Staff pixels must show on the shaft line beyond both ends of the grip.
    step = spec['ortho_scale'] / size; reach = HAND_CAPTURE_DEFAULTS['staff_search_px']
    def shows(sign, start):
        for k in range(1, reach):
            x, y = project(spec, grip + s * (start + sign * k * step), 'front', size)[:2]
            if owners[int(y), int(x)] == staff: return True
        return False
    staff_ends = [shows(1, hi), shows(-1, lo)]
    fraction = covered / total
    return {'passed': bool(fraction >= HAND_CAPTURE_DEFAULTS['grip_cover_fraction'] and all(staff_ends)),
            'shaft_centreline_covered_by_hand': fraction, 'staff_visible_above_and_below': staff_ends}


def window_owners(spec, pts, faces, box):
    """Portable depth-tested owner raster inside a pixel box (mutation twin)."""
    size = spec['mq19']['capture_px']; labels = list(spec['labels'])
    x0, y0, x1, y1 = box; owners = np.full((size, size), -1, np.int16); depth = np.full((size, size), -np.inf)
    for p in spec['pieces']:
        name = p['id'] + '_render'; v = project(spec, np.asarray(pts[name]), 'front', size)
        if v[:, 0].max() < x0 or v[:, 0].min() > x1 or v[:, 1].max() < y0 or v[:, 1].min() > y1: continue
        part = labels.index(p['part'])
        for face in faces[name]:
            for k in range(1, len(face) - 1):
                tri = v[[face[0], face[k], face[k + 1]]]
                if tri[:, 0].max() < x0 or tri[:, 0].min() > x1 or tri[:, 1].max() < y0 or tri[:, 1].min() > y1: continue
                sample = triangle_samples(tri, size, size)
                if sample is None: continue
                yy, xx, bary = sample; z = np.sum(bary * tri[:, 2], axis=1)
                front = z > depth[yy, xx]
                depth[yy[front], xx[front]] = z[front]; owners[yy[front], xx[front]] = part
    return owners


def hand_box(spec, pts, side):
    size = spec['mq19']['capture_px']; m = HAND_CAPTURE_DEFAULTS['window_margin_px']
    v = np.concatenate([np.asarray(pts[n]) for n in pts if n.endswith('_render') and ('_' + side + '_') in n and
                        (n.startswith('finger_') or n.startswith('thumb_') or n.startswith('palm_'))])
    q = project(spec, v, 'front', size)
    return [int(q[:, 0].min()) - m, int(q[:, 1].min()) - m, int(q[:, 0].max()) + m, int(q[:, 1].max()) + m]


def portable(spec, pts, faces):
    labels = list(spec['labels'])
    near = window_owners(spec, pts, faces, hand_box(spec, pts, 'near'))
    far = window_owners(spec, pts, faces, hand_box(spec, pts, 'far'))
    return {'near': near_gate(spec, pts, near, None, labels), 'far': far_gate(spec, pts, far, labels)}


def window_pieces(spec, pts, faces, view, names):
    """Depth-tested piece-index raster of the named pieces (all occluders) for one view."""
    size = spec['mq19']['capture_px']; ids = np.full((size, size), -1, np.int16); depth = np.full((size, size), -np.inf)
    for index, name in enumerate(names):
        v = project(spec, np.asarray(pts[name]), view, size)
        for face in faces[name]:
            for k in range(1, len(face) - 1):
                tri = v[[face[0], face[k], face[k + 1]]]
                sample = triangle_samples(tri, size, size)
                if sample is None: continue
                yy, xx, bary = sample; z = np.sum(bary * tri[:, 2], axis=1)
                front = z > depth[yy, xx]
                depth[yy[front], xx[front]] = z[front]; ids[yy[front], xx[front]] = index
    return ids, list(names)

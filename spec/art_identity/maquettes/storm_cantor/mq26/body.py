"""Take-three head, torso and pelvis forms (local frames, H units, then posed).

Faceted helm with a shield face plate, recessed visor and two tapered tines;
a navy hood cowl and shoulder mantle; an open cage of flat curved rib bands
around a deep chest with a sternum bar, back plate and spine; the inherited
bell lathe; a soft sash, knot, medallion and a faceted pelvis plate.
"""
import math
import numpy as np

from spec.art_identity.maquettes.blender.faceted_forms import polygon_loft, thick_sheet, blade, unit
from ..forms import shell, cord, oval
from spec.art_identity.maquettes.blender.closed_loft import loft

BODY_TOPOLOGY = {'rib_stations': 41, 'rib_rows': 5, 'rib_edge_fraction': .35, 'cage_samples': 72, 'cowl_columns': 33, 'cowl_rows': 15,
                 'mantle_columns': 64, 'mantle_rows': 11, 'sash_samples': 48, 'back_rows': 17}


def interp(u, table):
    xs, ys = zip(*table)
    return float(np.interp(u, xs, ys))


# ---------------------------------------------------------------- head ----
def helm_columns(u, c):
    """Nine helm columns (head-local, H units) at shield parameter u in [0, 1]."""
    w = interp(u, c['face_half_width'])
    s = w / c['face_half_width_max']
    xf = interp(u, c['ridge_x'])
    groove = interp(u, c['visor_groove'])
    e = c['ridge_half'] + groove * (c['visor_half_width'] - c['ridge_half'])
    depth = groove * c['visor_depth']
    zf = c['chin_z'] + u * c['face_height']
    zb = c['chin_z'] + c['back_bottom_lift'] + u * (c['face_height'] - c['back_bottom_lift'] - c['back_top_drop'])
    xb = interp(u, c['back_x'])
    wb = interp(u, c['back_half_width'])
    front = [(xf - depth, e, zf), (xf - c['crease_back'] * s, c['crease_fraction'] * w, zf),
             (xf - c['edge_back'] * s, w, zf - c['edge_drop'] * s)]
    back = [(xb * .72, wb, zb), (xb, 0., zb), (xb * .72, -wb, zb)]
    mirror = [(x, -y, z) for x, y, z in reversed(front)]
    return front + back + mirror


def helm(fr, c, H):
    us = c['stations']
    sections = [[(np.asarray(p) * H).tolist() for p in helm_columns(u, c)] for u in us]
    v, f, flat = polygon_loft(sections)
    v = fr.head(v)
    piece = shell('great_helm', 'head', 'head', v, f, list(range(len(f))))
    return piece


def visor(fr, c, H):
    u0 = (c['visor_centre_above_chin'] - c['visor_height'] / 2) / c['face_height']
    u1 = (c['visor_centre_above_chin'] + c['visor_height'] / 2) / c['face_height']
    rows = []
    for u in np.linspace(u0, u1, 9):
        xf = interp(u, c['ridge_x']) - c['visor_depth'] + c['visor_inlay_lift']
        z = c['chin_z'] + u * c['face_height']
        rows.append([[xf, y, z] for y in np.linspace(-c['visor_width'] / 2, c['visor_width'] / 2, 3)])
    rows = np.asarray(rows) * H
    normals = np.zeros_like(rows); normals[..., 0] = 1
    v, f = thick_sheet(rows, c['visor_inlay_thickness'] * H, normals)
    piece = shell('visor_slit', 'head', 'head', fr.head(v), f, list(range(len(f))))
    piece['clay_colour'] = [.015, .015, .015]
    return piece


def tines(fr, c, H):
    pieces = []
    for side, sign in (('near', 1), ('far', -1)):
        t = c['tines'][side]
        root = np.array([t['root_x'], sign * t['root_y'], c['chin_z'] + t['root_above_chin']])
        path = [root + np.array([x, sign * y, z]) for x, y, z in t['path']]
        widths = [w / 2 for w in t['widths']]
        depths = [w * c['tine_depth_ratio'] for w in widths]
        # Blade is authored in head-local space; pose with the head frame.
        local = np.asarray(path) * H
        # Broad blade face toward the board camera (head-local), as the sprite reads.
        v, f, _ = blade(local, np.asarray(widths) * H, np.asarray(depths) * H, c['tine_face'])
        pieces.append(shell('helm_tine_' + side, 'head', 'head', fr.head(v), f, list(range(len(f)))))
    return pieces


def cowl(fr, c, H):
    """Navy hood over the helm's back and sides, framing the face plate.

    Rows follow the helm's own faceted back columns (edge, cheek, back), offset
    outward; above the crown they close into a soft peak, below the helm they
    fall to the neck. Shallow vertical folds keep it cloth, not a dome.
    """
    k = c['cowl']; rows = []
    def ring(u):
        # Level rings at the helm's back height: the face plate's pointed top
        # stands clear in front, and the hood's own soft point is its highest part.
        source = helm_columns(u, c)[2:7]; back = source[2][2]
        blend = np.clip((u - k['level_from_u']) / (1 - k['level_from_u']), 0, 1); blend = blend * blend * (3 - 2 * blend)
        cols = [(x, y, z + (back - z) * blend) for x, y, z in source]
        pts = []
        for a, b in zip(cols, cols[1:]):
            for t in np.linspace(0, 1, k['subdivide'], endpoint=False):
                pts.append(np.asarray(a) + (np.asarray(b) - np.asarray(a)) * t)
        pts.append(np.asarray(cols[-1]))
        return np.asarray(pts)
    us = np.linspace(0, 1, BODY_TOPOLOGY['cowl_rows'])
    sections = [ring(u) for u in us]
    centre_x = np.mean([p[:, 0].mean() for p in sections])
    out = []
    for u, pts in zip(us, sections):
        centre = np.array([centre_x, 0., pts[:, 2].mean()])
        radial = pts - centre; radial[:, 2] = 0
        radial /= np.maximum(np.linalg.norm(radial, axis=1), 1e-9)[:, None]
        n = len(pts); folds = np.sin(np.linspace(0, math.pi * k['back_folds'], n)) ** 2
        hug = 1 - (1 - k['crown_offset_fraction']) * u * u      # tight over the helm's pointed top
        offset = (k['gap'] + k['thickness'] / 2) * hug + k['fold_depth'] * folds * math.sin(math.pi * u)
        row = pts + radial * offset[:, None]
        out.append(row)
    # Peak above the crown and a fall to the neck below the helm.
    # Soft point 0.02 H above the helm's back top, on the helm's own back line.
    back_top = np.asarray(helm_columns(1., c)[4])
    peak = back_top + [-k['peak_inset'], 0, k['peak_above_helm_back']]
    top = out[-1].copy()
    out.append(top + (peak - top) * .55)
    out.append(peak + (top - top.mean(0)) * .1)            # a small ring centred on the soft point
    bottom = out[0].copy(); centre = bottom.mean(0)
    neck = centre + (bottom - centre) * k['neck_scale']; neck[:, 2] = bottom[:, 2] - k['neck_drop']
    out.insert(0, neck)
    rows = np.asarray(out) * H
    v, f = thick_sheet(rows, k['thickness'] * H)
    return shell('hood_cowl', 'head', 'head', fr.head(v), f), list(rows.shape[:2])


# ---------------------------------------------------------------- torso ---
def cage_profile(c):
    def half_width(z):
        return interp(z, c['half_width'])
    return half_width


def bell_radius(bell_rows, dz):
    """Outer bell radius (m) at dz (m) below the hook, from the inherited lathe."""
    outer = bell_rows[:5]
    zs = [r[0] for r in outer]; rs = [r[1] for r in outer]
    if dz > 0 or dz < zs[-1]:
        return 0.
    return float(np.interp(-dz, [-z for z in zs], rs))


def bell_lathe(mouth, height_scale=1.):
    """The mq-17 r3 bell profile (outer flare, lip, inner return); metres; mouth is the radius.

    height_scale stretches the profile along its axis only (radii and mouth kept)."""
    return [(dz * height_scale, r) for dz, r in
            [(0, .008), (-.025, mouth * .23), (-.09, mouth * .45), (-.17, mouth), (-.18, mouth),
             (-.18, mouth - .012), (-.09, mouth * .45 - .012), (-.025, mouth * .14)]]


def rib_band(identifier, centre_line, outward, width, thickness, H):
    """Flat curved band: lens section, full thickness at its centre, thin edges."""
    n = len(centre_line); levels = np.linspace(-1, 1, BODY_TOPOLOGY['rib_rows'])
    up = np.array([0, 0, 1.])
    skins = []
    for sign in (1, -1):
        for v in levels:
            factor = BODY_TOPOLOGY['rib_edge_fraction'] + (1 - BODY_TOPOLOGY['rib_edge_fraction']) * (1 - v * v)
            skins.append(centre_line + up * v * width / 2 * H + outward * sign * thickness / 2 * H * factor)
    rows = len(levels); count = rows * n
    vertices = np.asarray(skins).reshape(-1, 3)
    faces = []
    for r in range(rows - 1):
        for c in range(n - 1):
            q = [r * n + c, r * n + c + 1, (r + 1) * n + c + 1, (r + 1) * n + c]
            faces.append(q); faces.append([i + count for i in reversed(q)])
    rim = (list(range(n)) + [r * n + n - 1 for r in range(1, rows)] +
           list(range(count - 2, count - n - 1, -1)) + [r * n for r in range(rows - 2, 0, -1)])
    for a, b in zip(rim, rim[1:] + rim[:1]):
        faces.append([a, a + count, b + count, b])
    return vertices.tolist(), faces


def cage(fr, c, H, hook_local, bell_rows):
    """Ribs (flat bands), sternum bar, back plate and spine; torso-local."""
    hw = cage_profile(c); ratio = c['depth_to_width']
    # The deeper cage grows forward from the spine, so the back stays put.
    xc = c['centre_x']
    pieces, ribs = [], []
    band, thick = c['band_width'], c['band_thickness']
    for k, z in enumerate(c['rib_z']):
        for side, sign in (('near', 1), ('far', -1)):
            thetas = np.linspace(0, math.radians(c['rib_end_degrees']), BODY_TOPOLOGY['rib_stations'])
            line, out = [], []
            for theta in thetas:
                droop = c['droop'] * math.sin(theta / 2) ** 2 / math.sin(math.radians(c['rib_end_degrees']) / 2) ** 2
                zz = z - droop
                a = hw(zz) - thick / 2; b = a * ratio
                x, y = xc + b * math.cos(theta), sign * a * math.sin(theta)
                # Stop the band where it would pass through the hanging bell.
                dz = (zz - hook_local[2]) * H
                rb = bell_radius(bell_rows, dz) / H
                # Safety only: a band never passes through the bell (radial clearance).
                if rb > 0 and math.hypot(x - hook_local[0], y) < rb + thick / 2 + c['bell_inner_clearance'] / 2:
                    continue
                normal = np.array([math.cos(theta) / b, sign * math.sin(theta) / a, 0.])
                line.append([x, y, zz]); out.append(normal / np.linalg.norm(normal))
            if len(line) < 3:
                raise ValueError('Rib band fully hidden by the bell: rib ' + str(k))
            line = np.asarray(line) * H
            v, f = rib_band('rib', line, np.asarray(out), band, thick, H)
            name = 'rib_' + side + '_' + str(k)
            pieces.append(shell(name, 'torso', 'torso', fr.torso(v), f, list(range(len(f)))))
            ribs.append(name)
    # Sternum bar: down the cage front, in front of the bell hanging inside.
    zs = np.linspace(c['rib_z'][-1] - band / 2, c['rib_z'][0] + band / 2, 21); rows = []
    for z in zs:
        a = hw(z) - thick / 2; x = xc + a * ratio
        rows.append([[x, -c['sternum_width'] / 2, z], [x, c['sternum_width'] / 2, z]])
    rows = np.asarray(rows) * H
    normals = np.zeros_like(rows); normals[..., 0] = 1
    v, f = thick_sheet(rows, c['sternum_depth'] * H, normals)
    pieces.append(shell('sternum_bar', 'torso', 'torso', fr.torso(v), f, list(range(len(f)))))
    # Hook from the sternum top back into the cage to the bell's hanging point.
    top = rows[-1].mean(0) / H
    hook_path = np.asarray([top - [c['sternum_depth'] / 2, 0, 0], [hook_local[0], 0, top[2]], hook_local]) * H
    v, f, _ = blade(hook_path, [.003 * H, .0025 * H, .002 * H], [.003 * H, .0025 * H, .002 * H], [0, 1., 0], sides=6)
    pieces.append(shell('sternum_hook', 'torso', 'torso', fr.torso(v), f, list(range(len(f)))))
    # Closed back plate behind the ribs' rear ends, with a spine ridge.
    rows = []
    back_angles = np.radians(np.linspace(c['back_plate_degrees'][0], c['back_plate_degrees'][1], BODY_TOPOLOGY['cage_samples']))
    for z in np.linspace(c['rib_z'][-1] - c['droop'] - band, c['rib_z'][0] + band / 2, BODY_TOPOLOGY['back_rows']):
        a = hw(z) - thick * 1.2; b = a * ratio
        rows.append([[xc + b * math.cos(t), a * math.sin(t), z] for t in back_angles])
    rows = np.asarray(rows) * H
    v, f = thick_sheet(rows, c['plate_thickness'] * H)
    pieces.append(shell('closed_back_plate', 'torso', 'torso', fr.torso(v), f))
    path = []
    for z in np.linspace(c['rib_z'][-1] - c['droop'], c['rib_z'][0], 9):
        a = hw(z) - thick * 1.2; path.append([xc - a * ratio - c['plate_thickness'] / 2, 0, z])
    path = np.asarray(path) * H
    widths = np.full(len(path), c['spine_width'] / 2 * H); widths[-1] = widths[-2]
    sections = []
    for p in path:
        sections.append([(p + [0, -c['spine_width'] / 2 * H, 0]).tolist(), (p + [-c['spine_width'] * .6 * H, 0, 0]).tolist(),
                         (p + [0, c['spine_width'] / 2 * H, 0]).tolist(), (p + [c['spine_width'] * .3 * H, 0, 0]).tolist()])
    v, f, _ = polygon_loft(sections)
    pieces.append(shell('spine_ridge', 'torso', 'torso', fr.torso(v), f, list(range(len(f)))))
    # Narrow gold abdomen from the lowest rib into the sash.
    sections = []
    for z, scale, depth_ratio in c['abdomen']:
        a = hw(min(z, c['rib_z'][-1])) * scale; b = a * depth_ratio
        cx = xc * (depth_ratio - c['source_depth_to_width']) / (ratio - c['source_depth_to_width'])
        sections.append([[(cx + b * math.cos(t)) * H, a * math.sin(t) * H, z * H] for t in np.linspace(0, math.tau, 16, endpoint=False)])
    v, f, flat = polygon_loft(sections)
    pieces.append(shell('lower_abdomen', 'torso', 'torso', fr.torso(v), f, list(range(len(f)))))
    return pieces, ribs


def bell(fr, hook_local, mouth, H, height_scale=1.):
    hook = np.asarray(hook_local) * H; rows = []
    for dz, r in bell_lathe(mouth / 2 * H, height_scale):
        rows.append([hook[0], hook[1], hook[2] + dz, r, r])
    v, f, flat = loft({'sections': rows, 'samples': 32, 'periodic': True})
    piece = shell('bell', 'bell', 'torso', fr.torso(v), f, flat)
    piece['rig_pivot_joint'] = 'bell_hook'
    return piece


def mantle(fr, c, H):
    """Torso-owned hood drape from the neck onto both shoulders, two folds."""
    m = c['mantle']; rows = []
    for t in np.linspace(0, 1, BODY_TOPOLOGY['mantle_rows']):
        row = []
        for phi in np.linspace(0, math.tau, BODY_TOPOLOGY['mantle_columns'], endpoint=False):
            front = max(0., math.cos(phi)); back = max(0., -math.cos(phi))
            top = np.array(m['neck_centre']) + [m['neck_half_depth'] * math.cos(phi), m['neck_half_width'] * math.sin(phi), 0]
            # Side hem on the shoulder tops, lower at the back, a narrow V in front.
            hem_z = m['hem_z'] - (m['back_drop'] - m['side_drop']) * back ** 2 - m['side_drop'] \
                + (m['front_v_z'] - m['hem_z'] + m['side_drop']) * front ** m['front_v_power']
            depth = m['hem_front_depth'] if math.cos(phi) >= 0 else m['hem_back_depth']
            bottom = np.array([m['hem_centre_x'] + depth * math.cos(phi), m['hem_half_width'] * math.sin(phi), hem_z])
            # Front drapes straight; the back hugs the neck, then falls (concave).
            power = m['radial_power'] + (m['back_radial_power'] - m['radial_power']) * back
            ease = t ** power
            p = top + (bottom - top) * np.array([ease, ease, t])
            # Shoulder rise: the drape sits over the shoulder tops before falling.
            p[2] += m['shoulder_rise'] * math.sin(math.pi * t) * abs(math.sin(phi))
            fold = sum(math.exp(-((phi - centre + math.pi) % math.tau - math.pi) ** 2 / (2 * m['fold_sigma'] ** 2))
                       for centre in m['fold_angles'])
            # The folds hang lower: the hem breaks into two falls on the cloak.
            p_hem_dip = m['fold_hem_dip'] * fold
            radial = np.array([math.cos(phi), math.sin(phi), 0.])
            p += radial * m['fold_depth'] * fold * t
            p[2] -= p_hem_dip * t * t
            # Follow the inherited sheared shoulder line (mq-17 hood rule).
            p[0] -= m['shear'] * p[1] * ease
            row.append(p.tolist())
        rows.append(row)
    rows = np.asarray(rows) * H
    v, f = thick_sheet(rows, m['thickness'] * H, periodic=True)
    piece = shell('hood_mantle', 'torso', 'torso', fr.torso(v), f)
    return piece, {'rows': BODY_TOPOLOGY['mantle_rows'], 'columns': BODY_TOPOLOGY['mantle_columns']}


# --------------------------------------------------------------- pelvis ---
def sash(fr, c, H):
    s = c['sash']; samples = BODY_TOPOLOGY['sash_samples']; rings = []
    hw, hd = s['half_width'], s['half_width'] * s['depth_to_width']
    for a in np.linspace(0, math.tau, 12, endpoint=False):
        # Soft rounded band section: height around the ring, rolled edges.
        rings.append([0, 0, s['centre_z'] + s['height'] / 2 * math.sin(a),
                      hd + s['roll'] * math.cos(a), hw + s['roll'] * math.cos(a)])
    v, f, flat = loft({'sections': [[r[0] * H, r[1] * H, r[2] * H, r[3] * H, r[4] * H] for r in rings],
                       'samples': samples, 'periodic': True})
    return shell('waist_sash', 'sash', 'pelvis', fr.pelvis(v), f, flat)


def sash_front(fr, c, H, tabard_front=None):
    """Knot on the sash front; the medallion hangs in front of the tabard."""
    s = c['sash']; hd = s['half_width'] * s['depth_to_width'] + s['roll']
    knot = []
    for side in (-1, 1):
        path = []
        for a in np.linspace(0, math.tau, 25):
            path.append([(hd + s['knot'] * (1 + math.cos(a))) * H, (side * s['knot'] + s['knot'] * .8 * math.cos(a)) * H,
                         (s['centre_z'] + s['knot'] * math.sin(a)) * H])
        v, f, _ = blade(path[:-1] + [path[-1]], [s['knot'] / 2.2 * H] * 25, [s['knot'] / 2.2 * H] * 25, [0, 0, 1.], sides=6)
        knot.append((v, f))
    vertices, faces = [], []
    for v, f in knot:
        offset = len(vertices); vertices += v; faces += [[i + offset for i in face] for face in f]
    pieces = [shell('sash_knot', 'sash', 'pelvis', fr.pelvis(vertices), faces)]
    low = s['centre_z'] - s['height'] / 2 - s['medallion_drop']
    front = max(hd, tabard_front(low) if tabard_front else hd) + .004
    v, f, _ = blade(np.asarray([[hd + .002, 0, s['centre_z'] - s['height'] / 2], [front, 0, low + s['medallion_radius']]]) * H,
                    [.0025 * H, .0025 * H], [.0025 * H, .0025 * H], [1., 0, 0], sides=6)
    pieces.append(shell('medallion_hanger', 'sash', 'pelvis', fr.pelvis(v), f))
    medal = oval('medallion', 'sash', 'pelvis', [(front + .002) * H, 0, low * H],
                 [.004 * H, s['medallion_radius'] * H, s['medallion_radius'] * H])
    medal['vertices'] = fr.pelvis(medal['vertices']).round(8).tolist()
    pieces.append(medal)
    return pieces


def pelvis_plate(fr, c, H):
    p = c['pelvis_plate']; sections = []
    for z, hw, hd in p['stations']:
        ring = []
        for k in range(10):
            a = math.tau * k / 10
            ring.append([hd * math.cos(a) * H, hw * math.sin(a) * H, z * H])
        sections.append(ring)
    v, f, flat = polygon_loft(sections)
    return shell('pelvis_plate', 'pelvis', 'pelvis', fr.pelvis(v), f, list(range(len(f))))

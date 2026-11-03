"""Opt-in sphericity gate for visible joint regions (NumPy; host or Blender Python).

For one capture camera, pixel-centre rays inside a disk around a projected joint
return the first visible surface. Hits within a 3D radius of the joint form the
visible joint region. One least-squares sphere is fitted to those points; the
sphere fraction is the share of hits whose position (radial residual) and face
normal (angle to the fitted radial direction) both agree with it. The normal
isotropy is the ratio of the two largest spreads of the visible normals. A
ball, bead or capsule end scores near 1 on both; a curved cop, faceted plates
and creases score low on at least one. The caller chooses the camera, window and threshold and reports them.
"""
import math
import numpy as np

SPHERICITY_DEFAULTS = {'pixel_chunk': 96, 'residual_fraction': .12, 'normal_degrees': 15.,
                       'minimum_samples': 40}


def triangles(points, faces):
    out = []
    for f in faces:
        for k in range(1, len(f) - 1):
            out.append((f[0], f[k], f[k + 1]))
    out = np.asarray(out, int)
    return np.asarray(points, float)[out]


def visible_hits(world_triangles, owners, screen, centre_px, radius_px):
    """First-surface hits at pixel centres inside a disk.

    world_triangles: (T,3,3) object-space vertices. screen: callable mapping
    (N,3) object points to (N,3) [x_px, y_px, depth_toward_camera].
    Returns pixel coordinates, hit points, unit face normals (toward camera) and owners.
    """
    T = world_triangles.reshape(-1, 3)
    s = screen(T).reshape(-1, 3, 3)
    cx, cy = centre_px
    lo = s[:, :, :2].min(1); hi = s[:, :, :2].max(1)
    near = (hi[:, 0] >= cx - radius_px) & (lo[:, 0] <= cx + radius_px) & (hi[:, 1] >= cy - radius_px) & (lo[:, 1] <= cy + radius_px)
    tri_s = s[near]; tri_w = world_triangles[near]; tri_o = np.asarray(owners)[near]
    xs = np.arange(math.floor(cx - radius_px), math.ceil(cx + radius_px) + 1) + .5
    gx, gy = np.meshgrid(xs, np.arange(math.floor(cy - radius_px), math.ceil(cy + radius_px) + 1) + .5)
    inside = (gx - cx) ** 2 + (gy - cy) ** 2 <= radius_px ** 2
    px = np.column_stack([gx[inside], gy[inside]])
    if not len(tri_s) or not len(px):
        return px[:0], np.zeros((0, 3)), np.zeros((0, 3)), np.asarray([], object)
    a, b, c = tri_s[:, 0], tri_s[:, 1], tri_s[:, 2]
    den = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
    live = abs(den) > 1e-12; den = np.where(live, den, 1.)
    best_t = np.full(len(px), -1); best_w = np.zeros((len(px), 3))
    for start in range(0, len(px), SPHERICITY_DEFAULTS['pixel_chunk']):
        P = px[start:start + SPHERICITY_DEFAULTS['pixel_chunk']]
        X = P[:, :1]; Y = P[:, 1:]
        w0 = ((b[:, 1] - c[:, 1]) * (X - c[:, 0]) + (c[:, 0] - b[:, 0]) * (Y - c[:, 1])) / den
        w1 = ((c[:, 1] - a[:, 1]) * (X - c[:, 0]) + (a[:, 0] - c[:, 0]) * (Y - c[:, 1])) / den
        w2 = 1 - w0 - w1
        hit = live & (w0 >= -1e-9) & (w1 >= -1e-9) & (w2 >= -1e-9)
        depth = np.where(hit, w0 * a[:, 2] + w1 * b[:, 2] + w2 * c[:, 2], -np.inf)
        index = depth.argmax(1); ok = np.isfinite(depth[np.arange(len(P)), index])
        rows = np.arange(len(P))
        best_t[start:start + len(P)] = np.where(ok, index, -1)
        best_w[start:start + len(P)] = np.column_stack([w0[rows, index], w1[rows, index], w2[rows, index]])
    found = best_t >= 0
    px, best_t, best_w = px[found], best_t[found], best_w[found]
    tri = tri_w[best_t]
    points = np.einsum('nk,nkj->nj', best_w, tri)
    normals = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    normals /= np.maximum(np.linalg.norm(normals, axis=1), 1e-30)[:, None]
    return px, points, normals, tri_o[best_t]


def sphere_fraction(points, normals, toward=None):
    """Least-squares sphere and the share of samples consistent with it."""
    p = np.asarray(points, float); n = np.asarray(normals, float)
    if len(p) < SPHERICITY_DEFAULTS['minimum_samples']:
        return {'samples': int(len(p)), 'sphere_fraction': None, 'applicable': False}
    A = np.column_stack([2 * p, np.ones(len(p))]); y = (p * p).sum(1)
    solution = np.linalg.lstsq(A, y, rcond=None)[0]
    centre = solution[:3]; radius = math.sqrt(max(solution[3] + centre @ centre, 0.))
    radial = p - centre; distance = np.linalg.norm(radial, axis=1)
    radial /= np.maximum(distance, 1e-30)[:, None]
    if toward is not None:
        n = np.where(((n @ np.asarray(toward, float)) < 0)[:, None], -n, n)
    cosine = abs((n * radial).sum(1))
    agree = (abs(distance - radius) <= SPHERICITY_DEFAULTS['residual_fraction'] * radius) & \
            (cosine >= math.cos(math.radians(SPHERICITY_DEFAULTS['normal_degrees'])))
    # Normal isotropy: a ball's visible normals spread in two directions; a
    # cylinder or crease spreads in one, a plate facet in none.
    spread = np.linalg.eigvalsh(np.cov((n - n.mean(0)).T))[::-1]
    isotropy = float(math.sqrt(max(spread[1], 0.) / spread[0])) if spread[0] > 1e-12 else 0.
    return {'samples': int(len(p)), 'applicable': True, 'sphere_fraction': float(agree.mean()),
            'normal_isotropy': isotropy,
            'fitted_radius_m': float(radius), 'fitted_centre': centre.tolist(),
            'rms_residual_m': float(np.sqrt(np.mean((distance - radius) ** 2)))}


def joint_region(world_triangles, owners, screen, joint, radius_px, radius_m, toward):
    """Visible hits around one projected joint, restricted to a 3D joint ball."""
    centre = screen(np.asarray([joint], float))[0]
    px, points, normals, who = visible_hits(world_triangles, owners, screen, centre[:2], radius_px)
    close = np.linalg.norm(points - np.asarray(joint, float), axis=1) <= radius_m
    result = sphere_fraction(points[close], normals[close], toward)
    result.update(window_pixels=int(len(px)), joint_pixels=int(close.sum()),
                  owners=sorted({str(o) for o in who[close]}), centre_px=centre[:2].tolist())
    return result

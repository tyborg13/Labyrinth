"""Deterministic watertight ring lofts and thickened sheets, in native metres.

Only explicitly opted-in recipes use these forms. Each profile station supplies
its centre and two radii; periodic profiles form closed cuffs/collars. A sector
recess deforms the surface inward without deleting faces or adding a decal.
"""
import math
import numpy as np

CLOSED_SWEEP_DEFAULTS = {'length_epsilon':1e-10}


def loft(item):
    axes = np.asarray(item.get('axes', [[1, 0, 0], [0, 1, 0]]), float)
    if axes.shape != (2, 3) or not np.allclose(axes @ axes.T, np.eye(2)):
        raise ValueError('Loft axes must be orthonormal')
    rings = item['sections']
    count = item['samples']
    if type(count) is not int or count < 8 or len(rings) < 2:
        raise ValueError('Loft requires two sections and at least eight samples')
    if item.get('periodic') and len(rings) < 3:
        raise ValueError('Periodic loft requires three or more sections')
    recess = item.get('sector_recess')
    if recess:
        bounds = recess['z_range']
        if len(bounds) != 2 or not bounds[0] < bounds[1] or not 0 < recess['half_angle'] < math.pi or not 0 < recess['depth'] < min(min(r[3:]) for r in rings):
            raise ValueError('Invalid closed-surface recess')
    exponent = item.get('cross_section_exponent')
    if exponent is not None and not 2 <= exponent <= 8:
        raise ValueError('Rounded cross-section exponent must be in [2, 8]')
    vertices = []
    for section in rings:
        center, radii = np.asarray(section[:3], float), np.asarray(section[3:], float)
        if len(radii) != 2 or min(radii) <= 0 or not np.isfinite(section).all():
            raise ValueError('Loft radii must be positive')
        for angle in np.linspace(0, math.tau, count, endpoint=False):
            cosine, sine = math.cos(angle), math.sin(angle)
            if exponent is not None:
                cosine = math.copysign(abs(cosine) ** (2 / exponent), cosine)
                sine = math.copysign(abs(sine) ** (2 / exponent), sine)
            radial = radii[0] * cosine * axes[0] + radii[1] * sine * axes[1]
            if recess:
                z0, z1 = recess['z_range']
                delta = abs((angle - recess['angle'] + math.pi) % math.tau - math.pi)
                if z0 <= center[2] <= z1 and delta < recess['half_angle']:
                    radial *= 1 - recess['depth'] / np.linalg.norm(radial)
            vertices.append((center + radial).tolist())
    periodic = item.get('periodic', False)
    faces = []
    for row in range(len(rings) if periodic else len(rings) - 1):
        following = (row + 1) % len(rings)
        for column in range(count):
            next_column = (column + 1) % count
            faces.append([row * count + column, row * count + next_column,
                          following * count + next_column, following * count + column])
    flat_faces = []
    if not periodic:
        flat_faces = [len(faces), len(faces) + 1]
        faces += [list(reversed(range(count))), list(range((len(rings)-1)*count, len(rings)*count))]
    return vertices, faces, flat_faces


def sheet(item):
    rows = np.asarray(item['rows'], float)
    if rows.ndim != 3 or rows.shape[0] < 2 or rows.shape[1] < 2 or rows.shape[2] != 3 or not np.isfinite(rows).all():
        raise ValueError('Closed sheet requires rectangular rows of spatial points')
    direction = np.asarray(item['thickness_axis'], float)
    if not np.isclose(np.linalg.norm(direction), 1) or item['thickness'] <= 0:
        raise ValueError('Sheet needs a positive thickness on a unit axis')
    nr, nc, _ = rows.shape
    count = nr * nc
    vertices = np.concatenate((rows.reshape(-1, 3), rows.reshape(-1, 3) - direction * item['thickness']))
    faces = []
    for row in range(nr-1):
        for col in range(nc-1):
            a = row*nc+col
            face = [a, a+1, a+1+nc, a+nc]
            faces += [face, [v+count for v in reversed(face)]]
    boundary = list(range(nc)) + [r*nc+nc-1 for r in range(1,nr)] + list(range(count-2,count-nc-1,-1)) + [r*nc for r in range(nr-2,0,-1)]
    for a,b in zip(boundary,boundary[1:]+boundary[:1]):
        faces.append([a, a+count, b+count, b])
    return vertices.tolist(), faces, []


def sweep(path, radii, samples):
    """Closed circular sweep with transported frames and shared cap vertices."""
    centers=np.asarray(path,float);radii=np.asarray(radii,float)
    if centers.ndim!=2 or centers.shape[1]!=3 or len(centers)<2 or len(radii)!=len(centers) or min(radii)<=0 or type(samples) is not int or samples<8 or not np.isfinite(centers).all() or not np.isfinite(radii).all():
        raise ValueError('Invalid closed sweep')
    directions=np.diff(centers,axis=0)
    if np.any(np.linalg.norm(directions,axis=1)<CLOSED_SWEEP_DEFAULTS['length_epsilon']):
        raise ValueError('Closed sweep path contains duplicate stations')
    tangent=np.vstack((directions[0],centers[2:]-centers[:-2],directions[-1]))
    lengths=np.linalg.norm(tangent,axis=1)
    if np.any(lengths<CLOSED_SWEEP_DEFAULTS['length_epsilon']):
        raise ValueError('Closed sweep cannot reverse at a station')
    tangent/=lengths[:,None]
    axis=np.eye(3)[np.argmin(np.abs(tangent[0]))];vertices=[]
    for center,direction,radius in zip(centers,tangent,radii):
        axis=axis-direction*np.dot(axis,direction)
        if np.linalg.norm(axis)<CLOSED_SWEEP_DEFAULTS['length_epsilon']:
            axis=np.eye(3)[np.argmin(np.abs(direction))]
            axis=axis-direction*np.dot(axis,direction)
        axis/=np.linalg.norm(axis)
        other=np.cross(direction,axis)
        for angle in np.linspace(0,math.tau,samples,endpoint=False):
            vertices.append((center+radius*(math.cos(angle)*axis+math.sin(angle)*other)).tolist())
    faces=[]
    for row in range(len(centers)-1):
        for col in range(samples):
            nxt=(col+1)%samples;a=row*samples
            faces.append([a+col,a+nxt,a+nxt+samples,a+col+samples])
    caps=[len(faces),len(faces)+1]
    faces += [list(reversed(range(samples))),list(range((len(centers)-1)*samples,len(centers)*samples))]
    return vertices,faces,caps

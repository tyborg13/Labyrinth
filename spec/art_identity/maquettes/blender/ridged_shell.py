"""Closed overlapping rigid shell plates from measured rims and relief ridges.

Each plate retains its jagged silhouette and has a closed underside. All plates
share one rig part; no cloth, anatomy or per-view geometry is substituted.
"""
import numpy as np

SHELL_DEFAULTS = {'epsilon': 1e-10, 'radial_steps': 6}


def relief(rim, ridge, thickness):
    rim = np.asarray(rim, float)
    ridge = np.asarray(ridge, float)
    normal = np.cross(rim[1] - rim[0], rim[-1] - rim[0])
    length = np.linalg.norm(normal)
    if len(rim) < 3 or length <= SHELL_DEFAULTS['epsilon'] or thickness <= 0:
        raise ValueError('Rigid relief requires a polygon and measured thickness')
    normal /= length
    if np.dot(ridge - rim.mean(0), normal) < 0:
        normal = -normal
    n = len(rim)
    centre = rim.mean(0)
    height = np.dot(ridge - centre, normal)
    planar_ridge = ridge - height * normal
    vertices, faces = [], []
    # Rounded convex relief, rather than a triangle fan pyramid. The measured
    # rim and ridge remain exact; tessellation only resolves the curved plate.
    steps = SHELL_DEFAULTS['radial_steps']
    for row, t in enumerate(np.linspace(0, 1, steps, endpoint=False)):
        points = (1-t)*rim + t*planar_ridge + normal*height*np.sin(t*np.pi/2)
        vertices.extend(points.tolist())
        if row:
            for i in range(n):
                j = (i+1)%n
                faces.append([(row-1)*n+i,(row-1)*n+j,row*n+j,row*n+i])
    top = len(vertices)
    vertices.append(ridge.tolist())
    bottom = len(vertices)
    vertices.extend((rim-normal*thickness).tolist())
    back = len(vertices)
    vertices.append((centre-normal*thickness).tolist())
    for i in range(n):
        j = (i+1)%n
        faces.extend([[(steps-1)*n+i,(steps-1)*n+j,top],
                      [bottom+j,bottom+i,back],[j,i,bottom+i,bottom+j]])
    return vertices, faces


def layered(plates):
    vertices, faces = [], []
    for plate in plates:
        v, f = relief(plate['rim'], plate['ridge'], plate['thickness'])
        faces.extend([[i + len(vertices) for i in face] for face in f])
        vertices.extend(v)
    if not vertices:
        raise ValueError('Rigid shell requires at least one measured plate')
    return vertices, faces

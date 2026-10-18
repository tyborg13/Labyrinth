"""Closed, smooth arthropod sections with curved axes and integral small spines."""
import math
import numpy as np

LIMB_DEFAULTS = {'samples_per_span': 10, 'radial_samples': 16, 'epsilon': 1e-9}


def sampled_axis(points, radii, closed=False):
    points = np.asarray(points, float)
    output = []
    for index in range(len(points) if closed else len(points)-1):
        a,b=points[index],points[(index+1)%len(points)]
        before = points[(index-1)%len(points)] if closed else points[max(0,index-1)]
        after = points[(index+2)%len(points)] if closed else points[min(len(points)-1,index+2)]
        ma, mb = (b-before)*.5, (after-a)*.5
        for t in np.linspace(0, 1, LIMB_DEFAULTS['samples_per_span'], endpoint=False):
            p = (2*t**3-3*t*t+1)*a + (t**3-2*t*t+t)*ma + (-2*t**3+3*t*t)*b + (t**3-t*t)*mb
            output.append((p, radii[index]*(1-t)+radii[(index+1)%len(points)]*t))
    return output if closed else output + [(points[-1], radii[-1])]


def section_mesh(points, radii, sculpt, closed=False):
    axis = sampled_axis(points, radii,closed)
    vertices, faces, frames = [], [], []
    sides = LIMB_DEFAULTS['radial_samples']
    extent=np.ptp(np.asarray(points),axis=0) if closed else abs(axis[-1][0]-axis[0][0])
    reference = np.eye(3)[int(np.argmin(extent))]
    for row, (centre, radius) in enumerate(axis):
        tangent = (axis[(row+1)%len(axis)][0]-axis[(row-1)%len(axis)][0] if closed else
                   axis[min(row+1,len(axis)-1)][0]-axis[max(row-1,0)][0])
        tangent /= np.linalg.norm(tangent)
        u = np.cross(tangent, reference);u /= np.linalg.norm(u)
        v = np.cross(tangent, u)
        frames.append((tangent,u,v))
        t = row/(len(axis) if closed else len(axis)-1)
        ridge = 1 + sculpt['ridge_depth'] * math.cos(math.tau*sculpt['ridge_count']*t)**8
        for column in range(sides):
            angle = math.tau*column/sides
            irregularity = 1 + sculpt['asymmetry']*math.sin(3*angle+5*t)
            vertices.append((centre + max(radius,LIMB_DEFAULTS['epsilon'])*ridge*irregularity*(u*math.cos(angle)+v*math.sin(angle))).tolist())
    if not closed:faces.append(list(reversed(range(sides))))
    for row in range(len(axis) if closed else len(axis)-1):
        following=(row+1)%len(axis)
        for column in range(sides):
            k = (column+1)%sides
            faces.append([row*sides+column,row*sides+k,following*sides+k,following*sides+column])
    if not closed:faces.append([(len(axis)-1)*sides+i for i in range(sides)])
    for spine in sculpt.get('spines', []):
        row = round(spine['t']*(len(axis)-1))
        centre, radius = axis[row]
        tangent,u,v = frames[row]
        outward = u*math.cos(spine['angle'])+v*math.sin(spine['angle'])
        root = centre + outward*radius*.8
        points = [root, root+outward*spine['length']*.65-tangent*spine['length']*.1,
                  root+outward*spine['length']-tangent*spine['length']*.4]
        child = {'ridge_depth':0,'ridge_count':1,'asymmetry':0}
        added, polygons = section_mesh(points,[spine['radius'],spine['radius']*.65,.0002],child)
        start=len(vertices);vertices.extend(added)
        faces.extend([[start+i for i in face] for face in polygons])
    return vertices, faces


def build(piece, spec):
    from .pieces import mesh_object, place
    vertices, faces = section_mesh(piece['path'],[piece['radius']*r for r in piece['taper']],piece['sculpt'],piece['closed'])
    obj = place(mesh_object(piece['id'],vertices,faces),piece,spec)
    for polygon in obj.data.polygons:polygon.use_smooth=True
    obj['sculpted_section'] = True
    obj['integral_spine_count'] = len(piece['sculpt'].get('spines',[]))
    return obj


def validate_sculpt(sculpt):
    if not (0 <= sculpt['ridge_depth'] <= .5 and type(sculpt['ridge_count']) is int and sculpt['ridge_count'] > 0 and 0 <= sculpt['asymmetry'] <= .25):
        raise ValueError('Limb sculpt requires bounded relief and positive annular count')
    for spine in sculpt.get('spines', []):
        if not (0 <= spine['t'] <= 1 and min(spine['radius'],spine['length']) > 0 and math.isfinite(spine['angle'])):
            raise ValueError('Integral spine requires a position, direction and positive dimensions')

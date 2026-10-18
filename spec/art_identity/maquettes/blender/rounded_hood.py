"""A rounded, open-faced cloth rest cowl fitted to the actual native skull.

The skull supplies dimensions, the director supplies opening width, and the
identity reference supplies its height and shoulder hem. Contact allowance is
exactly the existing collision skin plus solver and fabric thickness.
"""
import json
import math
import numpy as np

HOOD_DEFAULTS = {'revision': 1, 'skull_rows': 25, 'columns': 48,
                 'shoulder_rows': 8, 'crown_pin_rows': 3}


def rest_mesh(bounds, hem, width_ratio, opening_height, allowance):
    from .contract import pattern_mesh
    lo, hi = np.array(bounds[0]), np.array(bounds[1])
    centre = (lo + hi) / 2
    radii = (hi - lo) / 2 + allowance
    count = HOOD_DEFAULTS['columns']
    if width_ratio == 0:
        return closed_rest_mesh(lo, hi, hem, opening_height, allowance)
    rows, pins = [], []
    opening_rows = []
    for i, latitude in enumerate(np.linspace(math.pi / 2, -math.pi / 3, HOOD_DEFAULTS['skull_rows'])):
        radius_x, radius_y = radii[:2] * math.cos(latitude)
        z = centre[2] + radii[2] * math.sin(latitude)
        half_width = width_ratio * (hi[1] - lo[1]) / 2 * math.sqrt(max(0, 1 - ((z - centre[2]) / (opening_height / 2)) ** 2))
        angle = math.asin(min(.99, half_width / radius_y)) if radius_y > 1e-8 else 0
        if angle:
            opening_rows.append(i)
        row = [[centre[0] + radius_x * math.cos(a), centre[1] + radius_y * math.sin(a), z]
               for a in np.linspace(angle, math.tau - angle, count)]
        rows.append(row)
        if i < HOOD_DEFAULTS['crown_pin_rows']:
            pins.extend(i * count + j for j in range(count))
        if angle:
            pins.extend([i * count, (i + 1) * count - 1])
    # Interpolate the shoulder fall to its measured closed hem; the full skull
    # remains rounded, including the back and the brow's forward overhang.
    hem = np.array(hem, float)
    phi = np.linspace(0, len(hem) - 1, count)
    hem = np.column_stack([np.interp(phi, np.arange(len(hem)), hem[:, a]) for a in range(3)])
    first = np.array(rows[-1])
    for t in np.linspace(0, 1, HOOD_DEFAULTS['shoulder_rows'] + 1)[1:]:
        rows.append(((1 - t) * first + t * hem).tolist())
    pattern = {'columns': count, 'closed': False, 'rows': [{'points': row} for row in rows], 'pins': pins}
    vertices, faces = pattern_mesh(pattern, {'count': 0, 'depth': 0, 'seed': 0})
    return vertices, faces, pins, {'head_bounds': [lo.tolist(), hi.tolist()], 'head_width': float(hi[1] - lo[1]),
        'opening_width': float(width_ratio * (hi[1] - lo[1])), 'opening_width_ratio': width_ratio,
        'opening_height': opening_height, 'collision_allowance': allowance, 'opening_rows': opening_rows,
        'defaults': HOOD_DEFAULTS}


def closed_rest_mesh(lo, hi, hem, opening_height, allowance):
    """A sewn circular cowl with one crown vertex and no duplicate seam."""
    centre = (lo + hi) / 2
    radii = (hi - lo) / 2 + allowance
    count = HOOD_DEFAULTS['columns']
    rows = []
    latitudes = np.linspace(math.pi/2, -math.pi/3, HOOD_DEFAULTS['skull_rows'])
    crown = [centre[0], centre[1], centre[2] + radii[2]]
    for latitude in latitudes[1:]:
        rows.append([[centre[0]+radii[0]*math.cos(latitude)*math.cos(a),
                      centre[1]+radii[1]*math.cos(latitude)*math.sin(a),
                      centre[2]+radii[2]*math.sin(latitude)]
                     for a in np.linspace(0, math.tau, count, endpoint=False)])
    hem = np.asarray(hem, float)
    phi = np.linspace(0, len(hem)-1, count, endpoint=False)
    hem = np.column_stack([np.interp(phi,np.arange(len(hem)),hem[:,a]) for a in range(3)])
    first = np.array(rows[-1])
    rows.extend(((1-t)*first+t*hem).tolist() for t in np.linspace(0,1,HOOD_DEFAULTS['shoulder_rows']+1)[1:])
    vertices = [crown] + np.asarray(rows).reshape(-1,3).tolist()
    faces = [[0,1+(j+1)%count,1+j] for j in range(count)]
    for r in range(len(rows)-1):
        for j in range(count):
            k=(j+1)%count; a=1+r*count; b=a+count
            faces.append([a+j,a+k,b+k,b+j])
    pins = list(range(1+(HOOD_DEFAULTS['crown_pin_rows']-1)*count))
    report = {'head_bounds':[lo.tolist(),hi.tolist()],'head_width':float(hi[1]-lo[1]),
        'opening_width':0,'opening_width_ratio':0,'opening_height':opening_height,
        'collision_allowance':allowance,'opening_rows':[],'closed_crown_and_seam':True,'defaults':HOOD_DEFAULTS}
    return vertices, faces, pins, report


def make(obj, body, piece, spec):
    import bpy
    from .drape_collision import COLLIDER_DEFAULTS
    owners = json.loads(body['face_owners'])
    indices = {i for p, owner in zip(body.data.polygons, owners) if owner == piece['part'] for i in p.vertices}
    points = np.array([list(body.matrix_world @ body.data.vertices[i].co) for i in sorted(indices)])
    config = piece['drape']['native_hood']
    hem = piece['pattern']['rows'][-1]['points']
    allowance = piece.get('solver_margin', piece['collision_margin']) + COLLIDER_DEFAULTS['surface_allowance'] + piece['thick'] / 2
    if config.get('use_solver_rest_clearance'):
        # Match prepare()'s initial collision band. Starting inside that band
        # collapses distinct sewn crown vertices before self-collision begins.
        allowance += COLLIDER_DEFAULTS['initial_clearance']
    vertices, faces, pins, report = rest_mesh([points.min(axis=0), points.max(axis=0)], hem,
        config['opening_width_ratio'], config['opening_height_px'] * spec['ortho_scale'] / 256, allowance)
    old = obj.data
    mesh = bpy.data.meshes.new(piece['id'] + '_rounded_rest')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj.data = mesh
    bpy.data.meshes.remove(old)
    obj['rounded_hood_report'] = json.dumps(report)
    print('ROUNDED_HOOD_REST: ' + json.dumps(report), flush=True)
    return pins

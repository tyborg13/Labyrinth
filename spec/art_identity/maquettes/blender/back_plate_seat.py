"""Rigid, scaled back plates on native garment support planes.

Choose the closest legal back contact at each source layer's height. Pixel
bounds constrain placement, not plate dimensions. No boolean fragments,
per-view meshes, or changes to solved clothing are introduced.
"""
import json

import numpy as np

from ..raster import project
from .contract import BUILD_DEFAULTS
from .rigid_clearance import components

SEAT_DEFAULTS = {'epsilon': 1e-10}


def horizontal_segment(points, height):
    points = np.asarray(points, float)
    hits = []
    for a, b in zip(points, np.roll(points, -1, axis=0)):
        if abs(a[2] - height) <= SEAT_DEFAULTS['epsilon']:
            hits.append(a)
        if (a[2] - height) * (b[2] - height) < 0:
            hits.append(a + (b - a) * (height - a[2]) / (b[2] - a[2]))
    if len(hits) < 2:
        return None
    pairs = [(float(np.linalg.norm(b - a)), a, b) for i, a in enumerate(hits) for b in hits[i+1:]]
    _, a, b = max(pairs, key=lambda row: row[0])
    return None if np.linalg.norm(b - a) <= SEAT_DEFAULTS['epsilon'] else (a, b)


def feasible_parameter(minimum, maximum, delta, low, high):
    if abs(delta) <= SEAT_DEFAULTS['epsilon']:
        return (0., 1.) if minimum >= low and maximum <= high else None
    a, b = (low - minimum) / delta, (high - maximum) / delta
    start, stop = (a, b) if delta > 0 else (b, a)
    start, stop = max(0., start), min(1., stop)
    return (start, stop) if start <= stop else None


def surface_frame(normal, lateral):
    normal, lateral = np.asarray(normal, float), np.asarray(lateral, float)
    normal = normal / np.linalg.norm(normal)
    lateral = lateral - normal * (lateral @ normal)
    if np.linalg.norm(lateral) <= SEAT_DEFAULTS['epsilon']:
        raise ValueError('Shoulder line is normal to the plate support')
    lateral /= np.linalg.norm(lateral)
    return np.column_stack((lateral, np.cross(normal, lateral), normal))


def plate_frame(points, lateral, exposed):
    """Fit the thin plane of an accepted closed plate fragment."""
    points = np.asarray(points, float)
    relative = points-points.mean(0)
    _, axes = np.linalg.eigh(relative.T @ relative)
    normal, long_axis = axes[:, 0], axes[:, 2]
    if normal @ exposed < 0:
        normal = -normal
    if long_axis @ lateral < 0:
        long_axis = -long_axis
    return surface_frame(normal, long_axis)


def seat_shell(spec):
    import bpy
    from .drape_collision import COLLIDER_DEFAULTS

    config = spec['articulated_pose']['shell']
    obj = bpy.data.objects[config['piece'] + '_render']
    original_clearance = json.loads(obj['rigid_clearance_report'])
    targets = config['support']
    supports = [bpy.data.objects[p['id'] + '_render'] for p in spec['pieces'] if p['type'] == 'cloth']
    voxel = COLLIDER_DEFAULTS['voxel_size']
    clearance = max(p['collision_margin'] for p in spec['pieces'] if p['type'] == 'cloth') + COLLIDER_DEFAULTS['voxel_size']
    hood = bpy.data.objects[targets[0] + '_render']
    cover = set(json.loads(hood['articulated_head_cover_indices']))
    shoulders = [list(hood.matrix_world @ v.co) for v in hood.data.vertices if v.index not in cover]
    # The cowl and back supply shoulder contacts. The skull-covering hood
    # cannot act as a shoulder support even when it is the nearest hull face.
    from .rigid_clearance import hull
    vertices, faces = hull(shoulders + [list(o.matrix_world @ v.co) for o in supports
        if o != hood for v in o.data.vertices])
    vertices = np.asarray(vertices)
    pixels = project(spec, shoulders)[:, 0]
    # Reserve the existing native floating-point collision epsilon inside the
    # director's bound, so float32 mesh storage cannot add a spurious overrun.
    slack = config['max_overhang_px'] - (BUILD_DEFAULTS['collision_epsilon'] + voxel) * 1024 / spec['ortho_scale']
    low, high = pixels.min() - slack, pixels.max() + slack
    points = np.array([list(obj.matrix_world @ v.co) for v in obj.data.vertices])
    source_points = points.copy()
    centre = points.mean(0)
    points = centre + (points - centre) * config['scale']
    shoulder_height = np.mean([spec['joints']['shoulder_' + side][2] for side in ('near', 'far')])
    points[:, 2] += shoulder_height - points[:, 2].mean()
    groups = components(len(points), [list(e.vertices) for e in obj.data.edges])
    contacts = []
    contact_reports = []
    rigidity = []
    patch_vertices, patch_faces = [], []
    from .plate_contact import cloth_support, settle
    support = cloth_support(supports)
    for layer, indices in enumerate(groups):
        plate = points[indices]
        centre = plate.mean(0)
        relative = plate - centre
        lateral = np.subtract(spec['joints']['shoulder_far'], spec['joints']['shoulder_near'])
        exposed = source_points[indices].mean(0)-spec['articulated_pose_source_joints']['torso']
        source_frame = plate_frame(plate, lateral, exposed)
        candidates = []
        for face in faces:
            triangle = vertices[face]
            outward = np.cross(triangle[1] - triangle[0], triangle[-1] - triangle[0])
            length = np.linalg.norm(outward)
            if length <= SEAT_DEFAULTS['epsilon']:
                continue
            outward /= length
            if outward[0] >= -SEAT_DEFAULTS['epsilon']:
                continue
            segment = horizontal_segment(triangle, centre[2])
            if segment is None:
                continue
            a, b = segment
            # Normal alignment alone leaves an arbitrary roll: it can stand
            # the long rim upright as a fin. The source plate's long axis
            # follows the level shoulder bar along the cloak instead.
            try:
                rotation = surface_frame(outward, lateral) @ source_frame.T
            except ValueError:
                continue
            rotated = relative @ rotation.T
            offset = outward * (clearance - (rotated @ outward).min())
            initial = rotated + a + offset
            initial_x = project(spec, initial)[:, 0]
            dx = project(spec, [b])[0, 0] - project(spec, [a])[0, 0]
            interval = feasible_parameter(initial_x.min(), initial_x.max(), dx, low, high)
            if interval is None:
                continue
            direction = b - a
            t = np.clip((centre - a - offset) @ direction / (direction @ direction), *interval)
            contact = a + t * direction
            placed = rotated + contact + offset
            distance = float(np.linalg.norm(placed.mean(0) - centre))
            candidates.append((distance, placed, contact, outward))
        if not candidates:
            raise ValueError('Scaled back plate has no supported placement within the shoulder bound')
        # Preserve the accepted near/far placement by minimizing displacement
        # of each scaled piece, among the legal back-facing support contacts.
        _, placed, contact, outward = min(candidates, key=lambda row: row[0])
        selected = set(indices)
        lookup = {old: new for new, old in enumerate(indices)}
        layer_vertices = placed.tolist()
        layer_faces = [[lookup[i] for i in f.vertices] for f in obj.data.polygons if set(f.vertices) <= selected]
        layer_vertices, touch = settle(layer_vertices, layer_faces, support, clearance,
            max(p['collision_margin'] for p in spec['pieces'] if p['type'] == 'cloth'), spec, (low, high))
        placed = np.array(layer_vertices)
        contact_reports.append(touch)
        rigidity.append(float(abs(np.linalg.norm(placed - placed[0], axis=1) -
                                 np.linalg.norm(plate - plate[0], axis=1)).max()))
        offset = len(patch_vertices)
        patch_vertices.extend(layer_vertices)
        patch_faces.extend([i + offset for i in f] for f in layer_faces)
        contacts.append(contact.tolist())
    old = obj.data
    data = bpy.data.meshes.new(config['piece'] + '_flush')
    data.from_pydata(patch_vertices, [], patch_faces)
    smooth = all(p.use_smooth for p in old.polygons)
    for polygon in data.polygons:
        polygon.use_smooth = smooth
    data.update()
    obj.data = data
    obj.matrix_world.identity()
    bpy.data.meshes.remove(old)
    obj['rigid_clearance_report'] = json.dumps({'targets': targets, 'clearance': clearance,
        'cloth_unchanged': True, 'closed_plates_retained': len(groups), 'scale': config['scale'],
        'maximum_rigidity_error_m': max(rigidity),
        'source_clearance': original_clearance,
        'actual_cloth_contacts': contact_reports,
        'contacts': contacts, 'method': 'Rigid 60% source plates tangent to the solved cloak support envelope'})

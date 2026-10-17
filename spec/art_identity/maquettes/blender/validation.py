"""Geometry gates on evaluated Blender meshes, independent of pretty renders."""
import math
import json
from mathutils import Vector

from .contract import BUILD_DEFAULTS


def geometry_report(spec, objects, cloth_reports, details=None):
    details = {} if details is None else details
    details.update(collar_widths={}, corner_errors={}, conformance={})
    epsilon = BUILD_DEFAULTS['collision_epsilon']
    labelled = all(o.get('part') in spec['labels'] and len(o.data.polygons) for o in objects)
    expected = {b['region'] for b in spec['armature']['bones']} | {p['part'] for p in spec['pieces']}
    represented = {o['part'] for o in objects}
    collar_ok = True
    for obj in objects:
        if obj.get('cloth_kind') != 'collar':
            continue
        piece = next(p for p in spec['pieces'] if p['id'] == obj['piece_id'])
        origin = Vector(piece.get('symmetry_origin', spec['joints'][piece['at']]))
        pts = [obj.matrix_world @ v.co - origin for v in obj.data.vertices]
        front_axis = Vector(piece.get('symmetry_front', [1, 0, 0]))
        lateral = Vector(piece.get('symmetry_lateral', [0, 1, 0]))
        front = [abs(p.dot(lateral)) for p in pts if p.dot(front_axis) >= 0]
        back = [abs(p.dot(lateral)) for p in pts if p.dot(front_axis) <= 0]
        collar_ok &= bool(front and back and max(front) <= max(back) + epsilon)
        details['collar_widths'][obj['piece_id']] = {'front': max(front, default=0), 'back': max(back, default=0)}
    corners_ok = True
    conform_ok = True
    from .conformance import body_tree
    import bpy
    body = bpy.data.objects.get('posed_body')
    tree = body_tree(body) if body else None
    for obj in objects:
        if obj.get('conforming'):
            contact = body_tree(bpy.data.objects[obj['contact_target']]) if obj.get('contact_target') else tree
            distances = [contact.find_nearest(obj.matrix_world @ v.co)[3] for v in obj.data.vertices]
            if not distances:
                details['conformance'][obj['piece_id']] = {'passed': False, 'error': 'Empty armour mesh'}
                conform_ok = False
                continue
            limit = obj['surface_allowance'] + epsilon
            passed = obj['surface_offset'] <= .015 and max(distances) <= limit
            details['conformance'][obj['piece_id']] = {'max_distance': max(distances),
                'allowed': limit, 'shrinkwrap_offset': obj['surface_offset'], 'passed': bool(passed)}
            conform_ok &= passed
        if obj.get('piece_type') not in ('plate', 'lames'):
            continue
        if obj.get('body_shell'):
            continue
        piece = next(p for p in spec['pieces'] if obj['piece_id'] == p['id'] or obj['piece_id'].startswith(p['id'] + '_'))
        scale = [1, 1]
        if piece['type'] == 'lames':
            scale = piece['lame_scale'][int(obj['piece_id'].rsplit('_', 1)[1])]
        # Compare in the designed plate plane: corner erosion must remain within
        # the explicit bevel width. Native sharp miter is also set in pieces.py.
        outline = piece['outline']
        conformed = json.loads(obj['conformed_corners']) if 'conformed_corners' in obj else None
        for index, (x, z) in enumerate(outline):
            error = (min((v.co - Vector(conformed[index])).length for v in obj.data.vertices) if conformed else
                     min(((v.co.x - x * scale[0]) ** 2 + (v.co.z - z * scale[1]) ** 2) ** 0.5 for v in obj.data.vertices))
            a = Vector((outline[index - 1][0] - x, outline[index - 1][1] - z)).normalized()
            b = Vector((outline[(index + 1) % len(outline)][0] - x, outline[(index + 1) % len(outline)][1] - z)).normalized()
            if conformed:
                a = (Vector(conformed[index - 1]) - Vector(conformed[index])).normalized()
                b = (Vector(conformed[(index + 1) % len(outline)]) - Vector(conformed[index])).normalized()
            half_angle = math.acos(max(-1, min(1, a.dot(b)))) / 2
            # Native bevel cuts an acute corner farther along its bisector.
            # Compare with the exact geometric bound, not a right-angle-only width.
            erosion = piece['bevel']['width'] / max(math.sin(half_angle), epsilon)
            if conformed:
                erosion += piece['thick'] / 2
            corners_ok &= error <= erosion + epsilon
            if error > erosion + epsilon:
                details['corner_errors'].setdefault(obj['piece_id'], []).append({'error': error, 'allowed': erosion, 'corner': [x, z]})
    return {'labels_cover_every_face': bool(labelled and expected <= represented),
            'cloth_collision_margin': all(r['passed'] for r in cloth_reports.values()),
            'collar_front_no_wider_than_back': bool(collar_ok),
            'plate_corners_preserved': bool(corners_ok),
            'armour_conforms_to_body': bool(conform_ok)}

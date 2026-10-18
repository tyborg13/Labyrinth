"""Geometry gates on evaluated Blender meshes, independent of pretty renders."""
import math
import json
from mathutils import Vector

from .contract import BUILD_DEFAULTS
from .ownership import materials_match, weights_match, expected_materials


def geometry_report(spec, objects, cloth_reports, details=None):
    details = {} if details is None else details
    details.update(collar_widths={}, corner_errors={}, conformance={})
    epsilon = BUILD_DEFAULTS['collision_epsilon']
    labelled = all(o.get('part') in spec['labels'] and len(o.data.polygons) for o in objects)
    from .view_states import view_parts
    expected = view_parts(spec, 'front')
    import bpy
    forward = bpy.data.objects['maquette_armature']['posed_forward']
    assignments = {o.name: expected_materials(o, spec, forward) for o in objects}
    represented = {list(spec['labels'])[i] for values in assignments.values() for i in values}
    from .view_states import active_in_view, view_parts
    views_ok = all(view_parts(spec, view) <= {list(spec['labels'])[i] for o in objects
                   if active_in_view(o, view) for i in assignments[o.name]}
                   for view in ('front', 'rear'))
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
    body = bpy.data.objects.get('posed_body')
    material_ok = all(materials_match(o, assignments[o.name]) for o in objects)
    weighted_ok = True
    if body and 'face_owners' in body:
        source = bpy.data.objects['body']
        weights = [{source.vertex_groups[g.group].name: g.weight for g in v.groups} for v in source.data.vertices]
        regions = {b['name']: b['region'] for b in spec['armature']['bones']}
        source_owners = json.loads(body['face_owners'])
        weighted_ok = weights_match([p.vertices[:] for p in body.data.polygons], weights, regions, source_owners)
        by_face = {tuple(p.vertices): owner for p, owner in zip(body.data.polygons, source_owners)}
        weighted_ok &= all(by_face.get(tuple(p.vertices)) == o['part'] for o in objects
                           if o.get('piece_type') == 'body' for p in o.data.polygons)
    tree = body_tree(body) if body and len(body.data.polygons) else None
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
            if 'outline_3d' in piece:
                spatial = [Vector(p) for p in (conformed or piece['outline_3d'])]
                error = min((v.co - spatial[index]).length for v in obj.data.vertices)
                a = (spatial[index - 1] - spatial[index]).normalized()
                b = (spatial[(index + 1) % len(spatial)] - spatial[index]).normalized()
            if conformed:
                a = (Vector(conformed[index - 1]) - Vector(conformed[index])).normalized()
                b = (Vector(conformed[(index + 1) % len(outline)]) - Vector(conformed[index])).normalized()
            half_angle = math.acos(max(-1, min(1, a.dot(b)))) / 2
            # Native bevel cuts an acute corner farther along its bisector.
            # Compare with the exact geometric bound, not a right-angle-only width.
            erosion = piece['bevel']['width'] / max(math.sin(half_angle), epsilon)
            if conformed or 'outline_3d' in piece:
                erosion += piece['thick'] / 2
            corners_ok &= error <= erosion + epsilon
            if error > erosion + epsilon:
                details['corner_errors'].setdefault(obj['piece_id'], []).append({'error': error, 'allowed': erosion, 'corner': [x, z]})
    result = {'labels_cover_every_face': bool(labelled and expected <= represented),
            'view_piece_ownership': bool(views_ok),
            'polygon_material_ownership': bool(material_ok),
            'body_weight_ownership': bool(weighted_ok),
            'cloth_collision_margin': all(r['passed'] for r in cloth_reports.values()),
            'collar_front_no_wider_than_back': bool(collar_ok),
            'plate_corners_preserved': bool(corners_ok),
            'armour_conforms_to_body': bool(conform_ok)}
    bound = [p for p in spec['pieces'] if p.get('rig_bone')]
    if bound:
        # The editable source, not the immutable render copy, owns the binding.
        # A material-correct but unrigged boulder is not a finished native rig.
        from .creature_rig import bindings_match
        result['native_rigid_bindings'] = bindings_match(bound, bpy.data.objects,
                                                        bpy.data.objects['maquette_armature'])
    masses = [p for p in spec['pieces'] if p['type'] == 'sculpted_mass']
    if masses:
        from .sculpted_mass import native_stack_matches, frozen_differs_from_base
        result['native_sculpted_surfaces'] = all(native_stack_matches(p, bpy.data.objects.get(p['id'])) and
            frozen_differs_from_base(bpy.data.objects.get(p['id']),bpy.data.objects.get(p['id']+'_render'))
                                               for p in masses)
    if spec.get('native_features'):
        from .solid_features import feature_report
        details['native_features'] = feature_report(spec, objects)
        result['whole_native_features'] = all(r['passed'] for r in details['native_features'].values())
    sections=[p for p in spec['pieces'] if p.get('sculpt')]
    if sections:
        result['native_sculpted_sections'] = all(
            bpy.data.objects[p['id']].get('sculpted_section') and
            bpy.data.objects[p['id']].get('integral_spine_count') == len(p['sculpt'].get('spines',[])) and
            all(face.use_smooth for face in bpy.data.objects[p['id']+'_render'].data.polygons)
            for p in sections)
    if spec.get('native_contacts') or spec.get('foot_contacts') or any('support_z' in p for p in spec['pieces']):
        from .solid_contacts import report
        details['native_contacts'] = report(spec,objects)
        result['native_contacts'] = details['native_contacts']['passed']
    return result

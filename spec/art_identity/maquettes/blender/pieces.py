"""Native accessory modifiers, curves, faceted crystals and diamond insets."""
from copy import deepcopy
import math
import random

import bpy
from mathutils import Euler, Vector
from mathutils.geometry import delaunay_2d_cdt

from .contract import BUILD_DEFAULTS


def mesh_object(name, vertices, faces):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def place(obj, piece, spec):
    obj.location = Vector(spec['joints'][piece['at']]) + Vector(piece['offset'])
    if piece.get('bone'):
        # Accessories follow the posed bone frame while design offsets/rot stay local.
        bone = bpy.data.objects['maquette_armature'].pose.bones[piece['bone']]
        basis = bone.matrix.to_quaternion()
        obj.location = Vector(spec['joints'][piece['at']]) + basis @ Vector(piece['offset'])
        obj.rotation_euler = (basis @ Euler(piece['rot'], 'XYZ').to_quaternion()).to_euler()
    else:
        obj.rotation_euler = piece['rot']
    obj['part'] = piece['part']
    obj['piece_id'] = piece['id']
    obj['piece_type'] = piece['type']
    if 'clay_colour' in piece:
        obj['clay_colour'] = piece['clay_colour']
    if 'accent_colour' in piece:
        obj['accent_colour'] = piece['accent_colour']
    return obj


def plate(piece, spec, body):
    if piece.get('body_shell'):
        from .conformance import regional_body
        body = regional_body(body, piece)
        obj = place(mesh_object(piece['id'], [list(v.co) for v in body.data.vertices],
                                [tuple(p.vertices) for p in body.data.polygons]), piece, spec)
        obj.matrix_world = body.matrix_world.copy()
        obj['body_shell'] = True
        obj['conforming'] = True
        obj['contact_target'] = body.name
        obj['surface_offset'] = piece['offset_surface']
        obj['surface_allowance'] = piece['offset_surface'] + piece['thick'] / 2 + piece.get('cuff_flare', 0)
        if piece.get('smooth_shell'):
            for polygon in obj.data.polygons:
                polygon.use_smooth = True
        wrap = obj.modifiers.new('body_conform', 'SHRINKWRAP')
        wrap.target = body
        wrap.wrap_method = 'NEAREST_SURFACEPOINT'
        wrap.wrap_mode = 'ABOVE_SURFACE'
        wrap.offset = piece['offset_surface']
        if piece.get('cuff_flare'):
            group = obj.vertex_groups.new(name='flared_cuff')
            wrist = Vector(spec['joints'][piece['at']])
            for v in obj.data.vertices:
                weight = max(0, 1 - (obj.matrix_world @ v.co - wrist).length / piece['cuff_height'])
                group.add([v.index], weight, 'REPLACE')
            flare = obj.modifiers.new('flared_cuff', 'DISPLACE')
            flare.direction = 'NORMAL'
            flare.strength = piece['cuff_flare']
            flare.mid_level = 0
            flare.vertex_group = group.name
        solid = obj.modifiers.new('shell_thickness', 'SOLIDIFY')
        solid.thickness = piece['thick']
        solid.offset = 0
        bevel = obj.modifiers.new('shell_edges', 'BEVEL')
        bevel.width = piece['bevel']['width']
        bevel.segments = piece['bevel']['segments']
        bevel.miter_outer = 'MITER_SHARP'
        if piece.get('smooth_shell'):
            bevel.harden_normals = True
            normals = obj.modifiers.new('boot_normals', 'WEIGHTED_NORMAL')
            normals.keep_sharp = True
        return obj
    outline = piece['outline']
    vertices = piece.get('outline_3d', [(x, 0, z) for x, z in outline])
    conform = piece.get('conform_weights')
    if piece.get('conforming'):
        from .conformance import dense_outline
        vertices, faces, origins = dense_outline(outline, piece['surface_spacing'], piece.get('ridge'))
    elif piece.get('ridge'):
        # A constrained ridge edge, rather than a central pyramid point, keeps
        # the breastplate's vertical ridge continuous between its two endpoints.
        ridge = piece['ridge']
        coords = [Vector(p) for p in outline + ridge['line']]
        count = len(outline)
        edges = [(i, (i + 1) % count) for i in range(count)] + [(count, count + 1)]
        coords, _, faces, origins, _, _ = delaunay_2d_cdt(coords, edges, [list(range(count))], 1, BUILD_DEFAULTS['triangulation_epsilon'])
        vertices = [(p.x, -ridge['height'] if any(i >= count for i in ids) else 0, p.y)
                    for p, ids in zip(coords, origins)]
        if conform is not None:
            conform = [sum(conform[i] for i in ids) / len(ids) if ids else 0 for ids in origins]
    else:
        faces = [tuple(range(len(vertices)))]
    obj = place(mesh_object(piece['id'], vertices, faces), piece, spec)
    if piece.get('conforming'):
        from .conformance import conform_plate, regional_body
        body = regional_body(body, piece)
        conform_plate(obj, piece, body, origins)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    if piece.get('native_mask'):
        from .masked_hood import fit_plate
        fit_plate(obj, piece, spec, body)
    elif piece.get('face_plane'):
        import json
        from .source_recipe import plane_point
        target = bpy.data.objects[piece['seat_on'] + '_render']
        hood = json.loads(target['rounded_hood_report'])
        plane_x = hood['head_bounds'][1][0] + hood['collision_allowance'] + piece['thick']
        for vertex, pixel in zip(obj.data.vertices, piece['source_outline_px']):
            vertex.co = plane_point(spec, pixel, 0, plane_x)
        obj['conformed_corners'] = json.dumps([list(v.co) for v in obj.data.vertices])
        obj['source_face_plane'] = plane_x
        obj['seated_on_cloth'] = piece['seat_on']
    elif piece.get('seat_on'):
        from .conformance import body_tree
        target = bpy.data.objects[piece['seat_on'] + '_render']
        tree = body_tree(target)
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            hit, _, _, _ = tree.ray_cast(Vector((spec['ortho_scale'], point.y, point.z)), Vector((-1, 0, 0)))
            if hit is not None:
                vertex.co.x = hit.x + piece['thick']
        obj['conformed_corners'] = __import__('json').dumps([list(v.co) for v in obj.data.vertices])
        obj['seated_on_cloth'] = piece['seat_on']
    solid = obj.modifiers.new('plate_thickness', 'SOLIDIFY')
    solid.thickness = piece['thick']
    solid.offset = 0
    bevel = obj.modifiers.new('edge_bevel', 'BEVEL')
    bevel.width = piece['bevel']['width']
    bevel.segments = piece['bevel']['segments']
    bevel.limit_method = 'ANGLE'
    bevel.angle_limit = piece['bevel']['angle_limit']
    bevel.miter_outer = 'MITER_SHARP'
    if piece.get('conforming'):
        bevel.harden_normals = True
        normals = obj.modifiers.new('plate_normals', 'WEIGHTED_NORMAL')
        normals.keep_sharp = True
        if piece.get('slots'):
            from .face_slots import cut_slots
            cut_slots(obj, piece, spec)
        return obj
    wrap = obj.modifiers.new('body_conform', 'SHRINKWRAP')
    wrap.target = body
    wrap.wrap_method = 'NEAREST_SURFACEPOINT'
    wrap.wrap_mode = 'OUTSIDE'
    wrap.offset = piece['offset_surface']
    # Explicit conform weight preserves the designed centre ridge and corners.
    if conform is not None:
        group = obj.vertex_groups.new(name='conform')
        for i, weight in enumerate(conform):
            group.add([i], weight, 'REPLACE')
        wrap.vertex_group = group.name
    return obj


def lames(piece, spec, body):
    result = []
    for i in range(piece['count']):
        item = deepcopy(piece)
        item['id'] = f"{piece['id']}_{i:02}"
        scale = piece['lame_scale'][i]
        item['outline'] = [[x * scale[0], z * scale[1]] for x, z in piece['outline']]
        if item.get('ridge'):
            item['ridge']['line'] = [[x * scale[0], z * scale[1]] for x, z in piece['ridge']['line']]
        item['offset'] = [a + b for a, b in zip(piece['offset'], piece['lame_drop'][i])]
        # Positive overlap lifts the next plate along its local outward normal.
        item['offset_surface'] += piece['overlap'][i]
        result.append(plate(item, spec, body))
    return result


def curve(piece, spec):
    data = bpy.data.curves.new(piece['id'], 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = piece['resolution']
    data.bevel_depth = piece['radius']
    data.bevel_resolution = piece['bevel_resolution']
    data.use_fill_caps = True
    spline = data.splines.new(piece['spline'])
    points = piece['path']
    if piece['spline'] == 'BEZIER':
        spline.bezier_points.add(len(points) - 1)
        for p, xyz, radius in zip(spline.bezier_points, points, piece['taper']):
            p.co = xyz
            p.handle_left_type = p.handle_right_type = 'AUTO'
            p.radius = radius
    else:
        spline.points.add(len(points) - 1)
        for p, xyz, radius in zip(spline.points, points, piece['taper']):
            p.co = (*xyz, 1)
            p.radius = radius
    spline.use_cyclic_u = piece['closed']
    obj = bpy.data.objects.new(piece['id'], data)
    bpy.context.scene.collection.objects.link(obj)
    place(obj, piece, spec)
    if piece.get('conforming'):
        from .conformance import conform_curve
        conform_curve(obj, piece, bpy.data.objects['posed_body'])
    return obj


def tube(piece, spec):
    from .tube import tube_mesh
    vertices, faces = tube_mesh(piece['path'], [piece['radius'] * t for t in piece['taper']],
                                piece['wall'], piece['sides'], piece.get('radial_profile'))
    obj = place(mesh_object(piece['id'], vertices, faces), piece, spec)
    if piece.get('smooth_surface'):
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def sculpted_blade(piece, spec):
    obj = place(mesh_object(piece['id'], piece['vertices'], piece['faces']), piece, spec)
    if piece.get('root_joint'):
        from .sculpted_blade import seat_root
        seat_root(obj, piece, spec)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def rigid_shell(piece, spec):
    obj = place(mesh_object(piece['id'], piece['vertices'], piece['faces']), piece, spec)
    import bmesh
    topology = bmesh.new()
    topology.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(topology, faces=list(topology.faces))
    topology.to_mesh(obj.data)
    topology.free()
    obj['rig_joint'] = piece['rig_joint']
    if piece.get('clearance_parts'):
        from .rigid_clearance import fit
        fit(obj, piece, spec)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def crystal(piece, spec):
    path = [Vector(v) for v in piece['path']]
    if piece.get('continues'):
        source = next(p for p in spec['pieces'] if p['id'] == piece['continues'])
        source_obj = next(o for o in bpy.context.scene.objects if o.get('piece_id') == piece['continues'])
        marker = place(mesh_object(piece['id'] + '_frame', [], []), piece, spec)
        bpy.context.view_layer.update()
        transform = marker.matrix_world.inverted() @ source_obj.matrix_world
        path = [transform @ Vector(v) for v in source['path']]
        bpy.data.objects.remove(marker, do_unlink=True)
        direction = (path[-1] - path[-2]).normalized()
        path = [path[-1], path[-1] + direction * piece['length']]
    elif piece.get('continues_bone'):
        bone = bpy.data.objects['maquette_armature'].pose.bones[piece['continues_bone']]
        marker = place(mesh_object(piece['id'] + '_frame', [], []), piece, spec)
        bpy.context.view_layer.update()
        inverse = marker.matrix_world.inverted()
        origin = inverse @ bone.tail
        direction = (inverse @ bone.tail - inverse @ bone.head).normalized()
        path = [origin, origin + direction * piece['length']]
        bpy.data.objects.remove(marker, do_unlink=True)
    lengths = [(b - a).length for a, b in zip(path, path[1:])]
    total = sum(lengths)
    if total <= 0 or any(length <= 0 for length in lengths):
        raise ValueError('Crystal path needs nonzero segments')
    def frame(t):
        distance = t * total
        for i, length in enumerate(lengths):
            if distance <= length or i == len(lengths) - 1:
                direction = (path[i + 1] - path[i]).normalized()
                centre = path[0] + (path[i] - path[0] + direction * distance) * (piece['length'] / total)
                return centre, Vector((0, 0, 1)).rotation_difference(direction)
            distance -= length
    profile = piece['width_profile']
    sides = piece['sides']
    vertices, faces = [], []
    rng = random.Random(piece['jag']['seed'])
    if piece['jag']['count'] > sides * (len(profile) - 1):
        raise ValueError('More crystal jags than non-tip profile vertices')
    jags = set(piece['jag']['indices'] if 'indices' in piece['jag'] else
               rng.sample(range(sides * (len(profile) - 1)), piece['jag']['count']))
    for row, (t, width) in enumerate(profile[:-1]):
        centre, axis = frame(t)
        for j in range(sides):
            radius = width + (piece['jag']['depth'] if row * sides + j in jags else 0)
            angle = math.tau * j / sides
            vertices.append(centre + axis @ Vector((radius * math.cos(angle), radius * math.sin(angle), 0)))
    faces.append(tuple(reversed(range(sides))))
    for row in range(len(profile) - 2):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((row * sides + j, row * sides + k, (row + 1) * sides + k, (row + 1) * sides + j))
    tip = len(vertices)
    vertices.append(frame(1)[0])
    for j in range(sides):
        faces.append(((len(profile) - 2) * sides + j, (len(profile) - 2) * sides + (j + 1) % sides, tip))
    return place(mesh_object(piece['id'], vertices, faces), piece, spec)


def gem(piece, spec):
    n = piece['sides']
    vertices = [(0, 0, piece['length'] / 2), (0, 0, -piece['length'] / 2)]
    vertices += [(piece['width'] / 2 * math.cos(math.tau * j / n),
                  piece['depth'] / 2 * math.sin(math.tau * j / n), 0) for j in range(n)]
    faces = []
    for j in range(n):
        k = (j + 1) % n
        faces += [(0, 2 + j, 2 + k), (1, 2 + k, 2 + j)]
    obj = place(mesh_object(piece['id'], vertices, faces), piece, spec)
    if piece.get('seat_on'):
        from .conformance import surface_projector
        bpy.context.view_layer.update()
        # Use the exact captured surface. Hidden editable source objects may
        # stop evaluating their modifier stack in Blender's viewport graph.
        target = bpy.data.objects.get(piece['seat_on'] + '_render') or bpy.data.objects[piece['seat_on']]
        targets = [target] + [bpy.data.objects[name + '_render'] for name in piece.get('seat_contacts', [])]
        seat_vertices, seat_faces = [], []
        for surface in targets:
            start = len(seat_vertices)
            seat_vertices.extend(list(surface.matrix_world @ v.co) for v in surface.data.vertices)
            seat_faces.extend(tuple(i + start for i in p.vertices) for p in surface.data.polygons)
        proxy = mesh_object('gem_seat', seat_vertices, seat_faces)
        direction = obj.matrix_world.to_quaternion() @ Vector((0, 1, 0))
        project = surface_projector(proxy, direction)
        # A gem is a rigid bipyramid, not a cloth patch. Seat the complete
        # solid above the highest contacted point; independent vertex wraps
        # bend its faces through a ridged breastplate after the body turns.
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        samples = list(points)
        for face in obj.data.polygons:
            pts = [points[i] for i in face.vertices]
            samples.append(sum(pts, Vector()) / len(pts))
            samples.extend((a + b) / 2 for a, b in zip(pts, pts[1:] + pts[:1]))
        distance = max((world - project(world)[0]).dot(direction) for world in samples)
        obj.location -= direction * (distance + piece['seat_offset'])
        bpy.data.objects.remove(proxy, do_unlink=True)
    return obj

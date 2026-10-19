"""Native surface projection for armour; design dimensions live in the spec."""
import json
import math

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from mathutils.geometry import delaunay_2d_cdt, intersect_point_tri_2d
from .contract import BUILD_DEFAULTS

PROJECT_DEFAULTS = {'fallback_neighbours': 16, 'silhouette_slack': .005,
                    'bevel_miter_distance_bound': 3}


def body_tree(body):
    return BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices],
                               [tuple(p.vertices) for p in body.data.polygons])


def regional_body(body, piece):
    if not piece.get('body_regions') and not piece.get('contact_pieces') and not piece.get('contact_hull'):
        return body
    name = ('contact_' + piece['id'] if piece.get('contact_hull') else
            'contact_' + '_'.join(piece.get('body_regions', []) + piece.get('contact_pieces', [])))
    if name in bpy.data.objects:
        return bpy.data.objects[name]
    from .pieces import mesh_object
    owners = json.loads(body['face_owners'])
    faces = [tuple(p.vertices) for p, owner in zip(body.data.polygons, owners)
             if not piece.get('body_regions') or owner in piece['body_regions']]
    vertices = [tuple(body.matrix_world @ v.co) for v in body.data.vertices]
    for identifier in piece.get('contact_pieces', []):
        source = bpy.data.objects[identifier + '_render']
        count = len(vertices)
        vertices.extend(tuple(source.matrix_world @ v.co) for v in source.data.vertices)
        faces.extend(tuple(i + count for i in p.vertices) for p in source.data.polygons)
    obj = mesh_object(name, vertices, faces)
    if piece.get('contact_hull'):
        import bmesh
        mesh = bmesh.new()
        used = {i for face in faces for i in face}
        bounds = piece.get('contact_height_fraction')
        if bounds:
            low=min(vertices[i][2] for i in used); high=max(vertices[i][2] for i in used)
            piece={**piece,'contact_min_z':low+(high-low)*bounds[0],'contact_max_z':low+(high-low)*bounds[1]}
        for i in sorted(used):
            if piece.get('contact_min_z', -math.inf) <= vertices[i][2] <= piece.get('contact_max_z', math.inf):
                mesh.verts.new(vertices[i])
        hull = bmesh.ops.convex_hull(mesh, input=list(mesh.verts))
        bmesh.ops.delete(mesh, geom=list(set(hull['geom_interior'] + hull['geom_unused'])), context='VERTS')
        mesh.to_mesh(obj.data)
        mesh.free()
    obj.hide_render = True
    obj.hide_set(True)
    obj['native_source'] = True
    return obj


def surface_point(tree, world, direction=None, fallback=None):
    if direction is not None:
        hit, normal, _, _ = tree.ray_cast(world, direction)
        if hit is not None:
            return hit, normal
    hit, normal, _, _ = tree.find_nearest(world if fallback is None else fallback)
    if hit is None:
        raise ValueError('No body surface for armour')
    return hit, normal


def dense_outline(outline, spacing, ridge=None):
    coords = [Vector(p) for p in outline]
    count = len(coords)
    edges = [(i, (i + 1) % count) for i in range(count)]
    # Keep original corner indices, then sample both edges and the interior.
    for i in range(count):
        a, b = coords[i], coords[(i + 1) % count]
        steps = math.ceil((b - a).length / spacing)
        coords.extend(a.lerp(b, j / steps) for j in range(1, steps))
    base, _, faces, _, _, _ = delaunay_2d_cdt(coords, edges, [list(range(count))], 1, BUILD_DEFAULTS['triangulation_epsilon'])
    triangles = [[base[i] for i in face] for face in faces]
    x0, z0 = map(min, zip(*outline))
    x1, z1 = map(max, zip(*outline))
    for ix in range(1, math.ceil((x1 - x0) / spacing)):
        for iz in range(1, math.ceil((z1 - z0) / spacing)):
            p = Vector((x0 + ix * spacing, z0 + iz * spacing))
            if any(len(t) == 3 and intersect_point_tri_2d(p, *t) for t in triangles):
                coords.append(p)
    if ridge:
        start = len(coords)
        coords.extend(Vector(p) for p in ridge['line'])
        edges.append((start, start + 1))
    coords, _, faces, origins, _, _ = delaunay_2d_cdt(coords, edges, [list(range(count))], 1, BUILD_DEFAULTS['triangulation_epsilon'])
    return [(p.x, 0, p.y) for p in coords], faces, origins


def surface_projector(body, direction):
    tree = body_tree(body)
    extent = sum(Vector(body.dimensions))
    used = sorted({i for p in body.data.polygons for i in p.vertices})
    points = [body.matrix_world @ body.data.vertices[i].co for i in used]
    projected = KDTree(len(points))
    for i, p in enumerate(points):
        projected.insert(p - direction * p.dot(direction), i)
    projected.balance()
    def project(world):
        hit, normal, _, _ = tree.ray_cast(world - direction * extent, direction)
        if hit is None:
            nearest = projected.find_n(world - direction * world.dot(direction), min(len(points), PROJECT_DEFAULTS['fallback_neighbours']))
            distance = nearest[0][2]
            index = min((i for _, i, d in nearest if d <= distance + PROJECT_DEFAULTS['silhouette_slack']),
                        key=lambda i: points[i].dot(direction))
            fallback = world + direction * (points[index] - world).dot(direction)
            hit, normal = surface_point(tree, fallback)
        return hit, normal
    return project


def max_miter(outline):
    """Exact sharp-corner extension bound; acute plate tips exceed 3 widths."""
    result = 1.0
    for i, p in enumerate(outline):
        a = (Vector(outline[i - 1]) - Vector(p)).normalized()
        b = (Vector(outline[(i + 1) % len(outline)]) - Vector(p)).normalized()
        half = math.acos(max(-1, min(1, a.dot(b)))) / 2
        result = max(result, 1 / max(math.sin(half), BUILD_DEFAULTS['collision_epsilon']))
    return max(PROJECT_DEFAULTS['bevel_miter_distance_bound'], result)


def conform_plate(obj, piece, body, origins):
    bpy.context.view_layer.update()
    inverse = obj.matrix_world.inverted()
    direction = obj.matrix_world.to_quaternion() @ Vector((0, 1, 0))
    # Start rays on the camera side of the complete anatomy bounding box.
    project = surface_projector(body, direction)
    for vertex in obj.data.vertices:
        world = obj.matrix_world @ vertex.co
        hit, normal = project(world)
        vertex.co = inverse @ (hit + normal * piece['offset_surface'])
    obj.data.update()
    obj['conforming'] = True
    obj['surface_offset'] = piece['offset_surface']
    # Solidify and the sharp miter extend beyond the wrapping centre surface.
    obj['surface_allowance'] = (piece['offset_surface'] + piece['thick'] / 2 +
        (piece.get('ridge') or {}).get('height', 0) + max_miter(piece['outline']) * piece['bevel']['width'])
    obj['contact_target'] = body.name
    wrap = obj.modifiers.new('body_conform', 'SHRINKWRAP')
    wrap.target = body
    wrap.wrap_method = 'NEAREST_SURFACEPOINT'
    wrap.wrap_mode = 'OUTSIDE'
    wrap.offset = piece['offset_surface']
    # Corner sharpness is measured after Blender's actual conformance and
    # before thickness/bevel; a clothing contact can select a different nearby
    # triangle than the initial ray projection.
    from .rig import evaluated_mesh
    reference = evaluated_mesh(obj)
    corners = [list(reference.vertices[next(j for j, source in enumerate(origins) if i in source)].co)
               for i in range(len(piece['outline']))]
    obj['conformed_corners'] = json.dumps(corners)
    bpy.data.meshes.remove(reference)
    if piece.get('ridge'):
        a, b = [Vector(p) for p in piece['ridge']['line']]
        axis = b - a
        group = obj.vertex_groups.new(name='centre_ridge')
        # Use the original pattern XZ coordinates, before its surface projection.
        vertices, _, _ = dense_outline(piece['outline'], piece['surface_spacing'], piece['ridge'])
        for i, (x, _, z) in enumerate(vertices):
            p = Vector((x, z))
            t = max(0, min(1, (p - a).dot(axis) / axis.length_squared))
            distance = (p - a.lerp(b, t)).length
            weight = max(0, 1 - distance / piece['ridge']['width'])
            if weight:
                group.add([i], weight, 'REPLACE')
        displace = obj.modifiers.new('raised_centre_ridge', 'DISPLACE')
        displace.direction = 'Y'
        displace.strength = -piece['ridge']['height']
        displace.mid_level = 0
        displace.vertex_group = group.name


def conform_curve(obj, piece, body):
    bpy.context.view_layer.update()
    inverse = obj.matrix_world.inverted()
    tree = body_tree(bpy.data.objects[piece['conform_target']] if piece.get('conform_target') else body)
    direction = Vector(piece['conform_direction']) if piece.get('conform_direction') else None
    from .curve_projection import project_spline
    def project(co, radius):
        world = obj.matrix_world @ Vector(co)
        hit, normal = surface_point(tree, world, direction)
        return tuple(inverse @ (hit + normal * (piece['radius'] * radius + piece['offset_surface'])))
    for spline in obj.data.splines:
        project_spline(spline, piece['taper'], project)
    obj['conforming'] = True
    obj['surface_offset'] = piece['offset_surface']
    obj['surface_allowance'] = 2 * piece['radius'] + piece['offset_surface']
    if piece.get('conform_target'):
        obj['contact_target'] = piece['conform_target']

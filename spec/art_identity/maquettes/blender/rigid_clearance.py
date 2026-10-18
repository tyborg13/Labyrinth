"""Native rigid-shell cutouts around solved cloth, with a real clearance skin.

Convex garment envelopes plus a cube Minkowski support contain every cloth
triangle with clearance. Exact native booleans fit each closed plate around
those envelopes; the solved cloth and measured exposed spike tips stay put.
"""
import json
from itertools import product

CLEARANCE_DEFAULTS = {'clearance_in_voxels': 1}


def padded_points(points, clearance):
    return [[p[a] + d[a] for a in range(3)] for p in points
            for d in product((-clearance, clearance), repeat=3)]


def components(vertices, edges):
    neighbours = {i: set() for i in range(vertices)}
    for a, b in edges:
        neighbours[a].add(b); neighbours[b].add(a)
    remaining, result = set(neighbours), []
    while remaining:
        selected, pending = set(), [min(remaining)]
        while pending:
            i = pending.pop()
            if i not in selected:
                selected.add(i); pending.extend(sorted(neighbours[i] - selected))
        remaining -= selected
        result.append(sorted(selected))
    return result


def hull(points):
    import bmesh
    mesh = bmesh.new()
    for point in points:
        mesh.verts.new(point)
    bmesh.ops.convex_hull(mesh, input=list(mesh.verts), use_existing_faces=False)
    bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
    used = sorted({v for f in mesh.faces for v in f.verts}, key=lambda v: tuple(v.co))
    index = {v: i for i, v in enumerate(used)}
    vertices = [list(v.co) for v in used]
    faces = []
    for face in mesh.faces:
        ring = [index[v] for v in face.verts]
        start = ring.index(min(ring))
        faces.append(ring[start:] + ring[:start])
    faces.sort()
    mesh.free()
    return vertices, faces


def fit(obj, piece, spec):
    import bpy
    import bmesh
    from .pieces import mesh_object
    from .rig import active
    from .drape_collision import COLLIDER_DEFAULTS
    targets = piece['clearance_parts']
    clearance = max(p['collision_margin'] for p in spec['pieces'] if p['id'] in targets) + COLLIDER_DEFAULTS['voxel_size'] * CLEARANCE_DEFAULTS['clearance_in_voxels']
    tools = []
    for name in targets:
        source = bpy.data.objects[name + '_render']
        points = [list(source.matrix_world @ v.co) for v in source.data.vertices]
        vertices, _ = hull(points)
        vertices, faces = hull(padded_points(vertices, clearance))
        tool = mesh_object(name + '_rigid_clearance', vertices, faces)
        tool['native_source'] = True; tool.hide_render = True
        tools.append(tool)
    source_groups = components(len(obj.data.vertices), [list(e.vertices) for e in obj.data.edges])
    vertices, faces, retained = [], [], []
    for n, indices in enumerate(source_groups):
        selected = set(indices); index = {old: i for i, old in enumerate(indices)}
        original_faces = [[index[i] for i in f.vertices] for f in obj.data.polygons if set(f.vertices) <= selected]
        plate = mesh_object(piece['id'] + '_clearance_plate_' + str(n), [list(obj.data.vertices[i].co) for i in indices], original_faces)
        for tool in tools:
            active(plate)
            modifier = plate.modifiers.new('native_clearance', 'BOOLEAN')
            modifier.operation = 'DIFFERENCE'; modifier.solver = 'EXACT'; modifier.object = tool
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        topology = bmesh.new(); topology.from_mesh(plate.data)
        bmesh.ops.recalc_face_normals(topology, faces=list(topology.faces))
        topology.to_mesh(plate.data); topology.free()
        count = len(vertices)
        vertices.extend(list(v.co) for v in plate.data.vertices)
        faces.extend([i + count for i in f.vertices] for f in plate.data.polygons)
        retained.append(len(plate.data.polygons))
        bpy.data.objects.remove(plate, do_unlink=True)
    old = obj.data
    mesh = bpy.data.meshes.new(piece['id'] + '_fitted_clearance')
    mesh.from_pydata(vertices, [], faces); mesh.update(); obj.data = mesh
    bpy.data.meshes.remove(old)
    for tool in tools:
        bpy.data.objects.remove(tool, do_unlink=True)
    obj['rigid_clearance_report'] = json.dumps({'targets': targets, 'source_closed_plates': len(source_groups),
        'retained_faces_per_plate': retained, 'clearance': clearance, 'cloth_unchanged': True,
        'method': 'Native exact boolean difference against expanded convex garment envelopes'})

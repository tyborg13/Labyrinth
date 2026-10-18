"""Fitted armhole seams in regular sewn cloth grids, never rigid garment shells."""
from collections import Counter


def cut_pattern(faces, blocked, pins):
    old_edges = Counter(tuple(sorted((a, b))) for f in faces for a, b in zip(f, f[1:] + f[:1]))
    kept = [f for i, f in enumerate(faces) if i not in blocked]
    edges = Counter(tuple(sorted((a, b))) for f in kept for a, b in zip(f, f[1:] + f[:1]))
    used = {i for f in kept for i in f}
    seam = {i for edge, count in edges.items() if count == 1 and old_edges[edge] == 2 for i in edge}
    return kept, sorted((set(pins) & used) | seam)


def fitted_armholes(obj, body, piece, pins):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from .cloth_contacts import inside
    from .conformance import body_tree, regional_body
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    faces = [list(p.vertices) for p in obj.data.polygons]
    surface = BVHTree.FromPolygons(points, faces)
    blocked = set()
    for region in piece['drape']['cutout_regions']:
        support = regional_body(body, {'id': 'armhole_' + piece['id'] + '_' + region,
            'body_regions': [region], 'contact_hull': True})
        tree = body_tree(support)
        blocked.update(i for i, _ in surface.overlap(tree))
        for i, face in enumerate(faces):
            for p in [points[j] for j in face] + [sum((points[j] for j in face), Vector()) / len(face)]:
                near, normal, _, distance = tree.find_nearest(p)
                if distance < piece['drape'].get('armhole_clearance', 0) or ((p - near).dot(normal) < 0 and inside(tree, p)):
                    blocked.add(i)
                    break
    if 'cutout_max_row' in piece['drape']:
        blocked = {i for i in blocked if min(faces[i]) // piece['pattern']['columns'] < piece['drape']['cutout_max_row']}
    faces, pins = cut_pattern(faces, blocked, pins)
    if not faces:
        raise ValueError('Armhole fit removed all fabric: ' + piece['id'])
    old = obj.data
    mesh = bpy.data.meshes.new(piece['id'] + '_sewn')
    mesh.from_pydata([list(v.co) for v in old.vertices], [], faces)
    mesh.update()
    obj.data = mesh
    bpy.data.meshes.remove(old)
    print('CLOTH_ARMHOLES: ' + piece['id'] + '; removed_faces=' + str(len(blocked)), flush=True)
    return pins

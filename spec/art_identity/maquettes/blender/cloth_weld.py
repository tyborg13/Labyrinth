"""Remove subpixel coincident rest edges before the native cloth solver."""
import bmesh
from mathutils import Vector
from mathutils.kdtree import KDTree


def weld(obj, pins, targets, tolerance):
    original = {i: obj.data.vertices[i].co.copy() for i in pins}
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=tolerance)
    bmesh.ops.dissolve_degenerate(mesh, edges=list(mesh.edges), dist=tolerance)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if not v.link_faces], context='VERTS')
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    tree = KDTree(len(obj.data.vertices))
    for v in obj.data.vertices:
        tree.insert(v.co, v.index)
    tree.balance()
    mapped, grouped = set(), {}
    for old, point in original.items():
        _, index, distance = tree.find(point)
        if distance > tolerance:
            continue  # A zero-area crown face can leave no physical fabric.
        mapped.add(index)
        if old in targets:
            grouped.setdefault(index, []).append(targets[old])
    result = {i: sum(points, Vector()) / len(points) for i, points in grouped.items()}
    return sorted(mapped), result

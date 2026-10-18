"""Clear cloth contacts with minimum bidirectional front-ray displacements."""
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from .cloth_contacts import inside, mesh_payload
from .contract import BUILD_DEFAULTS
from .floor_contact import FLOOR_DEFAULTS
from ..raster import camera

RAY_CONTACT_DEFAULTS = {'passes': 128, 'ray_passes': 24, 'numerical_epsilon_m': 1e-8}


def signed_distance(tree, point):
    near, normal, _, distance = tree.find_nearest(point)
    return -distance if (point - near).dot(normal) < 0 and inside(tree, point) else distance


def first_clear(tree, point, direction, margin, bound):
    from .ray_search import first_clear as search
    return search(lambda length: signed_distance(tree, point + direction * length), margin, bound)


def minimum_clear(tree, point, ray, margin, bound):
    distances = [first_clear(tree, point, direction, margin, bound) for direction in (ray, -ray)]
    available = [(distance, sign) for distance, sign in zip(distances, (1, -1)) if distance is not None]
    return min(available)[0] * min(available)[1] if available else None


def intersections(a, b):
    """Segment/triangle intersection points from both edge sets."""
    result = []
    for triangle, other in ((a, b), (b, a)):
        tree = BVHTree.FromPolygons(other, [list(range(len(other)))])
        for p, q in zip(triangle, triangle[1:] + triangle[:1]):
            direction = q - p
            if direction.length:
                hit, _, _, _ = tree.ray_cast(p, direction.normalized(), direction.length)
                if hit is not None:
                    result.append(hit)
    return result


def clear(spec, cloth, body, margin, floor_vertices=()):
    matrix, _, basis, _ = camera(spec, 'front')
    ray = Vector(np.linalg.solve(matrix[:3, :3], basis[2])).normalized()
    payload = mesh_payload(body)
    body_points = [Vector(point) for point in payload['vertices']]
    body_faces = payload['faces']
    # Use exactly the same native polygons and BVH tessellation as the gate.
    tree = BVHTree.FromPolygons(body_points, body_faces)
    from .conformance import regional_body, body_tree
    region = regional_body(body, {'id': 'floor_far_leg', 'body_regions': ['skirt_far', 'foot_far'],
                                  'contact_hull': True})
    contact_tree = body_tree(region)
    import json
    body_owners = json.loads(body['face_owners'])
    bound = (Vector(tuple(max(p[i] for p in body_points) for i in range(3))) -
             Vector(tuple(min(p[i] for p in body_points) for i in range(3)))).length + margin
    inverse = cloth.matrix_world.inverted()
    original = [cloth.matrix_world @ vertex.co for vertex in cloth.data.vertices]
    faces = [list(face.vertices) for face in cloth.data.polygons]
    if any(len(face) != 3 for face in faces):
        raise ValueError('Front-ray contact correction requires fixed evaluated triangles')
    floor_vertices = set(floor_vertices)
    normal_matrix = cloth.matrix_world.to_3x3().inverted().transposed()
    floor_limit = FLOOR_DEFAULTS['maximum_lift_m'] - BUILD_DEFAULTS['collision_epsilon']
    normal_fallbacks = set()
    history = []
    target = margin + BUILD_DEFAULTS['collision_epsilon']
    for iteration in range(RAY_CONTACT_DEFAULTS['passes']):
        points = [cloth.matrix_world @ vertex.co for vertex in cloth.data.vertices]
        surface = BVHTree.FromPolygons(points, faces, all_triangles=True)
        overlaps = sorted(surface.overlap(tree))
        constraints = []
        # Same samples as collision_report, plus exact intersection witnesses.
        for index, point in enumerate(points):
            if signed_distance(tree, point) < margin:
                constraints.append(([index], [1.], point))
        for face in faces:
            samples = [([1/3, 1/3, 1/3], sum((points[i] for i in face), Vector()) / 3)]
            for a, b in ((0, 1), (1, 2), (2, 0)):
                weights = [0., 0., 0.]
                weights[a] = weights[b] = .5
                samples.append((weights, (points[face[a]] + points[face[b]]) / 2))
            for weights, point in samples:
                if signed_distance(tree, point) < margin:
                    constraints.append((face, weights, point))
        for cloth_index, body_index in overlaps:
            face = faces[cloth_index]
            triangle = [points[i] for i in face]
            coordinates = np.vstack((np.array(triangle).T, np.ones(3)))
            for point in intersections(triangle, [body_points[i] for i in body_faces[body_index]]):
                weights = np.linalg.lstsq(coordinates, np.r_[point, 1.], rcond=None)[0]
                constraints.append((face, weights, point))
        history.append({'pass': iteration, 'constraints': len(constraints), 'intersecting_face_pairs': len(overlaps)})
        print('RAY_CONTACT_PASS: ' + str(history[-1]), flush=True)
        if not constraints and not overlaps:
            break
        changes, counts = {}, {}
        for indices, weights, point in constraints:
            selected = [(index, weight) for index, weight in zip(indices, weights)
                        if abs(weight) > RAY_CONTACT_DEFAULTS['numerical_epsilon_m']]
            denominator = sum(weight * weight for _, weight in selected)
            if iteration < RAY_CONTACT_DEFAULTS['ray_passes']:
                delta = minimum_clear(tree, point, ray, target, bound)
                if delta is None:
                    continue
                # A floor anchor has no nonzero height-preserving ray move.
                # Do not redistribute its correction into tiny neighbour weights.
                updates = [(index, ray * (delta * weight / denominator))
                           for index, weight in selected if index not in floor_vertices]
            else:
                # Ray-only contacts remaining with anchored floor points are
                # corrected by the minimum outward normal of the collision.
                _, _, owner_face, _ = tree.find_nearest(point)
                normal_tree = contact_tree if body_owners[owner_face] in ('skirt_far', 'foot_far') else tree
                near, normal, _, distance = normal_tree.find_nearest(point)
                signed = signed_distance(normal_tree, point)
                direction = (near - point).normalized() if signed < 0 else (point - near).normalized()
                if distance <= BUILD_DEFAULTS['collision_epsilon']:
                    direction = normal
                correction = direction * (target - signed)
                updates = [(index, correction * (weight / denominator)) for index, weight in selected]
                normal_fallbacks.update(index for index, _ in updates)
            for index, update in updates:
                if index in floor_vertices and points[index].z + update.z - original[index].z > floor_limit:
                    continue
                changes[index] = changes.get(index, Vector()) + update
                counts[index] = counts.get(index, 0) + 1
        for index, change in changes.items():
            cloth.data.vertices[index].co = inverse @ (points[index] + change / counts[index])
        cloth.data.update()
    after = [cloth.matrix_world @ vertex.co for vertex in cloth.data.vertices]
    return {'method': 'nearest bidirectional front-ray exit; barycentric contact constraints',
            'normal_fallback_vertices': sorted(normal_fallbacks),
            'normal_fallback_reason': 'ray-only contact constraints cannot clear while floor anchors remain planted; minimum outward regional contact normal for the remaining constraints; full native anatomy is still the acceptance surface', 'history': history,
            'maximum_displacement_m': max((a - b).length for a, b in zip(original, after))}

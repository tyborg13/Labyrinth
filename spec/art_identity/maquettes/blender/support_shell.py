"""Place a shaped attachment outside its native anatomical support as one mesh."""
import json
import numpy as np


def clearance_translation(points, intersections, direction, clearance):
    # Preserve Blender's native float32 operations. Converting its Vectors to
    # NumPy here would subtly change an otherwise identical regeneration.
    if not hasattr(direction, 'dot'):
        direction = np.asarray(direction, float)
    shift = max([0.] + [float((hit - point).dot(direction)) + clearance
                        for point, hit in zip(points, intersections) if hit is not None])
    translation = direction * shift
    return translation.tolist() if isinstance(translation, np.ndarray) else translation


def seat(obj, piece, spec):
    import bpy
    from mathutils import Vector
    from .conformance import regional_body, body_tree
    from ..raster import camera
    support = regional_body(bpy.data.objects['posed_body'],
                            {'id': piece['id'] + '_support', 'body_regions': piece['support_regions']})
    tree = body_tree(support)
    matrix, _, basis, _ = camera(spec, piece['support_side'])
    direction = Vector(basis[2] @ matrix[:3, :3]).normalized()
    clearance = spec['armature']['collision_margin']
    points, intersections = [], []
    for vertex in obj.data.vertices:
        point = obj.matrix_world @ vertex.co
        origin = point + direction * spec['ortho_scale']
        hit, _, _, _ = tree.ray_cast(origin, -direction)
        points.append(point)
        intersections.append(hit)
    translation = Vector(clearance_translation(points, intersections, direction, clearance))
    shift = translation.length
    delta = obj.matrix_world.inverted().to_3x3() @ translation
    for vertex in obj.data.vertices:
        vertex.co += delta
    obj.data.update()
    obj['support_seating'] = json.dumps({'side': piece['support_side'], 'shift_m': shift,
        'clearance_m': clearance, 'regions': piece['support_regions'], 'rigid_shape_preserved': True})

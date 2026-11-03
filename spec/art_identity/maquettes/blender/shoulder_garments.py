"""Recipe-owned far-shoulder attachment motion, after native cloth solving.

The accepted pose and solved fold pattern are the inputs. A translation field
is one at the far attachment and zero at the near side and remote edge. The
field's bounds come from the source surface, not a new garment measurement.
"""
import json
import numpy as np

MOTION_DEFAULTS = {'epsilon': 1e-10, 'revision': 3}


def weights(points, near, far, mode, midpoint=None, roots=None, root_radius=0, head_floor=None):
    points, near, far = (np.asarray(x, float) for x in (points, near, far))
    if mode == 'root':
        if roots is None:
            raise ValueError('Root attachment motion requires the native cloth pin positions')
        distance = np.linalg.norm(points[:, None, :] - np.asarray(roots)[None, :, :], axis=2).min(axis=1)
        distance = np.maximum(distance - root_radius, 0)
        result = 1 - distance / max(distance.max(), MOTION_DEFAULTS['epsilon'])
    elif mode in ('far_top', 'far_skirt'):
        midpoint = np.asarray(midpoint if midpoint is not None else (near + far) / 2)
        axis = np.cross([1., 0, 0], [0., 0, 1.])
        if (far - midpoint) @ axis < 0:
            axis = -axis
        side = np.clip((points - midpoint) @ axis / ((far - midpoint) @ axis), 0, 1)
        if mode == 'far_skirt':
            if head_floor is None or head_floor <= far[2]:
                raise ValueError('Shoulder skirt requires the native skull lower boundary')
            top = np.clip((head_floor - points[:, 2]) / (head_floor - far[2]), 0, 1)
        else:
            low = points[:, 2].min()
            top = np.clip((points[:, 2] - low) / max(far[2] - low, MOTION_DEFAULTS['epsilon']), 0, 1)
        result = side * top
    elif mode == 'far_side':
        midpoint = np.asarray(midpoint if midpoint is not None else (near + far) / 2)
        axis = np.cross([1., 0, 0], [0., 0, 1.])
        if (far - midpoint) @ axis < 0:
            axis = -axis
        result = np.clip((points - midpoint) @ axis / ((far - midpoint) @ axis), 0, 1)
    else:
        raise ValueError('Unknown shoulder attachment field: ' + mode)
    # Smooth at both fixed and translated boundaries without changing them.
    return result * result * (3 - 2 * result)


def apply(spec, body):
    import bpy
    from mathutils import Vector
    from .contract import BUILD_DEFAULTS
    from .ownership import uses_body_side_ownership, cloak_owners, ARMATURE_UP_AXIS
    from .shoulder_motion_audit import audit

    config = spec.get('shoulder_garment_motion')
    if not config:
        return {}
    old = spec['source_fit_joints']
    near, far = old['shoulder_near'], old['shoulder_far']
    delta = np.subtract(spec['joints']['shoulder_far'], far)
    reports = {}
    for name, mode in config.items():
        frozen = bpy.data.objects[name + '_render']
        source = bpy.data.objects.get(name)
        points = np.array([list(frozen.matrix_world @ v.co) for v in frozen.data.vertices])
        midpoint = (np.asarray(spec['joints']['shoulder_near']) + spec['joints']['shoulder_far']) / 2
        piece = next(p for p in spec['pieces'] if p['id'] == name)
        roots = json.loads(frozen['shoulder_attachment_roots']) if mode == 'root' else None
        head_floor = json.loads(frozen['rounded_hood_report'])['head_bounds'][0][2] if mode == 'far_skirt' else None
        influence = weights(points, near, far, mode, midpoint, roots, piece.get('thick', 0), head_floor)
        if mode != 'root':
            far_sign = np.sign(far[1] - midpoint[1])
            # Hold complete near-side faces, including their seam vertices.
            # Moving a far corner of a near face would change its silhouette
            # and could silently relabel it across the sagittal plane.
            for face in frozen.data.polygons:
                vertices = points[list(face.vertices)]
                if ((vertices.mean(0)[1] - midpoint[1]) * far_sign <= 0 or
                        (head_floor is not None and vertices[:, 2].max() >= head_floor)):
                    influence[list(face.vertices)] = 0
        renderer_near = set()
        renderer_near_faces = []
        if uses_body_side_ownership(frozen):
            # Rendering labels drapes at the actual torso-bone plane. Protect
            # those complete near faces too, rather than moving a labelled
            # near seam just because it lies beyond the shoulder midpoint.
            rig = bpy.data.objects['maquette_armature']
            spine = next(b for b in spec['armature']['bones'] if b['region'] == 'torso')
            bone = rig.pose.bones[spine['name']]
            inverse = rig.matrix_world.inverted()
            centres = [list(inverse @ Vector(points[list(face.vertices)].mean(0))) for face in frozen.data.polygons]
            owners = cloak_owners(centres, list((bone.head + bone.tail) / 2), rig['posed_forward'],
                                  ARMATURE_UP_AXIS, spec['joints']['shoulder_near'], spec['joints']['shoulder_far'])
            renderer_near = {i for face, owner in zip(frozen.data.polygons, owners) if owner == 'cape_near' for i in face.vertices}
            renderer_near_faces = [list(face.vertices) for face, owner in zip(frozen.data.polygons, owners) if owner == 'cape_near']
            influence[sorted(renderer_near)] = 0
        shifted = points + influence[:, None] * delta
        inverse = frozen.matrix_world.inverted()
        for vertex, point in zip(frozen.data.vertices, shifted):
            vertex.co = inverse @ Vector(point)
        frozen.data.update()
        # Frozen surfaces are the common front/rear capture body. Retain the
        # source field as editable native provenance rather than refitting art.
        if source is not None:
            source['shoulder_attachment_field'] = mode
            source['shoulder_attachment_delta'] = delta.tolist()
        frozen['shoulder_attachment_field'] = mode
        frozen['shoulder_attachment_delta'] = delta.tolist()
        actual = np.array([list(frozen.matrix_world @ v.co) for v in frozen.data.vertices])
        checked = audit(points, actual, [list(face.vertices) for face in frozen.data.polygons],
            near, far, delta, mode, midpoint, roots, piece.get('thick', 0), head_floor,
            renderer_near_faces, BUILD_DEFAULTS['collision_epsilon'])
        reports[name] = {'field': mode, 'delta': delta.tolist(),
            'vertices': len(points), 'fixed_vertices': int((influence == 0).sum()),
            'fully_translated_vertices': int((influence == 1).sum()),
            'renderer_near_fixed_vertices': len(renderer_near),
            'maximum_displacement_m': float(np.linalg.norm(shifted - points, axis=1).max()),
            'fixed_vertex_error_m': checked['remote_vertex_error_m'],
            'head_cover_floor_z': head_floor,
            'independent_audit': checked, 'passed': checked['passed']}
    return reports

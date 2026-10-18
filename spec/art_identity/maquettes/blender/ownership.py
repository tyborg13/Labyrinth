"""Ownership-only gates. These functions never move vertices or camera axes."""
import numpy as np

ARMATURE_UP_AXIS = [0, 0, 1]


def sagittal_normal(torso_midpoint, forward, up, shoulder_near, shoulder_far):
    """Body-space plane normal, oriented toward the named near shoulder."""
    normal = np.cross(np.asarray(forward, float), np.asarray(up, float))
    length = np.linalg.norm(normal)
    if length == 0:
        raise ValueError('Armature forward and up axes cannot be parallel')
    normal /= length
    near = np.dot(np.subtract(shoulder_near, torso_midpoint), normal)
    if near < 0:
        normal = -normal
    if (np.dot(np.subtract(shoulder_near, torso_midpoint), normal) <= 0 or
        np.dot(np.subtract(shoulder_far, torso_midpoint), normal) >= 0):
        raise ValueError('Shoulders must straddle the body sagittal plane')
    return normal


def cloak_owners(centroids, torso_midpoint, forward, up, shoulder_near, shoulder_far):
    normal = sagittal_normal(torso_midpoint, forward, up, shoulder_near, shoulder_far)
    sides = (np.asarray(centroids, float) - torso_midpoint) @ normal
    return ['cape_far' if side < 0 else 'cape_near' for side in sides]


def assign_materials(obj, expected):
    for polygon, owner in zip(obj.data.polygons, expected):
        polygon.material_index = owner


def materials_match(obj, expected):
    return len(obj.data.polygons) == len(expected) and all(
        p.material_index == owner for p, owner in zip(obj.data.polygons, expected))


def weights_match(faces, weights, bone_regions, owners):
    """Independently audit face labels against summed heat-weight winners."""
    if len(faces) != len(owners):
        return False
    for face, owner in zip(faces, owners):
        totals = {}
        for index in face:
            for bone, weight in weights[index].items():
                if bone in bone_regions:
                    region = bone_regions[bone]
                    totals[region] = totals.get(region, 0) + weight
        if not totals or max(totals.values()) <= 0:
            return False
        winner = sorted(totals, key=lambda region: (-totals[region], region))[0]
        if owner != winner:
            return False
    return True


def require_solos(labels, counts):
    missing = [name for name in labels if counts.get(name, 0) <= 0]
    if missing:
        raise ValueError('Required rig labels have empty solos: ' + ', '.join(missing))
def uses_body_side_ownership(obj):
    return 'side_parts' in obj or (obj.get('cloth_kind') == 'cloak' and obj.get('ownership_mode') != 'whole_piece')


def expected_materials(obj, spec, forward):
    """Audit real cloth faces on each body side, including covered anatomy."""
    if 'sewn_parts' in obj:
        attribute = obj.data.attributes.get('sewn_owner')
        if attribute is None or len(attribute.data) != len(obj.data.polygons):
            raise ValueError('Sewn cloth lost its source-face ownership')
        owners = [a.value for a in attribute.data]
        allowed = {list(spec['labels']).index(name) for name in obj['sewn_parts']}
        if any(i not in allowed for i in owners):
            raise ValueError('Sewn cloth has an unregistered source-face owner')
        return owners
    if 'joint_parts' in obj:
        first, joint, last = (np.array(spec['joints'][name], float) for name in obj['joint_chain'])
        before, after = joint - first, last - joint
        normal = before / np.linalg.norm(before) + after / np.linalg.norm(after)
        pair = list(obj['joint_parts'])
        centres = [np.mean([list(obj.matrix_world @ obj.data.vertices[i].co) for i in p.vertices], axis=0)
                   for p in obj.data.polygons]
        return [list(spec['labels']).index(pair[0 if np.dot(p - joint, normal) <= 0 else 1]) for p in centres]
    if not uses_body_side_ownership(obj):
        return [list(spec['labels']).index(obj['part'])] * len(obj.data.polygons)
    midpoint = (np.array(spec['joints']['shoulder_near']) + spec['joints']['shoulder_far']) / 2
    centroids = [np.mean([list(obj.matrix_world @ obj.data.vertices[i].co) for i in p.vertices], axis=0)
                 for p in obj.data.polygons]
    sides = cloak_owners(centroids, midpoint, forward, ARMATURE_UP_AXIS,
                         spec['joints']['shoulder_near'], spec['joints']['shoulder_far'])
    pair = list(obj.get('side_parts', ['cape_near', 'cape_far']))
    return [list(spec['labels']).index(pair[0 if side == 'cape_near' else 1]) for side in sides]

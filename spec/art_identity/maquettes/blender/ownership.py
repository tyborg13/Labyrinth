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

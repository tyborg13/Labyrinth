"""Audit the frozen cloak's body-side split without changing geometry."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

import bpy
from mathutils import Vector

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.ownership import cloak_owners, sagittal_normal, ARMATURE_UP_AXIS


def main(spec_path, blend, output):
    bpy.ops.wm.open_mainfile(filepath=blend)
    spec = board_spec(json.loads(Path(spec_path).read_text()))
    rig = bpy.data.objects['maquette_armature']
    spine = next(b for b in spec['armature']['bones'] if b['region'] == 'torso')
    bone = rig.pose.bones[spine['name']]
    origin = (bone.head + bone.tail) / 2
    forward = list(rig['posed_forward'])
    near, far = (spec['joints']['shoulder_' + side] for side in ('near', 'far'))
    normal = Vector(sagittal_normal(list(origin), forward, ARMATURE_UP_AXIS, near, far))
    inverse = rig.matrix_world.inverted()
    result = {'rule': 'body_sagittal_plane', 'torso_midpoint_body': list(origin),
              'normal_toward_shoulder_near': list(normal), 'pieces': {}}
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or obj.get('native_source') or obj.get('cloth_kind') != 'cloak':
            continue
        vertices = [inverse @ obj.matrix_world @ v.co for v in obj.data.vertices]
        centroids = [sum((vertices[i] for i in p.vertices), Vector()) / len(p.vertices) for p in obj.data.polygons]
        sides = [(point - origin).dot(normal) for point in centroids]
        independently_labelled = ['cape_near' if side >= 0 else 'cape_far' for side in sides]
        native_centres = [list(inverse @ obj.matrix_world @ p.center) for p in obj.data.polygons]
        labels = cloak_owners(native_centres, list(origin), forward, ARMATURE_UP_AXIS, near, far)
        assert labels == independently_labelled, 'Native polygon centre and vertex-centroid ownership differ'
        result['pieces'][obj.name] = {'faces': len(labels), 'near_faces': labels.count('cape_near'),
            'far_faces': labels.count('cape_far'), 'minimum_signed_side': min(sides), 'maximum_signed_side': max(sides),
            'independent_centroid_labels_identical': True}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('CLOAK_BODY_SIDE_AUDIT: PASS; ' + json.dumps(result))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

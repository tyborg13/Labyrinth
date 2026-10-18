"""Native torso mattes prove the body is three-quarter, with a frontal control."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
import numpy as np

from .facing import FACING_DEFAULTS, axis_report


from .torso_reflection import asymmetry, passes_asymmetry


def probe(spec, objects, output, root, cam, capture):
    if spec.get('facing_parts'):
        return probe_mattes(spec, objects, output, root, cam, capture)
    if any(o.get('piece_type') == 'body' and o.get('part') == 'torso' for o in objects):
        return probe_mattes(spec, objects, output, root, cam, capture)
    # A robe legitimately covers the complete chest. Its proof still uses
    # the original heat-weighted torso, without exposing it in delivered clay.
    from .pieces import mesh_object
    body = bpy.data.objects['posed_body']
    owners = json.loads(body['face_owners'])
    faces = [list(p.vertices) for p, owner in zip(body.data.polygons, owners) if owner == 'torso']
    if not faces:
        raise ValueError('Covered torso has no weighted anatomy for facing proof')
    torso = mesh_object('proof_weighted_torso', [list(v.co) for v in body.data.vertices], faces)
    torso['part'], torso['piece_type'] = 'torso', 'body'
    torso.parent = root
    torso.matrix_basis = body.matrix_world.copy()
    objects.append(torso)
    try:
        return probe_mattes(spec, objects, output, root, cam, capture)
    finally:
        objects.remove(torso)
        data = torso.data
        bpy.data.objects.remove(torso, do_unlink=True)
        bpy.data.meshes.remove(data)


def probe_mattes(spec, objects, output, root, cam, capture):
    from bpy_extras.object_utils import world_to_camera_view
    output = Path(output)
    rig = bpy.data.objects['maquette_armature']
    forward = list(rig['posed_forward'])
    report = axis_report(spec, forward)
    original = root.matrix_world.copy()
    names = ({o.name for o in objects if o.get('part') in spec['facing_parts']}
             if spec.get('facing_parts') else
             {o.name for o in objects if o.get('piece_type') == 'body' and o.get('part') == 'torso'})
    if not names:
        raise ValueError('Facing proof requires weighted torso anatomy')
    def take(filename):
        capture('front', 'silhouette', object_names=names)
        path = output / 'front_silhouette.png'
        path.replace(output / filename)
        image = bpy.data.images.load(str(output / filename), check_existing=False)
        mask = np.asarray(image.pixels[:], float).reshape(image.size[1], image.size[0], 4)[::-1, :, 3] >= .5
        bpy.data.images.remove(image)
        line = []
        for name in spec.get('facing_joints', ('torso', 'head')):
            co = world_to_camera_view(bpy.context.scene, cam, root.matrix_world @ Vector(spec['joints'][name]))
            line.append([co.x * mask.shape[1], (1 - co.y) * mask.shape[0]])
        return asymmetry(mask, line)
    report['torso_three_quarter'] = take('front_torso.png')
    pivot = Vector(spec['joints']['torso'])
    # Rotate the evaluated native anatomy into the camera direction: this is
    # a proof-only counterfactual, never a delivered character view.
    angle = math.pi / 4 - math.atan2(forward[1], forward[0])
    turn = Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, 'Z') @ Matrix.Translation(-pivot)
    root.matrix_world = original @ turn
    bpy.context.view_layer.update()
    report['torso_frontal_control'] = take('front_torso_frontal_control.png')
    root.matrix_world = original
    bpy.context.view_layer.update()
    report['torso_asymmetry_passed'] = passes_asymmetry(report['torso_three_quarter'])
    # The control's actual object rotation is also rejected by the axis gate.
    control_forward = turn.to_3x3() @ Vector(forward)
    report['frontal_axis_rejected'] = not axis_report(spec, list(control_forward))['passed']
    report['passed'] = bool(report['passed'] and report['torso_asymmetry_passed'] and report['frontal_axis_rejected'])
    (output / 'facing_report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('BLENDER_FACING: ' + ('PASS' if report['passed'] else 'FAIL'))
    return report

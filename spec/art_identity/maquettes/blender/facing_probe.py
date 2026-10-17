"""Native torso mattes prove the body is three-quarter, with a frontal control."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
import numpy as np

from .facing import FACING_DEFAULTS, axis_report


def asymmetry(mask, centreline):
    a, b = np.asarray(centreline)
    yy, xx = np.indices(mask.shape)
    if abs(b[1] - a[1]) < FACING_DEFAULTS['epsilon']:
        raise ValueError('Cannot project a horizontal torso centreline')
    centre_x = a[0] + (yy - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
    mirror_x = np.rint(2 * centre_x - xx).astype(int)
    valid = (mirror_x >= 0) & (mirror_x < mask.shape[1])
    reflected = mask[yy, np.clip(mirror_x, 0, mask.shape[1] - 1)] & valid
    union = np.count_nonzero(mask | reflected)
    left = int(np.count_nonzero(mask & (xx < centre_x)))
    right = int(np.count_nonzero(mask & (xx >= centre_x)))
    return {'left_area_px': left, 'right_area_px': right,
            'area_imbalance': abs(left - right) / max(left + right, 1),
            'mirror_difference': float(np.count_nonzero(mask ^ reflected) / max(union, 1))}


def probe(spec, objects, output, root, cam, capture):
    from bpy_extras.object_utils import world_to_camera_view
    output = Path(output)
    rig = bpy.data.objects['maquette_armature']
    forward = list(rig['posed_forward'])
    report = axis_report(spec, forward)
    original = root.matrix_world.copy()
    names = {o.name for o in objects if o.get('piece_type') == 'body' and o.get('part') == 'torso'}
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
        for name in ('torso', 'head'):
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
    report['torso_asymmetry_passed'] = report['torso_three_quarter']['mirror_difference'] >= FACING_DEFAULTS['asymmetry_min']
    # The control's actual object rotation is also rejected by the axis gate.
    control_forward = turn.to_3x3() @ Vector(forward)
    report['frontal_axis_rejected'] = not axis_report(spec, list(control_forward))['passed']
    report['passed'] = bool(report['passed'] and report['torso_asymmetry_passed'] and report['frontal_axis_rejected'])
    (output / 'facing_report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('BLENDER_FACING: ' + ('PASS' if report['passed'] else 'FAIL'))
    return report

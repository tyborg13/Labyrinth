"""Inspect saved maquette bounds, collision and corner diagnostics via bridge."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

import bpy

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

INSPECTION_DEFAULTS = {'endpoint_tolerance': 1e-5, 'grip_clearance': .025}


def main(blend, output, spec_path=None):
    bpy.ops.wm.open_mainfile(filepath=blend)
    result = {}
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
        result[obj.name] = {'bounds': [[min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]],
                            'vertices': len(pts), 'render': not obj.hide_render,
                            'part': obj.get('part'), 'cloth': obj.get('collision_report'),
                            'matrix': [list(r) for r in obj.matrix_world]}
    if spec_path:
        from mathutils import Vector
        from spec.art_identity.maquettes.blender.facing import board_spec
        spec = board_spec(json.loads(Path(spec_path).read_text()))
        rig = bpy.data.objects['maquette_armature']
        error = max((getattr(rig.pose.bones[b['name']], field) - Vector(spec['joints'][b[field]])).length
                    for b in spec['armature']['bones'] for field in ('head', 'tail'))
        assert error < INSPECTION_DEFAULTS['endpoint_tolerance'], ('Pose endpoint error', error)
        result['native_joint_validation'] = {'passed': True, 'max_error': error}
        shaft = next((p for p in spec['pieces'] if p['id'] == 'spear_shaft'), None)
        if shaft:
            hand = bpy.data.objects.get('body_hand_far') or bpy.data.objects['posed_body']
            owners = json.loads(hand['face_owners']) if hand.name == 'posed_body' else None
            used = {i for index, face in enumerate(hand.data.polygons)
                    if owners is None or owners[index] == 'hand_far' for i in face.vertices}
            assert used, 'Missing weighted far-hand anatomy'
            source = bpy.data.objects['spear_shaft']
            a, b = [source.matrix_world @ Vector(p) for p in shaft['path']]
            delta = b - a
            distances = []
            for index in used:
                p = hand.matrix_world @ hand.data.vertices[index].co
                u = max(0, min(1, (p - a).dot(delta) / delta.length_squared))
                distances.append((p - (a + u * delta)).length - shaft['radius'])
            distance = min(distances)
            assert distance <= INSPECTION_DEFAULTS['grip_clearance'], ('Far hand is detached from spear', distance)
            result['native_grip_validation'] = {'passed': True, 'surface_distance': distance,
                                               'tolerance': INSPECTION_DEFAULTS['grip_clearance']}
            blade = next(p for p in spec['pieces'] if p['id'] == 'spear_blade')
            crystal = bpy.data.objects['spear_blade_render']
            tip = b + delta.normalized() * blade['length']
            tip_error = min((crystal.matrix_world @ v.co - tip).length for v in crystal.data.vertices)
            assert tip_error < INSPECTION_DEFAULTS['endpoint_tolerance'], ('Spear continuation error', tip_error)
            fraction = blade['length'] / (blade['length'] + delta.length)
            result['native_spear_validation'] = {'passed': True, 'tip_error': tip_error,
                'head_fraction_of_spear': fraction, 'sides': blade['sides'], 'jags': blade['jag']['count']}
    Path(output).write_text(json.dumps(result, indent=2))
    print('BUILD_INSPECTION: PASS')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

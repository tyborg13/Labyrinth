"""Director-run Blender integration; synthetic debug geometry, never creature art.

python3 spec/art_identity/maquettes/blender/bridge_client.py
  spec/art_identity/maquettes/blender/integration.py -- OUT
"""
from copy import deepcopy
import json
import math
from pathlib import Path
import sys
import uuid
sys.dont_write_bytecode = True

import bpy

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.build import build, write
from spec.art_identity.maquettes.blender.cloth import collision_report
from spec.art_identity.maquettes.blender.pieces import mesh_object
from spec.art_identity.maquettes.blender.render import render


# All values below are synthetic test dimensions/physics and proof settings.
TEST_DEFAULTS = {'radius': .2, 'body_z_scale': 4, 'frames': 8,
                 'margin': .001, 'pattern_columns': 16, 'spatial_tolerance': 1e-6}


def check_native_conformance(spec, objects):
    from mathutils import Vector
    from spec.art_identity.maquettes.blender.pieces import plate
    from spec.art_identity.maquettes.blender.rig import evaluated_mesh
    from spec.art_identity.maquettes.blender.contract import mesh_hash
    from spec.art_identity.maquettes.blender.validation import geometry_report
    piece = {'id': 'contact_test', 'type': 'plate', 'part': 'plate', 'at': 'root',
             'offset': [0, -.3, .1], 'rot': [0, 0, 0],
             'outline': [[-.12, -.15], [.12, -.15], [.12, .15], [-.12, .15]],
             'thick': .006, 'bevel': {'width': .002, 'segments': 1, 'angle_limit': .4},
             'conforming': True, 'offset_surface': .008, 'surface_spacing': .03,
             'ridge': {'line': [[0, -.1], [0, .1]], 'height': .006, 'width': .04}}
    candidate = deepcopy(spec)
    candidate['pieces'].append(piece)
    hashes = []
    for _ in range(2):
        source = plate(piece, spec, bpy.data.objects['posed_body'])
        frozen = bpy.data.objects.new('contact_test_frozen', evaluated_mesh(source))
        bpy.context.scene.collection.objects.link(frozen)
        frozen.matrix_world = source.matrix_world.copy()
        for key in source.keys():
            frozen[key] = source[key]
        checks = geometry_report(candidate, objects + [frozen], {})
        assert all(checks.values()), checks
        hashes.append(mesh_hash([list(v.co) for v in frozen.data.vertices],
                                [tuple(p.vertices) for p in frozen.data.polygons]))
        for v in frozen.data.vertices:
            v.co += Vector((0, -.2, 0))
        assert not geometry_report(candidate, objects + [frozen], {})['armour_conforms_to_body'], 'Contact gate missed a floating plate'
        bpy.data.objects.remove(frozen, do_unlink=True)
        bpy.data.objects.remove(source, do_unlink=True)
    assert hashes[0] == hashes[1], 'Conforming plate construction is nondeterministic'


def synthetic_spec():
    joints = {'pelvis': [0, 0, -.6], 'torso': [0, 0, -.1],
              'head': [0, 0, .4], 'tip': [0, 0, .7], 'root': [0, 0, 0]}
    bones = [{'name': name, 'head': name, 'tail': tail, 'parent': parent,
              'region': name, 'scale': [1, 1], 'roll': 0}
             for name, tail, parent in [('pelvis', 'torso', None), ('torso', 'head', 'pelvis'), ('head', 'tip', 'torso')]]
    spec = {'version': 2, 'base': {'asset': 'debug_body', 'matrix': [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]},
            'joints': joints, 'target': [0, 0, 0], 'ortho_scale': 4,
            'labels': {'pelvis': [.1, .1, .8], 'torso': [.8, .1, .1], 'head': [.8, .8, .1],
                       'plate': [.1, .8, .8], 'lames': [.1, .6, .1], 'cloth': [.6, .1, .6],
                       'curve': [.4, .4, .4], 'crystal': [.2, .3, .8], 'gem': [.8, .5, .2]},
            'armature': {'rest_joints': deepcopy(joints), 'bones': bones, 'collision_margin': .001}, 'pieces': []}
    spec['simulation'] = {'gravity': [0, 0, -9.81], 'fps': 24}
    def part(name, piece_type, **kwargs):
        return {'id': name, 'type': piece_type, 'part': name, 'at': 'root', 'offset': [0, 0, 0], 'rot': [0, 0, 0], **kwargs}
    plate = part('plate', 'plate', outline=[[-.2, -.2], [.2, -.2], [.2, .2], [-.2, .2]],
                 thick=.01, bevel={'width': .005, 'segments': 1, 'angle_limit': .5},
                 offset_surface=.01, conform_weights=[0, 0, 0, 0, 0, 0],
                 ridge={'line': [[0, -.15], [0, .15]], 'height': .04})
    plate['offset'] = [.8, 0, 0]
    lames = {**deepcopy(plate), 'id': 'lames', 'type': 'lames', 'part': 'lames', 'count': 3,
             'lame_scale': [[1, 1], [.9, .9], [.8, .8]], 'lame_drop': [[0, 0, 0], [0, 0, -.2], [0, 0, -.4]], 'overlap': [0, .01, .02]}
    lames['offset'] = [-.8, 0, 0]
    n = TEST_DEFAULTS['pattern_columns']
    cloth = part('cloth', 'cloth', kind='collar', pattern={'columns': n, 'closed': True,
                 'pins': list(range(n)), 'rows': [{'centre': [0, 0, .3], 'radii': [.35, .35], 'angles': [0, math.tau]},
                                                 {'centre': [0, 0, .1], 'radii': [.5, .5], 'angles': [0, math.tau]}]},
                 pin_group='test_pins', frames=TEST_DEFAULTS['frames'], stiffness={'quality': 5, 'mass': .3,
                 'tension_stiffness': 15, 'compression_stiffness': 15, 'shear_stiffness': 5, 'bending_stiffness': .5},
                 collision_margin=TEST_DEFAULTS['margin'], self_collision=True, thick=.002, solidify_offset=0,
                 rag={'count': 0, 'depth': 0, 'seed': 1})
    curve = part('curve', 'curve', path=[[0, -.8, -.7], [0, -.8, .5]], spline='POLY', radius=.02,
                 taper=[1, 1], closed=False, resolution=4, bevel_resolution=1)
    curve['offset'] = [.1, .05, 0]
    curve['rot'] = [.1, .2, .3]
    crystal = part('crystal', 'crystal', path=curve['path'], continues='curve', sides=5, length=.4,
                   width_profile=[[0, .04], [.4, .08], [.7, .04], [1, 0]], jag={'count': 6, 'depth': .01, 'seed': 4})
    gem = part('gem', 'gem', sides=4, length=.3, width=.15, depth=.06)
    gem['offset'] = [.5, .5, .6]
    spec['pieces'] = [plate, lames, cloth, curve, crystal, gem]
    return spec


def main(output, capture_mode='preview'):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=TEST_DEFAULTS['radius'])
    body = bpy.context.object
    body.name = 'debug_body'
    body.scale.z = TEST_DEFAULTS['body_z_scale']
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bundle = output / 'synthetic_fixture.blend'
    bpy.data.libraries.write(str(bundle), {body})
    spec = synthetic_spec()
    write(output / 'synthetic_spec.json', spec)
    # Two empty caches prove deterministic simulation, not merely cache replay.
    run_cache = output / 'runs' / uuid.uuid4().hex
    objects, a = build(spec, output / 'a', bundle, run_cache / 'cache_a')
    objects, b = build(spec, output / 'b', bundle, run_cache / 'cache_b')
    assert a['mesh_hashes'] == b['mesh_hashes'], 'Fresh simulations produced different mesh hashes'
    assert b['passed'], json.dumps(b['checks'])
    objects, cached = build(spec, output / 'cached', bundle, run_cache / 'cache_b')
    assert cached['mesh_hashes'] == b['mesh_hashes'], 'Cache replay changed geometry'
    assert cached['passed'], json.dumps(cached['checks'])
    plate = next(o for o in objects if o.get('piece_id') == 'plate')
    ridge = [v.co for v in plate.data.vertices if v.co.y < -.02]
    assert ridge and max(p.z for p in ridge) - min(p.z for p in ridge) > .2, 'Centre ridge lost its vertical edge'
    from mathutils import Vector
    shaft = next(o for o in objects if o.get('piece_id') == 'curve')
    crystal = next(o for o in objects if o.get('piece_id') == 'crystal')
    curve_spec = next(p for p in spec['pieces'] if p['id'] == 'curve')
    a, b = [shaft.matrix_world @ Vector(p) for p in curve_spec['path']]
    expected_tip = b + (b - a).normalized() * .4
    tip_error = min((crystal.matrix_world @ v.co - expected_tip).length for v in crystal.data.vertices)
    print('CRYSTAL_TIP_ERROR:', tip_error)
    assert tip_error < TEST_DEFAULTS['spatial_tolerance'], 'Crystal tip does not continue the transformed shaft'
    from spec.art_identity.maquettes.blender.validation import geometry_report
    collar = next(o for o in objects if o.get('cloth_kind') == 'collar')
    original = [v.co.copy() for v in collar.data.vertices]
    for v in collar.data.vertices:
        if v.co.x > 0:
            v.co.y *= 3
    assert not geometry_report(spec, objects, {})['collar_front_no_wider_than_back'], 'Symmetry gate missed front wings'
    for v, co in zip(collar.data.vertices, original):
        v.co = co
    original = [v.co.copy() for v in plate.data.vertices]
    for v in plate.data.vertices:
        v.co.x *= .5
        v.co.z *= .5
    assert not geometry_report(spec, objects, {})['plate_corners_preserved'], 'Corner gate missed eroded plate corners'
    for v, co in zip(plate.data.vertices, original):
        v.co = co
    check_native_conformance(spec, objects)
    # Validate the collision detector against a deliberately intersecting surface.
    crossing = mesh_object('crossing', [[-.4, 0, -.2], [.4, 0, -.2], [0, 0, .6]], [(0, 1, 2)])
    posed = bpy.data.objects['posed_body']
    assert not collision_report(crossing, posed, .001)['passed'], 'Intersection detector missed crossing triangle'
    bpy.data.objects.remove(crossing, do_unlink=True)
    # Verify that joint length and transverse scale actually affect the mesh,
    # while edit-bone rest coordinates and accessories remain unchanged data.
    changed = deepcopy(spec)
    changed['joints']['tip'][2] += .1
    changed['joints']['head'][0] += .04
    changed['joints']['tip'][0] += .08
    changed['armature']['bones'][-1]['scale'] = [1.2, 1.1]
    _, moved = build(changed, output / 'posed', bundle, run_cache / 'cache_pose')
    assert moved['combined_mesh_hash'] != cached['combined_mesh_hash'], 'Joint/scale changes did not deform the body'
    rig = bpy.data.objects['maquette_armature']
    from spec.art_identity.maquettes.blender.facing import board_spec
    changed_board = board_spec(changed)
    endpoint_error = max((getattr(rig.pose.bones[b['name']], field) - Vector(changed_board['joints'][b[field]])).length
                         for b in changed['armature']['bones'] for field in ('head', 'tail'))
    assert endpoint_error < TEST_DEFAULTS['spatial_tolerance'], ('Posed bone endpoints drifted', endpoint_error)
    objects, _ = build(spec, output / 'render', bundle, run_cache / 'cache_b')
    from spec.art_identity.maquettes.blender.facing import board_spec
    facing = render(board_spec(spec), objects, output / 'render', engine='cycles', gallery=capture_mode == 'full', preview=capture_mode != 'full')
    assert facing['passed'], facing
    from spec.art_identity.maquettes.raster import project
    # Front/rear projection agreement is tested from emitted coordinates.
    projected = json.loads((output / 'render/joints_px.json').read_text())
    for view, joints in projected.items():
        for name, actual in joints.items():
            expected = project(board_spec(spec), board_spec(spec)['joints'][name], view)[:2]
            assert max(abs(a - e) for a, e in zip(actual, expected)) <= 1, (view, name, actual, expected)
    write(output / 'integration_report.json', {'passed': True, 'deterministic_fresh_builds': True,
          'cache_replay_identical': True, 'facing': facing, 'checks': cached['checks'], 'projection_error_max_px': 1,
          'conformance_gate_rejects_floating_plate': True,
          'posed_joint_endpoint_error': endpoint_error, 'fresh_cache_namespace': str(run_cache)})
    print('BLENDER_NATIVE_INTEGRATION: PASS')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

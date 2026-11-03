"""Bridge-only independent contact, binding and ownership mutation audit."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

AUDIT_DEFAULTS = {'contact_tolerance_m': .02, 'endpoint_tolerance_m': 1e-4}


def feature_visibility(spec, objects):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.raster import camera
    import numpy as np
    vertices, faces, owners = [], [], []
    for obj in objects:
        start = len(vertices)
        vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        faces.extend([start+i for i in p.vertices] for p in obj.data.polygons)
        owners.extend([obj.name]*len(obj.data.polygons))
    tree = BVHTree.FromPolygons(vertices, faces)
    features = {'cyan_cross_visor': ('face_crossbar_accent_render', 'face_slit_accent_render'),
                'chest_crystal': ('chest_gem_render',), 'crystal_spearhead': ('spear_blade_render',)}
    result = {}
    for name, names in features.items():
        views = {}
        for view in ('front', 'rear'):
            matrix, _, basis, _ = camera(spec, view)
            toward = Vector(np.linalg.solve(matrix[:3, :3], basis[2]))
            visible = 0
            for obj in objects:
                if obj.name not in names:
                    continue
                for polygon in obj.data.polygons:
                    centre = obj.matrix_world @ polygon.center
                    _, _, index, _ = tree.ray_cast(centre+toward*spec['ortho_scale'], -toward)
                    visible += int(index is not None and owners[index] in names)
            views[view] = visible
        expected = spec['rig_delivery']['features'][name]['views']
        result[name] = {'visible_native_face_samples': views, 'expected_views': expected,
                        'passed': all((views[v] > 0) == (v in expected) for v in ('front', 'rear'))}
    return result


def main(spec_path, build, output):
    import bpy
    import numpy as np
    from mathutils import Vector
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.validation import geometry_report
    spec = json.loads(Path(spec_path).read_text())
    report = json.loads((Path(build) / 'build_report.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(Path(build) / 'maquette.blend'))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    floors = {side: min((o.matrix_world @ v.co).z for o in objects if o['part'] == 'foot_' + side
                       for v in o.data.vertices) for side in ('near', 'far')}
    shaft = bpy.data.objects['spear_shaft_render']
    spear_floor = min((shaft.matrix_world @ v.co).z for v in shaft.data.vertices)
    native = geometry_report(spec, objects, report['cloth'])
    for obj in objects:
        for polygon in obj.data.polygons:
            polygon.material_index = 0
    mutation = geometry_report(spec, objects, report['cloth'])
    rig = bpy.data.objects['maquette_armature']
    endpoints = {b['name']: max((rig.pose.bones[b['name']].head - Vector(spec['joints'][b['head']])).length,
                              (rig.pose.bones[b['name']].tail - Vector(spec['joints'][b['tail']])).length)
                 for b in spec['armature']['bones']}
    a, b = np.array(next(p for p in spec['pieces'] if p['id'] == 'spear_shaft')['path'])
    grip = np.array(spec['joints']['hand_far'])
    direction = (b-a) / np.linalg.norm(b-a)
    grip_error = float(np.linalg.norm(grip - a - np.dot(grip-a, direction)*direction))
    features = feature_visibility(spec, objects)
    checks = {'current_spec': report['spec_hash'] == digest(spec), 'native_geometry': all(native.values()),
        'both_feet_planted': abs(floors['near']-floors['far']) <= AUDIT_DEFAULTS['contact_tolerance_m'],
        'spear_planted': abs(spear_floor-min(floors.values())) <= AUDIT_DEFAULTS['contact_tolerance_m'],
        'spear_at_grip': grip_error <= AUDIT_DEFAULTS['endpoint_tolerance_m'],
        'native_endpoints': max(endpoints.values()) <= AUDIT_DEFAULTS['endpoint_tolerance_m'],
        'material_mutation_caught': not mutation['polygon_material_ownership'],
        'features_in_required_views': all(row['passed'] for row in features.values())}
    value = {'passed': all(checks.values()), 'checks': checks, 'spec_hash': digest(spec),
        'native_mesh_hash': report['combined_mesh_hash'], 'foot_min_z_m': floors, 'spear_min_z_m': spear_floor,
        'grip_error_m': grip_error, 'joint_errors_m': endpoints, 'features': features, 'defaults': AUDIT_DEFAULTS}
    Path(output).write_text(json.dumps(value, indent=2) + '\n')
    print('MQ14_NATIVE_AUDIT: ' + ('PASS' if value['passed'] else 'FAIL') + '; ' + str(checks))
    return 0 if value['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

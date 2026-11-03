"""Director bridge entry for mq-26: build, opened-native audit and determinism.

The build reuses mq-19's framed builder (explicit bone forward vectors) and the
shared Blender builder unchanged. The audit opens the saved model and measures
the take-three gates on opened native vertices and armature endpoints.
"""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))


def audit(spec_path, native, output):
    import bpy
    import numpy as np
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.storm_cantor.native_probe import mesh_binding
    from spec.art_identity.maquettes.storm_cantor.mq26.checks import observe
    from spec.art_identity.maquettes.storm_cantor.mq26.occlusion import observe as occlusion
    from spec.art_identity.maquettes.storm_cantor.mq26.mutations import native_mutations, far_exposure
    spec = json.loads(Path(spec_path).read_text()); native = Path(native)
    build = json.loads((native / 'build_report.json').read_text())
    if build['spec_hash'] != digest(spec): raise ValueError('Stale mq-26 native build')
    bpy.ops.wm.open_mainfile(filepath=str(native / 'maquette.blend')); bpy.context.view_layer.update()
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    rig = bpy.data.objects['maquette_armature']; joints = {}; forwards = {}
    for b in spec['armature']['bones']:
        bone = rig.pose.bones[b['name']]
        joints[b['head']] = list(bone.head); joints[b['tail']] = list(bone.tail)
        if b['name'] in ('pelvis', 'torso', 'head'): forwards[b['name']] = list(bone.matrix.col[2][:3])
    points = {o.name: np.asarray([list(o.matrix_world @ v.co) for v in o.data.vertices]) for o in objects}
    faces = {o.name: [list(f.vertices) for f in o.data.polygons] for o in objects}
    print('MQ26_AUDIT_STAGE: observe', flush=True)
    result = observe(spec, points, joints, forwards, faces)
    print('MQ26_AUDIT_STAGE: occlusion', flush=True)
    order = occlusion(spec, objects)
    result['cloak_occlusion'] = order; result['checks']['cloak_occlusion'] = order['passed']
    exposure = far_exposure(spec, points, faces)
    result['front_far_exposure'] = exposure; result['checks']['front_far_exposure'] = all(exposure['checks'].values())
    result['checks']['native_mesh_binding'] = mesh_binding(objects, build)
    result['checks']['native_endpoints'] = all(np.linalg.norm(np.subtract(q, spec['joints'][k])) <= 1e-4 for k, q in joints.items())
    result['checks']['native_build'] = build['passed']
    # Negative proofs need a passing baseline; mutations act on copied arrays.
    baseline = all(result['checks'].values())
    print('MQ26_AUDIT_STAGE: mutations; baseline=' + str(baseline), flush=True)
    result['mutations'] = native_mutations(spec, points, joints, forwards, faces) if baseline else {}
    result['checks']['native_mutations'] = bool(result['mutations']) and all(r['caught'] for r in result['mutations'].values())
    result['checks']['restored_native_geometry'] = mesh_binding(objects, build)
    result.update(spec_hash=digest(spec), native_mesh_hash=build['combined_mesh_hash'], observed_joints=joints,
                  observed_forward=forwards, passed=all(result['checks'].values()))
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(result, indent=2, allow_nan=False, default=float) + '\n')
    print('MQ26_NATIVE_AUDIT: ' + ('PASS' if result['passed'] else 'FAIL') + '; failed=' +
          str([k for k, v in result['checks'].items() if not v]) + '; director_accepted_rows=' + str(result['director_accepted_rows']))
    return 0 if result['passed'] else 1


def main():
    operation, *args = sys.argv[sys.argv.index('--') + 1:]
    if operation == 'audit': return audit(*args)
    from spec.art_identity.maquettes.storm_cantor.mq19.native import framed_builder
    with framed_builder():
        if operation == 'build':
            from spec.art_identity.maquettes.blender.build import main as build
            return build(args)
        if operation == 'determinism':
            from spec.art_identity.maquettes.blender.recipe_proof import main as proof
            return proof(*args)
    raise ValueError('Unknown mq-26 native operation: ' + operation)


if __name__ == '__main__': raise SystemExit(main())

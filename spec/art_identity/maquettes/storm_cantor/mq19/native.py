"""Director bridge entry; mq-19-specific bone frames, audit and cold replay.

The scoped adapter keeps the shared builder and every other figure unchanged.
The original automatic heat binding remains in use. Explicit anatomical forward
vectors resolve yaw, which cannot be represented by bone endpoints alone.
"""
from contextlib import contextmanager
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0,str(PROJECT))


@contextmanager
def framed_builder():
    import bpy
    from mathutils import Matrix, Vector
    from spec.art_identity.maquettes.blender import rig
    original = rig.bind_and_pose
    def bind(spec,body):
        armature,posed,owners = original(spec,body)
        matrices = {b.name:b.matrix.copy() for b in armature.pose.bones}
        for b in spec['armature']['bones']:
            name = b['name']; transform = matrices[name]
            forward = spec.get('mq19',{}).get('bone_forward',{}).get(name)
            if forward is not None:
                direction = (Vector(spec['joints'][b['tail']])-Vector(spec['joints'][b['head']])).normalized()
                anterior = Vector((forward[0],forward[1],-(direction.x*forward[0]+direction.y*forward[1])/direction.z)).normalized()
                transverse = direction.cross(anterior).normalized()
                basis = Matrix((transverse,direction,anterior)).transposed()
                lengths = transform.to_scale()
                transform = (basis@Matrix.Diagonal(lengths)).to_4x4()
                transform.translation = Vector(spec['joints'][b['head']])
            armature.pose.bones[name].matrix = transform
            bpy.context.view_layer.update()
        previous = posed.data; posed.data = rig.evaluated_mesh(body)
        bpy.data.meshes.remove(previous)
        armature['posed_forward'] = list(armature.pose.bones['torso'].matrix.col[2][:3])
        return armature,posed,owners
    rig.bind_and_pose = bind
    try: yield
    finally: rig.bind_and_pose = original


def audit(spec_path,native,output):
    import bpy
    import numpy as np
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.storm_cantor.native_probe import mesh_binding
    from spec.art_identity.maquettes.storm_cantor.mq19.checks import observe,preserved_shapes
    spec = json.loads(Path(spec_path).read_text()); native = Path(native)
    build = json.loads((native/'build_report.json').read_text())
    if build['spec_hash']!=digest(spec): raise ValueError('Stale mq-19 native build')
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend')); bpy.context.view_layer.update()
    objects = [o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    rig = bpy.data.objects['maquette_armature']; joints = {}; forwards = {}
    for b in spec['armature']['bones']:
        bone = rig.pose.bones[b['name']]
        joints[b['head']] = list(bone.head); joints[b['tail']] = list(bone.tail)
        if b['name'] in ('pelvis','torso','head'): forwards[b['name']] = list(bone.matrix.col[2][:3])
    def opened():
        bpy.context.view_layer.update()
        points = {o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects}
        faces = {o.name:[list(f.vertices) for f in o.data.polygons] for o in objects}
        return observe(spec,points,joints,forwards,faces)
    result = opened()
    points = {o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects}
    shapes = preserved_shapes(spec,points)
    from spec.art_identity.maquettes.storm_cantor.mq19.occlusion import observe as occlusion
    cloth_order = occlusion(spec,objects)
    from spec.art_identity.maquettes.storm_cantor.mq19.drape_checks import front_exposure
    native_faces={o.name:[list(f.vertices) for f in o.data.polygons] for o in objects}
    exposure=front_exposure(spec,points,native_faces)
    result['front_far_exposure']=exposure
    result['checks']['front_far_exposure']=all(exposure['checks'].values())
    result['checks']['r3_shapes_preserved'] = shapes['passed']
    result['checks']['cloak_occlusion'] = cloth_order['passed']
    result['preserved_shapes'] = shapes;result['cloak_occlusion'] = cloth_order
    result['checks']['native_mesh_binding'] = mesh_binding(objects,build)
    result['checks']['native_endpoints'] = all(np.linalg.norm(np.subtract(q,spec['joints'][k]))<=1e-4 for k,q in joints.items())
    result['checks']['native_build'] = build['passed']
    # Negative proofs require a passing baseline. A pre-existing failure must
    # never masquerade as successful mutation rejection.
    mutants = {}
    if all(result['checks'].values()):
        for label,name,axis in [('detached_staff','staff_render',0),('flattened_finger','finger_near_0_render',0)]:
            obj = bpy.data.objects[name]; saved = [v.co.copy() for v in obj.data.vertices]
            try:
                for v in obj.data.vertices:
                    if label=='detached_staff': v.co[axis]+=spec['mq19']['gauge_L_m']
                    else: v.co[axis]=saved[0][axis]
                mutants[label] = not opened()['checks']['pose_values']
            finally:
                for v,co in zip(obj.data.vertices,saved): v.co=co
    result['checks']['native_mutations'] = len(mutants)==2 and all(mutants.values())
    result['checks']['restored_native_geometry'] = mesh_binding(objects,build)
    result.update(spec_hash=digest(spec),native_mesh_hash=build['combined_mesh_hash'],observed_joints=joints,
                  observed_forward=forwards,mutations=mutants,passed=all(result['checks'].values()))
    Path(output).parent.mkdir(parents=True,exist_ok=True)
    Path(output).write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    print('MQ19_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL'))
    return 0 if result['passed'] else 1


def main():
    operation,*args = sys.argv[sys.argv.index('--')+1:]
    if operation=='audit': return audit(*args)
    with framed_builder():
        if operation=='build':
            from spec.art_identity.maquettes.blender.build import main as build
            return build(args)
        if operation=='determinism':
            from spec.art_identity.maquettes.blender.recipe_proof import main as proof
            return proof(*args)
    raise ValueError('Unknown mq-19 native operation: '+operation)


if __name__=='__main__': raise SystemExit(main())

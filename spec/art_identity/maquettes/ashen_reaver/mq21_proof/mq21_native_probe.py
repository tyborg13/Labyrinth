"""Opened Blender mq-21 audit. Invoke only through the director bridge."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[5];sys.path.insert(0,str(PROJECT))
MUTATION_DEFAULTS={'finger_detachment_m':.2}


def main(spec_path,native,output,source_reference):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.validation import geometry_report
    from spec.art_identity.maquettes.blender.facing import board_spec,axis_report
    from spec.art_identity.maquettes.ashen_reaver.native_probe import mesh_binding
    from spec.art_identity.maquettes.ashen_reaver.mq21_proof.mq21_checks import observe
    from spec.art_identity.maquettes.ashen_reaver.mq21_proof.mq21_contract import load as director_contract
    spec=json.loads(Path(spec_path).read_text());native=Path(native)
    report=json.loads((native/'build_report.json').read_text())
    if report['spec_hash']!=digest(spec):raise ValueError('Native build belongs to another specification')
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'));bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    binding=mesh_binding(objects,report);rig=bpy.data.objects['maquette_armature'];joints={};errors=[]
    for bone in spec['armature']['bones']:
        actual=rig.pose.bones[bone['name']]
        for name,point in ((bone['head'],actual.head),(bone['tail'],actual.tail)):
            joints[name]=list(point);errors.append((point-Vector(spec['joints'][name])).length)
    points={o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects}
    faces={o.name:[list(f.vertices) for f in o.data.polygons] for o in objects}
    baseline=json.loads(Path(source_reference).read_text())
    if digest(baseline)!=spec['mq21']['baseline_spec_hash']:raise ValueError('Native source reference differs from source compiler')
    result=observe(spec,points,joints,faces,baseline)
    result['checks']['source_reference_bound']=True
    # mq-23 replaces only the near arm and legs. All other accepted meshes,
    # including the complete far grip, remain pinned to round two.
    accepted={name:value for name,value in director_contract()['accepted_round2']['native_mesh_hashes'].items()
              if not (name.endswith('_near_render') or name.startswith('finger_near_')
                      or name in ('pauldron_near_1_render','pauldron_near_2_render'))}
    result['checks']['accepted_round2_meshes_preserved']=all(binding['mesh_hashes'].get(name)==expected for name,expected in accepted.items())
    geometry=geometry_report(board_spec(spec),objects,report['cloth'])
    result['checks'].update(opened_mesh_hash_matches_build=binding['passed'],
        native_joint_endpoints=max(errors)<=1e-5,whole_native_features=geometry['whole_native_features'],
        native_geometry=all(geometry.values()))
    cowl=bpy.data.objects['scarf_cowl_render']
    tree=BVHTree.FromPolygons([cowl.matrix_world@v.co for v in cowl.data.vertices],[list(f.vertices) for f in cowl.data.polygons])
    result['checks']['scarf_covers_shoulders']=all(tree.ray_cast(Vector(joints['shoulder_'+s]),Vector((1,0,0)))[0] is not None for s in ('near','far'))
    result['facing']={name:axis_report(board_spec(spec),list(rig.pose.bones[name].matrix.col[2][:3])) for name in ('head','torso')}
    result['checks']['native_facing']=all(row['passed'] for row in result['facing'].values())
    # Mutate the opened Blender mesh, then recompute both semantic geometry
    # and hashes. The contract gates must reject it even with fresh hashes.
    import numpy as np
    finger=bpy.data.objects['finger_far_1_render'];saved_vertices=[v.co.copy() for v in finger.data.vertices]
    direction=np.asarray(spec['mq16']['falchion']['direction']);hand=np.asarray(joints['hand_far'])
    centre=np.asarray(points[finger.name]).reshape(-1,12,3).mean((0,1))
    radial=centre-hand-direction*np.dot(centre-hand,direction);mutations=[]
    for name,shift,gate in (('finger_1_through_handle',-radial,'hand_hilt_penetration'),
                           ('finger_1_detached',radial/np.linalg.norm(radial)*MUTATION_DEFAULTS['finger_detachment_m'],'finger_far_1_hilt_contact')):
        local=finger.matrix_world.to_3x3().inverted()@Vector(shift)
        for vertex,position in zip(finger.data.vertices,saved_vertices):vertex.co=position+local
        bpy.context.view_layer.update()
        mutated=dict(points);mutated[finger.name]=[list(finger.matrix_world@v.co) for v in finger.data.vertices]
        semantic=observe(spec,mutated,joints,faces,baseline);fresh_binding=mesh_binding(objects,report)
        caught=not semantic['checks'][gate] and fresh_binding['combined_mesh_hash']!=binding['combined_mesh_hash']
        result['checks'][name+'_semantic_mutation_rejected']=caught
        mutations.append({'mutation':name,'caught':caught,'semantic_gate':gate,
                          'fresh_mesh_hash':fresh_binding['mesh_hashes'][finger.name],
                          'fresh_combined_mesh_hash':fresh_binding['combined_mesh_hash']})
    for vertex,position in zip(finger.data.vertices,saved_vertices):vertex.co=position
    bpy.context.view_layer.update();result['opened_grip_mutations']=mutations
    result['checks']['grip_mutation_geometry_restored']=mesh_binding(objects,report)['passed']
    saved={o.name:[f.material_index for f in o.data.polygons] for o in objects}
    for obj in objects:
        for face in obj.data.polygons:face.material_index=0
    result['checks']['material_mutation_rejected']=not geometry_report(board_spec(spec),objects,report['cloth'])['polygon_material_ownership']
    for obj in objects:
        for face,owner in zip(obj.data.polygons,saved[obj.name]):face.material_index=owner
    helm=bpy.data.objects['great_helm_render'];before=helm.data.vertices[0].co.copy()
    helm.data.vertices[0].co.x+=1
    result['checks']['geometry_mutation_rejected']=not mesh_binding(objects,report)['passed']
    helm.data.vertices[0].co=before
    result['checks']['native_geometry_restored']=mesh_binding(objects,report)['passed']
    result.update(spec_hash=digest(spec),native_mesh_hash=binding['combined_mesh_hash'],
                  max_joint_error_m=max(errors),passed=all(result['checks'].values()))
    target=Path(output);target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
    print('MQ21_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL')+'; failed='+str([k for k,v in result['checks'].items() if not v]))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

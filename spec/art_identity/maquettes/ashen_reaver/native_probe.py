"""Opened-scene geometry, body pose, ownership and in-memory mutation audit."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(PROJECT))

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from spec.art_identity.maquettes.blender.contract import mesh_hash,digest
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.ashen_reaver.native_checks import observe,NATIVE_DEFAULTS


def mesh_binding(objects,report):
    hashes={o.name:mesh_hash([list(o.matrix_world@v.co) for v in o.data.vertices],
        [list(f.vertices) for f in o.data.polygons],o['part']) for o in objects}
    return {'passed':hashes==report['mesh_hashes'] and digest(hashes)==report['combined_mesh_hash'],
            'mesh_hashes':hashes,'combined_mesh_hash':digest(hashes)}


def main(spec_path,native,output):
    spec=json.loads(Path(spec_path).read_text());native=Path(native)
    report=json.loads((native/'build_report.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'));bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    binding=mesh_binding(objects,report);rig=bpy.data.objects['maquette_armature'];joints={};errors=[]
    for bone in spec['armature']['bones']:
        actual=rig.pose.bones[bone['name']]
        for name,point in [(bone['head'],actual.head),(bone['tail'],actual.tail)]:
            joints[name]=list(point);errors.append((point-Vector(spec['joints'][name])).length)
    points={o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects}
    cowl=bpy.data.objects['scarf_cowl_render']
    tree=BVHTree.FromPolygons([cowl.matrix_world@v.co for v in cowl.data.vertices],[list(f.vertices) for f in cowl.data.polygons])
    scarf_hits={s:tree.ray_cast(Vector(joints['shoulder_'+s]),Vector((1,0,0)))[0] is not None for s in ('near','far')}
    faces={o.name:[list(f.vertices) for f in o.data.polygons] for o in objects}
    pauldron_hits={}
    for side in ('near','far'):
        cap=bpy.data.objects['pauldron_'+side+'_0_render']
        cap_tree=BVHTree.FromPolygons([cap.matrix_world@v.co for v in cap.data.vertices],[list(f.vertices) for f in cap.data.polygons])
        pauldron_hits[side]=cap_tree.ray_cast(Vector(joints['shoulder_'+side]),Vector((0,0,1)))[0] is not None
    result=observe(spec,points,joints,list(rig.pose.bones['head'].matrix.col[2][:3]),
                   list(rig.pose.bones['torso'].matrix.col[2][:3]),scarf_hits,faces,pauldron_hits)
    locked=json.loads((Path(spec_path).parent/'feedback1_preservation.json').read_text()) if (Path(spec_path).parent/'feedback1_preservation.json').is_file() else json.loads((Path(__file__).parent/'feedback1_preservation.json').read_text())
    result['checks']['accepted_native_meshes_unchanged']=all(binding['mesh_hashes'].get(name)==value for name,value in locked['fixed_native_mesh_hashes'].items())
    checks=geometry_report(board_spec(spec),objects,report['cloth'])
    result['checks'].update(opened_mesh_hash_matches_build=binding['passed'],
        native_joint_endpoints=max(errors)<=NATIVE_DEFAULTS['position_tolerance_m'],whole_native_features=checks['whole_native_features'],
        geometry_report=all(checks.values()))
    # A genuine material mutation must fail ownership without touching input.
    saved={o.name:[f.material_index for f in o.data.polygons] for o in objects}
    for obj in objects:
        for face in obj.data.polygons:face.material_index=0
    mutant=geometry_report(board_spec(spec),objects,report['cloth'])
    result['checks']['material_mutation_rejected']=not mutant['polygon_material_ownership']
    for obj in objects:
        for face,owner in zip(obj.data.polygons,saved[obj.name]):face.material_index=owner
    # Keep the old report and alter an opened native vertex: stale hashes
    # cannot certify a detached or corrupted piece.
    helm=bpy.data.objects['great_helm_render'];before=helm.data.vertices[0].co.copy()
    helm.data.vertices[0].co.x+=1
    result['checks']['geometry_mutation_rejected']=not mesh_binding(objects,report)['passed']
    helm.data.vertices[0].co=before
    result['checks']['native_geometry_restored']=mesh_binding(objects,report)['passed']
    result.update(spec_hash=digest(spec),native_mesh_hash=binding['combined_mesh_hash'],max_joint_error_m=max(errors),
                  passed=all(result['checks'].values()))
    Path(output).parent.mkdir(parents=True,exist_ok=True);Path(output).write_text(json.dumps(result,indent=2)+'\n')
    print('MQ16_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL')+'; '+str(result['checks']))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

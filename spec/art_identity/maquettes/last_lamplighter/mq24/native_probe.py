"""Bridge entry: open saved native geometry, then measure without recipe targets."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[5]))
import bpy
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.last_lamplighter.native_probe import mesh_binding
from spec.art_identity.maquettes.last_lamplighter.mq24.measure import observe
from spec.art_identity.maquettes.last_lamplighter.mq24.mutations import mutate,target_gate
from spec.art_identity.maquettes.last_lamplighter.mq24.oracle import contract
from spec.art_identity.maquettes.last_lamplighter.mq24.pose_audit import inspect as inspect_poses


def main(spec_path,native,output,mode='acceptance'):
    spec=json.loads(Path(spec_path).read_text());native=Path(native)
    build=json.loads((native/'build_report.json').read_text())
    if build['spec_hash']!=digest(spec) or not build['passed']:raise ValueError('Invalid mq-24 native build')
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'));bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    rig=bpy.data.objects['maquette_armature'];joints={}
    for bone in spec['armature']['bones']:
        actual=rig.pose.bones[bone['name']]
        for name,point in ((bone['head'],actual.head),(bone['tail'],actual.tail)):joints[name]=list(rig.matrix_world@point)
    def opened():
        bpy.context.view_layer.update()
        return ({o.name.removesuffix('_render'):[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects},
            {o.name.removesuffix('_render'):[list(f.vertices) for f in o.data.polygons] for o in objects},
            {o.name.removesuffix('_render'):{k:o.get(k) for k in ('part','rig_bone')} for o in objects})
    points,faces,owners=opened();result=observe(points,faces,joints,owners,spec['mq24']['design_pending'],opened_native=True)
    result['permitted_pose_search']=inspect_poses(points,joints,result['height_m'],contract())
    result['checks']['native_mesh_binding']=mesh_binding(objects,build)
    result['passed']=all(result['checks'].values());result['mutations']={'status':'not_run_baseline_failed','caught':0,'survived':0}
    diagnostic=mode=='--diagnostic';baseline_passed=result['passed']
    if result['passed'] or diagnostic:
        # Array mutations exercise the identical live geometry oracle. Also
        # put each defect into Blender data and re-read it before measuring.
        table=[];original={o.name:[v.co.copy() for v in o.data.vertices] for o in objects}
        for name in contract()['mutations']:
            p,f,own=mutate(name,points,faces,owners,result['height_m']);added=None
            if name=='plate_readded':
                key='pauldron_near_panel';mesh=bpy.data.meshes.new('mutation_plate');mesh.from_pydata(p[key],[],f[key]);mesh.update()
                added=bpy.data.objects.new(key+'_render',mesh);bpy.context.scene.collection.objects.link(added)
                added['part']='pauldron_near';added['rig_bone']='torso';objects.append(added)
            else:
                for obj in objects:
                    key=obj.name.removesuffix('_render')
                    if key not in p:continue
                    inverse=obj.matrix_world.inverted()
                    from mathutils import Vector
                    for vertex,value in zip(obj.data.vertices,p[key]):vertex.co=inverse@Vector(value)
            a,b,o=opened();observed=observe(a,b,joints,o,opened_native=True)
            caught=target_gate(name,result) and not target_gate(name,observed) if diagnostic else not observed['passed']
            table.append({'mutation':name,'caught':caught,'target_gate_baseline_passed':target_gate(name,result),'failed_checks':[k for k,v in observed['checks'].items() if not v],
                'failed_rows':[r['name'] for r in observed['rows'] if not r['passed']]})
            if added is not None:objects.remove(added);bpy.data.objects.remove(added,do_unlink=True)
            for obj in objects:
                for vertex,value in zip(obj.data.vertices,original[obj.name]):vertex.co=value
            bpy.context.view_layer.update()
        result['mutations']={'status':'opened_native_target_gates_only' if diagnostic else 'opened_native','overall_baseline_passed':baseline_passed,'caught':sum(r['caught'] for r in table),'survived':sum(not r['caught'] for r in table),'rows':table}
        a,b,o=opened();restored=observe(a,b,joints,o,opened_native=True)
        result['checks']['mutation_restoration']=mesh_binding(objects,build) and restored['checks']=={k:v for k,v in result['checks'].items() if k!='native_mesh_binding'}
        result['checks']['six_native_mutations_rejected']=baseline_passed and len(table)==6 and all(r['caught'] for r in table)
    result.update(passed=all(result['checks'].values()),spec_hash=digest(spec),native_mesh_hash=build['combined_mesh_hash'],geometry_scope='opened_native_meshes_and_armature_endpoints')
    Path(output).parent.mkdir(parents=True,exist_ok=True);Path(output).write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    print('MQ24_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL')+'; caught='+str(result['mutations']['caught'])+'; survived='+str(result['mutations']['survived']),flush=True)
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

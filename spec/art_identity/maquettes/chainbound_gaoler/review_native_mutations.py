"""Bridge reproduction: mutate the opened meshes while leaving recipe data fixed."""
import json,sys
from pathlib import Path
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(PROJECT))
import bpy
import numpy as np
from mathutils import Vector
from spec.art_identity.maquettes.chainbound_gaoler.geometry_checks import grip_observation,native_mesh_binding
from spec.art_identity.maquettes.blender.contract import digest

MUTATION_DEFAULTS={'flat_finger_z_offset_m':.1,'link_displacement_m':5,
                   'thumb_displacement_m':2,'helm_vertex_displacement_m':.02}


def main(spec_path,capture,output):
    capture=Path(capture);spec=json.loads(Path(spec_path).read_text())
    recipe=json.loads((Path(__file__).parent/'measurements.json').read_text());before=digest(recipe)
    bpy.ops.wm.open_mainfile(filepath=str(capture/'maquette.blend'))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    by_name={o.name:o for o in objects};frame=recipe['mq15']['grip_frame']
    def points():return {o.name:np.array([list(o.matrix_world@v.co) for v in o.data.vertices]) for o in objects}
    original={o.name:[v.co.copy() for v in o.data.vertices] for o in objects}
    baseline=grip_observation(spec,points(),frame)
    if not baseline['passed']:raise ValueError('Native mutation baseline failed')
    results={}
    for name in ('flatten_native_fingers','detach_native_top_link','detach_native_thumb_sideways','detach_native_thumb_forward'):
        for o in objects:
            for vertex,co in zip(o.data.vertices,original[o.name]):vertex.co=co
        values=points()
        if name=='flatten_native_fingers':
            names=['grip_finger_'+str(i)+'_render' for i in range(1,5)]
            for n in names:values[n][:,2]=frame['origin'][2]+MUTATION_DEFAULTS['flat_finger_z_offset_m']
        elif name=='detach_native_top_link':
            names=['chain_link_1_render'];values[names[0]][:,0]+=MUTATION_DEFAULTS['link_displacement_m']
        else:
            names=['grip_thumb_render'];axis=frame['finger_axis'] if name.endswith('sideways') else frame['knuckle_normal']
            values[names[0]]+=np.array(axis)*MUTATION_DEFAULTS['thumb_displacement_m']
        for n in names:
            obj=by_name[n];inverse=obj.matrix_world.inverted()
            for vertex,co in zip(obj.data.vertices,values[n]):vertex.co=inverse@Vector(co)
        observation=grip_observation(spec,points(),frame)
        results[name]={'caught':not observation['passed'],'checks':observation['checks']}
        print('MQ15_REVIEW_MUTATION: '+name+'; '+('CAUGHT' if not observation['passed'] else 'SURVIVED'))
    for o in objects:
        for vertex,co in zip(o.data.vertices,original[o.name]):vertex.co=co
    report=json.loads((capture/'build_report.json').read_text())
    baseline_binding=native_mesh_binding(objects,report)
    if not baseline_binding['passed']:raise ValueError('Native mesh hash baseline failed')
    by_name['bucket_helm_render'].data.vertices[0].co.x+=MUTATION_DEFAULTS['helm_vertex_displacement_m']
    changed=native_mesh_binding(objects,report)
    results['changed_helm_old_hash']={'caught':not changed['passed'],'native_hash_changed':changed['native_mesh_hash']!=baseline_binding['native_mesh_hash']}
    print('MQ15_REVIEW_MUTATION: changed_helm_old_hash; '+('CAUGHT' if not changed['passed'] else 'SURVIVED'))
    passed=all(r['caught'] for r in results.values()) and digest(recipe)==before
    Path(output).write_text(json.dumps({'passed':passed,'recipe_unchanged':digest(recipe)==before,'mutations':results},indent=2)+'\n')
    print('MQ15_REVIEW_NATIVE_MUTATIONS: '+('PASS' if passed else 'FAIL')+'; caught=5/5')
    return 0 if passed else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

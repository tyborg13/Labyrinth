"""Bridge-only native observations, independent mesh hashes, and restored mutations."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(PROJECT))
import bpy
import numpy as np
from mathutils import Vector
from spec.art_identity.maquettes.blender.contract import mesh_hash,digest
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.solid_features import feature_report
from spec.art_identity.maquettes.last_lamplighter.native_checks import observe,NATIVE_DEFAULTS

MUTATION_DEFAULTS={'stale_vertex_displacement_m':1.,'detached_lantern_m':.2,'armour_scale':.5,'hood_displacement_m':2.,'floating_lamp_over_H':.05,'signature_hide_over_L':.22}


def mesh_binding(objects,report):
    hashes={o.name:mesh_hash([list(o.matrix_world@v.co) for v in o.data.vertices],
        [list(f.vertices) for f in o.data.polygons],o['part']) for o in objects}
    return hashes==report['mesh_hashes'] and digest(hashes)==report['combined_mesh_hash']


def main(spec_path,native,output):
    spec=json.loads(Path(spec_path).read_text());native=Path(native)
    report=json.loads((native/'build_report.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'));bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    rig=bpy.data.objects['maquette_armature'];joints={};errors=[]
    for bone in spec['armature']['bones']:
        actual=rig.pose.bones[bone['name']]
        for name,point in [(bone['head'],actual.head),(bone['tail'],actual.tail)]:
            joints[name]=list(point);errors.append((point-Vector(spec['joints'][name])).length)
    def opened():
        bpy.context.view_layer.update()
        return observe(spec,{o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects},joints)
    result=opened();working=board_spec(spec);checks=geometry_report(working,objects,report['cloth'])
    from spec.art_identity.maquettes.last_lamplighter.lantern_visibility import observe as observe_lantern
    lantern=observe_lantern(working,objects);candle=lantern['candle']
    features=feature_report(working,objects)
    result['checks'].update(opened_mesh_hash_matches_build=mesh_binding(objects,report),
        native_joint_endpoints=max(errors)<=NATIVE_DEFAULTS['endpoint_tolerance_m'],
        geometry_report=all(checks.values()),whole_native_features=checks['whole_native_features'],
        candle_visible_through_glass=candle['passed'],two_panes_clear_both_views=lantern['passed'])
    baseline=all(result['checks'].values());mutations={}
    if baseline:
        saved={o.name:[f.material_index for f in o.data.polygons] for o in objects}
        for o in objects:
            for f in o.data.polygons:f.material_index=0
        mutations['wrong_polygon_owner']=not geometry_report(working,objects,report['cloth'])['polygon_material_ownership']
        for o in objects:
            for f,index in zip(o.data.polygons,saved[o.name]):f.material_index=index
        obj=bpy.data.objects['convex_mask_render'];old=obj.data.vertices[0].co.copy()
        obj.data.vertices[0].co.x+=MUTATION_DEFAULTS['stale_vertex_displacement_m']
        mutations['stale_native_mesh_hash']=not mesh_binding(objects,report);obj.data.vertices[0].co=old
        obj=bpy.data.objects['held_lantern_render'];old=obj.matrix_world.copy()
        obj.location.x+=MUTATION_DEFAULTS['detached_lantern_m'];mutations['detached_lantern']=not opened()['passed'];obj.matrix_world=old
        for name,kind in [('finger_far_0_render','flattened_finger'),('upper_plate_near_render','thin_armour'),('tattered_robe_render','collapsed_cloth')]:
            obj=bpy.data.objects[name];old=[v.co.copy() for v in obj.data.vertices]
            if kind=='flattened_finger':
                for v in obj.data.vertices:v.co.x=old[0].x
            elif kind=='thin_armour':
                centre=sum(old,Vector())/len(old)
                for v in obj.data.vertices:v.co=centre+(v.co-centre)*MUTATION_DEFAULTS['armour_scale']
            else:
                n=len(old)//2
                for k in range(n):obj.data.vertices[n+k].co=old[k]
            mutations[kind]=not opened()['passed']
            for v,co in zip(obj.data.vertices,old):v.co=co
        obj=bpy.data.objects['draped_hood_render'];old=obj.matrix_world.copy();obj.location.x+=MUTATION_DEFAULTS['hood_displacement_m'];bpy.context.view_layer.update()
        mutations['rear_mask_exposed']=not geometry_report(working,objects,report['cloth'])['whole_native_features'];obj.matrix_world=old
    if baseline:
        obj=bpy.data.objects['cowl_rolled_edge_render'];old=[v.co.copy() for v in obj.data.vertices]
        rings=np.array([list(v) for v in old]).reshape(-1,12,3);centres=rings.mean(1)
        for k,vertex in enumerate(obj.data.vertices):vertex.co=centres[k//12]
        mutations['collapsed_cowl_roll']=not opened()['passed']
        for vertex,co in zip(obj.data.vertices,old):vertex.co=co
        obj=bpy.data.objects['tattered_robe_render'];old=[v.co.copy() for v in obj.data.vertices]
        from spec.art_identity.maquettes.last_lamplighter.garments import GARMENT_TOPOLOGY
        a=np.array([list(v) for v in old]);n=len(a)//2;mid=(a[:n]+a[n:])/2;grid=mid.reshape(GARMENT_TOPOLOGY['rows'],GARMENT_TOPOLOGY['columns'],3)
        angles=np.linspace(np.pi/2,2*np.pi,GARMENT_TOPOLOGY['columns'])
        for row_index,row in enumerate(grid):
            basis=np.column_stack([np.ones(len(row)),np.sin(angles),np.cos(angles),abs(np.sin(angles)),row[:,2]])
            fit=np.einsum('ij,jk->ik',basis,np.linalg.lstsq(basis,row[:,:2],rcond=None)[0]);delta=fit-row[:,:2]
            for column,d in enumerate(delta):
                index=row_index*GARMENT_TOPOLOGY['columns']+column
                for k in (index,n+index):obj.data.vertices[k].co.x+=d[0];obj.data.vertices[k].co.y+=d[1]
        mutations['flattened_vertical_folds']=not opened()['checks']['soft_vertical_folds']
        for vertex,co in zip(obj.data.vertices,old):vertex.co=co
        selected=[o for o in objects if o['part']=='lamp_house'];old={o.name:o.matrix_world.copy() for o in selected}
        for o in selected:o.location.z+=spec['mq18']['height_m']*MUTATION_DEFAULTS['floating_lamp_over_H']
        mutations['floating_lamp_house']=not opened()['passed']
        for o in selected:o.matrix_world=old[o.name]
        selected=[o for o in objects if o['part']=='lantern'];old={o.name:o.matrix_world.copy() for o in selected}
        for o in selected:o.location.y-=spec['mq18']['leg_length_m']*MUTATION_DEFAULTS['signature_hide_over_L']
        bpy.context.view_layer.update();mutations['rear_signature_hidden']=not observe_lantern(working,objects)['passed']
        for o in selected:o.matrix_world=old[o.name]
    result['checks'].update(passing_native_baseline=baseline,native_mutations_rejected=bool(mutations) and all(mutations.values()),
        native_geometry_restored=mesh_binding(objects,report) and opened()['passed'])
    result.update(spec_hash=digest(spec),native_mesh_hash=report['combined_mesh_hash'],max_joint_error_m=max(errors),
        observed_joints=joints,feature_visibility=features,candle_visibility=candle,lantern_visibility=lantern,mutations=mutations,passed=all(result['checks'].values()))
    Path(output).parent.mkdir(parents=True,exist_ok=True);Path(output).write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
    print('MQ18_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL')+'; checks='+str(result['checks'])+'; mutations='+str(mutations))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

"""Bridge-only opened native pose/mesh/ownership audit and actual mutations."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(PROJECT))
import bpy
from mathutils import Vector
from spec.art_identity.maquettes.blender.contract import mesh_hash,digest
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.solid_features import feature_report
from spec.art_identity.maquettes.storm_cantor.native_checks import observe,NATIVE_DEFAULTS

MUTATION_DEFAULTS={'helm_vertex_displacement_m':1.,'staff_displacement_m':.1,'bell_rear_displacement_m':.5,
                   'feedback_armour_scale':.5,'feedback_dome_drop_over_H':.1,
                   'feedback_armour_length_scale':.1,'flattened_cap_height_over_H':.01}
VOLUME_MUTATIONS={'thin_armour','collapsed_cloth','sphere_below_shoulder',
                  'flattened_caps','shortened_armour','collapsed_shells'}


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
    def observe_opened():
        bpy.context.view_layer.update()
        points={o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects}
        return observe(spec,points,joints,list(rig.pose.bones['head'].matrix.col[2][:3]),
                       list(rig.pose.bones['torso'].matrix.col[2][:3]))
    result=observe_opened();working=board_spec(spec)
    working['native_features']['tabard_sigils']['visibility']['rear']='occluded'
    features=feature_report(working,objects)
    checks=geometry_report(working,objects,report['cloth'])
    result['checks'].update(opened_mesh_hash_matches_build=mesh_binding(objects,report),
        native_joint_endpoints=max(errors)<=NATIVE_DEFAULTS['endpoint_tolerance_m'],
        whole_native_features=checks['whole_native_features'],geometry_report=all(checks.values()),
        tabard_sigils_rear_occluded=features['tabard_sigils']['passed'])
    if not all(result['checks'].values()):
        Path(output).write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
        print('MQ17_NATIVE_AUDIT: FAIL; '+str(result['checks']))
        return 1
    # All mutations start with a passing opened-scene baseline. Restore native
    # data after each change; the source recipe/report remain untouched.
    mutations={}
    saved={o.name:[f.material_index for f in o.data.polygons] for o in objects}
    for obj in objects:
        for face in obj.data.polygons:face.material_index=0
    mutations['wrong_polygon_owner']=not geometry_report(board_spec(spec),objects,report['cloth'])['polygon_material_ownership']
    for obj in objects:
        for face,owner in zip(obj.data.polygons,saved[obj.name]):face.material_index=owner
    helm=bpy.data.objects['great_helm_render'];old=helm.data.vertices[0].co.copy()
    helm.data.vertices[0].co.x+=MUTATION_DEFAULTS['helm_vertex_displacement_m']
    mutations['stale_mesh_hash']=not mesh_binding(objects,report);helm.data.vertices[0].co=old
    staff=bpy.data.objects['staff_render'];old=staff.matrix_world.copy()
    staff.location.x+=MUTATION_DEFAULTS['staff_displacement_m']
    mutations['staff_detached_from_fist']=not observe_opened()['passed'];staff.matrix_world=old
    finger=bpy.data.objects['finger_near_0_render'];old=[v.co.copy() for v in finger.data.vertices]
    for vertex in finger.data.vertices:vertex.co.x=old[0].x
    mutations['flattened_native_finger']=not observe_opened()['passed']
    for vertex,co in zip(finger.data.vertices,old):vertex.co=co
    bell=bpy.data.objects['bell_render'];old=bell.matrix_world.copy()
    bell.location.x-=MUTATION_DEFAULTS['bell_rear_displacement_m']
    bpy.context.view_layer.update()
    mutations['rear_bell_exposed']=not geometry_report(board_spec(spec),objects,report['cloth'])['whole_native_features'];bell.matrix_world=old
    volume_mutations={}
    for label,name in [('thin_armour','upper_plate_near_render'),('collapsed_cloth','front_tabard_render'),('sphere_below_shoulder','pauldron_near_render')]:
        obj=bpy.data.objects[name];old=[v.co.copy() for v in obj.data.vertices]
        if label=='thin_armour':
            centre=sum(old,Vector())/len(old)
            for v in obj.data.vertices:v.co=centre+(v.co-centre)*MUTATION_DEFAULTS['feedback_armour_scale']
        elif label=='collapsed_cloth':
            count=len(old)//2
            for k in range(count):obj.data.vertices[count+k].co=old[k]
        else:
            for v in obj.data.vertices:v.co.z-=spec['mq17']['height_m']*MUTATION_DEFAULTS['feedback_dome_drop_over_H']
        volume_mutations[label]=not observe_opened()['checks']['feedback1_volumes']
        for v,co in zip(obj.data.vertices,old):v.co=co
    volume_mutation_details={}
    for label in ('flattened_caps','shortened_armour','collapsed_shells'):
        names=(['upper_plate_near_render','fore_plate_far_render'] if label=='shortened_armour' else
               ['pauldron_'+s+'_render' for s in ('near','far')])
        originals={name:[v.co.copy() for v in bpy.data.objects[name].data.vertices] for name in names}
        for name in names:
            obj=bpy.data.objects[name];world=obj.matrix_world;inverse=world.inverted()
            points=[world@co for co in originals[name]]
            if label=='flattened_caps':
                side=name.removeprefix('pauldron_').removesuffix('_render')
                height=joints['shoulder_'+side][2]+spec['volume_layout']['reference_height_m']*MUTATION_DEFAULTS['flattened_cap_height_over_H']
                for point in points:point.z=height
            elif label=='collapsed_shells':points[len(points)//2:]=[co.copy() for co in points[:len(points)//2]]
            else:
                a,b=('shoulder_near','elbow_near') if name.startswith('upper') else ('elbow_far','hand_far')
                axis=(Vector(joints[b])-Vector(joints[a])).normalized();centre=sum(points,Vector())/len(points)
                for point in points:point-=axis*((point-centre).dot(axis)*(1-MUTATION_DEFAULTS['feedback_armour_length_scale']))
            for vertex,point in zip(obj.data.vertices,points):vertex.co=inverse@point
        observation=observe_opened()['volumes']
        volume_mutations[label]=not observation['passed']
        volume_mutation_details[label]={'observed_shape_results':observation['checks'],'shape_measurements':observation['shape_measurements']}
        for name,coords in originals.items():
            for vertex,co in zip(bpy.data.objects[name].data.vertices,coords):vertex.co=co
    result['checks'].update(native_mutations_rejected=all(mutations.values()),
        feedback1_mutations_rejected=set(volume_mutations)==VOLUME_MUTATIONS and all(volume_mutations.values()),native_geometry_restored=mesh_binding(objects,report) and observe_opened()['passed'])
    result.update(spec_hash=digest(spec),native_mesh_hash=report['combined_mesh_hash'],max_joint_error_m=max(errors),
        observed_joints=joints,feature_visibility=features,
        mutations=mutations,volume_mutations=volume_mutations,volume_mutation_details=volume_mutation_details,
        passed=all(result['checks'].values()))
    Path(output).parent.mkdir(parents=True,exist_ok=True);Path(output).write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
    print('MQ17_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL')+'; mutations='+str(mutations))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

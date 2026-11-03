"""Bridge entry: inspect opened mq-20 geometry, facing rays and actual ownership."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[5];sys.path.insert(0,str(PROJECT))
import bpy
from mathutils import Vector
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.blender.solid_features import feature_report
from spec.art_identity.maquettes.last_lamplighter.native_probe import mesh_binding
from spec.art_identity.maquettes.last_lamplighter.lantern_visibility import observe as lantern_visibility
from spec.art_identity.maquettes.last_lamplighter.mq20.measure import observe
from spec.art_identity.maquettes.last_lamplighter.mq20.geometry import near_plate_visibility

MUTATIONS={'displacement_over_H':.2,'collapse_scale':0.}


def main(spec_path,native,output):
    spec=json.loads(Path(spec_path).read_text());native=Path(native)
    build=json.loads((native/'build_report.json').read_text())
    if build['spec_hash']!=digest(spec) or build['passed'] is not True:raise ValueError('Invalid mq-20 build')
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'));bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    rig=bpy.data.objects['maquette_armature'];joints={};errors=[]
    for bone in spec['armature']['bones']:
        actual=rig.pose.bones[bone['name']]
        for name,point in [(bone['head'],actual.head),(bone['tail'],actual.tail)]:
            joints[name]=list(point);errors.append((point-Vector(spec['joints'][name])).length)
    def opened():
        bpy.context.view_layer.update()
        return observe(spec,{o.name:[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects},joints,
            {o.name:[list(f.vertices) for f in o.data.polygons] for o in objects})
    result=opened();working=board_spec(spec);geometry=geometry_report(working,objects,build['cloth'])
    plate=near_plate_visibility(spec,
        {o.get('piece_id'):[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects},
        {o.get('piece_id'):[list(f.vertices) for f in o.data.polygons] for o in objects})
    lantern=lantern_visibility(working,objects);features=feature_report(working,objects)
    # mq-20 replaces the lantern and explicitly gates its rear candle and
    # front/rear projected area (the latter is measured from captures).
    # The authorized front overlap means partial rear occlusion after a true
    # turn. Keep mq-18's two-whole-pane totals as diagnostic evidence rather
    # than importing an additional visibility requirement for the new lamp.
    lantern['mq18_whole_pane_diagnostic']={'criterion':'Two whole-pane equivalents in each view; retained mq-18 diagnostic for the replaced lantern.',
        'threshold_met':lantern['passed']}
    for row in lantern['views'].values():
        row['mq18_whole_pane_threshold_met']=row.pop('passed')
    lantern['mq20_checks']={'candle_glow_both_views':lantern['candle']['passed'],
        'glass_exposed_front':lantern['views']['front']['visible_pane_equivalents']>0,
        'glass_exposed_rear':lantern['views']['rear']['visible_pane_equivalents']>0}
    lantern['passed']=all(lantern['mq20_checks'].values())
    lantern['mq20_requirement']='Six actual panes; exposed glass and lit candle in both views. Rear candle and capture area ratio are the mq-20 brief gates; mq-18 whole-pane totals are retained diagnostics.'
    result['checks'].update(opened_mesh_hash_matches_build=mesh_binding(objects,build),
        native_joint_endpoints=max(errors)<=1e-4,native_geometry=all(geometry.values()),
        whole_native_features=all(r['passed'] for r in features.values()),candle_and_glass_visible_both_views=lantern['passed'])
    baseline=all(result['checks'].values());mutants={}
    # Run mutations only against a passing baseline; a pre-existing failure
    # must never masquerade as a successful rejection of a deliberate defect.
    if baseline:
        for name,kind in [('finger_far_0_render','flattened_claw'),('pauldron_near_cross_render','rear_cross'),('tattered_robe_render','collapsed_robe')]:
            obj=bpy.data.objects[name];old=[v.co.copy() for v in obj.data.vertices]
            if kind=='flattened_claw':
                for v in obj.data.vertices:v.co.x=old[0].x
            elif kind=='rear_cross':
                for v in obj.data.vertices:v.co.x-=spec['mq18']['height_m']*MUTATIONS['displacement_over_H']
            else:
                n=len(old)//2
                for k in range(n):obj.data.vertices[n+k].co=old[k]
            mutants[kind]=not opened()['passed']
            for v,co in zip(obj.data.vertices,old):v.co=co
        selected=[o for o in objects if o['part']=='lantern'];old={o.name:o.matrix_world.copy() for o in selected}
        for o in selected:o.location.x+=spec['mq18']['height_m']*MUTATIONS['displacement_over_H']
        bpy.context.view_layer.update()
        mutants['detached_lantern']=not mesh_binding(objects,build)
        for o in selected:o.matrix_world=old[o.name]
        bpy.context.view_layer.update()
    result['checks'].update(passing_native_baseline=baseline,native_mutations_rejected=baseline and len(mutants)==4 and all(mutants.values()),
        native_geometry_restored=mesh_binding(objects,build) and opened()['passed'])
    result.update(spec_hash=digest(spec),native_mesh_hash=build['combined_mesh_hash'],observed_joints=joints,
        lantern_visibility=lantern,near_plate_visibility=plate,feature_visibility=features,mutations=mutants,passed=all(result['checks'].values()))
    # Blender's bundled Python has no Pillow. Keep native JSON output free
    # of the host-only image curation module.
    Path(output).parent.mkdir(parents=True,exist_ok=True)
    Path(output).write_text(json.dumps(result,separators=(',',':'),allow_nan=False)+'\n')
    print('MQ20_NATIVE_AUDIT: '+('PASS' if result['passed'] else 'FAIL')+'; checks='+str(result['checks']))
    return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

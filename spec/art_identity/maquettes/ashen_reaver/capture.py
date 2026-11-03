"""One bounded native preview or four semantic solos; bridge entry only."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(PROJECT))
import bpy
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.capture_view import signature
from spec.art_identity.maquettes.blender.render import render
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.blender.capture_manifest import write_manifest
from spec.art_identity.maquettes.blender.pieces import mesh_object
from spec.art_identity.maquettes.ashen_reaver.native_probe import mesh_binding


def main(spec_path,blend,output,view,mode):
    spec=json.loads(Path(spec_path).read_text());blend=Path(blend);output=Path(output)
    report=json.loads(blend.with_name('build_report.json').read_text())
    if report['spec_hash']!=digest(spec) or not report['passed']:raise ValueError('Invalid saved native build')
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    checks=geometry_report(board_spec(spec),objects,report['cloth'])
    if not all(checks.values()):raise ValueError('Opened scene failed geometry: '+str(checks))
    before=signature(objects);output.mkdir(parents=True,exist_ok=True)
    (output/'build_report.json').write_text(json.dumps(report)+'\n')
    if mode=='blade_area':
        binding=mesh_binding(objects,report)
        if not binding['passed']:raise ValueError('Blade area source differs from opened native build')
        source=bpy.data.objects['falchion_render'];count=spec['mq16']['falchion']['blade_vertex_count']
        vertices=[list(source.matrix_world@v.co) for v in list(source.data.vertices)[:count]]
        faces=[list(f.vertices) for f in source.data.polygons if all(i<count for i in f.vertices)]
        blade=mesh_object('native_blade_area',vertices,faces)
        blade['part']='falchion';blade['piece_id']='falchion';blade['piece_type']='rigid_shell'
        blade['owner_index']=list(spec['labels']).index('falchion')
        hidden={o.name:o.hide_render for o in objects}
        try:
            for obj in objects:obj.hide_render=True
            facing=render(board_spec(spec),[blade],output,views=(view,),preview=True,
                          image_modes=('silhouette',),capture_facing=False)
            name=view+'_blade_area.png'
            (output/(view+'_silhouette.png')).rename(output/name)
            write_manifest(output,digest(spec),'preview',[name])
        finally:
            for obj in objects:obj.hide_render=hidden[obj.name]
            bpy.data.objects.remove(blade,do_unlink=True)
    else:
        preview=mode in ('clay','labels','preview')
        facing=render(board_spec(spec),objects,output,views=(view,),preview=preview,
            ownership_only=not preview,solo_parts=None if preview else mode.split(','),
            solos_only=not preview,image_modes=('clay',) if mode=='clay' else ('parts','silhouette') if mode=='labels' else None,
            capture_facing=mode in ('labels','preview'))
    unchanged=before==signature(objects)
    passed=unchanged and (facing is None or facing['passed'])
    (output/'capture_checks.json').write_text(json.dumps({'passed':passed,'geometry_unchanged':unchanged,
        'geometry_checks':checks,'spec_hash':digest(spec),'facing':facing})+'\n')
    print('MQ16_BOUNDED_CAPTURE: '+('PASS' if passed else 'FAIL')+'; '+view+'; '+mode)
    return 0 if passed else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

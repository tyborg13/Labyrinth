"""Bridge-only bounded clay/map/facing passes and explicit two-label solos."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[5]))


def main(spec_path,blend,output,view,mode):
    import bpy
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.facing import board_spec
    from spec.art_identity.maquettes.blender.capture_view import signature
    from spec.art_identity.maquettes.blender import render as renderer
    render=renderer.render
    spec=json.loads(Path(spec_path).read_text());blend=Path(blend);output=Path(output)
    renderer.RENDER_DEFAULTS['size']=spec['mq19']['capture_px']
    report=json.loads(blend.with_name('build_report.json').read_text())
    if report['spec_hash']!=digest(spec) or not report['passed']:raise ValueError('Stale/failed native build')
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    before=signature(objects);output.mkdir(parents=True,exist_ok=True)
    (output/'build_report.json').write_text(json.dumps(report)+'\n')
    preview=mode in ('clay','parts','facing','silhouette')
    facing=render(board_spec(spec),objects,output,views=(view,),preview=preview,
        ownership_only=not preview,solo_parts=None if preview else mode.split(','),
        solos_only=not preview,image_modes=('silhouette' if mode in ('facing','silhouette') else mode,) if preview else None,
        capture_facing=mode=='facing')
    unchanged=before==signature(objects);passed=unchanged and (facing is None or facing['passed'])
    (output/'capture_checks.json').write_text(json.dumps({'passed':passed,'geometry_unchanged':unchanged,
        'geometry_checks':report['checks'],'spec_hash':digest(spec),'facing':facing})+'\n')
    print('MQ19_BOUNDED_CAPTURE: '+('PASS' if passed else 'FAIL')+'; '+view+'; '+mode)
    return 0 if passed else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

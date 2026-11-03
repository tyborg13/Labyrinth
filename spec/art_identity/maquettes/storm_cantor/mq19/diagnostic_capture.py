"""Bridge-only diagnostic clay of a failed build; never a delivery capture.

Keeps every failing build gate and writes no full-capture manifest. This lets
the director inspect a constraint conflict without certifying that geometry.
"""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[5]))


def main(spec_path,native,output,view,mode='clay'):
    import bpy
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.facing import board_spec
    from spec.art_identity.maquettes.blender.capture_view import signature
    from spec.art_identity.maquettes.blender import render as renderer
    spec=json.loads(Path(spec_path).read_text());native=Path(native);output=Path(output)
    report=json.loads((native/'build_report.json').read_text())
    if report['spec_hash']!=digest(spec) or report['passed']:
        raise ValueError('Diagnostic capture requires a matching FAILED native build')
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    before=signature(objects);output.mkdir(parents=True,exist_ok=True)
    (output/'build_report.json').write_text(json.dumps(report)+'\n')
    renderer.RENDER_DEFAULTS['size']=spec['mq19']['capture_px']
    renderer.render(board_spec(spec),objects,output,views=(view,),preview=mode=='clay',
        ownership_only=mode!='clay',solo_parts=None if mode=='clay' else ['cloak'],
        solos_only=mode!='clay',image_modes=('clay',) if mode=='clay' else None,capture_facing=False)
    if signature(objects)!=before:raise ValueError('Diagnostic capture changed geometry')
    # Remove the renderer's preview receipt so no diagnostic can masquerade as
    # a passing production preview. Native pixels and projected joints remain.
    (output/'capture_manifest.json').unlink(missing_ok=True)
    (output/'diagnostic.json').write_text(json.dumps({'passed':False,'diagnostic_only':True,
        'geometry_unchanged':True,'spec_hash':digest(spec),'failed_build_checks':
        [k for k,v in report['checks'].items() if not v]})+'\n')
    print('MQ19_DIAGNOSTIC_CAPTURE: complete; failed build gates retained')
    return 0


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

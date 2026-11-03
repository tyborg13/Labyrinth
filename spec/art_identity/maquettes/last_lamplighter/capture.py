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


def main(spec_path,blend,output,view,mode):
    spec=json.loads(Path(spec_path).read_text());blend=Path(blend);output=Path(output)
    report=json.loads(blend.with_name('build_report.json').read_text())
    if report['spec_hash']!=digest(spec) or not report['passed']:raise ValueError('Invalid saved native build')
    bpy.ops.wm.open_mainfile(filepath=str(blend))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    checks=geometry_report(board_spec(spec),objects,report['cloth'])
    if not all(checks.values()):raise ValueError('Opened scene failed geometry: '+str(checks))
    # Clay-only diagnostic transmission exposes the actual enclosed candle.
    # Ownership and solo passes retain the complete opaque glass geometry.
    import importlib
    renderer=importlib.import_module('spec.art_identity.maquettes.blender.render')
    standard_material=renderer.material
    def material(name,colour,mode):
        if name.startswith('lantern_pane_') and name.endswith('_render_clay') and mode=='clay':
            mat=bpy.data.materials.new(name);mat.use_nodes=True
            nodes=mat.node_tree.nodes;nodes.clear()
            surface=nodes.new('ShaderNodeOutputMaterial');glass=nodes.new('ShaderNodeBsdfTransparent')
            mat.node_tree.links.new(glass.outputs[0],surface.inputs['Surface']);return mat
        if name=='candle_glow_render_clay':return standard_material(name,colour,'parts')
        return standard_material(name,colour,mode)
    renderer.material=material
    before=signature(objects);output.mkdir(parents=True,exist_ok=True)
    (output/'build_report.json').write_text(json.dumps(report)+'\n')
    preview=mode in ('clay','labels','preview')
    facing=render(board_spec(spec),objects,output,views=(view,),preview=preview,
        ownership_only=not preview,solo_parts=None if preview else mode.split(','))
    unchanged=before==signature(objects)
    passed=unchanged and (facing is None or facing['passed'])
    (output/'capture_checks.json').write_text(json.dumps({'passed':passed,'geometry_unchanged':unchanged,
        'geometry_checks':checks,'spec_hash':digest(spec),'facing':facing})+'\n')
    print('MQ18_BOUNDED_CAPTURE: '+('PASS' if passed else 'FAIL')+'; '+view+'; '+mode)
    return 0 if passed else 1


if __name__=='__main__':raise SystemExit(main(*sys.argv[sys.argv.index('--')+1:]))

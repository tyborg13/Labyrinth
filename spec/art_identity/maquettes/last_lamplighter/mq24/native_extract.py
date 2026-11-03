"""Bridge-only diagnostic snapshot of opened mesh data and bone endpoints."""
import gzip
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[5]))
import bpy
from spec.art_identity.maquettes.last_lamplighter.native_probe import mesh_binding


def main(spec_path,native,output):
    spec=json.loads(Path(spec_path).read_text());native=Path(native)
    bpy.ops.wm.open_mainfile(filepath=str(native/'maquette.blend'));bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('part') and not o.get('native_source')]
    build=json.loads((native/'build_report.json').read_text());rig=bpy.data.objects['maquette_armature'];joints={}
    for bone in spec['armature']['bones']:
        actual=rig.pose.bones[bone['name']]
        for name,point in ((bone['head'],actual.head),(bone['tail'],actual.tail)):joints[name]=list(rig.matrix_world@point)
    report={'geometry_scope':'opened_native','mesh_binding':mesh_binding(objects,build),
        'points':{o.name.removesuffix('_render'):[list(o.matrix_world@v.co) for v in o.data.vertices] for o in objects},
        'faces':{o.name.removesuffix('_render'):[list(f.vertices) for f in o.data.polygons] for o in objects},
        'owners':{o.name.removesuffix('_render'):{k:o.get(k) for k in ('part','rig_bone')} for o in objects},'joints':joints}
    Path(output).write_bytes(gzip.compress(json.dumps(report,separators=(',',':')).encode()))
    print('MQ24_OPENED_NATIVE_SNAPSHOT: binding='+str(report['mesh_binding']),flush=True)


if __name__=='__main__':main(*sys.argv[sys.argv.index('--')+1:])

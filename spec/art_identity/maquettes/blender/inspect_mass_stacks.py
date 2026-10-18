"""Bridge-only, read-only saved-build diagnostics; never rewrites the blend."""
import argparse
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True


def main():
    import bpy
    args=sys.argv[sys.argv.index('--')+1:]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('blend',type=Path)
    parser.add_argument('out',type=Path)
    parser.add_argument('--contacts',type=Path,help='JSON list of part pairs to check on actual frozen geometry')
    config=parser.parse_args(args)
    bpy.ops.wm.open_mainfile(filepath=str(config.blend))
    result={}
    for frozen in list(bpy.data.objects):
        if not frozen.name.endswith('_render') or frozen.type!='MESH':continue
        source=bpy.data.objects.get(frozen.name[:-7])
        entry={'vertices':len(frozen.data.vertices),'faces':len(frozen.data.polygons)}
        if not frozen.data.polygons and source:
            source.hide_set(False)
            stages=[]
            while True:
                bpy.context.view_layer.update()
                evaluated=source.evaluated_get(bpy.context.evaluated_depsgraph_get())
                mesh=evaluated.to_mesh()
                stages.append({'modifiers':[m.name for m in source.modifiers],
                               'vertices':len(mesh.vertices),'faces':len(mesh.polygons)})
                evaluated.to_mesh_clear()
                if not source.modifiers:break
                source.modifiers.remove(source.modifiers[-1])
            entry['stages']=stages
        result[frozen.name]=entry
    if config.contacts:
        import hashlib
        from mathutils.bvhtree import BVHTree
        groups={}
        for obj in bpy.data.objects:
            if not obj.name.endswith('_render') or obj.type!='MESH':continue
            vertices,faces=groups.setdefault(obj.get('part'),([],[]))
            start=len(vertices);vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
            faces.extend([[start+i for i in face.vertices] for face in obj.data.polygons])
        trees={name:BVHTree.FromPolygons(*data) for name,data in groups.items()}
        pairs={a+'/'+b:len(trees[a].overlap(trees[b])) for a,b in json.loads(config.contacts.read_text())}
        result['part_contacts']={'surface_intersections':pairs,'passed':all(pairs.values()),
            'blend_sha256':hashlib.sha256(config.blend.read_bytes()).hexdigest()}
    config.out.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


if __name__=='__main__':main()

"""Bridge-only measurements of the actual frozen hood and vessel surfaces."""
import argparse
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
PROJECT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(PROJECT))

PROBE_DEFAULTS={'ray_distance_m':30.,'outer_face_tolerance_m':1e-5}


def probe(spec,capture):
    import bpy
    import numpy as np
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.raster import project,camera
    from spec.art_identity.maquettes.hollow_mimic.shape_measurements import vessel
    bpy.ops.wm.open_mainfile(filepath=str(capture/'maquette.blend'))
    build=json.loads((capture/'build_report.json').read_text())
    if digest(spec)!=build['spec_hash']:raise ValueError('Shape probe build input mismatch')
    objects=[o for o in bpy.context.scene.objects if 'owner_index' in o and not o.get('native_source')]
    def points(obj):
        used=sorted({i for p in obj.data.polygons for i in p.vertices})
        return np.array([list(obj.matrix_world@obj.data.vertices[i].co) for i in used])
    by_id={o.get('piece_id',o.name):o for o in objects}
    report={'id':spec['id'],'spec_hash':digest(spec),'cold_mesh_hash':build['combined_mesh_hash']}
    if spec['id']=='briar_weaver':
        hood={n:points(by_id[n]) for n in ('bark_leaf_hood','rear_hood_leaf_clumps')}
        tops={n:float(project(spec,p,'rear',1024)[:,1].min()) for n,p in hood.items()}
        report['rear_hood']={'top_px':min(tops.values()),'component_top_px':tops,
                             'referenced_vertices':{n:len(p) for n,p in hood.items()}}
    if spec['id']=='slag_mortar':
        cup=next(p for p in spec['pieces'] if p['id']=='crucible')
        axis=np.subtract(cup['path'][-1],cup['path'][0]);axis/=np.linalg.norm(axis)
        bands={n:points(o) for n,o in by_id.items() if n.startswith('crucible_band_') and n!='crucible_band_2'}
        report['vessel']=vessel(points(by_id['crucible']),bands,points(by_id['crucible_band_2']),axis,cup['path'][0])
        vertices,faces,owners=[],[],[]
        for o in objects:
            start=len(vertices);vertices.extend(o.matrix_world@v.co for v in o.data.vertices)
            faces.extend([start+i for i in p.vertices] for p in o.data.polygons);owners.extend([o.get('piece_id',o.name)]*len(o.data.polygons))
        tree=BVHTree.FromPolygons(vertices,faces)
        for row in report['vessel']['bands']:
            p=bands[row['object']];delta=p-cup['path'][0];z=delta@axis;rad=np.linalg.norm(delta-z[:,None]*axis,axis=1)
            outer=p[rad>=rad.max()-PROBE_DEFAULTS['outer_face_tolerance_m']]
            visible={}
            for view in ('front','rear'):
                matrix,_,basis,_=camera(spec,view);toward=Vector((basis[2]@matrix[:3,:3]).tolist()).normalized();count=0
                for point in outer:
                    hit,_,index,_=tree.ray_cast(Vector(point)+toward*PROBE_DEFAULTS['ray_distance_m'],-toward)
                    count+=int(hit is not None and owners[index]==row['object'])
                visible[view]=count
            row['visible_outer_samples']=visible
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec',type=Path);parser.add_argument('capture',type=Path);parser.add_argument('output',type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    report=probe(json.loads(args.spec.read_text()),args.capture)
    args.output.write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
    print('MQ09_NATIVE_SHAPE: '+report['id']+'; '+json.dumps(report,sort_keys=True))
    return 0

if __name__=='__main__':raise SystemExit(main())

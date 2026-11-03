"""Opened-native glass exposure and candle rays in the two proper board views."""
import numpy as np
from .feedback_checks import MEASUREMENT_DEFAULTS


def observe(spec,objects):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.raster import camera
    from spec.art_identity.maquettes.blender.solid_features import feature_report
    vertices=[];faces=[];owners=[]
    for obj in objects:
        offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend([offset+i for i in face.vertices] for face in obj.data.polygons)
        owners.extend([obj.get('piece_id')]*len(obj.data.polygons))
    tree=BVHTree.FromPolygons(vertices,faces);panes=[o for o in objects if o.get('piece_id','').startswith('lantern_pane_')]
    views={};grid=MEASUREMENT_DEFAULTS['pane_grid']
    for view in ('front','rear'):
        matrix,_,basis,_=camera(spec,view);toward=Vector((basis[2]@matrix[:3,:3]).tolist()).normalized();values={}
        for obj in panes:
            p=np.array([list(obj.matrix_world@v.co) for v in obj.data.vertices]);n=len(p)//2;mid=(p[:n]+p[n:])/2
            normal=np.cross(mid[1]-mid[0],mid[2]-mid[0]);facing=np.dot(normal,list(toward))>0
            visible=0;occluders={}
            if facing:
                for a in (np.arange(grid)+.5)/grid:
                    for b in (np.arange(grid)+.5)/grid:
                        point=Vector((mid[0]+a*(mid[1]-mid[0])+b*(mid[2]-mid[0])).tolist())
                        hit,_,index,_=tree.ray_cast(point+toward*30,-toward)
                        if hit is not None and owners[index]==obj.get('piece_id'):visible+=1
                        elif hit is not None:occluders[owners[index]]=occluders.get(owners[index],0)+1
            values[obj['piece_id']]={'facing':bool(facing),'visible_samples':visible,'total_samples':grid*grid,'visible_pane_equivalent':visible/(grid*grid),'occluding_pieces':occluders}
        equivalents=sum(r['visible_pane_equivalent'] for r in values.values())
        views[view]={'panes':values,'visible_pane_equivalents':equivalents,
                     'passed':equivalents>=spec['dimensions']['lantern_clear_pane_equivalents_min']}
    candle_spec={**spec,'native_features':{'candle':{'part':'lantern','objects':['candle_glow'],'visibility':{'front':'visible','rear':'visible'}}}}
    candle=feature_report(candle_spec,[o for o in objects if not o.get('piece_id','').startswith('lantern_pane_')])['candle']
    return {'passed':candle['passed'] and all(r['passed'] for r in views.values()),'candle':candle,'views':views,
        'definition':'Native pane mid-surfaces sampled at cell centres, in the actual half-turn cameras. One wholly exposed facing pane is one equivalent. At least two are required in each view. Glass stays in owner maps/solos and is transparent only to candle rays/clay.'}

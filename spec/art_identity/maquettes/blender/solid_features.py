"""Actual native mesh ownership and occlusion for whole maquette features."""

FEATURE_DEFAULTS = {'ray_distance': 30., 'ray_epsilon': 1e-5}


def feature_report(spec, objects):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from ..raster import camera

    vertices, faces, owners = [], [], []
    by_piece = {o.get('piece_id'): o for o in objects}
    for obj in objects:
        start=len(vertices)
        vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        faces.extend([start+i for i in face.vertices] for face in obj.data.polygons)
        owners.extend([obj.get('piece_id')]*len(obj.data.polygons))
    tree=BVHTree.FromPolygons(vertices,faces)
    reports={}
    for name,feature in spec.get('native_features',{}).items():
        pieces=[by_piece.get(identifier) for identifier in feature['objects']]
        present=all(p is not None and p.get('part')==feature['part'] for p in pieces)
        checks={'whole_feature_ownership':present}
        visibility={}
        for view,wanted in feature.get('visibility',{}).items():
            matrix,_,basis,_=camera(spec,view)
            toward=Vector((basis[2] @ matrix[:3,:3]).tolist()).normalized()
            samples=[]
            if present:
                for obj in pieces:
                    samples.extend(obj.matrix_world @ face.center for face in obj.data.polygons)
                    samples.extend(obj.matrix_world @ vertex.co for vertex in obj.data.vertices)
            visible_points=[]
            for point in samples:
                origin=point+toward*FEATURE_DEFAULTS['ray_distance']
                hit,normal,index,distance=tree.ray_cast(origin,-toward)
                if hit is not None and owners[index] in feature['objects'] and (hit-point).length<=FEATURE_DEFAULTS['ray_epsilon']:
                    visible_points.append(list(point))
            count=len(visible_points)
            visibility[view]={'visible_surface_samples':count,'total_samples':len(samples),'expected':wanted,
                              'visible_points_body':visible_points}
            checks[view+'_visibility']=bool(samples) and (count>0 if wanted=='visible' else count==0)
        reports[name]={'checks':checks,'visibility':visibility,'passed':all(checks.values())}
    return reports

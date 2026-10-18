"""Actual evaluated-mesh contacts; detached feet cannot pass on silhouette alone."""

CONTACT_DEFAULTS={'ground_epsilon':1e-5}


def report(spec, objects):
    from mathutils.bvhtree import BVHTree
    by_id={o.get('piece_id'):o for o in objects}
    trees={}
    def tree(name):
        if name not in trees:
            obj=by_id[name]
            trees[name]=BVHTree.FromPolygons([obj.matrix_world @ v.co for v in obj.data.vertices],
                                            [list(p.vertices) for p in obj.data.polygons])
        return trees[name]
    pairs={}
    for a,b in spec.get('native_contacts',[]):
        count=len(tree(a).overlap(tree(b))) if a in by_id and b in by_id else 0
        pairs[a+'/'+b]={'surface_intersections':count,'passed':count>0}
    supports={}
    for piece in spec['pieces']:
        if 'support_z' not in piece:continue
        obj=by_id.get(piece['id'])
        heights=[(obj.matrix_world @ v.co).z for v in obj.data.vertices] if obj else []
        error=abs(min(heights)-piece['support_z']) if heights else None
        thickness=max(heights)-min(heights) if heights else 0
        supports[piece['id']]={'plane_z':piece['support_z'],'contact_error':error,
            'thickness':thickness,'passed':bool(heights) and error<=CONTACT_DEFAULTS['ground_epsilon'] and thickness>=piece['minimum_support_thickness']}
    feet={}
    if spec.get('foot_contacts'):
        from .foot_projection import FOOT_LIMITS
        plane=spec['foot_contacts']['plane_z']
        for name in spec['foot_contacts']['pieces']:
            obj=by_id.get(name)
            heights=[(obj.matrix_world @ v.co).z for v in obj.data.vertices] if obj else []
            error=abs(min(heights)-plane) if heights else None
            feet[name]={'minimum_z':min(heights) if heights else None,'plane_z':plane,
                'ground_error_m':error,'passed':bool(heights) and error<=FOOT_LIMITS['ground_tolerance_m']}
    return {'pairs':pairs,'supports':supports,'feet':feet,
            'passed':all(v['passed'] for v in list(pairs.values())+list(supports.values())+list(feet.values()))}

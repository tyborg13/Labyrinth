"""A free back cape gathered onto the posed shoulder seam under gravity.

A collision-free sheet is the sewn rest mesh. Its measured fabric allowance
is gathered to the native shoulder span; the solver, rather than an expanded
body shell, forms the folds. The final hem is bounded by both identity views.
"""
import json
import numpy as np

BACK_SHEET_DEFAULTS={'revision':2}


def frame(spec,config):
    near,far=(np.array(spec['joints'][j],float) for j in config['shoulders'])
    lateral=near-far;lateral[2]=0;lateral/=np.linalg.norm(lateral)
    forward=np.cross(lateral,[0,0,1])
    return near,far,lateral,forward


def draft(spec,config,physics,identifier,part):
    from .source_recipe import cloth
    near,far,lateral,forward=frame(spec,config)
    centre=(near+far)/2
    width=config['width_px']*spec['ortho_scale']/256
    rows=[]
    for drop in (0,config['height_px']*spec['ortho_scale']/256):
        rows.append([(centre+lateral*(t-.5)*width-[0,0,drop]).tolist() for t in np.linspace(0,1,config['columns'])])
    return cloth(identifier,part,'cloak',rows,False,physics)


def make(obj,body,piece,spec):
    from mathutils import Vector
    from .drape_collision import closed_anatomy,COLLIDER_DEFAULTS
    from .conformance import body_tree
    from .source_recipe import bounded_hem
    config=piece['drape']['back_sheet']
    near,far,lateral,forward=frame(spec,config)
    if config.get('side','back')=='front':forward=-forward
    centre=(near+far)/2
    width=config['width_px']*spec['ortho_scale']/256
    columns=piece['pattern']['columns']
    count=len(obj.data.vertices)//columns
    if count*columns!=len(obj.data.vertices):raise ValueError('Back sheet requires an uncut sewn grid')
    support=closed_anatomy(body);tree=body_tree(support)
    targets=[]
    for t in np.linspace(0,1,columns):
        position=(1-t)*far+t*near
        origin=Vector(position-forward*spec['ortho_scale'])
        hit,_,_,_=tree.ray_cast(origin,Vector(forward))
        if hit is not None:
            position+=forward*(np.dot(np.array(hit)-position,forward)-piece.get('solver_margin',piece['collision_margin'])-piece['thick']/2)
        targets.append(position.tolist())
    # The hem is measured at the final shoulder depth. Starting behind the
    # furthest bent leg instead introduces a large, unintended forward pull
    # during gathering and rolls the cape into a band at the waist.
    plane=float(np.mean(np.array(targets)@forward))
    top=np.array([(centre+lateral*(t-.5)*width).tolist() for t in np.linspace(0,1,columns)])
    top+=(plane-top@forward)[:,None]*forward
    bottom=top-np.array([0,0,config['height_px']*spec['ortho_scale']/256])
    bottom=np.array(bounded_hem(spec,bottom.tolist(),config['hem_px']))
    margin=piece.get('solver_margin',piece['collision_margin'])+COLLIDER_DEFAULTS['initial_clearance']+piece['thick']/2
    for row,t in enumerate(np.linspace(0,1,count)):
        for col in range(columns):
            position=(1-t)*top[col]+t*bottom[col]
            hit,_,_,_=tree.ray_cast(Vector(position-forward*spec['ortho_scale']),Vector(forward))
            if hit is not None:
                position+=forward*min(0,np.dot(np.array(hit)-position,forward)-margin)
            obj.data.vertices[row*columns+col].co=position
    obj.data.update()
    obj['back_sheet_report']=json.dumps({'defaults':BACK_SHEET_DEFAULTS,'fabric_width':width,
        'shoulder_span':float(np.linalg.norm(near-far)),'initial_plane':plane,'columns':columns,'rows':count,
        'pin_targets':targets,'hem_basis':'Both approved identity contours; no per-view cloth state'})
    return list(range(columns))

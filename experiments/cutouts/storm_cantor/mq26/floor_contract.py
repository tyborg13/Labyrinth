"""Painted-cell floor support, inherited from the approved Reaver contract."""
import math
import numpy as np
from maquette_motion.features import source_pixels
def hull(points):
    points=sorted(set(map(tuple,points)))
    def cross(a,b,c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    def half(points):
        out=[]
        for p in points:
            while len(out)>1 and cross(out[-2],out[-1],p)<=0: out.pop()
            out.append(p)
        return out
    return half(points)[:-1]+half(points[::-1])[:-1]


def apply(layout, data, root):
    images=[source_pixels(root,p) for p in layout['parts'] if p['logical_part']=='staff']
    opaque=np.logical_or.reduce([im[...,3]>0 for im in images]);y,x=np.nonzero(opaque)
    points=hull([(int(px+dx),int(py+dy)) for px,py in zip(x,y) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])
    view=layout['facing'];track=next(t for t in data['view_tracks'][view]['death'] if t['source']=='staff.angle_deg')
    keyed=track['keys'][-1]['value'];direction=math.copysign(1,keyed)
    bound=95.0  # Director feedback 2, section 6.
    bottom=max(p[1] for p in points);contacts=[p for p in points if p[1]==bottom]
    contact=(min if direction<0 else max)(contacts,key=lambda p:p[0]);limits=[]
    for px,py in points:
        dx,dy=px-contact[0],py-contact[1]
        if not (dx or dy):continue
        angle=math.atan2(-dy,dx)
        for theta in (angle,angle-math.pi,angle+math.pi):
            if 1e-8<theta*direction<=math.radians(bound)+1e-8:limits.append(theta)
    first=min(limits,key=abs) if limits else math.radians(bound)*direction
    # A bevel on the small butt is an intermediate rolling contact, not the
    # long staff lying flat. Select the longest supporting hull edge in the
    # director's direction; support remains on the floor through the roll.
    supports=[]
    for a,b in zip(points,points[1:]+points[:1]):
        dx,dy=b[0]-a[0],b[1]-a[1]
        angle=-math.atan2(dy,dx)
        for theta in (angle,angle-math.pi,angle+math.pi):
            if not 1e-8<theta*direction<=math.radians(bound)+1e-8:continue
            heights=[p[0]*math.sin(theta)+p[1]*math.cos(theta) for p in points]
            edge=a[0]*math.sin(theta)+a[1]*math.cos(theta)
            if abs(edge-max(heights))<1e-7:supports.append((math.hypot(dx,dy),theta,[a,b]))
    support=max(supports,key=lambda r:r[0]) if supports else None
    stop=support[1] if support else first
    grip=np.asarray(layout['joints']['staff']['position'])
    layout['held_items']['staff'].update(floor_end=list(contact),painted_floor={'points_local':(np.asarray(points)-grip).tolist(),'contact_source':list(contact),'limit_deg':math.degrees(stop),'keyed_direction':direction,'bound_deg':bound,'second_support_reached':bool(limits),'status':'PASS' if limits else 'BOUND_REACHED'})
    data['view_held_drops'][view]['death']['staff'].update(floor_limit_deg=math.degrees(stop),rotation_sign=1.,floor_travel_deg=bound,floor_key_limit_deg=abs(keyed),support_points_local=(np.asarray(points)-grip).tolist())
    return {'angle_deg':math.degrees(stop),'first_contact':list(contact),'first_local_support_deg':math.degrees(first),'long_support_edge':support[2] if support else None,'hull_source':points,'protected_direction':direction,'support_direction':direction,'rotation_sign':1.,'bound_deg':bound,'second_support_reached':bool(support),'rule':'Continuous floor support through local butt bevels to the longest supporting silhouette edge; director topple-flat intent, unchanged keyed direction and 95-degree bound','status':'PASS' if support else 'BOUND_REACHED'}


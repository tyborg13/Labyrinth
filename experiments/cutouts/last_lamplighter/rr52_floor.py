"""Painted lantern floor support at the director's feedback-1 accepted stops."""
import math
import numpy as np
from maquette_motion.features import source_pixels
DIRECTOR_STOP_DEG={'front':26.56505117707799,'rear':-10.304846468766023}
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


def floor_contract(layout, data, root):
    images=[source_pixels(root,p) for p in layout['parts'] if p['logical_part']=='lantern']
    opaque=np.logical_or.reduce([im[...,3]>0 for im in images]);y,x=np.nonzero(opaque)
    points=hull([(int(px+dx),int(py+dy)) for px,py in zip(x,y) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])
    view=layout['facing'];track=next(t for t in data['view_tracks'][view]['death'] if t['source']=='lantern.angle_deg')
    keyed=track['keys'][-1]['value'];direction=math.copysign(1,keyed)
    bound=95.0  # Director death drop bound.
    bottom=max(p[1] for p in points);contacts=[p for p in points if p[1]==bottom]
    contact=(min if direction<0 else max)(contacts,key=lambda p:p[0]);limits=[]
    for px,py in points:
        dx,dy=px-contact[0],py-contact[1]
        if not (dx or dy):continue
        angle=math.atan2(-dy,dx)
        for theta in (angle,angle-math.pi,angle+math.pi):
            if 1e-8<theta*direction<=math.radians(bound)+1e-8:limits.append(theta)
    measured_stop=min(limits,key=abs) if limits else math.radians(bound)*direction
    stop=math.radians(DIRECTOR_STOP_DEG[view])
    if stop*direction<=0 or abs(stop)>abs(measured_stop)+1e-8:raise ValueError('Accepted floor stop exceeds the corrected painted support budget')
    grip=np.asarray(layout['joints']['lantern']['position'])
    layout['held_items']['lantern'].update(floor_end=list(contact),painted_floor={'points_local':(np.asarray(points)-grip).tolist(),'contact_source':list(contact),'limit_deg':math.degrees(stop),'keyed_direction':direction,'bound_deg':bound,'second_support_reached':abs(stop-measured_stop)<1e-8,'director_accepted_stop':True,'status':'PASS' if limits else 'BOUND_REACHED'})
    data['view_held_drops'][view]['death']['lantern'].update(floor_limit_deg=math.degrees(stop),rotation_sign=1.,floor_travel_deg=bound,floor_key_limit_deg=abs(keyed))
    return {'angle_deg':math.degrees(stop),'measured_next_support_deg':math.degrees(measured_stop),'first_contact':list(contact),'hull_source':points,'protected_direction':direction,'support_direction':direction,'rotation_sign':1.,'bound_deg':bound,'second_support_reached':abs(stop-measured_stop)<1e-8,'rule':'Feedback 1 accepted terminal angles; corrected opaque cell hull supplies the actual floor line. No full-side pose required.','budget_note':'Rear garment ownership repair moves the next support to -45 degrees; retain the director-accepted -10.304846468766023 degree stop.' if abs(stop-measured_stop)>1e-8 else None,'status':'PASS'}


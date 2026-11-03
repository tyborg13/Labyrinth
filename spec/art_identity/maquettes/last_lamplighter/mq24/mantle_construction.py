"""Extend only the retained shoulder mantle, against the actual iron meshes."""
import numpy as np
from .contact import triangles,ray_hits,inside
from ..forms import normal_sheet

CONSTRUCTION_DEFAULTS={'row_power':.5,'ray_epsilon':1e-9,'arc_samples':257,'coincident_root_epsilon':1e-7,'root_width_iterations':32,'spacing_iterations':8,'clearance_iterations':12}


def clear_facets(rows,spec,rule,tip_columns):
    """Conservative offset facets; keep neckline, hem roots and all Z fixed.

    A chord between individually clear columns can cut a convex joint. Project
    those sampled facets outward by the physical half-thickness margin. This
    is the finite-mesh equivalent of the prescribed continuous cloth offset.
    """
    H=spec['mq18']['height_m'];meshes=[];total=np.zeros_like(rows)
    for side in ('near','far'):
        for name,a,b in (('upper_plate_','shoulder','elbow'),('fore_plate_','elbow','hand'),('elbow_cop_','elbow','elbow')):
            q=next(p for p in spec['pieces'] if p['id']==name+side)
            meshes.append((triangles(np.asarray(q['vertices'])/H,q['faces']),np.asarray(spec['joints'][a+'_'+side])/H,np.asarray(spec['joints'][b+'_'+side])/H))
    for iteration in range(CONSTRUCTION_DEFAULTS['clearance_iterations']):
        q=normal_sheet('probe','torso','torso',rows,rule['standoff_over_H'],periodic=True);v=np.asarray(q['vertices']);groups=[([i],point) for i,point in enumerate(v)]
        groups += [(face,v[face].mean(0)) for face in q['faces']]
        corrections=np.zeros((343,3));counts=np.zeros(343);bad=0
        for mesh,start,end in meshes:
            lo=mesh.min((0,1));hi=mesh.max((0,1));axis=end-start
            for indices,point in groups:
                if not np.all((point>lo)&(point<hi)) or not inside(point,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon']):continue
                bad+=1;controls={i%343 for i in indices};movable=[i for i in controls if 0<i//49<6 or (i//49==6 and i%49 in tip_columns)]
                if not movable:continue
                t=np.dot(point-start,axis)/np.dot(axis,axis) if np.dot(axis,axis)>0 else 0
                centre=start+np.clip(t,0,1)*axis;direction=point-centre;direction[2]=0
                if np.linalg.norm(direction)==0:direction=np.array([1.,0,0])
                direction/=np.linalg.norm(direction);hits=ray_hits(point,direction,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon'])
                if not len(hits):continue
                shift=direction*(max(hits)+rule['standoff_over_H']/2)*len(controls)/len(movable)
                for i in movable:corrections[i]+=shift;counts[i]+=1
        if not bad:return rows,{'passes':iteration,'maximum_xy_correction_over_H':float(np.linalg.norm(total[:,:,:2],axis=2).max()),'remaining_inside_samples':0}
        delta=np.divide(corrections,counts[:,None],out=np.zeros_like(corrections),where=counts[:,None]>0).reshape(7,49,3);rows+=delta;total+=delta
    raise ValueError('Mantle facets still intersect iron after bounded clearance solve')


def build(spec,rule):
    H=spec['mq18']['height_m'];j=spec['joints']
    piece=next(p for p in spec['pieces'] if p['id']=='shoulder_mantle')
    p=np.asarray(piece['vertices'])/H;rows=((p[:343]+p[343:])/2).reshape(7,49,3);original=rows.copy()
    hem=rows[-1].copy();edges=np.linalg.norm(np.roll(hem,-1,axis=0)-hem,axis=1);arc=np.r_[0,np.cumsum(edges[:-1])]
    diagnostics={}
    for side,sign in (('near',1),('far',-1)):
        shoulder=np.asarray(j['shoulder_'+side])/H;elbow=np.asarray(j['elbow_'+side])/H;axis=elbow-shoulder
        selected=np.flatnonzero(sign*hem[:,1]>=sign*shoulder[1]);start,end=selected[0],selected[-1]
        lengths=rule[side+'_lengths_over_H']
        # Allocate existing hem stations to exact roots/tips while preserving
        # the cyclic vertex count and the entire neckline.
        tips=np.round(np.linspace(start+1,end-1,len(lengths))).astype(int)
        if side=='far':tips=tips[::-1]
        desired_z=shoulder[2]-rule['drop_over_H'];mesh=np.concatenate([
            triangles(np.asarray(q['vertices'])/H,q['faces']) for q in spec['pieces'] if q['id'] in ('upper_plate_'+side,'fore_plate_'+side,'elbow_cop_'+side)])
        upper=np.asarray(next(q['vertices'] for q in spec['pieces'] if q['id']=='upper_plate_'+side))/H
        shoulder_support_z=upper.reshape(2,6,24,3)[0,1].mean(0)[2]
        centre=shoulder+np.clip((desired_z-shoulder[2])/axis[2],0,1)*axis;centre[2]=desired_z
        curve=[];angles=np.linspace(0,np.pi,CONSTRUCTION_DEFAULTS['arc_samples'])
        if side=='far':angles=-angles
        for angle in angles:
            direction=np.array([np.cos(angle),np.sin(angle),0.]);hits=ray_hits(centre,direction,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon'])
            if not len(hits):raise ValueError('No live arm envelope under mantle')
            curve.append(centre+direction*(max(hits)+rule['standoff_over_H']))
        curve=np.asarray(curve);curve_s=np.r_[0,np.cumsum(np.linalg.norm(np.diff(curve,axis=0),axis=1))];width=rule['tongue_root_width_over_H']
        def sampled(s):return np.array([np.interp(s,curve_s,curve[:,k]) for k in range(3)])
        def half_span(s):
            lo,hi=0.,width
            for _ in range(CONSTRUCTION_DEFAULTS['root_width_iterations']):
                mid=(lo+hi)/2
                if np.linalg.norm(sampled(s+mid)-sampled(s-mid))<width:lo=mid
                else:hi=mid
            return (lo+hi)/2
        spacing=width
        for _ in range(CONSTRUCTION_DEFAULTS['spacing_iterations']):
            tongue_centres=curve_s[-1]/2+(np.arange(len(lengths))-(len(lengths)-1)/2)*spacing
            spans=[half_span(s) for s in tongue_centres]
            spacing=float(np.mean([spans[k]+spans[k+1] for k in range(len(spans)-1)]))
        column_values={}
        for tip,s,half in zip(tips,tongue_centres,spans):
            direction=1 if side=='near' else -1
            for column,value in ((tip-direction,s-half),(tip,s),(tip+direction,s+half)):
                column_values.setdefault(column,[]).append(value)
        column_s={column:float(np.mean(values)) for column,values in column_values.items()}
        ordered=sorted(column_s)
        for a,b in zip(ordered,ordered[1:]):
            if abs(column_s[a]-column_s[b])<CONSTRUCTION_DEFAULTS['coincident_root_epsilon']:
                column_s[b]+=CONSTRUCTION_DEFAULTS['coincident_root_epsilon']*(1 if side=='near' else -1)
        for column in range(49):
            distance=max(arc[start]-arc[column],arc[column]-arc[end],0)
            influence=1. if start<=column<=end else ((1+np.cos(np.pi*distance/rule['transition_arc_over_H']))/2 if distance<rule['transition_arc_over_H'] else 0.)
            if influence==0:continue
            drop=0.
            for tip,length in zip(tips,lengths):
                if column==tip:drop=length
            z=hem[column,2]*(1-influence)+(desired_z-drop)*influence
            angle=np.arctan2(hem[column,1]-shoulder[1],hem[column,0]-shoulder[0])
            if start<=column<=end:
                s=column_s.get(column,float(np.interp(column,ordered,[column_s[k] for k in ordered])))
                angle=float(np.interp(s,curve_s,angles))
            direction=np.array([np.cos(angle),np.sin(angle),0.])
            for row in range(1,7):
                t=(row/6)**CONSTRUCTION_DEFAULTS['row_power'];point=original[row,column].copy();point[2]+=t*(z-hem[column,2])
                at=(point[2]-shoulder[2])/axis[2];centre=shoulder+np.clip(at,0,1)*axis;centre[2]=point[2]
                probe_z=min(point[2],shoulder_support_z)
                probe=shoulder+np.clip((probe_z-shoulder[2])/axis[2],0,1)*axis;probe[2]=probe_z
                hits=ray_hits(probe,direction,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon'])
                if len(hits):
                    radius=max(hits)+rule['standoff_over_H'];outer=probe+direction*radius
                    blend=influence;point[:2]=point[:2]*(1-blend)+outer[:2]*blend
                    # If an intermediate interpolation enters the iron, seat
                    # it on the same physical envelope instead of moving iron.
                    radial=point-centre;radial[2]=0;distance_from_axis=np.linalg.norm(radial)
                    if distance_from_axis:
                        d=radial/distance_from_axis;contact=ray_hits(centre,d,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon'])
                        if len(contact) and distance_from_axis<max(contact)+rule['standoff_over_H']:
                            point[:2]=(centre+d*(max(contact)+rule['standoff_over_H']))[:2]
                if column not in selected and sign*point[1]>=sign*shoulder[1]:point[1]=shoulder[1]-sign*CONSTRUCTION_DEFAULTS['coincident_root_epsilon']
                if inside(point,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon']):
                    # Clamping a transition to the torso side of the shoulder
                    # line must not push it through the iron. Keep Y/Z fixed
                    # and recover the actual front/back surface along X.
                    outward=np.array([1. if point[0]>=centre[0] else -1.,0,0])
                    hits=ray_hits(point,outward,mesh,CONSTRUCTION_DEFAULTS['ray_epsilon'])
                    if len(hits):point+=outward*(max(hits)+rule['standoff_over_H'])
                rows[row,column]=point
        diagnostics[side]={'hem_columns':selected.tolist(),'tongue_tip_columns':tips.tolist(),'tongue_lengths_over_H':lengths,
            'tongue_root_width_over_H':rule['tongue_root_width_over_H'],'neckline_preserved':bool(np.array_equal(rows[0],original[0]))}
    rows,diagnostics['facet_clearance']=clear_facets(rows,spec,rule,set(diagnostics['near']['tongue_tip_columns']+diagnostics['far']['tongue_tip_columns']))
    return rows*H,diagnostics

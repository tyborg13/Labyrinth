"""Plate and torn-cloth observations from native topology and vertex positions."""
from collections import defaultdict
import math
import numpy as np
from .geometry import sheet_boundaries
from .pauldrons import TOPOLOGY
from ..forms import TOPOLOGY as FORM_TOPOLOGY
from ..native_checks import NATIVE_DEFAULTS


def rivets(points,part,centre,axes,H,surface,thickness,tolerance):
    """Recover each opened rivet's bounds in the measured plate frame."""
    targets=surface['rivets_yz_over_H'];result={};passed=bool(targets)
    for face,sign in [('front',1),('back',-1)]:
        names=sorted((n for n in points if n.startswith(part+'_'+face+'_rivet_')),
            key=lambda n:int(n.rsplit('_',1)[1]))
        passed &= len(names)==len(targets);result[face]=[]
        for name,(y,z) in zip(names,targets):
            local=(points[name]-centre)@axes.T
            location=(local.min(0)+local.max(0))/(2*H)
            radii=np.ptp(local,axis=0)/(2*H)
            target=np.array([sign*(thickness/2+surface['rim_proud_over_H']),y,z])
            good=bool(np.all(abs(location-target)<=tolerance) and
                np.all(abs(radii-surface['rivet_radius_over_H'])<=tolerance))
            passed &= good
            result[face].append({'name':name,'centre_local_over_H':location.tolist(),
                'target_centre_local_over_H':target.tolist(),'radii_over_H':radii.tolist(),
                'target_radius_over_H':surface['rivet_radius_over_H'],'tolerance':tolerance,'within_tolerance':good})
    return result,bool(passed)


def groups(edges):
    neighbours=defaultdict(set)
    for f in edges:
        for a,b in zip(f,f[1:]+f[:1]):neighbours[a].add(b);neighbours[b].add(a)
    result=[]
    while neighbours:
        pending=[next(iter(neighbours))];found=set()
        while pending:
            k=pending.pop()
            if k in found:continue
            found.add(k);pending.extend(neighbours.pop(k,()))
        result.append(sorted(found))
    return result


def observe(spec,points,faces,j,H,L,row,checks):
    d=spec['dimensions'];details={};values=spec['mq20']['design_values']
    tolerance=NATIVE_DEFAULTS['normalized_position_tolerance']
    for side,sign in [('near',1),('far',-1)]:
        part='pauldron_'+side;name=part+'_panel'
        if name not in points:checks[part+'_present']=False;continue
        panel=points[name];count=4*TOPOLOGY['corner_samples'];back=panel[-count:]
        eigen,vectors=np.linalg.eigh(np.cov(back.T));up=vectors[:,np.argsort(eigen)[1]];lateral=vectors[:,np.argmax(eigen)]
        if up[2]<0:up=-up
        if lateral[1]<0:lateral=-lateral
        normal=np.cross(lateral,up)
        if normal[0]<0:normal=-normal
        # The symmetric back contour is half a measured thickness behind
        # the plate centre. Do not infer position from its authoring target.
        thickness=np.ptp(panel@normal)
        centre=back.mean(0)+normal*thickness/2
        offset=(centre-j['shoulder_'+side])[:2]/H
        target_offset=values['pauldron_placement'][side+'_xy_over_H']
        placed=bool(np.all(abs(offset-target_offset)<=tolerance))
        for label,axis,target in [('width',lateral,d['pauldron_width_over_H']),('height',up,d['pauldron_height_over_H']),('thickness',normal,d['pauldron_thickness_over_H'])]:
            row(7,part+'_'+label+'_over_H',np.ptp(np.einsum('nj,j->n',panel,axis))/H,target)
        row(7,part+'_outward_degrees',math.degrees(math.atan2(sign*up[1],up[2])),d['pauldron_outward_degrees'],True)
        cross=points[part+'_cross'];row(7,part+'_cross_proud_over_H',((np.einsum('nj,j->n',cross,normal)).max()-(np.einsum('nj,j->n',panel,normal)).max())/H,d['pauldron_cross_proud_over_H'])
        row(7,part+'_hood_top_gap_over_H',(H-panel[:,2].max())/H,values['pauldron_placement']['hood_top_gap_over_H'])
        edge=panel[1+(TOPOLOGY['radial_stations']-2)*count:1+(TOPOLOGY['radial_stations']-1)*count]
        row(7,part+'_convexity_over_H',((np.einsum('nj,j->n',panel,normal)).max()-(np.einsum('nj,j->n',edge,normal)).mean())/H,values['pauldron_surface']['convexity_over_H'])
        checks[part+'_front_cross_only']=bool((np.einsum('nj,j->n',cross,normal)).min()>=(np.einsum('nj,j->n',panel,normal)).max()-1e-6)
        owned=[p for p in spec['pieces'] if p['part']==part]
        checks[part+'_torso_owned']=bool(owned) and all(p.get('rig_bone')=='torso' and p.get('rig_pivot_joint')=='torso' for p in owned)
        expected=len(values['pauldron_surface']['rivets_yz_over_H'])
        checks[part+'_rim_and_rivets']=part+'_rims' in points and all(sum(n.startswith(part+'_'+face+'_rivet_') for n in points)==expected for face in ('front','back')) and expected>0
        rivet_details,finish=rivets(points,part,centre,np.array([normal,lateral,up]),H,
            values['pauldron_surface'],d['pauldron_thickness_over_H'],tolerance)
        checks[part+'_rim_and_rivets'] &= finish
        mantle=points['shoulder_mantle'];origin=back.mean(0)
        local=np.column_stack([np.einsum('nj,j->n',mantle-origin,a) for a in (normal,lateral,up)])
        supported=(local[:,0]>=-.01*H)&(local[:,0]<=d['pauldron_thickness_over_H']*H+.01*H)&(abs(local[:,1])<d['pauldron_width_over_H']*H/2)
        bottom=(np.einsum('nj,j->n',back-origin,up)).min()
        support_error=abs(float(local[supported,2].max()-bottom))/H if supported.any() else None
        checks[part+'_stands_on_shoulder']=support_error is not None and support_error<=.01
        if part+'_mount' in points:
            ends=points[part+'_mount'].reshape(-1,FORM_TOPOLOGY['sweep_samples'],3).mean(1)
            mount_local=np.column_stack([np.einsum('nj,j->n',ends-origin,a) for a in (normal,lateral,up)])
            contact_error=min(np.linalg.norm(ends[0]-v) for v in mantle)/H
            top_seated=(0<=mount_local[-1,0]<=d['pauldron_thickness_over_H']*H and
                        abs(mount_local[-1,1])<d['pauldron_width_over_H']*H/2 and mount_local[-1,2]>=bottom)
            checks[part+'_stands_on_shoulder']=contact_error<=1e-5 and bool(top_seated)
            details[part+'_mount']={'mantle_contact_error_over_H':contact_error,'top_seated_in_panel':bool(top_seated)}
        checks[part+'_stands_on_shoulder'] &= placed
        details[part]={'back_normal':normal.tolist(),'top_z_m':float(panel[:,2].max()),'rivets_per_face':expected,'shoulder_support_error_over_H':support_error,
            'centre_m':centre.tolist(),'shoulder_relative_xy_over_H':offset.tolist(),
            'target_shoulder_relative_xy_over_H':target_offset,'offset_tolerance':tolerance,
            'offsets_within_tolerance':placed,'rivets':rivet_details}
    metadata=spec['mq20'].get('robe_grid')
    if metadata:
        robe=points['tattered_robe'];count=len(robe)//2;mid=(robe[:count]+robe[count:])/2
        surface,boundaries,loops=sheet_boundaries(faces['tattered_robe'],count)
        boundary_groups=groups(boundaries);outer=max(boundary_groups,key=len);holes=[g for g in boundary_groups if g is not outer]
        diameters=[max(np.linalg.norm(a-b) for a in mid[g] for b in mid[g])/H for g in holes]
        checks['four_real_holes']=loops-1==d['robe_hole_count']
        lo,hi=d['robe_hole_diameter_over_H_range'];checks['hole_diameters']=all(lo-.01<=v<=hi+.01 for v in diameters)
        seam=spec['mq20']['robe_seam_z_m'];lo,hi=d['robe_strand_length_over_H_range']
        indices=np.asarray(metadata['source_vertex_indices']);nc=metadata['grid_shape'][1]
        below=groups([f for f in surface if mid[f,2].max()<seam-lo*H/2])
        below.sort(key=lambda g:np.mean(indices[g]%nc))
        lengths=[(seam-mid[g,2].min())/H for g in below]
        widths=[np.linalg.norm(np.ptp(mid[g,:2],axis=0))/H for g in below]
        checks['ten_long_strands']=len(below)==d['robe_strand_count']
        targets=[s['length_over_H'] for s in values['robe_layout']['strands']]
        checks['strand_lengths']=(len(lengths)==len(targets) and
            all(abs(measured-target)<=tolerance for measured,target in zip(lengths,targets)))
        checks['strand_lengths_vary']=bool(lengths) and np.ptp(lengths)>1e-5
        wlo,whi=d['robe_strand_width_over_H_range'];checks['strand_widths']=all(wlo-.01<=v<=whi+.01 for v in widths)
        if len(below)==len(values['robe_layout']['strands']):
            # The director orders the strands far-to-near along the open wrap.
            # Cell-sampled tips use the same prescribed tolerance as every
            # other strand, above; this separately checks the side ordering.
            checks['longest_strands_at_sides']=all(targets[i]>=max(targets)-.010000001 and abs(lengths[i]-targets[i])<=.01 for i in (0,len(below)-1))
        else:checks['longest_strands_at_sides']=False
        indices=np.asarray(metadata['source_vertex_indices']);nc=metadata['grid_shape'][1];upper_rows=(metadata['grid_shape'][0]+1)//2
        notches={}
        for label,col in [('near',0),('far',nc-1)]:
            present=set((indices[(indices%nc==col)&(indices//nc<upper_rows)]//nc).tolist())
            missing=[r for r in range(1,upper_rows-1) if r not in present]
            notches[label]=sum(k==0 or r>missing[k-1]+1 for k,r in enumerate(missing))
        nlo,nhi=d['robe_notches_per_front_edge_range'];checks['front_edge_notches']=all(nlo<=v<=nhi for v in notches.values())
        row(8,'robe_thickness_over_H',np.linalg.norm(robe[:count]-robe[count:],axis=1).min()/H,d['robe_thickness_over_H'])
        checks['robe_one_continuous_wrap']=len(groups(surface))==1
        details['robe']={'holes':loops-1,'hole_diameters_over_H':diameters,'strands':len(below),'strand_lengths_over_H':lengths,
            'target_strand_lengths_over_H':targets,'strand_length_tolerance':tolerance,'strand_widths_over_H':widths,'notches':notches}
    else:checks['mq20_robe_layout_present']=False
    # Retained identity volumes remain independently measurable.
    for label,name in [('hood','draped_hood')]:
        v=points[name];n=len(v)//2;row('volumes',label+'_thickness_over_H',np.linalg.norm(v[:n]-v[n:],axis=1).min()/H,d[label+'_thickness_over_H'])
    roll=points['cowl_rolled_edge'].reshape(-1,FORM_TOPOLOGY['sweep_samples'],3);centres=roll.mean(1)
    row('volumes','cowl_roll_diameter_over_H',2*np.linalg.norm(roll-centres[:,None],axis=2).mean()/H,d['cowl_roll_diameter_over_H'])
    cage=points['curved_birdcage']
    row('volumes','cage_height_over_H',np.ptp(cage[:,2])/H,d['cage_height_over_H'])
    row('volumes','cage_width_over_H',max(np.ptp(cage[:,0]),np.ptp(cage[:,1]))/H,d['cage_width_over_H'])
    return details

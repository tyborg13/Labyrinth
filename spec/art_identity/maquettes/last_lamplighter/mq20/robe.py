"""Cut real holes, edge notches and ten strands into the inherited folded wrap.

The layout is owner data. Subdivision and cell clipping are numerical controls;
neither an unpainted hole nor a strand is simulated by a dark decal.
"""
from collections import Counter
import numpy as np
from ..forms import shell
from ..garments import GARMENT_TOPOLOGY

TOPOLOGY={'rows':97,'columns':145}


def inside_polygon(x,y,profile):
    """Owner-authored 2D contour, sampled at native cell centres."""
    polygon=np.asarray(profile,float)
    if polygon.ndim!=2 or polygon.shape[1]!=2 or len(polygon)<3 or not np.isfinite(polygon).all():raise ValueError('Owner profile needs a finite closed polygon')
    inside=np.zeros(np.broadcast_shapes(np.shape(x),np.shape(y)),bool)
    for a,b in zip(polygon,np.roll(polygon,-1,axis=0)):
        if a[1]==b[1]:continue
        crossing=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]);inside ^= crossing
    return inside


def cut_sheet(rows,active,thickness):
    rows=np.asarray(rows);nr,nc,_=rows.shape
    normals=np.cross(np.gradient(rows,axis=1),np.gradient(rows,axis=0));normals/=np.linalg.norm(normals,axis=2)[:,:,None]
    surface=[]
    for r,c in zip(*np.where(active)):
        a=int(r*nc+c);surface.append([a,a+1,a+1+nc,a+nc])
    used=sorted({i for f in surface for i in f});lookup={old:new for new,old in enumerate(used)}
    surface=[[lookup[i] for i in f] for f in surface];count=len(used)
    mid=rows.reshape(-1,3)[used];normal=normals.reshape(-1,3)[used]
    vertices=np.concatenate([mid+normal*thickness/2,mid-normal*thickness/2])
    faces=[]
    for f in surface:faces.extend([f,[i+count for i in reversed(f)]])
    edges=Counter(tuple(sorted((a,b))) for f in surface for a,b in zip(f,f[1:]+f[:1]))
    for f in surface:
        for a,b in zip(f,f[1:]+f[:1]):
            if edges[tuple(sorted((a,b)))]==1:faces.append([a,a+count,b+count,b])
    piece=shell('tattered_robe','robe','torso',vertices.tolist(),faces)
    return piece,{'surface_vertex_count':count,'surface_faces':len(surface),'grid_shape':[nr,nc],'source_vertex_indices':used}


def inherited_wrap(spec):
    """Return the retained upper wrap and exact hem arc before any new cuts."""
    H=spec['mq18']['height_m'];d=spec['dimensions'];pieces=spec['pieces']
    original=next(p for p in pieces if p['id']=='tattered_robe');v=np.asarray(original['vertices']);n=len(v)//2
    grid=((v[:n]+v[n:])/2).reshape(GARMENT_TOPOLOGY['rows'],GARMENT_TOPOLOGY['columns'],3)
    seam=float(grid[-1,:,2].max());source_s=np.linspace(0,1,grid.shape[1]);s=np.linspace(0,1,TOPOLOGY['columns'])
    # Preserve every inherited fold and the upper wrap. The existing highest
    # hem station is the attachment line for the owner's new long strands.
    columns=np.stack([np.stack([np.interp(s,source_s,row[:,k]) for k in range(3)],axis=1) for row in grid])
    original_t=np.linspace(0,1,len(columns))
    for col in range(len(s)):
        source=columns[:,col].copy();crossing=np.flatnonzero(source[:,2]<=seam)
        last=int(crossing[0]) if len(crossing) else len(source)-1
        previous=max(0,last-1);denominator=source[previous,2]-source[last,2]
        root=original_t[previous]+(original_t[last]-original_t[previous])*(source[previous,2]-seam)/denominator if denominator>0 else original_t[last]
        for axis in range(3):columns[:,col,axis]=np.interp(original_t*root,original_t,source[:,axis])
    columns[-1,:,2]=seam
    arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(columns[-1,:,:2],axis=0),axis=1))]
    return original,columns,seam,s,arc


def replace(spec,layout):
    if layout is None:return
    H=spec['mq18']['height_m'];d=spec['dimensions'];pieces=spec['pieces']
    original,columns,seam,s,arc=inherited_wrap(spec)
    strands=layout['strands']
    if len(strands)!=d['robe_strand_count']:raise ValueError('Owner layout requires ten strands')
    occupied=[]
    for index,strand in enumerate(strands):
        width=strand['width_over_H'];length=strand['length_over_H']
        if not d['robe_strand_width_over_H_range'][0]<=width<=d['robe_strand_width_over_H_range'][1]:raise ValueError('Strand width outside brief')
        if not d['robe_strand_length_over_H_range'][0]<=length<=d['robe_strand_length_over_H_range'][1]:raise ValueError('Strand length outside brief')
        start=strand['start_s']*arc[-1];end=start+width*H
        if not 0<=start<end<=arc[-1] or any(max(start,a)<min(end,b) for a,b in occupied):
            raise ValueError(f'Overlapping or off-wrap strands: strand {index}; start_s={strand["start_s"]}; '
                             f'interval_over_H=[{start/H:.12f}, {end/H:.12f}]; hem_arc_over_H={arc[-1]/H:.12f}')
        occupied.append((start,end))
    max_length=max(q['length_over_H'] for q in strands)*H
    # Include the seam explicitly, so all ten appendages attach to one wrap.
    source_t=np.linspace(0,1,len(columns));top_t=np.linspace(0,1,TOPOLOGY['rows'])
    upper=np.stack([np.stack([np.interp(top_t,source_t,columns[:,col,k]) for k in range(3)],axis=1) for col in range(len(s))],axis=1)
    lower=np.repeat(columns[-1:,:,:],TOPOLOGY['rows'],axis=0)
    depths=np.linspace(0,max_length,TOPOLOGY['rows']);lower[:,:,2]=seam-depths[:,None]
    rows=np.concatenate([upper,lower[1:]],axis=0)
    centres=(rows[:-1,:-1]+rows[1:,:-1]+rows[:-1,1:]+rows[1:,1:])/4
    active=np.ones(centres.shape[:2],bool)
    arc_mid=(arc[:-1]+arc[1:])/2;depth_mid=(depths[:-1]+depths[1:])/2
    lower_active=np.zeros((len(depth_mid),len(arc_mid)),bool)
    for strand,(start,end) in zip(strands,occupied):
        profile=np.asarray(strand['profile'],float)
        if np.any(profile<0) or np.any(profile>1):raise ValueError('Strand profile must fit its width/length rectangle')
        lower_active |= inside_polygon((arc_mid[None,:]-start)/(end-start),depth_mid[:,None]/(strand['length_over_H']*H),profile)
    active[TOPOLOGY['rows']-1:]=lower_active
    holes=layout['holes']
    if len(holes)!=d['robe_hole_count']:raise ValueError('Owner layout requires four holes')
    for hole in holes:
        diameter=hole['diameter_over_H']
        if not d['robe_hole_diameter_over_H_range'][0]<=diameter<=d['robe_hole_diameter_over_H_range'][1]:raise ValueError('Hole diameter outside brief')
        col=int(round(hole['s']*(len(s)-1)));row=int(round(hole['t']*(len(upper)-1)));centre=upper[row,col]
        tangent=upper[row,min(col+1,len(s)-1)]-upper[row,max(col-1,0)];tangent/=np.linalg.norm(tangent)
        vertical=upper[min(row+1,len(upper)-1),col]-upper[max(row-1,0),col];vertical-=tangent*np.dot(tangent,vertical);vertical/=np.linalg.norm(vertical)
        delta=centres-centre;profile=np.asarray(hole['profile'],float)
        if np.linalg.norm(profile,axis=1).max()>.5+1e-9:raise ValueError('Hole profile exceeds specified diameter')
        row_arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(upper[row],axis=0),axis=1))]
        along=((row_arc[:-1]+row_arc[1:])/2-row_arc[col])[None,:]
        cut=inside_polygon(along/(diameter*H),np.einsum('rcj,j->rc',delta,vertical)/(diameter*H),profile)
        active &= ~(cut&(np.linalg.norm(delta,axis=2)<diameter*H))
    for edge in ('near','far'):
        notches=layout['notches'][edge];lo,hi=d['robe_notches_per_front_edge_range']
        if not lo<=len(notches)<=hi:raise ValueError('Front edge needs two or three notches')
        for notch in notches:
            row=int(round(notch['t']*(len(upper)-1)));col=0 if edge=='near' else -1;centre=upper[row,col]
            tangent=upper[row,1]-upper[row,0] if edge=='near' else upper[row,-2]-upper[row,-1];tangent/=np.linalg.norm(tangent)
            vertical=upper[min(row+1,len(upper)-1),col]-upper[max(row-1,0),col];vertical-=tangent*np.dot(tangent,vertical);vertical/=np.linalg.norm(vertical)
            delta=centres-centre;size=notch['depth_over_H']*H
            row_arc=np.r_[0,np.cumsum(np.linalg.norm(np.diff(upper[row],axis=0),axis=1))]
            along=(row_arc[:-1]+row_arc[1:])/2
            if edge=='far':along=row_arc[-1]-along
            cut=inside_polygon(along[None,:]/size,np.einsum('rcj,j->rc',delta,vertical)/size,notch['profile'])
            active &= ~(cut&(np.linalg.norm(delta,axis=2)<size*2))
    piece,metadata=cut_sheet(rows,active,d['robe_thickness_over_H']*H)
    pieces[pieces.index(original)]=piece;spec['mq20']['robe_grid']=metadata
    spec['mq20']['robe_seam_z_m']=seam

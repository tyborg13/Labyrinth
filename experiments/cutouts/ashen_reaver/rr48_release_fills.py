"""Director r3: exact own-fist continuations, confined to release textures.

The front wrist's painted axis runs rightward into the forearm. Its nearest
complete uncovered cross-section is source column 105, rows 120..131 (both
outline ends included). The request clips that lower end; complete each axial
slice by only the missing cross-section cells. No scaling or new RGB is used.
"""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import digest
from maquette_motion.silhouette import components
from rr48_build import CASE

REQUESTS=CASE.parent/'underlay_requests/rr57_feedback2'
FRONT_WRIST={'axis':'x','direction':1,'source_column':105,'rows':[120,132]}


def bounds(mask):
    y,x=np.nonzero(mask)
    return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else []


def copy_texels(image,domain,source_uv):
    result=image.copy();records=[]
    for y,x in np.argwhere(domain & (image[...,3]==0)):
        u,v=source_uv(int(x),int(y))
        if not image[v,u,3]:continue  # Authored air is never manufactured paint.
        result[y,x]=image[v,u]
        records.append({'to':[int(x),int(y)],'from':[int(u),int(v)],'rgba':image[v,u].tolist()})
    return result,records


def front_wrist(image,request):
    recipe=FRONT_WRIST;domain=request.copy();lo,hi=recipe['rows'];column=recipe['source_column']
    if not np.all(image[lo:hi,column,3]):raise ValueError('Wrist cross-section no longer fully painted')
    # Each requested axial slice needs both ends of the existing cross-section.
    # Completing only these slices is the minimum extension for this row copy.
    for x in np.flatnonzero(request[lo:hi].any(axis=0)):domain[lo:hi,x]=True
    result,texels=copy_texels(image,domain,lambda x,y:(column,y))
    return result,domain,{'method':'repeat nearest complete own-wrist cross-section along painted x axis','measurement':recipe,'texels':texels}


def rear_fist(image,request):
    result=image.copy();records=[];transforms=[];labels,groups=components(request,8)
    yy,xx=np.nonzero(image[...,3]);painted=np.column_stack((xx,yy))
    for label,_ in groups:
        y,x=np.nonzero(labels==label);targets=np.column_stack((x,y))
        # Offsets and optional horizontal reflections are integer texel maps.
        # Derive candidates from existing paint, then choose the nearest whole
        # patch. Donors always come from the pre-fill fist, never new copies.
        best=None
        for mirror in (False,True):
            reflected=targets.copy()
            if mirror:reflected[:,0]=-reflected[:,0]
            offsets=np.unique(painted-reflected[0],axis=0)
            for offset in offsets:
                source=reflected+offset
                if (source<0).any() or (source>=255).any():continue
                if not np.all(image[source[:,1],source[:,0],3]):continue
                distances=np.sum((source-targets)**2,axis=1)
                score=(int(distances.max()),int(distances.sum()),int(mirror),int(abs(offset[1])),int(offset[0]),int(offset[1]))
                if best is None or score<best[0]:best=(score,source,mirror,offset)
        if best is None:raise ValueError('No exact adjacent own-fist donor patch')
        _,source,mirror,offset=best
        transforms.append({'target_bounds':bounds(labels==label),'mirror_x':mirror,'source_offset':list(map(int,offset))})
        for (tx,ty),(u,v) in zip(targets,source):
            if image[ty,tx,3]:continue
            result[ty,tx]=image[v,u];records.append({'to':[int(tx),int(ty)],'from':[int(u),int(v)],'rgba':image[v,u].tolist()})
    return result,request.copy(),{'method':'nearest complete adjacent own-fist offset/reflection patch','transforms':transforms,'texels':records}


def fill(view,image):
    path=REQUESTS/('front_empty_fist_seam.png' if view=='front' else 'rear_empty_fist.png')
    request=np.asarray(Image.open(path).convert('L'))>0
    result,domain,ledger=(front_wrist if view=='front' else rear_fist)(image,request)
    ledger.update(request_mask=str(path.relative_to(CASE.parent)),request_sha256=digest(path),
                  request_bounds=bounds(request),filled_domain_bounds=bounds(domain),
                  request_pixels=int(request.sum()),domain_pixels=int(domain.sum()),
                  widened_pixels=int((domain & ~request).sum()),
                  changed_pixels=int(np.any(result!=image,axis=-1).sum()),
                  preserves_existing_opaque=bool(np.array_equal(result[image[...,3]>0],image[image[...,3]>0])))
    return result,domain,ledger

"""Independent image and native-vertex measurements for director feedback 3."""
import math
import numpy as np

MEASURE_DEFAULTS = {'alpha_threshold':128, 'angle_step_deg':.25,
                    'smoothing_bins':7, 'minimum_tip_prominence_px':12.,
                    'hair_sector_deg':[-200.,60.], 'minimum_tip_separation_deg':10.}


def spike_tips(path, centre):
    """Prominent maxima of the rendered silhouette's radial envelope.

    This sees only pixels, not the recipe's lock count or control points. Each
    accepted tip needs a valley at least three source pixels deep on both sides.
    The sector excludes the mask/chin below the hair, and cannot count shading.
    """
    from PIL import Image
    with Image.open(path) as original:
        mask=np.asarray(original.convert('RGBA'))[:,:,3]>=MEASURE_DEFAULTS['alpha_threshold']
    inner=mask.copy()
    inner[1:-1,1:-1] &= (mask[:-2,1:-1]&mask[2:,1:-1]&mask[1:-1,:-2]&mask[1:-1,2:])
    yy,xx=np.nonzero(mask&~inner)
    dx,dy=xx+.5-centre[0],yy+.5-centre[1]
    lo,hi=MEASURE_DEFAULTS['hair_sector_deg'];step=MEASURE_DEFAULTS['angle_step_deg']
    angles=np.rad2deg(np.arctan2(dy,dx));angles=np.where(angles>hi,angles-360,angles)
    bins=np.arange(lo,hi+step,step);envelope=np.zeros(len(bins))
    valid=(angles>=lo)&(angles<=hi)
    np.maximum.at(envelope,np.minimum(((angles[valid]-lo)/step).astype(int),len(bins)-1),np.hypot(dx[valid],dy[valid]))
    occupied=np.flatnonzero(envelope)
    envelope=np.interp(np.arange(len(bins)),occupied,envelope[occupied])
    width=MEASURE_DEFAULTS['smoothing_bins'];half=width//2
    smooth=np.convolve(np.pad(envelope,(half,half),mode='edge'),np.ones(width)/width,mode='valid')
    peaks=np.flatnonzero((smooth[1:-1]>smooth[:-2])&(smooth[1:-1]>=smooth[2:]))+1
    rows=[]
    for p in peaks:
        left=p-1;right=p+1
        while left>0 and smooth[left]<=smooth[p]:left-=1
        while right<len(smooth)-1 and smooth[right]<=smooth[p]:right+=1
        prominence=min(smooth[p]-min(smooth[left:p+1]),smooth[p]-min(smooth[p:right+1]))
        if prominence>=MEASURE_DEFAULTS['minimum_tip_prominence_px']:
            angle=math.radians(bins[p]);rows.append({'angle_deg':float(bins[p]),'radius_px':float(smooth[p]),
                'prominence_px':float(prominence),'tip_px':[float(centre[0]+smooth[p]*math.cos(angle)),float(centre[1]+smooth[p]*math.sin(angle))]})
    selected=[]
    for row in sorted(rows,key=lambda r:-r['prominence_px']):
        if all(abs(row['angle_deg']-old['angle_deg'])>=MEASURE_DEFAULTS['minimum_tip_separation_deg'] for old in selected):selected.append(row)
    return {'count':len(selected),'tips':sorted(selected,key=lambda r:r['angle_deg']),
            'centre_px':list(centre),'minimum_prominence_px':MEASURE_DEFAULTS['minimum_tip_prominence_px']}


def vessel(vertices, bands, rim, axis, origin):
    """Measure actual frozen surface vertices in the vessel's tangent frame."""
    axis=np.asarray(axis,float);axis/=np.linalg.norm(axis);origin=np.asarray(origin,float)
    def extent(points):
        delta=np.array(points)-origin;z=delta@axis
        radial=np.linalg.norm(delta-z[:,None]*axis,axis=1)
        return z,radial
    z,_=extent(vertices);rz,rr=extent(rim)
    height=float(max(z.max(),rz.max())-min(z.min(),rz.min()))
    diameter=float(2*rr.max());rows=[]
    for name,points in bands.items():
        bz,br=extent(points)
        # Compare the outer belt face with the vessel skin at its axial level.
        vz,vr=extent(vertices)
        level=(bz.min()+bz.max())/2;near=abs(vz-level)
        skin=float(vr[near<=max(float(near.min())+1e-6, .01)].max())
        rows.append({'object':name,'width_m':float(np.ptp(bz)),
                     'width_height_ratio':float(np.ptp(bz)/height),
                     'raised_m':float(br.max()-skin),'referenced_vertices':len(points)})
    return {'height_m':height,'outer_rim_diameter_m':diameter,'height_diameter_ratio':height/diameter,
            'band_count':len(rows),'bands':rows}

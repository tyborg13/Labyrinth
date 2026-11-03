"""Feedback-1 measurements from source semantic masks and native part maps."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from spec.art_identity.maquettes.raster import project

MEASURE_DEFAULTS = {'palette_tolerance': 1, 'antialias_radius_px': 2, 'alpha_threshold': 128,
                    'scan_radius_px': 200, 'line_stations': 13, 'arm_inner_fractions': [.2,.8], 'boot_ankle_offset_px': 8}


def labels(path, palette):
    a=np.asarray(Image.open(path).convert('RGBA')).astype(int)
    colours=[]
    for rgb in palette.values():
        linear=np.asarray(rgb);colours.append(np.rint(np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)*255))
    return {name:(np.max(np.abs(a[:,:,:3]-colours[i]),axis=2)<=MEASURE_DEFAULTS['palette_tolerance'])&(a[:,:,3]>=128) for i,name in enumerate(palette)}


def span(mask, row):
    xs=np.flatnonzero(mask[int(round(row))]);return int(xs[-1]-xs[0]+1) if len(xs) else 0


def line_width(mask, center, axis):
    normal=np.array([-axis[1],axis[0]],float);normal/=np.linalg.norm(normal)
    t=np.arange(-MEASURE_DEFAULTS['scan_radius_px'],MEASURE_DEFAULTS['scan_radius_px']+1)
    p=np.rint(np.asarray(center)+t[:,None]*normal).astype(int)
    inside=(p[:,0]>=0)&(p[:,0]<mask.shape[1])&(p[:,1]>=0)&(p[:,1]<mask.shape[0])
    hit=np.zeros(len(t),bool);hit[inside]=mask[p[inside,1],p[inside,0]]
    # A contiguous labelled cross-section; unrelated fragments cannot inflate it.
    groups=np.split(np.flatnonzero(hit),np.flatnonzero(np.diff(np.flatnonzero(hit))>1)+1)
    return max((len(g) for g in groups),default=0)


def arm_width(mask, a, b):
    a,b=np.array(a),np.array(b);axis=b-a
    widths=[line_width(mask,a+t*axis,axis) for t in np.linspace(*MEASURE_DEFAULTS['arm_inner_fractions'],MEASURE_DEFAULTS['line_stations'])]
    return min(widths),widths


def projected_span(mask, axis):
    pixels=np.argwhere(mask)[:,::-1];axis=np.array(axis,float);axis/=np.linalg.norm(axis)
    if not len(pixels):return 0.
    values=(pixels*axis[None,:]).sum(axis=1);return float(values.max()-values.min()+1)


def source_measurements(folder, source):
    data=json.loads((folder/'mass_annotations.json').read_text());alpha=np.asarray(Image.open(source).convert('RGBA'))[:,:,3]>=128
    masks={}
    for name,polygon in data['source_masks'].items():
        im=Image.new('1',(alpha.shape[1],alpha.shape[0]));ImageDraw.Draw(im).polygon([tuple(p) for p in polygon],fill=1)
        masks[name]=np.asarray(im,dtype=bool)&alpha
    for name,path in data.get('source_mask_files',{}).items():
        masks[name]=(np.asarray(Image.open(Path(folder)/path).convert('L'))>0)&alpha
    rows={name:span(masks[label],y)*4 for name,(label,y) in data['source_scanlines'].items()}
    rows['near_boot']=projected_span(masks['foot_near'],data['source_boot_axis'])*4
    for name,(a,b) in data['source_arm_axes'].items():rows[name+'_minimum']=arm_width(masks[name],a,b)[0]*4
    return data,masks,rows


def holes(mask, cover=None):
    """Enclosed background components, with their maximum horizontal span."""
    # Flood fill from the outer edge; no SciPy dependency.
    pixels=np.argwhere(mask)
    if not len(pixels):
        return {'pixels':0,'maximum_width_px':0,'passed':False}
    lo,hi=pixels.min(0),pixels.max(0)+1
    filled=mask[lo[0]:hi[0],lo[1]:hi[1]]
    # PIL floodfill is linear in pixels and preserves one-pixel cracks.
    im=Image.fromarray(np.where(filled,255,0).astype('uint8')).convert('RGB')
    padded=Image.new('RGB',(im.width+2,im.height+2));padded.paste(im,(1,1));ImageDraw.floodfill(padded,(0,0),(127,127,127))
    interior=np.asarray(padded)[1:-1,1:-1,0]==0
    if cover is not None:
        interior &= ~cover[lo[0]:hi[0],lo[1]:hi[1]]
    maximum=0
    for row in interior:
        values=np.flatnonzero(row)
        for group in np.split(values,np.flatnonzero(np.diff(values)>1)+1):maximum=max(maximum,len(group))
    return {'pixels':int(interior.sum()),'maximum_width_px':maximum,'passed':maximum<=1}


def no_see_through(maps, collar_bottom, belt_top, body_envelope, opaque=None):
    allowed=['torso','upper_near','fore_near','hand_near','upper_far','fore_far','hand_far','belt','chain']
    permitted=np.logical_or.reduce([maps[n] for n in allowed])
    forbidden=np.logical_or.reduce([value for name,value in maps.items() if name not in allowed])
    opaque=np.logical_or.reduce(list(maps.values())) if opaque is None else opaque
    # Blend pixels at label seams belong to an adjacent allowed surface.
    # Never fill transparent pixels or pixels of a forbidden semantic label.
    expanded=permitted.copy()
    radius=MEASURE_DEFAULTS['antialias_radius_px']
    for dy in range(-radius,radius+1):
        for dx in range(-radius,radius+1):
            expanded |= np.roll(np.roll(permitted,dy,0),dx,1)
    permitted=expanded&opaque&~forbidden
    yy=np.indices(permitted.shape)[0]
    roi=body_envelope&(yy>collar_bottom[None,:])&(yy<belt_top[None,:])
    bad=roi&~permitted
    return {'inspected_pixels':int(roi.sum()),'forbidden_pixels':int(bad.sum()),'background_pixels':int((bad&~opaque).sum()),'forbidden_label_pixels':int((bad&forbidden).sum()),'unmapped_blend_pixels':int((bad&opaque&~forbidden).sum()),'passed':bool(roi.any() and not bad.any())}


def open_front(maps, view, row, minimum):
    pants=maps['thigh_near'] if view=='front' else maps['pelvis']|maps['thigh_near']|maps['thigh_far']
    # Require the measured trousers to lie between the declared garments.
    left=maps['tabard'] if view=='front' else maps['coat_near']
    right=maps['coat_near'] if view=='front' else maps['coat_far']
    xs=np.flatnonzero(pants[int(round(row))]);a=np.flatnonzero(left[int(round(row))]);b=np.flatnonzero(right[int(round(row))])
    if len(a) and len(b):
        lo,hi=sorted([float(np.mean(a)),float(np.mean(b))]);xs=xs[(xs>lo)&(xs<hi)]
    else:xs=np.array([],int)
    runs=np.split(xs,np.flatnonzero(np.diff(xs)>1)+1)
    width=max((len(run) for run in runs),default=0)
    return {'row_px':float(row),'trouser_run_px':width,'minimum_px':minimum,'passed':width>=minimum}


def mass_row_passed(name, value, reference, tolerances, minimum):
    limit=tolerances.get(name)
    return abs(value/reference-1)<=limit if limit else value>=minimum


def closed_forms_passed(topology):
    return bool(topology) and all(v['passed'] for v in topology.values())


def lower_leg_visible(maps, bottom):
    result={'shin_pixels':int(maps['shin_far'][int(bottom)+1:].sum()),
            'boot_pixels':int(maps['foot_far'][int(bottom)+1:].sum())}
    result['passed']=result['shin_pixels']>0 and result['boot_pixels']>0
    return result


def pants_above_belt(maps, belt_top, opaque):
    forbidden=maps['pelvis']|maps['thigh_near']|maps['thigh_far']
    yy=np.indices(opaque.shape)[0]
    interior=opaque&np.roll(opaque,1,0)&np.roll(opaque,-1,0)&np.roll(opaque,1,1)&np.roll(opaque,-1,1)
    count=int((forbidden&interior&(yy<belt_top[None,:])&(belt_top[None,:]<opaque.shape[0])).sum())
    return {'pixels':count,'passed':count==0}


def chest_passed(width, shoulders, minimum_ratio):
    return width>=minimum_ratio*shoulders


def inspect_mass(folder,capture,spec,native,joints):
    data,_,reference=source_measurements(folder,Path(__file__).resolve().parents[4]/json.loads((folder/'measurements.json').read_text())['sources']['front'])
    masks={v:labels(capture/(v+'_parts.png'),spec['labels']) for v in ['front','rear']};front=masks['front'];points=joints['front']
    from spec.art_identity.maquettes.blender.surface_pose import point
    landmarks={name:point(spec.get('surface_pose',{'operations':[]} ),piece,data['native_landmarks_m'][name])
               for name,piece in [('eye_slit','bucket_helm'),('shin_above_cuff','shin_near_gambeson'),('mid_chest','gambeson')]}
    # Horizontal eye and shin scanlines anchored in native geometry, not selected by best fit.
    eye=project(spec,landmarks['eye_slit'],'front',1024)[1]
    actual={'helm_width':span(front['head'],eye)}
    rows={'helm_width':{'label':'head','row_px':float(eye)}}
    for name,label in [('chain_fist','hand_far'),('near_fist','hand_near')]:
        pixels=np.argwhere(front[label]);row=(pixels[:,0].min()+pixels[:,0].max())/2
        actual[name]=span(front[label],row);rows[name]={'label':label,'row_px':float(row)}
    row=project(spec,landmarks['shin_above_cuff'],'front',1024)[1]
    actual['near_shin']=span(front['shin_near'],row);rows['near_shin']={'label':'shin_near','row_px':float(row)}
    foot=front['foot_near'].copy();foot[:int(points['ankle_near'][1]-MEASURE_DEFAULTS['boot_ankle_offset_px'])]=False
    actual['near_boot']=projected_span(foot,data['native_boot_axis'])
    samples={}
    for side in ['near','far']:
        for part,a,b in [('upper','shoulder','elbow'),('fore','elbow','hand')]:
            label=part+'_'+side;value,values=arm_width(front[label],points[a+'_'+side],points[b+'_'+side])
            visible_values=values
            solo=np.asarray(Image.open(capture/f'front_solo_{label}.png').convert('RGBA'))[:,:,3]>=128
            value,values=arm_width(solo,points[a+'_'+side],points[b+'_'+side])
            actual[label+'_minimum']=value;samples[label]={'unoccluded':values,'visible':visible_values}
    table={}
    for name,value in actual.items():
        limit=data['tolerances'].get(name)
        passed=mass_row_passed(name,value,reference[name],data['tolerances'],data['minimum_arm_px'])
        table[name]={'approved_native_px':reference[name],'native_px':value,'relative_error':value/reference[name]-1,
                     'tolerance':limit,'minimum_px':None if limit else data['minimum_arm_px'],'passed':bool(passed)}
    # Closed object topology independently prevents torn scarf faces, including
    # faces hidden by another part in the two captures.
    topology=native.get('closed_topology',{})
    checks={'closed_native_forms':closed_forms_passed(topology)}
    see,opened,part_holes={}, {}, {}
    for view,m in masks.items():
        collar=native['objects']['scarf_render']['views'][view]
        # The visible belt top curves in depth; measure it per column.
        # The native barrel envelope remains independent of visible torso pixels.
        belt=m['belt']
        # Project the closed native barrel faces to an independent boundary;
        # its fill catches a missing torso or an interior hole in the part map.
        barrel=next(p for p in spec['pieces'] if p['id']=='gambeson')
        pixels=project(spec,barrel['vertices'],view,1024)[:,:2]
        env=Image.new('1',(1024,1024));draw=ImageDraw.Draw(env)
        for face in barrel['faces']:draw.polygon([tuple(pixels[i]) for i in face],fill=1)
        env=np.array(env,dtype=bool)
        # Raster polygon edges and flat-label antialiasing differ by one pixel.
        # Inspect the geometric interior; the separate hole guard allows <=1px.
        env &= np.roll(env,1,0)&np.roll(env,-1,0)&np.roll(env,1,1)&np.roll(env,-1,1)
        scarf=next(p for p in spec['pieces'] if p['id']=='scarf')
        scarf_pixels=project(spec,scarf['vertices'],view,1024)[:,:2]
        scarf_mask=Image.new('1',(1024,1024));scarf_draw=ImageDraw.Draw(scarf_mask)
        for face in scarf['faces']:scarf_draw.polygon([tuple(scarf_pixels[i]) for i in face],fill=1)
        scarf_mask=np.asarray(scarf_mask,dtype=bool)
        collar_bottom=np.full(1024,collar['max'][1]);belt_top=np.full(1024,1024.)
        for x in range(1024):
            ys=np.flatnonzero(scarf_mask[:,x])
            if len(ys):collar_bottom[x]=ys.max()
        for x in range(1024):
            ys=np.flatnonzero(belt[:,x]);
            if len(ys):belt_top[x]=ys.min()
        # Only core columns have a belt boundary; trim the curved side seam.
        env[:,belt_top==1024]=False
        opaque=np.asarray(Image.open(capture/f'{view}_parts.png').convert('RGBA'))[:,:,3]>=128
        see[view]=no_see_through(m,collar_bottom,belt_top,env,opaque)
        # No pelvis/thigh above the belt anywhere along its body span.
        above=pants_above_belt(m,belt_top,opaque)
        see[view]['pants_above_belt_pixels']=above['pixels'];see[view]['passed'] &= above['passed']
        mid=joints[view]['pelvis'][1]+data['mid_thigh_fraction']*(joints[view]['knee_near' if view=='front' else 'knee_far'][1]-joints[view]['pelvis'][1])
        opened[view]=open_front(m,view,mid,data['open_front_minimum_px'])
        cover=np.asarray(Image.open(capture/f'{view}_clay.png').convert('RGBA'))[:,:,3]>=128
        for label in spec['labels']:
            if label in ['chain','head']:continue # intentional iron link and ring openings
            path=capture/f'{view}_solo_{label}.png'
            part_holes[view+'_'+label]=holes(np.asarray(Image.open(path).convert('RGBA'))[:,:,3]>=128,cover)
    tabard_bottom=np.argwhere(front['tabard'])[:,0].max()
    opened['far_lower_leg']=lower_leg_visible(front,tabard_bottom)
    chest_y=project(spec,landmarks['mid_chest'],'front',1024)[1];chest_width=span(front['torso'],chest_y)
    shoulder_width=abs(points['shoulder_near'][0]-points['shoulder_far'][0])
    chest={'width_px':chest_width,'shoulder_width_px':shoulder_width,'ratio':chest_width/shoulder_width,'passed':chest_passed(chest_width,shoulder_width,data['chest_minimum_shoulder_ratio'])}
    checks.update(mass=all(v['passed'] for v in table.values()),no_see_through=all(v['passed'] for v in see.values()),open_front=all(v['passed'] for v in opened.values()),no_part_holes=all(v['passed'] for v in part_holes.values()),barrel_chest=chest['passed'])
    collar={}
    for view in ['front','rear']:
        helm=native['objects']['bucket_helm_render']['views'][view];scarf=native['objects']['scarf_render']['views'][view]
        collar[view]={'left_extension_px':helm['min'][0]-scarf['min'][0],'right_extension_px':scarf['max'][0]-helm['max'][0]}
    from .cloth_gates import inspect_cloth
    cloth=inspect_cloth(folder,capture,spec,native)
    table.update(cloth['table']);checks['cloth']=cloth['passed'];checks['gloved_grip']=native.get('gloved_grip',{}).get('passed',False)
    return {'cloth':cloth,'native_scanlines':rows,'collar_extensions':collar,'passed':all(checks.values()),'checks':checks,'table':table,'method':data['method'].replace('source_mass_landmarks.png','source_mass_landmarks.webp')+' Arm minimum uses unoccluded labelled part masks over the identical joint scanlines; visible widths are also retained to expose depth occlusion.','arm_scanline_widths_px':samples,'no_see_through':see,'open_front':opened,'part_holes':part_holes,'chest':chest}

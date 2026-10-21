"""Two measured cuff/hand cover texels beside the front brace's hip.

Their all-pose potential exposure is checked before any source write. This is
construction calibration using the retained bound, not new motion/tuning.
"""
import numpy as np
from PIL import Image
from rr31_finish_seams import CASE,ARCHIVE,RECORD,assembled
from rr31_images import ImageGate
from rr30_joint_gate import JointSurfaceGate,DISTANCE_EPSILON_PX
from rr30_joint_geometry import distance,COVER_LIMIT_PX
from rr30_cpu import sprite_transform
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gait_continuations import nearest_donors
from humanoid_cutout.materials import connected_mask
from maquette_motion.features import source_pixels
from maquette_motion import pixels

BRACE_CONTACTS={'hidden_bracer_far':(76,168),'hidden_hand_far':(75,170)}


def repair():
    layout=read_json(CASE/'layouts/front.json')
    parts={p['name']:p for p in layout['parts']}
    model=ImageGate(CASE,layout)
    gate=JointSurfaceGate(CASE,layout)
    sources={p['name']:model.model.image(p['file']).copy() for p in layout['parts']}
    additions={}
    disconnected=[]
    for name,xy in BRACE_CONTACTS.items():
        part=parts[name]
        x,y=np.asarray(xy)-part['offset']
        if sources[name][y,x,3]:continue
        minimum=gate.skin.get(part['logical_part'],max(gate.skin.values()))
        recipe=nearest_donors(CASE,layout,dict(part,continuation_min_luma=minimum),{(int(x),int(y))})
        donor=sources[recipe['donor']]
        patch=np.zeros_like(sources[name])
        for x,y,u,v in recipe['texels']:patch[y,x]=donor[v,u]
        full=source_pixels(CASE,part)[...,3]>0
        for sx,sy in [xy]:full[sy,sx]=True
        visible=gate.visible[part['logical_part']][...,3]>0
        if not connected_mask(visible,full)[xy[1],xy[0]]:
            disconnected.append(name)
            continue
        additions[name]=dict(recipe=recipe,patch=patch,maximum_distance=0.,rejected=[])
    cache={}
    samples=read_report(CASE)
    count=0
    for pose in samples['samples']:
        if pose['view']!='front' or pose['kind']!='presented':continue
        layers=model.layers(pose)
        visible=np.logical_or.reduce([im[...,3]>0 for p,im,_ in layers if not p['hidden_material']])
        for name,addition in additions.items():
            part=parts[name];transform=sprite_transform(layout,pose,part)
            key=(name,transform.tobytes())
            if key not in cache:cache[key]=pixels.render(addition['patch'],transform)[...,3]>0
            yy,xx=np.nonzero(cache[key]&~visible)
            if not len(xx):continue
            d=distance(np.column_stack((xx+.5,yy+.5)),gate.joint_segments(part,pose))
            addition['maximum_distance']=max(addition['maximum_distance'],float(d.max()))
            if np.any(d>COVER_LIMIT_PX+DISTANCE_EPSILON_PX):addition['rejected'].append(dict(clip=pose['clip'],frame=pose['frame'],maximum=float(d.max())))
        count+=1
    record=read_json(RECORD)
    reference=assembled(layout,sources)
    accepted={}
    for name,addition in additions.items():
        if addition['rejected']:continue
        change=addition['recipe']
        for x,y,u,v in change['texels']:sources[name][y,x]=sources[change['donor']][v,u]
        accepted[name]=dict(donor=change['donor'],texels=change['texels'],
                            measured_contact=BRACE_CONTACTS[name],maximum_distance=addition['maximum_distance'])
    if reference.tobytes()!=assembled(layout,sources).tobytes():raise ValueError('Brace repair changes the approved rest')
    build=read_json(CASE/'proof/build.json')
    for name,change in accepted.items():
        part=parts[name]
        Image.fromarray(sources[name]).save(CASE/part['file'])
        path=CASE/layout['proof_layers'][name]['mask']
        mask=np.asarray(Image.open(path).convert('RGBA')).copy()
        for x,y,_,_ in change['texels']:mask[y,x]=[255,255,0,255]
        Image.fromarray(mask).save(path)
        path=ARCHIVE/'front'/part['file'].split('/')[-1]
        archive=np.asarray(Image.open(path).convert('RGBA')).copy()
        donor_part=parts[change['donor']]
        donor=np.asarray(Image.open(ARCHIVE/'front'/donor_part['file'].split('/')[-1]).convert('RGBA'))
        for x,y,u,v in change['texels']:archive[y,x]=donor[v,u]
        Image.fromarray(archive).save(path)
        tuck=next(t for t in build['views']['front']['tucks'] if t['piece']==part['logical_part'])
        hidden=source_pixels(CASE,part)[...,3]>0
        Image.fromarray(hidden.astype('uint8')*255).save(CASE/tuck['required_mask'])
        tuck.update(required_pixels=int(hidden.sum()),missing_pixels=0)
        record['views']['front']['additions'][name]=change
    record['views']['front']['added_texels']+=len(accepted)
    record['brace_contact_calibration']=dict(frames=count,disconnected=disconnected,
        candidates={n:{k:v for k,v in a.items() if k not in ('patch','recipe')} for n,a in additions.items()})
    build['tucks']=build['views']['front']['tucks']
    write_json(CASE/'proof/build.json',build)
    write_json(RECORD,record)
    print(f'RR31 BRACE CONTACTS: {len(accepted)}/2 accepted after {count} front poses; rest 0px',flush=True)


if __name__=='__main__':repair()

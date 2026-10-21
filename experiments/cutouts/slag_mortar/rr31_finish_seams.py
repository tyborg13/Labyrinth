"""Measured, static joint-cover repairs for director feedback 2.

Only approved own-piece material supplies colour. Every addition is hidden at
rest. Native captures are read-only inputs, never edited or reclassified.
"""
from collections import defaultdict
from pathlib import Path
import argparse
import numpy as np
from PIL import Image
from rr30_case import CASE, ASSETS, PROJECT
from rr31_images import OUTPUT, ImageGate, composite
from rr30_cpu import sprite_transform
from rr30_joint_gate import JointSurfaceGate
from rr30_joint_geometry import distance, COVER_LIMIT_PX
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_frames import load_frame, frame_digest
from humanoid_cutout.image_gates import defects
from humanoid_cutout.gait_continuations import nearest_donors
from humanoid_cutout.bone_evidence import read_report
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from humanoid_cutout.materials import connected_mask

# Source coordinates measured in the seven native failures and the four
# additional CPU wrist observations; these are construction data, not motion.
REGISTRATION_GAPS = {'front': {'hidden_upper_near': [(194,112)]},
                     'rear': {'hidden_upper_far': [(154,134)],
                              'hidden_fore_far': [(215,182)]}}
JUDGED_FRONT_FRAMES = [('lob',32),('brace',20),('death',78)]
JUDGED_MATERIALS = {'torso','upper_near','upper_far','fore_near','fore_far','pelvis','thigh_far'}
RECORD = OUTPUT/'feedback2_source_fixes.json'
ARCHIVE = PROJECT/'spec/assets/board_pixel_density/sources/assets/units/slag_mortar_cutout/humanoid_v2'
COVER_PROGRESS_INTERVAL_FRAMES = 100  # Logging only.


def additions():
    samples = read_report(CASE)
    poses = {(p['view'],p['clip'],p['frame']):p for p in samples['samples'] if p['kind']=='presented'}
    capture=CASE/'proof/native'
    manifest=read_json(capture/'frames.json')
    targets={view:defaultdict(set) for view in ('front','rear')}
    evidence=[]
    for view,parts in REGISTRATION_GAPS.items():
        layout=read_json(CASE/f'layouts/{view}.json')
        for name,points in parts.items():
            part=next(p for p in layout['parts'] if p['name']==name)
            targets[view][name].update(tuple(np.asarray(p)-part['offset']) for p in points)
    layout=read_json(CASE/'layouts/front.json')
    model=ImageGate(CASE,layout)
    gate=JointSurfaceGate(CASE,layout)
    for clip,frame in JUDGED_FRONT_FRAMES:
        row=next(r for r in manifest['frames'] if (r['view'],r['clip'],r['frame'])==('front',clip,frame))
        path=capture/row['file']
        if frame_digest(path)!=row['sha256']:raise ValueError('Changed judged native pixels')
        alpha=np.asarray(load_frame(path).convert('RGBA'))[...,3]>0
        notch,_=defects(alpha)
        yy,xx=np.nonzero(notch)
        points=np.column_stack((xx+.5,yy+.5))
        pose=poses[('front',clip,frame)]
        for part in layout['parts']:
            if not part['hidden_material'] or part['logical_part'] not in JUDGED_MATERIALS:continue
            near=distance(points,gate.joint_segments(part,pose))<=COVER_LIMIT_PX
            source=model.model.image(part['file'])
            v,u=np.indices(source.shape[:2])
            uv=np.stack((u,v,np.ones_like(u),np.full_like(u,255)),axis=2).astype('uint8')
            shown=pixels.render(uv,sprite_transform(layout,pose,part))[yy,xx]
            local=shown[:,:2].astype(int)
            xy=local+part['offset']
            inside=(xy>=0).all(axis=1)&(xy<255).all(axis=1)
            painted=gate.paint[xy[:,1].clip(0,254),xy[:,0].clip(0,254),3]>0
            empty=source[local[:,1],local[:,0],3]==0
            selected=near & (shown[:,3]>0) & inside & painted & empty
            targets['front'][part['name']].update(map(tuple,local[selected].tolist()))
            if selected.any():
                evidence.append(dict(view='front',clip=clip,frame=frame,piece=part['name'],
                    native_sha256=row['sha256'],source_pixels=xy[selected].tolist(),
                    destinations=np.column_stack((xx,yy))[selected].tolist()))
    return targets,evidence,manifest


def assembled(layout, images):
    result=Image.new('RGBA',(255,255))
    for part in sorted(layout['parts'],key=lambda p:p['z_index']):
        result.alpha_composite(Image.fromarray(images[part['name']]),tuple(part['offset']))
    return result


def repair():
    if RECORD.exists():
        raise ValueError('Source repair already recorded; do not re-author it from new captures')
    targets,evidence,manifest=additions()
    record=dict(scope='static source construction only; director motion and native captures unchanged',
        native_manifest_sha256=digest(CASE/'proof/native/frames.json'),
        source_hashes_before={k:v for k,v in manifest['inputs'].items() if k.startswith('pieces/')},
        native_errors_before=read_json(CASE/'proof/native_gates.json')['errors'],
        evidence=evidence,views={})
    build=read_json(CASE/'proof/build.json')
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        gate=JointSurfaceGate(CASE,layout)
        images={p['name']:np.asarray(Image.open(CASE/p['file']).convert('RGBA')).copy() for p in layout['parts']}
        reference=assembled(layout,images)
        changes={}
        for name,points in targets[view].items():
            part=next(p for p in layout['parts'] if p['name']==name)
            points={p for p in points if images[name][p[1],p[0],3]==0}
            if not points:continue
            minimum=gate.skin.get(part['logical_part'],max(gate.skin.values()))
            recipe=nearest_donors(CASE,layout,dict(part,continuation_min_luma=minimum),points)
            donor=images[recipe['donor']]
            for x,y,u,v in recipe['texels']:images[name][y,x]=donor[v,u]
            changes[name]=dict(donor=recipe['donor'],texels=recipe['texels'],minimum_luma=minimum)
        if reference.tobytes()!=assembled(layout,images).tobytes():raise ValueError('Cover repair changes approved rest: '+view)
        for name,change in changes.items():
            part=next(p for p in layout['parts'] if p['name']==name)
            Image.fromarray(images[name]).save(CASE/part['file'])
            mask=CASE/layout['proof_layers'][name]['mask']
            checks=np.asarray(Image.open(mask).convert('RGBA')).copy()
            for x,y,_,_ in change['texels']:checks[y,x]=[255,255,0,255]
            Image.fromarray(checks).save(mask)
            # Untreated density material follows the same source-coordinate
            # recipe. The normal density runner supplies processed production.
            archive=ARCHIVE/view/Path(part['file']).name
            source=np.asarray(Image.open(archive).convert('RGBA')).copy()
            donor_part=next(p for p in layout['parts'] if p['name']==change['donor'])
            donor=np.asarray(Image.open(ARCHIVE/view/Path(donor_part['file']).name).convert('RGBA'))
            for x,y,u,v in change['texels']:source[y,x]=donor[v,u]
            Image.fromarray(source).save(archive)
        for tuck in build['views'][view]['tucks']:
            name='hidden_'+tuck['piece']
            if name not in changes:continue
            part=next(p for p in layout['parts'] if p['name']==name)
            hidden=np.zeros((255,255),dtype=np.uint8)
            x,y=part['offset'];im=images[name]
            hidden[y:y+im.shape[0],x:x+im.shape[1]]=(im[...,3]>0)*255
            Image.fromarray(hidden).save(CASE/tuck['required_mask'])
            tuck.update(required_pixels=int((hidden>0).sum()),missing_pixels=0)
        record['views'][view]=dict(additions=changes,rest_mismatch_pixels=0,
            added_texels=sum(len(r['texels']) for r in changes.values()))
        print(f'RR31 {view.upper()} SEAM CONSTRUCTION: {record["views"][view]["added_texels"]} source texels; rest 0px',flush=True)
    build['tucks']=build['views']['front']['tucks']
    write_json(CASE/'proof/build.json',build)
    write_json(RECORD,record)


def seal():
    """Refresh only derived integration hashes, without identity/density re-authoring."""
    integration=read_json(ASSETS/'integration.json')
    integration.update(ready=False,native_proof='pending director feedback-2 native capture; rr30 gates blocking, rr31 images diagnostic')
    integration['files']={name:digest(ASSETS/name) for name in integration['files']}
    write_json(ASSETS/'integration.json',integration)
    print('RR31 SEAM BINDINGS: REFRESHED (native proof pending director)')


def prune():
    """Keep only connected additions that obey the retained cover bound.

    Original material is never removed. The seven native-hole registration
    texels must survive; otherwise this repair is not a valid solution.
    """
    record=read_json(RECORD)
    samples=read_report(CASE)
    build=read_json(CASE/'proof/build.json')
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        parts={p['name']:p for p in layout['parts']}
        changes=record['views'][view]['additions']
        added={n:{(x,y) for x,y,_,_ in c['texels']} for n,c in changes.items()}
        rejected=defaultdict(set)
        for name in added:
            part=parts[name]
            visible=source_pixels(CASE,parts[part['logical_part']])[...,3]>0
            hidden=source_pixels(CASE,part)[...,3]>0
            keep=connected_mask(visible,hidden)
            for x,y in added[name]:
                sx,sy=np.asarray([x,y])+part['offset']
                if not keep[sy,sx]:rejected[name].add((x,y))
        model=ImageGate(CASE,layout)
        gate=JointSurfaceGate(CASE,layout)
        checked=0
        for pose in samples['samples']:
            if pose['view']!=view or pose['kind']!='presented':continue
            report=gate.frame(pose,model.layers(pose),potential_covers=True)
            if report['dark_errors']:raise ValueError('Source addition introduces dark material: '+str(report['dark_errors'][:1]))
            for error in report['cover_errors']:
                name=error['piece'];part=parts[name]
                image=model.model.image(part['file'])
                v,u=np.indices(image.shape[:2])
                uv=np.stack((u,v,np.ones_like(u),image[...,3]),axis=2).astype('uint8')
                mapped=pixels.render(uv,sprite_transform(layout,pose,part))
                pts=np.asarray(error['destination_pixels'])
                texels={tuple(p) for p in mapped[pts[:,1],pts[:,0],:2].astype(int).tolist()}
                if not texels<=added.get(name,set()):raise ValueError('Pre-existing cover violation outside new source additions')
                rejected[name].update(texels)
            checked+=1
            if checked%COVER_PROGRESS_INTERVAL_FRAMES==0:print(f'RR31 {view.upper()} COVER CALIBRATION: {checked}/431',flush=True)
        critical={name:{tuple(np.asarray(p)-parts[name]['offset']) for p in points}
                  for name,points in REGISTRATION_GAPS[view].items()}
        for name,points in critical.items():
            if points & rejected[name]:raise ValueError('A native-hole repair exceeds the source cover budget')
        for name,points in rejected.items():
            if not points:continue
            part=parts[name]
            for path in (CASE/part['file'],CASE/layout['proof_layers'][name]['mask'],ARCHIVE/view/Path(part['file']).name):
                image=np.asarray(Image.open(path).convert('RGBA')).copy()
                for x,y in points:image[y,x]=0
                Image.fromarray(image).save(path)
            previous={tuple(p) for p in changes[name].get('rejected_texels',[])}
            changes[name]['rejected_texels']=sorted(map(list,previous|points))
            changes[name]['texels']=[r for r in changes[name]['texels'] if tuple(r[:2]) not in points]
        # Pruning must not leave a new island on the end of an accepted patch.
        for name in changes:
            part=parts[name]
            visible=source_pixels(CASE,parts[part['logical_part']])[...,3]>0
            hidden=source_pixels(CASE,part)[...,3]>0
            if np.any(hidden & ~connected_mask(visible,hidden)):
                raise ValueError('Pruned addition leaves a disconnected island: '+name)
        for tuck in build['views'][view]['tucks']:
            name='hidden_'+tuck['piece']
            if name not in changes:continue
            hidden=source_pixels(CASE,parts[name])[...,3]>0
            Image.fromarray(hidden.astype('uint8')*255).save(CASE/tuck['required_mask'])
            tuck.update(required_pixels=int(hidden.sum()),missing_pixels=0)
        record['views'][view].update(added_texels=sum(len(c['texels']) for c in changes.values()),
            rejected_texels=sum(len(c.get('rejected_texels',[])) for c in changes.values()),cover_calibration_frames=checked)
        print(f'RR31 {view.upper()} CONNECTED COVERS: {record["views"][view]["added_texels"]} accepted; '
              f'{record["views"][view]["rejected_texels"]} rejected; native-hole texels retained',flush=True)
    build['tucks']=build['views']['front']['tucks']
    write_json(CASE/'proof/build.json',build)
    write_json(RECORD,record)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal',action='store_true')
    parser.add_argument('--prune',action='store_true')
    args=parser.parse_args()
    if args.seal:seal()
    elif args.prune:prune()
    else:repair()

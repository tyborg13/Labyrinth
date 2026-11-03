"""Director feedback 1: exact registered underlays and case-only motion policy.

The immutable round-zero production snapshot is the density outside authority.
No pixel is inferred: transparent director pixels remain transparent.
"""
from copy import deepcopy
import math
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from rr48_build import ROOT, CASE, ASSETS, VIEWS, MESHES
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.promotion import promote
from humanoid_cutout.mesh import grid,weights_for
from maquette_motion.silhouette import holes,dilate

BASE_REVISION = '3fbe07289'
BASE = CASE/'baseline/round0'
STAGED = ROOT/'spec/peer_benchmark/staged/rr-48'
MOVERS = ('arm_near','arm_far','hand_near','hand_far','falchion','loincloth','loincloth_back')
RECEIVERS = ('leg_far','leg_near','pelvis','torso')


def air_reference(view,owner,mask,layout,name):
    """Exact authored air, transported on the receiving piece's own geometry.

    Sparse full-source UVs retain registration without allocating an empty
    255-square skin. A separate template also prevents paint-only triangle
    pruning from deleting the interior of an air reference.
    """
    part=next(p for p in layout['parts'] if p['name']==owner)
    folder=CASE/'holes';folder.mkdir(exist_ok=True)
    path=folder/f'{view}_{name}.png';image=np.zeros((255,255,4),np.uint8);image[mask]=255;Image.fromarray(image).save(path)
    record={'name':name,'owner':owner,'bone':part['bone'],'file':str(path.relative_to(CASE)),'source_policy':'exact immutable painting/director alpha-zero texels'}
    mesh=next((m for m in layout['joint_meshes'] if m['name']==owner),None)
    if mesh:
        yy,xx=np.nonzero(mask);bounds=[max(0,int(xx.min())-2),max(0,int(yy.min())-2),min(255,int(xx.max())+3),min(255,int(yy.max())+3)]
        vertices,_,triangles=grid(bounds)
        logical=part['logical_part'];weights=weights_for(vertices,mesh['weight_bounds'],layout['joints'],MESHES[logical])
        template=folder/f'{view}_{name}_mesh.json';write_json(template,{'vertices':vertices,'uvs':vertices,'triangles':triangles,'weights':weights,'z_index':0})
        record['mesh_template']=str(template.relative_to(CASE))
    else:record.update(presentation_anchor=part.get('presentation_anchor',part['offset']),match_presentation_anchor=True)
    return record


def snapshot():
    if (BASE/'manifest.json').exists():
        for path,sha in read_json(BASE/'manifest.json')['files'].items():
            if digest(BASE/path)!=sha:raise ValueError('Changed round-zero density authority: '+path)
        return
    prefix = str(CASE.relative_to(ROOT))+'/'
    production = str((ASSETS/'humanoid_v2').relative_to(ROOT))+'/'
    paths = subprocess.check_output(['git','ls-tree','-r','--name-only',BASE_REVISION,'--',prefix,production],cwd=ROOT,text=True).splitlines()
    files = {}
    for path in paths:
        relative = path[len(prefix):] if path.startswith(prefix) else 'production/'+path[len(production):]
        if relative.startswith('proof/') and relative != 'proof/build.json': continue
        if Path(relative).suffix not in ('.json','.png'): continue
        target = BASE/relative; target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(subprocess.check_output(['git','show',BASE_REVISION+':'+path],cwd=ROOT))
        files[relative] = digest(target)
    for view in VIEWS:
        for name in MOVERS:
            relative = f'masks/{view}_{name}.png'; target=BASE/relative;target.parent.mkdir(exist_ok=True)
            target.write_bytes(subprocess.check_output(['git','show',BASE_REVISION+':experiments/cutouts/ashen_reaver/underlay_requests/'+f'{view}_{name}.png'],cwd=ROOT))
            files[relative] = digest(target)
    write_json(BASE/'manifest.json',{'revision':BASE_REVISION,'files':files})
    (BASE/'.gdignore').touch()


def inputs(view):
    provenance=read_json(STAGED/'provenance.json')
    for name,sha in provenance['files'].items():
        if digest(STAGED/name)!=sha: raise ValueError('Changed director input: '+name)
    paint=np.asarray(Image.open(STAGED/f'{view}_body_underlay.png').convert('RGBA')).copy()
    if paint.shape!=(255,255,4): raise ValueError('Underlay registration differs from (0,0), 255 px')
    paint[paint[...,3]==0]=0
    return paint


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


def floor_contract(layout, data, root=CASE):
    images=[source_pixels(root,p) for p in layout['parts'] if p['logical_part']=='falchion']
    opaque=np.logical_or.reduce([im[...,3]>0 for im in images]);y,x=np.nonzero(opaque)
    points=hull([(int(px+dx),int(py+dy)) for px,py in zip(x,y) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])
    view=layout['facing'];track=next(t for t in data['view_tracks'][view]['death'] if t['source']=='falchion.angle_deg')
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
    stop=min(limits,key=abs) if limits else math.radians(bound)*direction
    grip=np.asarray(layout['joints']['falchion']['position'])
    layout['held_items']['falchion'].update(floor_end=list(contact),painted_floor={'points_local':(np.asarray(points)-grip).tolist(),'contact_source':list(contact),'limit_deg':math.degrees(stop),'keyed_direction':direction,'bound_deg':bound,'second_support_reached':bool(limits),'status':'PASS' if limits else 'BOUND_REACHED'})
    data['view_held_drops'][view]['death']['falchion'].update(floor_limit_deg=math.degrees(stop),rotation_sign=1.,floor_travel_deg=bound,floor_key_limit_deg=abs(keyed))
    return {'angle_deg':math.degrees(stop),'first_contact':list(contact),'hull_source':points,'protected_direction':direction,'support_direction':direction,'rotation_sign':1.,'bound_deg':bound,'second_support_reached':bool(limits),'rule':'First new silhouette support in keyed direction, bounded to director 95 degrees; opaque cell hull includes the grip cap','status':'PASS' if limits else 'BOUND_REACHED'}


def motion_policy(data, layouts):
    data=deepcopy(data)
    unified=(CASE/'feedback3_policy.json').exists()
    data['clips']['move']['held_follow']['reference_frame']='body' if unified else 'root'
    if unified:data['clips']['move']['held_follow'].pop('reference_bone',None)
    else:data['clips']['move']['held_follow']['reference_bone']='pelvis'
    floors={v:floor_contract(layouts[v],data) for v in VIEWS}
    report='feedback2_policy_floor.json' if (CASE/'feedback2_supply.json').exists() else 'feedback1_floor.json'
    write_json(CASE/'proof'/report,{'views':floors,'native_pixels':False})
    return data


def apply():
    snapshot(); layouts={}; coverage=[]; partitions={}
    policy=CASE/'feedback1_policy.json'
    if not policy.exists():write_json(policy,{'floor_direction':'TODO_DESIGN_floor_rotation_direction'})
    for view in VIEWS:
        layout=read_json(BASE/f'layouts/{view}.json');paint=inputs(view)
        layout['raw_rest_source']=layout['rest_source']
        images={p['name']:source_pixels(BASE,p) for p in layout['parts']}
        visible=np.logical_or.reduce([im[...,3]>0 for im in images.values()])
        masks={name:np.asarray(Image.open(BASE/f'masks/{view}_{name}.png').convert('L'))>0 for name in MOVERS}
        moving_authority=np.logical_or.reduce(list(masks.values()))
        # Director authority is the requested vacated footprint only. Covered
        # edge/tuck requirements outside it remain findings, never new paint.
        authority=moving_authority
        # Existing registered storage bounds, then visible ownership, exactly as
        # rr-42. The nearest registered body texel resolves only empty storage.
        owner=np.full((255,255),'',object)
        for name in RECEIVERS:
            p=next(p for p in layout['parts'] if p['name']==name);x,y,r,b=p['bbox'];owner[y:b,x:r]=name
        for name in RECEIVERS:owner[images[name][...,3]>0]=name
        ys,xs=np.nonzero((owner=='') & authority)
        by_name={n:np.column_stack(np.nonzero(images[n][...,3]>0)) for n in RECEIVERS}
        for y,x in zip(ys,xs):
            owner[y,x]=min(RECEIVERS,key=lambda n:np.min(np.sum((by_name[n]-[y,x])**2,axis=1)))
        for name in MOVERS:
            mask=masks[name];missing=mask & (paint[...,3]==0)
            out=CASE/f'underlay_coverage/{view}_{name}_missing.png';out.parent.mkdir(exist_ok=True)
            Image.fromarray(missing.astype('uint8')*255).save(out)
            coverage.append({'view':view,'piece':name,'vacated_pixels':int(mask.sum()),'opaque_underlay_pixels':int((mask & (paint[...,3]>0)).sum()),'uncovered_pixels':int(missing.sum()),'missing_mask':str(out.relative_to(CASE)),'missing_uv':np.column_stack(np.nonzero(missing))[:,::-1].tolist()})
        authority_path=CASE/f'ownership/feedback1_{view}_authority.png';Image.fromarray(authority.astype('uint8')*255).save(authority_path)
        for index,receiver in enumerate(RECEIVERS):
            name='hidden_'+receiver;domain=moving_authority & (owner==receiver)
            image=np.zeros_like(paint);image[domain]=paint[domain]
            # A zero-alpha pixel is still inside the partition's clear authority.
            original=next(p for p in layout['parts'] if p['name']==receiver)
            # Transparent authority outside the stored crop is an explicit
            # zero, not a reason to skin a whole empty blade-sized rectangle.
            # Match the visible garment's two-pixel source grid (rr-42).
            yy,xx=np.nonzero(image[...,3])
            bounds=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)] if len(xx) else [0,0,2,2]
            if len(xx):
                for axis in (0,1):
                    bounds[axis]=max(0,bounds[axis]-(bounds[axis]-original['bbox'][axis])%2)
                    bounds[axis+2]=min(255,bounds[axis+2]+(original['bbox'][axis]-bounds[axis+2])%2)
            path=CASE/f'pieces/{view}/{name}.png';Image.fromarray(image).crop(bounds).save(path)
            part={'name':name,'file':str(path.relative_to(CASE)),'bbox':bounds,'offset':bounds[:2],'bone':original['bone'],'logical_part':receiver,'hidden_material':True,'z_index':index-len(RECEIVERS)}
            if receiver not in MESHES:part['presentation_anchor']=original.get('presentation_anchor',original['offset'])
            layout['parts'].append(part)
            if receiver in MESHES:layout['joint_meshes'].append(layer(part,receiver,original['bbox'],layout['joints'],part['z_index'],True,recipe=MESHES[receiver]))
            layout['source_labels'][name]=[receiver]
            for group,names in layout['idle_groups'].items():
                if receiver in names:names.append(name)
            check=np.zeros_like(image);check[image[...,3]>0]=[255,255,0,255]
            cp=CASE/f'checks/{view}/{name}.png';Image.fromarray(check).crop(bounds).save(cp)
            layout['proof_layers'][name]={'mask':str(cp.relative_to(CASE)),'mask_offset':bounds[:2],'z_index':part['z_index'],'source':part['file'],'rigid':receiver not in MESHES,'source_sha256':digest(path)}
            mp=CASE/f'ownership/feedback1_{view}_{name}.png';Image.fromarray(domain.astype('uint8')*255).save(mp)
            partitions[f'{view}/{name}.png']={'mask':{'path':str(mp.relative_to(ROOT)),'sha256':digest(mp)},'source_offset':bounds[:2]}
        for part in layout['parts']:
            if part.get('hidden_material'):continue
            mp=CASE/f'ownership/feedback1_{view}_{part["name"]}.png';Image.new('L',(255,255)).save(mp)
            old=next(p for p in read_json(BASE/f'production/{view}.json')['parts'] if p['name']==part['name']);baseline=BASE/'production'/old['file']
            partitions[f'{view}/{Path(part["file"]).name}']={'mask':{'path':str(mp.relative_to(ROOT)),'sha256':digest(mp)},'source_offset':part['offset'],'outside':{'path':str(baseline.relative_to(ROOT)),'sha256':digest(baseline),'offset':old['offset']}}
        references=[]
        for index,mask in enumerate(holes(visible)):
            rim=dilate(mask,1)&~mask
            owner=max(images,key=lambda n:int((rim&(images[n][...,3]>0)).sum()))
            references.append(air_reference(view,owner,mask,layout,f'AuthoredRestAir{index}'))
        for receiver in RECEIVERS:
            domain=np.asarray(Image.open(CASE/f'ownership/feedback1_{view}_hidden_{receiver}.png').convert('L'))>0
            clear=domain&(paint[...,3]==0)
            if clear.any():references.append(air_reference(view,'hidden_'+receiver,clear,layout,'DirectorClear_'+receiver))
        layout['proof_rest_holes']=references
        layouts[view]=layout
    data=motion_policy(read_json(BASE/'compiled_motion.json'),layouts)
    from rr48_budget_search import apply_recorded
    data=apply_recorded(data)
    for view,layout in layouts.items():write_json(CASE/f'layouts/{view}.json',layout)
    write_json(CASE/'compiled_motion.json',data)
    inputs_record=read_json(CASE/'inputs.json');inputs_record['design_placeholders']={};inputs_record['feedback1']={'director_underlays':str(STAGED.relative_to(ROOT)),'idle_free_arm':'rides rigidly with torso','held_follow_reference_frame':'root','floor':'painted silhouette second-contact stop'}
    if any(l['held_items']['falchion']['painted_floor']['status'].startswith('TODO_DESIGN') for l in layouts.values()):inputs_record['design_placeholders']['TODO_DESIGN_floor_rotation_direction']='The supplied direction reaches its next silhouette contact at 90 degrees, outside the 80-degree limit; director decision requested. Safe floor support is held meanwhile.'
    write_json(CASE/'inputs.json',inputs_record)
    anatomy=read_json(CASE/'anatomy.json');anatomy['integration']['owner_approval']='reaver-paint-3, 2026-10-28; feedback 1 director underlays, 2026-10-29; native rig proof pending'
    ownership=anatomy['ownership']
    for logical,recipe in MESHES.items():
        if recipe['kind']!='two_segment':continue
        ownership['segments'][logical]={'joints':recipe['joints'],'owners':recipe['bones']}
        for bone in recipe['bones']:
            if bone not in ownership['names']:ownership['names'].append(bone)
        pair=recipe['bones']
        if pair not in ownership['joint_pairs']:ownership['joint_pairs'].append(pair)
        side=logical.rsplit('_',1)[1]
        pairs=[['torso','upper_'+side],['fore_'+side,'hand_'+side]] if logical.startswith('arm_') else [['pelvis','thigh_'+side],['shin_'+side,'foot_'+side]]
        for pair in pairs:
            if pair not in ownership['joint_pairs']:ownership['joint_pairs'].append(pair)
    write_json(CASE/'anatomy.json',anatomy)
    write_json(CASE/'source_partitions.json',partitions)
    build=read_json(CASE/'proof/build.json');tuck_coverage=[]
    for view,layout in layouts.items():
        paint=inputs(view)
        for row in build['views'][view]['tucks']:
            mask=np.asarray(Image.open(CASE/row['required_mask']).convert('L'))>0
            own=np.zeros((255,255),bool)
            for part in layout['parts']:
                if part.get('hidden_material') and part['logical_part']==row['piece']:own |= source_pixels(CASE,part)[...,3]>0
            covered=int((mask&own).sum());row['missing_pixels']=row['required_pixels']-covered
            row['status']='PASS' if not row['missing_pixels'] else 'FINDING_missing_painted_tuck'
            tuck_coverage.append({'view':view,'piece':row['piece'],'required_pixels':row['required_pixels'],'opaque_underlay_pixels':int((mask&(paint[...,3]>0)).sum()),'own_continuation_pixels':covered,'missing_pixels':row['missing_pixels'],'mask':row['required_mask']})
    build.update(build['views']['front']);write_json(CASE/'proof/build.json',build)
    write_json(CASE/'proof/feedback1_tuck_coverage.json',{'regions':tuck_coverage,'native_pixels':False})
    write_json(CASE/'proof/underlay_coverage.json',{'native_pixels':False,'regions':coverage,'uncovered_pixels':sum(r['uncovered_pixels'] for r in coverage),'ok':not any(r['uncovered_pixels'] for r in coverage)})
    from humanoid_cutout.native_defects import packed
    contract=read_json(CASE/'material_contract.json')
    for view,layout in layouts.items():
        contract['views'][view]['interior_palettes']={p['name']:list(map(int,np.unique(packed(source_pixels(CASE,p))[source_pixels(CASE,p)[...,3]>0]))) for p in layout['parts']}
    write_json(CASE/'material_contract.json',contract)
    promote(ROOT,CASE,ASSETS/'humanoid_v2',layouts)
    for folder in (CASE/'pieces',CASE/'checks',ASSETS/'humanoid_v2'):
        for p in folder.rglob('*.png'):Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    print('RR48 DIRECTOR UNDERLAYS: exact registered RGBA; coverage findings='+str(sum(r['uncovered_pixels'] for r in coverage)))

if __name__=='__main__':apply()

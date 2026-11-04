"""Whole-falchion ownership and closed-fist texel provenance for rr-57 r2.

Masks register the existing painted weapon. The only added gauntlet pixels are
unmodified own-fist texels: the r2 near-fist donor and r3 wrist cross-sections.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from rr48_build import CASE, ROOT
from rr48_feedback1 import hull
from cutout_pipeline.cases import read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components, dilate

REGIONS = {
    'front': [
        [[108,124],[117,120],[126,121],[126,128],[114,131],[109,135],[105,134],[106,129]],
        [[82,130],[88,129],[97,138],[104,146],[109,147],[110,154],[104,155],[98,148],[91,141],[84,137]]],
    'rear': [
        [[136,137],[146,133],[157,134],[166,132],[169,135],[169,142],[162,146],[146,147],[137,145]],
        [[169,142],[175,142],[177,148],[167,157],[163,163],[158,168],[153,167],[155,161],[160,155]]],
}
GRIP_PATH = {'front':[(100,140),(121,124)], 'rear':[(166,157),(146,141)]}


def weapon_mask(view, depth):
    mask=Image.new('L',(255,255));draw=ImageDraw.Draw(mask)
    for polygon in REGIONS[view]:draw.polygon([tuple(p) for p in polygon],fill=255)
    draw.line(GRIP_PATH[view],fill=255,width=depth)
    return np.asarray(mask)>0


def closed_fist(hand, donor, joints, selected, search_radius):
    remaining=hand.copy();remaining[selected]=0
    y,x=np.nonzero(remaining[...,3]);points=list(zip(x.tolist(),y.tolist()))+[tuple(joints['hand_far']['position'])]
    shape=Image.new('L',(255,255));ImageDraw.Draw(shape).polygon(hull(points),fill=255)
    wanted=selected&(np.asarray(shape)>0)
    near=np.asarray(joints['hand_near']['position']);far=np.asarray(joints['hand_far']['position'])
    sy,sx=np.nonzero(donor[...,3]);best=None
    for mirror in (True,False):
        for dy in range(-search_radius,search_radius+1):
            for dx in range(-search_radius,search_radius+1):
                tx=far[0]+(-1 if mirror else 1)*(sx-near[0])+dx;ty=far[1]+sy-near[1]+dy
                keep=(tx>=0)&(tx<255)&(ty>=0)&(ty<255)
                mapped=np.zeros_like(hand);mapped[ty[keep],tx[keep]]=donor[sy[keep],sx[keep]]
                fill=wanted&(mapped[...,3]>0);overlap=(remaining[...,3]>0)&(mapped[...,3]>0)
                agreement=overlap&np.all(remaining==mapped,axis=-1)
                score=(int(fill.sum()),int(agreement.sum()),int(overlap.sum()),-abs(dx)-abs(dy))
                if best is None or score>best[0]:best=(score,mapped,fill,mirror,dx,dy)
    _,mapped,fill,mirror,dx,dy=best;remaining[fill]=mapped[fill]
    fy,fx=np.nonzero(fill);ux=near[0]+(-1 if mirror else 1)*(fx-far[0]-dx);uy=near[1]+fy-far[1]-dy
    ledger=[{'to':[int(x),int(y)],'from':[int(u),int(v)],'rgba':donor[v,u].tolist()} for x,y,u,v in zip(fx,fy,ux,uy)]
    return remaining,wanted&~fill,{'mirror_x':mirror,'offset_from_joint':[dx,dy],'texels':ledger}


def repartition(view, images, layout, *, release_fills=True):
    depth=read_json(CASE/'anatomy.json')['joint_continuations']['depth_px']
    mask=weapon_mask(view,depth);selected=mask&(images['hand_far'][...,3]>0)
    weapon=images['falchion'].copy();weapon[selected]=images['hand_far'][selected]
    # Old raster-sliver ownership moved a few ricasso/guard-end pixels onto
    # the glove. Recover only disconnected remnants touching this weapon.
    labels,groups=components((images['hand_far'][...,3]>0)&~mask,8)
    for label,_ in groups[1:]:
        fragment=labels==label
        if (fragment&dilate(weapon[...,3]>0,depth)).any():mask|=fragment
    selected=mask&(images['hand_far'][...,3]>0);weapon[selected]=images['hand_far'][selected]
    fist,missing,donor=closed_fist(images['hand_far'],images['hand_near'],layout['joints'],mask,depth)
    underlay=images['hidden_hand_far'].copy();underlay[mask]=0
    # The old hilt tuck must not survive as detached strips beside the now
    # smaller fist. Retain only its existing three-pixel glove continuation.
    underlay[~dilate(fist[...,3]>0,depth)]=0
    from rr48_release_fills import fill
    release_fill=None
    if release_fills:
        fist,fill_domain,release_fill=fill(view,fist)
        release_fill['domain_uv']=np.argwhere(fill_domain)[:,::-1].tolist()
        missing &= fist[...,3]==0
    transferred=np.argwhere(selected)[:,::-1].tolist()
    silhouette=(weapon[...,3]>0)|(images['hidden_falchion'][...,3]>0)
    return {'falchion':weapon,'hand_far':fist,'hidden_hand_far':underlay}, {
        'view':view,'weapon_texels':transferred,'weapon_rgba':images['hand_far'][selected].tolist(),
        'donor':donor,'release_fill':release_fill,'unfilled_fist_texels':np.argwhere(missing)[:,::-1].tolist(),
        'whole_weapon_source_components':len(components(silhouette,8)[1]),
        'regions':REGIONS[view],'grip_path':GRIP_PATH[view],'existing_continuation_depth_px':depth}


def images_for(root, layout):
    return {p['name']:source_pixels(root,p) for p in layout['parts']}


def released_part(part, clip, phase):
    variant=part.get('release_texture',{})
    return dict(part,**{k:variant[k] for k in ('file','offset','bbox')}) if phase>=variant.get('release_at',{}).get(clip,float('inf')) else part


def apply():
    from rr48_build import ASSETS
    from cutout_pipeline.cases import write_json,digest
    reports=[]
    for root,production in ((CASE,False),(ASSETS/'humanoid_v2',True)):
        for view in ('front','rear'):
            path=root/(f'{view}.json' if production else f'layouts/{view}.json')
            layout=read_json(path);images=images_for(root,layout)
            changed,ledger=repartition(view,images,layout)
            domain=np.zeros((255,255),np.uint8)
            for x,y in ledger['release_fill']['domain_uv']:domain[y,x]=255
            domain_path=CASE/f'rr57/feedback3_{view}_fill_domain.png'
            Image.fromarray(domain).save(domain_path)
            domain_path.with_name(domain_path.name+'.import').write_text('[remap]\n\nimporter="keep"\n')
            for name,full in changed.items():
                part=next(p for p in layout['parts'] if p['name']==name)
                y,x=np.nonzero(full[...,3]);bounds=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if name=='falchion' else part['bbox']
                relative=f'{view}/{name}_released.png' if production else f'pieces/{view}/{name}_released.png'
                target=root/relative;target.parent.mkdir(parents=True,exist_ok=True)
                Image.fromarray(full).crop(bounds).save(target)
                checks=np.zeros_like(full);checks[full[...,3]>0]=[255,255,0,255] if part.get('hidden_material') else [255,0,0,255]
                check=f'{view}/{name}_released_checks.png' if production else f'checks/{view}/{name}_released.png'
                (root/check).parent.mkdir(parents=True,exist_ok=True);Image.fromarray(checks).crop(bounds).save(root/check)
                part['release_texture']={'file':relative,'offset':bounds[:2],'bbox':bounds,'mask':check,'release_at':{'death':.3},'source_sha256':digest(target),'held_presentation':'original composite cache; fingers occlude the grip exactly as approved'}
                for p in (target,root/check):p.with_name(p.name+'.import').write_text('[remap]\n\nimporter="keep"\n')
            write_json(path,layout)
            ledger['paint_scope']='production' if production else 'case'
            ledger['sources']={p['name']:{'file':p['file'],'sha256':digest(root/p['file'])} for p in layout['parts'] if p['name'] in ('hand_far','hand_near','falchion','hidden_hand_far')}
            reports.append(ledger)
    target=CASE/'rr57/weapon_ownership.json';write_json(target,{'version':1,'views':reports,'note':'Only texture ownership changes at the existing release. All in-hand sprites use byte-identical presentation caches.'})
    requests=[]
    for row in reports:
        if row['paint_scope']!='production' or not row['unfilled_fist_texels']:continue
        mask=np.zeros((255,255),np.uint8)
        for x,y in row['unfilled_fist_texels']:mask[y,x]=255
        path=CASE/f'rr57/{row["view"]}_empty_fist_missing.png';Image.fromarray(mask).save(path)
        requests.append({'name':'TODO_DESIGN_'+row['view']+'_empty_fist_underlay','view':row['view'],'piece':'hand_far','source_size':[255,255],'missing_pixels':int((mask>0).sum()),'mask':str(path.relative_to(CASE)),'missing_uv':row['unfilled_fist_texels'],'request':'Closed gauntlet continuation where the removed grip is not covered by an exact mirrored/translated near-fist donor.'})
    write_json(CASE/'rr57/weapon_underlay_requests.json',{'native_pixels':False,'requests':requests,'landing_note':'Director r3: preserve approved landing path; its silhouette extends beyond the projected tile.'})
    print('RR57 WEAPON PARTITION:',[(r['paint_scope'],r['view'],len(r['weapon_texels']),len(r['donor']['texels']),len(r['unfilled_fist_texels'])) for r in reports])

if __name__=='__main__':apply()

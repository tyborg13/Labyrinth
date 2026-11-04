"""rr-57 r2 ownership/provenance and exact held-frame comparisons.

Headless comparisons prove texture and transform identity, not native pixels.
The same comparator can consume the director's two real-renderer grids.
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.native_frames import load_frame,frame_digest
from rr48_build import CASE,ASSETS
from rr48_weapon_ownership import images_for,repartition

PROOF_DISPLAY={'magnification':3,'background_rgba':(30,30,36,255)}


def ownership(root=CASE, production=False):
    errors=[];views=[]
    for view in ('front','rear'):
        layout=read_json(root/(f'{view}.json' if production else f'layouts/{view}.json'))
        expected,ledger=repartition(view,images_for(root,layout),layout)
        for name,image in expected.items():
            p=next(p for p in layout['parts'] if p['name']==name);v=p['release_texture'];a,b,c,d=v['bbox']
            actual=np.asarray(Image.open(root/v['file']).convert('RGBA'))
            if not np.array_equal(actual,image[b:d,a:c]):errors.append(f'{view}/{name}: release paint differs from exact partition/donor recipe')
            if digest(root/v['file'])!=v['source_sha256']:errors.append(f'{view}/{name}: stale hash')
        if ledger['whole_weapon_source_components']!=1:errors.append(view+': whole weapon disconnected')
        views.append({'view':view,'moved_weapon_texels':len(ledger['weapon_texels']),'donor_fist_texels':len(ledger['donor']['texels']),'missing_fist_texels':len(ledger['unfilled_fist_texels']),'whole_weapon_components':ledger['whole_weapon_source_components']})
    return {'ok':not errors,'errors':errors,'views':views,'native_pixels':False}


def held_pose_diff(before,after):
    """All native-grid in-hand transforms/alpha/depth must remain byte identical."""
    old={(r['view'],r['clip'],r['frame'],r['kind'],r['phase']):r for r in before['samples']};errors=[];count=0
    motion=read_json(CASE/'compiled_motion.json')
    for row in after['samples']:
        release=motion.get('view_release_at',{}).get(row['view'],{}).get(row['clip'],motion['clips'][row['clip']].get('release_at',{})).get('falchion',float('inf'))
        if row['kind']!='presented' or row['phase']>=release:continue
        key=(row['view'],row['clip'],row['frame'],row['kind'],row['phase']);previous=old[key]
        # Source paints are independently pinned by the ownership proof. This
        # compares every actual painted node and every bone, including gait.
        for field in ('parts','bones'):
            if row[field]!=previous[field]:errors.append({'view':row['view'],'clip':row['clip'],'frame':row['frame'],'field':field})
        count+=1
    return {'ok':not errors,'frames':count,'errors':errors,'native_pixels':False,'method':'byte-identical held texture caches and exact sampled painted-node/bone transforms; real-renderer pixel diff pending'}


def native_diff(before,after,output,*,native_pixels=True):
    from rr48_native_baseline import compare
    report=compare(before,after,read_json(CASE/'compiled_motion.json'),native_pixels=native_pixels)
    write_json(output,report)
    print(f'RR57 IN-HAND {"NATIVE" if native_pixels else "FIXTURE"} PIXEL DIFF: {report["differing_pixels"]} pixels ({report["frames"]} frames)')
    return report


def drop_bounds(samples,case):
    import math
    from humanoid_cutout.gates import matrix
    from rr48_weapon_ownership import released_part
    from rr48_build import ROOT
    profile=read_json(ROOT/'tests/approved_asset_pins.json')['registration']['ashen_reaver']
    half_width=samples['step_distance_px']/math.sqrt(1.25)/samples['screen_pixel_scale']
    half_height=half_width/2;records=[]
    for view in ('front','rear'):
        row=next(r for r in samples['samples'] if r['view']==view and r['clip']=='death' and r['phase']==1 and r['kind']=='presented')
        layout=read_json(case/f'layouts/{view}.json');all_points=[]
        for part in layout['parts']:
            if part['logical_part']!='falchion':continue
            active=released_part(part,'death',1);image=np.asarray(Image.open(case/active['file']).convert('RGBA'))
            y,x=np.nonzero(image[...,3]);points=np.concatenate([np.column_stack((x+dx,y+dy,np.ones(len(x)))) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])
            transform=matrix(row['parts'][part['name']]['transform'])
            posed=points[:,0,None]*transform[:2,0]+points[:,1,None]*transform[:2,1]+transform[:2,2]
            if not np.isfinite(posed).all():raise ValueError('Nonfinite dropped-weapon geometry')
            all_points.append(posed)
        points=np.concatenate(all_points);center=np.asarray(profile[view]);diamond=(np.abs(points-center)/[half_width,half_height]).sum(axis=1)
        records.append({'view':view,'terminal_source_bounds':[*points.min(axis=0),*points.max(axis=0)],'floor_line_y':layout['held_items']['falchion']['floor_line_y'],'tile_center_source_px':center.tolist(),'tile_half_extents_source_px':[half_width,half_height],'max_diamond_coordinate':float(diamond.max()),'inside_tile':bool((diamond<=1).all())})
    return {'native_pixels':False,'records':records,'landing_note':'Director r3: retain the approved landing path; its tile overhang is noted only.'}


def prepare_baseline(case,target):
    import shutil
    shutil.copytree(case,target,dirs_exist_ok=True)
    for view in ('front','rear'):
        path=target/f'layouts/{view}.json';layout=read_json(path)
        for part in layout['parts']:part.pop('release_texture',None)
        layout['motion_data']=str(target/'compiled_motion.json');write_json(path,layout)
    print('RR57 NATIVE BASELINE: exact approved held caches; '+str(target))


def drop_rows(manifest,view):
    rows=[r for r in manifest['frames'] if r['view']==view and r['clip']=='death' and r['phase']>=.3]
    selected=[rows[0],min(rows,key=lambda r:abs(r['phase']-.45)),rows[len(rows)//2],rows[-1]]
    # Include both ends of the director's actual wrist-continuation witnesses.
    requests=read_json(CASE.parent/'underlay_requests/rr57_feedback2/index.json')
    witness=[w['frame'] for region in requests['regions'] if region['view']==view for w in region.get('witnesses',[]) if w.get('clip')=='death']
    if witness:
        selected += [r for r in rows if r['frame'] in (min(witness),max(witness))]
    return sorted({r['frame']:r for r in selected}.values(),key=lambda r:r['frame'])


def save_drop_strip(images,rows,output,view,native_pixels):
    from PIL import ImageDraw
    from humanoid_cutout.proof import SHEET_LABEL_HEIGHT_PX
    boxes=[im.getbbox() for im in images];box=(min(b[0] for b in boxes),min(b[1] for b in boxes),max(b[2] for b in boxes),max(b[3] for b in boxes))
    zoom=PROOF_DISPLAY['magnification'];width=(box[2]-box[0])*zoom;height=(box[3]-box[1])*zoom;label=SHEET_LABEL_HEIGHT_PX
    sheet=Image.new('RGBA',(width*len(images),height+label),PROOF_DISPLAY['background_rgba']);draw=ImageDraw.Draw(sheet)
    for i,(im,row) in enumerate(zip(images,rows)):
        sheet.alpha_composite(im.crop(box).resize((width,height),Image.Resampling.NEAREST),(i*width,0))
        draw.text((i*width,height),f'{"native" if native_pixels else "CPU"} {view} death {row["frame"]}',fill='white')
    sheet.save(output/f'{view}_drop_3x.png')
    write_json(output/f'{view}_drop_frames.json',{'native_pixels':native_pixels,'frames':[r['frame'] for r in rows],'crop':list(box),'magnification':zoom})


def drops(capture,output):
    manifest=read_json(capture/'frames.json');output.mkdir(parents=True,exist_ok=True)
    for view in ('front','rear'):
        rows=drop_rows(manifest,view);images=[load_frame(capture/r['file']).convert('RGBA') for r in rows]
        save_drop_strip(images,rows,output,view,True)
    print('RR57 NATIVE DROP SHEETS: '+str(output))


def cpu_drops(case,samples,output):
    from rr48_feedback3_cpu import model
    from rr48_joint_budget import pose_layers
    from humanoid_cutout.canvas import for_case
    output.mkdir(parents=True,exist_ok=True);motion=read_json(case/'compiled_motion.json')
    with for_case(case):
        for view in ('front','rear'):
            m=model(case,view);rows=drop_rows({'frames':samples['samples']},view);images=[]
            for row in rows:
                layers,_=pose_layers(m,row,motion);image=Image.new('RGBA',(layers[0][1].shape[1],layers[0][1].shape[0]))
                for _,paint,_ in sorted(layers,key=lambda layer:layer[0]['z_index']):image.alpha_composite(Image.fromarray(paint))
                images.append(image)
            save_drop_strip(images,rows,output,view,False)
    print('RR57 CPU DROP SHEETS: '+str(output))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepare-baseline',type=Path);p.add_argument('--case',type=Path);p.add_argument('--before',type=Path);p.add_argument('--after',type=Path);p.add_argument('--native-before',type=Path);p.add_argument('--native-after',type=Path);p.add_argument('--drop-sheets',type=Path);p.add_argument('--cpu-drops',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if a.prepare_baseline:prepare_baseline(a.case,a.prepare_baseline);r={'ok':True}
    elif a.native_before:
        try:r=native_diff(a.native_before,a.native_after,a.output)
        except (OSError,ValueError) as error:
            write_json(a.output,{'ok':False,'errors':str(error).splitlines(),'native_pixels':False})
            print('RR57 IN-HAND NATIVE PIXEL DIFF: FAIL')
            print(str(error));raise SystemExit(1)
    elif a.drop_sheets:drops(a.drop_sheets,a.output);r={'ok':True}
    elif a.cpu_drops:cpu_drops(a.case,read_json(a.cpu_drops),a.output);r={'ok':True}
    else:
        r={'case':ownership(),'production':ownership(ASSETS/'humanoid_v2',True)}
        if a.before:r['held']=held_pose_diff(read_json(a.before),read_json(a.after))
        if a.after and a.case:write_json(a.output.with_name('drop_tile_bounds.json'),drop_bounds(read_json(a.after),a.case))
        r['ok']=all(v['ok'] for v in r.values());write_json(a.output,r)
        print('RR57 WHOLE WEAPON / DONOR PROVENANCE: '+('PASS' if r['ok'] else 'FAIL'))
        if 'held' in r:print('RR57 IN-HAND TRANSFORMS: %s (%d frames; native pixel diff pending)'%('PASS' if r['held']['ok'] else 'FAIL',r['held']['frames']))
    raise SystemExit(0 if r['ok'] else 1)

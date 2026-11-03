"""Small native/source witnesses for row continuations with no own-row paint."""
import collections
from pathlib import Path
import time
import numpy as np
from rr38_case import CASE
from rr38_triage import crop
from rr38_surfaces import interior
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose,mesh_map,sprite_transform
from humanoid_cutout.canvas import for_case
from humanoid_cutout.native_frames import load_frame,frame_digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules


def run():
    began=time.monotonic()
    root=CASE/'proof/logs/feedback2';case=root/'baseline_source';treated=root/'baseline_treated';native=CASE/'proof/native'
    triage=read_json(root/'triage_source_final/triage.json');manifest=read_json(native/'frames.json')
    poses={(r['view'],r['clip'],r['frame']):r for r in read_json(case/'proof/logs/samples.json')['samples'] if r['kind']=='presented'}
    pieces={(r['view'],r['clip'],r['frame'],r['name']):r for r in manifest['pieces']}
    frames={(r['view'],r['clip'],r['frame']):r for r in manifest['frames']}
    groups=collections.defaultdict(list)
    for row in triage['records']:
        if row['kind']=='flat' and row['classification']=='a_native':groups[row['view'],row['finding']['piece']].append(row)
    models={v:CpuPose(case,read_json(case/f'layouts/{v}.json'),triangle_batch_size=128) for v in ('front','rear')}
    result=[]
    with for_case(case):
        for (view,logical),rows in sorted(groups.items()):
            model=models[view];part=next(p for p in model.layout['parts'] if p['name']=='hidden_'+logical)
            visible=next(p for p in model.layout['parts'] if p['name']==logical)
            seed=interior(source_pixels(case,visible),rules(case,view));available=(seed[...,3]>0).any(axis=1)
            if available.all():continue
            paint=model.image(part['file'])
            treated_paint=np.asarray(load_frame(treated/part['file']).convert('RGBA'))
            found=None
            # One exact witness establishes a needed row decision per surface;
            # every original flag/frame/crop remains in the full triage.
            for row in rows:
                pose=poses[view,row['clip'],row['frame']];piece=pieces[view,row['clip'],row['frame'],part['name']]
                if frame_digest(native/piece['file'])!=piece['sha256']:raise ValueError('Changed native underlay piece')
                image=np.asarray(load_frame(native/piece['file']).convert('RGBA'))
                x0,y0,x1,y1=row['finding']['bbox']
                if part['name'] in model.meshes:
                    mapping=mesh_map(model.layout,pose,model.meshes[part['name']],native_skin=True,triangle_batch_size=128)
                    xy,uv=mapping.pixels,mapping.texels
                    select=(xy[:,0]>=x0)&(xy[:,0]<x1)&(xy[:,1]>=y0)&(xy[:,1]<y1)
                    samples=zip(xy[select],uv[select])
                else:
                    y,x=np.mgrid[y0:y1,x0:x1];xy=np.column_stack((x.ravel(),y.ravel()))
                    points=np.column_stack((xy+.5-192,np.ones(len(xy))))
                    uv=np.floor((np.linalg.inv(sprite_transform(model.layout,pose,part))@points.T).T[:,:2]).astype(int)
                    samples=zip(xy,uv)
                for (x,y),(u,v) in samples:
                    if not (0<=v<paint.shape[0] and 0<=u<paint.shape[1]):continue
                    sx,sy=int(u+part['offset'][0]),int(v+part['offset'][1])
                    if available[sy] or not paint[v,u,3] or not np.array_equal(treated_paint[v,u],image[y,x]):continue
                    frame=frames[view,row['clip'],row['frame']]
                    if frame_digest(native/frame['file'])!=frame['sha256']:raise ValueError('Changed native underlay frame')
                    full=np.asarray(load_frame(native/frame['file']).convert('RGBA'))
                    if not np.array_equal(full[y,x],image[y,x]):continue
                    found={'view':view,'piece':logical,'clip':row['clip'],'frame':row['frame'],
                        'native_xy':[int(x),int(y)],'source_xy':[sx,sy],
                        'native_rgba':image[y,x].tolist(),'source_rgba':paint[v,u].tolist(),
                        'native_frame_sha256':frame['sha256'],'native_piece_sha256':piece['sha256'],
                        'own_row_interior_donors':0,'native_flagged_regions':len(rows),
                        'crop':crop(full,row['finding']['bbox'],root/f'underlay_crops/{view}_{logical}.png'),
                        'decision':f'TODO_DESIGN_{view}_{logical}_row_paint'}
                    break
                if found:break
            if found:result.append(found)
    measurements=read_json(root/'repair_measurements.json')
    gates={(r['view'],r['clip'],r['frame']):r for r in triage['records'] if r['kind']=='gate' and r.get('native_joint_pockets')}
    def relative(path):
        path=Path(path)
        if path.is_absolute():return str(path.relative_to(CASE))
        prefix=Path('experiments/cutouts/chainbound_gaoler/rr38')
        return str(path.relative_to(prefix)) if path.is_relative_to(prefix) else str(path)
    for request in result:
        request['crop']=relative(request['crop'])
        pockets=[r for r in measurements['pockets'] if r['view']==request['view'] and r['piece']==request['piece'] and 'unresolved' in r]
        request['unresolved_native_joint_pockets']=[{k:r[k] for k in ('clip','frame','bbox','pixel_count','unresolved')}|
            {'crops':[relative(p) for p in gates[r['view'],r['clip'],r['frame']].get('crops',[])]} for r in pockets]
    report={'native_manifest_sha256':digest(native/'frames.json'),'triage_log_sha256':digest(root/'triage_source_final/triage.json'),
        'requests':result,'elapsed_seconds':time.monotonic()-began,
        'design_placeholders':{r['decision']:'Retained native texture flag has no own same-row interior donor at source '+str(r['source_xy'])+'; existing own-piece fill retained. Director decides whether to approve this texture or provide paint. See crop and any unresolved joint pockets.' for r in result},
        'note':'Native texture flags are diagnostic candidates, not automatic art rejection. These21 source-row gaps need director judgment; no new paint or colours have been invented.'}
    write_json(CASE/'proof/feedback2_underlay_requests.json',report)
    print(f'RR38 UNDERLAY WITNESSES: {len(result)} surfaces require director row-paint decisions')
    return report


if __name__=='__main__':run()

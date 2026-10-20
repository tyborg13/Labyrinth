"""Trace remaining canonical joint tears to clip-scoped own-surface texels."""
import numpy as np
from rr29_build import CASE,read_json,write_json
from cpu_proof import CpuPose
from humanoid_cutout.cpu_pose import sprite_transform
from humanoid_cutout.gait_continuations import nearest_donors,texture
from maquette_motion.pixels import PROOF_DEFAULTS
from maquette_motion.silhouette import dilate


def trace():
    census=read_json(CASE/'proof/census.json');samples=read_json(CASE/'proof/samples.json')
    definitions=read_json(CASE/'clip_continuation_targets.json') if (CASE/'clip_continuation_targets.json').exists() else {}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');model=CpuPose(CASE,layout)
        failures={(p['clip'],p['frame']):p['failures'] for p in census['views'][view]['failures'] if p['failures']}
        for pose in samples['samples']:
            key=(pose['clip'],pose['frame'])
            if pose['view']!=view or pose['kind']!='presented' or key not in failures:continue
            layers,maps=model.layers(pose);occupied=np.logical_or.reduce([p[...,3]>0 for _,p,_ in layers])
            for failure in failures[key]:
                left,top,right,bottom=failure['bbox'];target=np.zeros_like(occupied);target[top:bottom,left:right]=~occupied[top:bottom,left:right]
                candidates=[]
                for part in layout['parts']:
                    if not part.get('hidden_material'):continue
                    paint=texture(CASE,layout,part,clip=pose['clip'],gait=pose['clip']=='move')
                    if part['name'] in maps:
                        mapping=maps[part['name']];pick=target[mapping.pixels[:,1],mapping.pixels[:,0]]
                        xy,uv=mapping.pixels[pick],mapping.texels[pick]
                    else:
                        y,x=np.nonzero(target);xy=np.column_stack((x,y));inverse=np.linalg.inv(sprite_transform(layout,pose,part))
                        uv=np.floor((xy+.5-PROOF_DEFAULTS['source_offset'])@inverse[:2,:2].T+inverse[:2,2]).astype(int)
                    valid=(uv[:,0]>=0)&(uv[:,1]>=0)&(uv[:,0]<paint.shape[1])&(uv[:,1]<paint.shape[0])
                    uv,xy=uv[valid],xy[valid]
                    if not len(uv):continue
                    empty=paint[uv[:,1],uv[:,0],3]==0;uv,xy=uv[empty],xy[empty]
                    # rr20's same-surface domain bound; no distant paint patch.
                    own=next(p for p in layout['parts'] if p['logical_part']==part['logical_part'] and not p.get('hidden_material'))
                    donor=model.image(own['file']);ys,xs=np.nonzero(donor[...,3]);points=np.column_stack((xs,ys))+own['offset']
                    source=uv+part['offset']
                    close=np.array([np.min(np.linalg.norm(points-p,axis=1))<=2*read_json(CASE/'anatomy.json')['joint_continuations']['depth_px'] for p in source])
                    uv,xy=uv[close],xy[close]
                    if len(uv):candidates.append((len(np.unique(xy,axis=0)),part,uv))
                if not candidates:raise ValueError(f'No own-surface joint continuation for {view}/{key}/{failure}')
                _,part,uv=max(candidates,key=lambda c:c[0])
                record=definitions.setdefault(view,{}).setdefault(pose['clip'],{}).setdefault(part['name'],{'local_targets':[],'source_evidence':[]})
                record['local_targets']=[list(p) for p in sorted(set(map(tuple,record['local_targets']))|set(map(tuple,uv.tolist())),key=lambda p:(p[1],p[0]))]
                record['source_evidence'].append({'view':view,'clip':pose['clip'],'frame':pose['frame'],'pocket':failure})
                print(view,key,part['name'],uv.tolist())
    write_json(CASE/'clip_continuation_targets.json',definitions)


if __name__=='__main__':trace()

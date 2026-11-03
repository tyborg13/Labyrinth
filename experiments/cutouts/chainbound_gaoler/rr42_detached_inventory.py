"""Trace failing presented components back to immutable source UVs."""
import argparse
from pathlib import Path
import numpy as np
from rr42_underlay import CASE,inputs,repairs
from rr42_density import PROOF_CASE
from rr42_sweep import Surfaces
from rr38_cpu_diagnostics import Diagnostics
from rr42_repairs import merge_rows
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.cpu_pose import CpuPose,mapped,sprite_transform
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.canvas import for_case
from maquette_motion import pixels
from maquette_motion.silhouette import dilate


def run(case,view,clip,frame):
    layout=read_json(case/f'layouts/{view}.json');model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128)
    pose=next(r for r in read_json(case/'proof/logs/samples.json')['samples'] if (r['view'],r['clip'],r['frame'],r['kind'])==(view,clip,frame,'presented'))
    diag=Diagnostics(case,model);diag.surface=Surfaces(case,model)
    paint,_=inputs(); hidden=[];visible=[]
    with for_case(case):
        layers,maps=model.layers(pose);result=diag.measure(pose,layers,maps)
        owner=np.full(layers[0][1].shape[:2],'',object)
        for part,image,_ in sorted(layers,key=lambda l:l[0]['z_index']):owner[image[...,3]>0]=part['name']
        for component in result['detached']['unmatched_components']:
            xx,yy=np.asarray(component['pixels']).T
            for name in sorted(set(owner[yy,xx])):
                part=next(p for p in layout['parts'] if p['name']==name)
                source=texture(case,layout,part,gait=clip=='move',clip=clip)
                sy,sx=np.indices(source.shape[:2]);uv=np.zeros_like(source)
                uv[...,0]=sx+1;uv[...,1]=sy+1;uv[...,3]=source[...,3]
                coords=mapped(uv,maps[name]) if name in model.meshes else pixels.render(uv,sprite_transform(layout,pose,part))
                selected=owner[yy,xx]==name;data=coords[yy[selected],xx[selected]];data=data[data[:,3]>0]
                ox,oy=part['offset'];points=sorted({(int(x)-1+ox,int(y)-1+oy) for x,y in data[:,:2]})
                if part.get('hidden_material'):
                    if view!='front':raise ValueError('Rear hidden fragment requires rest-contact ownership, no new paint')
                    for x,y in points:
                        hidden.append({'part':name,'uv':[x,y],'before_rgba':source[y-oy,x-ox].tolist(),
                                       'director_rgba':paint[y,x].tolist(),'decision':'paint' if paint[y,x,3] else 'clear'})
                else:
                    if component['pixel_count']>=6:raise ValueError('Larger visible fragment still needs rest-contact re-ownership: '+str(points))
                    visible.append({'view':view,'source':name,'target':None,'decision':'clear','reason':'isolated presented speck under 6 px',
                        'source_pixels':len(points),'texels':[list(p) for p in points],'witness':[clip,frame],
                        'presented_pixels':component['pixel_count']})
    if hidden:
        prior={(r['part'],*r['uv']) for r in repairs()}
        hidden=[r for r in hidden if (r['part'],*r['uv']) not in prior]
        merge_rows([{'view':view,'clip':clip,'frame':frame,'repair_texels':hidden}])
    path=CASE.parent/'rr42_feedback1_fragments.json';old=read_json(path)
    for row in visible:
        if not any((r['view'],r['source'],r['texels'])==(row['view'],row['source'],row['texels']) for r in old['fragments']):old['fragments'].append(row)
    write_json(path,old)
    print('RR42 DETACHED UV TRACE:',view,clip,frame,'hidden',len(hidden),'visible',visible)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=PROOF_CASE);p.add_argument('--view',default='front');p.add_argument('--clip',default='reel');p.add_argument('--frame',type=int,default=33)
    a=p.parse_args();run(a.case,a.view,a.clip,a.frame)

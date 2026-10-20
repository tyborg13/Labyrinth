import sys
from pathlib import Path
sys.path.insert(0,'tools')
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion import pixels as P
case=Path(sys.argv[1]); cap=Path(sys.argv[2]); view=sys.argv[3]; pname=sys.argv[4]
nat=read_json(cap/'pixel_frames.json')
rows={r['frame']:r for r in nat['frames'] if r['view']==view and r['part']==pname}
samples=sorted((r for r in nat['samples'] if r['view']==view and r['clip']=='idle'),key=lambda r:r['frame'])
layout=read_json(case/f'layouts/{view}.json'); part=next(p for p in layout['parts'] if p['name']==pname)
img=load_frame(case/part['file']).convert('RGBA'); print('part size',img.size,'occupied',int((np.asarray(img)[...,3]>0).sum()),'bone',part['bone'],'z',part.get('z_index'))
for r in samples:
    node=r['parts'][pname]; e=rows[r['frame']]
    a=np.asarray(load_frame(cap/e['after']).convert('RGBA'))
    full=P.render(img,P.unpack(node['transform']),(0,0,512,512))
    ch=int(P.changed(a,full).sum()); un=int(((a[...,3]>0)|(full[...,3]>0)).sum())
    allow=P.PROOF_DEFAULTS['native_raster_edge_pixels']+un*P.PROOF_DEFAULTS['native_raster_fraction']
    t=P.unpack(node['transform'])
    print(r['frame'],'phase',r['presented_phase'],'changed',ch,'union',un,'allow',round(allow,2),'FAIL' if ch>allow else '', 't=',np.round(t[:2],4).tolist())
r=next(r for r in samples if r['frame']==12); node=r['parts'][pname]; e=rows[12]
a=np.asarray(load_frame(cap/e['after']).convert('RGBA')); t=P.unpack(node['transform']); full=P.render(img,t,(0,0,512,512))
ys,xs=np.nonzero(P.changed(a,full)); inv=np.linalg.inv(t)
for x,y in zip(xs,ys):
    src=inv@np.array([x+0.5-P.PROOF_DEFAULTS['source_offset'],y+0.5-P.PROOF_DEFAULTS['source_offset'],1])
    print('px',(x,y),'native',a[y,x].tolist(),'cpu',full[y,x].tolist(),'src',np.round(src[:2],5).tolist())
import inspect; print(inspect.getsource(P.render)[:1500])
from humanoid_cutout.native_frames import load_frame

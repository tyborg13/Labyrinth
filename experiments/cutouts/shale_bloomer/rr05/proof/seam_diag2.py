import sys
from pathlib import Path
sys.path.insert(0,'tools')
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion import pixels as P, raster as R
case=Path(sys.argv[1]); cap=Path(sys.argv[2])
nat=read_json(cap/'pixel_frames.json')
s=next(r for r in nat['samples'] if r['view']=='rear' and r['clip']=='idle' and r['frame']==12)
node=s['parts']['seam_core_arc_right']; print('raw transform field', node['transform'])
t=P.unpack(node['transform']).copy(); t[:2,2]+=128
img=Image.open(case/'seams/rear/seam_core_arc_right.png'); w,h=img.size
uv=np.array([[0,0],[w,0],[w,h],[0,h]],float); xy=uv@t[:2,:2].T+t[:2,2]
print('verts',xy.tolist())
fixed=np.floor(xy*256+0.5)/256; print('snapped',fixed.tolist())
for tri in R.QUAD_TRIANGLES:
    idx=list(tri); basis=np.concatenate((fixed[idx],np.ones((3,1))),axis=1); aff=np.linalg.solve(basis,uv[idx])
    for x in (308,311,312):
        X,Y=x+0.5,274.5
        print(tri,x,'u',X*aff[0,0]+Y*aff[1,0]+aff[2,0],'v',X*aff[0,1]+Y*aff[1,1]+aff[2,1])

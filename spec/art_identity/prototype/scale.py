import json, numpy as np
from PIL import Image, ImageFilter
from metrics import sets, erode, disk
def shape_scale(p):
    im=Image.open(p).convert('RGBA'); bb=im.getbbox(); im=im.crop(bb)
    a=np.asarray(im)[...,3]>128
    L=im.convert('L').filter(ImageFilter.MedianFilter(3))
    L=np.asarray(L).astype(float)
    inner=erode(a,disk(1))
    vals=L[inner]
    # quantize into 6 per-sprite quantile bands
    qs=np.quantile(vals,[1/6,2/6,3/6,4/6,5/6])
    Q=np.digitize(L,qs); Q[~a]=-1
    runs=[]
    for M in (Q,Q.T):
        for row in M:
            cur=None;n=0
            for v in row:
                if v==cur and v>=0: n+=1
                else:
                    if cur is not None and cur>=0 and n>0: runs.append(n)
                    cur=v;n=1
            if cur is not None and cur>=0: runs.append(n)
    runs=np.array(runs)
    # area-weighted mean run length (px)
    rl=(runs*runs).sum()/runs.sum()
    # regions: connected components of Q (4-conn) via label propagation
    H,W=Q.shape; lab=-np.ones((H,W),int); nreg=0; sizes=[]
    for y in range(H):
        for x in range(W):
            if Q[y,x]<0 or lab[y,x]>=0: continue
            v=Q[y,x]; st=[(y,x)]; lab[y,x]=nreg; c=0
            while st:
                cy,cx=st.pop(); c+=1
                for ny,nx in ((cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1)):
                    if 0<=ny<H and 0<=nx<W and lab[ny,nx]<0 and Q[ny,nx]==v:
                        lab[ny,nx]=nreg; st.append((ny,nx))
            sizes.append(c); nreg+=1
    sizes=np.array(sizes); big=sizes[sizes>=4]
    area=a.sum()
    feat=np.sqrt(area/len(big))  # typical feature size px
    return rl, len(big), feat, a.shape[0]
canon,new=sets()
out={}
for grp,lst in (('canon',canon),('new',new)):
    print('==',grp)
    for n,p in lst:
        rl,nr,f,h=shape_scale(p); out[n]=(rl,nr,f,h)
        print('%-20s h=%3d  run=%5.2f  regions=%4d  feat=%5.2f  feat/h=%.3f'%(n,h,rl,nr,f,f/h))
json.dump(out,open('scale.json','w'))

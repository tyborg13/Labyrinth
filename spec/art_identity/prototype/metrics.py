import sys, glob, os, json
import numpy as np
from PIL import Image
W='/Users/borgerding/workspace/Labyrinth.worktrees/'
PB=W+'peer-benchmark/'
def sets():
    canon=[('HERO',PB+'assets/units/protagonist_cutout/front/front_assembled_rest.png')]
    for p in sorted(glob.glob(PB+'assets/units/*_cutout/front/rest.png'))+sorted(glob.glob(PB+'assets/units/guardians/*/front/rest.png')):
        n=p.split('/')[-3]
        if 'protagonist' in n: continue
        canon.append((n.replace('_cutout',''),p))
    new=[]
    for n in ['burrow_grub','ember_tick','gloam_stalker','arc_thrall','gale_herald','hoarfrost_seer']:
        new.append((n,PB+'assets/art/enemies/%s.png'%n))
    for wt,ns in [('en-04',['briar_weaver','slag_mortar']),('en-05',['glacial_mirror','gust_shrike']),('en-06',['hollow_mimic','storm_capacitor'])]:
        for n in ns: new.append((n,W+wt+'/assets/art/enemies/%s.png'%n))
    return canon,new
def _shift(m,dy,dx,fill):
    out=np.full_like(m,fill)
    H,W=m.shape
    ys=slice(max(0,dy),H+min(0,dy)); yd=slice(max(0,-dy),H+min(0,-dy))
    xs=slice(max(0,dx),W+min(0,dx)); xd=slice(max(0,-dx),W+min(0,-dx))
    out[ys,xs]=m[yd,xd]; return out
def erode(m,st):
    r=st.shape[0]//2; out=np.ones_like(m)
    for dy in range(-r,r+1):
        for dx in range(-r,r+1):
            if st[dy+r,dx+r]: out&=_shift(m,dy,dx,False)
    return out
def dilate(m,st):
    r=st.shape[0]//2; out=np.zeros_like(m)
    for dy in range(-r,r+1):
        for dx in range(-r,r+1):
            if st[dy+r,dx+r]: out|=_shift(m,dy,dx,False)
    return out
def sobel(L):
    P=np.pad(L,1,mode='edge')
    gx=(P[:-2,2:]+2*P[1:-1,2:]+P[2:,2:])-(P[:-2,:-2]+2*P[1:-1,:-2]+P[2:,:-2])
    gy=(P[2:,:-2]+2*P[2:,1:-1]+P[2:,2:])-(P[:-2,:-2]+2*P[:-2,1:-1]+P[:-2,2:])
    return gx,gy
def disk(r):
    y,x=np.ogrid[-r:r+1,-r:r+1]; return x*x+y*y<=r*r
def metrics(p):
    im=np.asarray(Image.open(p).convert('RGBA')).astype(float)/255
    a=im[...,3]; m=a>0.5
    ys,xs=np.nonzero(m); y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    m=m[y0:y1,x0:x1]; rgb=im[y0:y1,x0:x1,:3]
    H,Wd=m.shape; area=m.sum()
    # mirror symmetry: best IoU over horizontal shifts
    best=0
    f=m[:,::-1]
    for s in range(-Wd//4,Wd//4+1):
        g=np.roll(f,s,axis=1)
        if s>0: g[:,:s]=False
        elif s<0: g[:,s:]=False
        iou=(m&g).sum()/max(1,(m|g).sum()); best=max(best,iou)
    # thin share
    op=dilate(erode(m,disk(2)),disk(2))
    thin=1-op.sum()/area
    # edge density on luminance inside eroded mask
    L=0.299*rgb[...,0]+0.587*rgb[...,1]+0.114*rgb[...,2]
    gx,gy=sobel(L); g=np.hypot(gx,gy)
    inner=erode(m,disk(1))
    edge=(g[inner]>0.35).mean()
    # silhouette complexity: perimeter^2/(4pi area)
    per=(m & ~erode(m,disk(1))).sum()
    comp=per*per/(4*np.pi*area)
    # value/chroma
    mx=rgb.max(-1); mn=rgb.min(-1)
    chroma=(mx-mn)[m].mean(); val=L[m].mean()
    # lower contact: lowest 8% of rows, horizontal extent of mask -> vs width
    return dict(h=H,w=Wd,area=int(area),sym=round(best,3),thin=round(thin,3),edge=round(edge,3),comp=round(comp,2),chroma=round(chroma,3),val=round(val,3))
if __name__=='__main__':
    canon,new=sets()
    out={}
    for grp,lst in [('canon',canon),('new',new)]:
        print('==',grp)
        for n,p in lst:
            r=metrics(p); out[n]=dict(r,grp=grp,path=p)
            print('%-20s h=%3d w=%3d sym=%.3f thin=%.3f edge=%.3f comp=%5.2f chroma=%.3f val=%.3f'%(n,r['h'],r['w'],r['sym'],r['thin'],r['edge'],r['comp'],r['chroma'],r['val']))
    json.dump(out,open(os.path.dirname(__file__)+'/metrics.json','w'),indent=1)

import sys, numpy as np
from PIL import Image
def process(raw, K, out):
    im=np.asarray(Image.open(raw).convert('RGB')).astype(float)
    g=np.array([0,255,0.]); d=np.abs(im-g).max(-1)
    a=np.clip((d-40)/40,0,1)              # hard key with a 40-80 ramp
    rgb=im.copy()
    # despill: clamp green to max(r,b) on edge pixels
    spill=a<1; rgb[...,1]=np.where(spill, np.minimum(rgb[...,1], np.maximum(rgb[...,0],rgb[...,2])), rgb[...,1])
    ys,xs=np.nonzero(a>0.5); y0,y1,x0,x1=ys.min(),ys.max()+1,xs.min(),xs.max()+1
    # pad crop to multiples of K anchored at bottom-left
    h=((y1-y0+K-1)//K)*K; w=((x1-x0+K-1)//K)*K
    y0=y1-h; x0=x0
    A=np.zeros((h,w)); C=np.zeros((h,w,3))
    sub=a[max(0,y0):y1, x0:x0+w]; A[h-sub.shape[0]:, :sub.shape[1]]=sub
    sc=rgb[max(0,y0):y1, x0:x0+w]; C[h-sc.shape[0]:, :sc.shape[1]]=sc
    pm=C*A[...,None]
    def box(x): return x.reshape(h//K,K,w//K,K,*x.shape[2:]).mean(axis=(1,3))
    As=box(A); Cs=box(pm)/np.maximum(As[...,None],1e-6)
    As=np.where(As>=0.5,1.0,0.0)          # binary alpha like canon
    spr=np.dstack([np.clip(np.rint(Cs),0,255),As*255]).astype(np.uint8)
    spr=Image.fromarray(spr,'RGBA'); bb=spr.getbbox(); spr=spr.crop(bb)
    canvas=Image.new('RGBA',(255,255),(0,0,0,0))
    x=128-spr.width//2; y=246-spr.height
    canvas.alpha_composite(spr,(max(0,x),max(0,y)))
    canvas.save(out); return spr.size
if __name__=='__main__':
    print(process(sys.argv[1],int(sys.argv[2]),sys.argv[3]))

"""Prototype: map a rear sprite's colours onto its approved front (Reinhard transfer in CIE Lab over opaque,
non-accent pixels). Accent pixels (chroma well above the body) keep their colour. Alpha is untouched."""
import sys, json, numpy as np
from PIL import Image
def srgb_to_lin(c): c=c/255.0; return np.where(c<=0.04045,c/12.92,((c+0.055)/1.055)**2.4)
def lin_to_srgb(c): c=np.clip(c,0,1); return np.where(c<=0.0031308,c*12.92,1.055*c**(1/2.4)-0.055)*255
M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]]); Mi=np.linalg.inv(M)
W=np.array([0.95047,1.0,1.08883])
def f(t): return np.where(t>(6/29)**3, np.cbrt(t), t/(3*(6/29)**2)+4/29)
def fi(t): return np.where(t>6/29, t**3, 3*(6/29)**2*(t-4/29))
def to_lab(rgb):
    xyz=srgb_to_lin(rgb)@M.T/W; fx,fy,fz=f(xyz[...,0]),f(xyz[...,1]),f(xyz[...,2])
    return np.stack([116*fy-16,500*(fx-fy),200*(fy-fz)],-1)
def from_lab(lab):
    fy=(lab[...,0]+16)/116; fx=fy+lab[...,1]/500; fz=fy-lab[...,2]/200
    xyz=np.stack([fi(fx),fi(fy),fi(fz)],-1)*W; return lin_to_srgb(xyz@Mi.T)
def body_mask(lab, alpha):
    c=np.hypot(lab[...,1],lab[...,2]); m=alpha>0
    thr=np.percentile(c[m],90)+15  # accent = far above the body's chroma
    return m & (c<=thr)
def match(front, rear, out):
    F=np.asarray(Image.open(front).convert('RGBA')).astype(float); R=np.asarray(Image.open(rear).convert('RGBA')).astype(float)
    Fl,Rl=to_lab(F[...,:3]),to_lab(R[...,:3]); fm,rm=body_mask(Fl,F[...,3]),body_mask(Rl,R[...,3])
    res=Rl.copy()
    for ch in range(3):
        mu_f,sd_f=Fl[...,ch][fm].mean(),Fl[...,ch][fm].std(); mu_r,sd_r=Rl[...,ch][rm].mean(),Rl[...,ch][rm].std()
        res[...,ch]=np.where(rm,(Rl[...,ch]-mu_r)*(sd_f/max(sd_r,1e-6))+mu_f,Rl[...,ch])
    rgb=np.clip(np.rint(from_lab(res)),0,255)
    rgb=np.where((R[...,3:]>0)&rm[...,None],rgb,R[...,:3])
    # strip near-black green key residue
    g=(rgb[...,1]>rgb[...,0]+20)&(rgb[...,1]>rgb[...,2]+20)&(R[...,3]>0)&~rm
    rgb[g]=np.stack([rgb[g].max(-1)*0+rgb[g][:,[0,2]].max(-1)]*3,-1)
    Image.fromarray(np.dstack([rgb,R[...,3]]).astype(np.uint8)).save(out)
if __name__=='__main__': match(*sys.argv[1:4])

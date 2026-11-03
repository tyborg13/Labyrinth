"""Lossless nearest-texel transport of up to sixteen independent proof masks."""
import numpy as np

MAX_MASKS=16


def encode(masks):
    if not masks or len(masks)>MAX_MASKS:raise ValueError('Footprint bit capacity exceeded')
    bits=np.zeros(next(iter(masks.values())).shape,np.uint16)
    for i,mask in enumerate(masks.values()):bits[mask]|=1<<i
    image=np.zeros((*bits.shape,4),np.uint8)
    image[...,0]=bits&255;image[...,1]=bits>>8;image[...,3]=np.where(bits,255,0)
    return image


def decode(frames,masks):
    bits=np.zeros(frames[0].shape[:2],np.uint16)
    for image in frames:
        value=image[...,0].astype(np.uint16)|(image[...,1].astype(np.uint16)<<8)
        bits |= np.where(image[...,3]>0,value,0).astype(np.uint16)
    return {name:(bits&(1<<i))>0 for i,name in enumerate(masks)}


def transport(image,mapping,masks,all_rounding):
    """Union mask fragments, including folded triangles and independent UVs.

    RGBA's last-opaque draw order cannot transport packed masks: a later
    triangle can contain B while only an earlier triangle contains A. Boolean
    mask transport is OR for each channel, so preserve both bits explicitly.
    """
    from maquette_motion import pixels
    h,w=image.shape[:2];limits=np.array([w-1,h-1])
    if all_rounding:
        default=np.where(mapping.ties,np.clip(mapping.texels,0,limits),mapping.texels)
        choices=[default]+[np.where((uv>=0)&(uv<=limits),uv,default) for uv in mapping.alternatives]
    else:choices=[mapping.texels]
    size=pixels.PROOF_DEFAULTS['canvas_size'];bits=np.zeros(size*size,np.uint16)
    source=image[...,0].astype(np.uint16)|(image[...,1].astype(np.uint16)<<8)
    for uv in choices:
        valid=np.all((uv>=0)&(uv<=limits),axis=-1)
        u,v=uv[valid].T;x,y=mapping.pixels[valid].T
        np.bitwise_or.at(bits,y*size+x,source[v,u])
    bits=bits.reshape((size,size))
    return {name:(bits&(1<<i))>0 for i,name in enumerate(masks)}

"""Isolate the generated flat-key rear artwork; preserve its painted pixels.

ImageGen authors the rear view. This deterministic asset-preparation step removes
only the magenta key and uniformly fits its height into the original255px canvas.
"""
from pathlib import Path
from PIL import Image


def main():
    base=Path(__file__).resolve().parent/'references'
    im=Image.open(base/'rear_keyed_source.png').convert('RGBA')
    values=[]
    for r,g,b,a in im.getdata():
        keyed=r>g+20 and b>g+20 and b>r*.5
        values.append((0,0,0,0) if keyed else (r,g,b,a))
    im.putdata(values)
    bbox=im.getchannel('A').getbbox()
    if not bbox:raise ValueError('Empty keyed source')
    scale=214/(bbox[3]-bbox[1])
    im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.NEAREST)
    bbox=im.getchannel('A').getbbox()
    result=Image.new('RGBA',(255,255))
    result.paste(im,((255-im.width)//2,223-bbox[3]))
    result.save(base/'rear.png')
    print('Prepared rear.png',result.getchannel('A').getbbox())


if __name__=='__main__':main()

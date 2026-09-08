"""Pack actual Godot frames into fixed-canvas sheets and front/rear videos.

This only assembles rendered pixels; it does not synthesize animation frames.
"""
from __future__ import annotations
import argparse,json,math,shutil,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from feedback_reel import write_previews
HERE=Path(__file__).resolve().parent


def label(draw,at,text,size=22,color='#d8c9ae'):
    try: font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',size)
    except OSError: font=ImageFont.load_default()
    draw.text(at,text,font=font,fill=color)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('frames_dir',type=Path)
    ap.add_argument('--output',type=Path,default=HERE/'renders/pass6')
    ap.add_argument('--require-both',action='store_true')
    args=ap.parse_args();output=args.output;output.mkdir(parents=True,exist_ok=True)
    source=json.loads((args.frames_dir/'render_manifest.json').read_text())
    if args.require_both and set(source['facings']) != {'front','rear'}:
        raise ValueError('Both real facings are required; a mirrored front is not a rear.')
    manifest={'uncloaked_animations':{},'frame_size':[512,512],'anchor':[(128+127.5)/512,(128+223)/512],
              'board_canvas_scale':512/255,'source_offset':[128,128],'animations':{}}
    clips={};count=0
    for facing,actions in source['facings'].items():
        for action,meta in actions.items():
            frames=[];columns=6;rows=math.ceil(meta['frames']/columns)
            sheet=Image.new('RGBA',(columns*512,rows*512))
            for frame in range(meta['frames']):
                path=args.frames_dir/(facing+'_'+action)/f'{frame:03d}.png'
                im=Image.open(path).convert('RGBA')
                if im.size != (512,512):raise ValueError('Unexpected frame size: '+str(path))
                bbox=im.getchannel('A').getbbox()
                if not bbox or min(bbox[0],bbox[1],512-bbox[2],512-bbox[3])<3:
                    raise ValueError('Empty or clipped animation frame: '+str(path))
                frames.append(im);sheet.paste(im,((frame%columns)*512,(frame//columns)*512));count+=1
            filename=f'{facing}_{action}.png';sheet.save(output/filename,optimize=True)
            bare_folder=args.frames_dir/(facing+'_'+action+'_without_cloak')
            if bare_folder.exists():
                bare_sheet=Image.new('RGBA',(columns*512,rows*512))
                for frame in range(meta['frames']):
                    image=Image.open(bare_folder/f'{frame:03d}.png').convert('RGBA')
                    if image.size != (512,512): raise ValueError('Unexpected uncloaked frame size')
                    bare_sheet.paste(image,((frame%columns)*512,(frame//columns)*512))
                bare_name=f'{facing}_{action}_without_cloak.png';bare_sheet.save(output/bare_name,optimize=True)
                manifest['uncloaked_animations'].setdefault(action,{})[facing]={'sheet':bare_name,'frames':meta['frames'],'cols':columns,'rows':rows,'fps':meta['fps'],'loop':meta['loop']}
            clips[(facing,action)]=frames
            manifest['animations'].setdefault(action,{})[facing]={'sheet':filename,'frames':len(frames),'cols':columns,'rows':rows,'fps':meta['fps'],'loop':meta['loop']}
        shutil.copyfile(args.frames_dir/(facing+'_rest.png'),output/(facing+'_rest.png'))
        models=HERE/'rigs';models.mkdir(exist_ok=True)
        shutil.copyfile(args.frames_dir/('reaver_'+facing+'.tscn'),models/('reaver_'+facing+'.tscn'))
    (output/'animations.json').write_text(json.dumps(manifest,indent=2)+'\n')
    # Preserve numeric source and trajectory checks; remove machine-specific folders.
    for actions in source['facings'].values():
        for meta in actions.values():meta.pop('folder',None)
    (output/'render_validation.json').write_text(json.dumps(source,indent=2)+'\n')
    facings=list(source['facings'])
    source_fps={action:int(meta["fps"]) for action,meta in source["facings"]["front"].items()}
    walk_frames,n=write_previews(clips,output,pass_number=6,source_fps=source_fps)
    # A smaller loop is convenient for inline review of the requested two walks.
    if walk_frames:
        gif_size=(960,round(walk_frames[0].height*960/walk_frames[0].width))
        small=[im.resize(gif_size,Image.Resampling.LANCZOS) for im in walk_frames]
        # One palette avoids encoding-induced color flicker. GIF delays have
        # 10ms precision, so distribute rounding instead of shortening every frame.
        sample=Image.new('RGB',(300*4,190*math.ceil(len(small)/4)))
        for index,im in enumerate(small):
            sample.paste(im.resize((300,190),Image.Resampling.NEAREST),((index%4)*300,(index//4)*190))
        palette=sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT)
        small=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in small]
        times=[round(i*100/source_fps["walk"])*10 for i in range(len(small)+1)]
        delays=[b-a for a,b in zip(times,times[1:])]
        small[0].save(output/'walking_front_rear.gif',save_all=True,append_images=small[1:],duration=delays,loop=0,disposal=2,optimize=False)
    # One shared walk crop retains every painted pixel in both facings.
    bounds=[im.getchannel('A').getbbox() for facing in facings for im in clips[(facing,'walk')]]
    crop=(min(b[0] for b in bounds)-8,min(b[1] for b in bounds)-8,
          max(b[2] for b in bounds)+8,max(b[3] for b in bounds)+8)
    cell=(crop[2]-crop[0]+24,crop[3]-crop[1]+60)
    contact=Image.new('RGB',(cell[0]*4,cell[1]*len(facings)),'#1b1d20');d=ImageDraw.Draw(contact)
    for row,facing in enumerate(facings):
        frames=clips[(facing,'walk')]
        for col,phase in enumerate((0,.25,.5,.75)):
            frame=int(len(frames)*phase)
            im=frames[frame].crop(crop)
            contact.paste(im,(col*cell[0]+12,row*cell[1]+48),im)
            label(d,(col*cell[0]+12,row*cell[1]+16),f'{facing.title()} / frame {frame+1}',18)
    contact.save(output/'walking_poses.png')
    print(json.dumps({'frames':count,'facings':facings,'sheets':len(clips),'video_frames':n,'rest':source['rest_reconstruction']},indent=2))

if __name__=='__main__':main()

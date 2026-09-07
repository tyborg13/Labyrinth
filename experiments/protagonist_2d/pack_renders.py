"""Pack actual Godot frames into fixed-canvas sheets and front/rear videos.

This only assembles rendered pixels; it does not synthesize animation frames.
"""
from __future__ import annotations
import argparse,json,math,shutil,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent


def label(draw,at,text,size=22,color='#d8c9ae'):
    try: font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',size)
    except OSError: font=ImageFont.load_default()
    draw.text(at,text,font=font,fill=color)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('frames_dir',type=Path)
    ap.add_argument('--output',type=Path,default=HERE/'renders')
    ap.add_argument('--require-both',action='store_true')
    args=ap.parse_args();output=args.output;output.mkdir(parents=True,exist_ok=True)
    source=json.loads((args.frames_dir/'render_manifest.json').read_text())
    if args.require_both and set(source['facings']) != {'front','rear'}:
        raise ValueError('Both real facings are required; a mirrored front is not a rear.')
    manifest={'frame_size':[512,512],'anchor':[(128+127.5)/512,(128+223)/512],
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
    video=output/'video_frames';video.mkdir(exist_ok=True)
    facings=list(source['facings']);n=0;walk_frames=[]
    for action in ('idle','walk','attack','block','hit'):
        length=len(clips[(facings[0],action)])
        for frame in range(length):
            canvas=Image.new('RGB',(1200,760),'#1b1d20');d=ImageDraw.Draw(canvas)
            label(d,(42,30),'REAVER / 2D SKELETAL EXPERIMENT',28)
            label(d,(42,80),action.upper(),24,'#c99b62')
            for index,facing in enumerate(facings):
                center=340+index*500
                im=clips[(facing,action)][frame]
                # A fixed camera crop is never fitted to individual alpha bounds.
                doubled=im.resize((1024,1024),Image.Resampling.NEAREST)
                canvas.paste(doubled,(center-511,630-702),doubled)
                label(d,(center-95,137),'Front' if facing=='front' else 'Rear',22)
            label(d,(42,704),'Original painted cutouts on 20 bones • fixed scale • in-place animation',19,'#a4a29a')
            canvas.save(video/f'{n:04d}.png');n+=1
            if action=='walk':walk_frames.append(canvas)
    ffmpeg=shutil.which('ffmpeg')
    if ffmpeg:
        subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate','24','-i',str(video/'%04d.png'),'-c:v','libx264','-crf','16','-pix_fmt','yuv420p','-movflags','+faststart',str(output/'animation_showcase.mp4')],check=True)
    # A smaller loop is convenient for inline review of the requested two walks.
    if walk_frames:
        small=[im.resize((960,608),Image.Resampling.LANCZOS) for im in walk_frames]
        small[0].save(output/'walking_front_rear.gif',save_all=True,append_images=small[1:],duration=42,loop=0,disposal=2,optimize=False)
    # Equal framing, four phases of the front/rear walks.
    contact=Image.new('RGB',(1200,720),'#1b1d20');d=ImageDraw.Draw(contact)
    for row,facing in enumerate(facings):
        frames=clips[(facing,'walk')]
        for col,phase in enumerate((0,.25,.5,.75)):
            frame=int(len(frames)*phase)
            im=frames[frame].crop((112,112,400,368))
            contact.paste(im,(col*300+6,row*360+54),im)
            label(d,(col*300+10,row*360+20),f'{facing.title()} / {frame+1}',18)
    contact.save(output/'walking_poses.png')
    print(json.dumps({'frames':count,'facings':facings,'sheets':len(clips),'video_frames':n,'rest':source['rest_reconstruction']},indent=2))

if __name__=='__main__':main()

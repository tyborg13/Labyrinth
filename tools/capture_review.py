"""Director comparison reels, including captures with recorded gate failures.

Composition matches humanoid_cutout.proof at the capture baseline. Kept outside
that renderer-bound package so repairing evidence collection does not invalidate
the director's existing frames. Gate results remain explicit review evidence;
the ordinary production proof command still requires passing canonical gates.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.proof import encode
from maquette_cutout_review import plan
from humanoid_cutout.native_frames import load_frame

FPS = 60
SHEET_COLUMNS = 8
SHEET_LABEL_HEIGHT_PX = 18
SHEET_CROP_MARGIN_PX = 3


def compose(case, capture, output, mode, gate_report):
    gate = read_json(gate_report)
    if type(gate.get('ok')) is not bool or not isinstance(gate.get('errors'), list):
        raise ValueError('Incomplete gate evidence: ' + str(gate_report))
    manifest = read_json(capture / 'frames.json')
    if manifest['inputs'] != __import__('humanoid_cutout.gates',fromlist=['bindings']).bindings(case):
        raise ValueError('Stale native proof inputs')
    if not manifest['native_pixels'] or not manifest['ok']: raise ValueError('Incomplete native capture')
    data = read_json(case / 'compiled_motion.json')
    if mode == 'idle':
        count = round(data['clips']['idle']['seconds'] * FPS * 5)
        paths = [capture / f'idle_comparison/frame_{i:04d}.png' for i in range(count)]
        encode(paths, output)
    else:
        if mode == 'review':
            if set(data['view_tracks']) != {'front','rear'}:
                raise ValueError('TODO_DESIGN_mq6_rear_delivery_and_paint: rr-04 two-view review deferred')
            order = list(read_json(case / 'director_motion.json')[data['creature']]['clips'])
            paths = []
            for clip, loops in plan(data,order):
                count = round(data['clips'][clip]['seconds'] * FPS)
                sequence = list(range(count)) * loops + ([count-1] * FPS if clip == 'death' else [])
                paths += [capture / f'pair_{clip}/frame_{frame:04d}.png' for frame in sequence]
            encode(paths,output)
        else:
            output.mkdir(parents=True,exist_ok=True)
            for view in data['view_tracks']:
                for clip in data['clips']:
                    rows = sorted([r for r in manifest['frames'] if r['view']==view and r['clip']==clip],key=lambda r:r['frame'])
                    bounds = [512,512,0,0]
                    for row in rows:
                        box = load_frame(capture / row['file']).getbbox()
                        if box:
                            bounds = [min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3])]
                    bounds = [max(0,bounds[0]-SHEET_CROP_MARGIN_PX),max(0,bounds[1]-SHEET_CROP_MARGIN_PX),
                              min(512,bounds[2]+SHEET_CROP_MARGIN_PX),min(512,bounds[3]+SHEET_CROP_MARGIN_PX)]
                    width,height=(bounds[2]-bounds[0])*3,(bounds[3]-bounds[1])*3
                    sheet = Image.new('RGB',(width*SHEET_COLUMNS,(height+SHEET_LABEL_HEIGHT_PX)*((len(rows)+SHEET_COLUMNS-1)//SHEET_COLUMNS)), '#1E1E24')
                    draw = ImageDraw.Draw(sheet)
                    for index,row in enumerate(rows):
                        image = load_frame(capture / row['file']).convert('RGBA').crop(tuple(bounds)).resize((width,height),Image.Resampling.NEAREST)
                        x,y=(index%SHEET_COLUMNS)*width,(index//SHEET_COLUMNS)*(height+SHEET_LABEL_HEIGHT_PX)
                        sheet.paste(image,(x,y),image)
                        draw.text((x,y+height),f'{clip} {row["frame"]:04d} phase={row["phase"]:.4f}',fill='white')
                    sheet.save(output / f'{view}_{clip}_3x.png')
            paths = list(output.glob('*_3x.png'))
    record = {'ok':True,'mode':mode,'frames':len(paths),'native_manifest_sha256':digest(capture/'frames.json'),
              'output':str(output),'fps':FPS,'inputs':manifest['inputs'],
              'gate_report': str(gate_report), 'gate_ok': gate['ok']}
    write_json(output / 'manifest.json' if mode=='sheets' else output.with_suffix('.json'),record)
    print('RR10 %s: PASS (%d frames; %s)' % (mode.upper(),len(paths),output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['idle','review','sheets'])
    parser.add_argument('--case',type=Path,required=True)
    parser.add_argument('--capture',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--gate-report',type=Path,required=True)
    args=parser.parse_args()
    compose(args.case,args.capture,args.output,args.mode,args.gate_report)


if __name__=='__main__': main()

"""Case sheets reuse the exact case verdict, never a different generic policy."""
import argparse
from pathlib import Path
from PIL import Image,ImageDraw
from build import CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame

COLUMNS=8
ZOOM=3
LABEL_HEIGHT=18
MARGIN=3


def compose(case,capture,output,gate_path):
    manifest=read_json(capture/'frames.json');gate=read_json(gate_path)
    if manifest['inputs']!=bindings(case):raise ValueError('Stale native proof inputs: rerun native')
    if gate.get('native_manifest_sha256')!=digest(capture/'frames.json') or gate.get('inputs')!=manifest['inputs']:
        raise ValueError('Case gate report does not belong to this capture')
    if not manifest.get('native_pixels') or not manifest.get('ok'):raise ValueError('Incomplete native capture')
    output.mkdir(parents=True,exist_ok=True);data=read_json(case/'compiled_motion.json');files=[]
    for view in data['view_tracks']:
        for clip in data['clips']:
            rows=sorted([r for r in manifest['frames'] if r['view']==view and r['clip']==clip],key=lambda r:r['frame'])
            size=load_frame(capture/rows[0]['file']).size;bounds=[*size,0,0]
            for row in rows:
                box=load_frame(capture/row['file']).getbbox()
                if box:bounds=[min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3])]
            bounds=[max(0,bounds[0]-MARGIN),max(0,bounds[1]-MARGIN),min(size[0],bounds[2]+MARGIN),min(size[1],bounds[3]+MARGIN)]
            width,height=(bounds[2]-bounds[0])*ZOOM,(bounds[3]-bounds[1])*ZOOM
            sheet=Image.new('RGB',(width*COLUMNS,(height+LABEL_HEIGHT)*((len(rows)+COLUMNS-1)//COLUMNS)),'#1E1E24');draw=ImageDraw.Draw(sheet)
            for index,row in enumerate(rows):
                image=load_frame(capture/row['file']).convert('RGBA').crop(bounds).resize((width,height),Image.Resampling.NEAREST)
                x,y=index%COLUMNS*width,index//COLUMNS*(height+LABEL_HEIGHT);sheet.paste(image,(x,y),image)
                draw.text((x,y+height),f'{clip} {row["frame"]:04d} phase={row["phase"]:.4f}',fill='white')
            path=output/f'{view}_{clip}_3x.png';sheet.save(path);files.append(str(path))
    result={'ok':gate['ok'],'native_manifest_sha256':digest(capture/'frames.json'),'gate_report_sha256':digest(gate_path),
            'gate_errors':gate['errors'],'diagnostic':not gate['ok'],'files':files,'native_pixels':True}
    write_json(output/'manifest.json',result)
    print('RR56 SHEETS: %s (%d sheets; same case verdict, %d errors)'%('PASS' if gate['ok'] else 'FAIL; diagnostic saved',len(files),len(gate['errors'])))
    return gate['ok']

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--case',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    raise SystemExit(0 if compose(a.case,a.capture,a.output,a.case/'proof/native_gates.json') else 1)

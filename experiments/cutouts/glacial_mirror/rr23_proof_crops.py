"""Compose guard contact and all-clip ankle sheets from fresh native captures."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

from rr18_case import CASE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame, frame_digest

PROOF_SIZE=(1920,1080)
PROOF_BACKGROUND=(30,30,36)
PROOF_MARGIN_PX=8
PROOF_LABEL_HEIGHT_PX=36
PROOF_MAX_ZOOM=3
PROOF_SHEET_COLUMNS=3
PROOF_CELLS_PER_SHEET=9
PROOF_MID_PHASE=.5


def compose(capture, output, contract_only=False):
    contract=read_json(CASE/'rr23_crops_contract.json')
    if contract_only:
        if len(contract['required_images'])!=6 or contract['expected_sizes']!=['1920x1080']:
            raise ValueError('Incomplete guard/ankle proof contract')
        print('RR23 CROP PROBE LOAD: PASS (native-only input, 1920x1080 output)')
        return
    manifest=read_json(capture/'frames.json')
    if not manifest['native_pixels'] or not manifest['ok'] or manifest['inputs']!=bindings(CASE):
        raise ValueError('Fresh complete native capture required')
    data=read_json(CASE/'compiled_motion.json')
    output.mkdir(parents=True,exist_ok=True)
    records=[]
    def crop(view,clip,frame,names):
        row=next(r for r in manifest['frames'] if (r['view'],r['clip'],r['frame'])==(view,clip,frame))
        source=capture/row['file']
        if frame_digest(source)!=row['sha256']:raise ValueError('Changed native capture: '+str(source))
        bounds=None
        for part in manifest['pieces']:
            if (part['view'],part['clip'],part['frame'])!=(view,clip,frame) or part['name'] not in names:continue
            box=load_frame(capture/part['file']).getbbox()
            if box:
                bounds=list(box) if bounds is None else [min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3])]
        if bounds is None:raise ValueError('Missing native parts: '+str(names))
        bounds=[max(0,bounds[0]-PROOF_MARGIN_PX),max(0,bounds[1]-PROOF_MARGIN_PX),
                min(512,bounds[2]+PROOF_MARGIN_PX),min(512,bounds[3]+PROOF_MARGIN_PX)]
        records.append({'view':view,'clip':clip,'frame':frame,'native_file':row['file'],'native_sha256':row['sha256'],'crop':bounds})
        return load_frame(source).convert('RGBA').crop(bounds)
    def sheet(name,cells,columns):
        canvas=Image.new('RGB',PROOF_SIZE,PROOF_BACKGROUND)
        draw=ImageDraw.Draw(canvas)
        rows=(len(cells)+columns-1)//columns
        width,height=PROOF_SIZE[0]//columns,PROOF_SIZE[1]//rows
        for index,(label,image) in enumerate(cells):
            zoom=min(PROOF_MAX_ZOOM,width//image.width,(height-PROOF_LABEL_HEIGHT_PX)//image.height)
            if zoom<1:raise ValueError('Proof crop does not fit without shrinking')
            image=image.resize((image.width*zoom,image.height*zoom),Image.Resampling.NEAREST)
            x=(index%columns)*width+(width-image.width)//2
            y=(index//columns)*height+PROOF_LABEL_HEIGHT_PX
            canvas.paste(image,(x,y),image)
            draw.text(((index%columns)*width+PROOF_MARGIN_PX,(index//columns)*height+PROOF_MARGIN_PX),label,fill='white')
        canvas.save(output/name)
    for view in ('front','rear'):
        guard=[r for r in manifest['frames'] if r['view']==view and r['clip']=='guard']
        contact=min(guard,key=lambda r:abs(r['phase']-data['clips']['guard']['contact']))
        guard_names={'torso','head','fore_near','fist_near','fore_far','fist_far'}
        sheet(f'{view}_guard_contact.png',[(f'{view} guard contact frame {contact["frame"]}',crop(view,'guard',contact['frame'],guard_names))],1)
        cells=[]
        for clip in data['clips']:
            frames=sorted([r for r in manifest['frames'] if r['view']==view and r['clip']==clip],key=lambda r:r['frame'])
            # Every clip: first/contact-or-mid/last, both ankles in each crop.
            phases=(0,data['clips'][clip].get('contact',PROOF_MID_PHASE),1)
            for phase in phases:
                row=min(frames,key=lambda r:abs(r['phase']-phase))
                names={prefix+bone+'_'+side for prefix in ('','hidden_') for bone in ('shin','foot') for side in ('near','far')}
                cells.append((f'{view} {clip} frame {row["frame"]}',crop(view,clip,row['frame'],names)))
        # Six clips, split to keep native pixels readable at integer zoom.
        sheet(f'{view}_ankles_a.png',cells[:PROOF_CELLS_PER_SHEET],PROOF_SHEET_COLUMNS)
        sheet(f'{view}_ankles_b.png',cells[PROOF_CELLS_PER_SHEET:],PROOF_SHEET_COLUMNS)
    write_json(output/'manifest.json',{'native_pixels':True,'native_manifest_sha256':digest(capture/'frames.json'),
               'size':list(PROOF_SIZE),'ui_scale':1.0,'inputs':manifest['inputs'],'crops':records})
    from visual_probe_runner import validate_pngs
    validate_pngs(sorted(output.glob('*.png')),6,{PROOF_SIZE},contract)
    print('RR23 GUARD/ANKLE CROPS: PASS (both views; 6 sheets; native input only)')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,default=CASE/'proof/native')
    parser.add_argument('--output',type=Path,default=CASE/'proof/rr23_native_crops')
    parser.add_argument('--validate-only',action='store_true')
    args=parser.parse_args()
    compose(args.capture,args.output,args.validate_only)

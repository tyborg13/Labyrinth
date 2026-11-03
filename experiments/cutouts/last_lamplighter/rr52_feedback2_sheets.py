"""Same-pose native-before / software-after coverage diagnostics."""
from PIL import Image
from rr52_build import CASE
from rr52_feedback1_sheets import render
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame

DEFAULTS={'crop_margin_px':8,'scale':4,'background_rgba':[140,140,140,255]}
FRAMES=(('rear','snuff',20),('rear','mourning_hook',20),('rear','death',88),('front','mourning_hook',48),('front','move',5))


def run():
    case=CASE/'proof/production_case';capture=CASE/'proof/native';manifest=read_json(capture/'frames.json');output=CASE/'proof/feedback2_sheets';output.mkdir(exist_ok=True);rows=[]
    for view in ('front','rear'):
        selected={(c,f) for v,c,f in FRAMES if v==view};prediction=render(case,view,selected)
        for clip,frame in sorted(selected):
            row=next(r for r in manifest['frames'] if (r['view'],r['clip'],r['frame'])==(view,clip,frame));before=load_frame(capture/row['file']).convert('RGBA');after=prediction[clip,frame];a,b=before.getbbox(),after.getbbox();m=DEFAULTS['crop_margin_px'];box=(min(a[0],b[0])-m,min(a[1],b[1])-m,max(a[2],b[2])+m,max(a[3],b[3])+m);w,h=box[2]-box[0],box[3]-box[1]
            sheet=Image.new('RGBA',(w*2,h),tuple(DEFAULTS['background_rgba']));sheet.alpha_composite(before.crop(box),(0,0));sheet.alpha_composite(after.crop(box),(w,0));name=f'{view}_{clip}_{frame:03d}.png';scale=DEFAULTS['scale'];sheet.resize((sheet.width*scale,sheet.height*scale),Image.Resampling.NEAREST).save(output/name);rows.append({'view':view,'clip':clip,'frame':frame,'file':name})
    write_json(output/'manifest.json',{'columns':['original native','new CPU prediction (not recaptured)'],'defaults':DEFAULTS,'frames':rows,'current_inputs':bindings(case),'native_manifest_sha256':digest(capture/'frames.json')})
    print(f'RR52 COVERAGE SHEETS: {len(rows)} same-pose native-before / CPU-after diagnostics')

if __name__=='__main__':run()

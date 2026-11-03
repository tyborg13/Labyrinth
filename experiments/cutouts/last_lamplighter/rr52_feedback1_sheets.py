"""Same-frame before/after CPU diagnostics; these are not renderer proof."""
from collections import Counter
import numpy as np
from PIL import Image,ImageDraw
from rr52_build import CASE,VIEWS
from rr52_joint_budget import CpuPose,pose_layers
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import mask_mesh

DEFAULTS={'crop_margin_px':8,'scale':4,'background_rgba':[140,140,140,255],
          'finding_rgba':[255,0,0,255],'finding_width_px':1}


def render(case,view,selection):
    samples=read_json(case/'proof/raster_samples.json');motion=read_json(case/'compiled_motion.json')
    layout=read_json(case/f'layouts/{view}.json');result={}
    with for_case(case):
        model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128)
        for name,mesh in model.meshes.items():
            selected=mask_mesh(mesh,model.image(next(p['file'] for p in layout['parts'] if p['name']==name))[...,3]>0)
            if selected['triangles']:model.meshes[name]=selected
        for row in samples['samples']:
            key=(row['clip'],row['frame'])
            if row['view']!=view or key not in selection:continue
            layers,_=pose_layers(model,row,motion);image=np.zeros_like(layers[0][1])
            for _,paint,_ in sorted(layers,key=lambda r:r[0]['z_index']):image[paint[...,3]>0]=paint[paint[...,3]>0]
            result[key]=Image.fromarray(image)
    return result


def run():
    before=CASE/'proof/feedback1_before';old=read_json(before/'proof/cpu_sweep.json');new=read_json(CASE/'proof/cpu_sweep.json')
    motion=read_json(CASE/'compiled_motion.json');output=CASE/'proof/feedback1_sheets';output.mkdir(exist_ok=True);records=[]
    for view in VIEWS:
        selected={}
        for clip in motion['clips']:
            count=Counter(r['frame'] for r in old['errors'] if (r['view'],r['clip'])==(view,clip))
            selected[clip]=max(count,key=count.get) if count else 0
        keys=set(selected.items());images=[render(c,view,keys) for c in (before,CASE)]
        for clip,frame in selected.items():
            key=(clip,frame);bounds=[im[key].getbbox() for im in images];m=DEFAULTS['crop_margin_px']
            box=(max(0,min(b[0] for b in bounds)-m),max(0,min(b[1] for b in bounds)-m),max(b[2] for b in bounds)+m,max(b[3] for b in bounds)+m)
            width,height=box[2]-box[0],box[3]-box[1];sheet=Image.new('RGBA',(width*2,height*2),tuple(DEFAULTS['background_rgba']))
            for index,(im,report) in enumerate(zip(images,(old,new))):
                clean=Image.new('RGBA',(width,height),tuple(DEFAULTS['background_rgba']));clean.alpha_composite(im[key].crop(box));overlay=clean.copy();draw=ImageDraw.Draw(overlay)
                findings=[r for r in report['errors'] if (r['view'],r['clip'],r['frame'])==(view,clip,frame)]
                for r in findings:
                    b=r.get('source_space',r.get('component',{})).get('bbox')
                    if b:draw.rectangle((b[0]-box[0],b[1]-box[1],b[2]-box[0]-1,b[3]-box[1]-1),outline=tuple(DEFAULTS['finding_rgba']),width=DEFAULTS['finding_width_px'])
                sheet.alpha_composite(clean,(0,index*height));sheet.alpha_composite(overlay,(width,index*height))
            path=output/f'{view}_{clip}_{frame:03d}.png';scale=DEFAULTS['scale'];sheet.resize((sheet.width*scale,sheet.height*scale),Image.Resampling.NEAREST).save(path)
            records.append({'view':view,'clip':clip,'frame':frame,'file':path.name,'crop':box,'before_findings':sum((r['view'],r['clip'],r['frame'])==(view,clip,frame) for r in old['errors']),'after_findings':sum((r['view'],r['clip'],r['frame'])==(view,clip,frame) for r in new['errors'])})
    write_json(output/'manifest.json',{'native_pixels':False,'rows':['before','after'],'columns':['clean','findings'],'defaults':DEFAULTS,'frames':records,'before_report_sha256':digest(before/'proof/cpu_sweep.json'),'after_report_sha256':digest(CASE/'proof/cpu_sweep.json')})
    print(f'RR52 CPU BEFORE/AFTER SHEETS: {len(records)} same-frame diagnostics; native pixels=false')

if __name__=='__main__':run()

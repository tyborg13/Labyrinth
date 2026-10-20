"""Actual rr20 before crops from its preserved paint and headless Bone2D poses."""
from PIL import Image
from rr29_build import CASE,BASE,read_json,write_json,digest
from rr29_measure import box,PROOF
from cpu_proof import CpuPose
from maquette_motion.pixels import PROOF_DEFAULTS


def build():
    source=CASE/'proof/before_samples.json'
    samples=read_json(source)
    findings=read_json(CASE/'proof/draw_order_findings.json')['findings']
    layout=read_json(BASE/'layouts/front.json');model=CpuPose(BASE,layout)
    torso=next(p for p in layout['parts'] if p['name']=='torso')
    poses={(p['clip'],p['frame']):p for p in samples['samples'] if p['view']=='front' and p['kind']=='presented'}
    records=[]
    for finding in findings:
        pose=poses[(finding['clip'],finding['frame'])]
        layers,_=model.layers(pose);image=Image.new('RGBA',(512,512))
        for part,paint,_ in sorted(layers,key=lambda row:row[0]['z_index']):image.alpha_composite(Image.fromarray(paint))
        bounds=box(layout,pose,torso);origin=PROOF_DEFAULTS['source_offset'];pad=PROOF['crop_padding_px']
        image=image.crop([int(bounds[0])+origin-pad,int(bounds[1])+origin-pad,int(bounds[2])+origin+pad,int(bounds[3])+origin+pad])
        image=image.resize((image.width*PROOF['crop_zoom'],image.height*PROOF['crop_zoom']),Image.Resampling.NEAREST)
        output=CASE/f'proof/draw_order/rr20_{pose["clip"]}_{pose["frame"]:03d}_{finding["side"]}_before.png'
        output.parent.mkdir(parents=True,exist_ok=True);image.save(output)
        records.append({'clip':pose['clip'],'frame':pose['frame'],'side':finding['side'],
            'file':str(output.relative_to(CASE)),'sha256':digest(output)})
    write_json(CASE/'proof/rr20_before_crops.json',{'native_pixels':False,'scope':'preserved rr20 source paint and original static draw order',
        'sample_sha256':digest(source),'layout_sha256':digest(BASE/'layouts/front.json'),'records':records})
    print(f'RR29 RR20 BEFORE CROPS: PASS ({len(records)} original frames; CPU diagnostic only)')


if __name__=='__main__':build()

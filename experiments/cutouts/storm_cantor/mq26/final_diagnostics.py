"""One inspected-size source crop for every unresolved strict failure class."""
from collections import Counter
import numpy as np
from PIL import Image
from build import CASE
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.canvas import for_case
from surface_policy import model
from cpu_sweep import pose_layers

CROP_ZOOM=4
CROP_PADDING=4


def base_category(e):
    if e['kind']=='paint_metric':return e['metric']
    if e['kind']=='joint_hole':return 'joint_'+e['joint']
    if e['kind']=='held_release':return 'staff_release' if 'released held' in e['message'] else 'assembly_counter'
    logical=e['logical_part']
    if logical in ('cloak','tabard'):
        return logical+('_idle_hit' if e['clip'] in ('idle','hit') else '_over_6px' if e['component']['pixel_count']>6 else '_small_blocked')
    return logical


def category(e):
    base=base_category(e)
    return e['clip']+'_'+base if e['clip'] in ('idle','hit') else base


def run():
    cpu=read_json(CASE/'proof/cpu_sweep.json');rows={(r['view'],r['clip'],r['frame']):r for r in read_json(CASE/'proof/raster_samples.json')['samples']};data=read_json(CASE/'compiled_motion.json')
    by={}
    for error in cpu['errors']:by.setdefault(category(error),[]).append(error)
    out=CASE/'proof/feedback2/final_classes';out.mkdir(parents=True,exist_ok=True);records=[]
    with for_case(CASE):
        models={v:model(CASE,v) for v in ('front','rear')}
        for name,errors in sorted(by.items()):
            def size(e):return e.get('component',e.get('source_space',{})).get('pixel_count',e.get('count',0))
            witness=max(errors,key=size);key=(witness['view'],witness['clip'],witness['frame']);row=rows[key];layers,_=pose_layers(models[key[0]],row,data)
            image=Image.new('RGBA',(640,640))
            for p,paint,_ in sorted(layers,key=lambda r:r[0]['z_index']):image.alpha_composite(Image.fromarray(paint))
            bound=witness.get('component',witness.get('source_space',{})).get('bbox')
            if bound is None and witness['kind']=='paint_metric' and witness['metric']=='dark_slab_blocks':
                from maquette_motion.material_palette import outline_class,rules
                from surface_policy import box
                occupied=np.zeros((640,640),bool);dark=np.zeros_like(occupied)
                for p,paint,checks in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
                    alpha=paint[...,3]>0;shown=alpha&~occupied
                    dark|=shown&(checks[...,1]>0)&outline_class(paint,rules(CASE,key[0]));occupied|=alpha
                blocks=np.ones((638,638),bool)
                for dy in range(3):
                    for dx in range(3):blocks&=dark[dy:dy+638,dx:dx+638]
                block_box=box(blocks)
                if block_box:bound=[*block_box[:2],block_box[2]+2,block_box[3]+2]
            if bound is None and witness['kind']=='held_release' and 'released held' in witness['message']:
                from surface_policy import box
                bound=box(np.logical_or.reduce([paint[...,3]>0 for p,paint,_ in layers if p['logical_part']=='staff']))
            if bound is None:bound=list(image.getbbox())
            bound=[max(0,bound[0]-CROP_PADDING),max(0,bound[1]-CROP_PADDING),min(640,bound[2]+CROP_PADDING),min(640,bound[3]+CROP_PADDING)]
            crop=image.crop(bound);path=out/f'{name}_x4.png';crop.resize((crop.width*CROP_ZOOM,crop.height*CROP_ZOOM),Image.Resampling.NEAREST).save(path)
            record={'class':name,'findings':len(errors),'view':key[0],'clip':key[1],'frame':key[2],'crop':str(path.relative_to(CASE)),'native_pixels':False,'witness':witness}
            if name.startswith('joint_'):record['recommendation']='Director review of the provided joint continuation; keep blocking unless the missing receiver material is supplied or the authored excursion is revised.'
            elif name.startswith(('cloak','tabard')):record['recommendation']='Review this remaining strand/neck. Do not extend the six-pixel/eight-pixel ruling, especially in idle or hit.'
            elif name in ('staff','staff_release','head'):record['recommendation']='Review source-tip/rigid-raster separation. Keep blocking; a cloth exception cannot apply. Any silhouette repaint or angle change needs director direction.'
            elif name=='assembly_counter':record['recommendation']='Derived count: resolve the component classes listed separately.'
            else:record['recommendation']='Keep blocking; inspect the source ownership/coverage at this named physical part before accepting.'
            records.append(record)
    write_json(out/'index.json',{'native_pixels':False,'classes':records,'counts':dict(Counter(category(e) for e in cpu['errors']))})
    print('RR56 FINAL CLASS CROPS: %d classes, 4x source crops, CPU predictions only'%len(records))
    return records

if __name__=='__main__':run()

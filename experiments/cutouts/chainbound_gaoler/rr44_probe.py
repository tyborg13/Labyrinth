"""Bounded current-pose diagnostics and explicit CPU joint crops."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr44_case import CASE,DEFAULTS
from rr44_diagnostics import Diagnostics
from rr42_raster import pose_for_raster
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from cutout_pipeline.cases import read_json,write_json,digest


def measure(case,samples,view,clip,frames,output=None):
    layout=read_json(case/f'layouts/{view}.json')
    model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128);diagnostic=Diagnostics(case,model)
    rows=[]
    with for_case(case):
        for original in samples['samples']:
            if (original['view'],original['clip'],original['kind'])!=(view,clip,'presented') or original['frame'] not in frames:continue
            pose=pose_for_raster(original);layers,maps=model.layers(pose);result=diagnostic.measure(pose,layers,maps)
            result.update(view=view,clip=clip,frame=pose['frame'],native_pixels=False)
            if output:
                output.mkdir(parents=True,exist_ok=True);picture=np.zeros_like(layers[0][1])
                for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):picture[image[...,3]>0]=image[image[...,3]>0]
                from maquette_motion import pixels
                for joint in ('head','fore_near','fore_far'):
                    x,y=np.asarray(pose['bones'][joint]['global'][4:])+pixels.PROOF_DEFAULTS['source_offset'];radius=DEFAULTS['crop_context_px']
                    crop=Image.fromarray(picture).crop((round(x)-radius,round(y)-radius,round(x)+radius,round(y)+radius))
                    crop.resize((crop.width*4,crop.height*4),Image.Resampling.NEAREST).save(output/f'{view}_{clip}_{pose["frame"]:03d}_{joint}_cpu_4x.png')
            rows.append(result)
    return rows


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--samples',type=Path)
    p.add_argument('--view',required=True);p.add_argument('--clip',required=True);p.add_argument('--frames',required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();frames=[int(f) for f in a.frames.split(',')]
    if len(frames)>4:p.error('Use at most four frames per process')
    source=a.samples or a.case/'proof/logs/samples.json';rows=measure(a.case,read_json(source),a.view,a.clip,frames,a.output)
    write_json(a.output/'diagnostics.json',dict(samples_sha256=digest(source),frames=rows,native_pixels=False))
    for row in rows:print(f'RR44 FOCUSED CPU {a.view}/{a.clip}/{row["frame"]}: {row["kinds"]}; strays={row["clean"]["stray_components"]}; seams={len(row["source_space"]["failures"])}')

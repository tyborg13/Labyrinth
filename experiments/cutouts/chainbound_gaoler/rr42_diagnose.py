"""Focused computed masks/part receipts for the director; no new paint."""
import argparse
import numpy as np
from PIL import Image
from rr42_density import CASE,PROOF_CASE
from rr42_exposure import PaintedExposure
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case


def run(clip,frame):
    pose=next(p for p in read_json(PROOF_CASE/'proof/logs/samples.json')['samples'] if
              (p['view'],p['clip'],p['kind'],p['frame'])==('front',clip,'presented',frame))
    gate=PaintedExposure(CpuPose(PROOF_CASE,read_json(PROOF_CASE/'layouts/front.json'),native_skin=True,triangle_batch_size=128))
    with for_case(PROOF_CASE): metrics=gate.measure(pose)
    output=CASE/'proof/logs/exposure_witnesses';output.mkdir(parents=True,exist_ok=True)
    prefix=f'front_{clip}_{frame:03d}'
    for name,mask in [('procedural',gate.last_invalid),('missing',gate.last_missing)]:
        Image.fromarray(mask.astype('uint8')*255).save(output/(prefix+'_'+name+'.png'))
    result={'native_pixels':False,'view':'front','clip':clip,'frame':frame,'metrics':metrics,'fragments':gate.last_rows}
    write_json(output/(prefix+'.json'),result)
    print('RR42 EXPOSURE WITNESS:',prefix,metrics,sorted({r['part'] for r in gate.last_rows}))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--clip',default='move');parser.add_argument('--frame',type=int,default=12)
    args=parser.parse_args();run(args.clip,args.frame)

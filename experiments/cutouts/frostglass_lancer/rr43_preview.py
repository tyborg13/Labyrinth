"""Fixed-camera software construction previews; never native renderer proof."""
from pathlib import Path
import numpy as np
from PIL import Image
from rr37_case import CASE
from rr37_proof_case import PROOF_CASE
from rr37_raster import CpuPose
from cutout_pipeline.cases import read_json
from humanoid_cutout.canvas import for_case

PROOF_DEFAULTS = {'canvas_px':640, 'nearest_scale':2, 'front_lunge_frames':list(range(56,63)), 'fallback_phase':.5}


def render():
    output = CASE/'proof/rr43_software'
    output.mkdir(parents=True, exist_ok=True)
    (output/'.gdignore').write_text('# Software construction preview output.\n')
    samples = read_json(PROOF_CASE/'proof/logs/samples.json')['samples']
    clips = read_json(PROOF_CASE/'compiled_motion.json')['clips']
    selected = [r for r in samples if r['view']=='front' and r['clip']=='lunge' and
        r['kind']=='presented' and r['frame'] in PROOF_DEFAULTS['front_lunge_frames']]
    for clip, definition in clips.items():
        rows = [r for r in samples if r['view']=='rear' and r['clip']==clip and r['kind']=='presented']
        selected.append(min(rows,key=lambda r:abs(r['phase']-definition.get('contact',PROOF_DEFAULTS['fallback_phase']))))
    with for_case(PROOF_CASE):
        models = {v:CpuPose(PROOF_CASE,read_json(PROOF_CASE/f'layouts/{v}.json')) for v in ('front','rear')}
        for pose in selected:
            layers,_ = models[pose['view']].layers(pose)
            image = Image.new('RGBA',(PROOF_DEFAULTS['canvas_px'],)*2)
            for _,pixels,_ in sorted(layers,key=lambda r:r[0]['z_index']): image.alpha_composite(Image.fromarray(pixels))
            path = output/f'{pose["view"]}_{pose["clip"]}_{pose["frame"]:04d}.png'
            image.resize(tuple(n*PROOF_DEFAULTS['nearest_scale'] for n in image.size),Image.Resampling.NEAREST).save(path)
    print(f'RR43 SOFTWARE PREVIEWS: PASS ({len(selected)} fixed-camera frames; {output}; NOT native proof)')


if __name__=='__main__': render()

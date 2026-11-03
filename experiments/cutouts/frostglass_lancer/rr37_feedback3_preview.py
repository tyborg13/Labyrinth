"""Software construction previews for the director's retained feedback poses.

These composites use treated production textures and actual retained runtime
transforms. They do not replace fresh windowed native proof.
"""
from PIL import Image
from cutout_pipeline.cases import read_json
from humanoid_cutout.canvas import for_case
from rr37_case import CASE
from rr37_feedback3_fixture import TARGET
from rr37_proof_case import PROOF_CASE
from rr37_raster import CpuPose
from rr37_uncovered import UncoveredSurface

PREVIEW_DEFAULTS = {'crop': [140, 130, 430, 430], 'scale': 4}


def capture():
    poses = read_json(TARGET / 'poses.json')['samples']
    output = CASE / 'proof/feedback3_cpu'
    output.mkdir(exist_ok=True)
    with for_case(CASE):
        for view in ('front', 'rear'):
            model = CpuPose(PROOF_CASE, read_json(PROOF_CASE / f'layouts/{view}.json'))
            gate = UncoveredSurface(PROOF_CASE, model)
            for pose in poses:
                if pose['view'] != view: continue
                layers, maps = model.layers(pose)
                metrics = gate.measure(pose, layers, maps)
                if any(metrics.values()): raise ValueError(metrics)
                image = Image.new('RGBA', layers[0][1].shape[1::-1])
                for _, paint, _ in sorted(layers, key=lambda row: row[0]['z_index']):
                    image.alpha_composite(Image.fromarray(paint))
                name = f'{view}_{pose["clip"]}_{pose["frame"]:04d}'
                image.save(output / (name + '.png'))
                crop = image.crop(PREVIEW_DEFAULTS['crop'])
                crop.resize(tuple(n * PREVIEW_DEFAULTS['scale'] for n in crop.size),
                            Image.Resampling.NEAREST).save(output / (name + '_4x.png'))
                print(f'RR37 SOFTWARE PREVIEW: PASS ({name}; {output / name}.png; not native proof)')


if __name__ == '__main__': capture()

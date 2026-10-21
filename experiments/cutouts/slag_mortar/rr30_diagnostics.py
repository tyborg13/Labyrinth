"""Headless stretch evidence and worst face/neck/arm crops, explicitly CPU-only."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from rr22_case import PROJECT
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.stretch import report
from humanoid_cutout.gates import bindings
from rr30_cpu import CpuPose as CoveragePose
from maquette_motion.pixels import PROOF_DEFAULTS

MAXIMUM_STRETCH = .12  # Director, rr-30 requirement 3.
CROP_PADDING_PX = 4  # Proof only, shared source space in before/after.
COMPARISON_ZOOM = 2
COMPARISON_COLUMN_WIDTH = 500
COMPARISON_ROW_HEIGHT = 220
COMPARISON_LABEL_OFFSET = (5, 5)
COMPARISON_IMAGE_TOP = 24
COMPARISON_BACKGROUND = (35, 35, 35)


def comparison(before, after, output):
    """Pair identical frame windows; labels and layout are proof-only controls."""
    rows = read_json(before / 'crops.json')['crops']
    sheet = Image.new('RGB', (COMPARISON_COLUMN_WIDTH * 2,
                             COMPARISON_ROW_HEIGHT * len(rows)), COMPARISON_BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for index, row in enumerate(rows):
        top = index * COMPARISON_ROW_HEIGHT
        for column, (label, folder) in enumerate((('before', before), ('after', after))):
            left = column * COMPARISON_COLUMN_WIDTH
            draw.text((left + COMPARISON_LABEL_OFFSET[0], top + COMPARISON_LABEL_OFFSET[1]),
                      label + ' ' + row['file'], fill='white')
            with Image.open(folder / row['file']) as image:
                image = image.convert('RGBA').resize((image.width * COMPARISON_ZOOM,
                    image.height * COMPARISON_ZOOM), Image.Resampling.NEAREST)
                sheet.paste(image, (left, top + COMPARISON_IMAGE_TOP), image)
    sheet.save(output)


def run(case, output, baseline=False, selection=None, full_region=False):
    selections = read_json(selection)['crops'] if selection else []
    samples = read_json(case / 'proof/logs/samples_full.json')
    layouts = {v: read_json(case / ('layouts/' + v + '.json')) for v in ('front', 'rear')}
    data = read_json(case / 'compiled_motion.json')
    result = report(case, layouts, data, samples, samples['inputs'] if baseline else bindings(case), maximum_stretch=MAXIMUM_STRETCH)
    output.mkdir(parents=True, exist_ok=True)
    write_json(output / 'stretch_full.json', result)
    write_json(output / 'stretch.json', dict(result, pieces={n:{k:v for k,v in r.items() if k != 'frames'} for n,r in result['pieces'].items()}))
    crops = []
    for view, layout in layouts.items():
        model = CoveragePose(case, layout)
        rows = [r for r in samples['samples'] if r['view'] == view and r['kind'] == 'presented']
        regions = {'face_neck': ['head', 'torso'], 'arm_near': ['upper_near','fore_near','bracer_near','hand_near'], 'arm_far': ['upper_far','fore_far','bracer_far','hand_far']}
        for region, names in regions.items():
            reference = next((r for r in selections if r['view']==view and r['region']==region), None)
            if reference:
                frame = reference
            elif region.startswith('arm'):
                measured = max((result['pieces'][view + '/' + name] for name in names if view + '/' + name in result['pieces']), key=lambda r:r['maximum_stretch'], default=None)
                if not measured: continue
                frame = measured['worst']
            else:
                # Face/neck severity: maximum relative head/torso angle.
                def turn(row):
                    a,b=[row['bones'][n]['global'] for n in ('head','torso')]
                    return abs(np.arctan2(a[1],a[0])-np.arctan2(b[1],b[0]))
                frame = max(rows, key=turn)
            pose = next(r for r in rows if r['clip'] == frame['clip'] and r['frame'] == frame['frame'])
            layers, _ = model.layers(pose)
            composite = Image.new('RGBA',(512,512))
            region_mask = np.zeros((512,512), dtype=bool)
            for part, image, _ in sorted(layers, key=lambda r:r[0]['z_index']):
                composite.alpha_composite(Image.fromarray(image))
                if part['logical_part'] in names: region_mask |= image[...,3] > 0
            if region == 'face_neck':
                # Head bounds plus the neck seam, rather than the entire torso.
                region_mask = next(image[...,3]>0 for part,image,_ in layers if part['name']=='head')
            y,x=np.nonzero(region_mask)
            box=[max(0,int(x.min())-CROP_PADDING_PX),max(0,int(y.min())-CROP_PADDING_PX),min(512,int(x.max())+CROP_PADDING_PX+1),min(512,int(y.max())+CROP_PADDING_PX+1)]
            if reference and not full_region: box = reference['crop']
            file = f'{view}_{region}_{pose["clip"]}_{pose["frame"]:04d}.png'
            composite.crop(box).save(output / file)
            crops.append(dict(view=view, region=region, clip=pose['clip'],frame=pose['frame'],phase=pose['phase'],crop=box,file=file,native_pixels=False))
    write_json(output/'crops.json',dict(basis='CPU diagnostic from actual presented transforms; no native renderer claim',crops=crops))
    print('RR30 STRETCH: %s (%d errors; %d pieces)' % ('PASS' if result['ok'] else 'FAIL',len(result['errors']),len(result['pieces'])))
    for error in result['errors']: print(error)
    print('RR30 CPU CROPS: %d (%s)'%(len(crops),output))
    return result


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--case',type=Path,required=True); p.add_argument('--output',type=Path,required=True); p.add_argument('--baseline',action='store_true'); p.add_argument('--selection',type=Path)
    p.add_argument('--comparison-baseline', type=Path)
    p.add_argument('--full-region', action='store_true', help='Keep reference frames but include the entire current rigid limb')
    a=p.parse_args()
    result = run(a.case,a.output,a.baseline,a.selection,a.full_region)
    if a.comparison_baseline:
        comparison(a.comparison_baseline, a.output, a.output.parent / 'before_after.png')
    raise SystemExit(not result['ok'])

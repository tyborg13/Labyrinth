"""Director collar/hem sheets from fresh, bound native captures only."""
import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from rr24_build import CASE, RECIPE, read_json, write_json, digest
from tools.humanoid_cutout.gates import bindings
from tools.humanoid_cutout.cpu_pose import sprite_transform
from maquette_motion.pixels import PROOF_DEFAULTS

SHEET_SIZE = (1920, 1080)
SHEET_COLUMNS = 6
SHEET_ROWS = 3
CELL_SIZE = (320, 360)
CROP_MARGIN_PX = 4
CROP_ZOOM = 2
LABEL_HEIGHT_PX = 20
BACKGROUND = '#1E1E24'  # Existing cutout proof-sheet background.
CLIPS = {'move': 'move', 'arc_jab': 'jab', 'death': 'death'}


def frame_root(pose):
    # Integer crop translation preserves native texels without resampling.
    return np.rint(pose['bones']['root']['global'][4:]).astype(int) + PROOF_DEFAULTS['source_offset']


def collar_box(layout, contours, pose):
    boxes = []
    for contour,name in [('jaw','head'),('collar','torso')]:
        part = next(p for p in layout['parts'] if p['name']==name)
        local = np.asarray(contours[contour]) - part['offset']
        matrix = sprite_transform(layout,pose,part)
        xy = local @ matrix[:2,:2].T + matrix[:2,2] + PROOF_DEFAULTS['source_offset']
        boxes.append([*xy.min(axis=0),*xy.max(axis=0)])
    return [min(b[0] for b in boxes),min(b[1] for b in boxes),
            max(b[2] for b in boxes),max(b[3] for b in boxes)]


def crop_plan(boxes, roots):
    relative = [np.asarray(box)-np.tile(root,2) for box,root in zip(boxes,roots)]
    bounds = [math.floor(min(b[0] for b in relative))-CROP_MARGIN_PX,
              math.floor(min(b[1] for b in relative))-CROP_MARGIN_PX,
              math.ceil(max(b[2] for b in relative))+CROP_MARGIN_PX,
              math.ceil(max(b[3] for b in relative))+CROP_MARGIN_PX]
    size = ((bounds[2]-bounds[0])*CROP_ZOOM,(bounds[3]-bounds[1])*CROP_ZOOM)
    if size[0]>CELL_SIZE[0] or size[1]>CELL_SIZE[1]-LABEL_HEIGHT_PX:
        raise ValueError('Root-relative crop exceeds the fixed proof cell')
    crops = [(np.asarray(bounds)+np.tile(root,2)).tolist() for root in roots]
    return bounds,size,crops


def compose(capture, output):
    manifest = read_json(capture / 'frames.json')
    bound = bindings(CASE)
    if not manifest['native_pixels'] or not manifest['ok'] or manifest['inputs'] != bound:
        raise ValueError('Fresh, complete native capture with current inputs required')
    samples = read_json(CASE / 'proof/samples.json')
    if samples['inputs'] != bound: raise ValueError('Stale pose samples')
    poses = {(p['view'],p['clip'],p['frame']):p for p in samples['samples'] if p['kind']=='presented'}
    output.mkdir(parents=True, exist_ok=True)
    outputs = []
    for view in ('front','rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        contours = read_json(RECIPE / 'ownership.json')[view]
        for label, clip in CLIPS.items():
            frames = sorted([r for r in manifest['frames'] if r['view']==view and r['clip']==clip],
                            key=lambda r:r['frame'])
            expected = round(read_json(CASE/'compiled_motion.json')['clips'][clip]['seconds'] * 60)
            if len(frames) != expected: raise ValueError('Missing native frames: '+view+'/'+clip)
            roots = [frame_root(poses[view,clip,row['frame']]) for row in frames]
            for region in ('collar','hem'):
                if region == 'collar':
                    boxes = [collar_box(layout,contours,poses[view,clip,row['frame']]) for row in frames]
                else:
                    rows = {r['frame']:r for r in manifest['pieces'] if r['view']==view and r['clip']==clip and r['name']=='loincloth'}
                    if len(rows) != expected: raise ValueError('Missing isolated native skirt frames')
                    boxes = [Image.open(capture/rows[r['frame']]['file']).getbbox() for r in frames]
                bounds,size,crops = crop_plan(boxes,roots)
                count = SHEET_COLUMNS*SHEET_ROWS
                for start in range(0,len(frames),count):
                    sheet = Image.new('RGB',SHEET_SIZE,BACKGROUND); draw = ImageDraw.Draw(sheet)
                    for i,row in enumerate(frames[start:start+count]):
                        image = Image.open(capture/row['file']).convert('RGBA').crop(crops[start+i]).resize(size,Image.Resampling.NEAREST)
                        x=(i%SHEET_COLUMNS)*CELL_SIZE[0]; y=(i//SHEET_COLUMNS)*CELL_SIZE[1]
                        sheet.paste(image,(x,y),image)
                        draw.text((x,y+CELL_SIZE[1]-LABEL_HEIGHT_PX),f'{view} {label} {region} {row["frame"]:04d}',fill='white')
                    path=output/f'{view}_{label}_{region}_{start//count:02d}.png';sheet.save(path)
                    outputs.append({'file':path.name,'sha256':digest(path),'crop_bounds':bounds,
                                    'crop_space':'frame_root','view':view,'clip':clip,'region':region,'first_frame':start,
                                    'frame_crops':[{'frame':r['frame'],'root_px':roots[j].tolist(),'bounds':crops[j]}
                                                   for j,r in enumerate(frames[start:start+count],start)]})
    from tools.visual_probe_runner import validate_pngs
    validate_pngs(sorted(output.glob('*.png')),44,{SHEET_SIZE},read_json(RECIPE/'crop_contract.json'))
    write_json(output/'manifest.json',{'ok':True,'native_pixels':True,'inputs':bound,
        'native_manifest_sha256':digest(capture/'frames.json'),'size':list(SHEET_SIZE),'sheets':outputs})
    print(f'RR24 COLLAR/HEM CROP SHEETS: PASS ({len(outputs)} sheets; 1920x1080; all move/arc_jab/death frames, both views)')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,default=CASE/'proof/native')
    parser.add_argument('--output',type=Path,default=CASE/'proof/rr24_crops')
    args=parser.parse_args();compose(args.capture,args.output)

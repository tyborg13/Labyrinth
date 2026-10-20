"""Native-before / CPU-after diagnostic crops. Never renderer acceptance."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

from rr28_build import paths, RIGS
from rr28_check import model_for
from cutout_pipeline.cases import read_json, digest, write_json
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import bindings
from maquette_motion.pixels import PROOF_DEFAULTS
from humanoid_cutout.native_frames import load_frame

CROP_MARGIN_PX = 14
CROP_ZOOM = 4
SHEET_COLUMNS = 4
LABEL_HEIGHT_PX = 32
TILE_GAP_PX = 8
PROOF_BACKGROUND_RGB = (38, 38, 38)


def compose(name, capture, output):
    case, _, recipe = paths(name)
    baseline = read_json(recipe / 'native_baseline.json')
    if digest(capture / 'frames.json') != baseline['manifest_sha256']:
        raise ValueError('Expected the director native baseline, not another capture')
    frames = {(r['view'], r['clip'], r['frame']): r for r in read_json(capture / 'frames.json')['frames']}
    samples = read_report(case)
    if not samples['ok'] or samples['errors'] or samples['inputs'] != bindings(case):
        raise ValueError('Refresh headless samples before composing CPU estimates')
    poses = {(r['view'], r['clip'], r['frame']): r for r in samples['samples'] if r['kind'] == 'presented'}
    definitions = read_json(recipe / 'joint_continuations.json')
    models = {v: model_for(name, case, read_json(case / f'layouts/{v}.json')) for v in definitions}
    evidence = {}
    for pieces in definitions.values():
        for definition in pieces.values():
            for row in definition['source_evidence']:
                if not row.get('reason'):
                    evidence[row['view'], row['clip'], row['frame'], tuple(row['bbox'])] = row
    side = CROP_MARGIN_PX * 2 * CROP_ZOOM
    tile_width, tile_height = side * 2 + TILE_GAP_PX, side + LABEL_HEIGHT_PX
    sheet = Image.new('RGB', (SHEET_COLUMNS * tile_width,
        ((len(evidence) + SHEET_COLUMNS - 1) // SHEET_COLUMNS) * tile_height), PROOF_BACKGROUND_RGB)
    draw, cache = ImageDraw.Draw(sheet), {}
    for index, (key, row) in enumerate(evidence.items()):
        pose_key = key[:3]
        if pose_key not in cache:
            layers, _ = models[key[0]].layers(poses[pose_key])
            image = Image.new('RGBA', (PROOF_DEFAULTS['canvas_size'],) * 2)
            for _, paint, _ in sorted(layers, key=lambda r: r[0]['z_index']):
                image.alpha_composite(Image.fromarray(paint))
            cache[pose_key] = image
        box = row['bbox']
        x, y = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
        crop = (x - CROP_MARGIN_PX, y - CROP_MARGIN_PX, x + CROP_MARGIN_PX, y + CROP_MARGIN_PX)
        before = load_frame(capture / frames[pose_key]['file']).convert('RGBA')
        left, top = index % SHEET_COLUMNS * tile_width, index // SHEET_COLUMNS * tile_height
        draw.text((left, top), f'{name} {key[0]} {key[1]} {key[2]} {box}', fill='white')
        draw.text((left, top + LABEL_HEIGHT_PX // 2), 'Native baseline | CPU estimate', fill='white')
        for image, offset in ((before, 0), (cache[pose_key], side + TILE_GAP_PX)):
            tile = image.crop(crop).resize((side, side), Image.Resampling.NEAREST)
            sheet.paste(tile, (left + offset, top + LABEL_HEIGHT_PX), tile)
    output.mkdir(parents=True, exist_ok=True)
    sheet.save(output / 'joint_crops.png')
    write_json(output / 'joint_crops.json', {'native_acceptance': False,
        'scope': 'Director native baseline beside current CPU estimate', 'pockets': len(evidence),
        'baseline_manifest_sha256': baseline['manifest_sha256'], 'sheet_sha256': digest(output / 'joint_crops.png')})
    print(f'RR28 {name.upper()} DIAGNOSTIC CROPS: PASS ({len(evidence)} pockets; CPU after, not native acceptance)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rig', choices=RIGS, required=True)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    compose(args.rig, args.capture, args.output)

"""rr-54 one-off CPU contact sheets; never native renderer proof or a runtime guard.

Use the production paint and every 60 Hz presented runtime pose. Source-case
masks/meshes supply the existing registration only. Red boxes mark visible
ordering violations, not mere overlap. The director judges the native cel look.
"""
import argparse
from functools import partial
from pathlib import Path
import sys

from rr37_case import CASE, ASSETS, PROJECT
sys.path[:0] = [str(PROJECT / 'tools')]
import numpy as np
from PIL import Image, ImageDraw
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import matrix
from maquette_motion import pixels
from rr37_raster import CpuPose
from rr54_layers import apply_layers
from sweep_parallel import map_shards

PROOF_DEFAULTS = {
    'nearest_scale': 2,
    'columns': 6,
    'caption_height_px': 24,
    'crop_padding_px': 8,
    'background_rgb': (30, 30, 36),
    'fault_rgb': (255, 64, 64),
    'box_width_px': 2,
    'box_padding_px': 2,
    'caption_inset_px': 4,
    'caption_rgb': (255, 255, 255),
}


def production_layout(view, baseline):
    layout = read_json(CASE / f'layouts/{view}.json')
    production = read_json(baseline / f'{view}.json')
    for field in ('parts', 'joint_meshes', 'gait_continuations', 'clip_continuations'):
        if field in production: layout[field] = production[field]
    for part in layout['parts']:
        part['file'] = str(ASSETS / 'humanoid_v2' / part['file'])
    return layout


def compose(layers):
    canvas = Image.new('RGBA', (layers[0][1].shape[1], layers[0][1].shape[0]))
    owners = np.full(layers[0][1].shape[:2], '', dtype=object)
    for part, image, _ in sorted(layers, key=lambda row: row[0]['z_index']):
        canvas.alpha_composite(Image.fromarray(image))
        owners[image[..., 3] > 0] = part['name']
    return canvas, owners


def findings(layout, pose, layers, owners):
    """Apply the brief's front/rear precedence to actual opaque shaft pixels.

    Near forearm and spear retain their source depth throughout this projected
    cutout's clips; no clip authors a depth crossing. A stable near-arm layer
    therefore covers their overlaps without any order transition.
    """
    item_names = [p['name'] for p, _, _ in layers if p['logical_part'] == 'spear']
    shaft = np.zeros(owners.shape, bool)
    crystal = next(f for f in layout['features'] if f['name'] == 'crystal_spearhead')
    source = np.asarray(Image.open(CASE / crystal['mask'])) > 0
    mask = np.zeros((*source.shape, 4), np.uint8)
    mask[source] = 255
    main = next(p for p in layout['parts'] if p['name'] == 'spear')
    transform = matrix(pose['parts']['spear']['transform'])
    transform[:2, 2] -= transform[:2, :2] @ np.asarray(main['offset'])
    tip = pixels.render(mask, transform)[..., 3] > 0
    for part, image, _ in layers:
        if part['name'] in item_names: shaft |= image[..., 3] > 0
    shaft &= ~tip
    visible = np.isin(owners, item_names)
    records = []
    for part, image, _ in layers:
        logical = part['logical_part']
        if logical == 'spear': continue
        overlap = shaft & (image[..., 3] > 0)
        if layout['facing'] == 'rear':
            bad, rule = overlap & visible, 'shaft over body silhouette'
        elif logical in ('hand_far', 'hand_near', 'arm_near') and not part.get('hidden_material'):
            bad, rule = overlap & visible, 'shaft over fingers/near forearm'
        elif logical in ('torso', 'pelvis', 'tabard', 'cape_near', 'cape_far'):
            bad, rule = overlap & (owners == part['name']), 'shaft hidden behind front body/cloak'
        else:
            continue
        if bad.any():
            y, x = np.nonzero(bad)
            records.append({'piece': part['name'], 'rule': rule, 'pixels': int(bad.sum()),
                'bbox': [int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1]})
    return records


def shard(poses, output, candidate, baseline):
    results = []
    with for_case(CASE):
        models = {}
        for view in ('front', 'rear'):
            layout = production_layout(view, baseline)
            if candidate: apply_layers(layout)
            models[view] = CpuPose(CASE, layout)
        for pose in poses:
            model = models[pose['view']]
            layers, _ = model.layers(pose)
            canvas, owners = compose(layers)
            bad = findings(model.layout, pose, layers, owners)
            path = output / pose['view'] / pose['clip'] / ('%04d.png' % pose['frame'])
            path.parent.mkdir(parents=True, exist_ok=True)
            canvas.save(path)
            results.append({k: pose[k] for k in ('view', 'clip', 'frame', 'phase')} |
                {'faults': bad, 'bbox': canvas.getbbox(), 'file': str(path)})
    return results


def sheets(output, stage, rows, selection=None, crop=None):
    if crop is None:
        boxes = [r['bbox'] for r in rows if r['bbox']]
        pad = PROOF_DEFAULTS['crop_padding_px']
        canvas_size = read_json(CASE / 'cutout.json')['proof_geometry']['canvas_size']
        crop = [max(0, min(b[0] for b in boxes) - pad), max(0, min(b[1] for b in boxes) - pad),
            min(canvas_size, max(b[2] for b in boxes) + pad), min(canvas_size, max(b[3] for b in boxes) + pad)]
    if selection is None:
        selection = {}
        for view in ('front', 'rear'):
            selection[view] = []
            for clip in read_json(CASE / 'compiled_motion.json')['clips']:
                group = [r for r in rows if r['view'] == view and r['clip'] == clip]
                # Six evenly spread frames, with one slot replaced by the
                # greatest visible fault. Same exact frames in the after sheet.
                indices = np.linspace(0, len(group) - 1, PROOF_DEFAULTS['columns']).round().astype(int).tolist()
                worst = max(range(len(group)), key=lambda i: sum(f['pixels'] for f in group[i]['faults']))
                if group[worst]['faults'] and worst not in indices: indices[len(indices) // 2] = worst
                selection[view].extend((clip, group[i]['frame']) for i in sorted(indices))
    scale, columns = PROOF_DEFAULTS['nearest_scale'], PROOF_DEFAULTS['columns']
    width, height = (crop[2] - crop[0]) * scale, (crop[3] - crop[1]) * scale
    caption = PROOF_DEFAULTS['caption_height_px']
    for view in ('front', 'rear'):
        chosen = selection[view]
        sheet = Image.new('RGB', (columns * width, (len(chosen) // columns) * (height + caption)), PROOF_DEFAULTS['background_rgb'])
        draw = ImageDraw.Draw(sheet)
        for index, (clip, frame) in enumerate(chosen):
            row = next(r for r in rows if (r['view'], r['clip'], r['frame']) == (view, clip, frame))
            im = Image.open(row['file']).convert('RGBA').crop(crop).resize((width, height), Image.Resampling.NEAREST)
            left, top = (index % columns) * width, (index // columns) * (height + caption)
            sheet.paste(im, (left, top), im)
            for fault in row['faults']:
                x0, y0, x1, y1 = fault['bbox']
                padding = PROOF_DEFAULTS['box_padding_px']
                draw.rectangle((left + (x0 - crop[0]) * scale - padding, top + (y0 - crop[1]) * scale - padding,
                    left + (x1 - crop[0]) * scale + padding, top + (y1 - crop[1]) * scale + padding),
                    outline=PROOF_DEFAULTS['fault_rgb'], width=PROOF_DEFAULTS['box_width_px'])
            inset = PROOF_DEFAULTS['caption_inset_px']
            draw.text((left + inset, top + height + inset), f'{view}/{clip}/{frame:03d}  faults={len(row["faults"])}', fill=PROOF_DEFAULTS['caption_rgb'])
        sheet.save(output / f'{stage}_{view}.png')
    return selection, crop


def run(args):
    data = read_json(args.samples)
    poses = [p for p in data['samples'] if p['kind'] == 'presented']
    clips = read_json(CASE / 'compiled_motion.json')['clips']
    expected = {(v, c, f) for v in ('front', 'rear') for c, d in clips.items() for f in range(round(d['seconds'] * 60))}
    actual = [(p['view'], p['clip'], p['frame']) for p in poses]
    if len(actual) != len(set(actual)) or set(actual) != expected: raise ValueError('Incomplete/duplicate presented inventory')
    args.output.mkdir(parents=True, exist_ok=True)
    baseline = args.output / 'baseline'
    baseline.mkdir(exist_ok=True)
    for view in ('front', 'rear'):
        path = baseline / f'{view}.json'
        if not path.exists(): path.write_bytes((ASSETS / f'humanoid_v2/{view}.json').read_bytes())
    selection = crop = None
    if args.fixed_only:
        before = read_json(args.output / 'faults.json')
        selection, crop = before['sheet_selection'], before['sheet_crop']
    stages = (('fixed', True),) if args.fixed_only else (('faults', False), ('fixed', True))
    for stage, candidate in stages:
        groups = map_shards(partial(shard, output=args.output / stage, candidate=candidate, baseline=baseline), poses)
        rows = sorted([r for group in groups for r in group], key=lambda r: (r['view'], list(clips).index(r['clip']), r['frame']))
        selection, crop = sheets(args.output, stage, rows, selection, crop)
        report = {'native_pixels': False, 'samples_sha256': digest(args.samples), 'frames': rows,
            'fault_count': sum(len(r['faults']) for r in rows), 'proof_defaults': PROOF_DEFAULTS,
            'sheet_crop': crop, 'sheet_selection': selection,
            'inputs': {v: digest(baseline / f'{v}.json') for v in ('front', 'rear')}}
        write_json(args.output / f'{stage}.json', report)
        lines = ['# rr-54 ' + stage + ' — CPU raster, zero-based 60 Hz frames', '', '| View | Clip | Frame | Crossed piece | Rule | Pixels |', '|---|---|---:|---|---|---:|']
        for row in rows:
            for fault in row['faults']:
                lines.append('| {view} | {clip} | {frame} | '.format(**row) + '{piece} | {rule} | {pixels} |'.format(**fault))
        if not report['fault_count']: lines.append('\nNo shaft ordering violations in any clip/view.')
        (args.output / f'{stage}.md').write_text('\n'.join(lines) + '\n')
        print(f'RR54 {stage.upper()}: {len(rows)} frames; {report["fault_count"]} frame/piece faults; native=False', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--fixed-only', action='store_true')
    run(parser.parse_args())

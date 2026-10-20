"""Compose 3x Tether studies from native captures or labelled CPU estimates.

The same source crop is used in every panel and every raise frame. Native
composition refuses stale/missing images; CPU output cannot masquerade as GPU.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from rr27_build import CASE, RECIPE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from humanoid_cutout.gates import bindings

ZOOM = 3
SHEET_COLUMNS = 3
CELL_SIZE = (840, 960)
LABEL_HEIGHT_PX = 120
LABEL_FONT_SIZE_PX = 18
CROP_MARGIN_PX = 4
BACKGROUND = '#1E1E24'
PHASES = [0.0, 0.1, 0.2, 0.3, 0.35, 0.5]
CANDIDATES = {'current': [206, 63], 'A': [65, 153], 'B': [47, 121], 'C': [59, 46], 'D': [19, 101]}
SOURCE_ORIGIN = np.array([128, 128])
# Dense centreline test omits endpoint contact, which is the shoulder socket.
AXIS_INTERIOR_FRACTIONS = np.linspace(.1, .9, 81)


def transformed_point(layout, pose, part, point):
    matrix = sprite_transform(layout, pose, part)
    return (np.asarray(point) - part['offset']) @ matrix[:2, :2].T + matrix[:2, 2] + SOURCE_ORIGIN


def axis_crosses(mask, start, end):
    points = start + AXIS_INTERIOR_FRACTIONS[:, None] * (end - start)
    pixels = np.floor(points).astype(int)
    valid = (pixels[:, 0] >= 0) & (pixels[:, 1] >= 0) & (pixels[:, 0] < mask.shape[1]) & (pixels[:, 1] < mask.shape[0])
    return bool(mask[pixels[valid, 1], pixels[valid, 0]].any())


def compose(capture, *, cpu=False):
    report = read_json(capture / 'samples.json')
    if (not report['ok'] or report['native_pixels'] == cpu or report['inputs'] != bindings(CASE)
            or report['candidates'] != CANDIDATES or report['phases'] != PHASES):
        raise ValueError('Fresh, complete study evidence with the requested candidates required')
    poses = report['samples']
    if [(p['candidate'], p['phase']) for p in poses] != [(c, phase) for c in CANDIDATES for phase in PHASES]:
        raise ValueError('Study must contain all five candidates and all six requested phases')
    output = capture if cpu else RECIPE / 'tether_study'
    layout = read_json(CASE / 'layouts/rear.json')
    model = CpuPose(CASE, layout)
    parts = {p['name']: p for p in layout['parts']}
    frames, records = {}, []
    for pose in poses:
        key = pose['candidate'], pose['frame']
        if cpu:
            layers, _ = model.layers(pose)
            image = Image.new('RGBA', (512, 512))
            for _, paint, _ in sorted(layers, key=lambda r: r[0]['z_index']):
                image.alpha_composite(Image.fromarray(paint))
            isolated = {p['name']: paint[..., 3] > 0 for p, paint, _ in layers}
        else:
            names = [('file', 'sha256')] + [(n + '_file', n + '_sha256') for n in ('torso', 'upper_near', 'tube')]
            for field, sha in names:
                path = (capture / pose[field]).resolve()
                if not path.is_relative_to(capture.resolve()) or not path.is_file() or digest(path) != pose[sha]:
                    raise ValueError('Study capture changed: ' + str(path))
            image = Image.open(capture / pose['file']).convert('RGBA')
            isolated = {n: np.asarray(Image.open(capture / pose[n + '_file']).convert('RGBA'))[..., 3] > 0
                        for n in ('torso', 'upper_near', 'tube')}
        frames[key] = image
        tip = transformed_point(layout, pose, parts['tube'], layout['joints']['tube_tip']['position'])
        elbow = np.asarray(pose['bones']['fore_near']['global'][4:]) + SOURCE_ORIGIN
        shoulder = np.asarray(pose['bones']['upper_near']['global'][4:]) + SOURCE_ORIGIN
        records.append({'candidate': pose['candidate'], 'frame': pose['frame'], 'phase': pose['phase'],
            'cap_presented_pixel': np.floor(tip).astype(int).tolist(),
            'cap_presented_position': tip.tolist(), 'elbow_position': elbow.tolist(),
            'upper_arm_crosses_torso': axis_crosses(isolated['torso'], shoulder, elbow),
            'tube_crosses_torso': axis_crosses(isolated['torso'], elbow, tip),
            'upper_arm_torso_overlap_px': int((isolated['upper_near'] & isolated['torso']).sum()),
            'tube_torso_overlap_px': int((isolated['tube'] & isolated['torso']).sum())})
    boxes = [im.getbbox() for im in frames.values()]
    crop = [min(b[0] for b in boxes) - CROP_MARGIN_PX, min(b[1] for b in boxes) - CROP_MARGIN_PX,
            max(b[2] for b in boxes) + CROP_MARGIN_PX, max(b[3] for b in boxes) + CROP_MARGIN_PX]
    size = ((crop[2] - crop[0]) * ZOOM, (crop[3] - crop[1]) * ZOOM)
    if size[0] > CELL_SIZE[0] or size[1] > CELL_SIZE[1] - LABEL_HEIGHT_PX:
        raise ValueError('Study exceeds the fixed full-figure proof cell')
    sheet = Image.new('RGB', (CELL_SIZE[0] * SHEET_COLUMNS, CELL_SIZE[1] * 2), BACKGROUND)
    scope = 'CPU ESTIMATE' if cpu else 'NATIVE'
    files = []

    def panel(target, key, x, y):
        image = frames[key].crop(crop).resize(size, Image.Resampling.NEAREST)
        target.paste(image, (x + (CELL_SIZE[0] - size[0]) // 2, y), image)
        record = next(r for r in records if (r['candidate'], r['frame']) == key)
        cap, elbow = record['cap_presented_pixel'], record['elbow_position']
        lines = [f'{key[0]}: {CANDIDATES[key[0]][0]} / {CANDIDATES[key[0]][1]} | phase {record["phase"]:g} | {scope} 3x',
                 f'cap pixel ({cap[0]}, {cap[1]}); elbow ({elbow[0]:.2f}, {elbow[1]:.2f})',
                 'torso axis crossing: upper arm %s; tube %s' %
                 ('YES' if record['upper_arm_crosses_torso'] else 'NO', 'YES' if record['tube_crosses_torso'] else 'NO'),
                 f'isolated alpha overlap: arm {record["upper_arm_torso_overlap_px"]} px; tube {record["tube_torso_overlap_px"]} px']
        draw = ImageDraw.Draw(target)
        for index, line in enumerate(lines):
            draw.text((x + 8, y + CELL_SIZE[1] - LABEL_HEIGHT_PX + 24 * index), line,
                      fill='white', font_size=LABEL_FONT_SIZE_PX)

    for index, candidate in enumerate(CANDIDATES):
        panel(sheet, (candidate, 5), (index % SHEET_COLUMNS) * CELL_SIZE[0], (index // SHEET_COLUMNS) * CELL_SIZE[1])
        strip = Image.new('RGB', (CELL_SIZE[0] * len(PHASES), CELL_SIZE[1]), BACKGROUND)
        for frame in range(len(PHASES)):
            panel(strip, (candidate, frame), frame * CELL_SIZE[0], 0)
        path = output / f'{candidate}_raise_3x.png'
        strip.save(path)
        files.append({'file': path.name, 'sha256': digest(path)})
    path = output / 'hold_contact_sheet_3x.png'
    sheet.save(path)
    files.append({'file': path.name, 'sha256': digest(path)})
    write_json(output / 'manifest.json', {'ok': True, 'native_pixels': not cpu, 'scope': scope,
        'inputs': report['inputs'], 'samples_sha256': digest(capture / 'samples.json'),
        'coordinate_space': '512px source canvas; origin (128,128); cap pixel=floor(transported rest tube_tip landmark)',
        'crossing_measurement': 'Open centreline interior (10%-90%) intersects isolated torso alpha; alpha-overlap counts include attachment contact',
        'crop_bounds': crop, 'zoom': ZOOM, 'rows': records, 'files': files})
    print(f'RR27 TETHER {scope} SHEETS: PASS (1 hold sheet; 5 six-frame strips; 3x nearest; {output})')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cpu', action='store_true')
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    compose(args.capture or RECIPE / 'tether_study' / ('cpu' if args.cpu else 'native'), cpu=args.cpu)

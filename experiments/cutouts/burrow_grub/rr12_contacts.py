"""Every captured native frame, both views, at exact 3x nearest neighbour.

One fixed union crop per clip keeps all motion, including hidden/death holds.
This is diagnostic composition of approved captured pixels, never new paint.
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw
from rr12_inputs import read_json, write_json, digest

PROOF_DEFAULTS = {'columns': 6, 'label_height_px': 24, 'crop_margin_px': 3}
ZOOM = 3  # rr-12 required proof scale.
BACKGROUND = '#1E1E24'  # Director's review background.


def compose(capture, output):
    manifest = read_json(capture / 'frames.json')
    if not manifest.get('ok') or not manifest.get('native_pixels'):
        raise ValueError('Contact sheets require successful native captures')
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    clips = list(dict.fromkeys(r['clip'] for r in manifest['frames']))
    for clip in clips:
        rows = [r for r in manifest['frames'] if r['clip'] == clip]
        bounds = []
        for row in rows:
            path = capture / row['file']
            if digest(path) != row['sha256']:
                raise ValueError('Changed captured frame: ' + str(path))
            box = Image.open(path).convert('RGBA').getbbox()
            if box:
                bounds.append(box)
        if not bounds:
            raise ValueError('No painted pixels in clip ' + clip)
        margin = PROOF_DEFAULTS['crop_margin_px']
        size = Image.open(capture / rows[0]['file']).size
        box = (max(0, min(b[0] for b in bounds) - margin),
               max(0, min(b[1] for b in bounds) - margin),
               min(size[0], max(b[2] for b in bounds) + margin),
               min(size[1], max(b[3] for b in bounds) + margin))
        count = max(r['frame'] for r in rows) + 1
        cell = ((box[2] - box[0]) * ZOOM * 2,
                (box[3] - box[1]) * ZOOM + PROOF_DEFAULTS['label_height_px'])
        columns = PROOF_DEFAULTS['columns']
        sheet = Image.new('RGB', (cell[0] * columns, cell[1] * ((count + columns - 1) // columns)), BACKGROUND)
        draw = ImageDraw.Draw(sheet)
        lookup = {(r['view'], r['frame']): r for r in rows}
        for frame in range(count):
            x, y = frame % columns * cell[0], frame // columns * cell[1]
            draw.text((x, y), f'{clip} {frame:04d} | front / rear', fill='white')
            for side, view in enumerate(('front', 'rear')):
                row = lookup[(view, frame)]
                image = Image.open(capture / row['file']).convert('RGBA').crop(box)
                image = image.resize((image.width * ZOOM, image.height * ZOOM), Image.Resampling.NEAREST)
                sheet.paste(image, (x + side * image.width, y + PROOF_DEFAULTS['label_height_px']), image)
        target = output / (clip + '_all_frames_3x.png')
        sheet.save(target)
        reports.append({'clip': clip, 'frames_per_view': count, 'crop': list(box),
                        'file': target.name, 'sha256': digest(target)})
    write_json(output / 'contact_sheets.json', {'ok': True, 'native_manifest_sha256': digest(capture / 'frames.json'),
        'zoom': ZOOM, 'filter': 'nearest', 'view_order': ['front', 'rear'], 'clips': reports,
        'proof_defaults': PROOF_DEFAULTS})
    print('RR12 CONTACT SHEETS: PASS (%d clips; every native frame at 3x)' % len(reports))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    compose(args.capture, args.output)

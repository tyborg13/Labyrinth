"""Assemble the director's sixteen approved-rig native 512 viewport captures."""
import argparse
from pathlib import Path

from PIL import Image

from cutout_pipeline.cases import read_json


def compose(directory):
    manifest = read_json(directory / 'frames.json')
    if not manifest['ok'] or not manifest['native_pixels'] or manifest['canvas_size'] != [512, 512]:
        raise ValueError('Fresh native 512 viewport captures required')
    if manifest['size'] != [1920, 1080] or manifest['ui_scale'] != 1.0:
        raise ValueError('1920x1080 / 100% UI scale required')
    sheet = Image.new('RGBA', (512 * 8, 512 * 2))
    for view_index, view in enumerate(('front', 'rear')):
        rows = [row for row in manifest['frames'] if row['view'] == view]
        if {row['frame'] for row in rows} != set(range(8)) or len(rows) != 8:
            raise ValueError('Eight frames per view required')
        for row in rows:
            image = Image.open(directory / row['file']).convert('RGBA')
            if image.size != (512, 512):
                raise ValueError('Expected native 512 viewport')
            sheet.paste(image, (512 * row['frame'], 512 * view_index))
    path = directory / 'walk_contact_sheet.png'
    sheet.save(path)
    print('WALK-01 CONTACT SHEET: PASS (' + str(path) + ')')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    compose(parser.parse_args().capture)

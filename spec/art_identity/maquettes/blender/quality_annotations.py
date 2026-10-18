"""Compose diagnostic boxes over existing native clays; never retouch them."""
import json
from pathlib import Path
import sys

from PIL import Image, ImageDraw


def main(capture, config):
    capture = Path(capture)
    settings = json.loads(Path(config).read_text())['quality_issue_overlay_defaults']
    size, header = settings['size'], settings['caption_height']
    canvas = Image.new('RGBA', (2 * size, size + header), tuple(settings['background']))
    draw = ImageDraw.Draw(canvas)
    for column, view in enumerate(('front', 'rear')):
        offset = column * size
        with Image.open(capture / (view + '_clay.png')) as source:
            if source.size != (size, size):
                raise ValueError('Diagnostic clay size differs from named proof settings')
            canvas.alpha_composite(source.convert('RGBA'), (offset, header))
        draw.text((offset + settings['caption_padding'], settings['caption_padding']),
                  settings['figure_id'] + ' / ' + view + ' / ' + settings['caption_suffix'],
                  fill=settings['caption_colour'])
        for x0, y0, x1, y1 in settings['rois_px'][view].values():
            draw.rectangle([x0 + offset, y0 + header, x1 + offset, y1 + header],
                           outline=tuple(settings['box_colour']), width=settings['box_width'])
    canvas.save(capture / 'quality_issue_overlay.png')
    print('QUALITY_ANNOTATIONS: PASS; size=' + str(canvas.width) + 'x' + str(canvas.height))


if __name__ == '__main__':
    main(*sys.argv[1:])

"""Remove the generated rear artwork's magenta key and fit the source canvas.

ImageGen authors every painted pixel. Preparation uses a binary key and nearest
sampling, then records the exact transform; it never adjusts character colors.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image


def main():
    base = Path(__file__).resolve().parent / 'references'
    source = base / 'rear_keyed_source.png'
    image = Image.open(source).convert('RGBA')
    raw_size = image.size
    pixels, removed = [], 0
    for r, g, b, a in image.getdata():
        keyed = r > g + 20 and b > g + 20 and b > r * .5
        removed += int(keyed)
        pixels.append((0, 0, 0, 0) if keyed else (r, g, b, a))
    image.putdata(pixels)
    bounds = image.getchannel('A').getbbox()
    if not bounds:
        raise ValueError('Empty keyed source')
    scale = 214 / (bounds[3] - bounds[1])
    image = image.resize((round(image.width * scale), round(image.height * scale)),
                         Image.Resampling.NEAREST)
    bounds = image.getchannel('A').getbbox()
    translation = ((255 - image.width) // 2, 223 - bounds[3])
    placed = (bounds[0] + translation[0], bounds[1] + translation[1],
              bounds[2] + translation[0], bounds[3] + translation[1])
    if min(placed[:2]) < 0 or max(placed[2:]) > 255:
        raise ValueError(f'Artwork would clip the fixed source canvas: {placed}')
    result = Image.new('RGBA', (255, 255))
    result.paste(image, translation)
    if any(result.getchannel('A').histogram()[1:255]):
        raise ValueError('Expected binary source alpha')
    destination = base / 'rear.png'
    result.save(destination)
    manifest = {
        'source': source.name,
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'raw_size': list(raw_size), 'key_rule': 'r>g+20 and b>g+20 and b>r*0.5',
        'background_pixels_removed': removed, 'uniform_scale': scale,
        'resampler': 'nearest', 'translation': list(translation),
        'result_alpha_bounds': list(result.getchannel('A').getbbox()),
        'result_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
        'character_color_adjustment': False,
    }
    (base / 'rear_preparation.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared rear.png', result.getchannel('A').getbbox())


if __name__ == '__main__':
    main()

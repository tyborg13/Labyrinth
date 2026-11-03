"""One proof sheet, with native clays registered to a shared world scale."""
import json

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.raster import camera
from .recipe import FIGURE

SHEET_DEFAULTS = {'size': 1024, 'caption': 28, 'columns': 4, 'rows': 2,
                  'background': [24, 24, 24, 255], 'foreground': 'white', 'padding': 4,
                  'encoding': 'lossless WebP method 6', 'font': 'Pillow default'}


def same_scale(image, source, target):
    """Register camera scale/target only; never fit individual figure bounds."""
    _, old_target, old_basis, old_scale = camera(source)
    _, new_target, _, new_scale = camera(target)
    factor = old_scale/new_scale
    delta = np.array(new_target)-old_target
    size = SHEET_DEFAULTS['size']
    offset = size*(1-factor)/2 + size/new_scale*np.array([-delta@old_basis[0], delta@old_basis[1]])
    return image.transform((size, size), Image.Transform.AFFINE,
        (1/factor, 0, -offset[0]/factor, 0, 1/factor, -offset[1]/factor), Image.Resampling.BICUBIC)


def sheet(spec, capture, output):
    size, caption = SHEET_DEFAULTS['size'], SHEET_DEFAULTS['caption']
    result = Image.new('RGBA', (size*4, (size+caption)*2), tuple(SHEET_DEFAULTS['background']))
    draw = ImageDraw.Draw(result)
    inputs = {}
    cells = []
    for view in ('front', 'rear'):
        path = output/(view+'_fit_overlay.png')
        cells.append((Image.open(path).convert('RGBA').resize((size, size), Image.Resampling.NEAREST),
                      'mq4 '+view+' fit overlay / source pixels x4'))
        inputs[str(path.name)] = sha(path)
    for name in ('frostglass_lancer', 'gale_herald', 'gloam_stalker'):
        folder = FIGURE.parent/name
        native_spec = spec if name == 'frostglass_lancer' else compile_recipe(json.loads((folder/'measurements.json').read_text()))
        for view in ('front', 'rear'):
            path = (capture if name == 'frostglass_lancer' else folder/'delivery')/(view+'_clay.png')
            image = Image.open(path).convert('RGBA')
            if image.size != (size, size):
                raise ValueError('Comparison requires native 1024 captures')
            if name != 'frostglass_lancer':
                image = same_scale(image, native_spec, spec)
            cells.append((image, name+' / '+view+' / common world scale'))
            inputs[str(path)] = sha(path)
    for index, (image, label) in enumerate(cells):
        x, y = index%4*size, index//4*(size+caption)
        result.alpha_composite(image, (x, y+caption))
        draw.text((x+4, y+4), label, fill=SHEET_DEFAULTS['foreground'])
    result.save(output/'contact_sheet.webp', lossless=True, method=6)
    write(output/'review_inputs.json', {'inputs_sha256': inputs, 'camera': {'ortho_scale': spec['ortho_scale'], 'target': spec['target']},
        'registration': 'Every clay uses the same physical world-to-pixel scale and camera target; no figure-bounds scaling.', 'defaults': SHEET_DEFAULTS})

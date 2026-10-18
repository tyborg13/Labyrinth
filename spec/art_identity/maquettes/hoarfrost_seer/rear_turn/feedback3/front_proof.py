"""Reproduce the stopped front gate without invoking Blender."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.front_gate import compare
from spec.art_identity.maquettes.blender.curate_delivery import sha

PROOF_DEFAULTS = {'cell_px': 1024}


def main():
    folder = Path(__file__).resolve().parent
    figure = folder.parents[1]
    before, after = figure / 'delivery', folder / 'front10'
    contract = folder.parent / 'feedback2/gate_contract.json'
    if (folder / 'baseline_recipe.json').read_bytes() != (figure / 'measurements.json').read_bytes():
        raise ValueError('Original front input changed; restore the archived baseline before comparing')
    report = compare(before, after, json.loads(contract.read_text()))
    report['inputs'] = {'before_manifest_sha256': sha(before / 'capture_manifest.json'),
        'after_manifest_sha256': sha(after / 'capture_manifest.json'), 'contract_sha256': sha(contract)}
    old = np.array(Image.open(before / 'front_silhouette.png').convert('RGBA'))[..., 3]
    new = np.array(Image.open(after / 'front_silhouette.png').convert('RGBA'))[..., 3]
    y, x = np.nonzero(old != new)
    report['alpha_diff'] = {'added_pixels': int(((new > 0) & (old == 0)).sum()),
        'removed_pixels': int(((old > 0) & (new == 0)).sum()),
        'bbox_px': [int(x.min()), int(y.min()), int(x.max()), int(y.max())] if len(x) else None}
    (folder / 'front10_gate.json').write_text(json.dumps(report, indent=2) + '\n')
    paths = [before / 'front_clay.png', after / 'front_clay.png', after / 'front_parts.png']
    size = PROOF_DEFAULTS['cell_px']
    sheet = Image.new('RGBA', (size * len(paths), size))
    for index, path in enumerate(paths):
        with Image.open(path) as image:
            if image.size != (size, size):
                raise ValueError('Native 1024 proof cells are required')
            sheet.paste(image.convert('RGBA'), (index * size, 0))
    sheet.save(folder / 'front_sheet.png', optimize=True)
    print('MQ06_FRONT_GATE: ' + ('PASS' if report['passed'] else 'FAIL') +
          '; whole alpha changes=' + str(report['whole_figure_alpha_changed_pixels']) +
          '; robe union changes=' + str(report['pieces']['robe']['changed_pixels']))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

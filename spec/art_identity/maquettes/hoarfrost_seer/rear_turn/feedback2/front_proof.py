"""Reproduce the owner's front gate and native-size diagnostic comparison."""
import json
from pathlib import Path
import sys

from PIL import Image

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.front_gate import compare
from spec.art_identity.maquettes.blender.curate_delivery import sha

PROOF_DEFAULTS = {'cell_px': 1024}


def main():
    folder = Path(__file__).resolve().parent
    figure = folder.parents[1]
    before, after = figure / 'delivery', folder / 'native_front8'
    contract = folder / 'gate_contract.json'
    report = compare(before, after, json.loads(contract.read_text()))
    report['proof_inputs'] = {'before_manifest_sha256': sha(before / 'capture_manifest.json'),
        'after_manifest_sha256': sha(after / 'capture_manifest.json'),
        'gate_contract_sha256': sha(contract)}
    report['native_build_passed'] = json.loads((after / 'build_report.json').read_text())['passed']
    (folder / 'native_front8_gate.json').write_text(json.dumps(report, indent=2) + '\n')
    paths = [before / 'front_clay.png', after / 'front_clay.png', after / 'front_parts.png']
    size = PROOF_DEFAULTS['cell_px']
    sheet = Image.new('RGBA', (size * len(paths), size))
    for index, path in enumerate(paths):
        with Image.open(path) as image:
            if image.size != (size, size):
                raise ValueError('Proof sheet must preserve native 1024 pixels')
            sheet.paste(image.convert('RGBA'), (index * size, 0))
    sheet.save(folder / 'front_gate_sheet.png', optimize=True)
    print('FRONT_V2_GATE: ' + ('PASS' if report['passed'] else 'FAIL') +
          '; alpha=' + str(report['whole_figure_alpha_changed_pixels']) +
          ' px; joints=' + str(report['max_joint_displacement_px']) +
          ' px; native build=' + str(report['native_build_passed']))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

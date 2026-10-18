"""Audit every committed figure's fitted ankle/prop contacts, and native Seer hem."""
import json
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.floor_contact import spec_contacts


def main():
    output = Path(__file__).resolve().parent
    root = PROJECT / 'spec/art_identity/maquettes'
    reports = {}
    for folder in sorted(root.glob('*/delivery')):
        if not (folder / 'front_clay.png').is_file() or not (folder / 'rear_clay.png').is_file():
            continue
        recipe = folder.parent / 'measurements.json'
        if recipe.is_file():
            reports[folder.parent.name] = spec_contacts(compile_recipe(json.loads(recipe.read_text())))
    reports['frostglass_lancer'] = spec_contacts(json.loads((root / 'frostglass_lancer/spec_r3.json').read_text()))
    native = output / 'corrected/floor_correction.json'
    if not native.is_file():
        native = output / 'native_floor_correction.json'
    result = {'basis': 'committed fitted ankle joints and shaft path endpoints; native Seer hem reported separately',
              'figures': reports,
              'native_hem_coverage': {'hoarfrost_seer': 'measured in diagnostic build',
                                      'other_figures': 'not measured; no native builds changed'}}
    if native.is_file():
        result['seer_native_before_after'] = json.loads(native.read_text())
    (output / 'floor_guard_before.json').write_text(json.dumps(result, indent=2) + '\n')
    for name, report in reports.items():
        print('FLOOR_CONTACT_GUARD: ' + name + '; ' + ('PASS' if report['passed'] else 'FAIL') + '; ' +
              json.dumps({key: row['above_floor_m'] for key, row in report['points'].items() if not row['passed']}))


if __name__ == '__main__':
    main()

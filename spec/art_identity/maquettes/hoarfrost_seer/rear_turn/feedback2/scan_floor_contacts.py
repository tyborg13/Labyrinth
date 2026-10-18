"""All committed humanoids; documented exceptions never hide measured lifts."""
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
    exceptions = json.loads((output / 'floor_guard_exceptions.json').read_text())['figures']
    reports = {}
    for folder in sorted(root.glob('*/delivery')):
        if not all((folder / (view + '_clay.png')).is_file() for view in ('front', 'rear')):
            continue
        recipe = folder.parent / 'measurements.json'
        if recipe.is_file():
            spec = compile_recipe(json.loads(recipe.read_text()))
            reports[folder.parent.name] = spec_contacts(spec, exceptions.get(folder.parent.name, []))
    spec = json.loads((root / 'frostglass_lancer/spec_r3.json').read_text())
    reports['frostglass_lancer'] = spec_contacts(spec, exceptions['frostglass_lancer'])
    if not set(exceptions) <= set(reports) or exceptions['hoarfrost_seer']:
        raise ValueError('Missing figure coverage or a forbidden Seer exception')
    report = {'basis': 'fitted ankle joints and prop path endpoints; explicit per-figure exceptions',
              'figures': reports, 'exceptions': exceptions, 'passed': all(row['passed'] for row in reports.values())}
    native = root / 'hoarfrost_seer/delivery/build_report.json'
    if native.is_file():
        data = json.loads(native.read_text()).get('geometry_details', {}).get('floor_contact')
        if data:
            report['seer_native_floor_contact'] = data
            report['passed'] &= data['passed']
    candidate = output / 'native_front8/build_report.json'
    if candidate.is_file():
        data = json.loads(candidate.read_text())
        report['diagnostic_candidate'] = {'native_build_passed': data['passed'],
            'floor_contact': data['geometry_details']['floor_contact']}
    (output / 'floor_guard.json').write_text(json.dumps(report, indent=2) + '\n')
    for name, row in reports.items():
        print('FLOOR_CONTACT_GUARD: ' + name + '; ' + ('PASS' if row['passed'] else 'FAIL') + '; documented exceptions=' +
              json.dumps(row['excepted_offenders']))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

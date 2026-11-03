"""Cold current-builder proof against the unchanged approved delivery."""
import argparse
import json
from pathlib import Path

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.glacial_mirror.regeneration_inputs import clean_inputs, input_builder
from .shoulder_workflow import ROOT, capture, job


def prove(figure):
    output = figure / 'proof/feedback2'
    recipe = figure / 'measurements.json'
    fresh = clean_inputs(output, figure, recipe)
    job(input_builder(fresh), [fresh, output / 'native', '--build-only'], output / 'bridge/native.json')
    native = json.loads((output / 'native/build_report.json').read_text())
    prior = json.loads((figure / 'delivery/build_report.json').read_text())
    if not native['passed'] or native['combined_mesh_hash'] != prior['combined_mesh_hash']:
        raise ValueError('Current builder changed approved native geometry or failed a gate')
    observed = capture(fresh, output / 'native', output / 'capture', preview=True)
    clean_inputs(output, figure, recipe, resume=True)
    views = compare_captures(observed, figure / 'delivery', output)
    motion = native['geometry_details']['shoulder_garment_motion']
    audits = {name: row['independent_audit'] for name, row in motion.items()}
    passed = (all(r['passed'] for parts in views.values() for r in parts.values()) and
              all(r['passed'] for r in audits.values()))
    report = {'passed': passed, 'compiled_spec_hash': digest(json.loads(fresh.read_text())),
        'input_inventory_sha256': sha(output / 'clean_input_sha256.json'),
        'approved_geometry_hash': prior['combined_mesh_hash'], 'current_geometry_hash': native['combined_mesh_hash'],
        'current_native_gate': native['checks']['native_shoulder_attachment_motion'],
        'independent_audits': audits, 'views': views,
        'method': 'Fresh input-only current builder, no cache reuse; exact native geometry and canonical clay/map comparison against the approved sealed delivery. Delivery files are not rewritten.'}
    write(output / 'feedback2_regeneration.json', report)
    print('MQ12_FEEDBACK2_REGENERATION: ' + ('PASS' if passed else 'FAIL') + '; ' + figure.name +
          '; geometry_identical=' + str(native['combined_mesh_hash'] == prior['combined_mesh_hash']) +
          '; clay_and_maps_identical=' + str(all(r['passed'] for parts in views.values() for r in parts.values())))
    return passed


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('figure', choices=('gale_herald', 'gloam_stalker'))
    args = parser.parse_args()
    raise SystemExit(0 if prove(ROOT / args.figure) else 1)

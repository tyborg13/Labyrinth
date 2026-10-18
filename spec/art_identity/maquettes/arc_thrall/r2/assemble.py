"""Assemble mq-07's bridge captures and bind their native determinism proof.

This prepares a candidate for gated promotion. It never accepts a stale
report or converts unresolved design fields into approval.
"""
import json
from pathlib import Path
import shutil

import numpy as np

from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery
from spec.art_identity.maquettes.arc_thrall.r2.proof import FIGURE, joints


ASSEMBLY_DEFAULTS = {'joint_tolerance_px': .011}


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def main():
    root = FIGURE / 'r2/proof'
    spec = compile_recipe(read(FIGURE / 'r2/measurements.json'))
    current = digest(spec)
    output = root / 'capture'
    output.mkdir(exist_ok=True)
    projected = joints(spec)
    names, joint_table, counts, captures, frames = [], {}, {}, {}, {}
    native = read(root / 'native/build_report.json')
    if native['spec_hash'] != current or not native['passed']:
        raise ValueError('Missing current passing native build')
    cold = read(root / 'determinism/cold/build_report.json')
    if cold['spec_hash'] != current or cold['mesh_hashes'] != native['mesh_hashes'] or not cold['passed']:
        raise ValueError('Capture geometry differs from current independently cold-built geometry')
    native = cold
    for view in ('front', 'rear'):
        folder = root / view
        manifest = read_manifest(folder, current, ('full',))
        capture = read(folder / 'capture_checks.json')
        if capture['spec_hash'] != current or not capture['passed'] or not capture['geometry_unchanged']:
            raise ValueError('Missing passing invariant capture: ' + view)
        table = read(folder / 'joints_px.json')
        frame = read(folder / 'capture_frame.json') if (folder / 'capture_frame.json').exists() else {}
        frames.update(frame)
        pan = frame.get(view, {}).get('pan_px', [0, 0])
        if set(table) != {view} or set(table[view]) != set(spec['joints']):
            raise ValueError('Incomplete native joint table: ' + view)
        if any(not np.allclose(value, np.asarray(projected[view][name]) + pan, atol=ASSEMBLY_DEFAULTS['joint_tolerance_px'], rtol=0)
               for name, value in table[view].items()):
            raise ValueError('Native joints differ from compiled pose: ' + view)
        for name in manifest['images']:
            shutil.copyfile(folder / name, output / name)
            names.append(name)
        captures[view] = capture
        joint_table.update(table)
        counts.update(read(folder / 'solo_coverage.json'))
    facing = read(root / 'front/facing_report.json')
    native['checks'].update(rendered_torso_asymmetry=facing['passed'], capture_geometry_unchanged=True,
                            required_solo_coverage=all(n > 0 for view in counts.values() for n in view.values()))
    native['passed'] = all(native['checks'].values())
    write(output / 'build_report.json', native)
    write(output / 'joints_px.json', joint_table)
    write(output / 'capture_frame.json', frames)
    write(output / 'solo_coverage.json', counts)
    write(output / 'facing_report.json', facing)
    write(output / 'capture_checks.json', {'passed': native['passed'], 'geometry_unchanged': True,
          'spec_hash': current, 'geometry_checks': native['checks'], 'facing': facing,
          'view_capture_checks': captures})
    write(output / 'ownership_validation.json', {'passed': all(n > 0 for v in counts.values() for n in v.values()),
          'empty_required_solos': {view: [name for name in spec['labels'] if counts[view].get(name, 0) <= 0]
                                   for view in ('front', 'rear')}})
    write_manifest(output, current, 'full', names)
    for name in ('recipe_proof.json', 'exact_native_replay.json'):
        shutil.copyfile(root / 'determinism' / name, output / name)
    seal_delivery(spec, output)
    print('MQ07_NATIVE_ASSEMBLY: PASS; ' + str(output))


if __name__ == '__main__':
    main()

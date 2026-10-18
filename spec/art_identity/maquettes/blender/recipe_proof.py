"""Native cold-build, cache replay and joint endpoint proof for a fitted spec."""
import json
from pathlib import Path
import sys
import uuid
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

import bpy
from mathutils import Vector

from spec.art_identity.maquettes.blender.build import build, write
from spec.art_identity.maquettes.blender.contract import DEFAULT_BUNDLE, BUILD_DEFAULTS


PROOF_DEFAULTS = {'joint_error_max': 1e-4}


def main(spec_path, output):
    spec = json.loads(Path(spec_path).read_text())
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    cache = output / 'cache' / uuid.uuid4().hex
    bundle = Path(DEFAULT_BUNDLE).expanduser()
    reports = {}
    for name in ('cold', 'replay', 'independent_cold'):
        _, reports[name] = build(spec, output / name, bundle,
                                  cache if name != 'independent_cold' else output / 'cache' / uuid.uuid4().hex)
    rig = bpy.data.objects['maquette_armature']
    errors = {bone['name']: max((rig.pose.bones[bone['name']].head - Vector(spec['joints'][bone['head']])).length,
                 (rig.pose.bones[bone['name']].tail - Vector(spec['joints'][bone['tail']])).length)
              for bone in spec['armature']['bones']}
    hashes = [report['mesh_hashes'] for report in reports.values()]
    identical = all(value == hashes[0] for value in hashes[1:])
    checks = {'fresh_and_replay_raw_hashes': identical,
              'joint_endpoints': max(errors.values()) <= PROOF_DEFAULTS['joint_error_max'],
              'native_geometry': all(report['passed'] for report in reports.values())}
    result = {'passed': all(checks.values()), 'checks': checks, 'spec_hash': reports['cold']['spec_hash'],
              'cache_revision': BUILD_DEFAULTS['cache_revision'], 'raw_hashes_identical': identical,
              'mesh_count': len(hashes[0]), 'joint_errors': errors,
              'combined_mesh_hashes': {name: report['combined_mesh_hash'] for name, report in reports.items()}}
    write(output / 'recipe_proof.json', result)
    print('FITTED_RECIPE_PROOF: ' + ('PASS' if result['passed'] else 'FAIL') +
          '; raw_hashes_identical=' + str(identical).lower() + '; max_joint_error=' + str(max(errors.values())))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

"""Bounded single-view native capture, with explicit failed-build diagnostics.

Run only through bridge_client.py. Diagnostic captures always retain failed
geometry checks and return nonzero; they cannot certify an invalid delivery.
"""
import argparse
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

import bpy

from spec.art_identity.maquettes.blender.contract import digest, mesh_hash
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.render import render
from spec.art_identity.maquettes.blender.validation import geometry_report


def signature(objects):
    rig = bpy.data.objects['maquette_armature']
    return {'objects': {o.name: {'mesh': mesh_hash([list(v.co) for v in o.data.vertices],
                           [list(p.vertices) for p in o.data.polygons]),
                           'matrix': [list(row) for row in o.matrix_basis]} for o in objects},
            'pose': {b.name: [list(row) for row in b.matrix] for b in rig.pose.bones}}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec', type=Path)
    parser.add_argument('blend', type=Path)
    parser.add_argument('out', type=Path)
    parser.add_argument('view', choices=('front', 'rear', 'both'))
    parser.add_argument('--diagnostic', action='store_true')
    args = parser.parse_args(argv)
    spec = json.loads(args.spec.read_text())
    report = json.loads(args.blend.with_name('build_report.json').read_text())
    if report['spec_hash'] != digest(spec):
        raise ValueError('Saved build belongs to a different specification')
    bpy.ops.wm.open_mainfile(filepath=str(args.blend))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    working = board_spec(spec)
    checks = geometry_report(working, objects, report['cloth'])
    if not all(checks.values()) and not args.diagnostic:
        raise ValueError('Saved geometry failed validation: ' + str(checks))
    before = signature(objects)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'build_report.json').write_text(json.dumps(report, indent=2) + '\n')
    views = ('front', 'rear') if args.view == 'both' else (args.view,)
    facing = render(working, objects, args.out, views=views)
    unchanged = before == signature(objects)
    if not unchanged:
        raise ValueError('Capture mutated geometry, attachment or pose')
    passed = report['passed'] and all(checks.values()) and (facing is None or facing['passed'])
    from spec.art_identity.maquettes.blender.view_states import active_in_view
    (args.out / 'capture_checks.json').write_text(json.dumps({'passed': passed,
        'geometry_unchanged': unchanged, 'diagnostic': args.diagnostic,
        'spec_hash': report['spec_hash'],
        'cloth_view_states': {o['piece_id']: {'view': o['capture_view'],
            'visible': active_in_view(o, views[0]) if len(views) == 1 else
                       {view: active_in_view(o, view) for view in views}, 'part': o['part']}
            for o in objects if 'capture_view' in o},
        'geometry_checks': checks, 'facing': facing}, indent=2) + '\n')
    print('FITTED_VIEW_CAPTURE: ' + ('PASS' if passed else 'FAIL') + '; view=' + args.view)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[sys.argv.index('--') + 1:]))

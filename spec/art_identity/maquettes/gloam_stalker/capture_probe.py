"""mq-13 bounded capture; verify the loaded saved body before any rendering."""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(argv):
    from spec.art_identity.maquettes.gloam_stalker.saved_body import load
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec', type=Path)
    parser.add_argument('build', type=Path)
    parser.add_argument('out', type=Path)
    parser.add_argument('view', choices=('front', 'rear'))
    parser.add_argument('--solos', nargs='+')
    parser.add_argument('--diagnostic', action='store_true')
    parser.add_argument('--comparison', action='store_true')
    args = parser.parse_args(argv)
    spec, report, objects, native_hash = load(args.spec, args.build)
    import bpy
    import numpy as np
    from mathutils import Vector
    from spec.art_identity.maquettes.blender.capture_view import signature
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.facing import board_spec
    from spec.art_identity.maquettes.blender.render import render
    from spec.art_identity.maquettes.blender.validation import geometry_report
    from spec.art_identity.maquettes.raster import project

    checks = geometry_report(board_spec(spec), objects, report['cloth'])
    if (not all(checks.values()) or not report['passed']) and not args.diagnostic:
        raise ValueError('Native geometry failed: ' + str(checks))
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'build_report.json').write_text(json.dumps(report, indent=2) + '\n')
    before = signature(objects)
    observations = {}
    for view in ('front', 'rear'):
        tops = {}
        for part in ('upper_near', 'upper_far', 'head'):
            points = [list(o.matrix_world @ v.co) for o in objects if o.get('part') == part for v in o.data.vertices]
            if points:
                projected = project(board_spec(spec), points, view)
                tops[part] = projected[np.argmin(projected[:, 1]), :2].tolist()
        observations[view] = tops
    working = board_spec(spec)
    if args.comparison:
        working.pop('fit', None)
    facing = render(working, objects, args.out, views=(args.view,),
                    preview=args.solos is None, ownership_only=args.solos is not None,
                    solo_parts=args.solos)
    unchanged = signature(objects) == before
    if not unchanged:
        raise ValueError('Capture changed frozen meshes or armature pose')
    # Rear rendering deliberately turns the parent root by 180 degrees. The
    # loaded world-space digest was verified before that view transform; the
    # signature above requires every local mesh, attachment and pose to stay exact.
    result = {'passed': unchanged and all(checks.values()), 'spec_hash': digest(spec),
              'geometry_unchanged': unchanged, 'geometry_checks': checks, 'facing': facing,
              'mass_tops_px': observations, 'native_mesh_hash': native_hash, 'loaded_geometry_verified': True}
    rig = bpy.data.objects['maquette_armature']
    result['joint_errors_m'] = {b['name']: max(
        (rig.pose.bones[b['name']].head - Vector(spec['joints'][b['head']])).length,
        (rig.pose.bones[b['name']].tail - Vector(spec['joints'][b['tail']])).length)
        for b in spec['armature']['bones']}
    (args.out / 'batch_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('MQ13_BOUNDED_CAPTURE: COMPLETE; native_geometry=' + str(result['passed']) +
          '; view=' + args.view + '; solos=' + str(args.solos))


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:])

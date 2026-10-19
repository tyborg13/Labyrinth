"""mq-08 bridge-only bounded captures and independent frozen-mesh observations."""
import argparse
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(argv):
    import bpy
    import numpy as np
    from spec.art_identity.maquettes.blender.capture_view import signature
    from spec.art_identity.maquettes.blender.contract import digest
    from spec.art_identity.maquettes.blender.facing import board_spec
    from spec.art_identity.maquettes.blender.render import render
    from spec.art_identity.maquettes.blender.validation import geometry_report
    from spec.art_identity.maquettes.raster import project
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec', type=Path)
    parser.add_argument('build', type=Path)
    parser.add_argument('out', type=Path)
    parser.add_argument('view', choices=('front', 'rear'))
    parser.add_argument('--solos', nargs='+')
    parser.add_argument('--comparison', action='store_true', help='Only the clay/map comparison passes; omit optional fit masks')
    args = parser.parse_args(argv)
    spec = json.loads(args.spec.read_text())
    report = json.loads((args.build / 'build_report.json').read_text())
    if digest(spec) != report['spec_hash']:
        raise ValueError('Saved geometry belongs to a different spec')
    bpy.ops.wm.open_mainfile(filepath=str(args.build / 'maquette.blend'))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    checks = geometry_report(board_spec(spec), objects, report['cloth'])
    if not all(checks.values()) or not report['passed']:
        raise ValueError('Native geometry failed: ' + str(checks))
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'build_report.json').write_text(json.dumps(report, indent=2) + '\n')
    before = signature(objects)
    observations = {}
    for view in ('front', 'rear'):
        tops = {}
        for part in ('upper_near', 'upper_far', 'head'):
            points = [list(o.matrix_world @ v.co) for o in objects if o.get('part') == part for v in o.data.vertices]
            if not points:
                continue
            projected = project(board_spec(spec), points, view)
            top = projected[np.argmin(projected[:, 1]), :2]
            tops[part] = top.tolist()
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
    result = {'passed': unchanged and all(checks.values()), 'spec_hash': digest(spec),
              'geometry_unchanged': unchanged, 'geometry_checks': checks, 'facing': facing,
              'mass_tops_px': observations, 'native_mesh_hash': report['combined_mesh_hash']}
    from mathutils import Vector
    rig = bpy.data.objects['maquette_armature']
    result['joint_errors_m'] = {b['name']: max(
        (rig.pose.bones[b['name']].head - Vector(spec['joints'][b['head']])).length,
        (rig.pose.bones[b['name']].tail - Vector(spec['joints'][b['tail']])).length)
        for b in spec['armature']['bones']}
    (args.out / 'batch_checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print('MIRROR_BOUNDED_CAPTURE: PASS; view=' + args.view + '; solos=' + str(args.solos))


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:])

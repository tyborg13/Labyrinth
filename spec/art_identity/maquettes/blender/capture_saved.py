"""Capture an already verified baked build through the bridge, without rebinding."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

import bpy

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.contract import mesh_hash
from spec.art_identity.maquettes.blender.render import render


def main(spec_path, blend, output, mode='full'):
    spec = json.loads(Path(spec_path).read_text())
    report_path = Path(blend).parent / 'build_report.json'
    report = json.loads(report_path.read_text())
    if digest(spec) != report['spec_hash']:
        raise ValueError('Saved build belongs to a different spec')
    bpy.ops.wm.open_mainfile(filepath=blend)
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    (output / 'build_report.json').write_text(json.dumps(report, indent=2) + '\n')
    from spec.art_identity.maquettes.blender.facing import board_spec
    working = board_spec(spec)
    ownership_only = mode.startswith('ownership-')
    def signature(parented=False):
        # matrix_local is reconstructed through the turned parent's inverse;
        # at rear yaw its float roundoff is not an authoring transform change.
        # matrix_basis is the actual immutable attachment transform.
        geometry = {obj.name: {'mesh': mesh_hash([list(v.co) for v in obj.data.vertices],
                                            [list(p.vertices) for p in obj.data.polygons]),
                           'matrix': [list(row) for row in obj.matrix_basis]}
                for obj in objects}
        rig = bpy.data.objects['maquette_armature']
        return {'objects': geometry, 'pose': {b.name: [list(row) for row in b.matrix] for b in rig.pose.bones}}
    geometry = signature()
    from spec.art_identity.maquettes.blender.validation import geometry_report
    checks = geometry_report(working, objects, report['cloth'])
    if not all(checks.values()):
        raise ValueError('Saved geometry ownership validation failed: ' + str(checks))
    views = (mode.split('-')[1],) if ownership_only else ('front', 'rear')
    try:
        render(working, objects, output, engine='cycles', gallery=mode == 'full', fit_only=mode == 'fit',
               preview=mode == 'preview', views=views, ownership_only=ownership_only)
    finally:
        if geometry != signature(parented=True):
            raise ValueError('Capture changed approved geometry or pose')
        (output / (mode + '_geometry.json')).write_text(json.dumps({'passed': True, 'unchanged_geometry': geometry,
            'validation': checks}, indent=2) + '\n')
    print('BLENDER_SAVED_CAPTURE: PASS')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

"""Capture an already verified baked build through the bridge, without rebinding."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

import bpy

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.contract import digest
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
    render(board_spec(spec), objects, output, engine='cycles', gallery=mode == 'full', fit_only=mode == 'fit', preview=mode == 'preview')
    print('BLENDER_SAVED_CAPTURE: PASS')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

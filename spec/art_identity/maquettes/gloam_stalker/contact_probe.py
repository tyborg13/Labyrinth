"""Bridge-only diagnostic of the existing regional hood contact solver."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(spec_path, build, output):
    import bpy
    from spec.art_identity.maquettes.blender.cloth_contacts import collision_report
    from spec.art_identity.maquettes.blender.posed_surfaces import clear_shoulder_contacts
    spec = json.loads(Path(spec_path).read_text())
    bpy.ops.wm.open_mainfile(filepath=str(Path(build) / 'maquette.blend'))
    body, hood = bpy.data.objects['posed_body'], bpy.data.objects['hood_render']
    piece = next(p for p in spec['pieces'] if p['id'] == 'hood')
    clear_shoulder_contacts(hood, body, piece, spec)
    result = collision_report(hood, body, piece['collision_margin'])
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('MQ13_HOOD_CONTACT: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + json.dumps(result))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

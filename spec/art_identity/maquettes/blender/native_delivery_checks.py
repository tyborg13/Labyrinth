"""Inspect real native delivery meshes and mutate their ownership in memory.

Bridge-only entry. A JSON job lists spec and build directories explicitly so
the same probe works for clean regenerations and curated recipe inputs.
"""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

import bpy

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.blender.sewn_garment import topology_report

def main(job_path, output):
    results = {}
    for entry in json.loads(Path(job_path).read_text()):
        spec = json.loads(Path(entry['spec']).read_text())
        build = Path(entry['build'])
        report = json.loads((build / 'build_report.json').read_text())
        bpy.ops.wm.open_mainfile(filepath=str(build / 'maquette.blend'))
        objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
        native = geometry_report(board_spec(spec), objects, report['cloth'])
        saved = {o.name: [p.material_index for p in o.data.polygons] for o in objects}
        for obj in objects:
            for face in obj.data.polygons:
                face.material_index = 0
        mutation = geometry_report(board_spec(spec), objects, report['cloth'])
        for obj in objects:
            for face, owner in zip(obj.data.polygons, saved[obj.name]):
                face.material_index = owner
        checks = {'current_spec': report['spec_hash'] == digest(spec), 'native_geometry': all(native.values()),
                  'material_mutation_caught': not mutation['polygon_material_ownership']}
        details = {}
        if spec['id'] == 'gale_herald':
            hood = bpy.data.objects['masked_hood_render']
            rest = json.loads(hood['rounded_hood_report'])
            topology = topology_report([list(v.co) for v in hood.data.vertices], [list(p.vertices) for p in hood.data.polygons])
            checks['closed_cowl_without_aperture'] = rest['opening_width_ratio'] == 0 and rest.get('cut_faces', 0) == 0
            checks['hood_no_open_boundaries'] = topology['boundary_loops'] == 0 and topology['nonmanifold_edges'] == 0
            mask = bpy.data.objects['crest_mask_render']
            mask_topology = topology_report([list(v.co) for v in mask.data.vertices], [list(p.vertices) for p in mask.data.polygons])
            checks['one_closed_mask'] = mask_topology['connected'] and mask_topology['boundary_loops'] == 0
            details.update(hood_topology=topology, mask_topology=mask_topology)
        if spec['id'] == 'gloam_stalker':
            shell = bpy.data.objects['back_carapace_render']
            checks['carapace_own_part_on_torso'] = shell['part'] == 'carapace' and shell['rig_joint'] == 'torso'
            topology = topology_report([list(v.co) for v in shell.data.vertices], [list(p.vertices) for p in shell.data.polygons])
            checks['carapace_closed_plates'] = topology['nonmanifold_edges'] == 0 and topology['boundary_loops'] == 0
            attachments = {o.name: json.loads(o['blade_attachment_report']) for o in objects if 'blade_attachment_report' in o}
            checks['two_attached_single_piece_claws'] = len(attachments) == 2 and all(r['passed'] for r in attachments.values())
            checks['carapace_cloth_collisions'] = all(r['passed'] for name, r in report['cloth'].items() if name.endswith('__back_carapace')) and any(name.endswith('__back_carapace') for name in report['cloth'])
            details.update(carapace_topology=topology, blade_attachments=attachments)
        results[spec['id']] = {'passed': all(checks.values()), 'spec_hash': digest(spec), 'checks': checks, 'details': details}
    passed = all(r['passed'] for r in results.values())
    Path(output).write_text(json.dumps({'passed': passed, 'figures': results}, indent=2) + '\n')
    print('NATIVE_DELIVERY_CHECKS: ' + ('PASS' if passed else 'FAIL') + '; actual_material_mutations_caught=' +
          str(sum(r['checks']['material_mutation_caught'] for r in results.values())))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

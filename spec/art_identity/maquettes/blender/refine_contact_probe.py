"""Disposable extra contact refinement; never overwrites a delivered model."""
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
import bpy

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.cloth_contacts import collision_report, stabilise_collision, project_constraints, mesh_payload

PROBE_DEFAULTS = {'extra_refinement_levels': 1}


def main(blend, spec_path, piece_id, output):
    bpy.ops.wm.open_mainfile(filepath=blend)
    spec = json.loads(Path(spec_path).read_text())
    piece = dict(next(p for p in spec['pieces'] if p['id'] == piece_id))
    obj = bpy.data.objects[piece_id]
    support = bpy.data.objects['native_drape_collision_skin']
    for modifier in list(obj.modifiers):
        obj.modifiers.remove(modifier)
    piece['collision_refine_levels'] = PROBE_DEFAULTS['extra_refinement_levels']
    stabilise_collision(obj, support, piece)
    solid = obj.modifiers.new('cloth_thickness', 'SOLIDIFY')
    solid.thickness, solid.offset = piece['thick'], piece['solidify_offset']
    result = {'disposable': True, 'extra_refinement_levels': piece['collision_refine_levels'],
              'source_body': collision_report(obj, bpy.data.objects['posed_body'], piece['collision_margin']),
              'collision_support': collision_report(obj, support, piece['collision_margin'])}
    # A local convex contact surface tests whether the enclosing voxel union's
    # concave shoulder normal is trapping a small triangle patch.
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.blender.conformance import regional_body
    body = bpy.data.objects['posed_body']
    data = mesh_payload(body)
    tree = BVHTree.FromPolygons([Vector(p) for p in data['vertices']], data['faces'])
    cloth = mesh_payload(obj)
    surface = BVHTree.FromPolygons([Vector(p) for p in cloth['vertices']], cloth['faces'])
    owners = json.loads(body['face_owners'])
    regions = sorted({owners[j] for _, j in surface.overlap(tree)})
    obj.modifiers.clear()
    for region in regions:
        hull = regional_body(body, {'id': 'diagnostic_' + region, 'body_regions': [region], 'contact_hull': True})
        project_constraints(obj, hull, piece)
    solid = obj.modifiers.new('cloth_thickness', 'SOLIDIFY')
    solid.thickness, solid.offset = piece['thick'], piece['solidify_offset']
    result['regional_contacts'] = regions
    result['regional_refinement'] = collision_report(obj, body, piece['collision_margin'])
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('EXTRA_CONTACT_REFINEMENT: ' + json.dumps(result))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

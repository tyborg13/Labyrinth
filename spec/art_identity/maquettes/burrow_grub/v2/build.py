"""Run via the director's Blender bridge; bounded build or capture jobs."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

import bpy
import numpy as np

from spec.art_identity.maquettes.burrow_grub.v2 import recipe
from spec.art_identity.maquettes.blender.build import write
from spec.art_identity.maquettes.blender.contract import digest, mesh_hash


def evaluated(obj):
    obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    data = obj.to_mesh()
    points = np.array([list(obj.matrix_world @ v.co) for v in data.vertices])
    faces = [list(p.vertices) for p in data.polygons]
    obj.to_mesh_clear()
    return points, faces


def build(output):
    from spec.art_identity.maquettes.blender.creature_recipe import compile_solids
    from spec.art_identity.maquettes.blender.sculpted_mass import sculpted_mass
    from spec.art_identity.maquettes.blender.limb_mesh import build as limb
    from spec.art_identity.maquettes.blender.pieces import mesh_object
    from spec.art_identity.maquettes.blender.creature_rig import create
    from spec.art_identity.maquettes.blender.render import material
    from spec.art_identity.maquettes.burrow_grub.v2.floor_report import measure
    from spec.art_identity.maquettes.burrow_grub.v2.stub_legs import fit as stub_leg

    baseline = compile_solids(json.loads(recipe.BASELINE.read_text()))
    contract_path = recipe.HERE / 'feedback_1_contract.json'
    contract = json.loads(contract_path.read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    groups, polygons = {}, {}
    placements = recipe.plan(baseline['pieces'])
    sources = []
    for piece in baseline['pieces']:
        print('MQ27_SCULPT: ' + piece['id'], flush=True)
        obj = sculpted_mass(piece, baseline) if piece['type'] == 'sculpted_mass' else limb(piece, baseline)
        points, faces = evaluated(obj)
        sources.append(obj)
        if piece['part'] in recipe.RINGS:
            points = recipe.ring_points(points, piece, placements[piece['part']])
        groups[piece['id']], polygons[piece['id']] = points, faces
    body_groups = {n: p for n, p in groups.items() if n not in recipe.LEGS}
    spine, factor = recipe.normalise_body(body_groups, placements, baseline['pieces'])
    groups.update(body_groups)
    leg_factors, leg_joints, leg_shapes = {}, {}, {}
    for name in recipe.LEGS:
        piece = next(p for p in baseline['pieces'] if p['id'] == name)
        segment = recipe.CONSTRAINTS['leg_segments'][int(name[-1]) - 1]
        placement = placements[f'seg_{segment}']
        groups[name], polygons[name], leg_joints[name], leg_shapes[name] = stub_leg(
            piece, placement, baseline['joints'][name + '_tip'], baseline, contract)
        leg_factors[name] = leg_shapes[name]['axis_factor']
    # Feedback 1 approves the body and its exact world placement. Reframing
    # from the changed feet would move that approved body: retain its plane.
    floor_z = contract['floor_z_m']
    for points in groups.values():
        points[:, 2] += floor_z
    for placement in placements.values():
        placement['centre'][2] += floor_z
    for point in spine:
        point[2] += floor_z
    for pair in leg_joints.values():
        for point in pair:
            point[2] += floor_z
    spec = recipe.joint_spec(baseline, groups, placements, leg_joints)
    for obj in sources:
        bpy.data.objects.remove(obj, do_unlink=True)
    rig, _ = create(spec)[:2]
    objects = []
    for piece in spec['pieces']:
        name = piece['id']
        obj = mesh_object(name + '_render', groups[name].tolist(), polygons[name])
        for poly in obj.data.polygons:
            poly.use_smooth = True
        obj['part'] = piece['part']
        obj['piece_id'] = name
        obj['piece_type'] = piece['type']
        obj['owner_index'] = list(spec['labels']).index(piece['part'])
        obj['rig_bone'] = piece['rig_bone']
        # Capture meshes remain immutable. An editable, bone-bound duplicate
        # retains each labelled whole form for the following rig unit.
        source = obj.copy()
        source.data = obj.data.copy()
        source.name = name
        bpy.context.scene.collection.objects.link(source)
        source['native_source'] = True
        source.parent, source.parent_type, source.parent_bone = rig, 'BONE', piece['rig_bone']
        bpy.context.view_layer.update()
        from mathutils import Matrix
        source.matrix_world = Matrix.Identity(4)
        source.hide_render = True
        source.hide_set(True)
        for label, colour in spec['labels'].items():
            obj.data.materials.append(material(label, colour, 'parts'))
        for poly in obj.data.polygons:
            poly.material_index = obj['owner_index']
        objects.append(obj)
    rig.hide_render = True
    bpy.context.view_layer.update()
    final = {o['piece_id']: evaluated(o)[0] for o in objects}
    report = measure(final, baseline['pieces'], placements, spine, leg_shapes, floor_z)
    hashes = {o.name: mesh_hash(final[o['piece_id']].tolist(), polygons[o['piece_id']], o['part']) for o in objects}
    checks = {**report['checks'],
              'approved_body_geometry_unchanged': all(hashes[name] == value for name, value in contract['protected_mesh_hashes'].items()),
              'approved_body_joints_unchanged': all(spec['joints'][name] == value for name, value in contract['protected_joints'].items()),
              'labels_and_joint_names': set(spec['labels']) == set(baseline['labels']) and
              set(spec['joints']) == set(baseline['joints']),
              'six_leg_parents': all(b['parent'] == f"seg_{recipe.CONSTRAINTS['leg_segments'][int(b['name'][-1]) - 1]}"
                  for b in spec['armature']['bones'] if b['name'] in recipe.LEGS)}
    provenance = {'baseline_measurements_sha256': hashlib.sha256(recipe.BASELINE.read_bytes()).hexdigest(),
                  'feedback_1_contract_sha256': hashlib.sha256(contract_path.read_bytes()).hexdigest(),
                  'implementation_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in recipe.HERE.glob('*.py')}, 'constraints': recipe.CONSTRAINTS,
                  'proof_defaults': recipe.PROOF_DEFAULTS, 'body_uniform_scale': factor}
    output.mkdir(parents=True, exist_ok=True)
    write(output / 'source_spec.json', spec)
    write(output / 'floor_contact_report.json', report)
    write(output / 'build_report.json', {'schema': 2, 'blender': bpy.app.version_string,
          'spec_hash': digest(spec), 'mesh_hashes': hashes, 'combined_mesh_hash': digest(hashes),
          'checks': checks, 'passed': all(checks.values()), 'provenance': provenance,
          'placements': placements, 'spine_floor_m': spine, 'leg_factors': leg_factors, 'leg_shapes': leg_shapes})
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'maquette.blend'))
    print('MQ27_BUILD: ' + ('PASS' if all(checks.values()) else 'FAIL'), flush=True)
    return 0 if all(checks.values()) else 1


def capture(build_dir, output, view, kind):
    from spec.art_identity.maquettes.blender.render import render
    bpy.ops.wm.open_mainfile(filepath=str(build_dir / 'maquette.blend'))
    spec = json.loads((build_dir / 'source_spec.json').read_text())
    report = json.loads((build_dir / 'build_report.json').read_text())
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    def signature():
        return {o.name: mesh_hash([list(v.co) for v in o.data.vertices], [list(p.vertices) for p in o.data.polygons], o['part']) for o in objects}
    before = signature()
    output.mkdir(parents=True, exist_ok=True)
    write(output / 'build_report.json', report)
    render(spec, objects, output, views=(view,), preview=kind == 'preview',
           solos_only=kind == 'solos', ownership_only=kind == 'solos',
           solo_parts=list(spec['labels']) if kind == 'solos' else None,
           capture_facing=False,
           image_modes=['clay', 'parts', 'silhouette'] if kind == 'preview' else None)
    checks = {'geometry_unchanged': before == signature(), 'build_passed': report['passed']}
    write(output / f'{view}_{kind}_capture.json', {'checks': checks, 'passed': all(checks.values()),
           'view': view, 'yaw_deg': 0 if view == 'front' else 180,
           'spec_hash': report['spec_hash'], 'size_px': [1024, 1024]})
    print('MQ27_CAPTURE: ' + ('PASS' if all(checks.values()) else 'FAIL') + f'; {view} {kind}')
    return 0 if all(checks.values()) else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['build', 'capture'])
    parser.add_argument('build_dir', type=Path)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--view', choices=['front', 'rear'])
    parser.add_argument('--kind', choices=['preview', 'solos'], default='preview')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    raise SystemExit(build(args.build_dir) if args.mode == 'build' else
                     capture(args.build_dir, args.out, args.view, args.kind))

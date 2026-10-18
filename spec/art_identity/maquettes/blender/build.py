#!/usr/bin/env python3
"""Native entry: bridge_client.py blender/build.py -- SPEC OUT [--engine cycles]."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.contract import digest, mesh_hash, validate


def write(path, value):
    Path(path).write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def build(spec, output, bundle, cache):
    import bpy
    from spec.art_identity.maquettes.blender.rig import append_body, bind_and_pose, evaluated_mesh
    from spec.art_identity.maquettes.blender import pieces
    from spec.art_identity.maquettes.blender.cloth import cloth

    validate(spec)
    source_hash = digest(spec)
    input_spec = spec
    from spec.art_identity.maquettes.blender.facing import board_spec
    spec = board_spec(spec)
    target_joints = deepcopy(spec['joints'])
    if spec.get('floor_contact_correction'):
        spec['joints'] = deepcopy(spec['floor_contact_correction']['fitted_joints'])
    if spec.get('rear_body'):
        spec['joints'] = deepcopy(spec['rear_body']['fitted_joints'])
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    write(output / 'source_spec.json', input_spec)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.use_scripts_auto_execute = False
    bpy.context.scene.gravity = spec['simulation']['gravity']
    bpy.context.scene.render.fps = spec['simulation']['fps']
    print('BUILD_STAGE: append anatomy', flush=True)
    body = append_body(spec, bundle)
    print(f'BUILD_STAGE: bind {len(body.data.vertices)} anatomy vertices', flush=True)
    rig, posed, owners = bind_and_pose(spec, body)
    from spec.art_identity.maquettes.blender.source_cage import fit_body
    source_fit = fit_body(spec, body, rig, posed)
    posed['face_owners'] = json.dumps(owners)
    rear_pose = None
    context_key = digest({'spec': spec, 'bundle_sha256': hashlib.sha256(Path(bundle).read_bytes()).hexdigest()})
    objects = []
    cloth_reports = {}
    simulation_reports = {}
    for piece in spec['pieces']:
        print('BUILD_STAGE: ' + piece['id'], flush=True)
        if spec.get('rear_body', {}).get('hem_piece') == piece['id']:
            from spec.art_identity.maquettes.blender.rear_body import pose_leg
            rear_pose = pose_leg(spec, body, rig, posed, target_joints)
        kind = piece['type']
        if kind == 'cloth':
            obj = cloth(piece, spec, posed, cache, context_key)
            cloth_reports[piece['id']] = json.loads(obj['collision_report'])
            if 'simulation_report' in obj:
                simulation_reports[piece['id']] = json.loads(obj['simulation_report'])
            result = [obj]
        elif kind == 'neck_collar':
            from spec.art_identity.maquettes.blender.neck_collar import build as collar
            result = [collar(piece, spec, posed)]
        elif kind == 'lames':
            result = pieces.lames(piece, spec, posed)
        elif kind == 'plate':
            result = [pieces.plate(piece, spec, posed)]
        else:
            result = [getattr(pieces, kind)(piece, spec)]
        for obj in result:
            data = evaluated_mesh(obj)
            # Keep the native curve/modifier stack editable in the saved blend;
            # render immutable evaluated copies so camera turns cannot change
            # shrinkwrap or collision evaluation beneath a captured frame.
            frozen = bpy.data.objects.new(obj.name + '_render', data)
            bpy.context.scene.collection.objects.link(frozen)
            frozen.matrix_world = obj.matrix_world.copy()
            for key in obj.keys():
                frozen[key] = obj[key]
            obj['native_source'] = True
            obj.hide_render = True
            obj.hide_set(True)
            frozen.data.materials.clear()
            frozen['owner_index'] = list(spec['labels']).index(piece['part'])
            objects.append(frozen)
    # Split posed body into true unoccluded semantic solos using weight owners.
    for region in sorted(set(owners)):
        if region in spec['base'].get('covered_regions', []):
            continue
        faces = [list(p.vertices) for p, owner in zip(posed.data.polygons, owners) if owner == region
                 and not ('covered_above_z' in spec['base'] and
                          min((posed.matrix_world @ posed.data.vertices[i].co).z for i in p.vertices)
                          > spec['base']['covered_above_z'])]
        obj = pieces.mesh_object('body_' + region, [list(v.co) for v in posed.data.vertices], faces)
        obj.matrix_world = posed.matrix_world.copy()
        obj['part'] = region
        obj['owner_index'] = list(spec['labels']).index(region)
        obj['piece_type'] = 'body'
        objects.append(obj)
    floor_contact = None
    if rear_pose is not None:
        from spec.art_identity.maquettes.blender.rear_body import floor_report
        from spec.art_identity.maquettes.blender.cloth_contacts import collision_report
        floor_contact = floor_report(spec, objects, rear_pose)
        cloth_reports.update({p['id']: collision_report(bpy.data.objects[p['id'] + '_render'], posed,
            p['collision_margin']) for p in spec['pieces'] if p['type'] == 'cloth'})
    if spec.get('floor_contact_correction'):
        from spec.art_identity.maquettes.blender.floor_contact_native import apply as correct_floor
        floor_contact, corrected_collisions = correct_floor(spec, objects, body, rig, posed, target_joints)
        cloth_reports.update(corrected_collisions)
    posed.hide_render = True
    posed.hide_set(True)
    rig.hide_render = True
    from spec.art_identity.maquettes.blender.render import material
    materials = [material(name, colour, 'parts') for name, colour in spec['labels'].items()]
    for obj in objects:
        for mat in materials:
            obj.data.materials.append(mat)
        from spec.art_identity.maquettes.blender.ownership import assign_materials, expected_materials
        assign_materials(obj, expected_materials(obj, spec, rig['posed_forward']))
    # Hash evaluated geometry before camera transforms; rendering never changes it.
    hashes = {o.name: mesh_hash([list(o.matrix_world @ v.co) for v in o.data.vertices],
                               [list(p.vertices) for p in o.data.polygons], o['part']) for o in objects}
    from spec.art_identity.maquettes.blender.validation import geometry_report
    details = {'metric_accessories': {o.name: json.loads(o['metric_collar']) for o in objects if 'metric_collar' in o},
               'rounded_hoods': {o.name: json.loads(o['rounded_hood_report']) for o in objects if 'rounded_hood_report' in o},
               'sewn_rest': {o.name: json.loads(o['sewn_rest_report']) for o in objects if 'sewn_rest_report' in o}}
    if floor_contact is not None:
        details['floor_contact'] = floor_contact
    if spec.get('cloth_obstacles'):
        from spec.art_identity.maquettes.blender.cloth_contacts import collision_report
        for cloth_id, obstacle_id in spec['cloth_obstacles']:
            garment = next(p for p in spec['pieces'] if p['id'] == cloth_id)
            cloth_reports[cloth_id + '__' + obstacle_id] = collision_report(
                bpy.data.objects[cloth_id + '_render'], bpy.data.objects[obstacle_id + '_render'], garment['collision_margin'])
        details['rigid_clearance'] = {o.name: json.loads(o['rigid_clearance_report']) for o in objects if 'rigid_clearance_report' in o}
    checks = geometry_report(spec, objects, cloth_reports, details)
    if floor_contact is not None:
        checks['floor_contact_correction'] = floor_contact['passed']
    details['blade_attachments'] = {o.name: json.loads(o['blade_attachment_report']) for o in objects
                                    if 'blade_attachment_report' in o}
    checks['sculpted_blade_roots_attached'] = all(r['passed'] for r in details['blade_attachments'].values())
    if any(p.get('drape') for p in spec['pieces']):
        from spec.art_identity.maquettes.blender.drape import simulation_valid, contact_valid
        checks['native_cloth_drape'] = all(simulation_valid(p, simulation_reports.get(p['id'], {}), spec['ortho_scale'])
            for p in spec['pieces'] if p.get('drape'))
        checks['native_cloth_stability'] = all(r['maximum_solver_displacement'] <= spec['ortho_scale']
                                                for r in simulation_reports.values())
        checks['native_cloth_contact_stability'] = all(contact_valid(r, spec['ortho_scale']) for r in simulation_reports.values())
        details['cloth_simulation'] = simulation_reports
    if source_fit is not None:
        details['source_outline_fit'] = source_fit
        checks['source_fit_native_skinning'] = source_fit['maximum_skinning_error'] <= 1e-4
    from spec.art_identity.maquettes.blender.facing import axis_report
    facing = axis_report(spec, rig['posed_forward'])
    checks['board_facing_axis'] = facing['passed']
    details['facing'] = facing
    from mathutils import Vector
    front_frames = {obj.name: axis_report(spec, list(obj.matrix_world.to_3x3() @ Vector((0, -1, 0))))
                    for obj in objects if obj.get('part') == 'torso' and
                    obj.get('piece_type') in ('plate', 'gem')}
    details['front_chest_attachment_axes'] = front_frames
    checks['front_chest_attachment_axes'] = all(r['passed'] for r in front_frames.values())
    report = {'schema': 2, 'spec_hash': source_hash, 'board_frame': spec['_board_frame'], 'context_key': context_key,
              'blender': bpy.app.version_string, 'mesh_hashes': hashes,
              'combined_mesh_hash': digest(hashes), 'checks': checks,
              'cloth': cloth_reports, 'geometry_details': details, 'passed': all(checks.values())}
    write(output / 'build_report.json', report)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'maquette.blend'))
    return objects, report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec', type=Path)
    parser.add_argument('out', type=Path)
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--engine', choices=['cycles', 'workbench'], default='cycles')
    parser.add_argument('--build-only', action='store_true')
    parser.add_argument('--silhouettes-only', action='store_true')
    parser.add_argument('--gallery', action='store_true')
    parser.add_argument('--fit-only', action='store_true', help='Capture front silhouette/body/head for numerical fitting')
    parser.add_argument('--preview', action='store_true', help='Parts/clay/silhouette without per-part solos')
    args = parser.parse_args(argv)
    spec = json.loads(args.spec.read_text())
    validate(spec)
    from spec.art_identity.maquettes.blender.contract import DEFAULT_BUNDLE
    bundle = args.bundle or Path(spec['base'].get('bundle', DEFAULT_BUNDLE)).expanduser()
    objects, report = build(spec, args.out.resolve(), bundle,
                            args.cache or args.out.resolve() / 'cloth_cache')
    if not args.build_only and report['checks'].get('native_cloth_stability', True):
        from spec.art_identity.maquettes.blender.render import render
        from spec.art_identity.maquettes.blender.capture_view import signature
        from spec.art_identity.maquettes.blender.facing import board_spec
        before = signature(objects)
        facing = render(board_spec(spec), objects, args.out, args.engine, args.silhouettes_only, args.gallery, args.fit_only, args.preview)
        report = json.loads((args.out / 'build_report.json').read_text())
        report['checks']['rendered_torso_asymmetry'] = facing['passed']
        report['checks']['capture_geometry_unchanged'] = before == signature(objects)
        report['passed'] = all(report['checks'].values())
        write(args.out / 'build_report.json', report)
        write(args.out / 'capture_checks.json', {'passed': report['passed'], 'spec_hash': report['spec_hash'],
            'geometry_unchanged': report['checks']['capture_geometry_unchanged'],
            'geometry_checks': report['checks'], 'facing': facing})
    print('BLENDER_MAQUETTE: ' + ('PASS' if report['passed'] else 'FAIL'))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main(sys.argv[sys.argv.index('--') + 1:]))
    except (ValueError, KeyError, OSError) as error:
        print('BLENDER_MAQUETTE_ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(2)

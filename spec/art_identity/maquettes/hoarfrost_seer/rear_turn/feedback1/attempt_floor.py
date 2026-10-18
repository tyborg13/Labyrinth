"""Bridge-only diagnostic: apply feedback 1 and measure the front before staging."""
from copy import deepcopy
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))

import bpy
import numpy as np
from mathutils import Vector

from spec.art_identity.maquettes.blender.contract import digest, mesh_hash
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.floor_contact import (
    along_front_ray, far_leg_changes, far_hem_changes, projection_error, contact_guard)
from spec.art_identity.maquettes.blender.rig import evaluated_mesh
from spec.art_identity.maquettes.blender.render import render


def points(obj):
    return np.array([list(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices])


def replace_points(obj, corrected):
    inverse = obj.matrix_world.inverted()
    for vertex, position in zip(obj.data.vertices, corrected):
        vertex.co = inverse @ Vector(position)
    obj.data.update()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main(spec_path, blend_path, output_path):
    source_spec = json.loads(Path(spec_path).read_text())
    spec = board_spec(source_spec)
    output = Path(output_path)
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=blend_path)
    report = json.loads(Path(blend_path).with_name('build_report.json').read_text())
    floor = spec['joints']['ankle_near'][2]
    source_body, posed = bpy.data.objects['body'], bpy.data.objects['posed_body']
    leg_bones = {'thigh_far', 'shin_far', 'foot_far'}
    weights = np.array([sum(group.weight for group in vertex.groups
                           if source_body.vertex_groups[group.group].name in leg_bones)
                        for vertex in source_body.data.vertices])
    errors = {}
    objects = [obj for obj in bpy.context.scene.objects
               if obj.type == 'MESH' and obj.get('part') and not obj.get('native_source')]
    for obj in [posed, *[o for o in objects if o.get('piece_type') == 'body']]:
        before = points(obj)
        after = along_front_ray(spec, before, far_leg_changes(spec, before, weights))
        replace_points(obj, after)
        errors[obj.name] = projection_error(spec, before, points(obj))
    skirt = bpy.data.objects['robe_skirt']
    before_hem_mesh = points(skirt)
    changes, contacts = far_hem_changes(spec, before_hem_mesh, [list(p.vertices) for p in skirt.data.polygons])
    after_hem_mesh = along_front_ray(spec, before_hem_mesh, changes)
    replace_points(skirt, after_hem_mesh)
    errors[skirt.name] = projection_error(spec, before_hem_mesh, points(skirt))
    bpy.context.view_layer.update()
    frozen = bpy.data.objects['robe_skirt_render']
    old = frozen.data
    frozen.data = evaluated_mesh(skirt)
    bpy.data.meshes.remove(old)
    corrected_joints = deepcopy(spec['joints'])
    for name in ('knee_far', 'ankle_far', 'foot_tip_far'):
        point = np.array([spec['joints'][name]])
        corrected_joints[name] = along_front_ray(spec, point, far_leg_changes(spec, point))[0].tolist()
    before_contacts = {'ankle_far': spec['joints']['ankle_far'][2],
                       'robe_skirt.hem_far_min': float(before_hem_mesh[contacts, 2].min()),
                       'robe_skirt.hem_far_max': float(before_hem_mesh[contacts, 2].max())}
    after_contacts = {'ankle_far': corrected_joints['ankle_far'][2],
                      'robe_skirt.hem_far_min': float(after_hem_mesh[contacts, 2].min()),
                      'robe_skirt.hem_far_max': float(after_hem_mesh[contacts, 2].max())}
    staff = next(piece for piece in spec['pieces'] if piece['id'] == 'staff_shaft')
    butt = min(staff['path'][0][2], staff['path'][-1][2])
    before_contacts['staff_shaft.prop_foot'] = after_contacts['staff_shaft.prop_foot'] = butt
    correction = {'floor_m': floor, 'before': contact_guard(before_contacts, floor),
                  'after': contact_guard(after_contacts, floor),
                  'hem_contact_vertices': len(contacts), 'front_projection_error_px': errors,
                  'corrected_joints': corrected_joints,
                  'method': 'front-ray lowering; far-leg blend from hip to ankle; far hem Dirichlet interpolation, fixed waist and near side',
                  'native_pose_recertified': False}
    write(output / 'floor_correction.json', correction)
    source_spec['joints'] = corrected_joints
    spec['joints'] = corrected_joints
    write(output / 'spec.json', source_spec)
    report['spec_hash'] = digest(source_spec)
    report['mesh_hashes'] = {obj.name: mesh_hash([list(obj.matrix_world @ v.co) for v in obj.data.vertices],
        [list(p.vertices) for p in obj.data.polygons], obj['part']) for obj in objects}
    report['combined_mesh_hash'] = digest(report['mesh_hashes'])
    # This is a diagnostic model, not a newly certified native delivery. Only
    # proceed to production integration after the owner's front limits pass.
    report['checks']['floor_correction_recertified'] = False
    report['passed'] = False
    report['floor_correction'] = correction
    write(output / 'build_report.json', report)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / 'maquette.blend'))
    render(spec, objects, output, views=('front',))
    print('FLOOR_CONTACT_CAPTURE: COMPLETE; view=front; diagnostic model, not staged')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

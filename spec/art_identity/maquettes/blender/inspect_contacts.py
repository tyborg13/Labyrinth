"""Read-only diagnostic for a fitted garment and its native contact surface."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.cloth_contacts import inside, mesh_payload

DIAGNOSTIC_DEFAULTS = {'minimum_distance': .003, 'sample_limit': 5,
                       'ray_start_distance': 10, 'ray_length': 20}


def main(blend, output, spec_path=None):
    bpy.ops.wm.open_mainfile(filepath=blend)
    spec = json.loads(Path(spec_path).read_text()) if spec_path else None
    def tree(obj):
        data = mesh_payload(obj)
        return BVHTree.FromPolygons([Vector(p) for p in data['vertices']], data['faces'])
    body = tree(bpy.data.objects['posed_body'])
    result = {}
    for obj in bpy.context.scene.objects:
        if not obj.get('cloth_kind') or obj.get('native_source'):
            continue
        name = 'contact_cloth_contact_' + obj['piece_id']
        contact = tree(bpy.data.objects[name]) if name in bpy.data.objects else body
        errors = []
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            near, normal, _, distance = body.find_nearest(p)
            if distance < DIAGNOSTIC_DEFAULTS['minimum_distance'] or ((p - near).dot(normal) < 0 and inside(body, p)):
                c, n, _, d = contact.find_nearest(p)
                errors.append({'point': list(p), 'body_distance': distance, 'body_inside': inside(body, p),
                               'contact_distance': d, 'contact_inside': inside(contact, p),
                               'contact_normal_dot': (p - c).dot(n)})
                if spec:
                    piece = next(item for item in spec['pieces'] if item['id'] == obj['piece_id'])
                    origin = Vector(piece.get('contact_origin', [0, 0, 0]))
                    direction = Vector(piece['contact_direction']) if 'contact_direction' in piece else (p - origin).normalized()
                    far = p + direction * DIAGNOSTIC_DEFAULTS['ray_start_distance'] if 'contact_direction' in piece else origin + direction * DIAGNOSTIC_DEFAULTS['ray_start_distance']
                    hit, _, _, _ = body.ray_cast(far, -direction, DIAGNOSTIC_DEFAULTS['ray_length'])
                    errors[-1]['outer_ray'] = {'hit': list(hit) if hit is not None else None,
                        'hit_ahead_of_point': (hit - p).dot(direction) if hit is not None else None,
                        'piece_origin': list(origin), 'direction': list(direction)}
                if len(errors) == DIAGNOSTIC_DEFAULTS['sample_limit']:
                    break
        result[obj.name] = {'contact': name, 'first_failed_vertices': errors}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('CONTACT_DIAGNOSTIC: ' + json.dumps(result))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

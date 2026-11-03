"""Independent bridge proof of the accepted pose and protected round-0 meshes."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

GUARD_DEFAULTS = {'world_error_m': 1e-6}


def snapshot(build, spec):
    import bpy
    import numpy as np
    build = Path(build)
    bpy.ops.wm.open_mainfile(filepath=str(build / 'maquette.blend'))
    rig = bpy.data.objects['maquette_armature']
    from spec.art_identity.maquettes.blender.ownership import uses_body_side_ownership
    spine = next(b for b in spec['armature']['bones'] if b['region'] == 'torso')
    bone = rig.pose.bones[spine['name']]
    middle = np.array((bone.head + bone.tail) / 2)
    normal = np.cross(rig['posed_forward'], [0, 0, 1])
    if np.dot(np.subtract(spec['joints']['shoulder_near'], middle), normal) < 0:
        normal = -normal
    near_faces = {}
    inverse = rig.matrix_world.inverted()
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and uses_body_side_ownership(obj):
            near_faces[obj.name] = [list(p.vertices) for p in obj.data.polygons
                if np.dot(np.array(inverse @ obj.matrix_world @ p.center) - middle, normal) >= 0]
    return {'pose': {b.name: [list(row) for row in b.matrix] for b in rig.pose.bones},
        'renderer_near_faces': near_faces,
        'objects': {o.name: {'vertices': np.array([list(o.matrix_world @ v.co) for v in o.data.vertices]),
                           'faces': [list(p.vertices) for p in o.data.polygons]}
                    for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')}}


def main(spec_path, before, after, output):
    import numpy as np
    spec = json.loads(Path(spec_path).read_text())
    old, new = snapshot(before, spec), snapshot(after, spec)
    allowed = {name + '_render': mode for name, mode in spec['shoulder_garment_motion'].items()}
    head_floor = None
    if 'far_skirt' in allowed.values():
        head = old['objects']['body_head']
        head_floor = head['vertices'][sorted({i for f in head['faces'] for i in f}), 2].min()
    midpoint = (np.array(spec['joints']['shoulder_near']) + spec['joints']['shoulder_far']) / 2
    far_sign = np.sign(spec['joints']['shoulder_far'][1] - midpoint[1])
    rows = {}
    for name, a in old['objects'].items():
        b = new['objects'][name]
        topology = a['faces'] == b['faces'] and a['vertices'].shape == b['vertices'].shape
        unchanged = topology and np.array_equal(a['vertices'], b['vertices'])
        near_error = 0.
        head_error = 0.
        renderer_error = 0.
        if name in allowed and name in old['renderer_near_faces']:
            indices = sorted({i for f in old['renderer_near_faces'][name] for i in f})
            if indices:
                renderer_error = float(np.linalg.norm(a['vertices'][indices] - b['vertices'][indices], axis=1).max())
        if name in allowed and allowed[name] != 'root':
            indices = {i for f in a['faces'] if (a['vertices'][f].mean(0)[1] - midpoint[1]) * far_sign <= 0 for i in f}
            if indices:
                indices = sorted(indices)
                near_error = float(np.linalg.norm(a['vertices'][indices] - b['vertices'][indices], axis=1).max())
            if allowed[name] == 'far_skirt':
                indices = sorted({i for f in a['faces'] if a['vertices'][f, 2].max() >= head_floor for i in f})
                head_error = float(np.linalg.norm(a['vertices'][indices] - b['vertices'][indices], axis=1).max())
        rows[name] = {'topology_unchanged': topology, 'unchanged': bool(unchanged),
            'allowed_attachment_motion': name in allowed, 'near_face_error_m': near_error,
            'head_cover_error_m': head_error,
            'renderer_near_face_error_m': renderer_error,
            'passed': bool(topology and (max(near_error, head_error, renderer_error) <= GUARD_DEFAULTS['world_error_m'] if name in allowed else unchanged))}
    result = {'passed': old['pose'] == new['pose'] and all(r['passed'] for r in rows.values()),
        'accepted_pose_exact': old['pose'] == new['pose'], 'objects': rows}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('MQ12_ROUND0_PRESERVATION: ' + ('PASS' if result['passed'] else 'FAIL'))
    if not result['passed']:
        print(json.dumps({n: r for n, r in rows.items() if not r['passed']}))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

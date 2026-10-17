"""Compare saved frozen meshes, independent of pre-save report hashes."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True

import bpy


def snapshot(path):
    bpy.ops.wm.open_mainfile(filepath=path)
    return {o.name: {'vertices': [list(v.co) for v in o.data.vertices],
                     'faces': [list(p.vertices) for p in o.data.polygons],
                     'matrix': [list(row) for row in o.matrix_basis]}
            for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')}


def main(baseline, candidate, output):
    a, b = snapshot(baseline), snapshot(candidate)
    result = {}
    for name in a:
        old, new = a[name], b[name]
        def oriented_faces(faces):
            return sorted(min(tuple(face[i:] + face[:i]) for i in range(len(face))) for face in faces)
        distances = [max(abs(x - y) for x, y in zip(p, q)) for p, q in zip(old['vertices'], new['vertices'])]
        result[name] = {'vertices_identical': old['vertices'] == new['vertices'],
                        'faces_identical': old['faces'] == new['faces'], 'matrix_identical': old['matrix'] == new['matrix'],
                        'same_oriented_faces': oriented_faces(old['faces']) == oriented_faces(new['faces']),
                        'vertex_count': [len(old['vertices']), len(new['vertices'])],
                        'max_coordinate_difference': max(distances, default=0)}
    passed = a == b
    Path(output).write_text(json.dumps({'identical': passed, 'objects': result}, indent=2) + '\n')
    print('SAVED_GEOMETRY_COMPARISON: ' + ('PASS' if passed else 'FAIL'))
    print(json.dumps({k: v for k, v in result.items() if not all(v[f] for f in ('vertices_identical', 'faces_identical', 'matrix_identical'))}))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

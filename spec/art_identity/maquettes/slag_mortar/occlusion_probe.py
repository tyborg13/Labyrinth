"""Bridge-only proof: the crucible covers the posterior skull and harness pivot."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

PROBE_DEFAULTS = {'upper_skull_fraction': .5, 'ray_distance_m': 30.}


def probe(spec, capture):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.raster import camera
    from spec.art_identity.maquettes.blender.facing import board_spec
    from spec.art_identity.maquettes.blender.contract import digest

    bpy.ops.wm.open_mainfile(filepath=str(capture / 'maquette.blend'))
    source_hash = digest(spec)
    build = json.loads((capture / 'build_report.json').read_text())
    if source_hash != build['spec_hash']:
        raise ValueError('Occlusion probe belongs to a different native build')
    spec = board_spec(spec)
    objects = [o for o in bpy.context.scene.objects if 'owner_index' in o and not o.get('native_source')]
    vertices, faces, owners = [], [], []
    head = []
    for obj in objects:
        start = len(vertices)
        vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        faces.extend([start + i for i in p.vertices] for p in obj.data.polygons)
        owners.extend([obj['part']] * len(obj.data.polygons))
        if obj['part'] == 'head':
            used = sorted({i for p in obj.data.polygons for i in p.vertices})
            head.extend(obj.matrix_world @ obj.data.vertices[i].co for i in used)
    tree = BVHTree.FromPolygons(vertices, faces)
    bone = bpy.data.objects['maquette_armature'].pose.bones['head']
    axis = (bone.tail - bone.head).normalized()
    anterior = (bone.matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
    skull = [p for p in head if (p - bone.head).dot(axis) >= bone.length * PROBE_DEFAULTS['upper_skull_fraction']]
    if not skull:
        raise ValueError('Native upper skull sample is empty')
    samples = {'front_face': ('front', max(skull, key=lambda p: p.dot(anterior)), 'head'),
               'rear_skull': ('rear', min(skull, key=lambda p: p.dot(anterior)), 'mortar'),
               'rear_harness': ('rear', Vector(spec['joints']['mortar_pivot']), 'mortar')}
    rows = {}
    for name, (view, point, expected) in samples.items():
        matrix, _, basis, _ = camera(spec, view)
        toward = Vector((basis[2] @ matrix[:3, :3]).tolist()).normalized()
        hit, _, index, _ = tree.ray_cast(point + toward * PROBE_DEFAULTS['ray_distance_m'], -toward)
        owner = owners[index] if hit is not None else None
        rows[name] = {'view': view, 'point_body': list(point), 'first_owner': owner,
                      'expected_owner': expected, 'passed': owner == expected}
    return {'passed': all(r['passed'] for r in rows.values()), 'spec_hash': source_hash,
            'cold_mesh_hash': build['combined_mesh_hash'],
            'checks': {k: r['passed'] for k, r in rows.items()}, 'samples': rows,
            'native_blend_sha256': hashlib.sha256((capture / 'maquette.blend').read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('spec', type=Path)
    parser.add_argument('capture', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    report = probe(json.loads(args.spec.read_text()), args.capture)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + '\n')
    print('MQ09_HEAD_OCCLUSION: ' + ('PASS' if report['passed'] else 'FAIL'))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

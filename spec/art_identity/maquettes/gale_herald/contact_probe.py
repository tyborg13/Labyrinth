"""Bridge-only actual contact locations, including native body owner regions."""
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(build, output):
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from spec.art_identity.maquettes.blender.cloth_contacts import mesh_payload, inside
    from spec.art_identity.maquettes.blender.contract import BUILD_DEFAULTS
    from spec.art_identity.maquettes.raster import project
    build, output = Path(build), Path(output)
    report = json.loads((build / 'build_report.json').read_text())
    spec = json.loads((build / 'source_spec.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(build / 'maquette.blend'))
    body = bpy.data.objects['posed_body']
    owners = json.loads(body['face_owners'])
    payload = mesh_payload(body)
    tree = BVHTree.FromPolygons([Vector(p) for p in payload['vertices']], payload['faces'])
    result = {}
    for name, old in report['cloth'].items():
        if old['passed'] or '__' in name:
            continue
        obj = bpy.data.objects[name + '_render']
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        regions, failed = {}, []
        for p in points:
            near, normal, face, distance = tree.find_nearest(p)
            signed = -distance if (p - near).dot(normal) < 0 and inside(tree, p) else distance
            if signed < old['margin'] - BUILD_DEFAULTS['collision_epsilon']:
                regions[owners[face]] = regions.get(owners[face], 0) + 1
                failed.append({'point': list(p), 'signed_distance': signed, 'region': owners[face]})
        failed.sort(key=lambda p: p['signed_distance'])
        selected = failed[:20]
        result[name] = {'gate': old, 'failed_vertex_regions': regions, 'deepest': selected,
            'front_px': project(spec, [p['point'] for p in selected]).tolist() if selected else []}
    output.write_text(json.dumps(result, indent=2) + '\n')
    print('SHOULDER_CONTACTS: ' + json.dumps({name: r['failed_vertex_regions'] for name, r in result.items()}))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

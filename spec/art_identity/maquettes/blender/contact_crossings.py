"""Inspect actual evaluated triangles at cloth/body crossings through the bridge."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.rig import evaluated_mesh

DIAGNOSTIC_DEFAULTS = {'sample_pairs': 3}


def triangles(obj):
    mesh = evaluated_mesh(obj)
    try:
        mesh.calc_loop_triangles()
        vertices = [obj.matrix_world @ v.co for v in mesh.vertices]
        faces = [list(t.vertices) for t in mesh.loop_triangles]
        return vertices, faces, BVHTree.FromPolygons(vertices, faces, all_triangles=True)
    finally:
        bpy.data.meshes.remove(mesh)


def main(blend, output):
    bpy.ops.wm.open_mainfile(filepath=blend)
    bv, bf, tree = triangles(bpy.data.objects['posed_body'])
    report = {}
    for obj in bpy.context.scene.objects:
        if not obj.get('cloth_kind') or obj.get('native_source'):
            continue
        cv, cf, cloth = triangles(obj)
        pairs = cloth.overlap(tree)
        report[obj.name] = {'triangle_crossings': len(pairs), 'samples': [
            {'cloth': [list(cv[i]) for i in cf[a]], 'body': [list(bv[i]) for i in bf[b]]}
            for a, b in pairs[:DIAGNOSTIC_DEFAULTS['sample_pairs']]]}
    Path(output).write_text(json.dumps(report, indent=2) + '\n')
    print('CONTACT_CROSSINGS: ' + json.dumps({k: v['triangle_crossings'] for k, v in report.items()}))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

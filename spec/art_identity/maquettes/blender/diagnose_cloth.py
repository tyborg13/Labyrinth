"""Native contact diagnostics for a saved build (debug only)."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.cloth import mesh_payload, inside, collision_report

blend, output = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.open_mainfile(filepath=blend)
body = bpy.data.objects['posed_body']
panel = bpy.data.objects['tabard_front_render']
proxy = bpy.data.objects['contact_cloth_contact_tabard_front']
result = {'body': collision_report(panel, body, .003), 'proxy': collision_report(panel, proxy, .003)}
for name, obj in [('body', body), ('proxy', proxy)]:
    data = mesh_payload(obj)
    tree = BVHTree.FromPolygons([Vector(p) for p in data['vertices']], data['faces'])
    negatives = []
    for i, v in enumerate(panel.data.vertices):
        p = panel.matrix_world @ v.co
        near, normal, index, distance = tree.find_nearest(p)
        if distance < .003 or ((p - near).dot(normal) < 0 and inside(tree, p)):
            negatives.append({'index': i, 'p': list(p), 'near': list(near), 'normal': list(normal), 'distance': distance})
    result[name + '_negative_vertices'] = negatives
    result[name + '_faces'] = len(data['faces'])
Path(output).write_text(json.dumps(result, indent=2) + '\n')
print('CLOTH_DIAGNOSTIC: PASS')

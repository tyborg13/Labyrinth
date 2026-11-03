"""Bridge-only inspection of mq-15's saved native geometry, without edits."""
import json
import hashlib
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

import bpy
import numpy as np

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.validation import geometry_report
from spec.art_identity.maquettes.raster import project

PROBE_DEFAULTS = {'native_size_px': 1024, 'endpoint_tolerance_m': 1e-4,
                   'mutation_material_index': 0}


def main(spec_path, build_path, output):
    build_path = Path(build_path)
    authored = json.loads(Path(spec_path).read_text())
    spec = board_spec(authored)
    report = json.loads((build_path / 'build_report.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(build_path / 'maquette.blend'))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH'
               and o.get('part') and not o.get('native_source')]
    from spec.art_identity.maquettes.chainbound_gaoler.geometry_checks import native_mesh_binding
    binding=native_mesh_binding(objects,report)
    current = geometry_report(spec, objects, report['cloth'])
    points = {o.name: np.array([list(o.matrix_world @ v.co) for v in o.data.vertices]) for o in objects}
    bounds = {}
    for name, vertices in points.items():
        bounds[name] = {'world_min': vertices.min(0).tolist(), 'world_max': vertices.max(0).tolist(),
                       'part': bpy.data.objects[name]['part'], 'views': {}}
        for view in ('front', 'rear'):
            pixels = project(spec, vertices, view, PROBE_DEFAULTS['native_size_px'])
            bounds[name]['views'][view] = {'min': pixels[:, :2].min(0).tolist(),
                                           'max': pixels[:, :2].max(0).tolist()}
    saved = {o.name: [p.material_index for p in o.data.polygons] for o in objects}
    for obj in objects:
        for polygon in obj.data.polygons:
            polygon.material_index = PROBE_DEFAULTS['mutation_material_index']
    mutated = geometry_report(spec, objects, report['cloth'])
    for obj in objects:
        for polygon, owner in zip(obj.data.polygons, saved[obj.name]):
            polygon.material_index = owner
    feet = {side: bounds['boot_' + side + '_render'] for side in ('near', 'far')}
    rig = bpy.data.objects['maquette_armature']
    errors = {}
    for bone in spec['armature']['bones']:
        native = rig.pose.bones[bone['name']]
        errors[bone['name']] = max(float(np.linalg.norm(np.array(native.head) - spec['joints'][bone['head']])),
                                   float(np.linalg.norm(np.array(native.tail) - spec['joints'][bone['tail']])))
    from collections import Counter
    closed = {}
    for piece in spec['pieces']:
        if piece['type'] != 'rigid_shell' and not piece['id'].startswith('grip_'):
            continue
        obj = bpy.data.objects[piece['id'] + '_render']
        edges = Counter(tuple(sorted((a,b))) for face in obj.data.polygons
                        for a,b in zip(list(face.vertices),list(face.vertices)[1:]+list(face.vertices)[:1]))
        closed[piece['id']] = {'nonmanifold_edges': sum(n != 2 for n in edges.values()),
                               'faces': len(obj.data.polygons), 'passed': bool(edges) and all(n == 2 for n in edges.values())}
    from spec.art_identity.maquettes.chainbound_gaoler.geometry_checks import hem_tip_count, grip_observation, GEOMETRY_PROOF_DEFAULTS
    recipe=json.loads((Path(__file__).parent/'measurements.json').read_text())
    hems={}
    for item in recipe['surfaces']:
        if item['id'] not in ('coat_near','coat_far','tabard'):
            continue
        columns=len(item['rows'][0]);start=(len(item['rows'])-1)*columns
        edge=points[item['id']+'_render'][start:start+columns]
        hems[item['id']]={'tip_count':hem_tip_count(-edge[:,2],GEOMETRY_PROOF_DEFAULTS['hem_prominence_m']),
                         'views':{view:project(spec,edge,view,1024)[:,:2].tolist() for view in ('front','rear')}}
    frame=spec.get('surface_pose',{}).get('grip_frame',recipe['mq15']['grip_frame'])
    grip=grip_observation(spec,points,frame)
    from spec.art_identity.maquettes.raster import triangle_samples
    hook=bpy.data.objects['iron_hook_render']
    pixels=project(spec,points['iron_hook_render'],'front',255)
    hook_mask=np.zeros((255,255),bool)
    for face in hook.data.polygons:
        for i in range(1,len(face.vertices)-1):
            sample=triangle_samples(pixels[[face.vertices[0],face.vertices[i],face.vertices[i+1]]],255,255)
            if sample is not None:hook_mask[sample[0],sample[1]]=True
    hook_centroid=np.argwhere(hook_mask).mean(0)[::-1].tolist() if hook_mask.any() else None
    result = {'hook_centroid_255_px':hook_centroid, 'cloth_hems':hems,'gloved_grip':grip,'closed_topology': closed, 'spec_hash': digest(authored), 'native_mesh_hash': binding['native_mesh_hash'], 'native_hash_mismatches': binding['mismatches'],
              'blend_sha256': hashlib.sha256((build_path / 'maquette.blend').read_bytes()).hexdigest(),
              'objects': bounds, 'feet': feet,
              'endpoint_errors_m': errors,
              'checks': {'native_mesh_binding': binding['passed'],
                         'native_geometry': all(current.values()),
                         'gloved_grip':grip['passed'],
                         'closed_forms': bool(closed) and all(v['passed'] for v in closed.values()),
                         'material_mutation_caught': not mutated['polygon_material_ownership'],
                         'native_endpoints': max(errors.values()) <= PROBE_DEFAULTS['endpoint_tolerance_m']}}
    result['passed'] = all(result['checks'].values())
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('MQ15_NATIVE_PROBE: ' + ('PASS' if result['passed'] else 'FAIL'))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

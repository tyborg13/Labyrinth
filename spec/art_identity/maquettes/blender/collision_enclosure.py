"""Read-only proof of source-anatomy containment and failed garment contacts."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.cloth_contacts import inside, collision_report
from spec.art_identity.maquettes.blender.conformance import body_tree


def main(blend, output):
    bpy.ops.wm.open_mainfile(filepath=blend)
    body = bpy.data.objects['posed_body']
    proxy = bpy.data.objects['native_drape_collision_skin']
    tree = body_tree(proxy)
    used = {i for p in body.data.polygons for i in p.vertices}
    outside = [i for i in sorted(used) if not inside(tree, body.matrix_world @ body.data.vertices[i].co)]
    report = json.loads(Path(blend).with_name('build_report.json').read_text())
    cloth = {}
    for obj in bpy.context.scene.objects:
        if obj.get('cloth_kind') and not obj.get('native_source') and not report['cloth'][obj['piece_id']]['passed']:
            cloth[obj['piece_id']] = collision_report(obj, proxy, report['cloth'][obj['piece_id']]['margin'])
    result = {'original_vertices': len(used), 'outside_collision_envelope': len(outside),
              'outside_vertex_indices': outside, 'failed_cloth_against_envelope': cloth}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('COLLISION_ENCLOSURE: ' + json.dumps(result))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

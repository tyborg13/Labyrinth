"""Read-only attribution of garment intersections to source anatomy regions."""
from collections import Counter
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.cloth_contacts import mesh_payload


def main(blend, output, spec_path=None):
    bpy.ops.wm.open_mainfile(filepath=blend)
    body = bpy.data.objects['posed_body']
    data = mesh_payload(body)
    tree = BVHTree.FromPolygons([Vector(p) for p in data['vertices']], data['faces'])
    owners = json.loads(body['face_owners'])
    result = {}
    bounds, semantic = {}, {}
    spec = json.loads(Path(spec_path).read_text()) if spec_path else None
    for obj in bpy.context.scene.objects:
        if not obj.get('cloth_kind') or obj.get('native_source'):
            continue
        cloth = mesh_payload(obj)
        surface = BVHTree.FromPolygons([Vector(p) for p in cloth['vertices']], cloth['faces'])
        pairs = surface.overlap(tree)
        result[obj['piece_id']] = dict(Counter(owners[j] for _, j in pairs))
        if spec and pairs:
            from spec.art_identity.maquettes.raster import project
            import numpy as np
            indices = sorted({i for i, _ in pairs})
            points = [cloth['vertices'][i] for face in indices for i in cloth['faces'][face]]
            bounds[obj['piece_id']] = {}
            for view in ('front', 'rear'):
                pixels = np.array([project(spec, p, view, 1024)[:2] for p in points])
                bounds[obj['piece_id']][view] = [*pixels.min(0).tolist(), *pixels.max(0).tolist()]
            semantic[obj['piece_id']] = dict(Counter(list(spec['labels'])[obj.data.polygons[i].material_index] for i in indices))
    if spec:
        from spec.art_identity.maquettes.blender.contract import digest
        result = {'spec_hash': digest(spec), 'body_contacts': result,
                  'cloth_semantic_parts': semantic, 'view_bboxes_px': bounds}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('CONTACT_OWNERS: ' + json.dumps(result))


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

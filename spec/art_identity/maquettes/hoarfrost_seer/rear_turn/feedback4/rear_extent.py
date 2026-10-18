"""Read native rear extents before any capture; invoke via the Blender bridge."""
import json
from pathlib import Path
import sys

import bpy
import numpy as np

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.view_states import active_in_view
from spec.art_identity.maquettes.raster import project

PROOF_DEFAULTS = {'size_px': 1024, 'edge_margin_px': 8}


def main(spec_path, build_path, output):
    spec = board_spec(json.loads(Path(spec_path).read_text()))
    bpy.ops.wm.open_mainfile(filepath=str(Path(build_path) / 'maquette.blend'))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and
               o.get('part') and not o.get('native_source') and active_in_view(o, 'rear')]
    rows = {}
    for obj in objects:
        used = sorted({i for p in obj.data.polygons for i in p.vertices})
        points = [list(obj.matrix_world @ obj.data.vertices[i].co) for i in used]
        xy = project(spec, points, 'rear', PROOF_DEFAULTS['size_px'])[:, :2]
        rows[obj.name] = {'min_px': xy.min(axis=0).tolist(), 'max_px': xy.max(axis=0).tolist()}
    low = np.min([row['min_px'] for row in rows.values()], axis=0)
    high = np.max([row['max_px'] for row in rows.values()], axis=0)
    span = high - low
    limit = PROOF_DEFAULTS['size_px'] - 2 * PROOF_DEFAULTS['edge_margin_px']
    report = {'bounds_px': [low.tolist(), high.tolist()], 'width_px': float(span[0]),
              'height_px': float(span[1]), 'maximum_height_px': limit,
              'ortho_scale': spec['ortho_scale'], 'objects': rows,
              'passed': bool(np.all(span <= limit)),
              'method': 'all face-used evaluated vertices, exact rear root turn, unchanged orthographic camera'}
    from spec.art_identity.maquettes.blender.rear_body import hem_indices
    source = bpy.data.objects[spec['rear_body']['hem_piece']]
    garment = bpy.data.objects[source.name + '_render']
    count = len(source.data.vertices)
    boundary = {i + shell * count for shell in (0, 1) for i in hem_indices(source)}
    report['hem_shell_heights_m'] = {}
    for name in ('skirt_near', 'skirt_far'):
        owner = list(spec['labels']).index(name)
        used = {i for p in garment.data.polygons if p.material_index == owner for i in p.vertices} & boundary
        heights = [float(garment.data.vertices[i].co.z) for i in used]
        report['hem_shell_heights_m'][name] = {'min': min(heights), 'max': max(heights), 'vertices': len(heights)}
    Path(output).write_text(json.dumps(report, indent=2) + '\n')
    print('MQ06_REAR_EXTENT: ' + ('PASS' if report['passed'] else 'STOP') +
          '; height_px=' + str(report['height_px']) + '; limit_px=' + str(limit))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

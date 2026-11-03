"""Verify loaded world-space meshes against the native builder's exact inventory."""
import json
from pathlib import Path

from spec.art_identity.maquettes.blender.contract import digest, mesh_hash


def verify_geometry(objects, report):
    hashes = {o.name: mesh_hash([list(o.matrix_world @ v.co) for v in o.data.vertices],
                               [list(p.vertices) for p in o.data.polygons], o['part']) for o in objects}
    combined = digest(hashes)
    if hashes != report['mesh_hashes'] or combined != report['combined_mesh_hash']:
        raise ValueError('Loaded saved geometry differs from the build report')
    return combined


def load(spec_path, build):
    import bpy
    spec = json.loads(Path(spec_path).read_text())
    build = Path(build)
    report = json.loads((build / 'build_report.json').read_text())
    if report['spec_hash'] != digest(spec):
        raise ValueError('Saved geometry belongs to a different spec')
    bpy.ops.wm.open_mainfile(filepath=str(build / 'maquette.blend'))
    bpy.context.view_layer.update()
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    return spec, report, objects, verify_geometry(objects, report)

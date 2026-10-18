"""Read-only bit-exact geometry and joint proof from the three saved builds."""
from array import array
import hashlib
import json
from pathlib import Path
import struct
import sys

sys.dont_write_bytecode = True
import bpy

RAW_PROOF_DEFAULTS = {'float_code': 'f', 'index_code': 'i', 'bool_code': 'b'}


def object_hash(obj):
    mesh = obj.data
    result = hashlib.sha256()
    result.update(struct.pack('16f', *(x for row in obj.matrix_world for x in row)))
    for collection, attribute, count, code in (
            (mesh.vertices, 'co', 3 * len(mesh.vertices), RAW_PROOF_DEFAULTS['float_code']),
            (mesh.edges, 'vertices', 2 * len(mesh.edges), RAW_PROOF_DEFAULTS['index_code']),
            (mesh.loops, 'vertex_index', len(mesh.loops), RAW_PROOF_DEFAULTS['index_code']),
            (mesh.loops, 'edge_index', len(mesh.loops), RAW_PROOF_DEFAULTS['index_code']),
            (mesh.polygons, 'loop_start', len(mesh.polygons), RAW_PROOF_DEFAULTS['index_code']),
            (mesh.polygons, 'loop_total', len(mesh.polygons), RAW_PROOF_DEFAULTS['index_code']),
            (mesh.polygons, 'material_index', len(mesh.polygons), RAW_PROOF_DEFAULTS['index_code']),
            (mesh.polygons, 'use_smooth', len(mesh.polygons), RAW_PROOF_DEFAULTS['bool_code'])):
        values = array(code, [0]) * count
        collection.foreach_get(attribute, values)
        result.update(struct.pack('Q', count))
        result.update(values.tobytes())
    return result.hexdigest()


def main(folder, output):
    root = Path(folder)
    builds, joint_hashes, spec_hashes = {}, {}, {}
    for name in ('cold', 'replay', 'independent_cold'):
        report = json.loads((root / name / 'build_report.json').read_text())
        bpy.ops.wm.open_mainfile(filepath=str(root / name / 'maquette.blend'))
        bpy.context.view_layer.update()
        builds[name] = {key: object_hash(bpy.data.objects[key]) for key in sorted(report['mesh_hashes'])}
        rig = bpy.data.objects['maquette_armature']
        joints = [x for bone in sorted(rig.pose.bones, key=lambda b: b.name)
                  for row in bone.matrix for x in row]
        joint_hashes[name] = hashlib.sha256(struct.pack(str(len(joints)) + 'f', *joints)).hexdigest()
        spec_hashes[name] = report['spec_hash']
    passed = (all(v == builds['cold'] for v in builds.values()) and
              len(set(joint_hashes.values())) == 1 and len(set(spec_hashes.values())) == 1)
    result = {'passed': passed, 'byte_order': sys.byteorder, 'rounding': None,
              'spec_hash': spec_hashes['cold'], 'mesh_count': len(builds['cold']),
              'mesh_hashes': builds, 'joint_matrix_hashes': joint_hashes}
    Path(output).write_text(json.dumps(result, indent=2) + '\n')
    print('EXACT_NATIVE_REPLAY: ' + ('PASS' if passed else 'FAIL') +
          '; unrounded_float32=true; mesh_count=' + str(result['mesh_count']))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

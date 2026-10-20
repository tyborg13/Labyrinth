"""Director bridge entry: export and measure the frozen mq-11 native accessories."""
import hashlib
import io
import json
import os
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.hollow_mimic.owner_review.measurements import measure


def sha(path):
    """Hash native files without importing the host-side image toolchain."""
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(io.DEFAULT_BUFFER_SIZE), b''):
            result.update(block)
    return result.hexdigest()


def write(path, data):
    """Keep the host receipt format and durable writes using only stdlib."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as stream:
        json.dump(data, stream, separators=(',', ':'), allow_nan=False)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())


def main(spec_path, capture_path, output_path):
    import bpy

    spec_path, capture = Path(spec_path), Path(capture_path)
    spec = json.loads(spec_path.read_text())
    build = json.loads((capture / 'build_report.json').read_text())
    if build['spec_hash'] != digest(spec) or not build['passed']:
        raise ValueError('Native shape probe requires its passing, current cold build')
    bpy.ops.wm.open_mainfile(filepath=str(capture / 'maquette.blend'))
    names = ('hair_crown', 'cracked_mask') if spec['id'] == 'hollow_mimic' else ('leather_apron', 'rear_leather_apron')
    meshes = {}
    for name in names:
        obj = bpy.data.objects[name + '_render']
        if obj.get('native_source') or obj.get('piece_id') != name:
            raise ValueError('Expected frozen native accessory: ' + name)
        used = sorted({i for face in obj.data.polygons for i in face.vertices})
        indices = {old: new for new, old in enumerate(used)}
        meshes[name] = {'vertices': [list(obj.matrix_world @ obj.data.vertices[i].co) for i in used],
                        'faces': [[indices[i] for i in face.vertices] for face in obj.data.polygons]}
    binding = {'spec_hash': digest(spec), 'cold_mesh_hash': build['combined_mesh_hash'],
               'blend_sha256': sha(capture / 'maquette.blend'),
               'build_report_sha256': sha(capture / 'build_report.json')}
    # Host verification can replay measurements from these exact frozen native
    # triangles without opening Blender or trusting cached numeric results.
    mesh_path = capture / 'mq11_meshes.json'
    write(mesh_path, dict(binding, meshes=meshes))
    report = measure(spec, meshes)
    report.update(binding, mesh_export_sha256=sha(mesh_path))
    write(output_path, report)
    print('MQ11_NATIVE_SHAPE: ' + ('PASS' if report['passed'] else 'FAIL') + '; ' + spec['id'])
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main(*sys.argv[sys.argv.index('--') + 1:]))

"""Native proof-only solo without transparent excluded cloth faces.

The delivery renderer is preserved. On a disposable loaded scene, remove the
excluded faces of split cloth before its normal bounded solo render. Retain
the exact original selected-face geometry hash and ownership hash as evidence.
"""
import hashlib
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))


def main(spec_path, build, output, label):
    import bpy
    from spec.art_identity.maquettes.blender.contract import digest, mesh_hash
    from spec.art_identity.maquettes.blender.facing import board_spec
    from spec.art_identity.maquettes.blender.ownership import cloak_owners, uses_body_side_ownership, ARMATURE_UP_AXIS
    from spec.art_identity.maquettes.blender.render import render
    def sha(path):
        return hashlib.sha256(Path(path).read_bytes()).hexdigest()

    def write(path, value):
        Path(path).write_text(json.dumps(value, indent=2) + '\n')
    spec = json.loads(Path(spec_path).read_text())
    build, output = Path(build), Path(output)
    source = json.loads((build / 'build_report.json').read_text())
    if source['spec_hash'] != digest(spec):
        raise ValueError('Isolated proof input does not match native build')
    bpy.ops.wm.open_mainfile(filepath=str(build / 'maquette.blend'))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    rig = bpy.data.objects['maquette_armature']
    spine = next(b for b in spec['armature']['bones'] if b['region'] == 'torso')
    bone = rig.pose.bones[spine['name']]
    inverse = rig.matrix_world.inverted()
    selected = {}
    for obj in objects:
        if not uses_body_side_ownership(obj):
            continue
        centres = [list(inverse @ obj.matrix_world @ p.center) for p in obj.data.polygons]
        owners = cloak_owners(centres, list((bone.head + bone.tail) / 2), rig['posed_forward'],
                              ARMATURE_UP_AXIS, spec['joints']['shoulder_near'], spec['joints']['shoulder_far'])
        pair = list(obj.get('side_parts', ['cape_near', 'cape_far']))
        labels = [pair[0 if owner == 'cape_near' else 1] for owner in owners]
        faces = [list(p.vertices) for p, owner in zip(obj.data.polygons, labels) if owner == label]
        if not faces:
            continue
        indices = sorted({i for face in faces for i in face})
        remap = {old: new for new, old in enumerate(indices)}
        vertices = [list(obj.data.vertices[i].co) for i in indices]
        world = [list(obj.matrix_world @ obj.data.vertices[i].co) for i in indices]
        faces = [[remap[i] for i in face] for face in faces]
        selected[obj.name] = {'faces': len(faces), 'vertices': len(vertices),
                              'world_geometry_hash': mesh_hash(world, faces, label)}
        mesh = bpy.data.meshes.new(obj.name + '_isolated_proof')
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj.data = mesh
    if not selected:
        raise ValueError('No split cloth faces for isolated part: ' + label)
    working = board_spec(spec)
    working.pop('fit', None)
    output.mkdir(parents=True, exist_ok=True)
    write(output / 'build_report.json', source)
    render(working, objects, output, views=('front',), ownership_only=True, solo_parts=[label])
    report = {'passed': True, 'proof_only': True, 'label': label, 'spec_hash': digest(spec),
        'native_build_sha256': sha(build / 'build_report.json'),
        'selected_faces': selected, 'solo_sha256': sha(output / ('front_solo_' + label + '.png')),
        'method': 'Native selected cloth faces only; excluded faces removed from a disposable scene, with native board camera, resolution and emission solo settings unchanged.'}
    write(output / 'isolation.json', report)
    print('MQ12_ISOLATED_PART: PASS; ' + label)


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

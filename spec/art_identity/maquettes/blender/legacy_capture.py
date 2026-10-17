"""Bridge-only CPU solo oracle: unchanged legacy geometry versus shared adapter."""
import hashlib
import json
import os
from pathlib import Path
import sys
sys.dont_write_bytecode = True

import bpy
from mathutils import Matrix, Vector
from bpy_extras.object_utils import world_to_camera_view

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.raster import camera
from spec.art_identity.maquettes.shrike_spec import legacy_shrike

PROOF_DEFAULTS = {'size': 1024, 'samples': 1, 'threads': 8, 'seed': 0}


def main(name, version, view, source, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    spec = legacy_shrike(0) if name == 'gust_shrike' else json.loads(
        (PROJECT / 'spec/art_identity/maquettes' / name / 'spec.json').read_text())
    source_path = Path(source)
    if version == 'legacy':
        # Execute the committed oracle's geometry AND camera verbatim. Only its
        # Workbench rendering loop is replaced with CPU alpha proof below.
        text = source_path.read_text()
        spec_path = output / 'input_spec.json'
        spec_path.write_text(json.dumps(spec))
        sys.argv = [str(source_path), '--', str(output)] if name == 'gust_shrike' else [str(source_path), '--', str(spec_path), str(output)]
        os.environ['FRONT_YAW'] = '0'
        scope = {'__file__': str(source_path), '__name__': '__legacy_oracle__'}
        exec(compile(text.split("scene.render.engine =")[0], str(source_path), 'exec'), scope)
        root = scope['root']
        objects = scope['objects_by_part'] if name == 'gust_shrike' else scope['objs']
        joints = scope['JOINTS'] if name == 'gust_shrike' else scope['J']
        cam = scope['cam']
        root.rotation_euler.z = 0 if view == 'front' else __import__('math').pi
    else:
        from spec.art_identity.maquettes.humanoid import render
        captured = []
        render(spec, output, lambda *args: captured.append(args))
        _, _, root, objects, joints = captured[0]
        matrix, target, basis, scale = camera(spec, view)
        root.matrix_world = Matrix(matrix.tolist())
        data = bpy.data.cameras.new('proof_camera')
        data.type, data.ortho_scale = 'ORTHO', scale
        cam = bpy.data.objects.new('proof_camera', data)
        bpy.context.scene.collection.objects.link(cam)
        cam.location = Vector(target) + Vector(basis[2]) * spec.get('camera_distance', 30)
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.engine = 'CYCLES'
    scene.cycles.device, scene.cycles.samples = 'CPU', PROOF_DEFAULTS['samples']
    scene.cycles.seed = PROOF_DEFAULTS['seed']
    scene.render.threads_mode, scene.render.threads = 'FIXED', PROOF_DEFAULTS['threads']
    scene.render.resolution_x = scene.render.resolution_y = PROOF_DEFAULTS['size']
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.file_format = 'PNG'
    bpy.context.view_layer.update()
    path = output / 'joints_px.json'
    projected = json.loads(path.read_text()) if path.exists() else {}
    projected[view] = {}
    for name, point in joints.items():
        p = world_to_camera_view(scene, cam, root.matrix_world @ Vector(point))
        projected[view][name] = [round(p.x * PROOF_DEFAULTS['size'], 2), round((1 - p.y) * PROOF_DEFAULTS['size'], 2)]
    path.write_text(json.dumps(projected, indent=2) + '\n')
    for part in spec['labels']:
        for other, meshes in objects.items():
            for obj in meshes:
                obj.hide_render = other != part
        scene.render.filepath = str(output / f'{view}_solo_{part}.png')
        bpy.ops.render.render(write_still=True)
    (output / f'{view}_receipt.json').write_text(json.dumps({'source_sha256': hashlib.sha256(source_path.read_bytes()).hexdigest(),
        'version': version, 'view': view, 'defaults': PROOF_DEFAULTS}, indent=2) + '\n')
    print('BLENDER_LEGACY_SOLOS: PASS')


if __name__ == '__main__':
    main(*sys.argv[sys.argv.index('--') + 1:])

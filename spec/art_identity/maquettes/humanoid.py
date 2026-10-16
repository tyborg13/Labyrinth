# Blender adapter for the shared NumPy maquette meshes. No geometry modifiers.
# Blender -b --factory-startup -P humanoid.py -- SPEC.json OUT_DIR
import json
import os
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from spec.art_identity.maquettes.geometry import build_meshes, deform_width, part_options
from spec.art_identity.maquettes.raster import camera


def render(spec, out):
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    root = bpy.data.objects.new('maquette', None)
    scene.collection.objects.link(root)
    J = {key: Vector(deform_width(spec, value)) for key, value in spec['joints'].items()}
    objs = {}
    for part, mesh in build_meshes(spec).items():
        data = bpy.data.meshes.new(part)
        data.from_pydata(mesh.vertices.tolist(), [], mesh.faces.tolist())
        data.update()
        obj = bpy.data.objects.new(part, data)
        scene.collection.objects.link(obj)
        obj.parent = root
        material = bpy.data.materials.new(part)
        material.diffuse_color = (*spec['labels'][part], 1)
        data.materials.append(material)
        for polygon in data.polygons:
            options = part_options(spec, part)
            polygon.use_smooth = options.get('smooth', False) or options.get('smooth_normals', False)
        objs[part] = [obj]
    cam_data = bpy.data.cameras.new('cam'); cam_data.type = 'ORTHO'
    cam = bpy.data.objects.new('cam', cam_data); scene.collection.objects.link(cam); scene.camera = cam
    scene.render.engine = 'BLENDER_WORKBENCH'; scene.render.resolution_x = scene.render.resolution_y = 1024
    scene.render.film_transparent = True; sh = scene.display.shading
    from bpy_extras.object_utils import world_to_camera_view
    def project(p):
        co = world_to_camera_view(scene, cam, root.matrix_world @ p); return [round(co.x * 1024, 2), round((1 - co.y) * 1024, 2)]
    result = {}
    for view in ('front', 'rear'):
        matrix, aim, basis, scale = camera(spec, view)
        root.matrix_world = Matrix(matrix.tolist())
        target = Vector(aim)
        distance = spec.get('view_transforms', {}).get(view, {}).get('distance', spec.get('camera_distance', 30))
        cam.location = target + Vector(basis[2]) * distance
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam_data.ortho_scale = scale
        bpy.context.view_layer.update()
        for mode in ('parts', 'clay'):
            sh.light = 'FLAT' if mode == 'parts' else 'STUDIO'; sh.color_type = 'MATERIAL' if mode == 'parts' else 'SINGLE'
            sh.single_color = (0.6, 0.6, 0.6); sh.show_cavity = mode == 'clay'
            for o in [o for os_ in objs.values() for o in os_]: o.hide_render = False
            scene.render.filepath = os.path.join(out, f'{view}_{mode}.png'); bpy.ops.render.render(write_still=True)
        sh.light = 'FLAT'; sh.color_type = 'MATERIAL'
        for part in spec.get('solo', []):
            for p2, os_ in objs.items():
                for o in os_: o.hide_render = (p2 != part)
            scene.render.filepath = os.path.join(out, f'{view}_solo_{part}.png'); bpy.ops.render.render(write_still=True)
        for o in [o for os_ in objs.values() for o in os_]: o.hide_render = False
        result[view] = {k: project(v) for k, v in J.items()}
    json.dump(result, open(os.path.join(out, 'joints_px.json'), 'w'), indent=1)


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:]
    with open(args[0]) as handle:
        definition = json.load(handle)
    render(definition, args[1])
